# Submission source notes

The competition form says the one-page project proposal must not be written by AI. This file is therefore only a factual checklist for the entrant to use while writing the proposal in their own words; it is not a submission document.

- Project name: MoonMorph
- Category: data and infrastructure / developer tooling
- One-line fact: atomic, reversible JSON configuration migration engine written in pure MoonBit
- General value: decouples deterministic migration logic from storage and works across browser, edge and native hosts
- Scenario facts:
  - upgrade application configuration with version preconditions and exact rollback
  - evolve API payloads between deployed client/server versions
  - migrate AI-tool configuration while preserving an auditable journal
  - update offline/local-first data before committing to storage
- Core functions: typed paths; add/replace/remove/copy/move/test/increment/rename; atomic execution; rollback generation; dry run; conflict detection; JSON spec parser; version graph planning
- Originality: original implementation; based on public JSON Pointer conventions but not ported from another codebase
- License: Apache-2.0
- Verification facts: 20 tests currently pass on Wasm, Wasm-GC and JavaScript; strict all-target type check passes
- Repository link: fill after the public repository is created
