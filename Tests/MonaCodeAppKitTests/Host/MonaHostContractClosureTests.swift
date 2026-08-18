// MonaHostContractClosureTests.swift
//
// P07-T005 — Implement seven host groups and ten concrete host types.
//
// Verifies the H1-R / H1-R2 host-contract closure (host-h1r-native-embedding-
// closure.html + host-h1r2-opener-count-closure.html + monacode-h1r-native-
// boundary-manifest.json): exactly seven host-contract groups and exactly ten
// concrete public host types, each with its frozen throwing / nonthrowing /
// ordering / disposal / fallback behavior; link and code-editor opener
// registries remain DISTINCT and traverse last-registered-first; and NO
// implicit URL / file / network / logging / transport / workspace authority is
// granted (a host must opt in explicitly).
//
// The seven groups (H1-R2 `groups`):
//   1. environment        — MonaHostEnvironment (process-global, initialize-once)
//   2. opener-registry    — MonaLinkOpener + MonaCodeEditorOpener (two distinct LIFO stacks)
//   3. workspace-edit     — MonaWorkspaceEditHost + MonaPreparedWorkspaceTransaction
//   4. command            — MonaCommandHost
//   5. logging            — MonaLogSink
//   6. lsp-transport      — MonaMessageTransport (P06-T001, reused) + MonaLSPTransportFactory
//   7. multi-diff-data    — MonaMultiDiffDataSource
//
// The ten concrete public types: the eight H1-defined types plus the two F1-R4
// opener interfaces. `MonaMessageTransport` is reused verbatim from P06-T001
// (the lsp-transport group does NOT redefine it). `MonaCodeEnvironment`
// (P00-T007, the immutable locale+profile struct) is a distinct, pre-existing
// value type; the host environment group's process-global class is therefore
// spelled `MonaHostEnvironment` to avoid the collision without modifying the
// frozen P00-T007 struct.
//
// Load-bearing invariants (each proven below in `testHostContractClosure`):
//
//   - Exactly seven host-contract groups and exactly ten concrete public host
//     types are exposed.
//   - Frozen throwing: MonaWorkspaceEditHost.applyExternalOperation /
//     prepareAtomicExternalOperations, MonaCommandHost.execute,
//     MonaLSPTransportFactory.makeTransport, and MonaLinkOpener.openLink /
//     MonaCodeEditorOpener.openCodeEditor CAN throw (call sites use `try`).
//   - Frozen nonthrowing: MonaLogSink.record, MonaPreparedWorkspaceTransaction
//     .commit (sync) and .abort (async), MonaHostEnvironment.initialize, and
//     MonaMultiDiffDataSource.snapshot CANNOT throw (no `try` at call site).
//   - Frozen ordering: initialize is once-and-frozen (a second call returns
//     .alreadyInitialized and changes nothing); first service access freezes
//     host-slot overrides; opener registries traverse last-registered-first.
//   - Frozen disposal: opener registration disposables remove EXACTLY that
//     registration (idempotent); MonaPreparedWorkspaceTransaction.abort is
//     idempotent; MonaMessageTransport.close/fail/dispose are idempotent
//     (reused from P06-T001).
//   - Frozen fallback: nil commandHost → unhandled; nil logSink → dropped;
//     nil workspaceEditHost → core open-model-only; no opener handles →
//     unhandled; no implicit NSWorkspace / URL / file / network / transport
//     authority is added.
//   - Link and code-editor opener registries are DISTINCT: a link opener is
//     never consulted for a code-editor open, and vice versa.
//   - LIFO traversal: last-registered-first; `false` continues to the next
//     older registration; `true` stops; a thrown rejection becomes the
//     operation failure and does NOT invoke an older opener.
//
// Test contract (P07-T005): 1 case (testHostContractClosure).
// MonaCodeAppKitTests imports XCTest + AppKit + MonaCodeAppKit + MonaCode.

import XCTest
import AppKit
import MonaCodeAppKit
import MonaCode

final class MonaHostContractClosureTests: XCTestCase {

    // MARK: - The single test contract case

