# Preflight guide

MoonMorph divides validation into two stages so callers can review a plan early without weakening execution-time safety.

## Static checks

`preflight(migration)` needs no input document and returns a `PreflightReport` containing `errors` and `warnings`.

Errors currently cover:

- empty migration names or version identifiers;
- identical source and target versions;
- `-` outside the final destination segment of an `add` operation;
- a `move` whose source and destination are identical;
- moving a value into one of its own descendants;
- a `rename` whose source and destination keys are identical.

Warnings currently cover:

- migrations with no operations;
- multiple non-`test` operations writing the same path.

Repeated writes are warnings because they can be intentional, such as replacing a version value and then incrementing it. Hosts may promote warnings to errors according to local policy.

## Dynamic checks

The executor evaluates facts that require the actual input document:

- path and object-key existence;
- object, array, scalar and numeric type compatibility;
- array insertion and access bounds;
- `test` preconditions;
- rename destination collisions.

If any dynamic check fails, `apply` returns a `MigrationError` with a stable code, operation index and path. The caller's input remains unchanged.

## Recommended host flow

1. Parse the migration JSON.
2. Run `preflight` and reject any errors.
3. Review or log warnings and `dry_run` summaries.
4. Load and authorize the input document.
5. Call `apply`.
6. Validate the returned value against any host schema.
7. Persist the new value and protect or discard the rollback artifact according to policy.

Preflight is deterministic across MoonBit targets and performs no I/O.
