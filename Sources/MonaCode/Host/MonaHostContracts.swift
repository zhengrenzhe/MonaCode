// MonaHostContracts.swift
//
// P07-T005 — Implement seven host groups and ten concrete host types.
//
// Defines the host-contract layer: the public API a host app implements to
// plug into MonaCode. This file is the Swift counterpart of the H1-R / H1-R2
// host-contract closure (host-h1r-native-embedding-closure.html +
// host-h1r2-opener-count-closure.html + monacode-h1r-native-boundary-
// manifest.json). It is Foundation-only Core: a host app conforms to these
// protocols in its own module (the macOS concrete adapters live in
// `MonaCodeAppKit/Host/MonaAppKitHostAdapters.swift`).
//
// The seven host-contract groups (H1-R2 `groups`, verbatim):
//
//   1. environment     — MonaHostEnvironment (process-global, initialize-once)
//   2. opener-registry — MonaLinkOpener + MonaCodeEditorOpener (two DISTINCT
//                        LIFO stacks; the registries live in MonaOpenerRegistry.swift)
//   3. workspace-edit   — MonaWorkspaceEditHost + MonaPreparedWorkspaceTransaction
//   4. command          — MonaCommandHost
//   5. logging          — MonaLogSink
//   6. lsp-transport     — MonaMessageTransport (P06-T001, REUSED) +
//                          MonaLSPTransportFactory
//   7. multi-diff-data  — MonaMultiDiffDataSource
//
// The ten concrete public host types: the eight H1-defined types plus the two
// F1-R4 opener interfaces. `MonaMessageTransport` is reused verbatim from
// P06-T001 — the lsp-transport group does NOT redefine it.
//
// Naming resolution (recorded): the H1-R manifest names the environment
// group's host type `MonaCodeEnvironment`. That exact spelling is already
// taken by the P00-T007 immutable `struct MonaCodeEnvironment` (the runtime-
// locale + UI-message-profile aggregate). The two are distinct concepts
// (P00-T007 is a value type; the host environment is a process-global mutable
// class). To honor `modify: none` (the P00-T007 struct is frozen and widely
// referenced) AND the contract intent, the host environment class is spelled
// `MonaHostEnvironment`. This is a minimal, documented deviation forced by the
// pre-existing frozen symbol; it does not change the group count, the type
// count, or any frozen behavior.
//
// Frozen behavior (per type):
//
//   - throwing:  MonaWorkspaceEditHost.applyExternalOperation /
//                prepareAtomicExternalOperations, MonaCommandHost.execute,
//                MonaLSPTransportFactory.makeTransport, MonaLinkOpener.openLink,
//                MonaCodeEditorOpener.openCodeEditor CAN throw.
//   - nonthrowing: MonaLogSink.record, MonaPreparedWorkspaceTransaction.commit
//                (sync) / .abort (async), MonaHostEnvironment.initialize,
//                MonaMultiDiffDataSource.snapshot CANNOT throw.
//   - ordering:  initialize is once-and-frozen (a second call returns
//                .alreadyInitialized); first service access freezes host-slot
//                overrides; opener registries traverse last-registered-first.
//   - disposal:  opener registration disposables remove EXACTLY that
//                registration (idempotent); MonaPreparedWorkspaceTransaction
//                .abort is idempotent; MonaMessageTransport.close/fail/dispose
//                are idempotent (reused from P06-T001).
//   - fallback:  nil commandHost → unhandled; nil logSink → dropped; nil
//                workspaceEditHost → core open-model-only; no opener handles
//                → unhandled; NO implicit URL / file / network / logging /
//                transport / workspace authority is added.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - MonaHostContractGroup

/// The seven host-contract groups (the verbatim projection of the H1-R2
/// `groups` array). Used by the closure test to assert the group count.
public enum MonaHostContractGroup: String, Sendable, Equatable, CaseIterable {

    /// The process-global MainActor environment (initialize-once, freeze-on-
    /// first-service-access). Concrete type: `MonaHostEnvironment`.
    case environment

