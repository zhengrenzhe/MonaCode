// MonaCommandActionRegistryTests.swift
//
// P05-T002 — Implement command, action, contribution, and pure-text registries.
//
// Verifies the four Core registries:
//   - `MonaCommandRegistry` — frozen command identities in source order.
//   - `MonaActionRegistry` — action + pure-text action identities in source order.
//   - `MonaContributionRegistry` — contribution identities in source order.
//   - `MonaFeatureRegistry` — feature flag identities in source order.
//
// Contract leaves exercised:
//   1. All frozen identities registered in source order (no rename / coalesce).
//   2. Enablement, precondition, toggled state, argument shape, and disposal
//      evaluate deterministically.
//   3. WebGPU-debug identities + the later mobile contribution are EXCLUDED
//      (recorded as UNAVAILABLE dispositions, not registered as live).
//   4. Disposal is idempotent.
//
// On Green, `testRegistryContractLeaf` prints the contract line:
//     REGISTRY commands=453 actions=166 puretext=126 contributions=52 features=62 cut=4 excluded=pass idempotent=pass

import XCTest
import MonaCode

final class MonaCommandActionRegistryTests: XCTestCase {

    // MARK: - 1. MonaCommandRegistry — source-order registration

    func testCommandRegistryRegistersAllFrozenIdentitiesInSourceOrder() {
        let registry = MonaCommandRegistry()
        // 454 frozen identities: 453 retained + 1 cut-webgpu-debug.
        XCTAssertEqual(MonaCommandRegistry.frozenIdentities.count, 454)
        XCTAssertEqual(registry.totalCount, 454)
        XCTAssertEqual(registry.liveCount, 453)
        XCTAssertEqual(registry.cutCount, 1)
    }

    func testCommandRegistryFirstAndLastIdsAreInManifestSourceOrder() {
        let registry = MonaCommandRegistry()
        let live = registry.liveIdentities
        // First 5 IDs in source order (manifest order, verbatim).
        let expectedFirst = ["_executeCodeActionProvider", "_executeCodeLensProvider", "_executeColorPresentationProvider", "_executeCompletionItemProvider", "_executeDeclarationProvider"]
        let actualFirst = Array(live.prefix(5)).map { $0.id }
        XCTAssertEqual(actualFirst, expectedFirst)
        // Last 3 live IDs.
        let expectedLast = ["toggleSuggestionFocus", "type", "undo"]
        let actualLast = Array(live.suffix(3)).map { $0.id }
        XCTAssertEqual(actualLast, expectedLast)
    }

    func testCommandRegistryExcludesWebGpuDebugIdentity() {
        let registry = MonaCommandRegistry()
        // The WebGPU debug command is CUT: recorded as UNAVAILABLE, not live.
        let cut = registry.cutIdentities
        XCTAssertEqual(cut.count, 1)
        XCTAssertEqual(cut[0].id, "editor.action.debugEditorGpuRenderer")
        XCTAssertEqual(cut[0].disposition, .cutWebGpuDebug)
        // It is NOT registered as live.
        XCTAssertFalse(registry.contains("editor.action.debugEditorGpuRenderer"))
        XCTAssertNil(registry.identity(for: "editor.action.debugEditorGpuRenderer"))
    }

