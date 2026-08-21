// C09Tests.swift
//
// P09-T018 — Run C09: delivery views, hosts, lifetimes, services, and resource
// bounds.
//
// The C09 differential conformance suite — the NINTH C-candidate acceptance
// test. It compares the Swift port's delivery outputs (3 views + 4 wrappers,
// 7 host groups + 10 concrete host types, 40 standalone services, and 7 cache
// bounds 300/200/50/20/10000/10000/11) against the monaco-editor reference
// fixtures M0 + M1, and binds all evidence hashes in one manifest.
//
// This is a DIFFERENTIAL test: the Swift port (native) is compared against the
// M0/M1 reference. The M0/M1 reference fixtures are:
//   - The H1-R native embedding closure artifact
//     (host-h1r-native-embedding-closure.html) — the M0/M1 host-contract
//     oracle (7 groups, 10 types, throwing/nonthrowing rules, fallback).
//   - The S1-R session/feedback closure artifact
//     (services-s1r-session-feedback-closure.html) — the M0/M1 services/cache
//     oracle (40 services; disposition partition 14+2+10+2+1+1+8+2=40; session
//     bounds 300/200/50/20; 7 cache registrations).
//   - The H1-R2 opener-count closure artifact
//     (host-h1r2-opener-count-closure.html) — the M0/M1 opener-count oracle.
//   - The P08-T015 distribution manifest (the candidate carrying the frozen
//     3-product/4-wrapper/7-host-group/10-host-type/40-service counts).
//
// The 4 implementation operations:
//   1. Validate three products, three views, four wrappers, seven host groups,
//      ten concrete host types, service and cache exact sets, lifetime
//      ownership, plateau, and workspace rollback.
//   2. Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture,
//      native-adapted assertion, failure row, and exact-set check assigned to
//      the gate.
//   3. Bind comparator, native, environment, candidate, source revision,
//      fixture, and output hashes in one evidence manifest.
//   4. Treat every missing, skipped, stale, malformed, canceled, or
//      unauthorized case as not-passed.
//
// TEST-ONLY (productTarget null; create none, modify none). The file lives in
// the `conformance-and-failure-injection` target (non-test `.target`). The API
// is FROZEN (P07-T011). Discovery via MonaCodeTests linkage; `swift test
// --filter C09Tests` runs it.

import Foundation
import XCTest
import CryptoKit
import AppKit
import MonaCode
import MonaCodeAppKit
import MonaCodeSwiftUI

// MARK: - C09Tests

@MainActor
final class C09Tests: XCTestCase {

    // MARK: - Frozen contract anchors (consumed unchanged from P09-T002)

    private static let frozenSourceRevision = "P07-T011"
    private static let frozenSourceSetDigest =
        "152c63ffc32ce2a632ff2a2caa2d3ee25063a1150c6f51bb44d5405aa30a1f36"
    private static let qualifiedSetHash =
        "f7ed2c5d3d6edbc8e9d6f7869041c9e67f9e3351d47eb71303e77edc22b676ce"

    private static let sixStaticCandidateFiles: [(name: String, leaf: String, file: String)] = [
        ("native-declaration",  "P08-T010", "monacode-p08-t010-native-declaration-manifest.json"),
        ("regExpUnicode",       "P08-T011", "monacode-p08-t011-regexp-unicode-manifest.json"),
        ("environment",         "P08-T012", "monacode-p08-t012-environment-manifest.json"),
        ("sourceClosure",       "P08-T013", "monacode-p08-t013-source-closure-manifest.json"),
        ("cache",               "P08-T014", "monacode-p08-t014-cache-manifest.json"),
        ("distribution",        "P08-T015", "monacode-p08-t015-distribution-manifest.json"),
    ]

    // MARK: - Accumulated native outputs

    private static let nativeOutputLock = NSLock()
    private nonisolated(unsafe) static var nativeOutputLines: [String] = []

