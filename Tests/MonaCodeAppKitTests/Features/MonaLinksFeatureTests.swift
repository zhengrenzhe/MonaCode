// MonaLinksFeatureTests.swift
//
// P05-T136 — Implement retained feature links.
//
// Verifies the links feature across its three implementation operations:
//   1. Feature-specific behavior: request, resolve, underline, activate, and
//      release document links (reuse `MonaProviderExecutor` P05-T013; the
//      underline is the AX/rendering underline attribute).
//   2. The exact feature identity `links` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testLinksContractLeaf` prints the contract line:
//     LINKS feature=live actions=1 commands=2 contributions=1 keybindings=0 options=1 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import MonaCode
@testable import MonaCodeAppKit

final class MonaLinksFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "see https://example.com here") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/links-\(UUID().uuidString)")
        )
    }

    /// A link covering the URL on line 1, columns 5–27.
    private func sampleLink(url: String? = "https://example.com") -> MonaLink {
        return MonaLink(
            range: MonaRange(startLine: 1, startColumn: 5, endLine: 1, endColumn: 27),
            url: url,
            tooltip: "Open"
        )
    }

    /// A provider that synchronously returns `links`.
    private struct SynchronousLinkProvider: MonaLinkProvider {
        let links: [MonaLink]
        func provideLinks(model: MonaCodeModel, token: MonaCancellationToken) -> MonaProviderResult<[MonaLink]> {
            return .synchronous(links)
        }
    }

    // MARK: - 1. Feature-specific behavior: request / resolve / underline / activate / release

    func testRequestLinksRetainsByModelVersionAndPublishes() {
        let feature = MonaLinksFeature()
        let model = makeModel()
        let version = model.getVersionId()
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let provider = SynchronousLinkProvider(links: [sampleLink()])
        let ticket = gate.captureTicket()

        var received: [MonaLink]?
        let accepted = feature.requestLinks(
            provider: provider,
            model: model,
            executor: executor,
            ticket: ticket,
            token: .none,
            receive: { delivered in received = delivered }
        )
        XCTAssertTrue(accepted)
        XCTAssertNil(received) // not delivered until drain
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received?.count, 1)
        XCTAssertEqual(received?.first, sampleLink())
        XCTAssertEqual(feature.retainedLinksCount(for: version), 1)
        XCTAssertEqual(feature.stagedLinks?.count, 1)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testRequestLinksForNewModelVersionIsIndependent() {
        let feature = MonaLinksFeature()
        let model = makeModel()

        let v1 = model.getVersionId()
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        _ = feature.requestLinks(
            provider: SynchronousLinkProvider(links: [sampleLink()]),
            model: model,
            executor: executor,
            ticket: gate.captureTicket(),
            token: .none,
            receive: { _ in }
        )
        executor.drain()

        // The model advances (a direct mutation bypassing the feature).
        model.setValue("see https://example.com here\nand another line")
        let v2 = model.getVersionId()

        XCTAssertNotEqual(v1, v2)
        XCTAssertEqual(feature.retainedLinksCount(for: v1), 1)
        XCTAssertEqual(feature.retainedLinksCount(for: v2), 0)
    }

    func testResolveLinkReturnsLinkWithUrl() {
        let feature = MonaLinksFeature()
        let link = sampleLink()
        let resolved = feature.resolveLink(link, token: .none)
        XCTAssertEqual(resolved?.url, "https://example.com")
    }

    func testResolveLinkReturnsNilForLinkWithoutUrl() {
        let feature = MonaLinksFeature()
        let link = sampleLink(url: nil)
        let resolved = feature.resolveLink(link, token: .none)
        XCTAssertNil(resolved)
    }

    func testResolveLinkReturnsNilWhenCancelled() {
        let feature = MonaLinksFeature()
        let link = sampleLink()
        let resolved = feature.resolveLink(link, token: .cancelled)
        XCTAssertNil(resolved)
    }

    func testUnderlineLinkProducesAttributedStringWithUnderlineAttribute() {
        let feature = MonaLinksFeature()
        let link = sampleLink()
        let attributed = feature.underlineLink(link)
        XCTAssertGreaterThan(attributed.length, 0)
        // The AX/rendering underline attribute is present.
        let underline = attributed.attribute(.underlineStyle, at: 0, effectiveRange: nil)
        XCTAssertNotNil(underline)
        // The underline is rendered as a single-style underline (the rendering
        // underline attribute used by the links feature).
        if let style = underline as? Int {
            XCTAssertEqual(style, NSUnderlineStyle.single.rawValue)
        } else if let style = underline as? NSUnderlineStyle {
            XCTAssertEqual(style, .single)
        }
    }

    func testUnderlineLinkAppliesLinkColorAttribute() {
        let feature = MonaLinksFeature()
        let link = sampleLink()
        let attributed = feature.underlineLink(link)
        // The link color attribute is applied for rendering.
        let color = attributed.attribute(.foregroundColor, at: 0, effectiveRange: nil)
        XCTAssertNotNil(color)
    }

    func testActivateLinkCommitsSelectionCoveringLinkRange() {
        let feature = MonaLinksFeature()
        let model = makeModel()
        let gateway = MonaTransactionGateway(model: model)
        let link = sampleLink()

        let committed = feature.activateLink(link, gateway: gateway)
        XCTAssertEqual(committed.count, 1)
        XCTAssertEqual(committed[0].anchor, MonaPosition(line: 1, column: 5))
        XCTAssertEqual(committed[0].activePosition, MonaPosition(line: 1, column: 27))
        XCTAssertEqual(gateway.lastCommittedSelections, committed)
    }

    func testReleaseLinksDropsResultsForStaleModelVersion() {
        let feature = MonaLinksFeature()
        let model = makeModel()
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let v1 = model.getVersionId()
        _ = feature.requestLinks(
            provider: SynchronousLinkProvider(links: [sampleLink()]),
            model: model,
            executor: executor,
            ticket: gate.captureTicket(),
            token: .none,
            receive: { _ in }
        )
        executor.drain()
        XCTAssertEqual(feature.retainedLinksCount(for: v1), 1)

        let released = feature.releaseLinks(modelVersion: v1)
        XCTAssertEqual(released, 1)
        XCTAssertEqual(feature.retainedLinksCount(for: v1), 0)
    }

    func testReleaseLinksForUnknownVersionReleasesNothing() {
        let feature = MonaLinksFeature()
        let model = makeModel()
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let v1 = model.getVersionId()
        _ = feature.requestLinks(
            provider: SynchronousLinkProvider(links: [sampleLink()]),
            model: model,
            executor: executor,
            ticket: gate.captureTicket(),
            token: .none,
            receive: { _ in }
        )
        executor.drain()
        let released = feature.releaseLinks(modelVersion: v1 + 999)
        XCTAssertEqual(released, 0)
        XCTAssertEqual(feature.retainedLinksCount(for: v1), 1)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaLinksFeature.featureId, "links")
        XCTAssertTrue(features.contains("links"))

        XCTAssertEqual(MonaLinksFeature.declaredActionIds, ["editor.action.openLink"])
        for id in MonaLinksFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
        }

        XCTAssertEqual(
            MonaLinksFeature.declaredCommandIds,
            ["_executeLinkProvider", "editor.action.openLink"]
        )
        for id in MonaLinksFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaLinksFeature.declaredContributionIds, ["editor.linkDetector"])
        for id in MonaLinksFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaLinksFeature.declaredKeybindingCommands, [])
        XCTAssertEqual(MonaLinksFeature.declaredOptionIds, ["links"])
        XCTAssertEqual(MonaLinksFeature.declaredMenuIds, [])
        for id in MonaLinksFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel()
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaLinksFeature()
        let ticket = gate.captureTicket()
        let links = [sampleLink()]

        var received: [MonaLink]?
        let accepted = feature.publishLinks(
            links,
            executor: executor,
            ticket: ticket
        ) { delivered in received = delivered }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received, links)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaLinksFeature()
        var fired: [MonaLinksEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, request / underline / activate / release are no-ops.
        let model = makeModel()
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let accepted = feature.requestLinks(
            provider: SynchronousLinkProvider(links: [sampleLink()]),
            model: model,
            executor: executor,
            ticket: gate.captureTicket(),
            token: .none
        ) { _ in }
        XCTAssertFalse(accepted)
        XCTAssertNil(feature.stagedLinks)
        XCTAssertEqual(feature.underlineLink(sampleLink()).length, 0)
        let gateway = MonaTransactionGateway(model: model)
        XCTAssertTrue(feature.activateLink(sampleLink(), gateway: gateway).isEmpty)
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaLinksFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaLinksFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels.first, "Open Link")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertEqual(pseudoLabels.count, 1)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaLinksFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        let language = feature.degradedLanguage
        XCTAssertEqual(language.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(language.hasTokenization)
        XCTAssertFalse(language.hasGrammar)
    }

    // MARK: - Contract leaf

    func testLinksContractLeaf() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()
        let feature = MonaLinksFeature()

        let featureLive = features.contains(MonaLinksFeature.featureId)
        let actionCount = MonaLinksFeature.declaredActionIds.count
        let commandCount = MonaLinksFeature.declaredCommandIds.count
        let contribCount = MonaLinksFeature.declaredContributionIds.count
        let kbCount = MonaLinksFeature.declaredKeybindingCommands.count
        let optionCount = MonaLinksFeature.declaredOptionIds.count
        let menuCount = MonaLinksFeature.declaredMenuIds.count

        let slicePass = MonaLinksFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaLinksFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaLinksFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaLinksFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaLinksFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Request + underline + activate + release.
        let model = makeModel()
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        let link = sampleLink()

        let accepted = feature.requestLinks(
            provider: SynchronousLinkProvider(links: [link]),
            model: model,
            executor: executor,
            ticket: gate.captureTicket(),
            token: .none
        ) { _ in }
        executor.drain()
        let requestPass = accepted && feature.retainedLinksCount(for: version) == 1

        let resolved = feature.resolveLink(link, token: .none)
        let resolvePass = resolved?.url == "https://example.com"

        let underlined = feature.underlineLink(link)
        let underlinePass = underlined.length > 0
            && (underlined is NSAttributedString)
            && underlined.attribute(.underlineStyle, at: 0, effectiveRange: nil) != nil

        let mutation = feature.activateLink(link, gateway: gateway).count == 1
            && gateway.lastCommittedSelections.count == 1

        let released = feature.releaseLinks(modelVersion: version)
        let releasePass = (released == 1 && feature.retainedLinksCount(for: version) == 0)

        // Async publication.
        var delivered = false
        _ = feature.publishLinks([link], executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("LINKS feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(requestPass)
        XCTAssertTrue(resolvePass)
        XCTAssertTrue(underlinePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(releasePass)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
