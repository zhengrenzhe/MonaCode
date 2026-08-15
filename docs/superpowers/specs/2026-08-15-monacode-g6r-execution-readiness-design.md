# MonaCode G6-R execution-readiness revision design

Status: approved on 2026-08-15; implementation has not started.

## Purpose

Create a new immutable G6-R successor archive whose implementation plan can be executed task by task from a clean checkout without an undeclared decision, missing command dependency, ambiguous task order, or unbounded repository mutation.

G6-R inherits the complete MonaCode product scope, behavior baseline, architecture, platform scope, exclusions, correctness gates, performance gates, and qualification environment from the adopted G5-R archive. This revision changes implementation-plan governance and planning verification only. It does not create MonaCode product Swift sources, execute product correctness or performance gates, generate release candidates, or claim product acceptance.

## Confirmed defect in G5-R

The adopted G5-R plan is structurally verified, not execution-ready. The first product task, `P00-T001`, runs:

```sh
swift package dump-package | node Tools/PlanChecks/assert-package-graph.mjs
```

The referenced `Tools/PlanChecks/assert-package-graph.mjs` file is absent from the repository, absent from the task's `files.create`, `files.modify`, and `files.test` arrays, absent from its commit boundary, and absent from every other task producer list. The observed command exits with Node `MODULE_NOT_FOUND`; it does not emit the required `PLAN_PACKAGE_GRAPH_MISSING` result.

The G5-R `auditExecutability` implementation accepts this command because it validates command syntax with a regular expression. It does not resolve repository-local command paths, model step-time file availability, or prove a producer relationship. The corresponding positive test repeats this blind spot. A scan of all 200 tasks and 400 Red/Green commands found two exact missing undeclared command-path references, both the Red and Green references to this same checker.

This defect invalidates a claim that G5-R can be executed directly from a clean checkout. It does not change or invalidate the frozen product contract.

## Selected revision strategy

G6-R is a complete, self-contained sibling archive at:

`docs/contracts/monaco-editor-0.56.0/g6-r/`

The adopted G5-R archive remains byte-for-byte unchanged. G6-R records G5-R as its parent, embeds the exact parent authority bytes required to prove scope equality, and replaces the G5-R implementation-plan authority with an execution-ready plan authority. G6-R does not depend on mutable state outside its own archive during verification.

An overlay addendum is rejected because it requires an executor to merge two authority graphs at runtime. Editing G5-R is rejected because its adoption record and checksum index select immutable bytes.

## Authority order

G6-R uses this strict authority order:

1. `g6-r/adoption-record.json` selects the exact adopted G6-R contract, plan, audit, review, and checksum bytes.
2. `g6-r/artifacts/monacode-g6r-authoritative-manifest.json` defines revision identity, parent identity, frozen product-scope equality, and execution-readiness governance.
3. `g6-r/artifacts/monacode-g6r-implementation-plan-manifest.json` defines the complete ordered task graph and every executable task record.
4. `g6-r/artifacts/monacode-g6r-execution-schema.json` defines task, step, command, path, interface, evidence, and commit-boundary records.
5. `g6-r/implementation-plan/runtime/planctl.mjs` is the only task-state and execution-readiness entry point.
6. `g6-r/implementation-plan/00-master-plan.md` and phase documents render the machine records for humans without overriding them.
7. G5-R and earlier revisions remain immutable historical authorities for their own revision only.

Any hash mismatch, scope delta outside the fixed allowlist, unresolved command path, absent task input, ambiguous step, undeclared mutation, interface-signature mismatch, dependency cycle, stale evidence, placeholder, or non-zero adversarial finding invalidates G6-R adoption.

## Frozen product scope

G6-R preserves all of these G5-R facts exactly:

- behavior baseline `monaco-editor@0.56.0`;
- exactly three public products: `MonaCode`, `MonaCodeAppKit`, and `MonaCodeSwiftUI`;
- arm64 macOS 26.0+ as the only release platform in this revision;
- iOS and iPadOS excluded from this release implementation and verdict;
- all 3,582 contract identities and their exact retained or disposition-only status;
- all 42 normative layers and 17 inherited machine-artifact domains;
- all 62 retained macOS feature identities and three native colorization replacements;
- provider-neutral and LSP-first language infrastructure with zero bundled language packs or LSP servers;
- plain-text behavior when no direct provider or LSP capability is attached;
- Core Text shaping and geometry authority;
- complete Core Graphics renderer before the frozen renderer-owned Metal decision;
- conditional Metal creation only under the existing Phase 03 predicate;
- C01-C10, P00-P13, M0, M1, 60 Hz, 120 Hz, and `native/comparator <= 1.00` requirements;
- zero WebView, DOM, CSS runtime, JavaScript runtime, TextKit semantic substitution, telemetry, persistence, or third-party production runtime;
- the G5-R qualification environment and formal zero-external-display predicate.

The G6-R scope comparator rejects every product or acceptance delta. Permitted deltas are limited to revision identity, parent pointers, implementation-plan authority, execution-readiness schema, planning tools, planning tests, plan-review evidence, and plan-adoption status.

## Archive layout

The embedded parent subtree is exact, not abbreviated by the machine authority: Task 1 writes all 148 destination paths to `Tools/G6PlanAuthoring/parent-snapshot-paths.txt`, and Task 2 copies and verifies those paths byte-for-byte with their observed Git mode `100644`. The topology below identifies the G6-R-owned roots and singletons; `implementation-plan/verification/payload-index.json` is the exhaustive final path and Git-mode authority.

