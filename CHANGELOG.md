# Changelog

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
