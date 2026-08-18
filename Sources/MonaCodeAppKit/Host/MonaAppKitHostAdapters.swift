// MonaAppKitHostAdapters.swift
//
// P07-T005 — Implement seven host groups and ten concrete host types.
//
// Concrete macOS host adapters — the AppKit-side implementations of the Core
// host contracts (`Sources/MonaCode/Host/MonaHostContracts.swift`). A host
// app conforms to the Core protocols to plug into MonaCode; this file
// provides the reference macOS conformances:
//
//   - `MonaAppKitLogSink` — a nonblocking `MonaLogSink` (lock-guarded ring
//     buffer; no document text; no control-flow authority).
//   - `MonaAppKitLSPTransportFactory` — a `MonaLSPTransportFactory` that
//     reuses P06-T009's `MonaProcessMessageTransport` for an EXPLICIT,
//     host-authorized absolute executable (no PATH lookup, no implicit
//     process/socket authority).
//   - `MonaAppKitWorkspaceEditHost` — a `MonaWorkspaceEditHost` that
//     DECLINES external resource operations (the no-implicit-workspace-
//     authority default); a host that wishes to apply external operations
//     must subclass / replace it with EXPLICIT authority.
//
// Explicit authority rule (frozen): NONE of these adapters grant implicit
// URL, file, network, logging, transport, or workspace authority. The LSP
// factory rejects a relative executable (no PATH lookup); the workspace host
// declines all external operations; the log sink records sanitized events
// only (no document text, no network/file emission).
//
// `MonaCodeAppKit` may `import AppKit`, `import Foundation`, and
// `import MonaCode`.

import AppKit
import Foundation
import MonaCode

// MARK: - MonaAppKitLogSink

/// A concrete macOS `MonaLogSink` — a nonblocking, non-reentrant, lock-guarded
/// ring buffer of sanitized log events.
///
/// `record(_:)` is nonthrowing and nonblocking: it appends the event under a
/// lock and returns. It carries NO document text and NO control-flow
/// authority — it never reenters editor APIs, never blocks the MainActor, and
/// never changes control flow. When no sink is attached to the environment,
/// logs are dropped (no implicit network/file logging).
public final class MonaAppKitLogSink: MonaLogSink, @unchecked Sendable {

    private let lock = NSLock()
    /// The recorded events (ordered). Exposed for host-side draining / tests.
    /// Capped to prevent unbounded growth in long-running hosts.
    private var events: [MonaLogEvent] = []
    private let capacity: Int

    /// Creates the sink. `capacity` caps the retained event count (default
    /// 1024); older events are dropped FIFO when the cap is reached.
    public init(capacity: Int = 1024) {
        self.capacity = max(1, capacity)
    }

    public func record(_ event: MonaLogEvent) {
        // Nonthrowing, nonblocking, non-reentrant: append under the lock and
        // return. No editor reentry, no network/file emission, no control-flow
        // authority.
        lock.lock(); defer { lock.unlock() }
        events.append(event)
        if events.count > capacity {
            events.removeFirst(events.count - capacity)
        }
    }

    /// The recorded events (a snapshot copy). Ordered, severity-preserving.
    public var recordedEvents: [MonaLogEvent] {
        lock.lock(); defer { lock.unlock() }
        return events
    }
}

// MARK: - MonaAppKitLSPTransportFactory

/// A concrete macOS `MonaLSPTransportFactory` that reuses P06-T009's
/// `MonaProcessMessageTransport` for an EXPLICIT, host-authorized absolute
/// executable.
///
/// The factory performs NO PATH lookup: a relative or empty `executable` is
/// rejected (the construction of `MonaProcessMessageTransport` throws
/// `.unauthorizedExecutable`). The environment is required verbatim (never
/// inherited from the host process). This grants NO implicit process, socket,
/// or download authority — a host that wishes to launch a server must do so
/// with EXPLICIT authority at construction time.
///
/// `ownership` is `.ownedRestartable` — the host owns the transport lifecycle
/// and can restart it (each `makeTransport` call constructs a fresh process).
public final class MonaAppKitLSPTransportFactory: MonaLSPTransportFactory, @unchecked Sendable {

    /// The explicit, absolute, host-authorized executable path.
    public let executable: String
    /// The exact environment for the process (never inherited).
    public let environment: [String: String]
    /// The absolute working directory for the process.
    public let workingDirectory: String

    public var ownership: MonaLSPTransportOwnership { .ownedRestartable }

    /// Creates the factory with an EXPLICIT executable, environment, and
    /// working directory. The executable + working directory must be absolute
    /// (verified lazily at `makeTransport` time — a relative path throws).
    public init(
        executable: String,
        environment: [String: String],
        workingDirectory: String
    ) {
        self.executable = executable
        self.environment = environment
        self.workingDirectory = workingDirectory
    }

    /// Constructs a `MonaMessageTransport` backed by a launched process
    /// (reusing P06-T009's `MonaProcessMessageTransport`).
    ///
    /// - Throws: `MonaProcessTransportError.unauthorizedExecutable` if the
    ///   executable is empty or relative (no PATH lookup); `.unauthorizedWorkingDirectory`
    ///   if the working directory is empty or relative; `.launchFailed` if
    ///   `Process.run()` fails.
    public func makeTransport(
        sessionDescriptor: MonaLSPSessionDescriptor,
        epoch: UInt64
    ) async throws -> MonaMessageTransport {
        // Reuse P06-T009 — explicit-authorization: the executable + working
        // directory must be absolute; the environment is never inherited. NO
        // PATH lookup, NO implicit process/socket/download authority.
        let transport = try MonaProcessMessageTransport(
            executable: executable,
            environment: environment,
            workingDirectory: workingDirectory
        )
        return transport
    }
}

// MARK: - MonaAppKitWorkspaceEditHost

/// A concrete macOS `MonaWorkspaceEditHost` that DECLINES external resource
/// operations — the no-implicit-workspace-authority default.
///
/// `capabilities.appliesResourceOperations == false`. `applyExternalOperation`
/// and `prepareAtomicExternalOperations` throw
/// `.workspaceAuthorityDeclined`; `undoExternalOperation` returns `false`.
/// Open-model mutation is NEVER delegated to the host (it remains component-
/// owned). A host that wishes to apply external create/rename/delete
/// operations must provide a different conformer with EXPLICIT authority.
public final class MonaAppKitWorkspaceEditHost: MonaWorkspaceEditHost, @unchecked Sendable {

    public init() {}

    public var capabilities: MonaWorkspaceEditCapabilities {
        // Declines all external resource operations — no implicit workspace
        // authority.
        return MonaWorkspaceEditCapabilities(
            appliesResourceOperations: false,
            supportsTransactional: false,
            supportsUndoReceipts: false
        )
    }

    public func applyExternalOperation(
        _ operation: MonaExternalWorkspaceOperation,
        index: Int,
        transactionID: MonaWorkspaceTransactionIdentity
    ) async throws -> MonaWorkspaceOperationResult {
        // The host has not opted into external resource operations.
        throw MonaHostContractError.workspaceAuthorityDeclined
    }

    public func undoExternalOperation(receipt: MonaWorkspaceUndoReceipt) async -> Bool {
        // No external operations were applied → no undo is possible.
        return false
    }

    public func prepareAtomicExternalOperations(
        _ operations: [MonaExternalWorkspaceOperation],
        transactionID: MonaWorkspaceTransactionIdentity
    ) async throws -> MonaPreparedWorkspaceTransaction {
        // The host has not opted into transactional external operations.
        throw MonaHostContractError.workspaceAuthorityDeclined
    }
}