```text
docs/contracts/monaco-editor-0.56.0/g6-r/
  README.md
  SHA256SUMS
  adoption-record.json
  verify-contract.mjs
  artifacts/
    parent/
      g5-r/
    monacode-g6r-authoritative-manifest.json
    monacode-g6r-implementation-plan-manifest.json
    monacode-g6r-execution-schema.json
    monacode-g6r-command-dependency-manifest.json
    monacode-g6r-interface-contract-manifest.json
    monacode-g6r-audit.mjs
    global-g6r-authoritative-contract.html
  implementation-plan/
    README.md
    00-master-plan.md
    phase-00-scaffold-harness.md
    phase-01-base-model.md
    phase-02-model-semantics.md
    phase-03-projection-layout-rendering.md
    phase-04-input-transfer-accessibility.md
    phase-05-public-surface-features.md
    phase-06-language-lsp-snippet-markdown.md
    phase-07-diff-services-host-source-closure.md
    phase-08-release-candidate-distribution.md
    phase-09-acceptance-release-verdict.md
    lib/
    runtime/
    schemas/
    tests/
      fixtures/
    verification/
    verify-plan.mjs
```

The final archive contains exactly 232 files, all with exact Git mode `100644`. Before adoption, `implementation-plan/verification/payload-index.json` enumerates all 232 final paths with an exact `producerTask`, `gitMode`, `presence`, and `checksumDisposition`. `presence` is orthogonal to checksum handling: it is `present` exactly when `producerTask <= completedThroughTask`, and otherwise `planned`; the writer rejects a physical path that disagrees with that predicate. `checksumDisposition` is `sha256` for 229 rows, `self-index` for the payload-index row, and `hash-cycle-excluded` only for `SHA256SUMS` and `adoption-record.json`. A present `sha256` row carries and verifies its byte hash; a planned row carries no byte hash; the three non-`sha256` rows never carry a self-referential hash. Every row has one exact authoring-task producer, including Task 33 for the two exclusions. The index is refreshed in the same commit as each candidate payload change. Candidate verification rejects an unknown path, mode drift, a stale present hash, a presence/producer-cursor disagreement, or a future path without one producer. The exact materialization sequence is 223 present and 9 planned through Task 26, 228/4 through Task 27, 229/3 through Task 28, 230/2 through Tasks 29-32, and 232/0 through Task 33.

At adoption, `SHA256SUMS` contains exactly 230 rows covering `README.md`, `verify-contract.mjs`, every file under `artifacts/`, and every file under `implementation-plan/`, including the final payload index. It excludes only `SHA256SUMS` and `adoption-record.json`, which prevents a hash cycle. Task 33 computes the final authoritative manifest, HTML, README, phase index, and projected 232-row payload index entirely in memory; computes `SHA256SUMS` over the resulting final bytes; computes the adoption record from that checksum-index hash; then publishes the seven final paths in a fixed journaled sequence. A retry accepts only an exact journal prefix or the exact complete output set, so no placeholder or partially adopted state can pass verification. G6-R adoption selects the exact checksum-index hash plus the contract, plan, audit, review, cold-checkout, and repository phase-index hashes. The G6 archive verifier remains self-contained and verifies only G6-owned authority; Task 33's separate repository-integration verifier checks the external phase index against its selected hash. `artifacts/parent/g5-r/` is a byte-for-byte snapshot of all 148 files and 4,050,132 bytes in the adopted G5-R archive, including its 144-row checksum index, adoption record, verifier, product-contract artifacts, plan authority, tests, and review evidence. G6-R runs the embedded G5-R verifier and outer-hashes every embedded byte; archive verification and plan-authority resolution then use only files inside G6-R. Product tasks consume repository producers or the exact controlled source-acquisition records selected by that self-contained authority.

## Execution-ready task model

G6-R retains all 200 G5-R product task IDs and their product ownership. Each evidence contract replaces only the root segment `artifacts/acceptance-evidence/g5-r/` with `artifacts/acceptance-evidence/g6-r/`, preserving the complete phase/task suffix and preventing any G6 run from overwriting G5 evidence. Each task is rewritten into an ordered machine record. The order is normative and uses these stages:

1. `preflight`: verify branch-independent prerequisites, dependency evidence, tool versions, environment class, input hashes, and permitted repository state.
2. `test-authoring`: create the exact test, fixture, or task-local checker required by Red verification; when a Swift Red command introduces a new source declaration, also create the exact compile-only Red scaffold selected by the interface manifest.
3. `red`: run the declared failing check and verify its exact failure class and identity; missing-symbol, syntax, linker, or unrelated package-build failure does not satisfy Red.
4. `implementation`: replace every Red scaffold and create or modify only the declared production and support files using exact interfaces and bounded operations.
5. `green`: run the focused passing verification and all task-owned regression tests.
6. `commit`: invoke only `planctl commit-task`; it stages the exact allowlisted product paths, rejects every unrelated product mutation, and creates the exact ASCII subject `monacode: complete <TASK_ID>` without staging the task evidence path.
7. `evidence`: record command results, hashes, environment identity, repository state, the actual product commit, and assertions in the fixed evidence schema, then commit only that evidence path with subject `evidence(monacode): complete <TASK_ID>`; only a verified evidence commit can move the task to `passed`.

