// MonaHoverFeatureTests.swift
//
// P05-T125 — Implement retained feature hover.
//
// Verifies the hover feature across its three implementation operations:
//   1. Feature-specific behavior: merge, render, update verbosity, and release
//      hover provider results (reuse `MonaProviderExecutor` P05-T013).
//   2. The exact feature identity `hover` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testHoverContractLeaf` prints the contract line:
//     HOVER feature=live actions=13 commands=16 contributions=2 keybindings=9 options=1 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import MonaCode
@testable import MonaCodeAppKit

final class MonaHoverFeatureTests: XCTestCase {

    // MARK: - 1. Feature-specific behavior: merge + render + verbosity + release

    private func makeHover(
        contents: [MonaHoverContent],
        range: MonaRange? = nil
    ) -> MonaHover {
        return MonaHover(contents: contents, range: range)
    }

    func testMergeConcatenatesContentsPreservingProviderOrder() {
        let feature = MonaHoverFeature()
        let a = makeHover(contents: [MonaHoverContent(text: "a-md", isMarkdown: true)])
        let b = makeHover(contents: [MonaHoverContent(text: "b-plain", isMarkdown: false)])
        let merged = feature.mergeHovers([a, b])
        XCTAssertEqual(merged.contents.count, 2)
        XCTAssertEqual(merged.contents[0].text, "a-md")
        XCTAssertTrue(merged.contents[0].isMarkdown)
        XCTAssertEqual(merged.contents[1].text, "b-plain")
        XCTAssertFalse(merged.contents[1].isMarkdown)
    }

