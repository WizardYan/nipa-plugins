# Plugin boundary

The manifest owns scientific inputs, outputs, parameters and runtime declarations.
Python adapters use the public `nipa3.sdk` data contract and run in a disposable
adapter worker. Scientific scripts run through the executor/container boundary.
They do not import NIPA execution/planning/web/persistence internals or write its
project database. `.nipa_complete` and `.nipa_references` within output folders
are plugin output markers/references, not the project database.

Process isolation is fault containment, not a filesystem/network security sandbox.
Validate this package using `validate_package(path, strict_isolation=True)`.
Requires NIPA 3.0.15 or newer. The public SDK and isolated worker are the supported integration boundary.
