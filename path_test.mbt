///|
test "path root and roundtrip" {
  let root = Path::parse("").unwrap()
  inspect(root.to_string(), content="")
  let path = Path::parse("/users/0/a~1b/~0meta").unwrap()
  inspect(path.to_string(), content="/users/0/a~1b/~0meta")
}

///|
test "path rejects malformed escape" {
  inspect(Path::parse("/a~2b") is Err(_), content="true")
  inspect(Path::parse("relative") is Err(_), content="true")
}
