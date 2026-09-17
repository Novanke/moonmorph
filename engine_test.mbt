///|
fn sample_document() -> Value {
  Object([
    ("version", Number(1.0)),
    (
      "service",
      Object([("host", String("localhost")), ("port", Number(8080.0))]),
    ),
    ("features", Array([String("search"), String("export")])),
  ])
}

///|
fn p(text : String) -> Path {
  Path::parse(text).unwrap()
}

///|
test "get nested values" {
  inspect(
    get(sample_document(), p("/service/host")).unwrap().to_json_string(),
    content="\"localhost\"",
  )
  inspect(
    get(sample_document(), p("/features/1")).unwrap().to_json_string(),
    content="\"export\"",
  )
}

///|
test "atomic migration and rollback" {
  let migration = Migration::new(
    name="v1-to-v2",
    from_version="1",
    to_version="2",
    operations=[
      Test(p("/version"), Number(1.0)),
      Replace(p("/version"), Number(2.0)),
      Rename(p("/service"), "host", "hostname"),
      Increment(p("/service/port"), 1.0),
      Add(p("/features/-"), String("audit")),
    ],
  )
  let result = apply(migration, sample_document()).unwrap()
  inspect(
    result.value.to_json_string(),
    content="{\"version\":2,\"service\":{\"port\":8081,\"hostname\":\"localhost\"},\"features\":[\"search\",\"export\",\"audit\"]}",
  )
  let rolled_back = apply_rollback(result).unwrap()
  inspect(rolled_back.value == sample_document(), content="true")
}

///|
test "rollback plan uses one root snapshot" {
  let migration = Migration::new(
    name="multi-step",
    from_version="1",
    to_version="2",
    operations=[
      Replace(p("/version"), Number(2.0)),
      Increment(p("/service/port"), 1.0),
      Add(p("/features/-"), String("audit")),
    ],
  )
  let result = apply(migration, sample_document()).unwrap()
  inspect(result.journal.length(), content="3")
  guard result.rollback is Some(rollback) else {
    fail("expected rollback plan")
  }
  inspect(rollback.operations.length(), content="1")
  inspect(
    apply(rollback, result.value).unwrap().value == sample_document(),
    content="true",
  )
}

///|
test "identity migration keeps an empty rollback plan" {
  let migration = Migration::new(
    name="identity",
    from_version="1",
    to_version="2",
    operations=[],
  )
  let result = apply(migration, sample_document()).unwrap()
  guard result.rollback is Some(rollback) else {
    fail("expected rollback plan")
  }
  inspect(rollback.operations.length(), content="0")
  inspect(
    apply_rollback(result).unwrap().value == sample_document(),
    content="true",
  )
}

///|
test "failure leaves caller input unchanged" {
  let original = sample_document()
  let migration = Migration::new(
    name="broken",
    from_version="1",
    to_version="2",
    operations=[Replace(p("/version"), Number(2.0)), Remove(p("/missing"))],
  )
  let outcome = apply(migration, original)
  inspect(outcome is Err({ operation_index: 1, .. }), content="true")
  inspect(original == sample_document(), content="true")
}

///|
test "array insert remove copy and move" {
  let source : Value = Object([
    ("items", Array([String("a"), String("c")])),
    ("backup", Null),
  ])
  let migration = Migration::new(
    name="collections",
    from_version="1",
    to_version="2",
    operations=[
      Add(p("/items/1"), String("b")),
      Copy(p("/items"), p("/backup")),
      Move(p("/items/2"), p("/items/0")),
      Remove(p("/items/2")),
    ],
  )
  let result = apply(migration, source).unwrap()
  inspect(
    result.value.to_json_string(),
    content="{\"items\":[\"c\",\"a\"],\"backup\":[\"a\",\"b\",\"c\"]}",
  )
}

///|
test "preflight reports same-path writes" {
  let migration = Migration::new(
    name="conflict",
    from_version="1",
    to_version="2",
    operations=[
      Replace(p("/version"), Number(2.0)),
      Increment(p("/version"), 1.0),
    ],
  )
  let conflicts = detect_conflicts(migration)
  inspect(conflicts.length(), content="1")
  inspect(conflicts[0], content="operations 0 and 1 both write /version")
}

