// MonaFormatFeatureTests.swift
//
// P05-T121 — Implement retained feature format.
//
// Verifies the format feature across its three implementation operations:
//   1. Feature-specific behavior: run document, range, and on-type formatting
//      providers, accept the returned edits (sorted ascending by start position,
//      non-overlapping), and apply the accepted edits through the shared
//      `MonaTransactionGateway` (reusing `MonaProviderExecutor` P05-T013 for
//      provider execution).
//   2. The exact feature identity `format` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testFormatContractLeaf` prints the contract line:
//     FORMAT feature=live actions=2 commands=6 contributions=2 keybindings=2 options=2 menus=1 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaFormatFeatureTests: XCTestCase {

    // MARK: - 1. Feature-specific behavior: run providers + accept + apply edits

    func testFormatDocumentAcceptsSortedNonOverlappingEdits() {
        let feature = MonaFormatFeature()
        let edits = [
            MonaFormatEdit(range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 3), text: "hi"),
            MonaFormatEdit(range: MonaRange(startLine: 2, startColumn: 1, endLine: 2, endColumn: 2), text: "x")
        ]
        let accepted = feature.formatDocument(edits)
        XCTAssertEqual(accepted.count, 2)
        XCTAssertEqual(accepted[0].range.startPosition.line, 1)
        XCTAssertEqual(accepted[1].range.startPosition.line, 2)
    }

    func testFormatRangeAcceptsEdits() {
        let feature = MonaFormatFeature()
        let edits = [
            MonaFormatEdit(range: MonaRange(startLine: 3, startColumn: 1, endLine: 3, endColumn: 4), text: "y")
        ]
        let accepted = feature.formatRange(edits)
        XCTAssertEqual(accepted.count, 1)
        XCTAssertEqual(accepted[0].text, "y")
    }

    func testFormatOnTypeAcceptsEdits() {
        let feature = MonaFormatFeature()
        let edits = [
            MonaFormatEdit(range: MonaRange(startLine: 5, startColumn: 2, endLine: 5, endColumn: 2), text: ";")
        ]
        let accepted = feature.formatOnType(edits)
        XCTAssertEqual(accepted.count, 1)
        XCTAssertEqual(accepted[0].text, ";")
    }

    func testAcceptsEditsReordersUnsortedInputAscendingByStart() {
        let feature = MonaFormatFeature()
        // Given out of order, format returns them sorted ascending by start.
        let edits = [
            MonaFormatEdit(range: MonaRange(startLine: 4, startColumn: 1, endLine: 4, endColumn: 1), text: "b"),
            MonaFormatEdit(range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1), text: "a")
        ]
        let accepted = feature.formatDocument(edits)
        XCTAssertEqual(accepted.map { $0.range.startPosition.line }, [1, 4])
    }

    func testOverlappingEditsAreRejectedAsEmpty() {
        let feature = MonaFormatFeature()
        // Overlapping edits are not accepted: Monaco rejects a formatting batch
        // whose edits overlap. The feature returns an empty acceptance.
        let edits = [
            MonaFormatEdit(range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 5), text: "a"),
            MonaFormatEdit(range: MonaRange(startLine: 1, startColumn: 3, endLine: 1, endColumn: 7), text: "b")
        ]
        XCTAssertTrue(feature.formatDocument(edits).isEmpty)
    }

    func testFormatFiresEventWithKindAndEditCount() {
        let feature = MonaFormatFeature()
        var events: [MonaFormatEvent] = []
        _ = feature.onChange { events.append($0) }
        _ = feature.formatDocument([
            MonaFormatEdit(range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2), text: "z")
        ])
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].kind, .document)
        XCTAssertEqual(events[0].editCount, 1)
    }

    func testApplyFormatEditsRoutesThroughTransactionGateway() {
        let model = MonaCodeModel(
            text: "abc\ndef",
            uri: MonaURI(scheme: "inmemory", path: "/fmt")
        )
        let gateway = MonaTransactionGateway(model: model)
        let feature = MonaFormatFeature()
        let edits = feature.formatDocument([
            MonaFormatEdit(range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2), text: "A")
        ])
        let outcome = feature.applyFormatEdits(edits, gateway: gateway)
        XCTAssertEqual(outcome, .applied)
        XCTAssertEqual(model.getValue(), "Abc\ndef")
    }

    func testFormatIsNoOpAfterDispose() {
        let feature = MonaFormatFeature()
        feature.dispose()
        let edits = [
            MonaFormatEdit(range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2), text: "z")
        ]
        XCTAssertTrue(feature.formatDocument(edits).isEmpty)
        XCTAssertTrue(feature.isDisposed)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()

        XCTAssertTrue(features.contains(MonaFormatFeature.featureId))
        XCTAssertEqual(MonaFormatFeature.featureId, "format")

        let actionIds = MonaFormatFeature.declaredActionIds
        XCTAssertEqual(actionIds, ["editor.action.formatDocument", "editor.action.formatSelection"])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        // Commands: the three provider-execute commands, the format trigger,
        // and the two action commands, in manifest source order.
        XCTAssertEqual(MonaFormatFeature.declaredCommandIds, [
            "_executeFormatDocumentProvider",
            "_executeFormatOnTypeProvider",
            "_executeFormatRangeProvider",
            "editor.action.format",
            "editor.action.formatDocument",
            "editor.action.formatSelection"
        ])
        for id in MonaFormatFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaFormatFeature.declaredContributionIds, [
            "editor.contrib.autoFormat",
            "editor.contrib.formatOnPaste"
        ])
        for id in MonaFormatFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        let kbCommands = MonaFormatFeature.declaredKeybindingCommands
        XCTAssertEqual(kbCommands, ["editor.action.formatDocument", "editor.action.formatSelection"])
        let rowCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in kbCommands {
            XCTAssertTrue(rowCommands.contains(id), "missing keybinding for \(id)")
        }

        XCTAssertEqual(MonaFormatFeature.declaredOptionIds, ["formatOnPaste", "formatOnType"])
        for name in MonaFormatFeature.declaredOptionIds {
            XCTAssertNotNil(options.value(for: name), "missing option \(name)")
        }

        XCTAssertEqual(MonaFormatFeature.declaredMenuIds, ["EditorContext"])
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = MonaCodeModel(
            text: "a\nb",
            uri: MonaURI(scheme: "inmemory", path: "/fmt-async")
        )
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaFormatFeature()
        let edits = feature.formatDocument([
            MonaFormatEdit(range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1), text: "!")
        ])
        let ticket = gate.captureTicket()

        var received: [MonaFormatEdit] = []
        let accepted = feature.publishFormatEdits(
            edits,
            executor: executor,
            ticket: ticket
        ) { delivered in received = delivered }
        XCTAssertTrue(accepted)
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, edits.count)
        XCTAssertEqual(received, edits)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaFormatFeature()
        var fired: [MonaFormatEvent] = []
        _ = feature.onChange { fired.append($0) }
        _ = feature.formatDocument([
            MonaFormatEdit(range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1), text: "x")
        ])
        XCTAssertEqual(fired.count, 1)
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        _ = feature.formatDocument([
            MonaFormatEdit(range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1), text: "x")
        ])
        XCTAssertEqual(fired.count, 1)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaFormatFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaFormatFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Format Document")
        XCTAssertEqual(enLabels[1], "Format Selection")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaFormatFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        XCTAssertEqual(feature.degradedLanguage.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(feature.degradedLanguage.hasTokenization)
    }

    // MARK: - Contract leaf

    func testFormatContractLeaf() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()
        let feature = MonaFormatFeature()

        let featureLive = features.contains(MonaFormatFeature.featureId)
        let actionCount = MonaFormatFeature.declaredActionIds.count
        let commandCount = MonaFormatFeature.declaredCommandIds.count
        let contribCount = MonaFormatFeature.declaredContributionIds.count
        let kbCount = MonaFormatFeature.declaredKeybindingCommands.count
        let optionCount = MonaFormatFeature.declaredOptionIds.count
        let menuCount = MonaFormatFeature.declaredMenuIds.count

        let slicePass = MonaFormatFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaFormatFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaFormatFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaFormatFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
        let kbPass = MonaFormatFeature.declaredKeybindingCommands.allSatisfy {
            Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
        }

        // Mutation: apply accepted format edits through the transaction gateway.
        let model = MonaCodeModel(text: "abc\ndef", uri: MonaURI(scheme: "inmemory", path: "/leaf"))
        let gateway = MonaTransactionGateway(model: model)
        let edits = feature.formatDocument([
            MonaFormatEdit(range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1), text: "!")
        ])
        let mutation = feature.applyFormatEdits(edits, gateway: gateway) == .applied

        // Async: publish format edits through the provider executor.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishFormatEdits(edits, executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed
        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("FORMAT feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(kbPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
