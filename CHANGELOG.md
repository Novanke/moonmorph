# Changelog

## 0.4.0 — 2026-09-21

- Synthesize deterministic migrations by comparing source and target JSON values.
- Recursively patch ordered objects and arrays while preserving exact target output.
- Fall back to a compact parent replacement when object-key reordering cannot be expressed cleanly.
- Add a `diff` CLI command that prints a portable plan and verifies the generated result.
- Add a runnable target document, synthesis guide and CI smoke test.
- Expand the cross-backend test suite to 38 tests.

## 0.3.0 — 2026-09-17

- Compact generated rollback migrations to one original root snapshot.
- Detect exact and ancestor/descendant write overlaps.
- Include both endpoints of `move` and `rename` in write-set analysis.
- Add stable error-code labels and JSON diagnostics for errors and preflight reports.
- Expand the cross-backend test suite to 33 tests.

## 0.2.0 — 2026-09-17

- Serialize typed migrations and generated rollback plans to portable JSON.
- Add structured preflight reports with separate errors and warnings.
- Reject invalid append usage, self/descendant moves and no-op renames before execution.
- Add typed path-prefix comparison and expand the cross-backend suite to 26 tests.
- Document the static/dynamic validation boundary and recovery-artifact security model.

## 0.1.0 — 2026-09-04

- Introduce ordered JSON-like value model and RFC 6901 paths.
- Add atomic execution for eight migration operations.
- Generate exact rollback plans and human-readable journals.
- Parse declarative migration JSON.
- Detect same-path write conflicts.
- Validate catalogs and compose shortest deterministic version routes.
- Add portable CLI demo, examples and multi-backend tests.
