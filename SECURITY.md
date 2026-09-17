# Security

MoonMorph transforms in-memory data and does not read files, use the network or persist results. Hosts remain responsible for authorization, schema validation and safe storage.

Do not place credentials directly in migration specifications committed to source control. Treat migration plans as code: review them, inspect `preflight` and `dry_run` output, use `test` preconditions, and commit only a successful returned value.

The rollback journal and its serialized migration contain historical document snapshots. If a document contains secrets, these recovery artifacts are equally sensitive and must follow the same retention and access policy.