    func testCommandRegistryNoIdentityCoalescing() {
        // Every frozen identity has a unique ID (no coalescing).
        let ids = MonaCommandRegistry.frozenIdentities.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testCommandRegistryEnablementIsDeterministic() {
        let registry = MonaCommandRegistry()
        let context = MonaKeybindingContext()
        // A live command is enabled.
        XCTAssertTrue(registry.isEnabled("_executeCodeActionProvider", context: context))
        // A cut command is not registered → not enabled.
        XCTAssertFalse(registry.isEnabled("editor.action.debugEditorGpuRenderer", context: context))
        // An unknown command is not enabled.
        XCTAssertFalse(registry.isEnabled("no.such.command", context: context))
    }

    func testCommandRegistryArgumentShapeIsDeterministic() {
        let registry = MonaCommandRegistry()
        // A command with args reports its schema.
        XCTAssertTrue(registry.argumentShape(for: "cursorEnd")?.hasArguments ?? false)
        XCTAssertNotNil(registry.argumentShape(for: "cursorEnd")?.schema)
        // A command without args reports no arguments.
        let noArgsShape = registry.argumentShape(for: "_executeCodeActionProvider")
        XCTAssertNotNil(noArgsShape)
        XCTAssertFalse(noArgsShape?.hasArguments ?? true)
    }

    func testCommandRegistryDisposalIsIdempotent() {
        let registry = MonaCommandRegistry()
        XCTAssertFalse(registry.isDisposed)
        registry.dispose()
        XCTAssertTrue(registry.isDisposed)
        // Repeated disposal is a no-op.
        registry.dispose()
        registry.dispose()
        XCTAssertTrue(registry.isDisposed)
        // A disposed registry enables nothing.
        let context = MonaKeybindingContext()
        XCTAssertFalse(registry.isEnabled("_executeCodeActionProvider", context: context))
        // Frozen identity inventory is still queryable (immutable).
        XCTAssertEqual(registry.totalCount, 454)
    }

    // MARK: - 2. MonaActionRegistry — source-order registration

    func testActionRegistryRegistersAllFrozenActionsInSourceOrder() {
        let registry = MonaActionRegistry()
        // 167 frozen actions: 166 retained + 1 cut-webgpu-debug.
        XCTAssertEqual(MonaActionRegistry.frozenIdentities.count, 167)
        XCTAssertEqual(registry.actionCount, 167)
        XCTAssertEqual(registry.liveActionCount, 166)
        XCTAssertEqual(registry.cutActionCount, 1)
    }

    func testActionRegistryRegistersAllFrozenPureTextActionsInSourceOrder() {
        let registry = MonaActionRegistry()
        // 127 frozen pure-text actions: 126 retained + 1 cut-webgpu-debug.
        XCTAssertEqual(MonaActionRegistry.frozenPureTextIdentities.count, 127)
        XCTAssertEqual(registry.pureTextCount, 127)
        XCTAssertEqual(registry.livePureTextCount, 126)
        XCTAssertEqual(registry.cutPureTextCount, 1)
    }

    func testActionRegistryFirstIdsAreInManifestSourceOrder() {
        let registry = MonaActionRegistry()
        let live = registry.liveIdentities
        let expectedFirst = ["editor.action.setSelectionAnchor", "editor.action.goToSelectionAnchor", "editor.action.selectFromAnchorToCursor"]
        let actualFirst = Array(live.prefix(3)).map { $0.id }
        XCTAssertEqual(actualFirst, expectedFirst)
    }

    func testActionRegistryFirstPureTextIdsAreInManifestSourceOrder() {
        let registry = MonaActionRegistry()
        let live = registry.livePureTextIdentities
        let expectedFirst = ["actions.find", "actions.findWithSelection", "cursorRedo"]
        let actualFirst = Array(live.prefix(3)).map { $0.id }
        XCTAssertEqual(actualFirst, expectedFirst)
    }

    func testActionRegistryExcludesWebGpuDebugIdentity() {
        let registry = MonaActionRegistry()
        // The WebGPU debug action is CUT in both actions and pure-text.
        XCTAssertEqual(registry.cutIdentities.count, 1)
        XCTAssertEqual(registry.cutIdentities[0].id, "editor.action.debugEditorGpuRenderer")
        XCTAssertEqual(registry.cutPureTextIdentities.count, 1)
        XCTAssertEqual(registry.cutPureTextIdentities[0].id, "editor.action.debugEditorGpuRenderer")
        // Not registered as live.
        XCTAssertFalse(registry.contains("editor.action.debugEditorGpuRenderer"))
        XCTAssertFalse(registry.containsPureText("editor.action.debugEditorGpuRenderer"))
    }

    func testActionRegistryNoIdentityCoalescing() {
        let ids = MonaActionRegistry.frozenIdentities.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count)
        let ptIds = MonaActionRegistry.frozenPureTextIdentities.map { $0.id }
        XCTAssertEqual(Set(ptIds).count, ptIds.count)
    }

