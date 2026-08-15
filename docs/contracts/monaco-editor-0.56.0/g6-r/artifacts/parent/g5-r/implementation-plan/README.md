# MonaCode G5-R full implementation plan

This directory is the human companion to the machine-authoritative G5-R plan manifest. It plans the complete macOS 26 arm64 implementation of the frozen Monaco Editor 0.56.0 Apple-port scope. It does not claim that Swift product sources, candidate artifacts, correctness gates, performance cells, or a release verdict exist.

## Authority and reading order

1. `../global-g5r-authoritative-contract.html` and `../artifacts/monacode-g5r-authoritative-manifest.json` freeze product scope and acceptance truth.
2. `../artifacts/monacode-g5r-implementation-plan-manifest.json` owns task records, dependencies, identity ownership, evidence paths, and commit boundaries.
3. `00-master-plan.md` summarizes the whole-project graph and fixed matrices.
4. `phase-00-*.md` through `phase-09-*.md` render the same task records. Every marker contains the SHA-256 of its complete machine record.

## Verification

`node verify-plan.mjs` performs the full audit. During authoring, `node verify-plan.mjs --phase NN` audits the selected phase plus all already declared graph, boundary, evidence, and ownership rows. Any finding or missing phase document exits 1.

The only plan evidence states are `planned`, `mapped`, and `structurally-verified`. Product states remain not-started/not-passed until implementation runs produce the separate evidence required by G5-R.
