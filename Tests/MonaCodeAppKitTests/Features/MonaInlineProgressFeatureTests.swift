// MonaInlineProgressFeatureTests.swift
//
// P05-T129 — Implement retained feature inlineProgress.
//
// Verifies the inlineProgress feature across its three implementation
// operations:
//   1. Feature-specific behavior: render retained inline progress feedback
//      WITHOUT notification-center UI (native AppKit inline progress — no
//      `NSUserNotificationCenter` / `UNUserNotificationCenter`).
//   2. The exact feature identity `inlineProgress` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testInlineProgressContractLeaf` prints the contract line:
//     INLINEPROGRESS feature=live actions=0 commands=0 contributions=0 keybindings=0 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import MonaCode
@testable import MonaCodeAppKit

final class MonaInlineProgressFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "line one\nline two") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/inlineprogress-\(UUID().uuidString)")
        )
    }

    private func sampleProgress(indeterminate: Bool = false) -> MonaInlineProgress {
        return MonaInlineProgress(
            identifier: "indexing",
            message: "Indexing files",
            percent: indeterminate ? nil : 0.42,
            position: MonaPosition(line: 1, column: 1)
        )
    }

    // MARK: - 1. Feature-specific behavior: render retained inline progress (no notification-center UI)

    func testStageInlineProgressRetainsByModelVersion() {
        let feature = MonaInlineProgressFeature()
        let model = makeModel()
        let version = model.getVersionId()
        let progress = sampleProgress()

        let staged = feature.stageInlineProgress(progress, modelVersion: version)

        XCTAssertEqual(staged, progress)
        XCTAssertEqual(feature.stagedProgress, progress)
        XCTAssertEqual(feature.retainedProgressCount(for: version), 1)
    }

    func testStageInlineProgressForNewModelVersionIsIndependent() {
        let feature = MonaInlineProgressFeature()
        let model = makeModel()

        let v1 = model.getVersionId()
        _ = feature.stageInlineProgress(sampleProgress(), modelVersion: v1)
        // The model advances (a direct mutation bypassing the feature).
        model.setValue("line one\nline two\nline three")
        let v2 = model.getVersionId()

        XCTAssertNotEqual(v1, v2)
        XCTAssertEqual(feature.retainedProgressCount(for: v1), 1)
        XCTAssertEqual(feature.retainedProgressCount(for: v2), 0)
    }

    func testRenderInlineProgressProducesAttributedStringWithMessage() {
        let feature = MonaInlineProgressFeature()
        let progress = sampleProgress()
        let attributed = feature.renderInlineProgress(progress)
        XCTAssertGreaterThan(attributed.length, 0)
        let plain = attributed.string
        XCTAssertTrue(plain.contains("Indexing files"))
        // Determinate progress includes the percent.
        XCTAssertTrue(plain.contains("42"))
    }

    func testRenderInlineProgressIndeterminateShowsMessage() {
        let feature = MonaInlineProgressFeature()
        let progress = sampleProgress(indeterminate: true)
        let attributed = feature.renderInlineProgress(progress)
        XCTAssertGreaterThan(attributed.length, 0)
        XCTAssertTrue(attributed.string.contains("Indexing files"))
        // Indeterminate progress does NOT include a percent figure.
        XCTAssertFalse(attributed.string.contains("42"))
    }

    func testRenderInlineProgressDoesNotUseNotificationCenterUI() {
        // The native AppKit inline-progress render path produces an
        // NSAttributedString for inline display — it must NOT route through
        // NSUserNotificationCenter / UNUserNotificationCenter. The render
        // result is an NSAttributedString (inline feedback), not a posted
        // notification.
        let feature = MonaInlineProgressFeature()
        let progress = sampleProgress()
        let rendered = feature.renderInlineProgress(progress)
        XCTAssertTrue(rendered is NSAttributedString)
        // The feature exposes no notification-center delivery surface.
        XCTAssertNil(feature.notificationCenterBridge)
    }

    func testRenderPlainTextJoinsThroughPlainTextLanguage() {
        let feature = MonaInlineProgressFeature()
        let progress = sampleProgress()
        let plain = feature.renderPlainText(progress)
        XCTAssertTrue(plain.contains("Indexing files"))
        XCTAssertTrue(plain.contains("42"))
    }

    func testUpdateInlineProgressReplacesStagedProgress() {
        let feature = MonaInlineProgressFeature()
        let model = makeModel()
        let version = model.getVersionId()
        _ = feature.stageInlineProgress(sampleProgress(), modelVersion: version)

        let updated = MonaInlineProgress(
            identifier: "indexing",
            message: "Almost done",
            percent: 0.91,
            position: MonaPosition(line: 1, column: 1)
        )
        let result = feature.updateInlineProgress(updated, modelVersion: version)

        XCTAssertEqual(result, updated)
        XCTAssertEqual(feature.stagedProgress, updated)
        XCTAssertEqual(feature.retainedProgressCount(for: version), 1)
    }

    func testReleaseInlineProgressDropsResultsForStaleModelVersion() {
        let feature = MonaInlineProgressFeature()
        let model = makeModel()
        let v1 = model.getVersionId()
        _ = feature.stageInlineProgress(sampleProgress(), modelVersion: v1)
        XCTAssertEqual(feature.retainedProgressCount(for: v1), 1)

        let released = feature.releaseInlineProgress(modelVersion: v1)
        XCTAssertEqual(released, 1)
        XCTAssertEqual(feature.retainedProgressCount(for: v1), 0)
    }

    func testReleaseInlineProgressForUnknownVersionReleasesNothing() {
        let feature = MonaInlineProgressFeature()
        let model = makeModel()
        let v1 = model.getVersionId()
        _ = feature.stageInlineProgress(sampleProgress(), modelVersion: v1)
        let released = feature.releaseInlineProgress(modelVersion: v1 + 999)
        XCTAssertEqual(released, 0)
        XCTAssertEqual(feature.retainedProgressCount(for: v1), 1)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaInlineProgressFeature.featureId, "inlineProgress")
        XCTAssertTrue(features.contains("inlineProgress"))

        // inlineProgress declares no commands, actions, contributions, options,
        // menus, or keybindings — every declared slice is empty.
        XCTAssertEqual(MonaInlineProgressFeature.declaredActionIds, [])
        for id in MonaInlineProgressFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
        }

        XCTAssertEqual(MonaInlineProgressFeature.declaredCommandIds, [])
        for id in MonaInlineProgressFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaInlineProgressFeature.declaredContributionIds, [])
        for id in MonaInlineProgressFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaInlineProgressFeature.declaredKeybindingCommands, [])
        XCTAssertEqual(MonaInlineProgressFeature.declaredOptionIds, [])
        XCTAssertEqual(MonaInlineProgressFeature.declaredMenuIds, [])
        for id in MonaInlineProgressFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGateway() {
        let feature = MonaInlineProgressFeature()
        let model = makeModel("abc\ndef")
        let gateway = MonaTransactionGateway(model: model)
        let progress = MonaInlineProgress(
            identifier: "indexing",
            message: "Indexing",
            percent: nil,
            position: MonaPosition(line: 1, column: 2)
        )
        _ = feature.stageInlineProgress(progress, modelVersion: model.getVersionId())

        let committed = feature.commitReveal(gateway: gateway)
        XCTAssertEqual(committed.count, 1)
        XCTAssertEqual(committed[0].anchor, MonaPosition(line: 1, column: 2))
        XCTAssertEqual(gateway.lastCommittedSelections, committed)
    }

    func testMutationWithNoPositionCommitsNothing() {
        let feature = MonaInlineProgressFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let progress = MonaInlineProgress(
            identifier: "indexing",
            message: "Indexing",
            percent: nil,
            position: nil
        )
        _ = feature.stageInlineProgress(progress, modelVersion: model.getVersionId())

        let committed = feature.commitReveal(gateway: gateway)
        XCTAssertTrue(committed.isEmpty)
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaInlineProgressFeature()
        let ticket = gate.captureTicket()
        let progress = sampleProgress()

        var received: MonaInlineProgress?
        let accepted = feature.publishInlineProgress(
            progress,
            executor: executor,
            ticket: ticket
        ) { delivered in received = delivered }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received, progress)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaInlineProgressFeature()
        var fired: [MonaInlineProgressEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, stage / render / release are no-ops.
        let model = makeModel()
        let version = model.getVersionId()
        let staged = feature.stageInlineProgress(sampleProgress(), modelVersion: version)
        XCTAssertNil(staged)
        XCTAssertNil(feature.stagedProgress)
        XCTAssertEqual(feature.retainedProgressCount(for: version), 0)
        let rendered = feature.renderInlineProgress(sampleProgress())
        XCTAssertEqual(rendered.length, 0)
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaInlineProgressFeature()
        // inlineProgress declares no actions, so localized labels are empty
        // under every profile — but the path still routes through
        // MonaLocalization.
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaInlineProgressFeature.declaredActionIds.count)
        XCTAssertTrue(enLabels.isEmpty)
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels.isEmpty)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaInlineProgressFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        let language = feature.degradedLanguage
        XCTAssertEqual(language.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(language.hasTokenization)
        XCTAssertFalse(language.hasGrammar)
    }

    // MARK: - Contract leaf

    func testInlineProgressContractLeaf() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()
        let feature = MonaInlineProgressFeature()

        let featureLive = features.contains(MonaInlineProgressFeature.featureId)
        let actionCount = MonaInlineProgressFeature.declaredActionIds.count
        let commandCount = MonaInlineProgressFeature.declaredCommandIds.count
        let contribCount = MonaInlineProgressFeature.declaredContributionIds.count
        let kbCount = MonaInlineProgressFeature.declaredKeybindingCommands.count
        let optionCount = MonaInlineProgressFeature.declaredOptionIds.count
        let menuCount = MonaInlineProgressFeature.declaredMenuIds.count

        let slicePass = MonaInlineProgressFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaInlineProgressFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaInlineProgressFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaInlineProgressFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaInlineProgressFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Stage + render: stage a progress item, then render it to an
        // NSAttributedString (native AppKit inline feedback — no
        // notification-center UI).
        let model = makeModel("abc\ndef")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        let progress = sampleProgress()
        let staged = feature.stageInlineProgress(progress, modelVersion: version)
        let rendered = feature.renderInlineProgress(progress)
        let stageRenderPass = staged == progress && rendered.length > 0
            && (rendered is NSAttributedString)
            && feature.notificationCenterBridge == nil

        // Mutation: reveal the staged progress position through the gateway.
        let mutation = feature.commitReveal(gateway: gateway).count == 1
            && gateway.lastCommittedSelections.count == 1

        // Release the stale-model-version progress.
        let released = feature.releaseInlineProgress(modelVersion: version)
        let releasePass = (released == 1 && feature.retainedProgressCount(for: version) == 0)

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishInlineProgress(progress, executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("INLINEPROGRESS feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(stageRenderPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(releasePass)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
