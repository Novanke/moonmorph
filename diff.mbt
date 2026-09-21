///|
fn entry_value(entries : Array[(String, Value)], key : String) -> Value? {
  for entry in entries {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
fn common_keys(
  entries : Array[(String, Value)],
  other : Array[(String, Value)],
) -> Array[String] {
  let keys : Array[String] = []
  for entry in entries {
    if entry_value(other, entry.0) is Some(_) {
      keys.push(entry.0)
    }
  }
  keys
}

///|
fn added_keys_are_suffix(
  source : Array[(String, Value)],
  target : Array[(String, Value)],
) -> Bool {
  let mut saw_added_key = false
  for entry in target {
    if entry_value(source, entry.0) is Some(_) {
      if saw_added_key {
        return false
      }
    } else {
      saw_added_key = true
    }
  }
  true
}

///|
fn can_patch_object(
  source : Array[(String, Value)],
  target : Array[(String, Value)],
) -> Bool {
  common_keys(source, target) == common_keys(target, source) &&
  added_keys_are_suffix(source, target)
}

///|
fn diff_into(
  path : Path,
  source : Value,
  target : Value,
  operations : Array[Operation],
) -> Unit {
  if source == target {
    return
  }
  match (source, target) {
    (Object(source_entries), Object(target_entries)) => {
      if !can_patch_object(source_entries, target_entries) {
        operations.push(Replace(path, Object(target_entries).deep_copy()))
        return
      }
      for entry in source_entries {
        if entry_value(target_entries, entry.0) is None {
          operations.push(Remove(path.child_key(entry.0)))
        }
      }
      for entry in target_entries {
        match entry_value(source_entries, entry.0) {
          Some(previous) =>
            diff_into(path.child_key(entry.0), previous, entry.1, operations)
          None =>
            operations.push(Add(path.child_key(entry.0), entry.1.deep_copy()))
        }
      }
    }
    (Array(source_values), Array(target_values)) => {
      let common_length = if source_values.length() < target_values.length() {
        source_values.length()
      } else {
        target_values.length()
      }
      for index in 0..<common_length {
        diff_into(
          path.child_index(index),
          source_values[index],
          target_values[index],
          operations,
        )
      }
      let mut remove_index = source_values.length() - 1
      while remove_index >= target_values.length() {
        operations.push(Remove(path.child_index(remove_index)))
        remove_index = remove_index - 1
      }
      for index in common_length..<target_values.length() {
        operations.push(
          Add(path.child_index(index), target_values[index].deep_copy()),
        )
      }
    }
    _ => operations.push(Replace(path, target.deep_copy()))
  }
}

///|
/// Build a deterministic operation list that transforms `source` into `target`.
/// Nested objects and arrays are patched when their order can be preserved.
/// A parent replacement is used when an object-key reorder cannot be represented
/// without noisy remove/add churn.
pub fn diff_values(source : Value, target : Value) -> Array[Operation] {
  let operations : Array[Operation] = []
  diff_into(Path::root(), source, target, operations)
  operations
}

///|
/// Create a portable migration by comparing two JSON-like values.
pub fn synthesize_migration(
  name~ : String,
  from_version~ : String,
  to_version~ : String,
  source~ : Value,
  target~ : Value,
) -> Migration {
  Migration::new(
    name~,
    from_version~,
    to_version~,
    operations=diff_values(source, target),
  )
}
