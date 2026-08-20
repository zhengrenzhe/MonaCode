# MonaCode G5-R contract and implementation-plan revision design

Status: design approved on 2026-08-15; written-spec review pending.

## Purpose

Create a new immutable G5-R global revision for MonaCode and replace the current G4-R implementation-plan draft with a complete, machine-verifiable execution plan. G5-R keeps the adopted product behavior and acceptance thresholds unchanged while qualifying the current macOS and Chrome comparator environment and eliminating every confirmed structural defect in the draft plan.

This revision changes documentation, machine contracts, audit tools, and implementation planning only. It does not add product Swift source, generate release artifacts, execute C01-C10 or P00-P13, or claim that MonaCode has passed implementation acceptance.

## Existing authority and facts

The adopted G4-R archive remains immutable at `docs/contracts/monaco-editor-0.56.0/g4-r/`. Its authoritative manifest SHA-256 is `f4d0da0ff6c1ad90ab1376588260afd6c92c1eca236619449c9b6532b5e57021`. The existing verifier reports:

- 72 of 72 archive hashes verified;
- 42 normative layers;
- 17 machine artifacts;
- 555 public declaration paths;
- correctness gates C01-C10;
- performance workloads P00-P13;
- seven required candidate-generated artifacts; and
- zero unresolved product-scope decisions.

The current `docs/implementation-phases/` draft contains 24 Markdown files, 2,181 lines, 99 unique task headings, and 125 completion checkboxes. It is not tracked by Git. It contains these confirmed defects:

- dependency cycles `9.3 -> 9.1 -> 8.9 -> 9.3` and `8.2 -> 9.3 -> 9.1 -> 8.9 -> 8.2`;
- 47 of the 62 retained macOS feature IDs absent as exact plan identities;
- no task identity for `editor.colorize`, `editor.colorizeElement`, or `editor.colorizeModelLine`;
- AppKit types assigned to the Foundation-only `MonaCode` target;
- public API additions after `MonaNativeDeclarationManifest` generation without a regeneration edge;
- package-product, target, resource, and sample-host dependency contradictions;
- plan-review reports sharing names with future product acceptance reports; and
- task steps that omit exact interfaces, red commands, expected failures, green commands, expected results, and evidence paths.

These defects invalidate the current draft as an execution baseline. They do not reopen G4-R product scope.

## Selected approach

G5-R is a complete self-contained sibling archive at:

`docs/contracts/monaco-editor-0.56.0/g5-r/`

All inherited G4-R evidence artifacts are copied byte-for-byte into the G5-R archive and retain their original hashes. G5-R adds a new global human contract, authoritative contract manifest, authoritative implementation-plan manifest, audit module, verifier, adoption record, and archive checksums. The new adoption record promotes exact hashes for both the G5-R contract manifest and the G5-R plan manifest.

This full-snapshot structure is selected because G4-R occupies 2.1 MB. It avoids cross-revision runtime references and lets one directory independently prove its authority graph. An incremental overlay is rejected because it creates cross-directory authority and verifier dependencies. Editing G4-R is rejected by its freeze rule.

## Authority model

G5-R uses this strict authority order:

1. `g5-r/adoption-record.json` selects exact immutable manifest bytes.
2. `g5-r/artifacts/monacode-g5r-authoritative-manifest.json` defines product scope, architecture, environment qualification, acceptance, and freeze rules.
3. `g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json` defines task identities, dependencies, ownership, commands, evidence, and plan completeness.
4. Other G5-R machine artifacts define their owned domains.
5. G5-R human HTML and Markdown explain the machine data without overriding it.
6. G4-R and all earlier adversarial pages remain historical evidence.
7. The archived G4-R implementation-plan draft remains planning history and has no implementation authority.

A hash mismatch, reference mismatch, missing artifact, duplicate owner, dependency cycle, or non-zero unresolved field invalidates adoption. Human prose never overrides a machine record.

## Archive and repository layout

The revision creates this structure:

```text
docs/contracts/monaco-editor-0.56.0/g5-r/
  README.md
  SHA256SUMS
  adoption-record.json
  verify-contract.mjs
  artifacts/
    # Complete inherited G4-R artifact set, byte-identical
    global-g5r-authoritative-contract.html
    monacode-g5r-authoritative-manifest.json
    monacode-g5r-implementation-plan-manifest.json
    monacode-g5r-audit.mjs
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
    verification/
      plan-audit.json
      adversarial-plan-review.md
    verify-plan.mjs

docs/implementation-phases/
  README.md
  history/g4-r-draft/
    # Current 24-file draft set, byte-identical
    SHA256SUMS
```

