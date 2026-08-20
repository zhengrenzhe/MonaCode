# MonaCode repository rules

This file applies to the entire repository. More deeply nested `AGENTS.md` files are prohibited unless the user authorizes a narrower rule set.

1. Read the root README authority, Tasks, and Definition of Done before changing files.
2. Read the frozen G6-R manifest and the task's referenced contract identities before implementation.
3. Bind every product, test, tool, or active-document change to an existing README task ID in the commit message or change record.
4. Do not implement work absent from the ledger. Add or split a task first; scope expansion and contract changes require user authorization.
5. Update implementation, tests, evidence, and README state in the same commit that changes the factual state.
6. Never infer capability completion from compilation, declaration presence, plan verification, fixture tests, or an artifact from another revision.
7. Never create `STATUS.md`, a second task list, a parallel roadmap, a mutable equivalence-status report, or a root release-status document.
8. Specs, plans, audits, and release artifacts are evidence or history. They contain an explicit non-authority classification and cannot set current progress.
9. Do not modify frozen G4-R, G5-R, or G6-R bytes. Create a new authorized contract revision for a scope change.
10. Preserve macOS current-release and mobile later-revision boundaries. A `MOBILE` task cannot block a macOS task unless G6-R explicitly defines that dependency.
11. State conclusions from current local code, executed commands, or identified evidence. When evidence is insufficient, stop and ask the user how to continue.
12. Run the governance checker, frozen-contract verifier, task-specific tests, and `git diff --check` before claiming completion.

## Governance bootstrap

The single-source migration is task `VERIFY-001`. After that task is `DONE`, every product, test, tool, and active-document change must bind an existing README task ID in its commit subject.

## Mandatory checks

```bash
node Tools/Docs/check-project-governance.mjs
node --test Tests/PlanStructureTests/ProjectGovernanceTests.mjs
node docs/contracts/monaco-editor-0.56.0/g6-r/verify-contract.mjs
git diff --check
```

Scope authority: [G6-R authoritative manifest](docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-authoritative-manifest.json). Current progress authority: [README Tasks](README.md#tasks). Historical context: [archive index](docs/archive/README.md).
