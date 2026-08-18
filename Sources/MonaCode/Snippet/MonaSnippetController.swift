// MonaSnippetController.swift
//
// P06-T007 — Implement snippet variables, resolvers, sessions, and multi-cursor
// ordering.
//
// The snippet controller: inserts snippets through the input barrier
// (P04-T005), manages the active session, and replicates snippet insertion
// across 1/100/10000 cursors with stable ordering. This is the Swift
// counterpart of Monaco's `snippetController2.js`.
//
// The controller parses the template once, captures one shared time snapshot
// and one shared entropy sequence, resolves the snippet per cursor (per-cursor
// selection/clipboard/comment/cursor-index; shared model/workspace/time/random),
// and publishes the full multi-cursor edit batch through `MonaModelInputBarrier`
// in ONE transaction (all-or-none). Each cursor's edit carries the `.snippet`
// kind and that cursor's resolved text + tabstop offset pairs (relative to the
// cursor's inserted text).
//
// Clipboard spread: the controller splits the raw clipboard on CRLF/LF/CR,
// removes blank/whitespace lines, and distributes one line per cursor when the
// remaining count equals the cursor count; otherwise every cursor receives the
// entire string.
//
// Multi-cursor cursor identity: CURSOR_INDEX/CURSOR_NUMBER use the caller's
// original cursor index even though resolution runs in range-sorted order (the
// contract's `cursorIdentity` rule).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A single cursor target for snippet insertion: the insertion position and an
/// optional selection (for selection-based variable resolvers).
public struct MonaSnippetCursorTarget {

    /// The position at which to insert the snippet (a folded insertion).
    public let position: MonaPosition

    /// The editor selection active at this cursor (for SELECTION/TM_CURRENT_LINE/
    /// TM_CURRENT_WORD/CURSOR_INDEX/etc.). When `nil`, selection-based variables
    /// resolve to their miss/empty path.
    public let selection: MonaSelection?

    /// Creates a cursor target.
    public init(position: MonaPosition, selection: MonaSelection? = nil) {
        self.position = position
        self.selection = selection
    }
}

/// The shared configuration for a snippet insertion: the clipboard, workspace,
/// comment tokens, time snapshot, entropy sources, and final-tabstop flags.
/// One config is shared across all cursors of one insertion so the time
/// snapshot and entropy sequence are shared.
public struct MonaSnippetInsertionConfig {

    /// The raw pre-read clipboard string (spread across cursors by the controller).
    public let clipboard: String?

    /// The workspace name (S1 logical identifier).
    public let workspaceName: String?

    /// The workspace folder (S1 logical URI path).
    public let workspaceFolder: String?

    /// The line-comment token for the active language configuration.
    public let lineComment: String?

    /// The block-comment start token.
    public let blockCommentStart: String?

    /// The block-comment end token.
    public let blockCommentEnd: String?

    /// The ONE captured time snapshot. All time variables read this Date.
    public let time: Date

    /// The Gregorian calendar (with the E1 time zone applied).
    public let calendar: Calendar

    /// The E1 time zone.
    public let timeZone: TimeZone

    /// The shared random-Double source (RANDOM/RANDOM_HEX draw from this).
    public let randomSource: any MonaRandomDoubleSource

    /// The shared cryptographic random source (UUID draws from this).
    public let cryptoSource: any MonaCryptoRandomSource

    /// The Number::toString source.
    public let numberToString: MonaNumberToString

    /// When `true` and no `$0` exists, append a final `0` tab stop.
    public let enforceFinalTabstop: Bool

    /// When `true` and at least one placeholder exists and no `$0` exists,
    /// append a final `0` tab stop.
    public let insertFinalTabstop: Bool

    /// Creates an insertion config.
    public init(
        clipboard: String?,
        workspaceName: String?,
        workspaceFolder: String?,
        lineComment: String?,
        blockCommentStart: String?,
        blockCommentEnd: String?,
        time: Date,
        calendar: Calendar,
        timeZone: TimeZone,
        randomSource: any MonaRandomDoubleSource,
        cryptoSource: any MonaCryptoRandomSource,
        numberToString: MonaNumberToString,
        enforceFinalTabstop: Bool,
        insertFinalTabstop: Bool
    ) {
        self.clipboard = clipboard
        self.workspaceName = workspaceName
        self.workspaceFolder = workspaceFolder
        self.lineComment = lineComment
        self.blockCommentStart = blockCommentStart
        self.blockCommentEnd = blockCommentEnd
        self.time = time
        self.calendar = calendar
        self.timeZone = timeZone
        self.randomSource = randomSource
        self.cryptoSource = cryptoSource
        self.numberToString = numberToString
        self.enforceFinalTabstop = enforceFinalTabstop
        self.insertFinalTabstop = insertFinalTabstop
    }

