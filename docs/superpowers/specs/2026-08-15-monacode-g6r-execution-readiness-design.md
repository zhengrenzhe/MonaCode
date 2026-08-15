# MonaCode G6-R execution-readiness revision design

Status: approach approved on 2026-08-15; written specification awaits user confirmation.

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

```text
docs/contracts/monaco-editor-0.56.0/g6-r/
  README.md
  SHA256SUMS
  adoption-record.json
  verify-contract.mjs
  artifacts/
    parent/
      monacode-g5r-authoritative-manifest.json
      monacode-g5r-implementation-plan-manifest.json
      adoption-record.json
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
      audit.mjs
      command-grammar.mjs
      command-paths.mjs
      file-state.mjs
      interfaces.mjs
      mutation-policy.mjs
      task-state.mjs
      evidence.mjs
      canonical-json.mjs
      findings.mjs
    runtime/
      assert-package-graph.mjs
      planctl.mjs
    schemas/
      task-evidence.schema.json
      task-state.schema.json
    tests/
      archive-verifier.test.mjs
      command-dependencies.test.mjs
      command-grammar.test.mjs
      file-state.test.mjs
      interfaces.test.mjs
      mutation-policy.test.mjs
      task-state.test.mjs
      evidence.test.mjs
      scope-delta.test.mjs
      fixtures/
    verification/
      plan-audit.json
      cold-checkout-preflight.json
      adversarial-plan-review.md
    verify-plan.mjs
```

All listed files are covered by `SHA256SUMS`. G6-R adoption selects the exact checksum-index hash. The parent bytes under `artifacts/parent/` are copied and hash-checked against G5-R before G6-R is assembled; G6-R verification then uses only its own archive.

## Execution-ready task model

G6-R retains all 200 G5-R product task IDs and their product ownership. Each task is rewritten into an ordered machine record. The order is normative and uses these stages:

1. `preflight`: verify branch-independent prerequisites, dependency evidence, tool versions, environment class, input hashes, and permitted repository state.
2. `test-authoring`: create the exact test, fixture, or task-local checker required by Red verification.
3. `red`: run the declared failing behavior and verify the exact failure identity.
4. `implementation`: create or modify only the declared production and support files using exact interfaces and bounded operations.
5. `green`: run the focused passing verification and all task-owned regression tests.
6. `evidence`: record command results, hashes, environment identity, repository state, and assertions in the fixed evidence schema.
7. `commit`: stage the exact allowlisted paths, reject every unrelated path, and create the fixed commit message.

A task can contain multiple steps within a stage. A stage cannot be omitted. A task that requires no new test file records an explicit plan-owned baseline checker and its archive hash in `test-authoring`; an empty or prose-only stage is invalid.

Every task record contains:

- immutable task ID, phase, title, platform scope, and task-record SHA-256;
- exact direct dependencies and transitive input producers;
- exact contract identities and ownership rows;
- path records for baseline inputs, created files, modified files, tests, fixtures, generated evidence, and temporary outputs;
- exact Swift declarations, JSON schemas, or command-line contracts produced and consumed;
- ordered steps with command IDs and mutation policies;
- exact completion assertions;
- exact evidence path and schema version;
- exact commit message and staged path set.

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
        "file": "/usr/bin/env",
        "args": ["node", "docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/assert-package-graph.mjs"]
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

Allowed command forms are `process` and `pipeline`. Each process uses an executable path plus an argument array. Shell evaluation, command substitution, implicit glob expansion, aliases, interactive prompts, and unbounded environment inheritance are forbidden. A command that needs file discovery receives an explicit sorted input list or invokes a plan-owned tool that returns a canonical sorted list.

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

The same proof applies to executables, test files, fixtures, schemas, comparison data, output directories, and evidence validators.

## File-state simulation

`file-state.mjs` simulates the repository state from a clean G6-R checkout through all 200 tasks in topological order. The simulator does not claim product behavior. It proves that every declared task operation has a deterministic input and output state.

For every step, the simulator validates:

- a created path does not already exist unless the step declares exact idempotent content;
- a modified path exists and has one unique prior create owner or baseline hash;
- a consumed path exists at that exact stage;
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

Every task evidence record contains:

- schema version and task ID;
- selected G6-R plan hash and task-record hash;
- dependency evidence hashes;
- repository commit before and after the task;
- command IDs, exit statuses, stdout and stderr hashes, and duration;
- created and modified file hashes;
- test counts and assertion identities;
- environment observation hash with forbidden identity fields removed;
- mutation-policy result;
- completion assertion results;
- final state `passed` only when every field validates.

Evidence states are exactly `absent`, `running`, `failed`, and `passed`. A skipped command, absent cell, stale plan hash, missing dependency hash, malformed record, unexpected mutation, or output mismatch produces `failed`. There is no warning-only state for a required field.

## Plan execution controller

`planctl.mjs` provides these non-interactive commands:

