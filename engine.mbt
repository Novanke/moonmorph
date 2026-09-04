///|
fn migration_error(
  code : ErrorCode,
  path : Path,
  message : String,
) -> MigrationError {
  { code, operation_index: -1, path: path.to_string(), message, }
}

///|
fn value_at_depth(
  value : Value,
  segments : Array[Segment],
  depth : Int,
  full_path : Path,
) -> Result[Value, MigrationError] {
  if depth == segments.length() {
    return Ok(value.deep_copy())
  }
  match (value, segments[depth]) {
    (Object(entries), segment) => {
      let key = match segment {
        Key(value) => value
        Index(value) => value.to_string()
        Append => "-"
      }
      match object_index(entries, key) {
        Some(index) =>
          value_at_depth(entries[index].1, segments, depth + 1, full_path)
        None =>
          Err(migration_error(NotFound, full_path, "object key not found"))
      }
    }
    (Array(values), Index(index)) =>
      if index < 0 || index >= values.length() {
        Err(
          migration_error(
            IndexOutOfBounds,
            full_path,
            "array index is out of bounds",
          ),
        )
      } else {
        value_at_depth(values[index], segments, depth + 1, full_path)
      }
    (Array(_), Append) =>
      Err(
        migration_error(
          InvalidPath,
          full_path,
          "'-' is only valid for a final add segment",
        ),
      )
    (Array(_), _) =>
      Err(
        migration_error(
          TypeMismatch,
          full_path,
          "array paths require an index segment",
        ),
      )
    _ =>
      Err(
        migration_error(
          TypeMismatch,
          full_path,
          "cannot descend through a scalar value",
        ),
      )
  }
}

///|
pub fn get(value : Value, path : Path) -> Result[Value, MigrationError] {
  value_at_depth(value, path.segments(), 0, path)
}

///|
fn array_insert(
  values : Array[Value],
  index : Int,
  value : Value,
) -> Array[Value] {
  let out : Array[Value] = []
  for i in 0..<(values.length() + 1) {
    if i == index {
      out.push(value.deep_copy())
    }
    if i < values.length() {
      out.push(values[i].deep_copy())
    }
  }
  out
}

///|
fn array_remove(values : Array[Value], index : Int) -> Array[Value] {
  let out : Array[Value] = []
  for i, value in values {
    if i != index {
      out.push(value.deep_copy())
    }
  }
  out
}