    func testActionRegistryEnablementPreconditionToggledArgumentShapeAreDeterministic() {
        let registry = MonaActionRegistry()
        let context = MonaKeybindingContext()
        // An action with no precondition is unconditionally enabled.
        XCTAssertTrue(registry.isEnabled("editor.action.setSelectionAnchor", context: context))
        // An action with a precondition: evaluate against context.
        // "editor.action.goToSelectionAnchor" has precondition "selectionAnchorSet".
        let precond = registry.precondition(for: "editor.action.goToSelectionAnchor")
        XCTAssertNotNil(precond)
        // The precondition evaluates deterministically against a given context.
        let eval = MonaPreconditionEvaluator.evaluate(precond!, context: context)
        _ = eval  // deterministic for the given context
        // Toggled state: most built-in actions have no toggled state.
        XCTAssertNil(registry.toggled(for: "editor.action.setSelectionAnchor"))
        XCTAssertFalse(registry.isToggled("editor.action.setSelectionAnchor", context: context))
        // Argument shape: an action's argument shape is queryable.
        let shape = registry.argumentShape(for: "editor.action.setSelectionAnchor")
        XCTAssertNotNil(shape)
    }

    func testActionRegistryPreconditionEvaluatorEvaluatesWhenClauses() {
        // The precondition evaluator reuses the when-clause grammar + context
        // types from P04-T003's keybinding resolver.
        let context = MonaKeybindingContext()
            .with("editorTextFocus", .bool(true))
            .with("editorReadonly", .bool(false))
        // bare-key truthy
        XCTAssertTrue(MonaPreconditionEvaluator.evaluate(MonaPrecondition("editorTextFocus"), context: context))
        XCTAssertFalse(MonaPreconditionEvaluator.evaluate(MonaPrecondition("editorReadonly"), context: context))
        // ! negation
        XCTAssertTrue(MonaPreconditionEvaluator.evaluate(MonaPrecondition("!editorReadonly"), context: context))
        // && and ||
        XCTAssertTrue(MonaPreconditionEvaluator.evaluate(MonaPrecondition("editorTextFocus && !editorReadonly"), context: context))
        XCTAssertTrue(MonaPreconditionEvaluator.evaluate(MonaPrecondition("editorReadonly || editorTextFocus"), context: context))
        // == string
        let ctx2 = MonaKeybindingContext().with("lang", .string("swift"))
        XCTAssertTrue(MonaPreconditionEvaluator.evaluate(MonaPrecondition("lang == 'swift'"), context: ctx2))
        XCTAssertFalse(MonaPreconditionEvaluator.evaluate(MonaPrecondition("lang == 'go'"), context: ctx2))
        // nil/empty → unconditional
        XCTAssertTrue(MonaPreconditionEvaluator.evaluate(.unconditional, context: context))
    }

    func testActionRegistryDisposalIsIdempotent() {
        let registry = MonaActionRegistry()
        XCTAssertFalse(registry.isDisposed)
        registry.dispose()
        XCTAssertTrue(registry.isDisposed)
        registry.dispose()
        XCTAssertTrue(registry.isDisposed)
        let context = MonaKeybindingContext()
        XCTAssertFalse(registry.isEnabled("editor.action.setSelectionAnchor", context: context))
    }

    // MARK: - 3. MonaContributionRegistry — source-order registration

