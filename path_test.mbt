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

///|
test "path prefix comparison uses typed segments" {
  let profile = Path::parse("/users/0").unwrap()
  inspect(
    profile.is_prefix_of(Path::parse("/users/0/name").unwrap()),
    content="true",
  )
  inspect(profile.is_prefix_of(profile), content="true")
  inspect(
    profile.is_prefix_of(Path::parse("/users/1").unwrap()),
    content="false",
  )
}
