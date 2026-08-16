# MonaCode G6-R execution plan

This directory is the human companion to the machine-authoritative G6-R execution plan manifest. It renders the complete execution-readiness plan: 200 tasks across 10 phases, each with a seven-stage lifecycle, pinned toolchain commands, and commit-before-evidence ordering.

## Authority and reading order

1. `../artifacts/monacode-g6r-execution-schema.json` defines the closed TaskRecord contract.
2. `../artifacts/monacode-g6r-implementation-plan-manifest.json` owns task records, ownership, evidence, and commit contracts.
3. `../artifacts/monacode-g6r-command-dependency-manifest.json` owns the 400 deduplicated verification commands.
4. `../artifacts/monacode-g6r-interface-contract-manifest.json` owns the 340 deduplicated interface contracts.
5. `00-master-plan.md` summarizes the whole-project graph and fixed matrices.
6. `phase-00-*.md` through `phase-09-*.md` render the same task records. Every task marker contains the SHA-256 of its complete machine record.

## Verification

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/assemble-plan.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/render-plan.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tools/G6PlanAuthoring/tests/assemble-plan.test.mjs
```

The assembly prints `G6_PLAN_ASSEMBLED ...` with the exact pinned counts. Rendering twice changes zero bytes. Every human document is derived from the machine record; no normative content is absent from the manifest.

## Plan summary

| Matrix | Count |
| --- | --- |
| Phases | 10 |
| Tasks | 200 |
| Test contracts | 200 |
| Commands | 400 |
| Leaves | 407 |
| Begin actions | 200 |
| Commit actions | 200 |
| Finalize actions | 200 |
| Product-commit contracts | 200 |
| Evidence-commit contracts | 200 |
| Source gaps | 0 |
| Acquisition gaps | 0 |
| Red-scaffold tasks | 139 |
| Red-scaffold paths | 249 |
| Interfaces | 340 |
| Ownership rows | 3582 |
| Evidence contracts | 200 |
