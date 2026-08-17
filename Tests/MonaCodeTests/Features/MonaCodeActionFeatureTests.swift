// MonaCodeActionFeatureTests.swift
//
// P05-T104 — Implement retained feature codeAction.
//
// Verifies the codeAction feature across its three implementation operations:
//   1. Feature-specific behavior: surface provider code actions, resolve them,
//      and apply accepted edits transactionally (via MonaTransactionGateway).
//   2. The exact feature identity `codeAction` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     CODEACTION feature=live actions=5 commands=17 contributions=2 keybindings=13 options=0 menus=3 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaCodeActionFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "let x = 1\nlet y = 2") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/codeaction-\(UUID().uuidString)")
        )
    }

    private func sampleActions() -> [MonaCodeAction] {
        return [
            MonaCodeAction(
                title: "Extract variable",
                kind: .refactor,
                edits: [
                    MonaCodeActionEdit(
                        range: MonaRange(
                            startPosition: MonaPosition(line: 1, column: 5),
                            endPosition: MonaPosition(line: 1, column: 6)
                        ),
                        text: "z"
                    )
                ],
                isPreferred: false
            ),
            MonaCodeAction(
                title: "Organize Imports",
                kind: .sourceOrganizeImports,
                edits: [],
                isPreferred: false
            ),
            MonaCodeAction(
                title: "Fix typo",
                kind: .quickFix,
                edits: [
                    MonaCodeActionEdit(
                        range: MonaRange(
                            startPosition: MonaPosition(line: 1, column: 1),
                            endPosition: MonaPosition(line: 1, column: 4)
                        ),
                        text: "const"
                    )
                ],
                isPreferred: true
            )
        ]
    }

    // MARK: - 1. Feature-specific behavior: surface / resolve / apply

    func testProvideCodeActionsSurfacesAllActionsWhenKindIsNil() {
        let feature = MonaCodeActionFeature()
        let provided = feature.provideCodeActions(sampleActions(), kind: nil)
        XCTAssertEqual(provided.count, 3)
        XCTAssertEqual(provided.map { $0.title }, ["Extract variable", "Organize Imports", "Fix typo"])
    }

    func testProvideCodeActionsFiltersByKind() {
        let feature = MonaCodeActionFeature()
        let quickFixes = feature.provideCodeActions(sampleActions(), kind: .quickFix)
        XCTAssertEqual(quickFixes.count, 1)
        XCTAssertEqual(quickFixes[0].title, "Fix typo")
        XCTAssertTrue(quickFixes[0].isPreferred)

        let refactors = feature.provideCodeActions(sampleActions(), kind: .refactor)
        XCTAssertEqual(refactors.count, 1)
        XCTAssertEqual(refactors[0].title, "Extract variable")

        let sources = feature.provideCodeActions(sampleActions(), kind: .sourceOrganizeImports)
        XCTAssertEqual(sources.count, 1)
    }

    func testResolveCodeActionReturnsActionWithEditsIntact() {
        let feature = MonaCodeActionFeature()
        let original = sampleActions()[2] // the quick fix
        let resolved = feature.resolveCodeAction(original)
        XCTAssertEqual(resolved.title, original.title)
        XCTAssertEqual(resolved.kind, original.kind)
        XCTAssertEqual(resolved.edits, original.edits)
        XCTAssertEqual(resolved.isPreferred, original.isPreferred)
    }

    func testApplyCodeActionCommitsEditsTransactionallyThroughGateway() {
        let feature = MonaCodeActionFeature()
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)
        let action = MonaCodeAction(
            title: "Replace",
            kind: .refactor,
            edits: [
                MonaCodeActionEdit(
                    range: MonaRange(
                        startPosition: MonaPosition(line: 1, column: 1),
                        endPosition: MonaPosition(line: 1, column: 4)
                    ),
                    text: "HEL"
                )
            ],
            isPreferred: false
        )
        let outcome = feature.applyCodeAction(action, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "HELlo")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testApplyCodeActionWithNoEditsCommitsEmptyTransaction() {
        let feature = MonaCodeActionFeature()
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)
        let action = MonaCodeAction(
            title: "Organize Imports",
            kind: .sourceOrganizeImports,
            edits: [],
            isPreferred: false
        )
        let outcome = feature.applyCodeAction(action, gateway: gateway)
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

        XCTAssertEqual(MonaCodeActionFeature.featureId, "codeAction")
        XCTAssertTrue(features.contains("codeAction"))

        let actionIds = MonaCodeActionFeature.declaredActionIds
        XCTAssertEqual(actionIds, [
            "editor.action.refactor",
            "editor.action.sourceAction",
            "editor.action.organizeImports",
            "editor.action.autoFix",
            "editor.action.fixAll"
        ])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        let commandIds = MonaCodeActionFeature.declaredCommandIds
        XCTAssertEqual(commandIds, [
            "_executeCodeActionProvider",
            "acceptSelectedCodeAction",
            "clearFilterCodeActionWidget",
            "collapseSectionCodeAction",
            "editor.action.autoFix",
            "editor.action.codeAction",
            "editor.action.fixAll",
            "editor.action.organizeImports",
            "editor.action.quickFix",
            "editor.action.refactor",
            "editor.action.sourceAction",
            "expandSectionCodeAction",
            "hideCodeActionWidget",
            "previewSelectedCodeAction",
            "selectNextCodeAction",
            "selectPrevCodeAction",
            "toggleSectionCodeAction"
        ])
        for id in commandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaCodeActionFeature.declaredContributionIds, [
            "editor.contrib.codeActionController",
            "editor.contrib.lightbulbWidget"
        ])
        for id in MonaCodeActionFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        let kbCommands = MonaCodeActionFeature.declaredKeybindingCommands
        let keybindingCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in kbCommands {
            XCTAssertTrue(keybindingCommands.contains(id), "missing keybinding for \(id)")
        }

        XCTAssertTrue(MonaCodeActionFeature.declaredOptionIds.isEmpty)

        XCTAssertEqual(MonaCodeActionFeature.declaredMenuIds, [
            "CommandPalette",
            "EditorContext",
            "InlineChatEditorAffordance"
        ])
        for id in MonaCodeActionFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaCodeActionFeature()
        let ticket = gate.captureTicket()

        var received: [MonaCodeAction] = []
        let accepted = feature.publishCodeActions(
            sampleActions(),
            executor: executor,
            ticket: ticket
        ) { actions in
            received = actions
        }
        XCTAssertTrue(accepted)
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 3)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaCodeActionFeature()
        var fired: [MonaCodeActionEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaCodeActionFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaCodeActionFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Refactor...")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaCodeActionFeature()
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
        let feature = MonaCodeActionFeature()

        let featureLive = features.contains(MonaCodeActionFeature.featureId)
        let actionCount = MonaCodeActionFeature.declaredActionIds.count
        let commandCount = MonaCodeActionFeature.declaredCommandIds.count
        let contribCount = MonaCodeActionFeature.declaredContributionIds.count
        let kbCount = MonaCodeActionFeature.declaredKeybindingCommands.count
        let optionCount = MonaCodeActionFeature.declaredOptionIds.count
        let menuCount = MonaCodeActionFeature.declaredMenuIds.count

        let slicePass = MonaCodeActionFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaCodeActionFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaCodeActionFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaCodeActionFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaCodeActionFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Mutation: apply a code action through the transaction gateway.
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)
        let applyAction = MonaCodeAction(
            title: "Replace",
            kind: .refactor,
            edits: [
                MonaCodeActionEdit(
                    range: MonaRange(
                        startPosition: MonaPosition(line: 1, column: 1),
                        endPosition: MonaPosition(line: 1, column: 4)
                    ),
                    text: "HEL"
                )
            ],
            isPreferred: false
        )
        let mutation: Bool
        let outcome = feature.applyCodeAction(applyAction, gateway: gateway)
        if case .applied = outcome, model.getValue() == "HELlo" {
            mutation = true
        } else {
            mutation = false
        }

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishCodeActions([], executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("CODEACTION feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