    /// A default config with no clipboard/workspace/comments, the current time,
    /// the system random/crypto sources, and no final-tabstop enforcement.
    public static func defaults(
        time: Date = Date(),
        timeZone: TimeZone = TimeZone.current,
        randomSource: any MonaRandomDoubleSource = MonaSystemRandomDoubleSource(),
        cryptoSource: any MonaCryptoRandomSource = MonaSystemCryptoRandomSource()
    ) -> MonaSnippetInsertionConfig {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return MonaSnippetInsertionConfig(
            clipboard: nil,
            workspaceName: nil,
            workspaceFolder: nil,
            lineComment: nil,
            blockCommentStart: nil,
            blockCommentEnd: nil,
            time: time,
            calendar: cal,
            timeZone: timeZone,
            randomSource: randomSource,
            cryptoSource: cryptoSource,
            numberToString: MonaNumberToString(),
            enforceFinalTabstop: false,
            insertFinalTabstop: false
        )
    }
}

/// The snippet controller: inserts snippets through the input barrier and
/// manages the active session.
public final class MonaSnippetController {

    /// The model this controller inserts into.
    public let model: MonaCodeModel

    /// The input barrier (P04-T005) all snippet insertions pass through.
    public let barrier: MonaModelInputBarrier

    /// The active snippet session (the primary cursor's session), or `nil`
    /// when no snippet is active.
    public private(set) var activeSession: MonaSnippetSession?

    /// Creates a controller. When `barrier` is `nil`, the controller creates
    /// its own barrier wrapping `model`.
    public init(model: MonaCodeModel, barrier: MonaModelInputBarrier? = nil) {
        self.model = model
        if let b = barrier {
            self.barrier = b
        } else {
            self.barrier = MonaModelInputBarrier(model: model)
        }
    }

    // MARK: - Single-cursor insertion

    /// Inserts a snippet template at one cursor position through the input
    /// barrier. The snippet is parsed once and resolved against `config`; the
    /// resolved text + tabstops are published in one transaction.
    @discardableResult
    public func insertSnippet(
        template: String,
        at position: MonaPosition,
        selection: MonaSelection? = nil,
        config: MonaSnippetInsertionConfig
    ) -> MonaModelInputBarrierOutcome {
        let cursor = MonaSnippetCursorTarget(position: position, selection: selection)
        return insertSnippet(template: template, cursors: [cursor], config: config)
    }

    /// Convenience: single-cursor insertion with the default config.
    @discardableResult
    public func insertSnippet(
        template: String,
        at position: MonaPosition,
        config: MonaSnippetInsertionConfig = .defaults()
    ) -> MonaModelInputBarrierOutcome {
        return insertSnippet(template: template, at: position, selection: nil, config: config)
    }

    // MARK: - Multi-cursor insertion (1/100/10000)

    /// Inserts a snippet template at multiple cursor positions through the input
    /// barrier, replicating per cursor. The template is parsed once; one shared
    /// time snapshot and one shared entropy sequence are used across all cursors;
    /// each cursor's snippet is resolved in range-sorted order (with CURSOR_INDEX/
    /// CURSOR_NUMBER using the caller's original cursor index) and the full batch
    /// is published in ONE transaction (all-or-none).
    @discardableResult
    public func insertSnippet(
        template: String,
        cursors: [MonaSnippetCursorTarget],
        config: MonaSnippetInsertionConfig
    ) -> MonaModelInputBarrierOutcome {
        guard !cursors.isEmpty else {
            return .dropped(reason: "no cursors")
        }

        // 1. Parse the template once.
        let markers = MonaSnippetParser.parse(Array(template.utf16))

        // 2. Compute the clipboard spread.
        let spread = computeClipboardSpread(
            raw: config.clipboard, cursorCount: cursors.count
        )

        // 3. Copy cursors with their original index, stable-sort by range start
        //    (range order), process in range order, then emit edits at the
        //    original index. This is the contract's `selectionInsert` /
        //    `snippetEditArray` processing order.
        let indexed = cursors.enumerated().map { (i, c) -> (origIdx: Int, cursor: MonaSnippetCursorTarget) in
            return (i, c)
        }
        let rangeOrdered = indexed.sorted { a, b in
            let aPos = a.cursor.position
            let bPos = b.cursor.position
            return aPos < bPos
        }

        // 4. Resolve each cursor's snippet in range order, building the
        //    per-cursor resolved session + edit. Time and entropy are shared
        //    (one Date, one shared random/crypto source).
        var resolvedByOrigIdx: [Int: MonaSnippetResolvedSession] = [:]
        var edits: [MonaCursorInputEdit] = []
        edits.reserveCapacity(rangeOrdered.count)
        for entry in rangeOrdered {
            let origIdx = entry.origIdx
            let cursor = entry.cursor
            let clipboardLine = spread.applied ? spread.lines[origIdx] : nil
            let clipboardRaw = spread.applied ? nil : config.clipboard
            let context = MonaSnippetVariableContext(
                model: model,
                selection: cursor.selection,
                cursorIndex: origIdx,
                cursorCount: cursors.count,
                clipboardLine: clipboardLine,
                clipboardRaw: clipboardRaw,
                workspaceName: config.workspaceName,
                workspaceFolder: config.workspaceFolder,
                lineComment: config.lineComment,
                blockCommentStart: config.blockCommentStart,
                blockCommentEnd: config.blockCommentEnd,
                time: config.time,
                calendar: config.calendar,
                timeZone: config.timeZone,
                randomSource: config.randomSource,
                cryptoSource: config.cryptoSource,
                numberToString: config.numberToString
            )
            let resolved = MonaSnippetVariableResolver.resolve(
                markers: markers,
                context: context,
                enforceFinalTabstop: config.enforceFinalTabstop,
                insertFinalTabstop: config.insertFinalTabstop
            )
            resolvedByOrigIdx[origIdx] = resolved
            // Build the cursor's edit: folded range, resolved text, .snippet
            // kind, tabstop offset pairs relative to this cursor's text.
            let tabstops = resolved.placeholders.map { p in
                MonaSnippetTabstop(
                    index: p.index,
                    startOffset: p.startOffset,
                    endOffset: p.endOffset
                )
            }
            let range = MonaRange(
                startPosition: cursor.position, endPosition: cursor.position
            )
            edits.append(MonaCursorInputEdit(
                range: range,
                text: resolved.text,
                kind: .snippet,
                forceMoveMarkers: false,
                tabstops: tabstops
            ))
        }

        // 5. Build the multi-cursor plan. The plan's `resolvingConflicts`
        //    handles merge of adjacent/overlapping edits; the barrier commits
        //    all-or-none.
        let plan = MonaMultiCursorInputPlan(
            primary: edits[0],
            secondary: Array(edits.dropFirst())
        )

        // 6. Commit through the input barrier (all-or-none in one transaction).
        let outcome = barrier.commit(plan)

        // 7. Establish the active session for the primary cursor (cursor 0).
        if case .applied = outcome {
            if let primaryResolved = resolvedByOrigIdx[0] {
                activeSession = MonaSnippetSession(
                    resolved: primaryResolved, cursorIndex: 0
                )
            }
        }
        return outcome
    }

