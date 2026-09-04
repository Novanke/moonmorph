///|
/// Convert a standard MoonBit JSON value into MoonMorph's ordered value model.
pub fn Value::from_json(json : Json) -> Value {
  match json {
    Json::Null => Null
    Json::True => Bool(true)
    Json::False => Bool(false)
    Json::Number(number, ..) => Number(number)
    Json::String(value) => String(value)
    Json::Array(values) => Array(values.map(Value::from_json))
    Json::Object(values) => {
      let entries : Array[(String, Value)] = []
      for key, value in values {
        entries.push((key, Value::from_json(value)))
      }
      Object(entries)
    }
  }
}

///|
/// Convert a MoonMorph value back to the standard MoonBit JSON representation.
pub fn Value::to_json(self : Value) -> Json {
  match self {
    Null => Json::null()
    Bool(value) => Json::boolean(value)
    Number(value) => Json::number(value)
    String(value) => Json::string(value)
    Array(values) => Json::array(values.map(value => value.to_json()))
    Object(entries) => {
      let object : Map[String, Json] = Map([])
      for entry in entries {
        object[entry.0] = entry.1.to_json()
      }
      Json::object(object)
    }
  }
}

///|
pub fn parse_value(text : String) -> Result[Value, String] {
  Ok(Value::from_json(@json.parse(text))) catch {
    _ => Err("invalid JSON document")
  }
}

///|
fn required_string(
  object : Map[String, Json],
  key : String,
) -> Result[String, String] {
  match object.get(key) {
    Some(Json::String(value)) => Ok(value)
    Some(_) => Err("field '" + key + "' must be a string")
    None => Err("missing required field '" + key + "'")
  }
}

///|
fn required_value(
  object : Map[String, Json],
  key : String,
) -> Result[Value, String] {
  match object.get(key) {
    Some(value) => Ok(Value::from_json(value))
    None => Err("missing required field '" + key + "'")
  }
}

///|
fn path_from_text(text : String) -> Result[Path, String] {
  match Path::parse(text) {
    Ok(path) => Ok(path)
    Err(error) => Err(error.message)
  }
}

///|
fn parse_operation(json : Json) -> Result[Operation, String] {
  guard json is Json::Object(object) else {
    return Err("each operation must be an object")
  }
  let op = match required_string(object, "op") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let path_text = match required_string(object, "path") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let path = match path_from_text(path_text) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match op {
    "add" =>
      match required_value(object, "value") {
        Ok(value) => Ok(Add(path, value))
        Err(error) => Err(error)
      }
    "replace" =>
      match required_value(object, "value") {
        Ok(value) => Ok(Replace(path, value))
        Err(error) => Err(error)
      }
    "remove" => Ok(Remove(path))
    "test" =>
      match required_value(object, "value") {
        Ok(value) => Ok(Test(path, value))
        Err(error) => Err(error)
      }
    "increment" =>
      match object.get("delta") {
        Some(Json::Number(delta, ..)) => Ok(Increment(path, delta))
        Some(_) => Err("field 'delta' must be a number")
        None => Err("missing required field 'delta'")
      }
    "rename" => {
      let from = match required_string(object, "from") {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let to = match required_string(object, "to") {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      Ok(Rename(path, from, to))
    }
    "copy" | "move" => {
      let from_text = match required_string(object, "from") {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let from = match path_from_text(from_text) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      if op == "copy" {
        Ok(Copy(from, path))
      } else {
        Ok(Move(from, path))
      }
    }
    _ => Err("unsupported operation '" + op + "'")
  }
}

///|
/// Parse a declarative migration specification from JSON.
pub fn parse_migration(text : String) -> Result[Migration, String] {
  let json = @json.parse(text) catch {
    _ => return Err("invalid migration JSON")
  }
  guard json is Json::Object(object) else {
    return Err("migration must be an object")
  }
  let name = match required_string(object, "name") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let from_version = match required_string(object, "from") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let to_version = match required_string(object, "to") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let operation_json = match object.get("operations") {
    Some(Json::Array(values)) => values
    Some(_) => return Err("field 'operations' must be an array")
    None => return Err("missing required field 'operations'")
  }
  let operations : Array[Operation] = []
  for index, item in operation_json {
    match parse_operation(item) {
      Ok(operation) => operations.push(operation)
      Err(error) => return Err("operation " + index.to_string() + ": " + error)
    }
  }
  Ok(Migration::new(name~, from_version~, to_version~, operations~))
}
