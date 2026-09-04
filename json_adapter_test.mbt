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