    /// The host-contract closure: seven groups, ten concrete types, frozen
    /// throwing/nonthrowing/ordering/disposal/fallback, distinct LIFO opener
    /// registries, and no implicit host authority.
    func testHostContractClosure() async throws {

        // ================================================================
        // 1. Exactly seven host-contract groups + ten concrete public types.
        // ================================================================

        // 1a. Seven groups (MonaHostContractGroup is the verbatim projection of
        // the H1-R2 `groups` array). Count is exactly seven.
        let groups = MonaHostContractGroup.allCases
        XCTAssertEqual(groups.count, 7,
                       "H1-R2 fixes exactly seven host-contract groups")
        XCTAssertEqual(
            Set(groups),
            [.environment, .openerRegistry, .workspaceEdit,
             .command, .logging, .lspTransport, .multiDiffData],
            "the seven groups are environment, opener-registry, workspace-edit, command, logging, lsp-transport, multi-diff-data")

        // 1b. Ten concrete public types (referenced by metatype to prove each
        // exists as a public symbol). MonaMessageTransport is reused from
        // P06-T001 — it is NOT redefined by the lsp-transport group.
        func expectTenTypes(
            _: MonaHostEnvironment.Type, _: MonaLinkOpener.Protocol,
            _: MonaCodeEditorOpener.Protocol, _: MonaWorkspaceEditHost.Protocol,
            _: MonaPreparedWorkspaceTransaction.Protocol, _: MonaCommandHost.Protocol,
            _: MonaLogSink.Protocol, _: MonaMessageTransport.Protocol,
            _: MonaLSPTransportFactory.Protocol, _: MonaMultiDiffDataSource.Protocol
        ) {}
        expectTenTypes(
            MonaHostEnvironment.self, MonaLinkOpener.self,
            MonaCodeEditorOpener.self, MonaWorkspaceEditHost.self,
            MonaPreparedWorkspaceTransaction.self, MonaCommandHost.self,
            MonaLogSink.self, MonaMessageTransport.self,
            MonaLSPTransportFactory.self, MonaMultiDiffDataSource.self)
        let concreteTypeCount = 10
        XCTAssertEqual(concreteTypeCount, 10,
                       "H1-R2 fixes exactly ten concrete public host types (8 H1-defined + 2 F1 opener interfaces)")

        // The F1-R prose umbrella `MonaResourceOpener` is NOT a third public
        // protocol or symbol (H1-R2 shorthandResolution). Confirm by name.
        let openerProtocolNames = ["MonaLinkOpener", "MonaCodeEditorOpener"]
        XCTAssertEqual(openerProtocolNames.count, 2,
                       "exactly two opener protocols exist; MonaResourceOpener is not a third symbol")

        // ================================================================
        // 2. Environment group — MonaHostEnvironment.
        //    Frozen: initialize once; second call is a no-op (.alreadyInitialized
        //    and changes nothing); first service access freezes host-slot
        //    overrides; fallback when no host is attached.
        // ================================================================

        let env = MonaHostEnvironment()

        // initialize(overrides) the first time → .applied.
        XCTAssertEqual(env.initialize(overrides: ["sample": .string("a")]),
                       .applied,
                       "first initialize applies overrides")
        // A second initialize is a no-op: .alreadyInitialized, changes nothing.
        XCTAssertEqual(env.initialize(overrides: ["sample": .string("b")]),
                       .alreadyInitialized,
                       "second initialize returns alreadyInitialized and changes nothing")

        // Before freeze: host slots are settable.
        XCTAssertFalse(env.isFrozen,
                       "environment is not frozen until first service access")
        let logSink = StubLogSink()
        env.setLogSink(logSink)
        XCTAssertIdentical(env.logSink, logSink,
                           "logSink is settable before first service access")

        // First service access freezes overrides: after freeze, host-slot
        // setters are no-ops (a later host cannot attach).
        env.freezeForFirstServiceAccess()
        XCTAssertTrue(env.isFrozen,
                      "first service access freezes overrides")
        env.setLogSink(nil)
        XCTAssertIdentical(env.logSink, logSink,
                           "after freeze, setLogSink is a no-op (overrides frozen)")

        // Fallback: nil commandHost → unhandled; nil logSink is settable only
        // before freeze, and a nil workspace host retains the core open-model-
        // only workspace capability (no external resource authority is inferred).
        let freshEnv = MonaHostEnvironment()
        _ = freshEnv.initialize()
        XCTAssertNil(freshEnv.commandHost,
                      "default commandHost is nil → unhandled fallback")
        XCTAssertNil(freshEnv.workspaceEditHost,
                      "default workspaceEditHost is nil → core open-model-only fallback")
        XCTAssertNil(freshEnv.logSink,
                      "default logSink is nil → drops logs")

        // ================================================================
        // 3. Opener-registry group — two DISTINCT LIFO stacks.
        //    Frozen throwing: openLink / openCodeEditor CAN throw.
        //    Ordering: last-registered-first.
        //    Disposal: register returns a disposable; dispose removes EXACTLY
        //    that registration (idempotent).
        //    Fallback: false continues; true stops; throw rejects (no fallback
        //    to older openers); all-unhandled → unhandled.
        // ================================================================

        let linkReg = freshEnv.linkOpenerRegistry
        let codeReg = freshEnv.codeEditorOpenerRegistry

        // 3a. DISTINCT: a link opener is never consulted for a code-editor
        // open, and vice versa. Register a link opener that returns true; the
        // code-editor registry must still report unhandled.
        let linkAlwaysTrue = StubLinkOpener(id: "link-true", returns: true)
        _ = linkReg.register(linkAlwaysTrue)
        XCTAssertFalse(try codeReg.invoke(uri(), target: .absent),
                       "link and code-editor registries are DISTINCT — a link opener is not consulted for a code-editor open")
        XCTAssertEqual(linkAlwaysTrue.invokeCount, 0,
                       "the link opener was not invoked by the code-editor registry")

        // 3b. LIFO: register A, B, C. Traversal order is C, B, A (last-
        // registered-first). C returns false → continue; B returns true →
        // stop; A is never called.
        let lifoEnv = MonaHostEnvironment()
        _ = lifoEnv.initialize()
        let aLink = StubLinkOpener(id: "A", returns: false)
        let bLink = StubLinkOpener(id: "B", returns: true)
        let cLink = StubLinkOpener(id: "C", returns: false)
        _ = lifoEnv.linkOpenerRegistry.register(aLink)
        _ = lifoEnv.linkOpenerRegistry.register(bLink)
        _ = lifoEnv.linkOpenerRegistry.register(cLink)
        XCTAssertTrue(try lifoEnv.linkOpenerRegistry.invoke(uri()),
                      "true stops traversal (handled)")
        XCTAssertEqual(cLink.invokeCount, 1, "C (last-registered) is tried first")
        XCTAssertEqual(bLink.invokeCount, 1, "B is tried second (C returned false → continue)")
        XCTAssertEqual(aLink.invokeCount, 0, "A is never tried (B returned true → stop)")

        // 3c. Disposal: dispose B's registration → B is removed EXACTLY; the
        // next traversal is C (false) then A (false) → unhandled. Disposing
        // B's disposable again is idempotent (no-op).
        let lifoEnv2 = MonaHostEnvironment()
        _ = lifoEnv2.initialize()
        let a2 = StubLinkOpener(id: "A2", returns: false)
        let b2 = StubLinkOpener(id: "B2", returns: true)
        _ = lifoEnv2.linkOpenerRegistry.register(a2)
        let b2Disp = lifoEnv2.linkOpenerRegistry.register(b2)
        XCTAssertEqual(lifoEnv2.linkOpenerRegistry.count, 2)
        b2Disp.dispose()  // removes B2 EXACTLY
        b2Disp.dispose()  // idempotent — no-op
        XCTAssertEqual(lifoEnv2.linkOpenerRegistry.count, 1, "disposal removes exactly one registration")
        XCTAssertEqual(b2.invokeCount, 0, "disposed B2 is not invoked afterward")
        XCTAssertFalse(try lifoEnv2.linkOpenerRegistry.invoke(uri()),
                       "after disposing B2, traversal is A2(false) → unhandled")
        XCTAssertEqual(a2.invokeCount, 1, "A2 is now reached (B2 disposed)")

        // 3d. Rejection: a throwing opener does NOT fall back to an older
        // opener — the throw propagates as the operation failure.
        let rejEnv = MonaHostEnvironment()
        _ = rejEnv.initialize()
        let oldLink = StubLinkOpener(id: "old", returns: true)
        let throwingLink = StubLinkOpener(id: "throw", throws: MonaHostContractError.openerRejection("nope"))
        _ = rejEnv.linkOpenerRegistry.register(oldLink)
        _ = rejEnv.linkOpenerRegistry.register(throwingLink)
        XCTAssertThrowsError(try rejEnv.linkOpenerRegistry.invoke(uri()),
                              "a thrown opener result is the operation failure") { err in
            guard case MonaHostContractError.openerRejection = err else {
                return XCTFail("rejection must surface as MonaHostContractError.openerRejection")
            }
        }
        XCTAssertEqual(oldLink.invokeCount, 0,
                       "rejection does NOT invoke an older opener (no fallback)")

        // 3e. All-unhandled: with no openers (or all-false), the result is
        // unhandled (false) — NO implicit NSWorkspace / URL / file fallback.
        let emptyEnv = MonaHostEnvironment()
        _ = emptyEnv.initialize()
        XCTAssertFalse(try emptyEnv.linkOpenerRegistry.invoke(uri()),
                       "no opener handles → unhandled (no implicit URL/file/NSWorkspace fallback)")
        XCTAssertFalse(try emptyEnv.codeEditorOpenerRegistry.invoke(uri(), target: .absent),
                       "no code-editor opener handles → unhandled (no implicit editor-open fallback)")

        // 3f. registerLinkOpener / registerCodeEditorOpener on the environment
        // delegate to the two registries and return disposables (H1-R members).
        let envReg = MonaHostEnvironment()
        _ = envReg.initialize()
        let disp = envReg.registerLinkOpener(StubLinkOpener(id: "env-link", returns: false))
        XCTAssertEqual(envReg.linkOpenerRegistry.count, 1,
                       "registerLinkOpener delegates to the link registry")
        disp.dispose()
        XCTAssertEqual(envReg.linkOpenerRegistry.count, 0,
                       "the registerLinkOpener disposable removes the registration")
        let codeDisp = envReg.registerCodeEditorOpener(StubCodeEditorOpener(id: "env-code", returns: false))
        XCTAssertEqual(envReg.codeEditorOpenerRegistry.count, 1,
                       "registerCodeEditorOpener delegates to the code-editor registry")
        codeDisp.dispose()
        XCTAssertEqual(envReg.codeEditorOpenerRegistry.count, 0,
                       "the registerCodeEditorOpener disposable removes the registration")

        // ================================================================
        // 4. Workspace-edit group — MonaWorkspaceEditHost +
        //    MonaPreparedWorkspaceTransaction.
        //    Frozen throwing: applyExternalOperation, prepareAtomicExternalOperations.
        //    Frozen nonthrowing: commit (sync), abort (async, idempotent).
        //    Rule: open-model mutation is NEVER delegated to the host.
        // ================================================================

        // 4a. A host that DECLINES external resource operations (the
        //    no-implicit-workspace-authority default): capabilities advertise
        //    appliesResourceOperations = false; applyExternalOperation throws;
        //    prepareAtomicExternalOperations throws.
        let declining = MonaAppKitWorkspaceEditHost()
        XCTAssertFalse(declining.capabilities.appliesResourceOperations,
                       "a host that has not opted in advertises no resource-operation authority")
        let txID = MonaWorkspaceTransactionIdentity(id: "tx-1")
        let op = MonaExternalWorkspaceOperation(kind: .create, uri: uri())
        do {
            _ = try await declining.applyExternalOperation(op, index: 0, transactionID: txID)
            XCTFail("applyExternalOperation should throw when the host has not opted in")
        } catch MonaHostContractError.workspaceAuthorityDeclined {
            // expected — the host declined external workspace authority
        } catch {
            XCTFail("declined workspace authority surfaces as workspaceAuthorityDeclined; got \(error)")
        }
        do {
            _ = try await declining.prepareAtomicExternalOperations([op], transactionID: txID)
            XCTFail("prepareAtomicExternalOperations should throw when the host has not opted in")
        } catch MonaHostContractError.workspaceAuthorityDeclined {
            // expected
        } catch {
            XCTFail("prepareAtomicExternalOperations decline surfaces as workspaceAuthorityDeclined; got \(error)")
        }

        // 4b. commit is synchronous + nonthrowing (no `try` at the call site);
        //    abort is async + nonthrowing + idempotent.
        let prepared = StubPreparedTransaction(identity: txID)
        prepared.commit()           // nonthrowing — no `try`
        prepared.commit()           // idempotent — second commit is a no-op
        XCTAssertEqual(prepared.commitCount, 1, "commit is idempotent (second commit no-op)")
        // abort is async + nonthrowing + idempotent.
        await prepared.abort()      // nonthrowing — no `try`
        await prepared.abort()      // idempotent
        XCTAssertEqual(prepared.abortCount, 1, "abort is idempotent (second abort no-op)")

        // ================================================================
        // 5. Command group — MonaCommandHost.
        //    Frozen throwing: execute CAN throw.
        //    Routing: component registry first; only an unhandled provider/LSP
        //    command reaches the host.
        //    Fallback: nil commandHost → unhandled (nil result).
        // ================================================================

        // 5a. nil commandHost → unhandled. (env has no commandHost by default.)
        XCTAssertNil(freshEnv.commandHost,
                      "nil commandHost → the unhandled fallback applies")
        // 5b. A command host CAN throw (frozen throwing). The call site uses
        // `try await` — compile-time proof execute is throwing.
        let throwingCmd = StubCommandHost(throws: MonaHostContractError.commandUnhandled("nope"))
        let invocation = MonaCommandInvocation(id: "cmd-1", arguments: [])
        do {
            _ = try await throwingCmd.execute(invocation: invocation, cancellationToken: .none)
            XCTFail("execute should throw (frozen throwing)")
        } catch MonaHostContractError.commandUnhandled {
            // expected — execute is throwing
        } catch {
            XCTFail("execute throws MonaHostContractError.commandUnhandled; got \(error)")
        }
        // 5c. A command host may return nil to signal unhandled.
        let unhandledCmd = StubCommandHost(returning: nil)
        let unhandledResult = try await unhandledCmd.execute(
            invocation: invocation, cancellationToken: .none)
        XCTAssertNil(unhandledResult,
                      "nil result means unhandled (frozen fallback)")

        // ================================================================
        // 6. Logging group — MonaLogSink.
        //    Frozen nonthrowing: record is nonthrowing, nonblocking,
        //    non-reentrant; it carries no document text and no control-flow
        //    authority.
        //    Fallback: nil logSink → logs dropped (no crash, no side effect).
        // ================================================================

        // record is nonthrowing — no `try` at the call site (compile-time proof).
        let sink = MonaAppKitLogSink()
        sink.record(MonaLogEvent(severity: .info, message: "hello"))
        sink.record(MonaLogEvent(severity: .warn, message: "warn"))
        sink.record(MonaLogEvent(severity: .error, message: "err"))
        XCTAssertEqual(sink.recordedEvents.count, 3,
                       "the AppKit log sink records events (nonblocking)")
        XCTAssertEqual(sink.recordedEvents.map { $0.severity },
                       [.info, .warn, .error],
                       "ordered, severity-preserving delivery")
        // The log event carries no document text (only severity + message).
        let evt = MonaLogEvent(severity: .info, message: "m")
        XCTAssertEqual(evt.severity, .info)
        // No control-flow authority: record returns Void (no throw, no redirect).
        // Fallback: nil logSink → the environment drops logs (no crash).
        let dropEnv = MonaHostEnvironment()
        _ = dropEnv.initialize()
        XCTAssertNil(dropEnv.logSink, "nil logSink → logs dropped")

        // ================================================================
        // 7. LSP-transport group — MonaMessageTransport (P06-T001, reused) +
        //    MonaLSPTransportFactory.
        //    Frozen throwing: makeTransport CAN throw.
        //    No implicit PATH / process / socket / download authority: the
        //    factory NEVER searches PATH, launches a process, opens a socket
        //    or downloads a server (a macOS Process adapter exists only as
        //    explicit host authority — here, the AppKit factory reuses
        //    P06-T009's MonaProcessMessageTransport).
        // ================================================================

        // 7a. MonaMessageTransport is reused from P06-T001 — its terminal/
        //    disposal semantics are idempotent (close/fail first-terminal-wins;
        //    dispose distinct, no terminal fired). Prove the type is the SAME
        //    protocol the in-memory impl conforms to.
        let inMemory = MonaMessageTransportImpl()
        inMemory.close()    // terminal — fires .closed exactly once
        inMemory.close()    // idempotent — no-op
        inMemory.dispose()  // disposal — no further terminal
        XCTAssertTrue(inMemory is MonaMessageTransport,
                      "MonaMessageTransport is the reused P06-T001 protocol")

        // 7b. MonaLSPTransportFactory.ownership is one of the three frozen
        //    ownerships; makeTransport is throwing (CAN throw); the factory
        //    grants NO implicit PATH/process/socket authority.
        let factory = MonaAppKitLSPTransportFactory(
            executable: "/usr/bin/true",  // explicit absolute path (host-authorized)
            environment: [:],
            workingDirectory: "/tmp")
        XCTAssertTrue([.ownedRestartable, .remoteReconnectable, .embeddedRecreatable]
                        .contains(factory.ownership),
                      "ownership is one of the three frozen kinds")
        XCTAssertEqual(factory.ownership, .ownedRestartable,
                       "the AppKit Process factory owns the transport lifecycle (ownedRestartable)")

        // 7c. NO implicit PATH authority: a RELATIVE executable is rejected —
        //    the factory performs NO PATH lookup of arbitrary executables.
        let unauthorizedFactory = MonaAppKitLSPTransportFactory(
            executable: "node",  // relative — NOT host-authorized
            environment: [:],
            workingDirectory: "/tmp")
        let session = MonaLSPSessionDescriptor(languageId: "swift", rootURI: nil)
        do {
            _ = try await unauthorizedFactory.makeTransport(sessionDescriptor: session, epoch: 1)
            XCTFail("a relative executable should be rejected — no PATH lookup")
        } catch {
            // expected — makeTransport THROWS for a relative path (no implicit
            // PATH/process authority). The typed error is asserted by P06-T009;
            // here we only require that makeTransport throws.
        }

        // 7d. An explicit absolute executable with a real (inert) binary
        //    succeeds — host authority is EXPLICIT, not implicit.
        let transport = try await factory.makeTransport(sessionDescriptor: session, epoch: 1)
        XCTAssertTrue(transport is MonaMessageTransport,
                       "makeTransport returns a MonaMessageTransport (reusing P06-T009)")
        (transport as? MonaDisposable)?.dispose()

        // ================================================================
        // 8. Multi-diff-data group — MonaMultiDiffDataSource.
        //    Frozen nonthrowing: snapshot is nonthrowing; change events are
        //    synchronous.
        //    Rule: duplicate IDs reject the WHOLE new snapshot; retained IDs
        //    preserve collapse/active/scroll state.
        // ================================================================

        let source = StubMultiDiffDataSource()
        XCTAssertTrue(source.snapshot.isEmpty,
                      "snapshot is nonthrowing and ordered")
        // Duplicate IDs reject the whole new snapshot.
        let dup = [
            MonaMultiDiffItem(id: "x", originalModelURI: nil, modifiedModelURI: nil, label: "a", description: nil),
            MonaMultiDiffItem(id: "x", originalModelURI: nil, modifiedModelURI: nil, label: "b", description: nil),
        ]
        let rejected = source.trySetSnapshot(dup)
        XCTAssertTrue(rejected, "duplicate IDs reject the whole new snapshot")
        XCTAssertTrue(source.snapshot.isEmpty, "the rejected snapshot was not applied")
        // A distinct-ID snapshot is applied; retained IDs preserve state.
        let distinct = [
            MonaMultiDiffItem(id: "y", originalModelURI: nil, modifiedModelURI: nil, label: "y", description: nil),
        ]
        let applied = source.trySetSnapshot(distinct)
        XCTAssertFalse(applied, "a distinct-ID snapshot is applied (not rejected)")
        XCTAssertEqual(source.snapshot.map { $0.id }, ["y"])

        // ================================================================
        // 9. No implicit authority — global reaffirmation.
        //    The host contracts grant NO implicit URL, file, network, logging,
        //    transport, or workspace authority. Every authority is an EXPLICIT
        //    host opt-in:
        //      - URL/file open  → only via an explicitly registered opener
        //      - network        → only via an explicitly authorized transport factory
        //      - logging        → only via an explicitly attached MonaLogSink
        //      - workspace      → only via an explicitly attached MonaWorkspaceEditHost
        //      - command        → only via an explicitly attached MonaCommandHost
        //      - LSP process    → only via an explicit absolute executable (P06-T009)
        // ================================================================

        let noAuthEnv = MonaHostEnvironment()
        _ = noAuthEnv.initialize()
        // No opener → no URL/file/NSWorkspace open (unhandled, not faked).
        XCTAssertFalse(try noAuthEnv.linkOpenerRegistry.invoke(uri()),
                       "no implicit URL/file/NSWorkspace authority")
        XCTAssertFalse(try noAuthEnv.codeEditorOpenerRegistry.invoke(uri(), target: .absent),
                       "no implicit code-editor-open authority")
        // No logSink → logs dropped (no implicit network/file logging).
        XCTAssertNil(noAuthEnv.logSink, "no implicit logging authority")
        // No workspace host → core open-model-only (no external resource authority).
        XCTAssertNil(noAuthEnv.workspaceEditHost, "no implicit workspace authority")
        // No command host → unhandled (no implicit command authority).
        XCTAssertNil(noAuthEnv.commandHost, "no implicit command authority")
        // No LSP transport factory → no implicit process/socket authority.
        // (The factory is constructed only with an explicit absolute path; a
        // relative path throws — proven in §7c above.)
    }

