// MonaSectionHeadersFeatureTests.swift
//
// P05-T148 — Implement retained feature sectionHeaders.
//
// Verifies the sectionHeaders feature across its three implementation operations:
//   1. Feature-specific behavior: derive and render section-header decorations
//      from configured patterns (native AppKit decoration rendering). The
//      configured patterns live inside the `minimap` editor option
//      (`markSectionHeaderRegex`, `showMarkSectionHeaders`,
//      `showRegionSectionHeaders`, `sectionHeaderFontSize`,
//      `sectionHeaderLetterSpacing`); region section headers are detected from
//      `#region` markers.
//   2. The exact feature identity `sectionHeaders` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     SECTIONHEADERS feature=live actions=0 commands=0 contributions=1 keybindings=0 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import Foundation
import MonaCode
@testable import MonaCodeAppKit

final class MonaSectionHeadersFeatureTests: XCTestCase {

    private func makeModel(_ text: String) -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/sectionheaders-\(UUID().uuidString)")
        )
    }

    /// A minimap option carrying the default section-header configuration.
    private func minimapStore(
        markRegex: String = "\\bMARK:\\s*(?<separator>-?)\\s*(?<label>.*)$",
        showMark: Bool = true,
        showRegion: Bool = true,
        fontSize: Int = 9,
        letterSpacing: Int = 1
    ) -> MonaOptionStore {
        let store = MonaOptionStore()
        _ = store.setValue(.object([
            "markSectionHeaderRegex": .string(markRegex),
            "showMarkSectionHeaders": .bool(showMark),
            "showRegionSectionHeaders": .bool(showRegion),
            "sectionHeaderFontSize": .int(fontSize),
            "sectionHeaderLetterSpacing": .int(letterSpacing)
        ]), for: "minimap")
        return store
    }

    // MARK: - 1. Feature-specific behavior: derive + render section-header decorations

    func testPatternReadsConfiguredMinimapSubFields() {
        let feature = MonaSectionHeadersFeature()
        let store = minimapStore(markRegex: "^MARK:", showMark: true, showRegion: false, fontSize: 11, letterSpacing: 2)
        let pattern = feature.pattern(for: store)

        XCTAssertEqual(pattern.markSectionHeaderRegex, "^MARK:")
        XCTAssertEqual(pattern.showMarkSectionHeaders, true)
        XCTAssertEqual(pattern.showRegionSectionHeaders, false)
        XCTAssertEqual(pattern.sectionHeaderFontSize, 11)
        XCTAssertEqual(pattern.sectionHeaderLetterSpacing, 2)
    }

    func testPatternFallsBackToDefaultsWhenMinimapAbsent() {
        let feature = MonaSectionHeadersFeature()
        let store = MonaOptionStore() // no minimap option set
        let pattern = feature.pattern(for: store)

        // Defaults mirror the minimap option's default value.
        XCTAssertEqual(pattern.markSectionHeaderRegex, "\\bMARK:\\s*(?<separator>-?)\\s*(?<label>.*)$")
        XCTAssertEqual(pattern.showMarkSectionHeaders, true)
        XCTAssertEqual(pattern.showRegionSectionHeaders, true)
        XCTAssertEqual(pattern.sectionHeaderFontSize, 9)
        XCTAssertEqual(pattern.sectionHeaderLetterSpacing, 1)
    }

    func testDeriveSectionHeadersDetectsMarkHeaders() {
        let feature = MonaSectionHeadersFeature()
        let model = makeModel("// MARK: - First\nlet x = 1\n// MARK: Second\nlet y = 2\n")
        let headers = feature.deriveSectionHeaders(in: model, options: minimapStore())

        XCTAssertEqual(headers.count, 2)
        XCTAssertEqual(headers[0].lineNumber, 1)
        XCTAssertEqual(headers[0].label, "First")
        XCTAssertEqual(headers[0].kind, .mark)
        XCTAssertEqual(headers[1].lineNumber, 3)
        XCTAssertEqual(headers[1].label, "Second")
        XCTAssertEqual(headers[1].kind, .mark)
    }

    func testDeriveSectionHeadersDetectsRegionHeaders() {
        let feature = MonaSectionHeadersFeature()
        let model = makeModel("#region First Section\nlet x = 1\n#endregion\n")
        let headers = feature.deriveSectionHeaders(in: model, options: minimapStore())

        XCTAssertEqual(headers.count, 1)
        XCTAssertEqual(headers[0].lineNumber, 1)
        XCTAssertEqual(headers[0].label, "First Section")
        XCTAssertEqual(headers[0].kind, .region)
    }

    func testDeriveSectionHeadersRespectsShowFlags() {
        let feature = MonaSectionHeadersFeature()
        let model = makeModel("// MARK: - A\n#region B\n")

        // Disable both — no headers derived.
        let hidden = minimapStore(showMark: false, showRegion: false)
        XCTAssertTrue(feature.deriveSectionHeaders(in: model, options: hidden).isEmpty)

        // Mark only — only MARK headers.
        let markOnly = minimapStore(showMark: true, showRegion: false)
        let markHeaders = feature.deriveSectionHeaders(in: model, options: markOnly)
        XCTAssertEqual(markHeaders.count, 1)
        XCTAssertEqual(markHeaders.first?.kind, .mark)

        // Region only — only region headers.
        let regionOnly = minimapStore(showMark: false, showRegion: true)
        let regionHeaders = feature.deriveSectionHeaders(in: model, options: regionOnly)
        XCTAssertEqual(regionHeaders.count, 1)
        XCTAssertEqual(regionHeaders.first?.kind, .region)
    }

    func testDeriveSectionHeadersIsNoOpAfterDispose() {
        let feature = MonaSectionHeadersFeature()
        feature.dispose()
        let model = makeModel("// MARK: - A\n")
        XCTAssertTrue(feature.deriveSectionHeaders(in: model, options: minimapStore()).isEmpty)
    }

    func testPresentationRendersNativeAppKitAttributedString() {
        let feature = MonaSectionHeadersFeature()
        let model = makeModel("// MARK: - Hello\nlet x = 1\n")
        let presentation = feature.presentation(
            for: model,
            options: minimapStore(fontSize: 10, letterSpacing: 2),
            profile: .default
        )

        XCTAssertTrue(presentation.visible)
        XCTAssertEqual(presentation.headers.count, 1)
        XCTAssertEqual(presentation.headers.first?.label, "Hello")
        XCTAssertFalse(presentation.attributedString.string.isEmpty)
        // The attributed string carries the font size + kern (letter spacing).
        let font = presentation.attributedString.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertNotNil(font)
        XCTAssertEqual(font?.pointSize, 10)
        let kern = presentation.attributedString.attribute(.kern, at: 0, effectiveRange: nil) as? NSNumber
        XCTAssertNotNil(kern)
        XCTAssertEqual(kern?.intValue, 2)
    }

    func testPresentationHiddenAfterDispose() {
        let feature = MonaSectionHeadersFeature()
        feature.dispose()
        let model = makeModel("// MARK: - Hello\n")
        let presentation = feature.presentation(for: model, options: minimapStore(), profile: .default)
        XCTAssertFalse(presentation.visible)
        XCTAssertTrue(presentation.headers.isEmpty)
    }

    func testPresentFiresEventWhenHeadersVisible() {
        let feature = MonaSectionHeadersFeature()
        let model = makeModel("// MARK: - A\n")
        var fired: [MonaSectionHeaderEvent] = []
        _ = feature.onChange { event in fired.append(event) }

        let presented = feature.present(using: model, options: minimapStore(), profile: .default)
        XCTAssertTrue(presented)
        XCTAssertEqual(fired.count, 1)
        XCTAssertTrue(fired[0].presentation.visible)
    }

    func testPresentIsNoOpWhenNoHeaders() {
        let feature = MonaSectionHeadersFeature()
        let model = makeModel("let x = 1\n") // no MARK / region
        var fired: [MonaSectionHeaderEvent] = []
        _ = feature.onChange { event in fired.append(event) }

        let presented = feature.present(using: model, options: minimapStore(), profile: .default)
        XCTAssertFalse(presented)
        XCTAssertTrue(fired.isEmpty)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaSectionHeadersFeature.featureId, "sectionHeaders")
        XCTAssertTrue(features.contains("sectionHeaders"))

        XCTAssertEqual(MonaSectionHeadersFeature.declaredActionIds, [])
        for id in MonaSectionHeadersFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaSectionHeadersFeature.declaredCommandIds, [])
        for id in MonaSectionHeadersFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaSectionHeadersFeature.declaredContributionIds, [
            "editor.sectionHeaderDetector"
        ])
        for id in MonaSectionHeadersFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaSectionHeadersFeature.declaredKeybindingCommands, [])
        let kbCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in MonaSectionHeadersFeature.declaredKeybindingCommands {
            XCTAssertTrue(kbCommands.contains(id), "missing keybinding \(id)")
        }

        XCTAssertEqual(MonaSectionHeadersFeature.declaredOptionIds, [])
        for id in MonaSectionHeadersFeature.declaredOptionIds {
            XCTAssertNotNil(options.value(for: id), "missing option \(id)")
        }

        XCTAssertEqual(MonaSectionHeadersFeature.declaredMenuIds, [])
        for id in MonaSectionHeadersFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRevealsSectionHeaderThroughTransactionGateway() {
        let feature = MonaSectionHeadersFeature()
        let model = makeModel("// MARK: - First\nlet x = 1\n")
        let gateway = MonaTransactionGateway(model: model)
        let headers = feature.deriveSectionHeaders(in: model, options: minimapStore())
        XCTAssertEqual(headers.count, 1)

        let outcome = feature.commitRevealSectionHeader(headers[0], gateway: gateway)
        if case .applied = outcome {
            // expected: the section header line is revealed via a collapsed selection.
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
        // The committed selection anchors at the header's first column.
        let selections = gateway.lastCommittedSelections
        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(selections.first?.anchor, MonaPosition(line: headers[0].lineNumber, column: 1))
    }

    func testMutationIsNoOpAfterDispose() {
        let feature = MonaSectionHeadersFeature()
        feature.dispose()
        let model = makeModel("// MARK: - A\n")
        let gateway = MonaTransactionGateway(model: model)
        let header = MonaSectionHeader(lineNumber: 1, label: "A", kind: .mark, range: MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 1, column: 15)
        ))
        let outcome = feature.commitRevealSectionHeader(header, gateway: gateway)
        if case .dropped = outcome {
            // expected
        } else {
            XCTFail("expected dropped, got \(outcome)")
        }
        XCTAssertTrue(gateway.lastCommittedSelections.isEmpty)
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("// MARK: - A\n")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaSectionHeadersFeature()
        let ticket = gate.captureTicket()

        let headers = feature.deriveSectionHeaders(in: model, options: minimapStore())
        var received: [MonaSectionHeader]?
        let accepted = feature.publishSectionHeaders(
            headers,
            executor: executor,
            ticket: ticket
        ) { delivered in
            received = delivered
        }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertNotNil(received)
        XCTAssertEqual(received?.count, headers.count)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaSectionHeadersFeature()
        var fired: [MonaSectionHeaderEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        let model = makeModel("// MARK: - A\n")
        _ = feature.present(using: model, options: minimapStore(), profile: .default)
        XCTAssertFalse(fired.isEmpty)

        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, present is a no-op and fires no events.
        let countBefore = fired.count
        _ = feature.present(using: model, options: minimapStore(), profile: .default)
        XCTAssertEqual(fired.count, countBefore)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaSectionHeadersFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaSectionHeadersFeature.declaredActionIds.count)
        XCTAssertTrue(enLabels.isEmpty)

        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels.isEmpty)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaSectionHeadersFeature()
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
        let options = MonaOptionStore()
        let menus = MonaMenuRegistry()
        let feature = MonaSectionHeadersFeature()

        let featureLive = features.contains(MonaSectionHeadersFeature.featureId)
        let actionCount = MonaSectionHeadersFeature.declaredActionIds.count
        let commandCount = MonaSectionHeadersFeature.declaredCommandIds.count
        let contribCount = MonaSectionHeadersFeature.declaredContributionIds.count
        let kbCount = MonaSectionHeadersFeature.declaredKeybindingCommands.count
        let optionCount = MonaSectionHeadersFeature.declaredOptionIds.count
        let menuCount = MonaSectionHeadersFeature.declaredMenuIds.count

        let slicePass = MonaSectionHeadersFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaSectionHeadersFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaSectionHeadersFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaSectionHeadersFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaSectionHeadersFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
            && MonaSectionHeadersFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Derive + render.
        let model = makeModel("// MARK: - First\nlet x = 1\n#region Region Two\nlet y = 2\n#endregion\n")
        let store = minimapStore()
        let headers = feature.deriveSectionHeaders(in: model, options: store)
        let derivePass = headers.count == 2 && headers[0].kind == .mark && headers[1].kind == .region
        let presentation = feature.presentation(for: model, options: store, profile: .default)
        let renderPass = presentation.visible && presentation.headers.count == 2
            && !presentation.attributedString.string.isEmpty

        // Mutation: reveal a section header line through the gateway.
        var mutation = false
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.commitRevealSectionHeader(headers[0], gateway: gateway)
        if case .applied = outcome, gateway.lastCommittedSelections.count == 1 {
            mutation = true
        }

        // Async publication through the provider executor + microtask queue.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishSectionHeaders(
            headers,
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        _ = feature.present(using: model, options: store, profile: .default)
        let presentPass = !feature.currentPresentation.headers.isEmpty

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("SECTIONHEADERS feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(derivePass)
        XCTAssertTrue(renderPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(presentPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
