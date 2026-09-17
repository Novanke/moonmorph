# MoonMorph

Atomic, reversible JSON migrations in pure MoonBit.

[![CI](https://github.com/Novanke/moonmorph/actions/workflows/ci.yml/badge.svg)](https://github.com/Novanke/moonmorph/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

Configuration upgrades often fail halfway through: one key has been renamed, an array has already shifted, and the old document is no longer recoverable. MoonMorph treats a migration as a transaction. It applies every operation to an isolated value, returns the result only after all preconditions pass, records an audit journal, and builds a rollback plan automatically.

## Why MoonMorph

- **Atomic by construction** — a failed operation never mutates the caller's document.
- **Automatic rollback** — every successful step captures an inverse root snapshot, including moves and array edits that are otherwise difficult to invert correctly.
- **Declarative plans** — migrations are ordinary JSON and work well in code review and CI.
- **Version graph planning** — compose the shortest deterministic route across a migration catalog.
- **Preflight diagnostics** — flag same-path writes before execution and report the exact failing operation.
- **Portable recovery plans** — serialize generated rollback migrations back to declarative JSON.
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

let report = @moonmorph.preflight(migration)
guard report.is_valid() else {
  println(report.errors.join("\n"))
  return
}

let result = @moonmorph.apply(migration, document).unwrap()
println(result.value.to_json().stringify())
let portable_rollback = result.rollback.unwrap().to_json_string()
let restored = @moonmorph.apply_rollback(result).unwrap()
assert_eq(restored.value, document)
```

## Preflight validation

`preflight` performs checks that do not require an input document. It rejects empty version metadata, identical source and target versions, illegal `-` segments, moves into descendants, and no-op renames. It also warns about empty plans and repeated writes to the same path.

```moonbit
let report = @moonmorph.preflight(migration)
for warning in report.warnings {
  println("warning: " + warning)
}
if !report.is_valid() {
  for error in report.errors {
    println("error: " + error)
  }
}
```

Preflight complements execution-time checks: missing values, incompatible types, array bounds, failed `test` operations and rename collisions depend on the actual document and remain transactional execution errors. See [the preflight guide](docs/PREFLIGHT.md) for the complete boundary.

## Portable rollback plans

Every `Migration`, including the rollback plan returned after a successful run, can be serialized and parsed through the same JSON format:

```moonbit
let rollback_json = result.rollback.unwrap().to_json_string()
let rollback = @moonmorph.parse_migration(rollback_json).unwrap()
let restored = @moonmorph.apply(rollback, result.value).unwrap()
```

This lets a host persist a recovery artifact separately from the migrated configuration. Because rollback snapshots can contain old secrets, protect them with the same controls as the source document.

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

The 26-test suite covers RFC 6901 escaping, typed path-prefix checks, nested lookup, numeric and dash object keys, root replacement, object and array edits, move/copy semantics, rename collision safety, bounds and type failures, atomic failure, exact rollback, migration serialization, declarative parsing, structured preflight, catalog validation, reachability and shortest-route planning.

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

## Public API at a glance

| API | Role |
|---|---|
| `parse_value` / `Value::to_json` | Bridge standard MoonBit JSON and the ordered value model |
| `parse_migration` / `Migration::to_json_string` | Decode and encode portable migration plans |
| `preflight` / `dry_run` | Review static plan diagnostics and operation summaries |
| `apply` / `apply_rollback` | Execute atomically and restore an exact prior value |
| `validate_catalog` / `plan_route` | Validate a version graph and compose its shortest route |
| `reachable_versions` | Enumerate deterministic BFS reachability |

## Scope

MoonMorph is not a database migration framework and does not perform I/O in its core. Hosts own persistence and decide when to commit the returned document. This narrow boundary keeps the library deterministic, testable and usable from browsers, edge workers and native services.

## License

Apache-2.0.