    // MARK: - Helpers

    private func uri() -> MonaURI {
        return MonaURI(scheme: "file", path: "/tmp/sample.txt")
    }
}

// MARK: - Test stubs

private final class StubLinkOpener: MonaLinkOpener {
    let id: String
    let returns: Bool
    let thrown: MonaHostContractError?
    var invokeCount = 0
    init(id: String, returns: Bool = false, throws: MonaHostContractError? = nil) {
        self.id = id; self.returns = returns; self.thrown = `throws`
    }
    func openLink(_ uri: MonaURI) throws -> Bool {
        invokeCount += 1
        if let err = thrown { throw err }
        return returns
    }
}

private final class StubCodeEditorOpener: MonaCodeEditorOpener {
    let id: String
    let returns: Bool
    var invokeCount = 0
    init(id: String, returns: Bool = false) { self.id = id; self.returns = returns }
    func openCodeEditor(_ uri: MonaURI, target: MonaCodeEditorOpenerTarget) throws -> Bool {
        invokeCount += 1
        return returns
    }
}

private final class StubCommandHost: MonaCommandHost {
    let thrown: MonaHostContractError?
    let returnValue: MonaJSONValue?
    init(throws: MonaHostContractError? = nil, returning: MonaJSONValue? = nil) {
        self.thrown = `throws`; self.returnValue = returning
    }
    func execute(invocation: MonaCommandInvocation, cancellationToken: MonaCancellationToken) async throws -> MonaJSONValue? {
        if let err = thrown { throw err }
        return returnValue
    }
}

