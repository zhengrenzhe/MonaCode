// MonaSnippetSession.swift
//
// P06-T007 — Implement snippet variables, resolvers, sessions, and multi-cursor
// ordering.
//
// The snippet session: placeholder navigation, nested sessions, merge, cancel,
// and undo. This is the Swift counterpart of Monaco's `snippetSession.js`
// (`SnippetSession` / `OneSnippet`).
//
// The session owns the resolved snippet (rendered text + placeholder offset
// table) for ONE cursor, tracks the current placeholder ordinal, and exposes
// the four session commands from the contract (`jumpToNextSnippetPlaceholder`,
// `jumpToPrevSnippetPlaceholder`, `leaveSnippet`, `acceptSnippet`).
//
// Placeholder order: numeric index order with index 0 final. Equal-index
// occurrences mirror and select together. `moveNext()` advances to the next
// distinct placeholder in walk order; `movePrev()` steps back. `accept()` jumps
// to the final (index 0) tab stop and deactivates. `cancel()` deactivates
// without moving.
//
// Nested sessions: a snippet inserted inside a placeholder stacks under the
// parent as `nestedSession`. Canceling the nested session restores the parent
// as the active session. `merge(with:)` merges a nested session's placeholders
// into the parent and consumes the nested session.
//
// The session holds no model reference and performs no mutation: it is a pure
// value carrier. The controller (P06-T007) drives model mutation through the
// input barrier (P04-T005); the session tracks navigation state only.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A snippet session: the resolved snippet for one cursor plus the placeholder
/// navigation state (current ordinal, active flag, nested session).
///
/// Create with `init(resolved:cursorIndex:)`. Navigate with `moveNext()` (Tab)
/// and `movePrev()` (Shift-Tab). Accept with `accept()` (Enter) or cancel with
/// `cancel()` (Escape). A nested snippet stacks under `nestedSession`; canceling
/// the nested session restores the parent; `merge(with:)` absorbs a nested
/// session's placeholders into the parent.
public final class MonaSnippetSession {

    /// The resolved snippet (rendered text + placeholders).
    public private(set) var resolved: MonaSnippetResolvedSession

    /// The original (unsorted) editor selection index for this cursor.
    public let cursorIndex: Int

    /// The current placeholder ordinal in `resolved.placeholders`. Navigation
    /// advances/retreats this index. `-1` means "before the first placeholder"
    /// (the session was just created).
    public private(set) var placeholderOrdinal: Int

    /// `true` while the session is active (not accepted, not canceled). The
    /// controller considers a session active until `accept()` or `cancel()`.
    public private(set) var isActive: Bool

    /// A nested snippet session (a snippet inserted inside a placeholder of
    /// this session). Canceling the nested session clears this property and
    /// restores the parent as the active session.
    public var nestedSession: MonaSnippetSession? {
        didSet {
            nestedSession?.owningSession = self
        }
    }

    /// The parent session that owns this session as `nestedSession` (weak, to
    /// break the retain cycle). When this session is canceled, it clears the
    /// parent's `nestedSession` reference so the parent is restored as the
    /// active session.
    public weak var owningSession: MonaSnippetSession?

    /// Creates a session for one cursor from its resolved snippet.
    public init(resolved: MonaSnippetResolvedSession, cursorIndex: Int = 0) {
        self.resolved = resolved
        self.cursorIndex = cursorIndex
        // Start at the first non-final placeholder (index 1+), or the final
        // tab stop if there are no non-final placeholders.
        self.placeholderOrdinal = Self.firstNavigableOrdinal(in: resolved.placeholders)
        self.isActive = !resolved.placeholders.isEmpty
    }

    /// The current placeholder, or `nil` when there are no placeholders or the
    /// session is inactive.
    public var currentPlaceholder: MonaSnippetResolvedPlaceholder? {
        guard placeholderOrdinal >= 0,
              placeholderOrdinal < resolved.placeholders.count else {
            return nil
        }
        return resolved.placeholders[placeholderOrdinal]
    }

    /// `true` when the current placeholder is the final tab stop (index 0).
    public var isAtFinalTabstop: Bool {
        return currentPlaceholder?.index == 0
    }