///|
fn update_at_depth(
  current : Value,
  segments : Array[Segment],
  depth : Int,
  replacement : Value,
  mode : String,
  full_path : Path,
) -> Result[Value, MigrationError] {
  if depth == segments.length() {
    if mode == "remove" {
      return Err(
        migration_error(
          InvalidPath,
          full_path,
          "the document root cannot be removed",
        ),
      )
    }
    return Ok(replacement.deep_copy())
  }
  let final_segment = depth + 1 == segments.length()
  match (current, segments[depth]) {
    (Object(entries), segment) => {
      let key = match segment {
        Key(value) => value
        Index(value) => value.to_string()
        Append => "-"
      }
      let index = object_index(entries, key)
      if final_segment {
        match mode {
          "add" => {
            let out = entries.map(entry => (entry.0, entry.1.deep_copy()))
            match index {
              Some(i) => out[i] = (key, replacement.deep_copy())
              None => out.push((key, replacement.deep_copy()))
            }
            Ok(Object(out))
          }
          "replace" =>
            match index {
              Some(i) => {
                let out = entries.map(entry => (entry.0, entry.1.deep_copy()))
                out[i] = (key, replacement.deep_copy())
                Ok(Object(out))
              }
              None =>
                Err(
                  migration_error(NotFound, full_path, "object key not found"),
                )
            }
          "remove" =>
            match index {
              Some(i) => {
                let out : Array[(String, Value)] = []
                for j, entry in entries {
                  if i != j {
                    out.push((entry.0, entry.1.deep_copy()))
                  }
                }
                Ok(Object(out))
              }
              None =>
                Err(
                  migration_error(NotFound, full_path, "object key not found"),
                )
            }
          _ => Err(migration_error(Conflict, full_path, "unknown update mode"))
        }
      } else {
        match index {
          Some(i) => {
            let next = update_at_depth(
              entries[i].1,
              segments,
              depth + 1,
              replacement,
              mode,
              full_path,
            )
            match next {
              Ok(updated) => {
                let out = entries.map(entry => (entry.0, entry.1.deep_copy()))
                out[i] = (key, updated)
                Ok(Object(out))
              }
              Err(error) => Err(error)
            }
          }
          None =>
            Err(migration_error(NotFound, full_path, "object key not found"))
        }
      }
    }
    (Array(values), Index(index)) =>
      if final_segment {
        match mode {
          "add" =>
            if index < 0 || index > values.length() {
              Err(
                migration_error(
                  IndexOutOfBounds,
                  full_path,
                  "array insertion index is out of bounds",
                ),
              )
            } else {
              Ok(Array(array_insert(values, index, replacement)))
            }
          "replace" =>
            if index < 0 || index >= values.length() {
              Err(
                migration_error(
                  IndexOutOfBounds,
                  full_path,
                  "array index is out of bounds",
                ),
              )
            } else {
              let out = values.map(value => value.deep_copy())
              out[index] = replacement.deep_copy()
              Ok(Array(out))
            }
          "remove" =>
            if index < 0 || index >= values.length() {
              Err(
                migration_error(
                  IndexOutOfBounds,
                  full_path,
                  "array index is out of bounds",
                ),
              )
            } else {
              Ok(Array(array_remove(values, index)))
            }
          _ => Err(migration_error(Conflict, full_path, "unknown update mode"))
        }
      } else if index < 0 || index >= values.length() {
        Err(
          migration_error(
            IndexOutOfBounds,
            full_path,
            "array index is out of bounds",
          ),
        )
      } else {
        match
          update_at_depth(
            values[index],
            segments,
            depth + 1,
            replacement,
            mode,
            full_path,
          ) {
          Ok(updated) => {
            let out = values.map(value => value.deep_copy())
            out[index] = updated
            Ok(Array(out))
          }
          Err(error) => Err(error)
        }
      }
    (Array(values), Append) if final_segment && mode == "add" => {
      let out = values.map(value => value.deep_copy())
      out.push(replacement.deep_copy())
      Ok(Array(out))
    }
    (Array(_), Append) =>
      Err(
        migration_error(
          InvalidPath,
          full_path,
          "'-' is only valid for a final add segment",
        ),
      )
    (Array(_), _) =>
      Err(
        migration_error(
          TypeMismatch,
          full_path,
          "array paths require an index segment",
        ),
      )
    _ =>
      Err(
        migration_error(
          TypeMismatch,
          full_path,
          "cannot descend through a scalar value",
        ),
      )
  }
}

///|
fn add(
  value : Value,
  path : Path,
  replacement : Value,
) -> Result[Value, MigrationError] {
  update_at_depth(value, path.segments(), 0, replacement, "add", path)
}

///|
fn replace(
  value : Value,
  path : Path,
  replacement : Value,
) -> Result[Value, MigrationError] {
  update_at_depth(value, path.segments(), 0, replacement, "replace", path)
}

///|
fn remove(value : Value, path : Path) -> Result[Value, MigrationError] {
  update_at_depth(value, path.segments(), 0, Null, "remove", path)
}

///|
fn operation_path(operation : Operation) -> Path {
  match operation {
    Add(path, _)
    | Replace(path, _)
    | Remove(path)
    | Test(path, _)
    | Increment(path, _) => path
    Copy(_, destination) | Move(_, destination) => destination
    Rename(parent, _, _) => parent
  }
}

///|
fn operation_summary(operation : Operation) -> String {
  match operation {
    Add(path, _) => "add " + path.to_string()
    Replace(path, _) => "replace " + path.to_string()
    Remove(path) => "remove " + path.to_string()
    Copy(source, destination) =>
      "copy " + source.to_string() + " -> " + destination.to_string()
    Move(source, destination) =>
      "move " + source.to_string() + " -> " + destination.to_string()
    Test(path, _) => "test " + path.to_string()
    Increment(path, delta) =>
      "increment " + path.to_string() + " by " + delta.to_string()
    Rename(parent, from, to) =>
      "rename " +
      parent.child_key(from).to_string() +
      " -> " +
      parent.child_key(to).to_string()
  }
}