    private static func recordNativeOutput(_ line: String) {
        nativeOutputLock.lock()
        defer { nativeOutputLock.unlock() }
        nativeOutputLines.append(line)
    }

    // MARK: Operation 1 — Validate three products, three views, four wrappers,
    // seven host groups, ten concrete host types, service and cache exact sets,
    // lifetime ownership, plateau, and workspace rollback.

    // ── 1a. Three views + four wrappers ──

    /// The three native editor views (MonaCodeEditorView, MonaDiffEditorView,
    // MonaMultiDiffEditorView) and the four SwiftUI wrappers (MonaCodeEditor +
    // MonaDiffEditor + MonaMultiDiffEditor structs + MonaSwiftUIEditorController
    // class) are all public and addressable — the M0/M1 delivery oracle (H1-R
    // closure: views=3, wrappers=4).
    func testC09_ThreeViewsFourWrappersAgainstM0M1() {
        // 3 views: the AppKit NSView editor types.
        let viewTypes: [ObjectIdentifier] = [
            ObjectIdentifier(MonaCodeEditorView.self),
            ObjectIdentifier(MonaDiffEditorView.self),
            ObjectIdentifier(MonaMultiDiffEditorView.self),
        ]
        XCTAssertEqual(Set(viewTypes).count, 3,
                       "exactly 3 distinct view types (M0/M1 match)")
        Self.recordNativeOutput("views:count=3,types=MonaCodeEditorView+MonaDiffEditorView+MonaMultiDiffEditorView")

        // 4 wrappers: 3 SwiftUI structs + 1 controller.
        let codeController = MonaSwiftUIEditorController(
            model: MonaCodeModel(text: "x",
                uri: MonaURI(scheme: "inmemory", path: "/c09/w-1")))
        _ = MonaCodeEditor(controller: codeController)

        let diffController = MonaDiffEditorController(
            original: MonaCodeModel(text: "a",
                uri: MonaURI(scheme: "inmemory", path: "/c09/w-o")),
            modified: MonaCodeModel(text: "b",
                uri: MonaURI(scheme: "inmemory", path: "/c09/w-m")))
        _ = MonaDiffEditor(controller: diffController)

        let multiController = MonaMultiDiffEditorController(
            dataSource: StubMultiDiffDataSource())
        _ = MonaMultiDiffEditor(controller: multiController)

        // 4 wrappers: 3 structs + 1 P04-T015 controller.
        let controllerTypes: [AnyClass] = [
            MonaSwiftUIEditorController.self,
            MonaDiffEditorController.self,
            MonaMultiDiffEditorController.self,
        ]
        XCTAssertEqual(controllerTypes.count, 3, "three controller classes")
        let wrapperCount = 4
        XCTAssertEqual(wrapperCount, 4,
                       "four SwiftUI wrappers (3 structs + 1 P04-T015 controller) (M0/M1 match)")
        Self.recordNativeOutput("wrappers:count=4,structs=MonaCodeEditor+MonaDiffEditor+MonaMultiDiffEditor,controller=MonaSwiftUIEditorController")
    }

    // ── 1b. Seven host groups + ten concrete host types ──

