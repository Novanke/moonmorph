# Design decisions

## Root snapshots for rollback

Minimal inverse patches are attractive but subtle: removing an array item shifts later indexes; moving a parent into a descendant can invalidate both paths; and overwriting an object key needs the previous value. MoonMorph stores the entire pre-step value as `Replace(root, snapshot)`. The invariant is simple: applying inverse entries in reverse order restores the exact original value.

This is the correct default for configuration documents, which are usually small. A future storage strategy can add compact inverses behind the same public result type.

## Preconditions are operations

`test` lives in the operation stream instead of a separate schema layer. Preconditions are therefore ordered, journaled and visible in dry runs. A plan can guard both the initial version and intermediate assumptions.

## No implicit container creation

Adding `/a/b` fails if `/a` does not exist. Silent container creation makes typos look successful and complicates rollback. Callers must create parents explicitly, keeping plans reviewable.

## Rename refuses overwrite

`rename` fails when its destination key exists. JSON Patch-style `add` remains available for intentional overwrite. The safe default protects configuration fields from accidental loss.

## Deterministic routing

When two shortest version routes exist, catalog order wins. This avoids non-deterministic deployments while allowing maintainers to express preference without another priority language.

