///|
fn demo_document() -> String {
  (
    #|{"version":1,"service":{"host":"localhost","port":8080},"features":["search","export"]}
  )
}

///|
fn demo_migration() -> String {
  (
    #|{
    #|  "name":"service-v1-to-v2",
    #|  "from":"1",
    #|  "to":"2",
    #|  "operations":[
    #|    {"op":"test","path":"/version","value":1},
    #|    {"op":"replace","path":"/version","value":2},
    #|    {"op":"rename","path":"/service","from":"host","to":"hostname"},
    #|    {"op":"increment","path":"/service/port","delta":1},
    #|    {"op":"add","path":"/features/-","value":"audit"}
    #|  ]
    #|}
  )
}

///|
fn run_apply(document_text : String, migration_text : String) -> Unit {
  let document = match @moonmorph.parse_value(document_text) {
    Ok(value) => value
    Err(message) => {
      println("DOCUMENT_ERROR " + message)
      return
    }
  }
  let migration = match @moonmorph.parse_migration(migration_text) {
    Ok(value) => value
    Err(message) => {
      println("SPEC_ERROR " + message)
      return
    }
  }
  let report = @moonmorph.preflight(migration)
  for warning in report.warnings {
    println("PREFLIGHT_WARNING " + warning)
  }
  if !report.is_valid() {
    for error in report.errors {
      println("PREFLIGHT_ERROR " + error)
    }
    return
  }
  match @moonmorph.apply(migration, document) {
    Ok(result) => {
      println(result.value.to_json().stringify())
      println("JOURNAL")
      for entry in result.journal {
        println("  " + entry.operation_index.to_string() + ": " + entry.summary)
      }
      match @moonmorph.apply_rollback(result) {
        Ok(rolled_back) =>
          println(
            "ROLLBACK_VERIFIED " + (rolled_back.value == document).to_string(),
          )
        Err(error) => println("ROLLBACK_ERROR " + error.message)
      }
    }
    Err(error) =>
      println(
        "MIGRATION_ERROR operation=" +
        error.operation_index.to_string() +
        " code=" +
        error.code.label() +
        " path=" +
        error.path +
        " message=" +
        error.message,
      )
  }
}

///|
fn run_diff(source_text : String, target_text : String) -> Unit {
  let source = match @moonmorph.parse_value(source_text) {
    Ok(value) => value
    Err(message) => {
      println("SOURCE_ERROR " + message)
      return
    }
  }
  let target = match @moonmorph.parse_value(target_text) {
    Ok(value) => value
    Err(message) => {
      println("TARGET_ERROR " + message)
      return
    }
  }
  let migration = @moonmorph.synthesize_migration(
    name="generated-diff",
    from_version="source",
    to_version="target",
    source~,
    target~,
  )
  println(migration.to_json_string())
  match @moonmorph.apply(migration, source) {
    Ok(result) =>
      println("DIFF_VERIFIED " + (result.value == target).to_string())
    Err(error) => println("DIFF_ERROR " + error.to_json_string())
  }
}

///|
fn print_help() -> Unit {
  println("MoonMorph — atomic, reversible JSON migrations")
  println("Usage:")
  println("  moon run cmd/main -- demo")
  println("  moon run cmd/main -- apply '<document-json>' '<migration-json>'")
  println("  moon run cmd/main -- dry-run '<migration-json>'")
  println("  moon run cmd/main -- diff '<source-json>' '<target-json>'")
}

///|
fn main {
  let args = @env.args()
  let mut command_index = -1
  for i, arg in args {
    if arg == "demo" || arg == "apply" || arg == "dry-run" || arg == "diff" {
      command_index = i
      break
    }
  }
  if command_index < 0 || args[command_index] == "demo" {
    run_apply(demo_document(), demo_migration())
    return
  }
  match args[command_index] {
    "apply" if args.length() == command_index + 3 =>
      run_apply(args[command_index + 1], args[command_index + 2])
    "dry-run" if args.length() == command_index + 2 =>
      match @moonmorph.parse_migration(args[command_index + 1]) {
        Ok(migration) => {
          let report = @moonmorph.preflight(migration)
          for error in report.errors {
            println("PREFLIGHT_ERROR " + error)
          }
          for warning in report.warnings {
            println("PREFLIGHT_WARNING " + warning)
          }
          for line in @moonmorph.dry_run(migration) {
            println(line)
          }
        }
        Err(message) => println("SPEC_ERROR " + message)
      }
    "diff" if args.length() == command_index + 3 =>
      run_diff(args[command_index + 1], args[command_index + 2])
    _ => print_help()
  }
}