    /// Link and code-editor opener registries (two DISTINCT last-registered-
    /// first stacks). Concrete types: `MonaLinkOpener`, `MonaCodeEditorOpener`.
    case openerRegistry = "opener-registry"

    /// Host-owned external resource operations plus prepared nonthrowing
    /// atomic commit. Concrete types: `MonaWorkspaceEditHost`,
    /// `MonaPreparedWorkspaceTransaction`.
    case workspaceEdit = "workspace-edit"

    /// Host command execution (only an unhandled provider/LSP command reaches
    /// the host). Concrete type: `MonaCommandHost`.
    case command

    /// Nonthrowing, nonblocking, non-reentrant telemetry. Concrete type:
    /// `MonaLogSink`.
    case logging

    /// Host LSP byte transport (host supplies lifecycle + ordered bytes; the
    /// component owns framing/JSON-RPC/LSP). Concrete types:
    /// `MonaMessageTransport` (P06-T001, reused) + `MonaLSPTransportFactory`.
    case lspTransport = "lsp-transport"

    /// Stable item identity, ordered snapshots, synchronous MainActor change
    /// events. Concrete type: `MonaMultiDiffDataSource`.
    case multiDiffData = "multi-diff-data"
}

// MARK: - MonaHostContractError

/// Errors raised by the host-contract layer.
public enum MonaHostContractError: Error, Equatable, Sendable {

    /// An opener threw — the rejection becomes the operation failure and does
    /// NOT invoke an older opener (no fallback). Carries the opener's
    /// diagnostic string.
    case openerRejection(String)

    /// The host declined external workspace authority — a host that has not
    /// opted into resource operations throws this from
    /// `applyExternalOperation` / `prepareAtomicExternalOperations`.
    case workspaceAuthorityDeclined

    /// A host command could not be handled. Carries the command id.
    case commandUnhandled(String)

    /// A multi-diff snapshot was rejected because it contained duplicate item
    /// IDs (the whole new snapshot is rejected; the previous snapshot is
    /// preserved).
    case multiDiffDuplicateIDs
}

// MARK: - Group 1: environment — MonaHostEnvironment

/// The process-global host environment — the Swift counterpart of Monaco's
/// standalone singleton services.
///
/// `initialize(overrides:)` is called exactly once before the first service
/// access; a second call returns `.alreadyInitialized` and changes nothing.
/// The first service access (signaled by `freezeForFirstServiceAccess()`)
/// freezes host-slot overrides — after freeze, `setWorkspaceEditHost(_:)` /
/// `setCommandHost(_:)` / `setLogSink(_:)` are no-ops.
///
/// The environment holds the two DISTINCT opener registries
/// (`linkOpenerRegistry`, `codeEditorOpenerRegistry`) and the three host
/// slots (`workspaceEditHost`, `commandHost`, `logSink`). All slots are `nil`
/// by default — a host must opt in EXPLICITLY. There is NO implicit URL,
/// file, network, logging, transport, or workspace authority: `nil` slots
/// mean the corresponding fallback applies (unhandled / dropped / open-model-
/// only).
///
/// Fallback (frozen):
///   - `workspaceEditHost == nil` → the core open-model-only workspace
///     capability is retained (no external resource operations are inferred).
///   - `commandHost == nil` → a command execution returns unhandled.
///   - `logSink == nil` → logs are dropped (no implicit network/file logging).
///   - no registered opener handles a URI → unhandled (no implicit
///     `NSWorkspace.open` / URL / file fallback).
public final class MonaHostEnvironment: @unchecked Sendable {

    /// The result of `initialize(overrides:)`.
    public enum InitializeResult: Sendable, Equatable {
        /// The overrides were applied (first successful initialize).
        case applied
        /// Initialize was already called — this call is a no-op (overrides
        /// frozen from the first call).
        case alreadyInitialized
    }

    private let lock = NSLock()
    private var initialized = false
    private var frozen = false
    private var _overrides: [String: MonaJSONValue] = [:]

    private let _linkOpenerRegistry: MonaLinkOpenerRegistry
    private let _codeEditorOpenerRegistry: MonaCodeEditorOpenerRegistry