A task can contain multiple steps within a stage. A stage cannot be omitted. A task that requires no new test file records an explicit plan-owned baseline checker and its archive hash in `test-authoring`; an empty or prose-only stage is invalid.

Each Red scaffold contains the full selected declaration plus the exact marker `G6_RED_SCAFFOLD:<task-id>:<source-path-sha256>`, where `source-path-sha256` is the SHA-256 of the UTF-8 bytes of the normalized repository-relative source path using `/` separators and no leading `./`. Its task test resolves the declared source paths, checks for that marker before invoking behavior, and emits the inherited G5-R Red output marker when any scaffold remains. Scaffold bodies are compile-only and are never invoked in the Red control. Green requires every marker absent before behavioral assertions run. This makes Red a declared test failure rather than a compiler failure while preventing a scaffold from satisfying Green.

Every task record contains:

- immutable task ID, phase, title, platform scope, and task-record SHA-256;
- exact direct dependencies and transitive input producers;
- exact contract identities and ownership rows;
- path records for baseline inputs, created files, modified files, tests, fixtures, generated evidence, and temporary outputs;
- source-input records selecting a baseline/dependency path or an exact HTTPS acquisition URL, allowed host and redirect chain, expected byte count, maximum byte count, SHA-256, license identity, optional closed archive-entry and expanded-byte contract, output path/disposition, and owning task stage;
- exact Red-scaffold records with declaration text and hash, sentinel behavior, source path, test-authoring owner, implementation replacement owner, and required absence from the final source tree;
- one exact task-test contract selecting every test/checker path, target, test symbol or Node name pattern, fixture value/hash, ordered assertion, Red/Green leaf mapping, expected marker, failure class, and authoring owner;
- exact Swift declarations, JSON schemas, or command-line contracts produced and consumed;
- ordered steps with command IDs and mutation policies;
- exact completion assertions;
- exact evidence path and schema version;
- exact product-commit author/committer `zhengrenzhe <zhengrenzhe0416@outlook.com>`, subject `monacode: complete <TASK_ID>`, staged path set, parent commit, and evidence exclusion;
- exact evidence-commit author/committer, subject `evidence(monacode): complete <TASK_ID>`, sole parent equal to the product commit, and diff containing only the task evidence path. G5-R contains zero task commit-message fields and zero `git commit` commands, so both G6-R subjects are new planning governance rather than inherited product behavior.

The plan contains no task ranges, implicit predecessor prose, aggregate ownership in place of identity rows, or branch-name assumptions.

## Structured command model

Free-form shell strings are not execution authority. Every command uses a structured record:

```json
{
  "id": "P00-T001.RED.001",
  "stage": "red",
  "cwd": ".",
  "timeoutMs": 30000,
  "network": {
    "mode": "forbidden",
    "allowedHosts": []
  },
  "environment": {
    "inherit": ["PATH", "TMPDIR"],
    "set": {
      "LC_ALL": "C",
      "TZ": "UTC"
    }
  },
  "pipeline": {
    "pipefail": true,
    "processes": [
      {
        "file": "/usr/bin/xcrun",
        "args": ["swift", "package", "dump-package"]
      },
      {
        "file": "/opt/homebrew/Cellar/node/26.7.0/bin/node",
        "args": ["docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/assert-package-graph.mjs"]
      }
    ]
  },
  "inputs": [
    {
      "path": "docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/assert-package-graph.mjs",
      "availability": "baseline",
      "sha256FromArchivePath": "implementation-plan/runtime/assert-package-graph.mjs"
    }
  ],
  "mutations": {
    "repository": "forbidden",
    "temporary": ["${TMPDIR}/monacode-plan/**"]
  },
  "expected": {
    "exit": 1,
    "stdoutIncludes": ["PLAN_PACKAGE_GRAPH_MISSING"],
    "stderrIncludes": [],
    "stdoutExcludes": ["MODULE_NOT_FOUND"],
    "stderrExcludes": ["MODULE_NOT_FOUND"]
  }
}
```

The archive verifier resolves `sha256FromArchivePath` against the selected checksum row and compares the resulting exact SHA-256 before command execution.

Allowed command-record forms are `process`, `all-success`, and `pipeline`. `all-success` is an ordered list of two or more processes and starts each process only after the preceding process exits zero; `pipeline` connects an ordered list of two or more processes and requires `pipefail: true`. Composition cannot nest. Each leaf process uses an absolute executable path plus an argument array. Swift leaves use `/usr/bin/xcrun`; Node leaves use `/opt/homebrew/Cellar/node/26.7.0/bin/node`. The 400 inherited G5-R command records normalize to 393 single-process records, five all-success records, and two pipeline records, containing 407 leaf processes: 359 Swift-test, 42 Node-test, four Node-script, and two Swift-package leaves. Shell evaluation, command substitution, implicit glob expansion, aliases, interactive prompts, and unbounded environment inheritance are forbidden. A command that needs file discovery receives an explicit sorted input list or invokes a plan-owned tool that returns a canonical sorted list.

All 400 inherited verification commands set `network.mode` to `forbidden`; arbitrary command allowlists are invalid. Twenty inherited Node-test Red records place `--test-name-pattern` after the test-file positional argument. Node.js 26.7.0 treats that ordering as non-filtering; the G6 converter normalizes each to `node --test --test-name-pattern VALUE FILE` and tests the selected-case count. This argv correction is planning executability repair and does not alter the retained product assertion or expected marker. G6-R authoring and final-verification commands also enumerate every test file as a literal argument; no plan step delegates its test set to shell glob expansion or directory discovery.

