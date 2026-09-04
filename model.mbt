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
/// One component in a parsed path.
pub(all) enum Segment {
  Key(String)
  Index(Int)
  Append
} derive(Debug, Eq)

///|
/// A parsed RFC 6901-style path.
pub(all) struct Path {
  segments : Array[Segment]
} derive(Debug, Eq)

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
pub(all) struct Migration {
  name : String
  from_version : String
  to_version : String
  operations : Array[Operation]
} derive(Debug, Eq)

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
pub(all) struct MigrationError {
  code : ErrorCode
  operation_index : Int
  path : String
  message : String
} derive(Debug, Eq)

///|
pub(all) struct JournalEntry {
  operation_index : Int
  summary : String
  inverse : Operation?
} derive(Debug, Eq)

///|
pub(all) struct MigrationResult {
  value : Value
  journal : Array[JournalEntry]
  rollback : Migration?
} derive(Debug, Eq)
