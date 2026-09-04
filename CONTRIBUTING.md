# Contributing

1. Add or update tests with every behavioral change.
2. Run `moon fmt`, `moon check --deny-warn --target all`, and the Wasm, Wasm-GC and JavaScript test suites.
3. Keep the core deterministic and free of I/O or backend-specific FFI.
4. Document compatibility changes in `CHANGELOG.md`.

Bug reports should include the input document, migration plan, expected result, actual result and MoonBit toolchain version. Remove secrets before sharing configuration files.