    private var _workspaceEditHost: MonaWorkspaceEditHost? = nil
    private var _commandHost: MonaCommandHost? = nil
    private var _logSink: MonaLogSink? = nil

    /// Creates a fresh host environment. The host app creates ONE instance and
    /// shares it process-globally; tests create fresh instances for hermetic
    /// isolation ("test processes isolate environment state by process").
    public init() {
        self._linkOpenerRegistry = MonaLinkOpenerRegistry()
        self._codeEditorOpenerRegistry = MonaCodeEditorOpenerRegistry()
    }

    /// Initializes the environment with `overrides`. Called exactly once
    /// before the first service access. A second call returns
    /// `.alreadyInitialized` and changes nothing (overrides are frozen from
    /// the first call).
    public func initialize(overrides: [String: MonaJSONValue] = [:]) -> InitializeResult {
        lock.lock(); defer { lock.unlock() }
        if initialized { return .alreadyInitialized }
        initialized = true
        _overrides = overrides
        return .applied
    }

    /// `true` once `freezeForFirstServiceAccess()` has frozen host-slot
    /// overrides. After freeze, the host-slot setters are no-ops.
    public var isFrozen: Bool {
        lock.lock(); defer { lock.unlock() }
        return frozen
    }

    /// Freezes host-slot overrides — called by the runtime on the first
    /// service access. After freeze, `setWorkspaceEditHost(_:)` /
    /// `setCommandHost(_:)` / `setLogSink(_:)` are no-ops (a later host cannot
    /// attach). Idempotent.
    public func freezeForFirstServiceAccess() {
        lock.lock(); frozen = true; lock.unlock()
    }

    /// The link opener registry (DISTINCT from the code-editor registry).
    public var linkOpenerRegistry: MonaLinkOpenerRegistry { _linkOpenerRegistry }

    /// The code-editor opener registry (DISTINCT from the link registry).
    public var codeEditorOpenerRegistry: MonaCodeEditorOpenerRegistry { _codeEditorOpenerRegistry }

    /// The workspace-edit host, or `nil` (open-model-only fallback).
    public var workspaceEditHost: MonaWorkspaceEditHost? {
        lock.lock(); defer { lock.unlock() }
        return _workspaceEditHost
    }

    /// The command host, or `nil` (unhandled fallback).
    public var commandHost: MonaCommandHost? {
        lock.lock(); defer { lock.unlock() }
        return _commandHost
    }

    /// The log sink, or `nil` (drop fallback).
    public var logSink: MonaLogSink? {
        lock.lock(); defer { lock.unlock() }
        return _logSink
    }

    /// Attaches a workspace-edit host. No-op after `freezeForFirstServiceAccess()`.
    public func setWorkspaceEditHost(_ host: MonaWorkspaceEditHost?) {
        lock.lock(); defer { lock.unlock() }
        guard !frozen else { return }
        _workspaceEditHost = host
    }

    /// Attaches a command host. No-op after `freezeForFirstServiceAccess()`.
    public func setCommandHost(_ host: MonaCommandHost?) {
        lock.lock(); defer { lock.unlock() }
        guard !frozen else { return }
        _commandHost = host
    }

    /// Attaches a log sink. No-op after `freezeForFirstServiceAccess()`.
    public func setLogSink(_ sink: MonaLogSink?) {
        lock.lock(); defer { lock.unlock() }
        guard !frozen else { return }
        _logSink = sink
    }

    /// Registers a link opener (delegates to `linkOpenerRegistry`). Returns a
    /// disposable that removes EXACTLY this registration when disposed.
    @discardableResult
    public func registerLinkOpener(_ opener: MonaLinkOpener) -> MonaDisposable {
        return _linkOpenerRegistry.register(opener)
    }

    /// Registers a code-editor opener (delegates to `codeEditorOpenerRegistry`).
    /// Returns a disposable that removes EXACTLY this registration.
    @discardableResult
    public func registerCodeEditorOpener(_ opener: MonaCodeEditorOpener) -> MonaDisposable {
        return _codeEditorOpenerRegistry.register(opener)
    }

