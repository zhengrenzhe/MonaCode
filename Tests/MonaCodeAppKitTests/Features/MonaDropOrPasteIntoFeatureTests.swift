// MonaDropOrPasteIntoFeatureTests.swift
//
// P05-T116 — Implement retained feature dropOrPasteInto.
//
// Verifies the dropOrPasteInto feature across its three implementation operations:
//   1. Feature-specific behavior: select and apply explicit drop-or-paste edit
//      proposals over the native drop gateway (P04-T009) / paste pipeline
//      (P04-T008). Provider proposals are surfaced (optionally filtered by
//      kind), one is selected, and its edits apply transactionally through
//      `MonaTransactionGateway`.
//   2. The exact feature identity `dropOrPasteInto` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     DROPORPASTEINTO feature=live actions=2 commands=6 contributions=2 keybindings=4 options=2 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import MonaCode
@testable import MonaCodeAppKit

final class MonaDropOrPasteIntoFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "hello world") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/droppaste-\(UUID().uuidString)")
        )
    }

    private func makeProposal(
        title: String,
        kind: MonaDropOrPasteKind = .text,
        text: String = "X",
        isDefault: Bool = false
    ) -> MonaDropOrPasteProposal {
        return MonaDropOrPasteProposal(
            title: title,
            kind: kind,
            edits: [
                MonaDropOrPasteEdit(
                    range: MonaRange(
                        startPosition: MonaPosition(line: 1, column: 1),
                        endPosition: MonaPosition(line: 1, column: 6)
                    ),
                    text: text
                )
            ],
            isDefault: isDefault
        )
    }

    // MARK: - 1. Feature-specific behavior: select and apply drop-or-paste edit proposals

    func testSurfaceProposalsReturnsAllWhenKindIsNil() {
        let feature = MonaDropOrPasteIntoFeature()
        let proposals = [
            makeProposal(title: "Paste as Text", kind: .text),
            makeProposal(title: "Insert URI List", kind: .uriList)
        ]

        let surfaced = feature.surfaceProposals(proposals, kind: nil)

        XCTAssertEqual(surfaced.count, 2)
    }

    func testSurfaceProposalsFiltersByKind() {
        let feature = MonaDropOrPasteIntoFeature()
        let proposals = [
            makeProposal(title: "Paste as Text", kind: .text),
            makeProposal(title: "Insert URI List", kind: .uriList),
            makeProposal(title: "Paste as Text (plain)", kind: .text)
        ]

        let surfaced = feature.surfaceProposals(proposals, kind: .text)

        XCTAssertEqual(surfaced.count, 2)
        XCTAssertTrue(surfaced.allSatisfy { $0.kind == .text })
    }

    func testSelectProposalFiresEventAndReturnsSelected() {
        let feature = MonaDropOrPasteIntoFeature()
        var fired: [MonaDropOrPasteIntoEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        let proposal = makeProposal(title: "Paste as Text", isDefault: true)

        let selected = feature.selectProposal(proposal)

        XCTAssertEqual(selected.title, "Paste as Text")
        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(fired.first?.proposals.count, 1)
        XCTAssertEqual(fired.first?.proposals.first?.title, "Paste as Text")
    }

    func testApplyProposalRoutesEditsThroughTransactionGateway() {
        let feature = MonaDropOrPasteIntoFeature()
        let model = makeModel("hello world")
        let gateway = MonaTransactionGateway(model: model)
        let proposal = makeProposal(title: "Paste as Text", text: "HELLO")

        let outcome = feature.applyProposal(proposal, gateway: gateway)

        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "HELLO world")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testApplyProposalWithoutEditsIsAcknowledged() {
        let feature = MonaDropOrPasteIntoFeature()
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)
        let proposal = MonaDropOrPasteProposal(
            title: "No-op",
            kind: .text,
            edits: [],
            isDefault: false
        )

        let outcome = feature.applyProposal(proposal, gateway: gateway)

        switch outcome {
        case .applied, .reconciled:
            XCTAssertEqual(model.getValue(), "hello")
        default:
            XCTFail("expected applied/reconciled, got \(outcome)")
        }
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()
        let options = MonaOptionStore()

        XCTAssertEqual(MonaDropOrPasteIntoFeature.featureId, "dropOrPasteInto")
        XCTAssertTrue(features.contains("dropOrPasteInto"))

        XCTAssertEqual(MonaDropOrPasteIntoFeature.declaredActionIds, [
            "editor.action.pasteAs",
            "editor.action.pasteAsText"
        ])
        for id in MonaDropOrPasteIntoFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
        }

        XCTAssertEqual(MonaDropOrPasteIntoFeature.declaredCommandIds, [
            "editor.action.pasteAs",
            "editor.action.pasteAsText",
            "editor.changeDropType",
            "editor.changePasteType",
            "editor.hideDropWidget",
            "editor.hidePasteWidget"
        ])
        for id in MonaDropOrPasteIntoFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaDropOrPasteIntoFeature.declaredContributionIds, [
            "editor.contrib.dropIntoEditorController",
            "editor.contrib.copyPasteActionController"
        ])
        for id in MonaDropOrPasteIntoFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaDropOrPasteIntoFeature.declaredKeybindingCommands, [
            "editor.changeDropType",
            "editor.changePasteType",
            "editor.hideDropWidget",
            "editor.hidePasteWidget"
        ])

        XCTAssertEqual(MonaDropOrPasteIntoFeature.declaredOptionIds, [
            "dropIntoEditor",
            "pasteAs"
        ])
        for id in MonaDropOrPasteIntoFeature.declaredOptionIds {
            XCTAssertNotNil(options.value(for: id), "missing option \(id)")
        }

        XCTAssertEqual(MonaDropOrPasteIntoFeature.declaredMenuIds, [])
        for id in MonaDropOrPasteIntoFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaDropOrPasteIntoFeature()
        let ticket = gate.captureTicket()
        let proposal = makeProposal(title: "Paste as Text")

        var received: MonaDropOrPasteIntoEvent?
        let accepted = feature.publishDropOrPasteEvent(
            MonaDropOrPasteIntoEvent(proposals: [proposal]),
            executor: executor,
            ticket: ticket
        ) { event in received = event }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertNotNil(received)
        XCTAssertEqual(received?.proposals.count, 1)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaDropOrPasteIntoFeature()
        var fired: [MonaDropOrPasteIntoEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, select / apply are no-ops.
        let proposal = makeProposal(title: "Paste as Text")
        let selected = feature.selectProposal(proposal)
        // selectProposal returns the proposal unchanged after disposal but
        // fires no event.
        XCTAssertEqual(selected.title, "Paste as Text")
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.applyProposal(proposal, gateway: gateway)
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "hello")
        } else {
            XCTFail("expected dropped after disposal, got \(outcome)")
        }
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaDropOrPasteIntoFeature()
        let enActionLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enActionLabels.count, MonaDropOrPasteIntoFeature.declaredActionIds.count)
        XCTAssertEqual(enActionLabels.first, "Paste As...")
        XCTAssertEqual(enActionLabels.last, "Paste as Text")
        let pseudoActionLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoActionLabels.allSatisfy { $0.hasPrefix("\u{FF3B}") && $0.hasSuffix("\u{FF3D}") })
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaDropOrPasteIntoFeature()
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
        let feature = MonaDropOrPasteIntoFeature()

        let featureLive = features.contains(MonaDropOrPasteIntoFeature.featureId)
        let actionCount = MonaDropOrPasteIntoFeature.declaredActionIds.count
        let commandCount = MonaDropOrPasteIntoFeature.declaredCommandIds.count
        let contribCount = MonaDropOrPasteIntoFeature.declaredContributionIds.count
        let kbCount = MonaDropOrPasteIntoFeature.declaredKeybindingCommands.count
        let optionCount = MonaDropOrPasteIntoFeature.declaredOptionIds.count
        let menuCount = MonaDropOrPasteIntoFeature.declaredMenuIds.count

        let slicePass = MonaDropOrPasteIntoFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaDropOrPasteIntoFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaDropOrPasteIntoFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaDropOrPasteIntoFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaDropOrPasteIntoFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
            && MonaDropOrPasteIntoFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Surface (filtered by kind) + select.
        let proposals = [
            makeProposal(title: "Paste as Text", kind: .text, isDefault: true),
            makeProposal(title: "Insert URI List", kind: .uriList)
        ]
        let surfaced = feature.surfaceProposals(proposals, kind: .text)
        let surfacePass = surfaced.count == 1 && surfaced.first?.title == "Paste as Text"
        let selected = feature.selectProposal(surfaced.first!)
        let selectPass = selected.title == "Paste as Text" && selected.isDefault

        // Mutation: the selected proposal's edits route through the gateway.
        let model = makeModel("hello world")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.applyProposal(
            makeProposal(title: "Paste as Text", text: "HELLO"),
            gateway: gateway
        )
        let mutation: Bool
        if case .applied = outcome, model.getValue() == "HELLO world" {
            mutation = true
        } else {
            mutation = false
        }

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishDropOrPasteEvent(
            MonaDropOrPasteIntoEvent(proposals: []),
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let actionLabelCount = feature.localizedActionLabels(profile: .default).count
        let localizationPass = actionLabelCount == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("DROPORPASTEINTO feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(surfacePass)
        XCTAssertTrue(selectPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