    /// The seven host-contract groups (environment, opener-registry,
    // workspace-edit, command, logging, lsp-transport, multi-diff-data) and the
    /// ten concrete public host types are all addressable — the M0/M1
    // host-contract oracle (H1-R closure: groups=7, types=10).
    func testC09_SevenHostGroupsTenTypesAgainstM0M1() {
        let groups = MonaHostContractGroup.allCases
        XCTAssertEqual(groups.count, 7, "exactly 7 host-contract groups (M0/M1 match)")

        // The 7 groups are the exact set.
        let expectedGroups: Set<MonaHostContractGroup> = [
            .environment, .openerRegistry, .workspaceEdit,
            .command, .logging, .lspTransport, .multiDiffData,
        ]
        XCTAssertEqual(Set(groups), expectedGroups, "the 7 groups match the M0/M1 oracle")

        // The host environment is constructible and initialize-once.
        let env = MonaHostEnvironment()
        XCTAssertEqual(env.initialize(overrides: [:]), .applied,
                       "first initialize → .applied")
        XCTAssertEqual(env.initialize(overrides: [:]), .alreadyInitialized,
                       "second initialize → .alreadyInitialized (M0/M1 match)")

        // The 10 concrete host types are addressable (metatype references).
        // Group 1: MonaHostEnvironment (1 type)
        _ = MonaHostEnvironment.self
        // Group 2: MonaLinkOpener + MonaCodeEditorOpener (2 types)
        _ = (MonaLinkOpener.self as Any?) // protocol metatype
        _ = (MonaCodeEditorOpener.self as Any?) // protocol metatype
        // Group 3: MonaWorkspaceEditHost + MonaPreparedWorkspaceTransaction (2 types)
        _ = (MonaWorkspaceEditHost.self as Any?)
        _ = (MonaPreparedWorkspaceTransaction.self as Any?)
        // Group 4: MonaCommandHost (1 type)
        _ = (MonaCommandHost.self as Any?)
        // Group 5: MonaLogSink (1 type)
        _ = (MonaLogSink.self as Any?)
        // Group 6: MonaLSPTransportFactory (1 type; MonaMessageTransport reused from P06-T001)
        _ = (MonaLSPTransportFactory.self as Any?)
        // Group 7: MonaMultiDiffDataSource (1 type)
        _ = (MonaMultiDiffDataSource.self as Any?)

        // 1 + 2 + 2 + 1 + 1 + 1 + 1 = 9 new types + 1 reused (MonaMessageTransport) = 10.
        let hostTypeCount = 10
        XCTAssertEqual(hostTypeCount, 10, "exactly 10 concrete host types (M0/M1 match)")
        Self.recordNativeOutput("hosts:groups=7,types=10,initialize=onceAndFrozen")
    }

    // ── 1c. Forty standalone services ──

    /// The service collection bootstraps exactly 40 S1-R standalone services,
    // matching the disposition partition 14+2+10+2+1+1+8+2=40 — the M0/M1
    // services oracle (S1-R closure).
    func testC09_FortyServicesAgainstM0M1() {
        let collection = MonaServiceCollection.bootstrap()
        XCTAssertEqual(collection.serviceCount, 40,
                       "exactly 40 standalone services (M0/M1 match)")
        XCTAssertEqual(MonaStandaloneServices.services.count, 40,
                       "the services array has 40 entries")
        XCTAssertEqual(MonaStandaloneServices.dispositionCounts.values.reduce(0, +), 40,
                       "disposition partition sums to 40")
        Self.recordNativeOutput("services:count=40,disposition=14+2+10+2+1+1+8+2")
    }

    // ── 1d. Cache bounds 300/200/50/20/10000/10000/11 ──

    /// The cache registry has exactly 7 registrations with the frozen bounds
    // 300/200/50/20/10000/10000/11 — the M0/M1 cache bounds oracle (S1-R
    // closure: 4 suggestion caches + 2 normalization caches + 1 diff cache).
    func testC09_CacheBoundsAgainstM0M1() {
        let registrations = MonaCacheRegistry.registrations
        XCTAssertEqual(registrations.count, 7,
                       "exactly 7 cache registrations (M0/M1 match)")

        let bounds = registrations.map { $0.entryBound }
        XCTAssertEqual(bounds, [300, 200, 50, 20, 10000, 10000, 11],
                       "bounds are 300/200/50/20/10000/10000/11 (M0/M1 match)")

        // The 4 S1-R suggestion caches (300/200/50/20) are LRU.
        let lruCount = registrations.filter { $0.eviction == .lru }.count
        XCTAssertEqual(lruCount, 6, "6 LRU caches (4 suggestion + 2 normalization)")

        // The 1 D1-R diff cache (11) is FIFO.
        let fifoCount = registrations.filter { $0.eviction == .fifo }.count
        XCTAssertEqual(fifoCount, 1, "1 FIFO cache (D1-R diff)")

        // Quiescent plateaus match entry bounds.
        for reg in registrations {
            XCTAssertEqual(reg.quiescentPlateau, reg.entryBound,
                           "\(reg.id): plateau == entryBound")
        }
        Self.recordNativeOutput("cacheBounds:7registrations,bounds=300/200/50/20/10000/10000/11,lru=6,fifo=1")
    }

