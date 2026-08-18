// MonaInlineCompletionsFeatureTests.swift
//
// P05-T128 — Implement retained feature inlineCompletions.
//
// Verifies the inlineCompletions feature across its three implementation
// operations:
//   1. Feature-specific behavior: request, update, partially accept, accept,
//      and release inline completions (reuse `MonaProviderExecutor` P05-T013;
//      edits via `MonaTransactionGateway`).
//   2. The exact feature identity `inlineCompletions` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     INLINECOMPLETIONS feature=live actions=11 commands=14 contributions=1 keybindings=7 options=3 menus=3 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaInlineCompletionsFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "abc") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/inlinecompletions-\(UUID().uuidString)")
        )
    }

    private func sampleCompletion() -> MonaInlineCompletion {
        return MonaInlineCompletion(
            range: MonaRange(
                startPosition: MonaPosition(line: 1, column: 4),
                endPosition: MonaPosition(line: 1, column: 4)
            ),
            insertText: "hello world",
            filterText: "hello world"
        )
    }

    // MARK: - 1. Feature-specific behavior: request / update / partially accept / accept / release

    func testRequestInlineCompletionStagesAndRetainsByVersion() {
        let feature = MonaInlineCompletionsFeature()
        let model = makeModel()
        let version = model.getVersionId()
        let completion = sampleCompletion()

        let requested = feature.requestInlineCompletion(completion, modelVersion: version)

        XCTAssertEqual(requested, completion)
        XCTAssertEqual(feature.stagedCompletion, completion)
        XCTAssertEqual(feature.retainedCompletion(for: version), completion)
    }

    func testRequestInlineCompletionForNewModelVersionIsIndependent() {
        let feature = MonaInlineCompletionsFeature()
        let model = makeModel()

        let v1 = model.getVersionId()
        _ = feature.requestInlineCompletion(sampleCompletion(), modelVersion: v1)
        // The model advances (a direct mutation bypassing the feature).
        model.setValue("abcdef")
        let v2 = model.getVersionId()

        XCTAssertNotEqual(v1, v2)
        XCTAssertNotNil(feature.retainedCompletion(for: v1))
        XCTAssertNil(feature.retainedCompletion(for: v2))
    }

    func testUpdateInlineCompletionReplacesStagedCompletion() {
        let feature = MonaInlineCompletionsFeature()
        let model = makeModel()
        let version = model.getVersionId()
        let first = sampleCompletion()
        _ = feature.requestInlineCompletion(first, modelVersion: version)

        let updated = MonaInlineCompletion(
            range: MonaRange(
                startPosition: MonaPosition(line: 1, column: 4),
                endPosition: MonaPosition(line: 1, column: 4)
            ),
            insertText: "goodbye",
            filterText: "goodbye"
        )
        let result = feature.updateInlineCompletion(updated)

        XCTAssertEqual(result, updated)
        XCTAssertEqual(feature.stagedCompletion, updated)
        XCTAssertEqual(feature.retainedCompletion(for: version), updated)
    }

    func testPartiallyAcceptInlineCompletionAppliesFirstWordThroughGateway() {
        let feature = MonaInlineCompletionsFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        _ = feature.requestInlineCompletion(sampleCompletion(), modelVersion: version)

        let outcome = feature.partiallyAcceptInlineCompletion(gateway: gateway)
        if case .applied = outcome {
            // "abc" + first word "hello" inserted at column 4 (end) → "abchello".
            XCTAssertEqual(model.getValue(), "abchello")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testAcceptInlineCompletionAppliesFullInsertTextThroughGateway() {
        let feature = MonaInlineCompletionsFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        _ = feature.requestInlineCompletion(sampleCompletion(), modelVersion: version)

        let outcome = feature.acceptInlineCompletion(gateway: gateway)
        if case .applied = outcome {
            // "abc" + "hello world" inserted at column 4 (end) → "abchello world".
            XCTAssertEqual(model.getValue(), "abchello world")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testAcceptInlineCompletionWithNoStagedCompletionIsDropped() {
        let feature = MonaInlineCompletionsFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.acceptInlineCompletion(gateway: gateway)
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "abc")
        } else {
            XCTFail("expected dropped, got \(outcome)")
        }
    }

    func testReleaseInlineCompletionDropsResultsForStaleModelVersion() {
        let feature = MonaInlineCompletionsFeature()
        let model = makeModel()
        let v1 = model.getVersionId()
        _ = feature.requestInlineCompletion(sampleCompletion(), modelVersion: v1)
        XCTAssertNotNil(feature.retainedCompletion(for: v1))

        let released = feature.releaseInlineCompletion(modelVersion: v1)
        XCTAssertEqual(released, 1)
        XCTAssertNil(feature.retainedCompletion(for: v1))
    }

    func testReleaseInlineCompletionForUnknownVersionReleasesNothing() {
        let feature = MonaInlineCompletionsFeature()
        let model = makeModel()
        let v1 = model.getVersionId()
        _ = feature.requestInlineCompletion(sampleCompletion(), modelVersion: v1)
        let released = feature.releaseInlineCompletion(modelVersion: v1 + 999)
        XCTAssertEqual(released, 0)
        XCTAssertNotNil(feature.retainedCompletion(for: v1))
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaInlineCompletionsFeature.featureId, "inlineCompletions")
        XCTAssertTrue(features.contains("inlineCompletions"))

        let actionIds = MonaInlineCompletionsFeature.declaredActionIds
        XCTAssertEqual(actionIds, [
            "editor.action.inlineSuggest.trigger",
            "editor.action.inlineSuggest.showNext",
            "editor.action.inlineSuggest.showPrevious",
            "editor.action.inlineSuggest.acceptNextWord",
            "editor.action.inlineSuggest.acceptNextLine",
            "editor.action.inlineSuggest.commit",
            "editor.action.inlineSuggest.commitAlternativeAction",
            "editor.action.inlineSuggest.toggleShowCollapsed",
            "editor.action.inlineSuggest.hide",
            "editor.action.inlineSuggest.jump",
            "editor.action.inlineSuggest.dev.extractRepro"
        ])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        let commandIds = MonaInlineCompletionsFeature.declaredCommandIds
        XCTAssertEqual(commandIds, [
            "editor.action.inlineSuggest.acceptNextLine",
            "editor.action.inlineSuggest.acceptNextWord",
            "editor.action.inlineSuggest.cancelSnooze",
            "editor.action.inlineSuggest.commit",
            "editor.action.inlineSuggest.commitAlternativeAction",
            "editor.action.inlineSuggest.dev.extractRepro",
            "editor.action.inlineSuggest.hide",
            "editor.action.inlineSuggest.jump",
            "editor.action.inlineSuggest.showNext",
            "editor.action.inlineSuggest.showPrevious",
            "editor.action.inlineSuggest.snooze",
            "editor.action.inlineSuggest.toggleAlwaysShowToolbar",
            "editor.action.inlineSuggest.toggleShowCollapsed",
            "editor.action.inlineSuggest.trigger"
        ])
        for id in commandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(
            MonaInlineCompletionsFeature.declaredContributionIds,
            ["editor.contrib.inlineCompletionsController"]
        )
        for id in MonaInlineCompletionsFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        // Declared keybinding commands: the seven inlineSuggest actions that
        // carry a default keybinding, in declared action order.
        XCTAssertEqual(MonaInlineCompletionsFeature.declaredKeybindingCommands, [
            "editor.action.inlineSuggest.showNext",
            "editor.action.inlineSuggest.showPrevious",
            "editor.action.inlineSuggest.acceptNextWord",
            "editor.action.inlineSuggest.commit",
            "editor.action.inlineSuggest.commitAlternativeAction",
            "editor.action.inlineSuggest.hide",
            "editor.action.inlineSuggest.jump"
        ])
        let rowCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in MonaInlineCompletionsFeature.declaredKeybindingCommands {
            XCTAssertTrue(rowCommands.contains(id), "missing keybinding for \(id)")
        }

        XCTAssertEqual(MonaInlineCompletionsFeature.declaredOptionIds, [
            "screenReaderAnnounceInlineSuggestion",
            "inlineSuggest",
            "inlineCompletionsAccessibilityVerbose"
        ])

        XCTAssertEqual(MonaInlineCompletionsFeature.declaredMenuIds, [
            "CommandPalette",
            "InlineEditsActions",
            "InlineSuggestionToolbar"
        ])
        for id in MonaInlineCompletionsFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGateway() {
        let feature = MonaInlineCompletionsFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        _ = feature.requestInlineCompletion(sampleCompletion(), modelVersion: version)

        let outcome = feature.acceptInlineCompletion(gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "abchello world")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaInlineCompletionsFeature()
        let ticket = gate.captureTicket()
        let completion = sampleCompletion()

        var received: MonaInlineCompletion?
        let accepted = feature.publishInlineCompletion(
            completion,
            executor: executor,
            ticket: ticket
        ) { delivered in received = delivered }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received, completion)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaInlineCompletionsFeature()
        var fired: [MonaInlineCompletionEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, request / update / accept / release are no-ops.
        let model = makeModel()
        let version = model.getVersionId()
        let requested = feature.requestInlineCompletion(sampleCompletion(), modelVersion: version)
        XCTAssertNil(requested)
        XCTAssertNil(feature.stagedCompletion)
        XCTAssertNil(feature.retainedCompletion(for: version))
        let outcome = feature.acceptInlineCompletion(gateway: MonaTransactionGateway(model: model))
        if case .dropped = outcome {
        } else {
            XCTFail("expected dropped after disposal, got \(outcome)")
        }
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaInlineCompletionsFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaInlineCompletionsFeature.declaredActionIds.count)
        // The first declared action is "Trigger Inline Suggestion".
        XCTAssertEqual(enLabels[0], "Trigger Inline Suggestion")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaInlineCompletionsFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        let language = feature.degradedLanguage
        XCTAssertEqual(language.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(language.hasTokenization)
        XCTAssertFalse(language.hasGrammar)
    }

    // MARK: - Contract leaf

    func testContractBehavior() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()
        let feature = MonaInlineCompletionsFeature()

        let featureLive = features.contains(MonaInlineCompletionsFeature.featureId)
        let actionCount = MonaInlineCompletionsFeature.declaredActionIds.count
        let commandCount = MonaInlineCompletionsFeature.declaredCommandIds.count
        let contribCount = MonaInlineCompletionsFeature.declaredContributionIds.count
        let kbCount = MonaInlineCompletionsFeature.declaredKeybindingCommands.count
        let optionCount = MonaInlineCompletionsFeature.declaredOptionIds.count
        let menuCount = MonaInlineCompletionsFeature.declaredMenuIds.count

        let slicePass = MonaInlineCompletionsFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaInlineCompletionsFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaInlineCompletionsFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaInlineCompletionsFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaInlineCompletionsFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Request + update: request a completion, then update it.
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        let completion = sampleCompletion()
        let requested = feature.requestInlineCompletion(completion, modelVersion: version)
        let updated = feature.updateInlineCompletion(completion)
        let requestUpdatePass = requested == completion && updated == completion
            && feature.stagedCompletion == completion

        // Partially accept on a fresh model (avoids a stale range after the
        // model mutates): apply the first word ("hello") through the gateway.
        let partialModel = makeModel("abc")
        let partialGateway = MonaTransactionGateway(model: partialModel)
        let partialVersion = partialModel.getVersionId()
        _ = feature.requestInlineCompletion(sampleCompletion(), modelVersion: partialVersion)
        let partialOutcome = feature.partiallyAcceptInlineCompletion(gateway: partialGateway)
        var partialPass = false
        if case .applied = partialOutcome, partialModel.getValue() == "abchello" {
            partialPass = true
        }

        // Mutation: re-stage the completion for the original model (the staged
        // was overwritten by the partial-model request), then accept the full
        // insertText through the transaction gateway.
        _ = feature.requestInlineCompletion(sampleCompletion(), modelVersion: version)
        let mutation: Bool
        let outcome = feature.acceptInlineCompletion(gateway: gateway)
        if case .applied = outcome, model.getValue() == "abchello world" {
            mutation = true
        } else {
            mutation = false
        }

        // Release the stale-model-version completion.
        let released = feature.releaseInlineCompletion(modelVersion: version)
        let releasePass = (released == 1 && feature.retainedCompletion(for: version) == nil)

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishInlineCompletion(sampleCompletion(), executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("INLINECOMPLETIONS feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(requestUpdatePass)
        XCTAssertTrue(partialPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(releasePass)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