    /// Advances to the next placeholder group in walk order. Returns `false`
    /// when already at the final tab stop (no further placeholder to move to).
    ///
    /// Navigation order: distinct placeholder indices ascending, with `0`
    /// (final) last. Mirrors of the same index move together; Tab skips them
    /// and lands on the first occurrence of the next distinct index. From a
    /// non-final index with no strictly-greater index remaining, Tab moves to
    /// the final tab stop (`0`).
    @discardableResult
    public func moveNext() -> Bool {
        guard isActive else { return false }
        guard let current = currentPlaceholder else {
            if !resolved.placeholders.isEmpty {
                placeholderOrdinal = 0
                return true
            }
            return false
        }
        let order = distinctNavOrder()
        guard let pos = order.firstIndex(of: current.index) else { return false }
        guard pos + 1 < order.count else { return false }
        let nextIdx = order[pos + 1]
        if let ord = resolved.placeholders.firstIndex(where: { $0.index == nextIdx }) {
            placeholderOrdinal = ord
            return true
        }
        return false
    }

    /// Retreats to the previous placeholder group in walk order. Returns
    /// `false` when already at the first placeholder.
    ///
    /// Navigation order: distinct placeholder indices ascending, with `0`
    /// (final) last. From the final tab stop (`0`), Shift-Tab moves to the
    /// last occurrence of the previous distinct index (so forward-then-back
    /// returns to the same group).
    @discardableResult
    public func movePrev() -> Bool {
        guard isActive else { return false }
        guard let current = currentPlaceholder else { return false }
        let order = distinctNavOrder()
        guard let pos = order.firstIndex(of: current.index) else { return false }
        guard pos - 1 >= 0 else { return false }
        let prevIdx = order[pos - 1]
        if let ord = resolved.placeholders.lastIndex(where: { $0.index == prevIdx }) {
            placeholderOrdinal = ord
            return true
        }
        return false
    }

    /// Accepts the snippet: jumps to the final tab stop (index 0) and
    /// deactivates the session.
    public func accept() {
        if let finalOrd = resolved.placeholders.lastIndex(where: { $0.index == 0 }) {
            placeholderOrdinal = finalOrd
        }
        isActive = false
        // A nested session is consumed on accept.
        nestedSession?.accept()
        nestedSession = nil
    }

    /// Cancels (leaves) the snippet: deactivates the session without moving to
    /// the final tab stop. When this session is a nested session, the parent's
    /// `nestedSession` reference is cleared so the parent is restored as the
    /// active session.
    public func cancel() {
        isActive = false
        nestedSession?.cancel()
        nestedSession = nil
        owningSession?.nestedSession = nil
    }

    /// The distinct placeholder indices in navigation order: non-zero indices
    /// ascending, then `0` (final) last. Mirrors collapse to one group entry.
    private func distinctNavOrder() -> [Int] {
        var seen = Set<Int>()
        var order: [Int] = []
        for p in resolved.placeholders where !seen.contains(p.index) {
            seen.insert(p.index)
            order.append(p.index)
        }
        let nonZero = order.filter { $0 != 0 }.sorted()
        let hasZero = order.contains(0)
        return nonZero + (hasZero ? [0] : [])
    }

    /// Merges a nested session into this session, absorbing its placeholders
    /// into the parent and consuming the nested session.
    ///
    /// After merge, `nestedSession` is `nil`, this session remains active, and
    /// its `resolved.placeholders` now include the nested session's
    /// placeholders (appended in walk order).
    public func merge(with nested: MonaSnippetSession) {
        // Absorb the nested session's placeholders into this session's table.
        // The nested placeholders are offset relative to the nested snippet's
        // rendered text; after merge they become part of the parent's table.
        let offset = resolved.text.utf16.count
        var merged = resolved.placeholders
        for p in nested.resolved.placeholders {
            merged.append(
                MonaSnippetResolvedPlaceholder(
                    index: p.index,
                    startOffset: p.startOffset + offset,
                    endOffset: p.endOffset + offset,
                    value: p.value
                )
            )
        }
        resolved = MonaSnippetResolvedSession(
            text: resolved.text + nested.resolved.text,
            placeholders: merged
        )
        nestedSession = nil
    }

    /// Returns the first navigable ordinal: the first placeholder whose index
    /// is greater than zero (the first non-final tab stop), or the final tab
    /// stop if there are no non-final placeholders.
    private static func firstNavigableOrdinal(
        in placeholders: [MonaSnippetResolvedPlaceholder]
    ) -> Int {
        for (i, p) in placeholders.enumerated() where p.index > 0 {
            return i
        }
        // No non-final placeholder: the final tab stop, if any.
        if let zeroOrd = placeholders.lastIndex(where: { $0.index == 0 }) {
            return zeroOrd
        }
        return -1
    }
}