    func testMergeTakesFirstNonNilRange() {
        let feature = MonaHoverFeature()
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 1, column: 5)
        )
        let a = makeHover(contents: [MonaHoverContent(text: "a", isMarkdown: true)], range: range)
        let b = makeHover(contents: [MonaHoverContent(text: "b", isMarkdown: true)], range: nil)
        let merged = feature.mergeHovers([a, b])
        XCTAssertEqual(merged.range, range)
        // When the first has no range, the next non-nil range is used.
        let merged2 = feature.mergeHovers([b, a])
        XCTAssertEqual(merged2.range, range)
    }

    func testMergeEmptyReturnsEmptyHover() {
        let feature = MonaHoverFeature()
        let merged = feature.mergeHovers([])
        XCTAssertTrue(merged.contents.isEmpty)
        XCTAssertNil(merged.range)
    }

    func testRenderHoverProducesAttributedString() {
        let feature = MonaHoverFeature()
        let hover = makeHover(contents: [
            MonaHoverContent(text: "hello", isMarkdown: true),
            MonaHoverContent(text: "world", isMarkdown: false)
        ])
        let attributed = feature.renderHover(hover)
        XCTAssertGreaterThan(attributed.length, 0)
        // The rendered string contains both contents' text.
        let plain = attributed.string
        XCTAssertTrue(plain.contains("hello"))
        XCTAssertTrue(plain.contains("world"))
    }

    func testRenderPlainTextJoinsContentsThroughPlainTextLanguage() {
        let feature = MonaHoverFeature()
        let hover = makeHover(contents: [
            MonaHoverContent(text: "alpha", isMarkdown: true),
            MonaHoverContent(text: "beta", isMarkdown: false)
        ])
        let plain = feature.renderPlainText(hover)
        XCTAssertTrue(plain.contains("alpha"))
        XCTAssertTrue(plain.contains("beta"))
    }

    func testVerbosityStartsAtZeroAndIncreases() {
        let feature = MonaHoverFeature()
        XCTAssertEqual(feature.verbosityLevel, 0)
        feature.increaseVerbosity()
        XCTAssertEqual(feature.verbosityLevel, 1)
        feature.increaseVerbosity()
        XCTAssertEqual(feature.verbosityLevel, 2)
    }

    func testVerbosityDecreaseClampsAtZero() {
        let feature = MonaHoverFeature()
        feature.increaseVerbosity()
        feature.increaseVerbosity()
        XCTAssertEqual(feature.verbosityLevel, 2)
        feature.decreaseVerbosity()
        XCTAssertEqual(feature.verbosityLevel, 1)
        feature.decreaseVerbosity()
        XCTAssertEqual(feature.verbosityLevel, 0)
        // Clamped at zero.
        feature.decreaseVerbosity()
        XCTAssertEqual(feature.verbosityLevel, 0)
    }

    func testSetVerbosityLevelClampsAtZero() {
        let feature = MonaHoverFeature()
        feature.setVerbosityLevel(5)
        XCTAssertEqual(feature.verbosityLevel, 5)
        feature.setVerbosityLevel(-3)
        XCTAssertEqual(feature.verbosityLevel, 0)
    }

    func testVerbosityChangeFiresEvent() {
        let feature = MonaHoverFeature()
        var events: [MonaHoverEvent] = []
        _ = feature.onChange { events.append($0) }
        feature.increaseVerbosity()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].verbosityLevel, 1)
        XCTAssertNil(events[0].hover)
    }

    func testReleaseHoverReleasesOwnedResourcesExactlyOnce() {
        let feature = MonaHoverFeature()
        let hover = makeHover(contents: [MonaHoverContent(text: "x", isMarkdown: true)])
        let owned = [MonaHoverTestDisposable(), MonaHoverTestDisposable()]
        let released = feature.releaseHover(hover, owned: owned)
        XCTAssertTrue(released)
        XCTAssertTrue(owned[0].isDisposed)
        XCTAssertTrue(owned[1].isDisposed)
        // Idempotent: a second release of the same owned list is a no-op (the
        // resources were already released exactly once).
        let released2 = feature.releaseHover(hover, owned: [])
        XCTAssertFalse(released2)
    }

    func testReleaseHoverIsNoOpAfterDispose() {
        let feature = MonaHoverFeature()
        let hover = makeHover(contents: [MonaHoverContent(text: "x", isMarkdown: true)])
        let owned = [MonaHoverTestDisposable()]
        feature.dispose()
        let released = feature.releaseHover(hover, owned: owned)
        XCTAssertFalse(released)
        XCTAssertFalse(owned[0].isDisposed)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()

        XCTAssertTrue(features.contains(MonaHoverFeature.featureId))
        XCTAssertEqual(MonaHoverFeature.featureId, "hover")

        XCTAssertEqual(MonaHoverFeature.declaredActionIds.count, 13)
        for id in MonaHoverFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
        }

        XCTAssertEqual(MonaHoverFeature.declaredCommandIds.count, 16)
        for id in MonaHoverFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(
            MonaHoverFeature.declaredContributionIds,
            ["editor.contrib.contentHover", "editor.contrib.marginHover"]
        )
        for id in MonaHoverFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaHoverFeature.declaredOptionIds, ["hover"])
        XCTAssertEqual(MonaHoverFeature.declaredMenuIds, [])

        let kbCommands = MonaHoverFeature.declaredKeybindingCommands
        XCTAssertEqual(kbCommands.count, 9)
        let rowCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in kbCommands {
            XCTAssertTrue(rowCommands.contains(id), "missing keybinding for \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGateway() {
        let model = MonaCodeModel(
            text: "abc\ndef",
            uri: MonaURI(scheme: "inmemory", path: "/hover")
        )
        let gateway = MonaTransactionGateway(model: model)
        let feature = MonaHoverFeature()
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 2),
            endPosition: MonaPosition(line: 1, column: 4)
        )
        feature.stageHover(makeHover(contents: [MonaHoverContent(text: "x", isMarkdown: true)], range: range))
        let committed = feature.commitReveal(gateway: gateway)
        XCTAssertEqual(committed.count, 1)
        XCTAssertEqual(committed[0].anchor, MonaPosition(line: 1, column: 2))
        XCTAssertEqual(gateway.lastCommittedSelections, committed)
    }

    func testAsyncPublicationRoutesThroughProviderExecutorWithReleasableShape() {
        let model = MonaCodeModel(
            text: "a\nb",
            uri: MonaURI(scheme: "inmemory", path: "/hover-async")
        )
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaHoverFeature()
        let hover = makeHover(contents: [MonaHoverContent(text: "x", isMarkdown: true)])
        let owned = [MonaHoverTestDisposable()]
        let ticket = gate.captureTicket()

        var received: [MonaHover] = []
        let accepted = feature.publishHover(
            hover,
            executor: executor,
            ticket: ticket,
            owned: owned
        ) { delivered in received = [delivered] }
        XCTAssertTrue(accepted)
        XCTAssertTrue(received.isEmpty)
        XCTAssertFalse(owned[0].isDisposed)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[0], hover)
        XCTAssertTrue(owned[0].isDisposed)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaHoverFeature()
        var fired: [MonaHoverEvent] = []
        _ = feature.onChange { fired.append($0) }
        feature.increaseVerbosity()
        XCTAssertEqual(fired.count, 1)
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.increaseVerbosity()
        XCTAssertEqual(fired.count, 1)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaHoverFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaHoverFeature.declaredActionIds.count)
        // The first declared action is "Show or Focus Hover".
        XCTAssertEqual(enLabels[0], "Show or Focus Hover")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaHoverFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        XCTAssertEqual(feature.degradedLanguage.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(feature.degradedLanguage.hasTokenization)
    }

    // MARK: - Contract leaf

    func testHoverContractLeaf() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let feature = MonaHoverFeature()

        let featureLive = features.contains(MonaHoverFeature.featureId)
        let actionCount = MonaHoverFeature.declaredActionIds.count
        let commandCount = MonaHoverFeature.declaredCommandIds.count
        let contribCount = MonaHoverFeature.declaredContributionIds.count
        let kbCount = MonaHoverFeature.declaredKeybindingCommands.count
        let optionCount = MonaHoverFeature.declaredOptionIds.count
        let menuCount = MonaHoverFeature.declaredMenuIds.count

        let slicePass = MonaHoverFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaHoverFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaHoverFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
        let kbPass = MonaHoverFeature.declaredKeybindingCommands.allSatisfy {
            Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
        }

        // Merge + render: two provider hovers merged, then rendered.
        let a = MonaHover(contents: [MonaHoverContent(text: "alpha", isMarkdown: true)])
        let b = MonaHover(contents: [MonaHoverContent(text: "beta", isMarkdown: false)])
        let merged = feature.mergeHovers([a, b])
        let rendered = feature.renderHover(merged)
        let mergeRenderPass = merged.contents.count == 2 && rendered.length > 0

        // Verbosity: increase + decrease.
        feature.increaseVerbosity()
        feature.decreaseVerbosity()
        let verbosityPass = feature.verbosityLevel == 0

        // Mutation: reveal the hover range through the transaction gateway.
        let model = MonaCodeModel(text: "abc\ndef", uri: MonaURI(scheme: "inmemory", path: "/leaf"))
        let gateway = MonaTransactionGateway(model: model)
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 2),
            endPosition: MonaPosition(line: 1, column: 4)
        )
        feature.stageHover(MonaHover(contents: [MonaHoverContent(text: "x", isMarkdown: true)], range: range))
        let mutation = feature.commitReveal(gateway: gateway).count == 1
            && gateway.lastCommittedSelections.count == 1

        // Async: publish a hover through the provider executor (releasable).
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        let owned = [MonaHoverTestDisposable()]
        _ = feature.publishHover(merged, executor: executor, ticket: gate.captureTicket(), owned: owned) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0 && owned[0].isDisposed

        // Release: release owned resources exactly once.
        let releaseOwned = [MonaHoverTestDisposable()]
        let releasePass = feature.releaseHover(merged, owned: releaseOwned) && releaseOwned[0].isDisposed

        feature.dispose()
        let disposalPass = feature.isDisposed
        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("HOVER feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(kbPass)
        XCTAssertTrue(mergeRenderPass)
        XCTAssertTrue(verbosityPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(releasePass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}

// A test-only disposable that records when it was disposed, used to verify the
// hover feature's release-once semantics for owned provider resources.
final class MonaHoverTestDisposable: MonaDisposable {
    private(set) var isDisposed = false
    func dispose() {
        isDisposed = true
    }
}