///|
test "object keys are type-directed" {
  let document : Value = Object([
    ("0", String("zero")),
    ("-", String("dash")),
    ("a/b", String("slash")),
    ("~meta", String("tilde")),
  ])
  inspect(get(document, p("/0")).unwrap().to_json_string(), content="\"zero\"")
  inspect(get(document, p("/-")).unwrap().to_json_string(), content="\"dash\"")
  inspect(
    get(document, p("/a~1b")).unwrap().to_json_string(),
    content="\"slash\"",
  )
  inspect(
    get(document, p("/~0meta")).unwrap().to_json_string(),
    content="\"tilde\"",
  )
}

///|
test "replace at root" {
  let migration = Migration::new(
    name="root",
    from_version="1",
    to_version="2",
    operations=[Replace(Path::root(), String("entirely new"))],
  )
  let result = apply(migration, sample_document()).unwrap()
  inspect(result.value.to_json_string(), content="\"entirely new\"")
  inspect(
    apply_rollback(result).unwrap().value == sample_document(),
    content="true",
  )
}

///|
test "rename refuses to overwrite" {
  let migration = Migration::new(
    name="unsafe-rename",
    from_version="1",
    to_version="2",
    operations=[Rename(p("/service"), "host", "port")],
  )
  match apply(migration, sample_document()) {
    Err(error) => {
      inspect(error.code == AlreadyExists, content="true")
      inspect(error.path, content="/service/port")
    }
    Ok(_) => fail("expected rename collision")
  }
}

///|
test "increment checks the value type" {
  let migration = Migration::new(
    name="bad-increment",
    from_version="1",
    to_version="2",
    operations=[Increment(p("/service/host"), 1.0)],
  )
  match apply(migration, sample_document()) {
    Err(error) => inspect(error.code == TypeMismatch, content="true")
    Ok(_) => fail("expected type mismatch")
  }
}

///|
test "array bounds are checked" {
  let migration = Migration::new(
    name="bad-index",
    from_version="1",
    to_version="2",
    operations=[Add(p("/features/9"), String("never"))],
  )
  match apply(migration, sample_document()) {
    Err(error) => inspect(error.code == IndexOutOfBounds, content="true")
    Ok(_) => fail("expected bounds error")
  }
}

///|
test "append is invalid before the final segment" {
  let migration = Migration::new(
    name="bad-append",
    from_version="1",
    to_version="2",
    operations=[Add(p("/features/-/x"), String("never"))],
  )
  match apply(migration, sample_document()) {
    Err(error) => inspect(error.code == InvalidPath, content="true")
    Ok(_) => fail("expected append path error")
  }
}

///|
test "test precondition stops the transaction" {
  let migration = Migration::new(
    name="guarded",
    from_version="1",
    to_version="2",
    operations=[
      Replace(p("/service/port"), Number(9000.0)),
      Test(p("/version"), Number(9.0)),
    ],
  )
  match apply(migration, sample_document()) {
    Err(error) => {
      inspect(error.code == TestFailed, content="true")
      inspect(error.operation_index, content="1")
    }
    Ok(_) => fail("expected failed precondition")
  }
}

///|
test "preflight accepts a valid append migration" {
  let migration = Migration::new(
    name="append-feature",
    from_version="1",
    to_version="2",
    operations=[Add(p("/features/-"), String("audit"))],
  )
  let report = preflight(migration)
  inspect(report.is_valid(), content="true")
  inspect(report.warnings.length(), content="0")
}

///|
test "preflight rejects unsafe plan invariants" {
  let migration = Migration::new(name="", from_version="1", to_version="1", operations=[
    Remove(p("/features/-")),
    Move(p("/service"), p("/service/archive")),
    Rename(p("/service"), "host", "host"),
  ])
  let report = preflight(migration)
  inspect(report.is_valid(), content="false")
  inspect(report.errors.length(), content="5")
  inspect(
    report.errors[3],
    content="operation 1: cannot move a value into its own descendant",
  )
}

///|
test "preflight reports empty and repeated write plans" {
  let empty = Migration::new(name="empty", from_version="1", to_version="2", operations=[])
  inspect(
    preflight(empty).warnings[0],
    content="migration contains no operations",
  )
  let repeated = Migration::new(
    name="repeated",
    from_version="1",
    to_version="2",
    operations=[
      Replace(p("/version"), Number(2.0)),
      Increment(p("/version"), 1.0),
    ],
  )
  inspect(preflight(repeated).warnings.length(), content="1")
}
