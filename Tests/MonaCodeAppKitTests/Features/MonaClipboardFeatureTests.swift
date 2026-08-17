// MonaClipboardFeatureTests.swift
//
// P05-T103 — Implement retained feature clipboard.
//
// Verifies the clipboard feature across its three implementation operations:
//   1. Feature-specific behavior: register editor copy, cut, and paste actions
//      over the native transfer gateway (`MonaPasteboardGateway` /
//      `MonaPasteEditPipeline`).
//   2. The exact feature identity `clipboard` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     CLIPBOARD feature=live actions=1 commands=4 contributions=1 keybindings=0 options=1 menus=4 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import MonaCode
@testable import MonaCodeAppKit

final class MonaClipboardFeatureTests: XCTestCase {

    /// Creates a fresh, uniquely-named `NSPasteboard` so tests never collide
    /// with the system pasteboard or each other.
    private func makePasteboard() -> NSPasteboard {
        return NSPasteboard(name: NSPasteboard.Name("MonaClipboardTest-\(UUID().uuidString)"))
    }

    private func makeModel(_ text: String = "hello\nworld") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/clipboard-\(UUID().uuidString)")
        )
    }

    // MARK: - 1. Feature-specific behavior: copy / cut / paste over the gateway

    func testCopyWritesPlainTextAndEditorMetadataToPasteboard() {
        let pb = makePasteboard()
        let feature = MonaClipboardFeature(transferGateway: MonaPasteboardGateway(pasteboard: pb))
        let model = makeModel("abc")
        let selection = MonaSelection(
            anchor: MonaPosition(line: 1, column: 1),
            activePosition: MonaPosition(line: 1, column: 3)
        )
        let content = feature.copy(text: "ab", selection: selection, model: model)
        XCTAssertEqual(content.plainText, "ab")
        XCTAssertEqual(content.metadata?.sourceModelId, model.id)
        XCTAssertEqual(content.metadata?.selectionAnchorLine, 1)
        // The pasteboard now carries the plain text + metadata flavors.
        XCTAssertEqual(pb.string(forType: .string), "ab")
        XCTAssertNotNil(pb.data(forType: MonaPasteboardGateway.monacodeMetadataType))
    }

    func testCutWritesClipboardAndCommitsDeletionThroughBarrier() {
        let pb = makePasteboard()
        let feature = MonaClipboardFeature(transferGateway: MonaPasteboardGateway(pasteboard: pb))
        let model = makeModel("hello")
        let barrier = MonaModelInputBarrier(model: model)
        let selection = MonaSelection(
            anchor: MonaPosition(line: 1, column: 1),
            activePosition: MonaPosition(line: 1, column: 4)
        )
        let outcome = feature.cut(
            text: "hel",
            selections: [selection],
            model: model,
            barrier: barrier
        )
        if case .applied(let selections) = outcome {
            XCTAssertFalse(selections.isEmpty)
        } else {
            XCTFail("expected applied cut, got \(outcome)")
        }
        XCTAssertEqual(pb.string(forType: .string), "hel")
        XCTAssertNotNil(pb.data(forType: MonaPasteboardGateway.monacodeMetadataType))
    }

    func testPasteReadsPasteboardAndCommitsInsertionThroughBarrier() {
        let pb = makePasteboard()
        let feature = MonaClipboardFeature(transferGateway: MonaPasteboardGateway(pasteboard: pb))
        let model = makeModel("XY")
        // Seed the pasteboard with a copy first.
        let selection = MonaSelection(
            anchor: MonaPosition(line: 1, column: 1),
            activePosition: MonaPosition(line: 1, column: 2)
        )
        _ = feature.copy(text: "Z", selection: selection, model: model)

        let barrier = MonaModelInputBarrier(model: model)
        let outcome = feature.paste(
            cursorPositions: [MonaPosition(line: 1, column: 2)],
            barrier: barrier
        )
        if case .applied = outcome {
            // success
        } else {
            XCTFail("expected applied paste, got \(outcome)")
        }
    }

    func testPasteWithEmptyPasteboardIsDropped() {
        let pb = makePasteboard()
        pb.clearContents()
        let feature = MonaClipboardFeature(transferGateway: MonaPasteboardGateway(pasteboard: pb))
        let model = makeModel("abc")
        let barrier = MonaModelInputBarrier(model: model)
        let outcome = feature.paste(
            cursorPositions: [MonaPosition(line: 1, column: 1)],
            barrier: barrier
        )
        if case .dropped = outcome {
            // expected
        } else {
            XCTFail("expected dropped paste for empty pasteboard, got \(outcome)")
        }
    }

    func testCopyWithSyntaxHighlightingWritesRichText() {
        let pb = makePasteboard()
        let feature = MonaClipboardFeature(transferGateway: MonaPasteboardGateway(pasteboard: pb))
        let rich = NSAttributedString(string: "let x = 1")
        let content = feature.copyWithSyntaxHighlighting(richText: rich)
        XCTAssertEqual(content.plainText, "let x = 1")
        XCTAssertEqual(pb.string(forType: .string), "let x = 1")
        // The rich-text flavor is published on the pasteboard.
        XCTAssertNotNil(pb.data(forType: .rtf))
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaClipboardFeature.featureId, "clipboard")
        XCTAssertTrue(features.contains("clipboard"))

        // Declared actions (the single labeled editor action).
        let actionIds = MonaClipboardFeature.declaredActionIds
        XCTAssertEqual(actionIds, ["editor.action.clipboardCopyWithSyntaxHighlightingAction"])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        // Declared commands (copy / cut / paste + copy-with-syntax-highlighting).
        let commandIds = MonaClipboardFeature.declaredCommandIds
        XCTAssertEqual(commandIds, [
            "editor.action.clipboardCopyAction",
            "editor.action.clipboardCutAction",
            "editor.action.clipboardPasteAction",
            "editor.action.clipboardCopyWithSyntaxHighlightingAction"
        ])
        for id in commandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        // Declared contribution.
        XCTAssertEqual(MonaClipboardFeature.declaredContributionIds, ["editor.contrib.copyPasteActionController"])
        for id in MonaClipboardFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        // Declared keybindings: clipboard copy / cut / paste use native OS keys
        // and carry no builtin keybinding.
        XCTAssertTrue(MonaClipboardFeature.declaredKeybindingCommands.isEmpty)

        // Declared options (selectionClipboard is `cut`, excluded).
        XCTAssertEqual(MonaClipboardFeature.declaredOptionIds, ["emptySelectionClipboard"])

        // Declared menus (the menus that carry clipboard items).
        XCTAssertEqual(MonaClipboardFeature.declaredMenuIds, [
            "CommandPalette",
            "EditorContext",
            "MenubarEditMenu",
            "SimpleEditorContext"
        ])
        for id in MonaClipboardFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testModelMutationRoutesThroughTransactionGateway() {
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)
        let feature = MonaClipboardFeature(transferGateway: MonaPasteboardGateway(pasteboard: makePasteboard()))
        let selection = MonaSelection(
            anchor: MonaPosition(line: 1, column: 1),
            activePosition: MonaPosition(line: 1, column: 3)
        )
        let committed = feature.commitCopySelection(gateway: gateway, selection: selection)
        XCTAssertEqual(committed.count, 1)
        XCTAssertEqual(gateway.lastCommittedSelections, committed)
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaClipboardFeature(transferGateway: MonaPasteboardGateway(pasteboard: makePasteboard()))
        let ticket = gate.captureTicket()

        var received: String?
        let accepted = feature.publishClipboardContent(
            "payload",
            executor: executor,
            ticket: ticket
        ) { plainText in
            received = plainText
        }
        XCTAssertTrue(accepted)
        XCTAssertTrue(received == nil)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received, "payload")
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaClipboardFeature(transferGateway: MonaPasteboardGateway(pasteboard: makePasteboard()))
        var fired: [MonaClipboardAction] = []
        _ = feature.onChange { event in fired.append(event.action) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaClipboardFeature(transferGateway: MonaPasteboardGateway(pasteboard: makePasteboard()))
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaClipboardFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Copy with Syntax Highlighting")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaClipboardFeature(transferGateway: MonaPasteboardGateway(pasteboard: makePasteboard()))
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
        let feature = MonaClipboardFeature(transferGateway: MonaPasteboardGateway(pasteboard: makePasteboard()))

        let featureLive = features.contains(MonaClipboardFeature.featureId)
        let actionCount = MonaClipboardFeature.declaredActionIds.count
        let commandCount = MonaClipboardFeature.declaredCommandIds.count
        let contribCount = MonaClipboardFeature.declaredContributionIds.count
        let kbCount = MonaClipboardFeature.declaredKeybindingCommands.count
        let optionCount = MonaClipboardFeature.declaredOptionIds.count
        let menuCount = MonaClipboardFeature.declaredMenuIds.count

        let slicePass = MonaClipboardFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaClipboardFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaClipboardFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaClipboardFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Mutation + async + disposal + localization + plaintext routing.
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)
        let mutation = feature.commitCopySelection(
            gateway: gateway,
            selection: MonaSelection(
                anchor: MonaPosition(line: 1, column: 1),
                activePosition: MonaPosition(line: 1, column: 3)
            )
        ).count == 1 && gateway.lastCommittedSelections.count == 1

        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishClipboardContent(nil, executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("CLIPBOARD feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
