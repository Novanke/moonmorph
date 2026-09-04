# Security

MoonMorph transforms in-memory data and does not read files, use the network or persist results. Hosts remain responsible for authorization, schema validation and safe storage.

Do not place credentials directly in migration specifications committed to source control. Treat migration plans as code: review them, use `test` preconditions, inspect `dry_run` output and commit only a successful returned value.

The rollback journal contains historical document snapshots. If a document contains secrets, the journal is equally sensitive and must follow the same retention and access policy.