    /// Tears down the environment: disposes both opener registries. Idempotent.
    public func dispose() {
        _linkOpenerRegistry.dispose()
        _codeEditorOpenerRegistry.dispose()
    }
}

// MARK: - Group 2: opener-registry — MonaLinkOpener + MonaCodeEditorOpener

/// A link opener. Invoked on MainActor in registry order (last-registered-
/// first). Returns `true` to stop traversal (handled), `false` to continue to
/// the next older registration. A thrown result is the operation failure
/// (rejection) and does NOT invoke an older opener.
///
/// The opener receives the parsed `MonaURI`. It performs NO implicit
/// `NSWorkspace.open`, URL, file, or network fallback — a host that wishes to
/// open a resource must do so with EXPLICIT authority inside its conformer.
public protocol MonaLinkOpener: AnyObject {
    /// Opens `uri`. `true` = handled (stop); `false` = unhandled (continue);
    /// `throw` = rejection (failure, no fallback to older openers).
    func openLink(_ uri: MonaURI) throws -> Bool
}

/// The target a code-editor opener is asked to reveal: absent, a position, or
/// a range.
public enum MonaCodeEditorOpenerTarget: Sendable, Equatable {
    /// No specific target — open the editor for the URI.
    case absent
    /// Reveal a position (1-based line, 1-based character).
    case position(line: Int, character: Int)
    /// Reveal a range (1-based, inclusive).
    case range(startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int)
}

/// A code-editor opener. Invoked on MainActor in registry order (last-
/// registered-first) with the live source editor's URI and an absent /
/// position / range target. Returns `true` to stop, `false` to continue. A
/// thrown result is the operation failure and does NOT invoke an older opener.
///
/// The opener does NOT copy editor or model state. It performs NO implicit
/// editor-open fallback — a host that wishes to open an editor must do so
/// with EXPLICIT authority.
public protocol MonaCodeEditorOpener: AnyObject {
    /// Opens a code editor for `uri` at `target`. `true` = handled (stop);
    /// `false` = unhandled (continue); `throw` = rejection (no fallback).
    func openCodeEditor(_ uri: MonaURI, target: MonaCodeEditorOpenerTarget) throws -> Bool
}

// MARK: - Group 3: workspace-edit — MonaWorkspaceEditHost + MonaPreparedWorkspaceTransaction

/// The capabilities a workspace-edit host advertises. A host that has not
/// opted into resource operations reports `appliesResourceOperations == false`
/// (the no-implicit-workspace-authority default).
public struct MonaWorkspaceEditCapabilities: Sendable, Equatable {
    /// `true` when the host applies external create/rename/delete resource
    /// operations. `false` (default for a declining host) means external
    /// resource operations are NOT delegated to the host.
    public let appliesResourceOperations: Bool
    /// `true` when the host can prepare an atomic nonthrowing commit.
    public let supportsTransactional: Bool
    /// `true` when the host records undo receipts for applied operations.
    public let supportsUndoReceipts: Bool

    public init(
        appliesResourceOperations: Bool,
        supportsTransactional: Bool = false,
        supportsUndoReceipts: Bool = false
    ) {
        self.appliesResourceOperations = appliesResourceOperations
        self.supportsTransactional = supportsTransactional
        self.supportsUndoReceipts = supportsUndoReceipts
    }
}

/// A stable transaction identity (assigned by the component, opaque to the
/// host).
public struct MonaWorkspaceTransactionIdentity: Sendable, Equatable {
    public let id: String
    public init(id: String) { self.id = id }
}

/// The kind of an external workspace operation (create / rename / delete).
/// Open-model text edits are NEVER delegated to the host — they remain
/// component-owned.
public enum MonaExternalWorkspaceOperationKind: String, Sendable, Equatable {
    case create
    case rename
    case delete
}

/// An external workspace operation delegated to the host. Open-model mutation
/// is NEVER delegated (it stays component-owned).
public struct MonaExternalWorkspaceOperation {
    public let kind: MonaExternalWorkspaceOperationKind
    public let uri: MonaURI
    public init(kind: MonaExternalWorkspaceOperationKind, uri: MonaURI) {
        self.kind = kind; self.uri = uri
    }
}

