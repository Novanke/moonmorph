///|
fn decode_path_token(token : String) -> String? {
  let out = StringBuilder()
  let chars = token.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '~' {
      if i + 1 >= chars.length() {
        return None
      }
      match chars[i + 1] {
        '0' => out.write_char('~')
        '1' => out.write_char('/')
        _ => return None
      }
      i = i + 2
    } else {
      out.write_char(chars[i])
      i = i + 1
    }
  }
  Some(out.to_string())
}

///|
fn parse_index(token : String) -> Int? {
  if token.is_empty() {
    return None
  }
  let mut value = 0
  for ch in token {
    if ch < '0' || ch > '9' {
      return None
    }
    value = value * 10 + (ch.to_int() - '0'.to_int())
  }
  Some(value)
}

///|
pub fn Path::parse(text : String) -> Result[Path, MigrationError] {
  if text == "" {
    return Ok(Path::root())
  }
  if !text.has_prefix("/") {
    return Err({
      code: InvalidPath,
      operation_index: -1,
      path: text,
      message: "path must be empty or begin with '/'",
    })
  }
  let result : Array[Segment] = []
  let tokens = text[1:].split("/")
  for token_view in tokens {
    let raw = token_view.to_owned()
    guard decode_path_token(raw) is Some(token) else {
      return Err({
        code: InvalidPath,
        operation_index: -1,
        path: text,
        message: "invalid '~' escape; only ~0 and ~1 are allowed",
      })
    }
    if token == "-" {
      result.push(Append)
    } else {
      match parse_index(token) {
        Some(index) => result.push(Index(index))
        None => result.push(Key(token))
      }
    }
  }
  Ok({ segments: result, })
}

///|
fn encode_path_token(token : String) -> String {
  token.replace(old="~", new="~0").replace(old="/", new="~1")
}

///|
pub fn Path::to_string(self : Path) -> String {
  if self.segments.is_empty() {
    return ""
  }
  let out = StringBuilder()
  for segment in self.segments {
    out.write_char('/')
    match segment {
      Key(key) => out.write_string(encode_path_token(key))
      Index(index) => out.write_string(index.to_string())
      Append => out.write_char('-')
    }
  }
  out.to_string()
}

///|
pub fn Path::parent(self : Path) -> Path? {
  if self.segments.is_empty() {
    None
  } else {
    Some({ segments: self.segments[:self.segments.length() - 1].to_owned(), })
  }
}

///|
pub fn Path::last(self : Path) -> Segment? {
  self.segments.last()
}

///|
pub fn Path::child_key(self : Path, key : String) -> Path {
  { segments: [..self.segments, Key(key)], }
}

///|
pub fn Path::child_index(self : Path, index : Int) -> Path {
  { segments: [..self.segments, Index(index)], }
}
