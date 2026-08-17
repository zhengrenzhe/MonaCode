// MonaIndentationFeatureTests.swift
//
// P05-T126 — Implement retained feature indentation.
//
// Verifies the indentation feature across its three implementation operations:
//   1. Feature-specific behavior: detect, convert, and reindent whitespace from
//      explicit model options (reuse T005 `MonaOptionStore` for indentation
//      options like tabSize/insertSpaces).
//   2. The exact feature identity `indentation` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testIndentationContractLeaf` prints the contract line:
//     INDENTATION feature=live actions=9 commands=9 contributions=1 keybindings=2 options=3 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaIndentationFeatureTests: XCTestCase {

    // MARK: - 1. Feature-specific behavior: detect + convert + reindent

    func testDetectIndentationPrefersSpacesWhenMajoritySpaceLed() {
        let feature = MonaIndentationFeature()
        let text = "    a\n        b\n    c\nd\n"
        let detection = feature.detectIndentation(
            text,
            defaultInsertSpaces: false,
            defaultTabSize: 4
        )
        XCTAssertTrue(detection.insertSpaces)
        XCTAssertEqual(detection.tabSize, 4)
    }

    func testDetectIndentationPrefersTabsWhenMajorityTabLed() {
        let feature = MonaIndentationFeature()
        let text = "\ta\n\t\tb\n\tc\nd\n"
        let detection = feature.detectIndentation(
            text,
            defaultInsertSpaces: true,
            defaultTabSize: 4
        )
        XCTAssertFalse(detection.insertSpaces)
        XCTAssertEqual(detection.tabSize, 4)
    }

    func testDetectIndentationFallsBackToDefaultsWhenNoIndentation() {
        let feature = MonaIndentationFeature()
        let text = "a\nb\nc\n"
        let detection = feature.detectIndentation(
            text,
            defaultInsertSpaces: true,
            defaultTabSize: 2
        )
        XCTAssertTrue(detection.insertSpaces)
        XCTAssertEqual(detection.tabSize, 2)
    }

    func testConvertToSpacesExpandsTabsToTabStops() {
        let feature = MonaIndentationFeature()
        // tab at column 0 → 4 spaces; tab at column 4 → 4 spaces.
        let converted = feature.convertToSpaces("\thello", tabSize: 4)
        XCTAssertEqual(converted, "    hello")
        // Mid-line tab advances to the next tab stop, not a flat 4.
        let mid = feature.convertToSpaces("a\tb", tabSize: 4)
        XCTAssertEqual(mid, "a   b")
    }

    func testConvertToTabsCollapsesLeadingSpacesToTabs() {
        let feature = MonaIndentationFeature()
        // 8 leading spaces with tabSize 4 → 2 tabs; remainder stays as spaces.
        let converted = feature.convertToTabs("        hello", tabSize: 4)
        XCTAssertEqual(converted, "\t\thello")
        // 6 leading spaces with tabSize 4 → 1 tab + 2 spaces.
        let mixed = feature.convertToTabs("      hello", tabSize: 4)
        XCTAssertEqual(mixed, "\t  hello")
    }

    func testNormalizeWhitespaceSpacesModeEmitsSpaces() {
        let feature = MonaIndentationFeature()
        let options = MonaModelOptions(tabSize: 4, indentSize: 4, insertSpaces: true)
        // One tab = 4 visual columns → 4 spaces.
        let normalized = feature.normalizeWhitespace("\t", options: options)
        XCTAssertEqual(normalized, "    ")
    }

    func testNormalizeWhitespaceTabsModeEmitsTabsPlusRemainderSpaces() {
        let feature = MonaIndentationFeature()
        let options = MonaModelOptions(tabSize: 4, indentSize: 4, insertSpaces: false)
        // 6 columns → 1 tab + 2 spaces.
        let normalized = feature.normalizeWhitespace("\t  ", options: options)
        XCTAssertEqual(normalized, "\t  ")
    }

    func testReindentLinesNormalizesLeadingWhitespacePerOptions() {
        let feature = MonaIndentationFeature()
        let options = MonaModelOptions(tabSize: 4, indentSize: 4, insertSpaces: true)
        // A tab-led line reindented to spaces under insertSpaces=true.
        let text = "\thello\nworld\n"
        let reindented = feature.reindentLines(text, options: options)
        XCTAssertEqual(reindented, "    hello\nworld\n")
    }

    func testReindentLinesConvertsSpacesToTabsUnderTabsMode() {
        let feature = MonaIndentationFeature()
        let options = MonaModelOptions(tabSize: 4, indentSize: 4, insertSpaces: false)
        let text = "        hello\nworld\n"
        let reindented = feature.reindentLines(text, options: options)
        XCTAssertEqual(reindented, "\t\thello\nworld\n")
    }

    func testReadIndentationOptionsReadsFromMonaOptionStore() {
        let feature = MonaIndentationFeature()
        let store = MonaOptionStore()
        let editor = feature.readIndentationOptions(from: store)
        // Defaults: autoIndent = "full", autoIndentOnPaste = false,
        // autoIndentOnPasteWithinString = true.
        XCTAssertEqual(editor.autoIndent, "full")
        XCTAssertEqual(editor.autoIndentOnPaste, false)
        XCTAssertEqual(editor.autoIndentOnPasteWithinString, true)
    }

    func testReindentIsNoOpAfterDispose() {
        let feature = MonaIndentationFeature()
        feature.dispose()
        let options = MonaModelOptions(tabSize: 4, indentSize: 4, insertSpaces: true)
        let reindented = feature.reindentLines("\thello", options: options)
        XCTAssertEqual(reindented, "\thello")
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()

        XCTAssertTrue(features.contains(MonaIndentationFeature.featureId))
        XCTAssertEqual(MonaIndentationFeature.featureId, "indentation")

        XCTAssertEqual(MonaIndentationFeature.declaredActionIds.count, 9)
        for id in MonaIndentationFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
        }

        XCTAssertEqual(MonaIndentationFeature.declaredCommandIds.count, 9)
        for id in MonaIndentationFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(
            MonaIndentationFeature.declaredContributionIds,
            ["editor.contrib.autoIndentOnPaste"]
        )
        for id in MonaIndentationFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(
            MonaIndentationFeature.declaredOptionIds,
            ["autoIndent", "autoIndentOnPaste", "autoIndentOnPasteWithinString"]
        )
        XCTAssertTrue(MonaIndentationFeature.declaredMenuIds.isEmpty)

        let kbCommands = MonaIndentationFeature.declaredKeybindingCommands
        XCTAssertEqual(kbCommands.count, 2)
        let rowCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in kbCommands {
            XCTAssertTrue(rowCommands.contains(id), "missing keybinding for \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGateway() {
        let model = MonaCodeModel(
            text: "\thello\nworld\n",
            uri: MonaURI(scheme: "inmemory", path: "/indent")
        )
        let gateway = MonaTransactionGateway(model: model)
        let feature = MonaIndentationFeature()
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 1, column: 6)
        )
        let outcome = feature.commitReindent(
            gateway: gateway,
            range: range,
            newText: "    hello"
        )
        XCTAssertEqual(outcome, .applied)
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = MonaCodeModel(
            text: "a\nb",
            uri: MonaURI(scheme: "inmemory", path: "/indent-async")
        )
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaIndentationFeature()
        let detection = MonaIndentationDetection(insertSpaces: true, tabSize: 4)
        let ticket = gate.captureTicket()

        var received: [MonaIndentationDetection] = []
        let accepted = feature.publishIndentationDetection(
            detection,
            executor: executor,
            ticket: ticket
        ) { delivered in received = [delivered] }
        XCTAssertTrue(accepted)
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[0], detection)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaIndentationFeature()
        var fired: [MonaIndentationEvent] = []
        _ = feature.onChange { fired.append($0) }
        let detection = MonaIndentationDetection(insertSpaces: true, tabSize: 4)
        feature.stageDetection(detection)
        XCTAssertEqual(fired.count, 1)
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.stageDetection(detection)
        XCTAssertEqual(fired.count, 1)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaIndentationFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaIndentationFeature.declaredActionIds.count)
        // The first declared action is "Indent Line".
        XCTAssertEqual(enLabels[0], "Indent Line")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaIndentationFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        XCTAssertEqual(feature.degradedLanguage.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(feature.degradedLanguage.hasTokenization)
    }

    // MARK: - Contract leaf

    func testIndentationContractLeaf() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let feature = MonaIndentationFeature()

        let featureLive = features.contains(MonaIndentationFeature.featureId)
        let actionCount = MonaIndentationFeature.declaredActionIds.count
        let commandCount = MonaIndentationFeature.declaredCommandIds.count
        let contribCount = MonaIndentationFeature.declaredContributionIds.count
        let kbCount = MonaIndentationFeature.declaredKeybindingCommands.count
        let optionCount = MonaIndentationFeature.declaredOptionIds.count
        let menuCount = MonaIndentationFeature.declaredMenuIds.count

        let slicePass = MonaIndentationFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaIndentationFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaIndentationFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
        let kbPass = MonaIndentationFeature.declaredKeybindingCommands.allSatisfy {
            Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
        }

        // Detect: space-led majority → insertSpaces=true, tabSize=4.
        let detection = feature.detectIndentation(
            "    a\n        b\n    c\n",
            defaultInsertSpaces: false,
            defaultTabSize: 4
        )
        let detectPass = detection.insertSpaces && detection.tabSize == 4

        // Convert: tabs → spaces.
        let converted = feature.convertToSpaces("\thello", tabSize: 4)
        let convertPass = converted == "    hello"

        // Reindent: tab-led line reindented to spaces under insertSpaces=true.
        let options = MonaModelOptions(tabSize: 4, indentSize: 4, insertSpaces: true)
        let reindented = feature.reindentLines("\thello\nworld\n", options: options)
        let reindentPass = reindented == "    hello\nworld\n"

        // Option store: read editor-level indentation options.
        let store = MonaOptionStore()
        let editor = feature.readIndentationOptions(from: store)
        let optionStorePass = editor.autoIndent == "full" && editor.autoIndentOnPaste == false

        // Mutation: commit a reindent edit through the transaction gateway.
        let model = MonaCodeModel(
            text: "\thello\nworld\n",
            uri: MonaURI(scheme: "inmemory", path: "/leaf")
        )
        let gateway = MonaTransactionGateway(model: model)
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 1, column: 6)
        )
        let mutation = feature.commitReindent(gateway: gateway, range: range, newText: "    hello") == .applied

        // Async: publish a detection through the provider executor.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishIndentationDetection(detection, executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed
        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("INDENTATION feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(kbPass)
        XCTAssertTrue(detectPass)
        XCTAssertTrue(convertPass)
        XCTAssertTrue(reindentPass)
        XCTAssertTrue(optionStorePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