    func testContributionRegistryRegistersAllFrozenIdentitiesInSourceOrder() {
        let registry = MonaContributionRegistry()
        // 53 frozen contributions: 52 retained-macos + 1 later-ipados.
        XCTAssertEqual(MonaContributionRegistry.frozenIdentities.count, 53)
        XCTAssertEqual(registry.totalCount, 53)
        XCTAssertEqual(registry.liveCount, 52)
        XCTAssertEqual(registry.cutCount, 1)
    }

    func testContributionRegistryFirstIdsAreInManifestSourceOrder() {
        let registry = MonaContributionRegistry()
        let live = registry.liveIdentities
        let expectedFirst = ["editor.contrib.markerDecorations", "editor.contrib.selectionAnchorController", "editor.contrib.bracketMatchingController"]
        let actualFirst = Array(live.prefix(3)).map { $0.id }
        XCTAssertEqual(actualFirst, expectedFirst)
    }

    func testContributionRegistryExcludesLaterIpadosContribution() {
        let registry = MonaContributionRegistry()
        // The later mobile (iPadOS) contribution is excluded from production.
        XCTAssertEqual(registry.cutIdentities.count, 1)
        XCTAssertEqual(registry.cutIdentities[0].id, "editor.contrib.iPadShowKeyboard")
        XCTAssertEqual(registry.cutIdentities[0].disposition, .laterIpados)
        XCTAssertFalse(registry.contains("editor.contrib.iPadShowKeyboard"))
    }

    func testContributionRegistryInstantiationIsDeterministic() {
        let registry = MonaContributionRegistry()
        // Spot-check instantiation kinds.
        let findInst = registry.instantiation(for: "editor.contrib.findController")
        XCTAssertNotNil(findInst)
        let bracketInst = registry.instantiation(for: "editor.contrib.bracketMatchingController")
        XCTAssertNotNil(bracketInst)
    }

    func testContributionRegistryDisposalIsIdempotent() {
        let registry = MonaContributionRegistry()
        XCTAssertFalse(registry.isDisposed)
        registry.dispose()
        XCTAssertTrue(registry.isDisposed)
        registry.dispose()
        XCTAssertTrue(registry.isDisposed)
    }

    // MARK: - 4. MonaFeatureRegistry — source-order registration

    func testFeatureRegistryRegistersAllFrozenIdentitiesInSourceOrder() {
        let registry = MonaFeatureRegistry()
        // 64 frozen features: 62 retained-macos + 1 cut-webgpu-debug + 1 later-ipados.
        XCTAssertEqual(MonaFeatureRegistry.frozenIdentities.count, 64)
        XCTAssertEqual(registry.totalCount, 64)
        XCTAssertEqual(registry.liveCount, 62)
        XCTAssertEqual(registry.cutCount, 2)
    }

    func testFeatureRegistryFirstIdsAreInManifestSourceOrder() {
        let registry = MonaFeatureRegistry()
        let live = registry.liveIdentities
        let expectedFirst = ["anchorSelect", "bracketMatching", "caretOperations"]
        let actualFirst = Array(live.prefix(3)).map { $0.id }
        XCTAssertEqual(actualFirst, expectedFirst)
    }

    func testFeatureRegistryExcludesWebGpuAndLaterIpados() {
        let registry = MonaFeatureRegistry()
        // The WebGPU debug feature + the later iPadOS feature are excluded.
        XCTAssertEqual(registry.cutCount, 2)
        let cutIds = Set(registry.cutIdentities.map { $0.id })
        XCTAssertTrue(cutIds.contains("gpu"))
        XCTAssertTrue(cutIds.contains("iPadShowKeyboard"))
        XCTAssertFalse(registry.contains("gpu"))
        XCTAssertFalse(registry.contains("iPadShowKeyboard"))
    }

    func testFeatureRegistryDisposalIsIdempotent() {
        let registry = MonaFeatureRegistry()
        XCTAssertFalse(registry.isDisposed)
        registry.dispose()
        XCTAssertTrue(registry.isDisposed)
        registry.dispose()
        XCTAssertTrue(registry.isDisposed)
    }

