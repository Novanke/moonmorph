# Design decisions

## Root snapshots for rollback

Minimal inverse patches are attractive but subtle: removing an array item shifts later indexes; moving a parent into a descendant can invalidate both paths; and overwriting an object key needs the previous value. MoonMorph stores the entire pre-step value as `Replace(root, snapshot)`. The invariant is simple: applying inverse entries in reverse order restores the exact original value.

This is the correct default for configuration documents, which are usually small. A future storage strategy can add compact inverses behind the same public result type.

## Preconditions are operations

`test` lives in the operation stream instead of a separate schema layer. Preconditions are therefore ordered, journaled and visible in dry runs. A plan can guard both the initial version and intermediate assumptions.

## Static and dynamic validation stay separate

`preflight` reports invariants visible from a plan alone. It does not inspect a document or claim that execution will succeed. Document-dependent checks remain in `apply`, where failure is atomic and includes the exact operation index. This separation makes preflight deterministic and keeps the executor authoritative.

## No implicit container creation

Adding `/a/b` fails if `/a` does not exist. Silent container creation makes typos look successful and complicates rollback. Callers must create parents explicitly, keeping plans reviewable.

## Rename refuses overwrite

`rename` fails when its destination key exists. JSON Patch-style `add` remains available for intentional overwrite. The safe default protects configuration fields from accidental loss.

## Deterministic routing

When two shortest version routes exist, catalog order wins. This avoids non-deterministic deployments while allowing maintainers to express preference without another priority language.

## Recovery plans use the input format

Rollback output is serialized as an ordinary migration rather than a second recovery-specific schema. One parser and one executor therefore cover both forward and reverse workflows, which reduces integration surface and makes recovery artifacts independently testable.
