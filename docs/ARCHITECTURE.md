# Architecture

MoonMorph separates parsing, planning and execution so each layer can be reused independently.

```text
JSON document ──► ordered Value ──► atomic executor ──► migrated Value
                       ▲                  │                    │
                       │                  ├── audit journal     └── host commits
migration JSON ─► typed Operations ─► preflight ─┘   └── rollback plan ─► JSON
                            ▲
catalog ─────────────► route planner
```

## Ordered value model

`Value` mirrors JSON but stores objects as ordered key/value arrays. This makes output and tests stable across targets. All public reads and executor entry points deep-copy nested arrays and objects so the engine never shares mutable storage with caller-owned values.

## Path layer

`Path` is parsed once into typed segments. String keys use RFC 6901 `~0` and `~1` escapes. Decimal segments are array indexes when traversing arrays; the same token remains usable as an object key because traversal is type-directed. `-` is accepted only as the final segment of an `add` operation.

## Atomic executor

The executor starts from a deep copy and threads a fresh value through each operation. An error returns immediately with the operation index; the original input is untouched. A successful step stores a root snapshot as its journal inverse. The generated rollback migration stores only the original root, so its size stays constant with respect to operation count. Root snapshots cost more memory than minimal patches, but they make rollback exact for every supported operation, including overlapping moves and shifted arrays.

## Preflight boundary

Preflight analyzes only the typed migration. It catches plan-level invariants such as invalid append tokens and moves into descendants without needing a document. Its write-set analysis includes source and destination paths for `move` and `rename`, and reports both exact and ancestor/descendant overlaps. Data-dependent checks—path existence, value type, bounds, preconditions and collisions—remain in the atomic executor. Keeping this boundary explicit avoids pretending static validation can guarantee a migration against unknown input.

## Portable recovery

Typed migrations serialize to the same declarative JSON accepted by the parser. A generated rollback plan is therefore a normal migration artifact: a host can persist it, transfer it to another process, parse it later and execute it through the same engine. The serialized snapshots inherit the sensitivity of the source document.

## Planner

The planner views migrations as directed edges between version strings. Breadth-first search finds the minimum number of migrations. Visited versions prevent cycles; input order provides a deterministic tie-break. The returned route is an ordinary `Migration`, so execution and rollback need no planner-specific logic.

## Trust boundary

The core performs no file, network, environment or process access. A host parses input, calls `apply`, validates the result if needed, and persists only after success. This is intentionally similar to a database transaction's prepare/commit separation.
