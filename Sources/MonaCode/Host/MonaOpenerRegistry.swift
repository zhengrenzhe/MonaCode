// MonaOpenerRegistry.swift
//
// P07-T005 — Implement seven host groups and ten concrete host types.
//
// The opener-registry mechanism: two DISTINCT last-registered-first (LIFO)
// stacks — one for link openers (`MonaLinkOpenerRegistry`) and one for
// code-editor openers (`MonaCodeEditorOpenerRegistry`). They are the Swift
// counterpart of Monaco's `registerLinkOpener` / `registerEditorOpener`
// (monaco-editor 0.56.0, `standaloneEditor.js`).
//
// Load-bearing contract invariants (H1-R2 `openerObservableContract`):
//
//   - DISTINCT: link and code-editor openers remain in SEPARATE registries.
//     A link opener is never consulted for a code-editor open, and vice versa.
//   - LIFO: each registry traverses last-registered-first (the most recently
//     registered opener wins).
//   - Disposal: `register` returns a `MonaDisposable`; disposing it removes
//     EXACTLY that registration. Disposal is idempotent.
//   - Continuation: `false` continues to the next older registration; `true`
//     stops traversal; a thrown result is the operation failure (rejection)
//     and does NOT invoke an older opener.
//   - Fallback: when no opener handles a request (or no openers are
//     registered), the result is unhandled (`false`) — NO implicit
//     `NSWorkspace.open`, URL, file, or network fallback is added.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - MonaLinkOpenerRegistry

/// The link-opener registry — a DISTINCT last-registered-first (LIFO) stack of
/// `MonaLinkOpener` instances. Traversal invokes openers last-registered-
/// first; `false` continues, `true` stops, a throw is the operation failure
/// (no fallback to older openers).
public final class MonaLinkOpenerRegistry: @unchecked Sendable {

    private let lock = NSLock()
    /// The LIFO stack of registrations. `unshift` semantics from Monaco's
    /// `openerService.js`: a newly registered opener is appended and traversal
    /// walks the array in reverse (last-registered-first).
    private var registrations: [Registration] = []
    private var _disposed = false

    /// A single registration: the opener + a unique registration token (for
    /// exact-removal disposal).
    private final class Registration {
        let opener: MonaLinkOpener
        let token: UUID
        init(opener: MonaLinkOpener, token: UUID) {
            self.opener = opener; self.token = token
        }
    }

    public init() {}

    /// The number of registered openers.
    public var count: Int {
        lock.lock(); defer { lock.unlock() }
        return registrations.count
    }

    /// Registers `opener`. Returns a `MonaDisposable` that removes EXACTLY
    /// this registration when disposed (idempotent). Disposal after the
    /// registry is torn down is a no-op.
    @discardableResult
    public func register(_ opener: MonaLinkOpener) -> MonaDisposable {
        let token = UUID()
        lock.lock()
        if !_disposed {
            registrations.append(Registration(opener: opener, token: token))
        }
        lock.unlock()
        let registry = self
        return MonaDisposableImpl {
            registry.remove(token)
        }
    }

    /// Invokes the registered openers last-registered-first for `uri`.
    /// - Returns: `true` if an opener handled the request (stops traversal);
    ///   `false` if no opener handled it (unhandled fallback).
    /// - Throws: the rejection of an opener that threw (does NOT invoke an
    ///   older opener — no fallback on rejection).
    public func invoke(_ uri: MonaURI) throws -> Bool {
        // Snapshot the openers last-registered-first under the lock, then
        // invoke outside the lock (an opener must not deadlock the registry).
        let snapshot: [MonaLinkOpener] = {
            lock.lock(); defer { lock.unlock() }
            return registrations.reversed().map { $0.opener }
        }()
        for opener in snapshot {
            let handled = try opener.openLink(uri)
            if handled { return true }   // true stops traversal
            // false → continue to next older registration
        }
        return false  // unhandled — no implicit NSWorkspace/URL/file fallback
    }

    /// Tears down the registry (drops all registrations). Idempotent.
    public func dispose() {
        lock.lock()
        _disposed = true
        registrations.removeAll()
        lock.unlock()
    }

    /// Removes the registration with `token` (exact-removal disposal).
    private func remove(_ token: UUID) {
        lock.lock()
        registrations.removeAll { $0.token == token }
        lock.unlock()
    }
}

// MARK: - MonaCodeEditorOpenerRegistry

/// The code-editor-opener registry — a DISTINCT last-registered-first (LIFO)
/// stack of `MonaCodeEditorOpener` instances. Traversal invokes openers last-
/// registered-first; `false` continues, `true` stops, a throw is the
/// operation failure (no fallback to older openers).
public final class MonaCodeEditorOpenerRegistry: @unchecked Sendable {

    private let lock = NSLock()
    private var registrations: [Registration] = []
    private var _disposed = false

    private final class Registration {
        let opener: MonaCodeEditorOpener
        let token: UUID
        init(opener: MonaCodeEditorOpener, token: UUID) {
            self.opener = opener; self.token = token
        }
    }

    public init() {}

    public var count: Int {
        lock.lock(); defer { lock.unlock() }
        return registrations.count
    }

    @discardableResult
    public func register(_ opener: MonaCodeEditorOpener) -> MonaDisposable {
        let token = UUID()
        lock.lock()
        if !_disposed {
            registrations.append(Registration(opener: opener, token: token))
        }
        lock.unlock()
        let registry = self
        return MonaDisposableImpl {
            registry.remove(token)
        }
    }

    /// Invokes the registered openers last-registered-first for `uri` +
    /// `target`.
    /// - Returns: `true` if handled (stops); `false` if unhandled.
    /// - Throws: the rejection of an opener that threw (no fallback).
    public func invoke(_ uri: MonaURI, target: MonaCodeEditorOpenerTarget) throws -> Bool {
        let snapshot: [MonaCodeEditorOpener] = {
            lock.lock(); defer { lock.unlock() }
            return registrations.reversed().map { $0.opener }
        }()
        for opener in snapshot {
            let handled = try opener.openCodeEditor(uri, target: target)
            if handled { return true }
        }
        return false  // unhandled — no implicit editor-open fallback
    }

    /// Tears down the registry (drops all registrations). Idempotent.
    public func dispose() {
        lock.lock()
        _disposed = true
        registrations.removeAll()
        lock.unlock()
    }

    private func remove(_ token: UUID) {
        lock.lock()
        registrations.removeAll { $0.token == token }
        lock.unlock()
    }
}