/// The result of an applied external operation, plus an optional undo receipt.
public struct MonaWorkspaceOperationResult: Sendable, Equatable {
    public let applied: Bool
    public let undoReceipt: MonaWorkspaceUndoReceipt?
    public init(applied: Bool, undoReceipt: MonaWorkspaceUndoReceipt? = nil) {
        self.applied = applied; self.undoReceipt = undoReceipt
    }
}

/// An opaque undo receipt returned by the host for an applied operation.
public struct MonaWorkspaceUndoReceipt: Sendable, Equatable {
    public let token: String
    public init(token: String) { self.token = token }
}

/// Host-owned external resource operations plus prepared nonthrowing atomic
/// commit. Open-model mutation is NEVER delegated to the host.
///
/// Throwing: `applyExternalOperation`, `prepareAtomicExternalOperations`.
/// Nonthrowing: `undoExternalOperation` (returns Bool).
public protocol MonaWorkspaceEditHost: AnyObject {
    /// The immutable capabilities.
    var capabilities: MonaWorkspaceEditCapabilities { get }

    /// Applies a single external operation (THROWING). Returns the result and
    /// an optional undo receipt.
    func applyExternalOperation(
        _ operation: MonaExternalWorkspaceOperation,
        index: Int,
        transactionID: MonaWorkspaceTransactionIdentity
    ) async throws -> MonaWorkspaceOperationResult

    /// Undoes a previously applied operation using its receipt. Returns `true`
    /// if the undo was applied. Nonthrowing — the protocol gives no rollback
    /// guarantee; `false` means the undo could not be applied.
    func undoExternalOperation(receipt: MonaWorkspaceUndoReceipt) async -> Bool

    /// Prepares an atomic nonthrowing commit for a batch of operations
    /// (THROWING). A host may advertise transactional only when this makes
    /// `commit()` allocation-free with no externally reportable failure.
    func prepareAtomicExternalOperations(
        _ operations: [MonaExternalWorkspaceOperation],
        transactionID: MonaWorkspaceTransactionIdentity
    ) async throws -> MonaPreparedWorkspaceTransaction
}

/// A single-use prepared atomic workspace transaction.
///
/// Nonthrowing: `commit()` is synchronous + nonthrowing (callback-free);
/// `abort()` is async + idempotent. A host may advertise transactional only
/// when `prepareAtomicExternalOperations` makes `commit()` allocation-free
/// with no externally reportable failure.
public protocol MonaPreparedWorkspaceTransaction: AnyObject {
    /// The transaction identity.
    var identity: MonaWorkspaceTransactionIdentity { get }

    /// Commits the prepared operations. Synchronous, nonthrowing, and
    /// callback-free. Idempotent — a second commit is a no-op.
    func commit()

    /// Aborts the prepared transaction. Async, nonthrowing, idempotent — a
    /// second abort is a no-op. Tears down without firing a terminal.
    func abort() async
}

// MARK: - Group 4: command — MonaCommandHost

/// A command invocation delegated to the host.
public struct MonaCommandInvocation {
    public let id: String
    public let arguments: [MonaJSONValue]
    public init(id: String, arguments: [MonaJSONValue]) {
        self.id = id; self.arguments = arguments
    }
}

/// Host command execution. The component command registry executes first; only
/// an unhandled provider or LSP command reaches the host.
///
/// Throwing: `execute` CAN throw. Returns `nil` to signal unhandled.
public protocol MonaCommandHost: AnyObject {
    /// Executes `invocation`. `nil` = unhandled. Throws on failure.
    func execute(
        invocation: MonaCommandInvocation,
        cancellationToken: MonaCancellationToken
    ) async throws -> MonaJSONValue?
}

// MARK: - Group 5: logging — MonaLogSink

/// The severity of a log event.
public enum MonaLogSeverity: String, Sendable, Equatable, CaseIterable {
    case info
    case warn
    case error
}

/// A sanitized log event. Carries severity + message only — NO document text
/// and NO control-flow authority.
public struct MonaLogEvent: Sendable, Equatable {
    public let severity: MonaLogSeverity
    public let message: String
    public init(severity: MonaLogSeverity, message: String) {
        self.severity = severity; self.message = message
    }
}

