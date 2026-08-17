// MonaCommentFeatureTests.swift
//
// P05-T109 — Implement retained feature comment.
//
// Verifies the comment feature across its three implementation operations:
//   1. Feature-specific behavior: execute line and block comment commands
//      from explicit language configuration only (via MonaTransactionGateway
//      for mutation).
//   2. The exact feature identity `comment` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     COMMENT feature=live actions=4 commands=4 contributions=0 keybindings=4 options=1 menus=1 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaCommentFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "let x = 1\nlet y = 2") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/comment-\(UUID().uuidString)")
        )
    }

    /// A Swift-like configuration: `//` line comments, `/* */` block comments.
    private func swiftConfig() -> MonaCommentConfiguration {
        return MonaCommentConfiguration(
            lineComment: "//",
            blockCommentOpen: "/*",
            blockCommentClose: "*/"
        )
    }

    // MARK: - 1. Feature-specific behavior: line / block comment commands from explicit config

    func testToggleLineCommentAddsLineCommentTokenToEachLine() {
        let feature = MonaCommentFeature()
        let model = makeModel("a\nb")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.toggleLineComment(
            range: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 2, column: 2)
            ),
            configuration: swiftConfig(),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "// a\n// b")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testToggleLineCommentRemovesExistingLineCommentToken() {
        let feature = MonaCommentFeature()
        let model = makeModel("// a\n// b")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.toggleLineComment(
            range: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 2, column: 5)
            ),
            configuration: swiftConfig(),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "a\nb")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testAddLineCommentAlwaysAddsToken() {
        let feature = MonaCommentFeature()
        let model = makeModel("a\nb")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.addLineComment(
            range: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 2, column: 2)
            ),
            configuration: swiftConfig(),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "// a\n// b")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testRemoveLineCommentStripsLeadingToken() {
        let feature = MonaCommentFeature()
        let model = makeModel("// a\n// b")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.removeLineComment(
            range: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 2, column: 5)
            ),
            configuration: swiftConfig(),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "a\nb")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testToggleBlockCommentWrapsSelection() {
        let feature = MonaCommentFeature()
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.toggleBlockComment(
            range: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 1, column: 6)
            ),
            configuration: swiftConfig(),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "/*hello*/")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testToggleBlockCommentUnwrapsWhenAlreadyWrapped() {
        let feature = MonaCommentFeature()
        let model = makeModel("/*hello*/")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.toggleBlockComment(
            range: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 1, column: 10)
            ),
            configuration: swiftConfig(),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "hello")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testCommandsAreNoOpsAfterDisposal() {
        let feature = MonaCommentFeature()
        let model = makeModel("a\nb")
        let gateway = MonaTransactionGateway(model: model)
        feature.dispose()

        let outcome = feature.toggleLineComment(
            range: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 2, column: 2)
            ),
            configuration: swiftConfig(),
            gateway: gateway
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "a\nb")
        } else {
            XCTFail("expected dropped after disposal, got \(outcome)")
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

        XCTAssertEqual(MonaCommentFeature.featureId, "comment")
        XCTAssertTrue(features.contains("comment"))

        let actionIds = MonaCommentFeature.declaredActionIds
        XCTAssertEqual(actionIds, [
            "editor.action.commentLine",
            "editor.action.addCommentLine",
            "editor.action.removeCommentLine",
            "editor.action.blockComment"
        ])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        let commandIds = MonaCommentFeature.declaredCommandIds
        XCTAssertEqual(commandIds, [
            "editor.action.commentLine",
            "editor.action.addCommentLine",
            "editor.action.removeCommentLine",
            "editor.action.blockComment"
        ])
        for id in commandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaCommentFeature.declaredContributionIds, [])

        XCTAssertEqual(MonaCommentFeature.declaredKeybindingCommands, [
            "editor.action.commentLine",
            "editor.action.addCommentLine",
            "editor.action.removeCommentLine",
            "editor.action.blockComment"
        ])
        for id in MonaCommentFeature.declaredKeybindingCommands {
            let kbCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
            XCTAssertTrue(kbCommands.contains(id), "missing keybinding \(id)")
        }

        XCTAssertEqual(MonaCommentFeature.declaredOptionIds, ["comments"])
        for id in MonaCommentFeature.declaredOptionIds {
            XCTAssertNotNil(options.value(for: id), "missing option \(id)")
        }

        XCTAssertEqual(MonaCommentFeature.declaredMenuIds, ["MenubarEditMenu"])
        for id in MonaCommentFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaCommentFeature()
        let ticket = gate.captureTicket()

        var received: [MonaCommentEvent] = []
        let accepted = feature.publishCommentEvent(
            MonaCommentEvent(action: .toggleLineComment, lines: [1, 2]),
            executor: executor,
            ticket: ticket
        ) { event in
            received.append(event)
        }
        XCTAssertTrue(accepted)
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaCommentFeature()
        var fired: [MonaCommentEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaCommentFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaCommentFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Toggle Line Comment")
        XCTAssertEqual(enLabels[1], "Add Line Comment")
        XCTAssertEqual(enLabels[2], "Remove Line Comment")
        XCTAssertEqual(enLabels[3], "Toggle Block Comment")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaCommentFeature()
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
        let feature = MonaCommentFeature()

        let featureLive = features.contains(MonaCommentFeature.featureId)
        let actionCount = MonaCommentFeature.declaredActionIds.count
        let commandCount = MonaCommentFeature.declaredCommandIds.count
        let contribCount = MonaCommentFeature.declaredContributionIds.count
        let kbCount = MonaCommentFeature.declaredKeybindingCommands.count
        let optionCount = MonaCommentFeature.declaredOptionIds.count
        let menuCount = MonaCommentFeature.declaredMenuIds.count

        let slicePass = MonaCommentFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaCommentFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaCommentFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaCommentFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaCommentFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
            && MonaCommentFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Mutation: toggle line comment through the transaction gateway.
        let model = makeModel("a\nb")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.toggleLineComment(
            range: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 2, column: 2)
            ),
            configuration: swiftConfig(),
            gateway: gateway
        )
        let mutation: Bool
        if case .applied = outcome, model.getValue() == "// a\n// b" {
            mutation = true
        } else {
            mutation = false
        }

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishCommentEvent(
            MonaCommentEvent(action: .toggleLineComment, lines: [1]),
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("COMMENT feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