The existing 24 draft files are preserved before the root plan index is rewritten. `history/g4-r-draft/SHA256SUMS` proves byte identity. The root plan index points to the canonical plan inside the G5-R archive. The G5-R plan manifest records every canonical G5-R plan-document hash, so the complete normative contract and execution plan verify without a cross-revision or cross-directory authority dependency. No historical verification page is reused as implementation evidence.

Future product evidence uses `artifacts/acceptance-evidence/g5-r/` in the implementation candidate, not `docs/implementation-phases/g5-r/verification/`. Plan verification and product verification therefore remain distinct data classes.

## Frozen product scope

G5-R retains every adopted G4-R decision unless this document explicitly lists a revision. The retained contract includes:

- `monaco-editor@0.56.0` as the product baseline;
- the complete contracted raw UTF-16 text-model surface and Piece Tree semantics;
- thin-MainActor live ownership, immutable background snapshots, explicit version gates, atomic transaction preparation and application, and deterministic event ordering;
- Core Text as the shaping, layout, geometry, and hit-test authority;
- Core Graphics as the complete first renderer;
- deterministic conditional Metal work only after a failed renderer-owned gate;
- custom AppKit view, input, transfer, accessibility, and host integration;
- all 30 provider surfaces and the frozen LSP 3.18 client architecture;
- zero bundled code-language implementations, grammar packs, snippet catalogs, and LSP servers;
- plain-text fallback when neither a direct provider nor an LSP capability exists;
- all adopted diff, snippet, Markdown, theme, icon, localization, session, service, resource, and source-closure behavior;
- all explicit cuts and Apple-native replacements;
- C01-C10, P00-P13, M0 and M1 comparators, 60 Hz and 120 Hz cells, and the `native/comparator <= 1.00` statistical gate; and
- arm64 macOS as the only current release target, with iOS and iPadOS excluded from this release verdict.

G5-R does not expand features, relax a threshold, add a language pack, qualify another device, or select Metal in advance.

## Revised qualification environment

G5-R replaces the stale G4-R qualification identity with these verified facts:

- macOS 26.6.1, build `25G76`;
- Xcode 26.6, build `17F113`;
- macOS SDK 26.5;
- Swift 6.3.3;
- arm64 MacBook Pro with Apple M4 Pro, 20 GPU cores, 48 GiB memory, and Metal 4;
- built-in 3456 x 2234 display at 1728 x 1117 logical points and 2x backing scale;
- Google Chrome `151.0.7922.138`;
- Chrome executable SHA-256 `ee37661755341e9fc1babf9c20ec09d6a36e50aa8713ceb08082f8bbe2d8217d`;
- Chromium tag commit `41fa82442390a4d4456c78f2d69a832d5720cb27`;
- V8 `15.1.206.17`, source commit `00c2754b59cf5f79b323950c63b07cfb1a8377d4`;
- Chromium ICU 78.2 at commit `d578f2e8b7bd5938e21cfb6bf15c079e0aa5b738`;
- Chrome `icudtl.dat` SHA-256 `9f48c7f9c7c94d516a14870707e910ab94d75ae640ff6842c4af53276cd26ebe`; and
- Chromium `base/time/time_apple.mm` SHA-256 `0015cb2fa5ee082bb61f07e24c150d161b08a7148143914d43c58f4850c68134`.

The design-time observation on 2026-08-15 records one connected external LG display as an unqualified, privacy-filtered slot. The release qualification predicate remains built-in-display-only and requires `externalDisplayCount == 0` for every formal C/P run. Formal acceptance therefore starts only after the external display is disconnected. External-display behavior remains excluded from the release verdict.

Every acceptance block generates a fresh `QEnvironmentID`. It records only non-identifying environment fields. Hardware serial numbers, hardware UUIDs, display UUIDs, device UDIDs, and raw user or account identities remain forbidden.

## Plan manifest model

The G5-R implementation-plan manifest is the sole machine authority for execution planning. Each task record contains:

- `id`, `phase`, `title`, and `platformScope`;
- explicit predecessor task IDs, with no ranges or prose-only dependencies;
- owned G5-R normative domains and machine artifacts;
- owned public paths, feature IDs, command IDs, action IDs, keybinding IDs, menu IDs, option IDs, provider IDs, and candidate artifacts;
- exact files to create, modify, and test;
- exact interface declarations or schema records introduced by the task;
- one or more red-test commands and their exact expected failing conditions;
- the bounded implementation operation;
- one or more green-test commands and their exact expected passing conditions;
- generated evidence paths and validation commands;
- task completion criteria; and
- a commit boundary that excludes unrelated files.

Markdown task documents present the same records in reviewer-sized steps. `verify-plan.mjs` parses stable task markers from Markdown and proves equality with the plan manifest. A task without an interface, red command, expected red result, implementation operation, green command, expected green result, and evidence path fails plan verification.

