///|
pub fn Value::deep_copy(self : Value) -> Value {
  match self {
    Null => Null
    Bool(value) => Bool(value)
    Number(value) => Number(value)
    String(value) => String(value)
    Array(values) => Array(values.map(value => value.deep_copy()))
    Object(entries) =>
      Object(entries.map(entry => (entry.0, entry.1.deep_copy())))
  }
}

///|
fn object_index(entries : Array[(String, Value)], key : String) -> Int? {
  for i, entry in entries {
    if entry.0 == key {
      return Some(i)
    }
  }
  None
}

///|
pub fn Value::get_key(self : Value, key : String) -> Value? {
  match self {
    Object(entries) =>
      match object_index(entries, key) {
        Some(index) => Some(entries[index].1.deep_copy())
        None => None
      }
    _ => None
  }
}

///|
pub fn Value::get_index(self : Value, index : Int) -> Value? {
  match self {
    Array(values) if index >= 0 && index < values.length() =>
      Some(values[index].deep_copy())
    _ => None
  }
}

///|
fn escape_json_string(value : String) -> String {
  let out = StringBuilder()
  out.write_char('"')
  for ch in value {
    match ch {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      _ => out.write_char(ch)
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
pub fn Value::to_json_string(self : Value) -> String {
  match self {
    Null => "null"
    Bool(true) => "true"
    Bool(false) => "false"
    Number(value) => value.to_string()
    String(value) => escape_json_string(value)
    Array(values) => {
      let rendered = values.map(value => value.to_json_string())
      "[" + rendered.join(",") + "]"
    }
    Object(entries) => {
      let rendered = entries.map(entry => {
        escape_json_string(entry.0) + ":" + entry.1.to_json_string()
      })
      "{" + rendered.join(",") + "}"
    }
  }
}