///|
fn apply_one(
  value : Value,
  operation : Operation,
) -> Result[Value, MigrationError] {
  match operation {
    Add(path, replacement) => add(value, path, replacement)
    Replace(path, replacement) => replace(value, path, replacement)
    Remove(path) => remove(value, path)
    Test(path, expected) =>
      match get(value, path) {
        Ok(actual) =>
          if actual == expected {
            Ok(value.deep_copy())
          } else {
            Err(
              migration_error(
                TestFailed,
                path,
                "test precondition did not match",
              ),
            )
          }
        Err(error) => Err(error)
      }
    Increment(path, delta) =>
      match get(value, path) {
        Ok(Number(number)) => replace(value, path, Number(number + delta))
        Ok(_) =>
          Err(
            migration_error(TypeMismatch, path, "increment requires a number"),
          )
        Err(error) => Err(error)
      }
    Rename(parent, from, to) => {
      let source = parent.child_key(from)
      let destination = parent.child_key(to)
      match get(value, destination) {
        Ok(_) =>
          Err(
            migration_error(
              AlreadyExists,
              destination,
              "rename destination already exists",
            ),
          )
        Err({ code: NotFound, .. }) =>
          match get(value, source) {
            Ok(found) =>
              match remove(value, source) {
                Ok(without_source) => add(without_source, destination, found)
                Err(error) => Err(error)
              }
            Err(error) => Err(error)
          }
        Err(error) => Err(error)
      }
    }
    Copy(source, destination) =>
      match get(value, source) {
        Ok(found) => add(value, destination, found)
        Err(error) => Err(error)
      }
    Move(source, destination) =>
      match get(value, source) {
        Ok(found) =>
          match remove(value, source) {
            Ok(without_source) => add(without_source, destination, found)
            Err(error) => Err(error)
          }
        Err(error) => Err(error)
      }
  }
}

///|
pub fn apply(
  migration : Migration,
  input : Value,
) -> Result[MigrationResult, MigrationError] {
  let mut current = input.deep_copy()
  let journal : Array[JournalEntry] = []
  let inverses : Array[Operation] = []
  for index, operation in migration.operations {
    let before = current.deep_copy()
    match apply_one(current, operation) {
      Ok(updated) => {
        current = updated
        let inverse = Replace(Path::root(), before)
        inverses.push(inverse)
        journal.push({
          operation_index: index,
          summary: operation_summary(operation),
          inverse: Some(inverse),
        })
      }
      Err(error) => return Err({ ..error, operation_index: index, })
    }
  }
  let rollback_operations : Array[Operation] = []
  for i = inverses.length() - 1; i >= 0; i = i - 1 {
    rollback_operations.push(inverses[i])
  }
  Ok({
    value: current,
    journal,
    rollback: Some(
      Migration::new(
        name="rollback:" + migration.name,
        from_version=migration.to_version,
        to_version=migration.from_version,
        operations=rollback_operations,
      ),
    ),
  })
}

///|
pub fn apply_rollback(
  result : MigrationResult,
) -> Result[MigrationResult, MigrationError] {
  match result.rollback {
    Some(rollback) => apply(rollback, result.value)
    None =>
      Err(
        migration_error(
          NonReversible,
          Path::root(),
          "migration has no rollback plan",
        ),
      )
  }
}

///|
pub fn dry_run(migration : Migration) -> Array[String] {
  migration.operations.map(operation_summary)
}

///|
pub fn detect_conflicts(migration : Migration) -> Array[String] {
  let conflicts : Array[String] = []
  for i, left in migration.operations {
    if left is Test(_, _) {
      continue
    }
    let left_path = operation_path(left).to_string()
    for j in (i + 1)..<migration.operations.length() {
      let right = migration.operations[j]
      if right is Test(_, _) {
        continue
      }
      let right_path = operation_path(right).to_string()
      if left_path == right_path {
        conflicts.push(
          "operations " +
          i.to_string() +
          " and " +
          j.to_string() +
          " both write " +
          left_path,
        )
      }
    }
  }
  conflicts
}