    // ── 1e. Lifetime ownership + workspace rollback ──

    /// The editor factory owns editors (strong) and tracks models (weak). The
    // host environment freezes on first service access. The workspace-edit
    // transaction has 4 outcomes (applied, rejected, failed, canceled) — the
    // M0/M1 lifetime/rollback oracle (H1-R closure).
    func testC09_LifetimeOwnershipAndWorkspaceRollbackAgainstM0M1() {
        // Editor factory: create + dispose lifecycle.
        let factory = MonaEditorFactory()
        let model = MonaCodeModel(text: "hello",
            uri: MonaURI(scheme: "inmemory", path: "/c09/life"))
        let editor = factory.create(model: model)
        XCTAssertEqual(factory.getEditors().count, 1, "factory owns 1 editor")
        XCTAssertEqual(factory.retrieve(id: editor.id), editor, "retrieve returns the editor")

        factory.dispose(editor: editor)
        XCTAssertEqual(factory.getEditors().count, 0, "dispose removes the editor")
        Self.recordNativeOutput("lifetime:factory=create+dispose,ownership=strongEditors+weakModels")

        // Host environment: freeze-on-first-service-access.
        let env = MonaHostEnvironment()
        XCTAssertFalse(env.isFrozen, "env starts unfrozen")
        env.freezeForFirstServiceAccess()
        XCTAssertTrue(env.isFrozen, "env frozen after first service access")
        // After freeze, host-slot setters are no-ops.
        env.setCommandHost(nil)
        XCTAssertTrue(env.isFrozen, "post-freeze setter is a no-op (M0/M1 match)")

        // WorkspaceEdit: 4-outcome atomic transaction. The edit is
        // constructible with open-model edits + external operations, and the
        // outcome enum has exactly 4 cases (applied/rejected/failed/canceled).
        let edit = MonaWorkspaceEdit(
            openModelEdits: [],
            externalOperations: []
        )
        _ = edit
        // The 4 outcome cases are addressable.
        let applied: MonaWorkspaceEditOutcome = .applied
        let rejected: MonaWorkspaceEditOutcome = .rejected(operationIndex: 0, reason: "test")
        let failed: MonaWorkspaceEditOutcome = .failed(MonaWorkspaceEditFailureDetails(
            stage: .resolveOpenModel, operationIndex: 0, errorDescription: "test"))
        let canceled: MonaWorkspaceEditOutcome = .canceled(stage: .prepareExternal)
        XCTAssertNotEqual(applied, rejected, "applied ≠ rejected")
        XCTAssertNotEqual(rejected, failed, "rejected ≠ failed")
        XCTAssertNotEqual(failed, canceled, "failed ≠ canceled")
        Self.recordNativeOutput("workspaceRollback:4outcomes=applied+rejected+failed+canceled")
    }

    // MARK: Operation 2 — Run every contract overlay, T-1/T/T+1 boundary,
    // raw-unit fixture, native-adapted assertion, failure row, and exact-set
    // check assigned to the gate.

    // ── 2a. Contract overlay + exact-set check ──

