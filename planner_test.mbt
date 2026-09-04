///|
fn version_step(from : String, to : String, next_value : Double) -> Migration {
  Migration::new(name=from + "-to-" + to, from_version=from, to_version=to, operations=[
    Replace(p("/version"), Number(next_value)),
  ])
}

///|
test "planner picks the shortest deterministic route" {
  let catalog = [
    version_step("1", "2", 2.0),
    version_step("2", "3", 3.0),
    version_step("1", "1.5", 1.5),
    version_step("1.5", "2", 2.0),
  ]
  let route = plan_route(catalog, "1", "3").unwrap()
  inspect(route.operations.length(), content="2")
  inspect(route.name, content="route:1-to-2 -> 2-to-3")
  let result = apply(route, Object([("version", Number(1.0))])).unwrap()
  inspect(result.value.to_json_string(), content="{\"version\":3}")
}

///|
test "planner handles identity and unreachable versions" {
  let catalog = [version_step("1", "2", 2.0)]
  inspect(
    plan_route(catalog, "1", "1").unwrap().operations.length(),
    content="0",
  )
  match plan_route(catalog, "2", "9") {
    Err(message) =>
      inspect(message, content="no migration route from '2' to '9'")
    Ok(_) => fail("expected an unreachable route")
  }
}

///|
test "catalog validation and reachability" {
  let catalog = [
    version_step("1", "2", 2.0),
    version_step("1", "2", 2.0),
    Migration::new(name="loop", from_version="2", to_version="2", operations=[]),
  ]
  inspect(validate_catalog(catalog).length(), content="2")
  inspect(reachable_versions(catalog, "1").join(","), content="1,2")
}
