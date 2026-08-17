// MonaDndFeatureTests.swift
//
// P05-T114 — Implement retained feature dnd.
//
// Verifies the dnd feature across its three implementation operations:
//   1. Feature-specific behavior: register drag-and-drop editor behavior over
//      the native drop gateway (`MonaDragDropGateway` P04-T009) — register the
//      behavior over a gateway, commit a resolved drop through the transaction
//      gateway, and orchestrate the full drop (stale-geometry rejection,
//      payload reading, drop-edit provider chain, commit).
//   2. The exact feature identity `dnd` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     DND feature=live actions=0 commands=0 contributions=1 keybindings=0 options=1 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import MonaCode
@testable import MonaCodeAppKit

final class MonaDndFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "abcdef") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/dnd-\(UUID().uuidString)")
        )
    }

    private func makePasteboard(_ text: String) -> NSPasteboard {
        let pb = NSPasteboard(name: NSPasteboard.Name("dnd-test-\(UUID().uuidString)"))
        pb.declareTypes([.string], owner: nil)
        pb.setString(text, forType: .string)
        return pb
    }

    // MARK: - 1. Feature-specific behavior: register dnd behavior over the gateway

    func testRegisterBehaviorOverGatewayReturnsDeclaredContributionSlice() {
        let feature = MonaDndFeature()
        let gateway = MonaDragDropGateway()

        let registered = feature.registerBehavior(gateway: gateway)

        XCTAssertEqual(registered, MonaDndFeature.declaredContributionIds)
        XCTAssertTrue(feature.isRegistered)
    }

    func testCommitDropInsertsContentAtPositionThroughTransactionGateway() {
        let feature = MonaDndFeature()
        _ = feature.registerBehavior(gateway: MonaDragDropGateway())
        let model = makeModel("abcdef")
        let gateway = MonaTransactionGateway(model: model)
        let content = MonaClipboardContent(plainText: "XYZ", richText: nil, metadata: nil)

        let outcome = feature.commitDrop(
            content: content,
            at: MonaPosition(line: 1, column: 4),
            gateway: gateway
        )

        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "abcXYZdef")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testCommitDropWithNoTextIsDropped() {
        let feature = MonaDndFeature()
        _ = feature.registerBehavior(gateway: MonaDragDropGateway())
        let model = makeModel("abcdef")
        let gateway = MonaTransactionGateway(model: model)
        let content = MonaClipboardContent(plainText: nil, richText: nil, metadata: nil)

        let outcome = feature.commitDrop(
            content: content,
            at: MonaPosition(line: 1, column: 4),
            gateway: gateway
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "abcdef")
        } else {
            XCTFail("expected dropped, got \(outcome)")
        }
    }

    func testCommitDropFiresEventWithCommittedTextLength() {
        let feature = MonaDndFeature()
        _ = feature.registerBehavior(gateway: MonaDragDropGateway())
        let model = makeModel("abcdef")
        let gateway = MonaTransactionGateway(model: model)
        var fired: [MonaDndEvent] = []
        _ = feature.onChange { fired.append($0) }

        _ = feature.commitDrop(
            content: MonaClipboardContent(plainText: "XYZ", richText: nil, metadata: nil),
            at: MonaPosition(line: 1, column: 4),
            gateway: gateway
        )
        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(fired.first?.committedTextLength, 3)
        XCTAssertEqual(fired.first?.position, MonaPosition(line: 1, column: 4))
    }

    func testPerformDropOrchestratesPayloadReadProviderChainAndCommit() {
        let feature = MonaDndFeature()
        let dndGateway = MonaDragDropGateway()
        _ = feature.registerBehavior(gateway: dndGateway)
        let model = makeModel("abcdef")
        let txGateway = MonaTransactionGateway(model: model)
        let pb = makePasteboard("XYZ")
        let geometry = MonaDropGeometry(
            position: MonaPosition(line: 1, column: 4),
            resolvedVersionId: model.getVersionId()
        )

        let outcome = feature.performDrop(
            pasteboard: pb,
            operation: .copy,
            geometry: geometry,
            model: model,
            gateway: dndGateway,
            transactionGateway: txGateway
        )

        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "abcXYZdef")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testPerformDropRejectsStaleGeometry() {
        let feature = MonaDndFeature()
        let dndGateway = MonaDragDropGateway()
        _ = feature.registerBehavior(gateway: dndGateway)
        let model = makeModel("abcdef")
        let txGateway = MonaTransactionGateway(model: model)
        // The model advanced past the geometry's resolved version.
        model.setValue("abcdefg")
        let pb = makePasteboard("XYZ")
        let geometry = MonaDropGeometry(
            position: MonaPosition(line: 1, column: 4),
            resolvedVersionId: model.getVersionId() - 1
        )

        let outcome = feature.performDrop(
            pasteboard: pb,
            operation: .copy,
            geometry: geometry,
            model: model,
            gateway: dndGateway,
            transactionGateway: txGateway
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "abcdefg")
        } else {
            XCTFail("expected dropped for stale geometry, got \(outcome)")
        }
    }

    func testPerformDropRejectsEmptyPasteboard() {
        let feature = MonaDndFeature()
        let dndGateway = MonaDragDropGateway()
        _ = feature.registerBehavior(gateway: dndGateway)
        let model = makeModel("abcdef")
        let txGateway = MonaTransactionGateway(model: model)
        let pb = NSPasteboard(name: NSPasteboard.Name("dnd-empty-\(UUID().uuidString)"))
        pb.clearContents()
        let geometry = MonaDropGeometry(
            position: MonaPosition(line: 1, column: 4),
            resolvedVersionId: model.getVersionId()
        )

        let outcome = feature.performDrop(
            pasteboard: pb,
            operation: .copy,
            geometry: geometry,
            model: model,
            gateway: dndGateway,
            transactionGateway: txGateway
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "abcdef")
        } else {
            XCTFail("expected dropped for empty pasteboard, got \(outcome)")
        }
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()

        XCTAssertEqual(MonaDndFeature.featureId, "dnd")
        XCTAssertTrue(features.contains("dnd"))

        // dnd declares no actions / commands / keybindings / menus — it is the
        // drag-and-drop contribution + the `dragAndDrop` option.
        XCTAssertEqual(MonaDndFeature.declaredActionIds, [])
        XCTAssertEqual(MonaDndFeature.declaredCommandIds, [])
        XCTAssertEqual(MonaDndFeature.declaredKeybindingCommands, [])
        XCTAssertEqual(MonaDndFeature.declaredMenuIds, [])

        XCTAssertEqual(MonaDndFeature.declaredContributionIds, ["editor.contrib.dragAndDrop"])
        for id in MonaDndFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaDndFeature.declaredOptionIds, ["dragAndDrop"])
        for id in MonaDndFeature.declaredOptionIds {
            XCTAssertNotNil(options.value(for: id), "missing option \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaDndFeature()
        _ = feature.registerBehavior(gateway: MonaDragDropGateway())
        let ticket = gate.captureTicket()

        var received: MonaDndEvent?
        let accepted = feature.publishDndEvent(
            MonaDndEvent(operation: .copy, position: MonaPosition(line: 1, column: 1), committedTextLength: 3),
            executor: executor,
            ticket: ticket
        ) { event in received = event }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertNotNil(received)
        XCTAssertEqual(received?.committedTextLength, 3)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaDndFeature()
        var fired: [MonaDndEvent] = []
        _ = feature.onChange { fired.append($0) }
        _ = feature.registerBehavior(gateway: MonaDragDropGateway())
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, register / commit are no-ops.
        let registered = feature.registerBehavior(gateway: MonaDragDropGateway())
        XCTAssertTrue(registered.isEmpty)
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.commitDrop(
            content: MonaClipboardContent(plainText: "X", richText: nil, metadata: nil),
            at: MonaPosition(line: 1, column: 1),
            gateway: gateway
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "abc")
        } else {
            XCTFail("expected dropped after disposal, got \(outcome)")
        }
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaDndFeature()
        // dnd declares no actions; labels are empty.
        XCTAssertEqual(feature.localizedActionLabels(profile: .default).count, 0)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaDndFeature()
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
        let options = MonaOptionStore()
        let feature = MonaDndFeature()
        let dndGateway = MonaDragDropGateway()

        let featureLive = features.contains(MonaDndFeature.featureId)
        let actionCount = MonaDndFeature.declaredActionIds.count
        let commandCount = MonaDndFeature.declaredCommandIds.count
        let contribCount = MonaDndFeature.declaredContributionIds.count
        let kbCount = MonaDndFeature.declaredKeybindingCommands.count
        let optionCount = MonaDndFeature.declaredOptionIds.count
        let menuCount = MonaDndFeature.declaredMenuIds.count

        let actionSlicePass = MonaDndFeature.declaredActionIds.allSatisfy { actions.contains($0) }
        let commandSlicePass = MonaDndFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
        let contribSlicePass = MonaDndFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
        let kbSlicePass = MonaDndFeature.declaredKeybindingCommands.allSatisfy {
            Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
        }
        let optionSlicePass = MonaDndFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
        let menuSlicePass = MonaDndFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }
        let slicePass = actionSlicePass && commandSlicePass && contribSlicePass && kbSlicePass && optionSlicePass && menuSlicePass

        // Register the dnd behavior over the native drop gateway.
        let registered = feature.registerBehavior(gateway: dndGateway)
        let registrationPass = registered == MonaDndFeature.declaredContributionIds && feature.isRegistered

        // Mutation: commit a resolved drop through the transaction gateway.
        let model = makeModel("abcdef")
        let txGateway = MonaTransactionGateway(model: model)
        let outcome = feature.commitDrop(
            content: MonaClipboardContent(plainText: "XYZ", richText: nil, metadata: nil),
            at: MonaPosition(line: 1, column: 4),
            gateway: txGateway
        )
        let mutation: Bool
        if case .applied = outcome, model.getValue() == "abcXYZdef" {
            mutation = true
        } else {
            mutation = false
        }

        // Full drop orchestration over the gateway (stale-geometry rejection).
        let pb = makePasteboard("123")
        let staleGeometry = MonaDropGeometry(
            position: MonaPosition(line: 1, column: 4),
            resolvedVersionId: model.getVersionId() - 1
        )
        let staleOutcome = feature.performDrop(
            pasteboard: pb,
            operation: .copy,
            geometry: staleGeometry,
            model: model,
            gateway: dndGateway,
            transactionGateway: txGateway
        )
        let staleRejected: Bool
        if case .dropped = staleOutcome {
            staleRejected = true
        } else {
            staleRejected = false
        }

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishDndEvent(
            MonaDndEvent(operation: .copy, position: MonaPosition(line: 1, column: 1), committedTextLength: 0),
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("DND feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(registrationPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(staleRejected)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