Every command declares:

- repository-relative working directory;
- executable and argument arrays;
- timeout;
- inherited and fixed environment keys;
- network mode and exact host allowlist;
- input paths and their stage-time availability;
- permitted repository and temporary mutations;
- exact exit status;
- required and forbidden stdout and stderr fragments.

## Command dependency proof

`command-paths.mjs` extracts every repository-local input from structured commands without parsing shell prose. Each input resolves to exactly one of these sources:

- `baseline`: present and hash-selected in the clean G6-R checkout;
- `dependency`: created by one unique transitive predecessor task whose verified evidence is required by preflight;
- `task-step`: created by an earlier step in the same task;
- `temporary`: created by an earlier process in the same command under the declared temporary mutation root.

Every other input produces `PLAN_COMMAND_INPUT_UNAVAILABLE`. A path produced only by a later task produces `PLAN_COMMAND_INPUT_FROM_FUTURE`. Multiple producers produce `PLAN_COMMAND_INPUT_AMBIGUOUS`. A baseline path with a hash mismatch produces `PLAN_COMMAND_INPUT_HASH_MISMATCH`.

The same repository-path proof applies to test files, fixtures, schemas, comparison data, output directories, and evidence validators. Executables are external toolchain inputs and resolve only through the exact lock below; a missing path, symlink-target change, byte-hash change, version change, SDK change, or architecture change produces a preflight finding before a product command starts.

Remote implementation inputs use a separate `SourceAcquisition` record and never masquerade as a local command input. `planctl acquire-source` accepts only HTTPS, rejects credentials and ambient proxy variables, enforces the exact declared host and redirect chain, caps bytes before writing, streams into the declared controller-temporary or repository task-step partial path, verifies exact byte count and SHA-256, fsyncs, and atomically renames to the declared output. A host, redirect, timeout, byte count, hash, license, or output-path mismatch leaves no promoted source and blocks the task. Repeated acquisition with matching bytes is idempotent; non-matching existing bytes fail closed. A temporary source cannot satisfy a later task; a later consumer selects a committed derived artifact produced by the acquiring task or repeats the same exact acquisition contract.

`planctl run-command` is the only verification-command executor. It resolves the selected command from the adopted plan, re-runs task preflight, creates a realpath-normalized temporary root, sets exact locale, time-zone, HOME, cache, and PATH values, and wraps every leaf in the locked `/usr/bin/sandbox-exec`. The generated profile permits normal reads and process execution, denies all network access, and permits writes only below the command temporary root. The executor implements ordered all-success short-circuiting, connected pipelines with aggregate pipefail, timeout termination, ordered leaf exit/stream hashes, expected-result matching, repository before/after snapshots, and canonical evidence output. Direct execution of a leaf cannot satisfy task evidence.

## Development toolchain lock

G6-R plan authoring, plan verification, and product-task preflight use the current-device lock observed on 2026-08-15:

- Node executable `/opt/homebrew/Cellar/node/26.7.0/bin/node`, SHA-256 `1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040`, version `v26.7.0`;
- `/usr/bin/xcrun`, SHA-256 `4bc0cc7099775fbe35c653ceb09e0e393d2e5ada024db872e0eb8c43500b4dc6`;
- `/usr/bin/sandbox-exec`, SHA-256 `e3d7a792c58a5d3783d2f7274c82d70062393830d8cb1ded713ca554a470bd2f`;
- Swift executable selected by `xcrun --find swift` at `/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift`, SHA-256 `2ed38571e92c0283091838c1649e27650ad9c99950288e883c7b2dc6c4ce89fb`, Swift `6.3.3` with `swiftlang-6.3.3.1.3`, target `arm64-apple-macosx26.0`;
- Chrome comparator executable `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`, SHA-256 `ee37661755341e9fc1babf9c20ec09d6a36e50aa8713ceb08082f8bbe2d8217d`, version `151.0.7922.138`, and selected ICU data `/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/151.0.7922.138/Resources/icudtl.dat`, 10,876,560 bytes with SHA-256 `9f48c7f9c7c94d516a14870707e910ab94d75ae640ff6842c4af53276cd26ebe`;
- Xcode `26.6`, build `17F113`, and macOS SDK `26.5` at `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.5.sdk`;
- `/usr/bin/git`, SHA-256 `44a68ddc1983d6cff3fd35ba3f9ba5f82004216f1dcde69892b3d1b06e408698`, version `2.50.1 (Apple Git-155)`;
- `/usr/bin/bsdtar`, SHA-256 `bc069dd7ef2ecea4c27ff9daa97f4ba4c5a1a41938bad8050e96bce5daa64346`, version `3.5.3` with libarchive `3.7.4`;
- `/usr/sbin/system_profiler`, SHA-256 `6b868d95b01d44045fc434d5e867cd9ac5de15634fef126522d0a6919ccd2652`;
- macOS `26.6.1` build `25G76` on `arm64`.

Task 1 records these values in `baseline-inventory.json`. `planctl preflight`, the clean-checkout tool, and command audit compare all locked fields exactly and fail before execution on any mismatch. A changed lock requires a new planning-governance revision; it is never accepted as runtime drift.

