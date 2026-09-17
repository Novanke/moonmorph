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
fn operation_to_json(operation : Operation) -> Json {
  let object : Map[String, Json] = Map([])
  match operation {
    Add(path, value) => {
      object["op"] = Json::string("add")
      object["path"] = Json::string(path.to_string())
      object["value"] = value.to_json()
    }
    Replace(path, value) => {
      object["op"] = Json::string("replace")
      object["path"] = Json::string(path.to_string())
      object["value"] = value.to_json()
    }
    Remove(path) => {
      object["op"] = Json::string("remove")
      object["path"] = Json::string(path.to_string())
    }
    Copy(from, path) => {
      object["op"] = Json::string("copy")
      object["from"] = Json::string(from.to_string())
      object["path"] = Json::string(path.to_string())
    }
    Move(from, path) => {
      object["op"] = Json::string("move")
      object["from"] = Json::string(from.to_string())
      object["path"] = Json::string(path.to_string())
    }
    Test(path, value) => {
      object["op"] = Json::string("test")
      object["path"] = Json::string(path.to_string())
      object["value"] = value.to_json()
    }
    Increment(path, delta) => {
      object["op"] = Json::string("increment")
      object["path"] = Json::string(path.to_string())
      object["delta"] = Json::number(delta)
    }
    Rename(path, from, to) => {
      object["op"] = Json::string("rename")
      object["path"] = Json::string(path.to_string())
      object["from"] = Json::string(from)
      object["to"] = Json::string(to)
    }
  }
  Json::object(object)
}

///|
/// Convert a typed migration back to its portable declarative JSON form.
/// Generated rollback plans can be serialized with the same method.
pub fn Migration::to_json(self : Migration) -> Json {
  let object : Map[String, Json] = Map([])
  object["name"] = Json::string(self.name)
  object["from"] = Json::string(self.from_version)
  object["to"] = Json::string(self.to_version)
  object["operations"] = Json::array(self.operations.map(operation_to_json))
  Json::object(object)
}

///|
/// Serialize a migration as compact JSON.
pub fn Migration::to_json_string(self : Migration) -> String {
  self.to_json().stringify()
}

///|
/// Convert an execution error to a stable machine-readable object.
pub fn MigrationError::to_json(self : MigrationError) -> Json {
  let object : Map[String, Json] = Map([])
  object["code"] = Json::string(self.code.label())
  object["operation_index"] = Json::number(self.operation_index.to_double())
  object["path"] = Json::string(self.path)
  object["message"] = Json::string(self.message)
  Json::object(object)
}

///|
pub fn MigrationError::to_json_string(self : MigrationError) -> String {
  self.to_json().stringify()
}

///|
/// Convert static plan diagnostics to a JSON object for CI and host tooling.
pub fn PreflightReport::to_json(self : PreflightReport) -> Json {
  let object : Map[String, Json] = Map([])
  object["valid"] = Json::boolean(self.is_valid())
  object["errors"] = Json::array(self.errors.map(Json::string))
  object["warnings"] = Json::array(self.warnings.map(Json::string))
  Json::object(object)
}

///|
pub fn PreflightReport::to_json_string(self : PreflightReport) -> String {
  self.to_json().stringify()
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