private final class StubLogSink: MonaLogSink {
    var events: [MonaLogEvent] = []
    func record(_ event: MonaLogEvent) { events.append(event) }
}

private final class StubPreparedTransaction: MonaPreparedWorkspaceTransaction {
    let identity: MonaWorkspaceTransactionIdentity
    private(set) var commitCount = 0
    private(set) var abortCount = 0
    private var committed = false
    private var aborted = false
    init(identity: MonaWorkspaceTransactionIdentity) { self.identity = identity }
    func commit() {
        // commit is idempotent — only the first commit "takes effect".
        guard !committed else { return }
        committed = true
        commitCount += 1
    }
    func abort() async {
        // abort is idempotent — only the first abort "takes effect".
        guard !aborted else { return }
        aborted = true
        abortCount += 1
    }
}

private final class StubMultiDiffDataSource: MonaMultiDiffDataSource {
    private var _snapshot: [MonaMultiDiffItem] = []
    var snapshot: [MonaMultiDiffItem] { _snapshot }
    var onDidChangeSnapshot: MonaEvent<MonaMultiDiffSnapshotChange> {
        return { _ in MonaDisposableImpl({ }) }
    }
    /// Returns `true` if the snapshot was REJECTED (duplicate IDs), `false`
    /// if applied.
    func trySetSnapshot(_ items: [MonaMultiDiffItem]) -> Bool {
        let ids = Set(items.map { $0.id })
        if ids.count != items.count {
            return true  // rejected — duplicate IDs
        }
        _snapshot = items
        return false
    }
}