## File-state simulation

`file-state.mjs` simulates the repository state from a clean G6-R checkout through all 200 tasks in topological order. The simulator does not claim product behavior. It proves that every declared task operation has a deterministic input and output state.

For every step, the simulator validates:

- a created path does not already exist unless the step declares exact idempotent content;
- a modified path exists and has one unique prior create owner or baseline hash;
- a consumed path exists at that exact stage;
- every Swift Red command that introduces a source declaration has one compile-only scaffold before Red;
- every scaffold is replaced during the same task implementation stage;
- a deleted path is explicitly owned and recoverable through version control;
- temporary outputs remain under the command's temporary root;
- generated evidence cannot be consumed before its producer passes;
- commit paths equal the task's repository mutation set;
- no later task silently overwrites an earlier task's ownership;
- conditional Metal paths exist only in the frozen predicate branch selected by Phase 03 evidence.

The simulator emits a canonical per-task state hash. The final state contains every planned production, test, tool, fixture, candidate, and evidence path exactly once under its declared disposition.

## Interface-contract proof

Symbolic interface names alone are forbidden. Each produced interface records an exact contract:

- source path and owning target;
- Swift declaration or JSON schema identity;
- generic parameters and constraints;
- argument labels, types, return type, error type, visibility, availability, actor isolation, ownership, and `Sendable` disposition;
- raw UTF-16, indexing, cancellation, ordering, and lifetime invariants when applicable;
- source contract identity and behavioral oracle;
- canonical signature hash.

Every consumer references the producer task and canonical signature hash. A mismatch produces `PLAN_INTERFACE_SIGNATURE_MISMATCH`. A consumer without a transitive dependency produces `PLAN_INTERFACE_ORDER`. A duplicate producer produces `PLAN_INTERFACE_PRODUCER_DUPLICATE`.

`planctl interfaces compile` generates a temporary, non-product Swift package containing declaration stubs from the interface manifest and type-checks the three target boundaries with the pinned Swift compiler. The generated package is never committed and cannot be used as product implementation evidence.

## Implementation-operation precision

Each implementation step specifies:

- exact files and declarations affected;
- exact data structures and algorithms selected by the frozen contract;
- preconditions, postconditions, state transitions, error behavior, cancellation behavior, concurrency isolation, and deterministic ordering;
- required complexity and bounded-resource rules;
- exact Monaco comparator oracle, fixture, or native semantic replacement;
- explicit exclusions;
- the focused test cases that prove the operation.

Normative prose fields use a closed imperative grammar. The exact forbidden lexicon is `TBD`, `TODO`, `FIXME`, `maybe`, `probably`, `possibly`, `should`, `could`, `as needed`, `appropriate`, `similar to`, `and so on`, `待定`, `可能`, `应该`, `大概率`, `酌情`, `视情况`, `以后补充`, and `后续决定`, compared case-insensitively where case exists. Unresolved alternatives and unowned future work are also rejected by schema shape. Quoted mutation-fixture payloads are exempt from the prose lint only inside a typed fixture input field; fixture expectations and normative task fields remain subject to validation. Conditional renderer work is accepted only because its predicate, inputs, branches, outputs, and downstream dependency join are fully machine-defined.

## Evidence and task-state model

Product implementation evidence remains outside the documentation archive at:

`artifacts/acceptance-evidence/g6-r/`

These 200 evidence paths are plan-governed workspace files and are not members of any product task commit boundary. The current task's `running` evidence and journals are untracked; every prior `passed` evidence path is tracked by its exact evidence-only commit and must remain byte-valid and unchanged. Worktree audits classify only those states; every other evidence path or mutation is a finding. Product commit stages never stage evidence. `planctl begin-task` uses `EVIDENCE_PATH.g6-beginning` to create one realpath-normalized controller-owned task root whose name and mode-0600 marker are bound to a fresh 256-bit token, then atomically publishes the `running` evidence record. A repeated invocation resumes only the journal states produced by those ordered operations. Verification commands receive fresh child roots that are removed after each command; controlled source acquisitions remain below the task root until their same-task implementation operations consume them. No later task can consume a temporary output. `commit-task` uses a separate `EVIDENCE_PATH.g6-committing` journal before it touches the index; it can resume its own partial staging or exact already-created product commit and rejects the same states without that journal. The evidence stage runs after the product commit, records that commit, cleans the owned task root, publishes `passed`, stages only the evidence path, and creates one evidence-only commit. The evidence JSON does not contain its own commit hash; `verify-evidence` proves the product commit is on the current first-parent history, selects its immediate first-parent successor as the evidence commit, validates parent/tree/blob/identity/message, and rejects any later first-parent commit that touches the evidence path. This removes both a future-commit reference and a Git hash self-reference while retaining every completed task artifact in the repository.

Every task evidence record contains:

- schema version and task ID;
- selected G6-R plan hash and task-record hash;
- dependency evidence hashes;
- current stage, ordered attempt IDs, task-root realpath, SHA-256 of its 32-byte ownership token, and beginning/committing/finalizing journal protocol version; only the short-lived beginning journal and mode-0600 root marker contain the raw token bytes;
- repository commit before and after the task;
- evidence-commit subject, identity, expected sole parent, and selector mode `external-git`; the record omits its own blob hash and evidence-commit object ID, both of which `verify-evidence` derives from Git;
- command IDs, exit statuses, stdout and stderr hashes, and duration;
- created and modified file hashes;
- test counts and assertion identities;
- environment observation hash with forbidden identity fields removed;
- mutation-policy result;
- task-root tombstone and cleanup result;
- completion assertion results;
- final state `passed` only when every field validates.