Aggregated implementation is permitted only when each contracted identity retains an individual manifest row and deterministic implementation/test owner. Grouping never removes traceability.

## Phase topology

The G5-R task graph uses this forward-only order:

1. Phase 00 creates the Swift package graph, provenance inputs, differential harness, environment collectors, and plan-preserving infrastructure.
2. Phase 01 implements base values, events, raw UTF-16 Piece Tree model truth, transactions, reconciliation, and model lifetime.
3. Phase 02 implements model semantics, search, RegExp and Unicode profiles, environment semantics, and retained ECMAScript intrinsics.
4. Phase 03 implements projection, vertical indexes, Core Text geometry, Core Graphics rendering, scrolling, and hit testing, then runs the locked renderer-owned decision gate. A passing Core Graphics result freezes Metal as absent; a failing renderer-owned result triggers Metal implementation and parity validation before any later phase begins.
5. Phase 04 implements keyboard input, IME, pointer and scroll adaptation, clipboard, drag and drop, Services, accessibility, and AppKit/SwiftUI editor embedding.
6. Phase 05 implements the complete public declaration surface, commands, actions, keybindings, menus, options, themes, icons, localization, and all retained feature identities.
7. Phase 06 implements providers, LSP transport and protocol mapping, snippets, Markdown presentation, and plain-text fallback.
8. Phase 07 implements diff, standalone services, WorkspaceEdit, host contracts, resource bounds, source closure, all remaining public diff views and SwiftUI types, and final public API closure.
9. Phase 08 builds the release candidate, completes license notices, emits the distribution manifest, and regenerates and validates all static candidate manifests after public API closure.
10. Phase 09 captures `QEnvironmentID`, runs C01-C10, P00-P13, cross-cutting and failure-injection gates against the renderer frozen by Phase 03, and produces the final release verdict last. Phase 09 never adds or changes product source.

Every dependency points from a later task to an earlier task. Distribution exists before C10. Public API closure exists before the final native declaration manifest. Candidate validation exists before acceptance. The release verdict depends on every acceptance result and has no outgoing dependency into candidate construction.

## Module and package boundaries

The package graph is fixed as follows:

- `MonaCode` imports Foundation only and owns text-model, value, transaction, language-neutral provider, LSP protocol, snippet, diff-algorithm, and service abstractions.
- `MonaCodeAppKit` depends on `MonaCode`, imports AppKit, Core Text, Core Graphics, and conditionally Metal, and owns `NSView`, `CGPoint`, native event, rendering, input, accessibility, transfer, and AppKit host types.
- `MonaCodeSwiftUI` depends explicitly on both `MonaCode` and `MonaCodeAppKit`, imports SwiftUI and AppKit, and owns lifecycle-only representables and controllers.
- `sample-macOS-host` depends on all three products from package creation onward; early phases compile a stub and later phases activate the full host.
- conformance, failure-injection, benchmark, and fixture resources use exact contract-facing names plus an explicit SwiftPM target-name mapping when SwiftPM identifiers differ.
- `DifferentialFixtures` resolves to the exact declared resource directory and never appears as a target.

Core public declarations represent AppKit concepts through Core-owned semantic protocols and value records. Concrete `NSView`, `CGPoint`, `NSRange`, pasteboard, event, and accessibility projections live in `MonaCodeAppKit`. Public symbol generation joins the Core semantic record with the AppKit projection record; it never imports AppKit into Core.

## Complete surface ownership

The plan verifier requires set equality against the adopted source manifests. It rejects both missing and extra identities. Required coverage includes:

- all 555 public declaration paths and their 434 retained versus 121 cut dispositions;
- all 64 feature entries, including 62 retained macOS features, one later-iPadOS feature, and one cut WebGPU debug feature;
- every command, action, contribution, keybinding, menu, menu item, option, color, icon, theme, provider surface, snippet identity, localization profile, host group, and service disposition in the machine artifacts; and
- every native replacement, including separate owned rows and tests for `editor.colorize`, `editor.colorizeElement`, and `editor.colorizeModelLine`.

Every retained feature has an implementation task, registry or direct entry point, accessibility disposition, and correctness owner. A feature implemented only as incidental behavior without its exact manifest identity fails the plan audit.

## Candidate artifacts and evidence lifecycle

The seven required candidate artifacts have explicit producer and finalizer tasks:

1. `MonaRegExpUnicodeManifest` after RegExp and Unicode implementation closure.
2. `MonaEnvironmentManifest` after all environment-sensitive source sites close.
3. `MonaNativeDeclarationManifest` after Phase 07 public API closure.
4. `MonaSourceClosureManifest` after source, runtime, and style closure.
5. `MonaCacheManifest` after every bounded cache and registry exists.
6. `MonaDistributionManifest` after the Phase 08 release candidate and notices exist.
7. `QEnvironmentID` at the start of each Phase 09 acceptance run.