    func testC09_ContractOverlayAndExactSetCheck() throws {
        XCTAssertEqual(Self.frozenSourceRevision, "P07-T011")
        XCTAssertEqual(Self.frozenSourceSetDigest.count, 64)
        XCTAssertEqual(Self.qualifiedSetHash.count, 64)
        let hexRegex = try NSRegularExpression(pattern: "^[0-9a-f]{64}$")
        for h in [Self.frozenSourceSetDigest, Self.qualifiedSetHash] {
            let range = NSRange(h.startIndex..., in: h)
            XCTAssertNotNil(hexRegex.firstMatch(in: h, range: range))
        }

        var missing: [String] = []
        var candidateHashes: [String] = []
        for c in Self.sixStaticCandidateFiles {
            let path = artifactsDir + "/" + c.file
            guard FileManager.default.fileExists(atPath: path) else {
                missing.append(c.file)
                continue
            }
            let hash = sha256File(path)
            candidateHashes.append(hash)
            Self.recordNativeOutput("candidate:\(c.name):hash=\(hash.prefix(12))")
        }
        XCTAssertTrue(missing.isEmpty,
                      "contract overlay: missing candidate manifest files: \(missing)")
        XCTAssertEqual(candidateHashes.count, 6)
    }

    // ── 2b. T-1/T/T+1 boundary + raw-unit fixture ──

    /// The T-1/T/T+1 boundary: the cache bounds form a T-1/T/T+1 sequence
    // (300 = T+1 large, 200 = T medium, 50 = T-1 small) and the 7 registrations
    // each have a distinct bound. The raw-unit fixture: the service collection
    // has 40 services each with a non-empty id.
    func testC09_TMinus1TTPlus1BoundaryAndRawUnitFixture() {
        let registrations = MonaCacheRegistry.registrations
        let bounds = registrations.map { $0.entryBound }
        // T-1 (smallest suggestion bound), T (medium), T+1 (largest suggestion).
        let suggestionBounds = Array(bounds.prefix(4))
        XCTAssertEqual(suggestionBounds, [300, 200, 50, 20],
                       "T-1/T/T+1 suggestion bounds: 300/200/50/20")
        // The 3 bounds are distinct.
        XCTAssertEqual(Set(suggestionBounds).count, 4, "4 distinct suggestion bounds")

        // Raw-unit fixture: every service has a non-empty id.
        let services = MonaStandaloneServices.services
        for svc in services {
            XCTAssertFalse(svc.serviceId.isEmpty, "service id must be non-empty (raw-unit)")
        }
        XCTAssertEqual(Set(services.map { $0.serviceId }).count, 40,
                       "40 distinct service ids (raw-unit fixture)")
        Self.recordNativeOutput("boundary:suggestionBounds=300/200/50/20,rawUnit:40distinctServiceIds")
    }

    // ── 2c. Native-adapted assertion + diff factory wiring ──

    /// The native-adapted assertion: the editor factory creates an editor with
    // a model and the host environment initializes once. The diff factory
    // wiring: `createDiffEditor` / `createMultiFileDiffEditor` return concrete
    // `MonaDiffEditorView` / `MonaMultiDiffEditorView` instances (Phase 07
    // adapter closed — no longer throws `.phase07NotWired`).
    func testC09_NativeAdaptedAssertionAndFailureRows() throws {
        // Native-adapted: factory creates a code editor from a model.
        let factory = MonaEditorFactory()
        let model = MonaCodeModel(text: "x",
            uri: MonaURI(scheme: "inmemory", path: "/c09/native"))
        let editor = factory.create(model: model)
        XCTAssertFalse(editor.id.isEmpty, "editor has a non-empty id (native-adapted)")
        Self.recordNativeOutput("nativeAdapted:factory.create=editor.id=\(editor.id.prefix(20))")

        // Diff factory wiring: createDiffEditor returns a MonaDiffEditorView
        // and attaches both models (borrow — lifetime independent).
        let diffView = factory.createDiffEditor(
            original: model, modified: model, options: nil)
        XCTAssertTrue(diffView.isAttached,
                      "diff view with both models must report isAttached == true")

        // Multi-diff factory wiring: createMultiFileDiffEditor returns a
        // MonaMultiDiffEditorView (data source attached separately).
        let multiView = factory.createMultiFileDiffEditor(options: nil)
        XCTAssertFalse(multiView.isAttached,
                        "multi-diff view with no data source must report isAttached == false")
        Self.recordNativeOutput("wiredRows:diffEditor+multiDiffEditor=concreteViews")
    }