Evidence states are exactly `absent`, `running`, `failed`, and `passed`. `begin-task` performs preflight, records the exact base commit in its beginning journal, creates the task root and token marker, atomically publishes `running`, and removes the journal. Command and acquisition execution append canonical attempt results. An expected result advances the stage; an unexpected Red or Green result stays in `running`, records the failed attempt, and leaves the task at `test-authoring` or `implementation` respectively so the exact stage-owned files can be corrected and the check rerun. An invariant failure moves the record to `failed`. Before a product commit exists, `resume-task` accepts `failed` or `running` with exact plan-derived crash residue only when `HEAD` still equals the recorded base, the index is empty, all worktree changes remain within the current task mutation policy, the task-root ownership token matches, and plan/task hashes are unchanged. It removes only exact plan-derived `.g6-part` files or token-owned command children whose final target still has its recorded prior hash or declared-absent state; each candidate must be a non-symlink regular file or directory below the selected task/evidence workspace. `commit-task` first journals its exact base, boundary, file hashes, identity, and subject; it then accepts only the empty, exact partial-boundary, or exact full-boundary index states generated under that journal, creates at most one matching product commit, appends it to running evidence, and removes the journal. A retry after commit recognizes only that exact direct single-parent product commit whose parent is the recorded base. After `commit-task` succeeds, the only recovery is idempotent `finalize-evidence` against that same product commit. Finalization journals the prehashed passed record, task-root cleanup, evidence path, and evidence-commit contract; cleans only the token-owned root; publishes and stages only the passed evidence path; creates at most one evidence commit whose sole parent is the product commit; verifies its blob/tree/identity/message; and removes the journal. A retry recognizes only ordered prefix states of that protocol, including an exact already-created evidence commit, and resumes at the first incomplete operation. At current-task finalization, the task becomes `passed` only when the journal is absent, `HEAD` is that evidence commit, its parent is the product commit, and its only diff is the selected evidence blob. After later tasks advance `HEAD`, historical validation requires the product commit on the current first-parent ancestry, the same evidence commit as its immediate successor, and zero later first-parent commit touching that evidence path. This makes every journaled crash point recoverable without changing or duplicating the product commit and keeps prior evidence valid without requiring an old commit to remain `HEAD`. A skipped command, absent cell, stale plan hash, missing dependency hash, malformed record, unexpected mutation, prematurely staged evidence path, later evidence-path mutation, or commit mismatch blocks advancement with a stable finding. There is no warning-only state for a required field and no automatic rollback or worktree repair.

## Plan execution controller

`planctl.mjs` provides these non-interactive commands:

- `verify-archive`: verify G6-R selected hashes and parent-scope equality;
- `audit`: run every schema, graph, ownership, boundary, command, file-state, interface, evidence, and ambiguity rule;
- `simulate`: compute all 200 task stage transitions and final path state;
- `begin-task --task TASK_ID --evidence-path PATH`: run task preflight, create the owned task root, and atomically create the exact `running` evidence record;
- `resume-task --task TASK_ID --evidence-path PATH`: resume one pre-commit `failed` task or one `running` task with exact controller crash residue only after the fixed base, index, mutation, task-root, authority, and transient-target checks pass;
- `preflight --task TASK_ID`: validate exact prerequisites without modifying repository files;
- `preflight --all`: validate baseline inputs, every simulated task transition, and the exact future enforcement point of every qualification predicate without creating a live `QEnvironmentID` or claiming a current formal cell;
- `run-command --id COMMAND_ID --evidence-path PATH`: execute one selected Red or Green command under the locked sandbox and write its canonical result only to the declared task evidence path;
- `acquire-source --task TASK_ID --source SOURCE_ID`: retrieve one declared remote implementation input under its HTTPS, host, redirect, byte, hash, license, and output-path contract;
- `commit-task --task TASK_ID --evidence-path PATH`: verify Green, the base commit, author/message contract, exact worktree boundary, empty index, and evidence exclusion; stage exact literal paths and create the single product commit with hooks and signing disabled;
- `finalize-evidence --task TASK_ID --path PATH`: after the product commit, validate its parent, identity, message, tree, boundary, and task results; clean the token-owned workspace; publish the exact `passed` record; and create or resume its one evidence-only commit;
- `interfaces compile`: type-check generated interface stubs;
- `next --evidence-root PATH`: return the single executable next task or a fixed blocking finding;
- `verify-evidence --task TASK_ID --path PATH`: validate one completed task record;
- `render`: prove Markdown task markers and human text match machine records.

Every command emits canonical JSON and exits non-zero on any finding. Only `commit-task` creates a product commit; only `finalize-evidence` creates its evidence-only child commit; only `begin-task`, command/acquisition execution, `resume-task`, and `finalize-evidence` mutate the selected evidence/task workspace; and no controller command automatically repairs, resets, amends, or rolls back product state.

The current external display is valid for G6-R plan authoring and product development. Live qualification is evaluated only by `preflight --task`/`begin-task` for the selected formal Phase 09 task; those tasks require the frozen zero-external-display predicate and record a fresh `QEnvironmentID`. `preflight --all` proves this enforcement exists and emits `liveQualificationClaims=0`; it never treats the authoring display observation as formal evidence.

