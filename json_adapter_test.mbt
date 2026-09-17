///|
test "JSON adapter roundtrip" {
  let input = "{\"z\":null,\"ok\":true,\"items\":[1,\"two\"]}"
  let value = parse_value(input).unwrap()
  inspect(value.to_json().stringify(), content=input)
}

///|
test "parse declarative migration" {
  let spec =
    #|{
    #|  "name":"upgrade",
    #|  "from":"1",
    #|  "to":"2",
    #|  "operations":[
    #|    {"op":"test","path":"/version","value":1},
    #|    {"op":"replace","path":"/version","value":2},
    #|    {"op":"rename","path":"/service","from":"host","to":"hostname"}
    #|  ]
    #|}
  let migration = parse_migration(spec).unwrap()
  inspect(migration.operations.length(), content="3")
  inspect(
    dry_run(migration)[2],
    content="rename /service/host -> /service/hostname",
  )
}

///|
test "parser reports operation index" {
  let spec =
    #|{"name":"bad","from":"1","to":"2","operations":[{"op":"increment","path":"/x","delta":"many"}]}
  match parse_migration(spec) {
    Err(message) =>
      inspect(message, content="operation 0: field 'delta' must be a number")
    Ok(_) => fail("expected an invalid delta error")
  }
}

///|
test "migration JSON serialization preserves every operation" {
  let original = Migration::new(
    name="all-operations",
    from_version="1",
    to_version="2",
    operations=[
      Test(Path::parse("/version").unwrap(), Number(1.0)),
      Add(Path::parse("/enabled").unwrap(), Bool(true)),
      Replace(Path::parse("/version").unwrap(), Number(2.0)),
      Remove(Path::parse("/legacy").unwrap()),
      Copy(
        Path::parse("/profile/name").unwrap(),
        Path::parse("/display_name").unwrap(),
      ),
      Move(Path::parse("/old").unwrap(), Path::parse("/new").unwrap()),
      Increment(Path::parse("/quota").unwrap(), 2.5),
      Rename(Path::parse("/profile").unwrap(), "name", "full_name"),
    ],
  )
  let encoded = original.to_json_string()
  let decoded = parse_migration(encoded).unwrap()
  inspect(decoded == original, content="true")
}

///|
test "generated rollback plan is portable JSON" {
  let document : Value = Object([("version", Number(1.0))])
  let migration = Migration::new(
    name="upgrade",
    from_version="1",
    to_version="2",
    operations=[Replace(Path::parse("/version").unwrap(), Number(2.0))],
  )
  let result = apply(migration, document).unwrap()
  guard result.rollback is Some(rollback) else {
    fail("expected rollback plan")
  }
  let portable = parse_migration(rollback.to_json_string()).unwrap()
  let restored = apply(portable, result.value).unwrap()
  inspect(restored.value.to_json_string(), content="{\"version\":1}")
}

///|
test "execution errors have stable JSON codes" {
  let document : Value = Object([])
  let migration = Migration::new(
    name="missing",
    from_version="1",
    to_version="2",
    operations=[Remove(Path::parse("/missing").unwrap())],
  )
  guard apply(migration, document) is Err(error) else {
    fail("expected missing path error")
  }
  inspect(
    error.to_json_string(),
    content="{\"code\":\"not_found\",\"operation_index\":0,\"path\":\"/missing\",\"message\":\"object key not found\"}",
  )
}

///|
test "preflight reports serialize for CI" {
  let migration = Migration::new(name="", from_version="1", to_version="1", operations=[])
  let report = preflight(migration)
  let json = report.to_json()
  guard json is Json::Object(object) else { fail("expected diagnostic object") }
  inspect(object["valid"] == Json::boolean(false), content="true")
  guard object["errors"] is Json::Array(errors) else {
    fail("expected error array")
  }
  inspect(errors.length(), content="2")
  guard object["warnings"] is Json::Array(warnings) else {
    fail("expected warning array")
  }
  inspect(warnings.length(), content="1")
}
