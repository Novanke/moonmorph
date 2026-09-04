///|
fn string_in(values : Array[String], target : String) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
}

///|
/// Validate a catalog before it is exposed to a migration service.
pub fn validate_catalog(migrations : Array[Migration]) -> Array[String] {
  let problems : Array[String] = []
  for i, migration in migrations {
    if migration.name.trim().is_empty() {
      problems.push("migration " + i.to_string() + " has an empty name")
    }
    if migration.from_version == migration.to_version {
      problems.push(
        "migration '" +
        migration.name +
        "' has identical source and target versions",
      )
    }
    for j in (i + 1)..<migrations.length() {
      if migration.from_version == migrations[j].from_version &&
        migration.to_version == migrations[j].to_version {
        problems.push(
          "duplicate edge " +
          migration.from_version +
          " -> " +
          migration.to_version,
        )
      }
    }
  }
  problems
}

///|
/// Find the shortest deterministic route between two schema versions.
/// Catalog order breaks ties, making planning reproducible across backends.
pub fn plan_route(
  migrations : Array[Migration],
  from_version : String,
  to_version : String,
) -> Result[Migration, String] {
  if from_version == to_version {
    return Ok(
      Migration::new(
        name="identity:" + from_version,
        from_version~,
        to_version~,
        operations=[],
      ),
    )
  }
  let versions : Array[String] = [from_version]
  let routes : Array[Array[Int]] = [[]]
  let mut cursor = 0
  while cursor < versions.length() {
    let current = versions[cursor]
    let route = routes[cursor]
    for edge_index, migration in migrations {
      if migration.from_version != current ||
        string_in(versions, migration.to_version) {
        continue
      }
      let next_route = [..route, edge_index]
      if migration.to_version == to_version {
        let operations : Array[Operation] = []
        let names : Array[String] = []
        for selected in next_route {
          names.push(migrations[selected].name)
          for operation in migrations[selected].operations {
            operations.push(operation)
          }
        }
        return Ok(
          Migration::new(
            name="route:" + names.join(" -> "),
            from_version~,
            to_version~,
            operations~,
          ),
        )
      }
      versions.push(migration.to_version)
      routes.push(next_route)
    }
    cursor = cursor + 1
  }
  Err("no migration route from '" + from_version + "' to '" + to_version + "'")
}

///|
/// Return versions reachable from a starting point, in deterministic BFS order.
pub fn reachable_versions(
  migrations : Array[Migration],
  from_version : String,
) -> Array[String] {
  let versions : Array[String] = [from_version]
  let mut cursor = 0
  while cursor < versions.length() {
    let current = versions[cursor]
    for migration in migrations {
      if migration.from_version == current &&
        !string_in(versions, migration.to_version) {
        versions.push(migration.to_version)
      }
    }
    cursor = cursor + 1
  }
  versions
}