## Clean-checkout verification

G6-R adoption uses a realpath-normalized temporary directory. The verifier resolves one commit object, recursively enumerates its Git blobs and declared sizes with locked `/usr/bin/git ls-tree -r -l -z`, and rejects more than 16,384 blobs, any blob over 67,108,864 bytes, aggregate blob bytes over 1,073,741,824, any path over 4,096 UTF-8 bytes, or any component over 255 UTF-8 bytes before archive generation. It accepts only `100644` and `100755` for the repository while requiring the payload index's fixed `100644` mode for every materialized G6-R row and requiring every planned G6-R row to be absent. Every Git child receives no inherited `GIT_*` value, then exact `GIT_CONFIG_NOSYSTEM=1`, `GIT_CONFIG_GLOBAL=/dev/null`, `GIT_TERMINAL_PROMPT=0`, and `GIT_OPTIONAL_LOCKS=0`; the archive child additionally receives command arguments `-c tar.umask=0002`. The verifier streams locked `git archive` output under a 1,342,177,280-byte cap and lists it with locked `/usr/bin/bsdtar` under per-stream 8,388,608-byte caps before extraction. Tar regular-file paths and modes must equal Git blob paths and modes exactly, with fixed mappings `100644 -> -rw-rw-r--` and `100755 -> -rwxrwxr-x`; every directory mode is exactly `drwxrwxr-x`. Tar directory paths must equal the unique proper directory prefixes of Git blob paths exactly. Every bytewise duplicate, collision under the per-component key `component.normalize('NFC').toLowerCase().normalize('NFC')`, other mode, type, traversal, invalid UTF-8, or CR/LF path is rejected. The verifier also reproduces the topology with exclusive create operations in a separate probe root on the extraction target volume and rejects a filesystem-observed collision before extraction. After extraction, every file's `lstat` size and locked `git hash-object --no-filters` object ID must equal its selected `ls-tree` row before any exported byte executes. It then rechecks every materialized G6-R row as a non-executable regular file, rechecks every planned row as absent, clears repository-specific environment variables, and runs:

1. G4-R verification;
2. G5-R verification;
3. G6-R archive verification;
4. G6-R plan unit and mutation tests;
5. `planctl audit`;
6. `planctl simulate`;
7. `planctl preflight --all`;
8. `planctl interfaces compile`;
9. Markdown rendering equality;
10. candidate payload-inventory verification.

After the ten exported-checkout commands, the source checkout separately runs `git diff --check`; this source invariant is recorded outside the ten-command result array.

The pre-adoption clean-checkout result records the exported commit, command IDs, exit codes, finding counts, and output hashes in `cold-checkout-preflight.json`. Candidate payload verification proves that every tracked G6-R payload path is classified and selected by the candidate authority without relying on the final checksum index. After adoption creates `SHA256SUMS`, the final clean-checkout verification additionally checks every selected checksum row. Adoption requires zero findings and zero missing commands.

## Qualification environment boundary

Development and formal product acceptance use separate predicates:

- Plan authoring, plan verification, and product development require the pinned macOS, Xcode, SDK, Swift, architecture, and toolchain class. An external display does not invalidate these activities.
- Formal C01-C10 and P00-P13 evidence requires the complete G5-R qualification predicate, including built-in display only and `externalDisplayCount == 0`.

The current observation contains one external display. G6-R records this as an unqualified development observation. It cannot be used as formal product acceptance evidence.

## Adversarial verification matrix

The G6-R adversarial suite includes permanent negative fixtures for exactly 35 independent attack families. The ordered bullets below define the exact family keys `AF01` through `AF35` by position:

- missing baseline command input;
- command input produced by a future task;
- duplicate command-input producer;
- baseline or remote-source byte-count, size-cap, hash, or promoted-output drift;
- wrong command working directory;
- shell interpolation or command substitution;
- implicit or empty glob expansion;
- missing pipeline `pipefail` semantics;
- changed all-success short-circuit order;
- Node test-runner option left after its positional test file;
- ambiguous stdout versus stderr expectation;
- absent timeout;
- interactive command;
- undeclared network access, remote source, host, or redirect host;
- inherited environment leakage;
- repository mutation outside the allowlist;
- task-root escape, foreign or reused ownership token, command-child leakage, or cleanup outside the selected root;
- missing or ambiguous task-test contract, unselected/duplicate Red/Green leaf, or test/checker created after its Red command;
- missing, extra, or unreplaced Red scaffold;
- Red satisfied by compilation, linking, or a failure class other than its declared assertion class;
- modified file without baseline or create owner;
- deleted file without explicit ownership;
- commit boundary smaller or larger than task mutations, wrong author/committer/message/parent, enabled hooks/signing, or a direct Git commit that bypasses `commit-task`;
- interface signature, isolation, availability, or ownership drift;
- consumer without transitive producer dependency;
- dependency cycle or unknown task ID;
- evidence finalized before the product commit, current evidence staged or tracked before finalization, prior passed evidence changed or missing, evidence-commit identity/message/parent/boundary drift, evidence self-reference, or evidence consumed before producer completion;
- stale plan/task/workspace hash or a recovery transition outside the exact pre-commit/post-commit rules;
- false `passed`, `implemented`, `released`, or acceptance claims;
- conditional Metal path selected without the renderer-owned predicate;
- product-scope or performance-threshold delta from G5-R;
- placeholder or unresolved alternative in normative task fields;
- non-canonical task order or Markdown drift;
- archive file omitted from `SHA256SUMS` or a G6-R archive Git mode different from indexed `100644`;
- mutation of embedded parent authority bytes.