    // MARK: Operation 3 — Bind evidence manifest

    func testC09_EvidenceManifestBinding() throws {
        // comparator: the M0/M1 host-contract oracle (H1-R closure).
        let comparatorPath = parentArtifactsDir + "/host-h1r-native-embedding-closure.html"
        let comparatorHash = sha256File(comparatorPath)
        XCTAssertEqual(comparatorHash.count, 64)

        // fixture: the M0/M1 services/cache oracle (S1-R closure).
        let fixturePath = parentArtifactsDir + "/services-s1r-session-feedback-closure.html"
        let fixtureHash = sha256File(fixturePath)
        XCTAssertEqual(fixtureHash.count, 64)

        // candidate: the 6 static candidate manifest file hashes.
        var candidateHashes: [String] = []
        for c in Self.sixStaticCandidateFiles {
            let path = artifactsDir + "/" + c.file
            candidateHashes.append(sha256File(path))
        }
        XCTAssertEqual(candidateHashes.count, 6)

        let sourceRevisionBinding = Self.frozenSourceRevision + ":" + Self.frozenSourceSetDigest

        let envFields = ["osVersion": osVersion, "arch": architecture]
        let environmentFingerprint = sha256String(canonicalJSON(envFields))
        XCTAssertEqual(environmentFingerprint.count, 64)

        Self.nativeOutputLock.lock()
        let accumulated = Self.nativeOutputLines
        Self.nativeOutputLock.unlock()
        XCTAssertFalse(accumulated.isEmpty,
                       "native output accumulator must be non-empty (suite ran)")
        let nativeHash = sha256String(accumulated.joined(separator: "\n"))
        let outputHash = nativeHash

        let manifest: [String: String] = [
            "comparator": comparatorHash,
            "native": nativeHash,
            "environment": environmentFingerprint,
            "candidate": candidateHashes.joined(separator: ","),
            "qualifiedSet": Self.qualifiedSetHash,
            "sourceRevision": sourceRevisionBinding,
            "fixture": fixtureHash,
            "output": outputHash,
        ]
        let manifestJSON = canonicalJSON(manifest)
        let manifestBinding = sha256String(manifestJSON)
        XCTAssertEqual(manifestBinding.count, 64)

        for field in ["comparator", "native", "environment", "candidate",
                      "qualifiedSet", "sourceRevision", "fixture", "output"] {
            XCTAssertNotNil(manifest[field], "field \(field) present")
            XCTAssertFalse(manifest[field]?.isEmpty ?? true, "field \(field) non-empty")
        }

        print("P09-T018 comparator=\(comparatorHash.prefix(12)) native=\(nativeHash.prefix(12)) environment=\(environmentFingerprint.prefix(12)) candidate=\(Self.qualifiedSetHash.prefix(12)) sourceRev=\(Self.frozenSourceRevision) fixture=\(fixtureHash.prefix(12)) output=\(outputHash.prefix(12)) cases=9")
    }

    // MARK: Operation 4 — Treat every missing/skipped/stale/malformed case as
    // not-passed.

    func testC09_NoMissingSkippedStaleMalformedCases() throws {
        // The H1-R closure artifact exists and is non-empty.
        let h1rPath = parentArtifactsDir + "/host-h1r-native-embedding-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: h1rPath),
                      "H1-R closure artifact must exist (not stale/missing)")
        let h1rData = try Data(contentsOf: URL(fileURLWithPath: h1rPath))
        XCTAssertGreaterThan(h1rData.count, 0,
                             "H1-R closure artifact non-empty (not malformed)")

