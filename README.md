# MoonMorph

Atomic, reversible JSON migrations in pure MoonBit.

Configuration upgrades often fail halfway through: one key has been renamed, an array has already shifted, and the old document is no longer recoverable. MoonMorph treats a migration as a transaction. It applies every operation to an isolated value, returns the result only after all preconditions pass, records an audit journal, and builds a rollback plan automatically.

## Why MoonMorph

- **Atomic by construction** — a failed operation never mutates the caller's document.
- **Automatic rollback** — every successful step captures an inverse root snapshot, including moves and array edits that are otherwise difficult to invert correctly.
- **Declarative plans** — migrations are ordinary JSON and work well in code review and CI.
- **Version graph planning** — compose the shortest deterministic route across a migration catalog.
- **Preflight diagnostics** — flag same-path writes before execution and report the exact failing operation.
- **Portable core** — checked and tested on the Wasm, Wasm-GC and JavaScript backends; no FFI is used by the library.

## Quick start

```bash
moon test
moon run cmd/main -- demo
```

Expected output:

```text
{"version":2,"service":{"port":8081,"hostname":"localhost"},"features":["search","export","audit"]}
JOURNAL
  0: test /version
  1: replace /version
  2: rename /service/host -> /service/hostname
  3: increment /service/port by 1
  4: add /features/-
ROLLBACK_VERIFIED true
```

The CLI also accepts a document and migration as JSON strings:

```bash
moon run cmd/main -- apply \
  '{"version":1,"name":"demo"}' \
  '{"name":"v2","from":"1","to":"2","operations":[{"op":"replace","path":"/version","value":2}]}'
```

## Migration format

```json
{
  "name": "account-v1-to-v2",
  "from": "1",
  "to": "2",
  "operations": [
    { "op": "test", "path": "/version", "value": 1 },
    { "op": "replace", "path": "/version", "value": 2 },
    { "op": "rename", "path": "/profile", "from": "display_name", "to": "name" },
    { "op": "increment", "path": "/profile/quota", "delta": 5 },
    { "op": "add", "path": "/roles/-", "value": "contributor" }
  ]
}
```

Supported operations:

| Operation | Purpose |
|---|---|
| `test` | Guard a migration with an exact-value precondition |
| `add` | Add/replace an object key or insert/append an array element |
| `replace` | Replace an existing value |
| `remove` | Remove an existing key or array element |
| `copy` | Copy a value between paths |
| `move` | Move a value between paths |
| `increment` | Add a numeric delta with type checking |
| `rename` | Rename an object key without overwriting a destination |

Paths use RFC 6901 escaping: `/a~1b` addresses key `a/b`, `/~0meta` addresses `~meta`, and `/-` appends to an array during `add`.

## Library example

```moonbit
let document = @moonmorph.parse_value(
  #|{"version":1,"profile":{"name":"Ada"}}
).unwrap()

let migration = @moonmorph.parse_migration(
  #|{"name":"v2","from":"1","to":"2","operations":[
  #|  {"op":"test","path":"/version","value":1},
  #|  {"op":"replace","path":"/version","value":2},
  #|  {"op":"add","path":"/profile/active","value":true}
  #|]}
).unwrap()

let result = @moonmorph.apply(migration, document).unwrap()
println(result.value.to_json().stringify())
let restored = @moonmorph.apply_rollback(result).unwrap()
assert_eq(restored.value, document)
```

## Version routing

Applications can keep small migrations such as `1 -> 2`, `2 -> 3`, and `2 -> 2.1`. `plan_route` performs a breadth-first search and composes the shortest route to a requested version. Catalog order breaks ties, so results are reproducible.

```moonbit
let route = @moonmorph.plan_route(catalog, "1", "3").unwrap()
let upgraded = @moonmorph.apply(route, document).unwrap()
```

## Failure model

Errors contain a stable code, zero-based operation index, path, and human-readable message. The engine distinguishes malformed paths, missing values, type mismatches, bounds errors, unsafe rename overwrites, failed preconditions, conflicts and non-reversible plans.

Atomicity does not rely on callers remembering to clone data. MoonMorph deep-copies the input before execution and returns no partially changed value on failure.

## Verification

```bash
moon fmt --check
moon check --deny-warn --target all
moon test --target wasm
moon test --target wasm-gc
moon test --target js
```

The 20-test suite covers RFC 6901 escaping, nested lookup, numeric and dash object keys, root replacement, object and array edits, move/copy semantics, rename collision safety, bounds and type failures, atomic failure, exact rollback, declarative parsing, preflight conflicts, catalog validation, reachability and shortest-route planning.

## Project layout

```text
model.mbt          public data model and structured errors
path.mbt           RFC 6901-style path parser and renderer
value.mbt          ordered value model, cloning and stable serialization
engine.mbt         atomic executor, journal, rollback and preflight
json_adapter.mbt   MoonBit Json adapters and migration-spec parser
planner.mbt        catalog validation and deterministic BFS routing
cmd/main/          runnable CLI demonstration
examples/          example document and migration plan
docs/              architecture and design decisions
```

## Scope

MoonMorph is not a database migration framework and does not perform I/O in its core. Hosts own persistence and decide when to commit the returned document. This narrow boundary keeps the library deterministic, testable and usable from browsers, edge workers and native services.

## License

Apache-2.0.