Each fixture declares its exact expected finding IDs. The round ledger contains exactly 75 top-level attack IDs: 12 in R1, 22 in R2, 29 in R3, and 12 in R4. Every top-level attack selects one or more of the 35 family keys and contains a closed ordered variant list; every distinct named bypass or compound-case variant above has its own variant ID and fixture record. The test fails when a fixture is accepted, rejected under the wrong finding, produces extra findings, or when a family key, top-level attack, or required variant is missing, duplicated, prose-only, or not executed exactly once. Every production audit rule has at least one positive control and one negative mutation.

## Review rounds

G6-R requires four blocking adversarial rounds:

1. `R1 authority and scope`: prove G5-R product equality, archive self-containment, hash topology, and truthful status.
2. `R2 graph and state`: attack task dependencies, file-state transitions, ownership, interfaces, evidence ordering, and commit isolation.
3. `R3 command execution`: attack all 400 structured commands, local and remote input availability, process grammar, sandbox enforcement, environment, network, timeout, expected results, evidence provenance, and mutation boundaries.
4. `R4 cold checkout`: reproduce the complete plan audit, simulation, interface compile, and baseline preflight from the exported candidate commit.

Each successful round records attack ID, variant ID, mutated input, expected finding, observed finding, rerun command, final status, and exact `resolutionCommit: null`. If any observed result differs from its expected finding array, the runner emits canonical failure JSON, writes no review byte, creates no commit, and stops G6-R adoption. This plan authorizes no ad hoc repair because an undiscovered defect has no predeclared mutation boundary; continuation requires a separately user-authorized planning revision. The final record requires `missed=0`, `unresolvedFindings=0`, `missingVariants=0`, `duplicateVariants=0`, equality `passedVariants = variants`, and `resolutionCommit: null` for every variant.

## Failure behavior

All plan verification fails closed. The tooling does not skip, downgrade, infer, or auto-correct a required field. A missing executable, unsupported tool version, unavailable input, stale environment, malformed fixture, timeout, unexpected repository change, or absent evidence prevents task start or adoption and returns a stable finding ID.

No plan-review artifact counts as product implementation evidence. No clean-checkout preflight counts as C01-C10 or P00-P13 evidence. G6-R can be labeled `execution-ready` only after all planning gates pass; MonaCode remains `implementation: not-started` and `releaseAcceptance: not-passed` at G6-R adoption.

## Deliverables

The revision delivers:

- the complete immutable `g6-r/` archive;
- the G6-R authoritative contract and execution-ready plan manifests;
- exact human plans for phases 00-09;
- structured command, interface, dependency, and evidence manifests;
- plan execution controller and validation libraries;
- sandboxed verification-command execution and controlled source acquisition;
- positive, negative, and mutation tests;
- clean-checkout preflight evidence;
- four-round adversarial review record;
- checksum index, adoption record, and global verifier;
- a repository authority index pointing future development to G6-R.

## Acceptance criteria

G6-R is adopted only when all of these statements are proven in the current candidate commit:

- G4-R and G5-R remain byte-valid and pass their original verifiers;
- G6-R product and acceptance scope equals G5-R outside the fixed plan-governance allowlist;
- all 200 task IDs and 3,582 contract ownership rows are present and unique;
- all 400 Red/Green commands have structured command records and all 407 leaf processes have structured executable/argument arrays;
- all 139 Swift-Red tasks have exact compile-only scaffold contracts for their 249 newly created Swift source paths, every Red fails under its declared behavioral assertion, and no scaffold survives implementation;
- all 200 tasks have one exact task-test contract and every Red/Green leaf maps to its declared test/checker case and ordered assertions;
- every task has all seven ordered stages;
- every task has exactly one `begin-task`, one token-bound task workspace, one `commit-task` with the exact author/committer/message/boundary contract, and one post-commit `finalize-evidence` action;
- all 200 product commits exclude evidence, and all 200 passed evidence paths are retained by exact evidence-only child commits with the required identity, subject, sole parent, one-path diff, and no self-reference in their JSON bytes;
- every repository-local command input has one valid stage-time source;
- every external implementation source has one complete local producer or controlled acquisition record, and every acquired byte passes its host, redirect, size, hash, license, and output-path contract;
- every verification command runs through the locked sandbox executor with network denied, writes confined to its temporary root, and canonical leaf evidence recorded;
- every interface consumer selects one exact producer signature;
- complete file-state simulation has zero findings;
- interface-stub compilation has zero errors;
- every audit invariant has positive and negative coverage;
- every normative file is indexed and hash-verified;
- every one of the 232 G6-R archive paths has indexed and verified Git mode `100644`;
- clean-checkout audit, simulation, preflight, and interface compilation have zero findings;
- four adversarial rounds report zero missed attacks and zero unresolved findings;
- normative plan fields contain no placeholders or unresolved alternatives;
- G6-R status remains truthful: plan `execution-ready`, implementation `not-started`, release acceptance `not-passed`.

Only this acceptance result authorizes product development to begin at `P00-T001` under G6-R.
