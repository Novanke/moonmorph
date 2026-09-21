///|
fn diff_document() -> Value {
  Object([
    ("version", Number(1.0)),
    (
      "service",
      Object([("host", String("localhost")), ("port", Number(8080.0))]),
    ),
    ("features", Array([String("search"), String("export")])),
    ("legacy", Bool(true)),
  ])
}

///|
test "synthesized migration reaches the exact target and rolls back" {
  let source = diff_document()
  let target : Value = Object([
    ("version", Number(2.0)),
    (
      "service",
      Object([
        ("host", String("localhost")),
        ("port", Number(8081.0)),
        ("tls", Bool(true)),
      ]),
    ),
    ("features", Array([String("search"), String("audit"), String("offline")])),
  ])
  let migration = synthesize_migration(
    name="generated-v2",
    from_version="1",
    to_version="2",
    source~,
    target~,
  )
  inspect(migration.operations.length(), content="6")
  inspect(detect_conflicts(migration).length(), content="0")
  let result = apply(migration, source).unwrap()
  inspect(result.value == target, content="true")
  inspect(apply_rollback(result).unwrap().value == source, content="true")
}

///|
test "object reorder falls back to one deterministic parent replacement" {
  let source : Value = Object([
    ("meta", Object([("a", Number(1.0)), ("b", Number(2.0))])),
  ])
  let target : Value = Object([
    ("meta", Object([("b", Number(2.0)), ("a", Number(1.0))])),
  ])
  let operations = diff_values(source, target)
  inspect(operations.length(), content="1")
  guard operations[0] is Replace(path, _) else {
    fail("expected a parent replacement")
  }
  inspect(path.to_string(), content="/meta")
}

///|
test "diff escapes object keys through typed paths" {
  let source : Value = Object([("a/b", Number(1.0)), ("~meta", Bool(false))])
  let target : Value = Object([("a/b", Number(2.0)), ("~meta", Bool(true))])
  let operations = diff_values(source, target)
  guard operations[0] is Replace(first, _) else {
    fail("expected a replacement")
  }
  guard operations[1] is Replace(second, _) else {
    fail("expected a replacement")
  }
  inspect(first.to_string(), content="/a~1b")
  inspect(second.to_string(), content="/~0meta")
  inspect(
    apply(
      Migration::new(
        name="escaped",
        from_version="1",
        to_version="2",
        operations~,
      ),
      source,
    ).unwrap().value ==
    target,
    content="true",
  )
}

///|
test "equal values synthesize an empty plan" {
  let source = diff_document()
  inspect(diff_values(source, source).length(), content="0")
}

///|
test "array shrink removes the tail from the end" {
  let source : Value = Array([
    String("a"),
    String("b"),
    String("c"),
    String("d"),
  ])
  let target : Value = Array([String("a"), String("x")])
  let operations = diff_values(source, target)
  inspect(operations.length(), content="3")
  guard operations[1] is Remove(first_removed) else {
    fail("expected a tail removal")
  }
  guard operations[2] is Remove(second_removed) else {
    fail("expected a tail removal")
  }
  inspect(first_removed.to_string(), content="/3")
  inspect(second_removed.to_string(), content="/2")
  let migration = Migration::new(
    name="shrink",
    from_version="1",
    to_version="2",
    operations~,
  )
  inspect(apply(migration, source).unwrap().value == target, content="true")
}
