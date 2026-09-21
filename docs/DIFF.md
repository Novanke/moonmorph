# Migration synthesis

MoonMorph can derive a portable migration by comparing a current `Value` with a desired `Value`:

```moonbit
let migration = @moonmorph.synthesize_migration(
  name="generated-v2",
  from_version="1",
  to_version="2",
  source=current,
  target=desired,
)
```

The result is a normal `Migration`. It can be serialized with
`Migration::to_json_string`, reviewed with `preflight` and `dry_run`, executed
with `apply`, and reversed with the generated rollback plan.

## Deterministic rules

- Equal values emit no operation.
- Scalar or type changes emit `replace` at the current path.
- Arrays are compared at shared indexes, then shortened with descending
  removals or extended with ordered additions.
- Objects are patched recursively when their surviving keys keep the same order
  and new keys appear after existing keys.
- Other object-key reorderings emit one parent `replace` so the ordered target is
  reproduced exactly.
- Object keys always pass through `Path::child_key`, including RFC 6901 escaping
  for `/` and `~`.

These rules are intentionally deterministic rather than globally minimal. Two
hosts comparing the same ordered values receive the same operation list on the
Wasm, Wasm-GC and JavaScript backends.

## CLI

```bash
moon run cmd/main -- diff \
  "$(cat examples/account-v1.json)" \
  "$(cat examples/account-v2.json)"
```

The CLI prints the generated migration JSON followed by `DIFF_VERIFIED true`.
The verification step executes the generated plan and compares the result with
the target value, giving demos and CI a direct end-to-end check.

## Review boundary

Synthesis does not infer domain intent such as whether a remove/add pair should
be described as a rename, and it does not add version preconditions
automatically. Treat generated plans as code: review them, add any required
`test` operations, run preflight, and persist only a successful result.
