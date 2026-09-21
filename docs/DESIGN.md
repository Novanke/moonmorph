# Design decisions

## Root snapshots for rollback

Minimal inverse patches are attractive but subtle: removing an array item shifts later indexes; moving a parent into a descendant can invalidate both paths; and overwriting an object key needs the previous value. Journal entries retain the entire pre-step value as `Replace(root, snapshot)` so each completed step has an exact inverse. The generated recovery migration is more compact: it contains only one root snapshot of the original document, regardless of the number of forward operations.

This is the correct default for configuration documents, which are usually small. It keeps detailed audit information while minimizing the persisted rollback artifact. A future journal policy can make per-step snapshots optional behind a separate API.

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

## Synthesized plans prefer exactness over cosmetic minimality

The diff synthesizer guarantees that applying its output produces the exact ordered target value. It emits small nested patches when object-key order remains representable, and replaces a parent object when keys are reordered or inserted before existing keys. This deliberately avoids claiming globally minimal edit scripts and keeps output deterministic across backends. Arrays use index updates plus descending tail removals and ordered appends, which avoids index drift without a separate sequence-alignment algorithm.