    // MARK: - Session commands

    /// Moves to the next placeholder (Tab). Returns `false` when there is no
    /// active session or it is already at the final tab stop.
    @discardableResult
    public func moveNextPlaceholder() -> Bool {
        guard let session = activeSession, session.isActive else { return false }
        if session.nestedSession?.isActive == true {
            return session.nestedSession!.moveNext()
        }
        return session.moveNext()
    }

    /// Moves to the previous placeholder (Shift-Tab). Returns `false` when there
    /// is no active session or it is at the first placeholder.
    @discardableResult
    public func movePrevPlaceholder() -> Bool {
        guard let session = activeSession, session.isActive else { return false }
        if session.nestedSession?.isActive == true {
            return session.nestedSession!.movePrev()
        }
        return session.movePrev()
    }

    /// Accepts the snippet (Enter): jumps to the final tab stop and
    /// deactivates the session.
    public func acceptSnippet() {
        activeSession?.accept()
        activeSession = nil
    }

    /// Cancels the snippet (Escape): deactivates the session.
    public func cancelSnippet() {
        activeSession?.cancel()
        activeSession = nil
    }

    // MARK: - Clipboard spread

    /// The result of a clipboard spread computation.
    private struct ClipboardSpread {
        /// `true` when the spread applied (line count == cursor count after
        /// dropping blank/whitespace lines).
        let applied: Bool
        /// The per-cursor lines, indexed by original cursor index. Only
        /// meaningful when `applied` is `true`.
        let lines: [Int: String]
    }

    /// Computes the clipboard spread: split the raw string on CRLF/LF/CR,
    /// remove blank/whitespace-only lines, and when the remaining count equals
    /// `cursorCount`, distribute one line per cursor (by original index). When
    /// the counts don't match, every cursor receives the entire raw string.
    private func computeClipboardSpread(
        raw: String?, cursorCount: Int
    ) -> ClipboardSpread {
        guard let raw = raw, !raw.isEmpty else {
            return ClipboardSpread(applied: false, lines: [:])
        }
        // Split on CRLF/LF/CR.
        var lines: [String] = []
        var current = ""
        var iter = raw.makeIterator()
        while let ch = iter.next() {
            if ch == "\r" {
                // CRLF or CR.
                lines.append(current)
                current = ""
                // Peek for a following LF.
                // (We can't peek with IteratorProtocol; handle LF on next loop.)
            } else if ch == "\n" {
                // LF (possibly following a CR that already flushed).
                // If the previous char was CR, current is "" from the CR flush;
                // appending "" would create a spurious empty line. To match
                // Monaco's split, treat CRLF as one break.
                if current.isEmpty && !lines.isEmpty && lines.last == "" {
                    // The CR already flushed an empty line for this break; skip.
                } else {
                    lines.append(current)
                    current = ""
                }
            } else {
                current.append(ch)
            }
        }
        lines.append(current)

        // Remove blank/whitespace-only lines.
        let nonBlank = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        if nonBlank.count == cursorCount {
            var map: [Int: String] = [:]
            for (i, line) in nonBlank.enumerated() {
                map[i] = line
            }
            return ClipboardSpread(applied: true, lines: map)
        }
        return ClipboardSpread(applied: false, lines: [:])
    }
}