Static manifests generated earlier in development are provisional evidence. The Phase 03 renderer decision completes before any static manifest finalizer. Phase 08 therefore regenerates and hashes final forms containing the fixed Core Graphics-only or Core Graphics-plus-Metal source set. Acceptance consumes only final forms. `QEnvironmentID` is run-specific and joins the six static manifests before the first C/P result is accepted.

Plan audit outputs use `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verification/`. Product acceptance outputs use `artifacts/acceptance-evidence/g5-r/`. A plan audit uses the states `planned`, `mapped`, and `structurally-verified`; it never uses `implemented`, `passed`, or `released`. Those latter states require product code and executed acceptance evidence.

## Verification and adversarial analysis

G5-R adoption requires all of these commands to pass from a clean repository checkout:

- the unchanged G4-R `verify-contract.mjs`;
- the new G5-R `verify-contract.mjs`;
- the G5-R audit module;
- the G5-R `verify-plan.mjs`;
- archive and history SHA-256 verification;
- JSON parsing and schema checks;
- Markdown link and stable-marker checks; and
- `git diff --check`.

The plan audit proves:

- zero dependency cycles and zero references to absent task IDs;
- exactly one implementation owner and at least one test owner for every retained identity;
- zero ownership for cut identities in production targets;
- complete coverage of 42 normative layers, 17 machine artifacts, C01-C10, P00-P13, and seven candidate artifacts;
- package and module imports conform to the fixed target graph;
- candidate producers precede consumers;
- C10 consumes a completed distribution candidate;
- every performance cell retains M0, M1, 60 Hz, 120 Hz, sample, environment, and statistical requirements;
- no plan-review evidence masquerades as executed product evidence; and
- no privacy-forbidden key or value enters environment artifacts.

The adversarial review attacks at least these classes independently:

- hidden backward dependencies and cross-phase cycles;
- missing exact identities hidden behind aggregate tasks;
- public API additions after manifest finalization;
- AppKit, Core Text, Core Graphics, Metal, Process, JavaScript, ICU runtime, WebView, DOM, CSS runtime, or TextKit leakage across forbidden boundaries;
- product versus target naming drift;
- resource-path drift;
- sample-host dependency drift;
- acceptance before candidate construction;
- conditional Metal work triggered by non-renderer metrics;
- weakened no-worse-than-Monaco thresholds;
- stale Chrome, OS, display, locale, font, or input-source qualification;
- false `passed`, `implemented`, or `released` claims; and
- loss or silent rewriting of historical planning artifacts.

Every attack records its input, expected rejection, observed result, and owning invariant. Adoption requires zero failed audit assertions and zero unresolved findings.

## Failure behavior

Verification fails closed. A missing file, hash mismatch, stale environment identity, unresolved reference, duplicate ownership row, missing exact feature ID, dependency cycle, malformed command expectation, missing evidence path, or forbidden import prevents adoption. The tools return non-zero and print the exact record and invariant that failed.

The verifier never repairs inputs, rewrites historical files, skips unknown rows, or converts unavailable evidence into success. A formal C/P run performed while the external display remains connected is invalid and produces no release evidence. A conditional Metal branch records either `triggered-and-required` or `not-triggered-and-absent`; no third state exists.

## Delivery sequence

Work proceeds in these commit-separated units:

1. Commit this approved design specification only.
2. Preserve the current G4-R plan draft under its history path with exact hashes.
3. Create and audit the G5-R contract archive without adopting it.
4. Create the authoritative plan manifest and complete G5-R Markdown execution plan.
5. Run structural and adversarial plan verification and correct every failure.
6. Generate final archive hashes and adopt the exact G5-R contract and plan manifests.
7. Re-run both G4-R and G5-R verification from the adopted tree.

No product implementation begins within these units. Product work begins only after G5-R adoption and a separate execution decision.

## Completion criteria

The contract-and-plan revision is complete only when all of the following are true:

- G4-R remains byte-valid and independently verifiable;
- G5-R is present, self-contained, hash-complete, audited, and adopted;
- the current environment identity is exact and privacy-clean;
- the historical G4-R plan draft is present with verified byte hashes;
- the G5-R plan manifest and Markdown views agree exactly;
- the task graph is acyclic;
- every contracted identity, gate, workload, candidate artifact, module boundary, and evidence output has complete ownership;
- every executable task includes interfaces, red and green commands, exact expected outcomes, evidence, and a bounded commit boundary;
- the adversarial plan review reports zero unresolved findings; and
- the repository contains no product implementation or false acceptance claim introduced by this revision.