- `verify-archive`: verify G6-R selected hashes and parent-scope equality;
- `audit`: run every schema, graph, ownership, boundary, command, file-state, interface, evidence, and ambiguity rule;
- `simulate`: compute all 200 task stage transitions and final path state;
- `preflight --task TASK_ID`: validate exact prerequisites without modifying repository files;
- `preflight --all`: validate baseline inputs and every simulated task transition;
- `interfaces compile`: type-check generated interface stubs;
- `next --evidence-root PATH`: return the single executable next task or a fixed blocking finding;
- `verify-evidence --task TASK_ID --path PATH`: validate one completed task record;
- `render`: prove Markdown task markers and human text match machine records.

Every command emits canonical JSON and exits non-zero on any finding. The controller never repairs plan or product state automatically.

## Clean-checkout verification

G6-R adoption uses a temporary directory created with `mktemp -d`. The verifier exports the candidate commit with `git archive`, extracts it into the temporary directory, clears repository-specific environment variables, and runs:

1. G4-R verification;
2. G5-R verification;
3. G6-R archive verification;
4. G6-R plan unit and mutation tests;
5. `planctl audit`;
6. `planctl simulate`;
7. `planctl preflight --all`;
8. `planctl interfaces compile`;
9. Markdown rendering equality;
10. checksum verification and `git diff --check` in the source checkout.

The clean-checkout result records the exported commit, command IDs, exit codes, finding counts, and output hashes in `cold-checkout-preflight.json`. Adoption requires zero findings and zero missing commands.

## Qualification environment boundary

Development and formal product acceptance use separate predicates:

- Plan authoring, plan verification, and product development require the pinned macOS, Xcode, SDK, Swift, architecture, and toolchain class. An external display does not invalidate these activities.
- Formal C01-C10 and P00-P13 evidence requires the complete G5-R qualification predicate, including built-in display only and `externalDisplayCount == 0`.

The current observation contains one external display. G6-R records this as an unqualified development observation. It cannot be used as formal product acceptance evidence.

## Adversarial verification matrix

The G6-R adversarial suite includes permanent negative fixtures for these independent attack families:

- missing baseline command input;
- command input produced by a future task;
- duplicate command-input producer;
- baseline hash drift;
- wrong command working directory;
- shell interpolation or command substitution;
- implicit or empty glob expansion;
- missing pipeline `pipefail` semantics;
- ambiguous stdout versus stderr expectation;
- absent timeout;
- interactive command;
- undeclared network access or host;
- inherited environment leakage;
- repository mutation outside the allowlist;
- temporary mutation outside the task root;
- test or checker created after its Red command;
- modified file without baseline or create owner;
- deleted file without explicit ownership;
- commit boundary smaller or larger than task mutations;
- interface signature, isolation, availability, or ownership drift;
- consumer without transitive producer dependency;
- dependency cycle or unknown task ID;
- evidence consumed before producer completion;
- stale plan or task hash in evidence;
- false `passed`, `implemented`, `released`, or acceptance claims;
- conditional Metal path selected without the renderer-owned predicate;
- product-scope or performance-threshold delta from G5-R;
- placeholder or unresolved alternative in normative task fields;
- non-canonical task order or Markdown drift;
- archive file omitted from `SHA256SUMS`;
- mutation of embedded parent authority bytes.

Each fixture declares its exact expected finding IDs. The test fails when a fixture is accepted, rejected under the wrong finding, or produces extra findings. Every production audit rule has at least one positive control and one negative mutation.

## Review rounds

G6-R requires four blocking adversarial rounds:

1. `R1 authority and scope`: prove G5-R product equality, archive self-containment, hash topology, and truthful status.
2. `R2 graph and state`: attack task dependencies, file-state transitions, ownership, interfaces, evidence ordering, and commit isolation.
3. `R3 command execution`: attack all 400 structured commands, local path availability, process grammar, environment, network, timeout, expected results, and mutation boundaries.
4. `R4 cold checkout`: reproduce the complete plan audit, simulation, interface compile, and baseline preflight from the exported candidate commit.

Each round records attack ID, mutated input, expected finding, observed finding, resolution commit, rerun command, and final status. A discovered defect stops adoption. Repair occurs in an explicit commit, followed by all four rounds from the beginning. The final record requires `missed=0` and `unresolvedFindings=0`.

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
- all 400 Red/Green commands have structured command records;
- every task has all seven ordered stages;
- every repository-local command input has one valid stage-time source;
- every interface consumer selects one exact producer signature;
- complete file-state simulation has zero findings;
- interface-stub compilation has zero errors;
- every audit invariant has positive and negative coverage;
- every normative file is indexed and hash-verified;
- clean-checkout audit, simulation, preflight, and interface compilation have zero findings;
- four adversarial rounds report zero missed attacks and zero unresolved findings;
- normative plan fields contain no placeholders or unresolved alternatives;
- G6-R status remains truthful: plan `execution-ready`, implementation `not-started`, release acceptance `not-passed`.

Only this acceptance result authorizes product development to begin at `P00-T001` under G6-R.
