///|
/// A JSON-like value with deterministic object order.
pub(all) enum Value {
  Null
  Bool(Bool)
  Number(Double)
  String(String)
  Array(Array[Value])
  Object(Array[(String, Value)])
} derive(Debug, Eq)

///|
pub extend Value with Debug::{to_repr}

///|
pub extend Value with Eq::{not_equal, equal}

///|
/// One component in a parsed path.
pub(all) enum Segment {
  Key(String)
  Index(Int)
  Append
} derive(Debug, Eq)

///|
pub extend Segment with Debug::{to_repr}

///|
pub extend Segment with Eq::{not_equal, equal}

///|
/// A parsed RFC 6901-style path.
pub(all) struct Path {
  segments : Array[Segment]
} derive(Debug, Eq)

///|
pub extend Path with Debug::{to_repr}

///|
pub extend Path with Eq::{not_equal, equal}

///|
pub fn Path::root() -> Path {
  { segments: [], }
}

///|
pub fn Path::segments(self : Path) -> Array[Segment] {
  self.segments.copy()
}

///|
pub(all) enum Operation {
  Add(Path, Value)
  Replace(Path, Value)
  Remove(Path)
  Copy(Path, Path)
  Move(Path, Path)
  Test(Path, Value)
  Increment(Path, Double)
  Rename(Path, String, String)
} derive(Debug, Eq)

///|
pub extend Operation with Debug::{to_repr}

///|
pub extend Operation with Eq::{not_equal, equal}

///|
pub(all) struct Migration {
  name : String
  from_version : String
  to_version : String
  operations : Array[Operation]
} derive(Debug, Eq)

///|
pub extend Migration with Debug::{to_repr}

///|
pub extend Migration with Eq::{not_equal, equal}

///|
pub fn Migration::new(
  name~ : String,
  from_version~ : String,
  to_version~ : String,
  operations~ : Array[Operation],
) -> Migration {
  { name, from_version, to_version, operations, }
}

///|
pub(all) enum ErrorCode {
  InvalidPath
  NotFound
  TypeMismatch
  IndexOutOfBounds
  AlreadyExists
  TestFailed
  Conflict
  NonReversible
} derive(Debug, Eq)

///|
pub extend ErrorCode with Debug::{to_repr}

///|
pub extend ErrorCode with Eq::{not_equal, equal}

///|
/// Stable machine-readable label for an execution error category.
pub fn ErrorCode::label(self : ErrorCode) -> String {
  match self {
    InvalidPath => "invalid_path"
    NotFound => "not_found"
    TypeMismatch => "type_mismatch"
    IndexOutOfBounds => "index_out_of_bounds"
    AlreadyExists => "already_exists"
    TestFailed => "test_failed"
    Conflict => "conflict"
    NonReversible => "non_reversible"
  }
}

///|
pub(all) struct MigrationError {
  code : ErrorCode
  operation_index : Int
  path : String
  message : String
} derive(Debug, Eq)

///|
pub extend MigrationError with Debug::{to_repr}

///|
pub extend MigrationError with Eq::{not_equal, equal}

///|
pub(all) struct JournalEntry {
  operation_index : Int
  summary : String
  inverse : Operation?
} derive(Debug, Eq)

///|
pub extend JournalEntry with Debug::{to_repr}

///|
pub extend JournalEntry with Eq::{not_equal, equal}

///|
pub(all) struct MigrationResult {
  value : Value
  journal : Array[JournalEntry]
  rollback : Migration?
} derive(Debug, Eq)

///|
pub extend MigrationResult with Debug::{to_repr}

///|
pub extend MigrationResult with Eq::{not_equal, equal}

///|
/// Static diagnostics produced before a migration touches a document.
pub(all) struct PreflightReport {
  errors : Array[String]
  warnings : Array[String]
} derive(Debug, Eq)

///|
pub extend PreflightReport with Debug::{to_repr}

///|
pub extend PreflightReport with Eq::{not_equal, equal}

///|
pub fn PreflightReport::is_valid(self : PreflightReport) -> Bool {
  self.errors.is_empty()
}
