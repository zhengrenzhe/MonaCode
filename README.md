# MonaCode

MonaCode is a native Swift code-editor component for Apple platforms. The current implementation target is arm64 macOS; iOS and iPadOS remain later global revisions.

## Current status

- G4-R full-scope and technical contract: adopted and frozen on 2026-08-14.
- Implementation: not started.
- Release acceptance: not passed.
- Behavioral baseline: `monaco-editor@0.56.0`.

The repository contract entry point is [docs/contracts/monaco-editor-0.56.0/g4-r/README.md](docs/contracts/monaco-editor-0.56.0/g4-r/README.md).

Implementation phases must map back to G4-R. A phase cannot alter scope, cuts, native adaptations, architecture, host contracts, correctness gates, or performance thresholds. Any such change requires a new global contract revision.