/// Nonthrowing, nonblocking, non-reentrant telemetry. Logging CANNOT reenter
/// editor APIs, block the MainActor, contain document text, or change control
/// flow. When no sink is attached, logs are dropped (no implicit network/file
/// logging).
public protocol MonaLogSink: AnyObject {
    /// Records `event`. Nonthrowing — must never throw, block, or reenter.
    func record(_ event: MonaLogEvent)
}

// MARK: - Group 6: lsp-transport — MonaMessageTransport (reused) + MonaLSPTransportFactory

/// The ownership model a transport factory advertises.
public enum MonaLSPTransportOwnership: String, Sendable, Equatable, CaseIterable {
    /// The host owns the transport and can restart it.
    case ownedRestartable
    /// The transport is remote; the host reconnects on failure.
    case remoteReconnectable
    /// The transport is embedded; the host recreates it on failure.
    case embeddedRecreatable
}

/// A descriptor for an LSP session (the language and root URI).
public struct MonaLSPSessionDescriptor {
    public let languageId: String
    public let rootURI: MonaURI?
    public init(languageId: String, rootURI: MonaURI?) {
        self.languageId = languageId; self.rootURI = rootURI
    }
}

/// A factory for LSP message transports. The host supplies transport
/// lifecycle + ordered bytes; the component owns framing, JSON-RPC, and LSP.
///
/// Throwing: `makeTransport` CAN throw. The factory NEVER searches PATH,
/// launches a process, opens a socket, or downloads a server — a macOS
/// `Process` adapter exists only as EXPLICIT host authority (the AppKit
/// adapter reuses P06-T009's `MonaProcessMessageTransport`).
public protocol MonaLSPTransportFactory: AnyObject {
    /// The ownership model.
    var ownership: MonaLSPTransportOwnership { get }

    /// Creates a transport for `sessionDescriptor` at `epoch`. Throws on
    /// failure (e.g. an unauthorized executable). Returns a
    /// `MonaMessageTransport` (the byte-channel protocol from P06-T001).
    func makeTransport(
        sessionDescriptor: MonaLSPSessionDescriptor,
        epoch: UInt64
    ) async throws -> MonaMessageTransport
}

// MARK: - Group 7: multi-diff-data — MonaMultiDiffDataSource

/// A single multi-diff item: a stable ID, original/modified model URIs, a
/// label, a description, and immutable host metadata.
public struct MonaMultiDiffItem {
    public let id: String
    public let originalModelURI: MonaURI?
    public let modifiedModelURI: MonaURI?
    public let label: String
    public let description: String?
    public init(
        id: String,
        originalModelURI: MonaURI?,
        modifiedModelURI: MonaURI?,
        label: String,
        description: String?
    ) {
        self.id = id
        self.originalModelURI = originalModelURI
        self.modifiedModelURI = modifiedModelURI
        self.label = label
        self.description = description
    }
}

/// A synchronous change event: the new ordered snapshot, and whether a
/// duplicate-ID snapshot was rejected (the previous snapshot is preserved).
public struct MonaMultiDiffSnapshotChange {
    public let items: [MonaMultiDiffItem]
    public let rejectedDuplicateIDs: Bool
    public init(items: [MonaMultiDiffItem], rejectedDuplicateIDs: Bool) {
        self.items = items; self.rejectedDuplicateIDs = rejectedDuplicateIDs
    }
}

/// A multi-diff data source: stable item identity, ordered snapshots, and
/// synchronous MainActor change events.
///
/// Nonthrowing: `snapshot` is nonthrowing. Duplicate IDs reject the WHOLE new
/// snapshot (the previous snapshot is preserved); retained IDs preserve
/// collapse/active/scroll state.
public protocol MonaMultiDiffDataSource: AnyObject {
    /// The ordered item snapshot.
    var snapshot: [MonaMultiDiffItem] { get }

    /// The synchronous change event.
    var onDidChangeSnapshot: MonaEvent<MonaMultiDiffSnapshotChange> { get }
}