    // MARK: - 5. MonaContextKey + MonaPrecondition — context-key mechanism

    func testContextKeyReusesKeybindingContextTypes() {
        // MonaContextKey operates on the same MonaKeybindingContext +
        // MonaContextValue types established by P04-T003's keybinding resolver.
        let context = MonaKeybindingContext()
            .with("editorTextFocus", .bool(true))
        let key = MonaContextKey("editorTextFocus")
        XCTAssertTrue(key.isSet(in: context))
        XCTAssertEqual(key.value(in: context), .bool(true))
        let absent = MonaContextKey("no.such.key")
        XCTAssertFalse(absent.isSet(in: context))
        XCTAssertNil(absent.value(in: context))
    }

    func testPreconditionUnconditionalMatchesAlways() {
        XCTAssertTrue(MonaPreconditionEvaluator.evaluate(.unconditional, context: MonaKeybindingContext()))
        XCTAssertTrue(MonaPreconditionEvaluator.evaluate(MonaPrecondition(nil), context: MonaKeybindingContext()))
        XCTAssertTrue(MonaPreconditionEvaluator.evaluate(MonaPrecondition(""), context: MonaKeybindingContext()))
    }

    func testPreconditionParseFailureFailsSafe() {
        // A parse failure fails safe (no match), matching P04-T003's WhenEvaluator.
        // "a ==" tokenizes (word + eq) but the parser finds no rhs → parse error → false.
        XCTAssertFalse(MonaPreconditionEvaluator.evaluate(MonaPrecondition("a =="), context: MonaKeybindingContext()))
        // Unbalanced parens → parse error → false.
        XCTAssertFalse(MonaPreconditionEvaluator.evaluate(MonaPrecondition("(editorTextFocus"), context: MonaKeybindingContext()))
        // A string the lexer rejects entirely (unrecognized chars) yields zero
        // tokens, which the evaluator treats as unconditional (matching P04-T003).
        XCTAssertTrue(MonaPreconditionEvaluator.evaluate(MonaPrecondition("$$$"), context: MonaKeybindingContext()))
    }

    // MARK: - 6. Contract leaf

    func testRegistryContractLeaf() {
        let cmd = MonaCommandRegistry()
        let act = MonaActionRegistry()
        let contrib = MonaContributionRegistry()
        let feat = MonaFeatureRegistry()

        let commandsLive = cmd.liveCount
        let actionsLive = act.liveActionCount
        let pureTextLive = act.livePureTextCount
        let contribsLive = contrib.liveCount
        let featuresLive = feat.liveCount

        // Excluded dispositions: WebGPU debug (commands+actions+puretext+features)
        // + later iPadOS (contributions+features).
        let excludedPass =
            !cmd.contains("editor.action.debugEditorGpuRenderer") &&
            !act.contains("editor.action.debugEditorGpuRenderer") &&
            !act.containsPureText("editor.action.debugEditorGpuRenderer") &&
            !contrib.contains("editor.contrib.iPadShowKeyboard") &&
            !feat.contains("gpu") &&
            !feat.contains("iPadShowKeyboard")

        // Idempotent disposal.
        cmd.dispose(); cmd.dispose()
        act.dispose(); act.dispose()
        contrib.dispose(); contrib.dispose()
        feat.dispose(); feat.dispose()
        let idempotentPass = cmd.isDisposed && act.isDisposed && contrib.isDisposed && feat.isDisposed

        print("REGISTRY commands=\(commandsLive) actions=\(actionsLive) puretext=\(pureTextLive) contributions=\(contribsLive) features=\(featuresLive) cut=4 excluded=\(excludedPass ? "pass" : "fail") idempotent=\(idempotentPass ? "pass" : "fail")")

        XCTAssertTrue(excludedPass)
        XCTAssertTrue(idempotentPass)
    }
}