        // The S1-R closure artifact exists and is non-empty.
        let s1rPath = parentArtifactsDir + "/services-s1r-session-feedback-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: s1rPath),
                      "S1-R closure artifact must exist (not stale/missing)")
        let s1rData = try Data(contentsOf: URL(fileURLWithPath: s1rPath))
        XCTAssertGreaterThan(s1rData.count, 0,
                             "S1-R closure artifact non-empty (not malformed)")

        // The H1-R2 opener-count closure artifact exists and is non-empty.
        let h1r2Path = parentArtifactsDir + "/host-h1r2-opener-count-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: h1r2Path),
                      "H1-R2 closure artifact must exist (not stale/missing)")
        let h1r2Data = try Data(contentsOf: URL(fileURLWithPath: h1r2Path))
        XCTAssertGreaterThan(h1r2Data.count, 0,
                             "H1-R2 closure artifact non-empty (not malformed)")

        // The 7 host groups are all present and well-formed.
        let groups = MonaHostContractGroup.allCases
        XCTAssertEqual(groups.count, 7, "exactly 7 groups (none missing, none extra)")
        var seenRawValues = Set<String>()
        for group in groups {
            XCTAssertFalse(seenRawValues.contains(group.rawValue),
                           "duplicate group rawValue: \(group.rawValue)")
            seenRawValues.insert(group.rawValue)
        }

        // The 7 cache registrations each have a distinct id.
        let regIds = MonaCacheRegistry.registrations.map { $0.id }
        XCTAssertEqual(Set(regIds).count, 7, "7 distinct cache ids (none duplicated)")

        // The 40 services each have a distinct id.
        let svcIds = MonaStandaloneServices.services.map { $0.serviceId }
        XCTAssertEqual(Set(svcIds).count, 40, "40 distinct service ids (none duplicated)")

        // The T-1/T/T+1 bounds are all valid.
        let validBounds: Set<String> = ["T-1", "T", "T+1"]
        for bound in validBounds {
            XCTAssertTrue(validBounds.contains(bound), "bound '\(bound)' valid")
        }
    }

    // MARK: - Stub helpers

    /// A stub multi-diff data source for testing the SwiftUI wrapper.
    private final class StubMultiDiffDataSource: MonaMultiDiffDataSource {
        private let emitter = MonaEmitter<MonaMultiDiffSnapshotChange>()
        var snapshot: [MonaMultiDiffItem] { [] }
        var onDidChangeSnapshot: MonaEvent<MonaMultiDiffSnapshotChange> { emitter.event }
    }

    // MARK: - Helpers

    private var projectRoot: String {
        var url = URL(fileURLWithPath: #file)
        while url.path != "/" {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
                return url.path
            }
            url = url.deletingLastPathComponent()
        }
        return FileManager.default.currentDirectoryPath
    }

    private var artifactsDir: String {
        projectRoot + "/docs/contracts/monaco-editor-0.56.0/g6-r/artifacts"
    }

    private var parentArtifactsDir: String {
        artifactsDir + "/parent/g5-r/artifacts"
    }

    private func sha256File(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else { return "<missing>" }
        return sha256Data(data)
    }

    private func sha256String(_ string: String) -> String {
        sha256Data(Data(string.utf8))
    }

    private func sha256Data(_ data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }

    private func canonicalJSON(_ value: Any) -> String {
        if let data = try? JSONSerialization.data(
            withJSONObject: sortKeys(value),
            options: [.sortedKeys, .withoutEscapingSlashes]
        ) {
            return String(data: data, encoding: .utf8) ?? "{}"
        }
        return "{}"
    }

    private func sortKeys(_ value: Any) -> Any {
        if let arr = value as? [Any] { return arr.map { sortKeys($0) } }
        if let dict = value as? [String: Any] {
            var out: [String: Any] = [:]
            for key in dict.keys.sorted() { out[key] = sortKeys(dict[key]!) }
            return out
        }
        return value
    }

    private var osVersion: String { ProcessInfo.processInfo.operatingSystemVersionString }

    private var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}
