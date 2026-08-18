// MonaSnippetVariableResolver.swift
//
// P06-T007 — Implement snippet variables, resolvers, sessions, and multi-cursor
// ordering.
//
// The 39 snippet variable resolvers + the depth-first resolution walker. This is
// the Swift counterpart of Monaco's `snippetVariables.js`
// (`ModelBasedVariableResolver`, `ClipboardBasedVariableResolver`,
// `SelectionBasedVariableResolver`, `CommentBasedVariableResolver`,
// `TimeBasedVariableResolver`, `WorkspaceBasedVariableResolver`,
// `RandomBasedVariableResolver`).
//
// The resolver contract (from the F1-R3 snippet engine manifest):
//   - 39 known variable identifiers across 7 groups (time 16, selection 8,
//     clipboard 1, model 6, comments 3, workspace 2, random 3).
//   - Resolver order: Model, Clipboard, Selection, Comment, Time, Workspace,
//     Random. First-defined wins.
//   - Time variables: one Date captured at construction; numeric fields use
//     local Gregorian components with fixed zero padding; day/month names use
//     N1 (English Gregorian) identities; offset emits signed HH:MM; timezone
//     name = the E1 identifier.
//   - Clipboard: spreads across cursors (split CRLF/LF/CR, drop blank/whitespace
//     lines, distribute when remaining count == cursor count; otherwise every
//     cursor receives the entire string).
//   - Selection: SELECTION/TM_SELECTED_TEXT read the selected range; TM_CURRENT_LINE
//     uses the active position's line; TM_CURRENT_WORD uses the model word query;
//     TM_LINE_INDEX/TM_LINE_NUMBER preserve their 0/1-based definitions;
//     CURSOR_INDEX/CURSOR_NUMBER use the original (unsorted) editor selection index.
//   - Model: filename/path values use the pinned MonaURI path contract; no
//     filesystem access. TM_FILENAME_BASE strips the final extension only when
//     its dot index is greater than zero.
//   - Comments: the retained language-configuration line/block comment tokens.
//   - Workspace: the S1 synthetic standalone workspace service (logical URI values,
//     no filesystem access).
//   - Random: RANDOM/RANDOM_HEX/UUID draw from the E1 process-global sources, in
//     depth-first parser walk order, with shared entropy (one advancing sequence).
//
// Depth-first resolution: the walker traverses the parsed marker tree in
// depth-first parser order (T006), resolving each `.variable` as it is
// encountered. Time reads the one captured Date; RANDOM/RANDOM_HEX/UUID draw
// from the shared source sequence in walk order. The output is the rendered
// text plus the placeholder offset table (UTF-16 offsets into the rendered
// text).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - Resolution context

/// The bundle of inputs a snippet variable resolver reads. Carries the shared
/// per-session/per-edit-array values (model, workspace, time snapshot, entropy
/// sources) plus the per-cursor values (selection, original cursor index,
/// per-cursor clipboard line).
///
/// The controller constructs one context per cursor, sharing the same `time`,
/// `randomSource`, and `cryptoSource` instances across all cursors so that
/// time reads one snapshot and random/UUID draws advance one common sequence.
public struct MonaSnippetVariableContext {

    /// The model the snippet is being inserted into (supplies URI path + word
    /// query). `nil` in unit-test contexts that don't touch the model.
    public let model: MonaCodeModel?

    /// The editor selection active when the snippet was inserted (the caret
    /// position and any selected range). `nil` when there is no selection.
    public let selection: MonaSelection?

    /// The ORIGINAL (unsorted) editor selection index for this cursor, used by
    /// CURSOR_INDEX (0-based) and CURSOR_NUMBER (1-based). This is the cursor's
    /// identity in the caller's edit array, NOT its range-sorted position.
    public let cursorIndex: Int

    /// The total cursor count for the edit array (used by clipboard spread).
    public let cursorCount: Int

    /// The per-cursor clipboard line, pre-spread by the controller. When the
    /// clipboard spread applied (line count == cursor count), this is this
    /// cursor's assigned line; otherwise `nil`.
    public let clipboardLine: String?

    /// The raw pre-read clipboard string. Used when the spread did not apply
    /// (every cursor receives the entire string) or when there is a single
    /// cursor. `nil` when there is no clipboard.
    public let clipboardRaw: String?

    /// The workspace name (S1 logical identifier).
    public let workspaceName: String?

    /// The workspace folder (S1 logical URI path).
    public let workspaceFolder: String?

    /// The line-comment token for the active language configuration.
    public let lineComment: String?

    /// The block-comment start token for the active language configuration.
    public let blockCommentStart: String?

    /// The block-comment end token for the active language configuration.
    public let blockCommentEnd: String?

    /// The ONE captured time snapshot. All time variables read this Date.
    public let time: Date

    /// The Gregorian calendar (with the E1 time zone applied).
    public let calendar: Calendar

    /// The E1 time zone identifier (used by CURRENT_TIMEZONE_NAME and offset).
    public let timeZone: TimeZone

    /// The shared random-Double source. RANDOM/RANDOM_HEX draw from this in
    /// depth-first walk order; one advancing sequence across the whole edit
    /// array.
    public let randomSource: any MonaRandomDoubleSource

    /// The shared cryptographic random source. UUID draws from this.
    public let cryptoSource: any MonaCryptoRandomSource

    /// The Number::toString source (radix10 for RANDOM, radix16 for RANDOM_HEX).
    public let numberToString: MonaNumberToString

    /// Creates a resolution context.
    public init(
        model: MonaCodeModel?,
        selection: MonaSelection?,
        cursorIndex: Int,
        cursorCount: Int,
        clipboardLine: String?,
        clipboardRaw: String?,
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
        numberToString: MonaNumberToString
    ) {
        self.model = model
        self.selection = selection
        self.cursorIndex = cursorIndex
        self.cursorCount = cursorCount
        self.clipboardLine = clipboardLine
        self.clipboardRaw = clipboardRaw
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
    }
}

// MARK: - Resolved session

/// A placeholder resolved into the rendered text: its tab-stop index plus the
/// UTF-16 offset pair `[startOffset, endOffset)` into the rendered text and the
/// default value the placeholder contributes.
public struct MonaSnippetResolvedPlaceholder: Equatable, Sendable {

    /// The tab-stop ordinal. `0` is the final tab stop.
    public let index: Int

    /// The inclusive start offset (UTF-16 code units) into the rendered text.
    public let startOffset: Int

    /// The exclusive end offset (UTF-16 code units) into the rendered text.
    public let endOffset: Int

    /// The default value the placeholder contributes (its rendered children or
    /// the first choice option).
    public let value: String

    /// Creates a resolved placeholder.
    public init(index: Int, startOffset: Int, endOffset: Int, value: String) {
        self.index = index
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.value = value
    }
}

/// A resolved snippet session: the rendered text plus the placeholder offset
/// table (UTF-16 offsets into `text`), in depth-first parser walk order.
public struct MonaSnippetResolvedSession: Equatable, Sendable {

    /// The rendered text (variables resolved, transforms applied).
    public let text: String

    /// The placeholders, in depth-first walk order.
    public let placeholders: [MonaSnippetResolvedPlaceholder]

    /// Creates a resolved session.
    public init(text: String, placeholders: [MonaSnippetResolvedPlaceholder]) {
        self.text = text
        self.placeholders = placeholders
    }
}

// MARK: - Resolver

/// The 39 snippet variable resolvers + the depth-first resolution walker.
public enum MonaSnippetVariableResolver {

    /// The 39 known snippet variable identifiers, in the contract's group order
    /// (time 16, selection 8, clipboard 1, model 6, comments 3, workspace 2,
    /// random 3).
    public static let variableIdentifiers: [String] = [
        // time (16)
        "CURRENT_YEAR", "CURRENT_YEAR_SHORT", "CURRENT_MONTH", "CURRENT_DATE",
        "CURRENT_HOUR", "CURRENT_MINUTE", "CURRENT_SECOND", "CURRENT_MILLISECOND",
        "CURRENT_DAY_NAME", "CURRENT_DAY_NAME_SHORT", "CURRENT_MONTH_NAME",
        "CURRENT_MONTH_NAME_SHORT", "CURRENT_SECONDS_UNIX",
        "CURRENT_MILLISECONDS_UNIX", "CURRENT_TIMEZONE_OFFSET",
        "CURRENT_TIMEZONE_NAME",
        // selection (8)
        "SELECTION", "TM_SELECTED_TEXT", "TM_CURRENT_LINE", "TM_CURRENT_WORD",
        "TM_LINE_INDEX", "TM_LINE_NUMBER", "CURSOR_INDEX", "CURSOR_NUMBER",
        // clipboard (1)
        "CLIPBOARD",
        // model (6)
        "TM_FILENAME", "TM_FILENAME_BASE", "TM_DIRECTORY", "TM_DIRECTORY_BASE",
        "TM_FILEPATH", "RELATIVE_FILEPATH",
        // comments (3)
        "BLOCK_COMMENT_START", "BLOCK_COMMENT_END", "LINE_COMMENT",
        // workspace (2)
        "WORKSPACE_NAME", "WORKSPACE_FOLDER",
        // random (3)
        "RANDOM", "RANDOM_HEX", "UUID",
    ]

    /// The N1 (English Gregorian) day names, indexed by `Calendar.weekday`
    /// (1 = Sunday).
    private static let dayNames = [
        "Sunday", "Monday", "Tuesday", "Wednesday",
        "Thursday", "Friday", "Saturday",
    ]
    private static let dayNamesShort = [
        "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat",
    ]

    /// The N1 (English Gregorian) month names, indexed by month number (1 = January).
    private static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]
    private static let monthNamesShort = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]

    /// Resolves a single variable identifier against `context`, returning the
    /// resolved string, or `nil` when the variable is unknown or the required
    /// input is absent (a resolver miss — the variable renders its default
    /// children or empty).
    ///
    /// Resolver order (first-defined wins): Model, Clipboard, Selection,
    /// Comment, Time, Workspace, Random. Each of the 39 identifiers belongs to
    /// exactly one group, so the dispatch is by name.
    public static func resolve(
        name: String, context: MonaSnippetVariableContext
    ) -> String? {
        switch name {
        // -- Model (6) --
        case "TM_FILENAME": return modelFilename(context)
        case "TM_FILENAME_BASE": return modelFilenameBase(context)
        case "TM_DIRECTORY": return modelDirectory(context)
        case "TM_DIRECTORY_BASE": return modelDirectoryBase(context)
        case "TM_FILEPATH": return modelFilepath(context)
        case "RELATIVE_FILEPATH": return modelRelativeFilepath(context)
        // -- Clipboard (1) --
        case "CLIPBOARD": return context.clipboardLine ?? context.clipboardRaw
        // -- Selection (8) --
        case "SELECTION", "TM_SELECTED_TEXT": return selectionText(context)
        case "TM_CURRENT_LINE": return currentLine(context)
        case "TM_CURRENT_WORD": return currentWord(context)
        case "TM_LINE_INDEX": return lineIndex(context)
        case "TM_LINE_NUMBER": return lineNumber(context)
        case "CURSOR_INDEX": return String(context.cursorIndex)
        case "CURSOR_NUMBER": return String(context.cursorIndex + 1)
        // -- Comments (3) --
        case "BLOCK_COMMENT_START": return context.blockCommentStart
        case "BLOCK_COMMENT_END": return context.blockCommentEnd
        case "LINE_COMMENT": return context.lineComment
        // -- Time (16) --
        case "CURRENT_YEAR": return zeroPad(timeComponent(.year, context), width: 4)
        case "CURRENT_YEAR_SHORT": return zeroPad(timeComponent(.year, context) % 100, width: 2)
        case "CURRENT_MONTH": return zeroPad(timeComponent(.month, context), width: 2)
        case "CURRENT_DATE": return zeroPad(timeComponent(.day, context), width: 2)
        case "CURRENT_HOUR": return zeroPad(timeComponent(.hour, context), width: 2)
        case "CURRENT_MINUTE": return zeroPad(timeComponent(.minute, context), width: 2)
        case "CURRENT_SECOND": return zeroPad(timeComponent(.second, context), width: 2)
        case "CURRENT_MILLISECOND": return zeroPad(milliseconds(context), width: 3)
        case "CURRENT_DAY_NAME": return dayName(context, short: false)
        case "CURRENT_DAY_NAME_SHORT": return dayName(context, short: true)
        case "CURRENT_MONTH_NAME": return monthName(context, short: false)
        case "CURRENT_MONTH_NAME_SHORT": return monthName(context, short: true)
        case "CURRENT_SECONDS_UNIX": return String(Int(context.time.timeIntervalSince1970))
        case "CURRENT_MILLISECONDS_UNIX": return String(Int(context.time.timeIntervalSince1970 * 1000))
        case "CURRENT_TIMEZONE_OFFSET": return timezoneOffset(context)
        case "CURRENT_TIMEZONE_NAME": return context.timeZone.identifier
        // -- Workspace (2) --
        case "WORKSPACE_NAME": return context.workspaceName
        case "WORKSPACE_FOLDER": return context.workspaceFolder
        // -- Random (3) --
        case "RANDOM": return context.numberToString.radix10(context.randomSource.nextDouble())
        case "RANDOM_HEX": return context.numberToString.radix16(context.randomSource.nextDouble())
        case "UUID": return context.cryptoSource.makeUUIDv4()
        default: return nil
        }
    }

    // MARK: - Model resolvers

    private static func modelFilename(_ c: MonaSnippetVariableContext) -> String? {
        guard let path = c.model?.uri.path, !path.isEmpty else { return nil }
        return lastPathSegment(path)
    }

    private static func modelFilenameBase(_ c: MonaSnippetVariableContext) -> String? {
        guard let name = modelFilename(c) else { return nil }
        // Strip the final extension only when its dot index is greater than zero.
        // ".gitignore" → dot at index 0 → keep full name.
        guard let dotIndex = name.lastIndex(of: "."),
              dotIndex != name.startIndex else {
            return name
        }
        return String(name[..<dotIndex])
    }

    private static func modelDirectory(_ c: MonaSnippetVariableContext) -> String? {
        guard let path = c.model?.uri.path, !path.isEmpty else { return nil }
        // Directory = path up to (not including) the last separator.
        guard let sep = path.lastIndex(of: "/") else { return "" }
        if sep == path.startIndex {
            return "/"  // root: "/file" → directory "/"
        }
        return String(path[..<sep])
    }

    private static func modelDirectoryBase(_ c: MonaSnippetVariableContext) -> String? {
        guard let dir = modelDirectory(c) else { return nil }
        return lastPathSegment(dir)
    }

    private static func modelFilepath(_ c: MonaSnippetVariableContext) -> String? {
        guard let path = c.model?.uri.path, !path.isEmpty else { return nil }
        return path
    }

    private static func modelRelativeFilepath(_ c: MonaSnippetVariableContext) -> String? {
        // The standalone model has no workspace to relativize against; the
        // relative path is the logical URI path (no filesystem access).
        return modelFilepath(c)
    }

    /// Returns the last non-empty path segment of `path` (the part after the
    /// last `/`). For a path ending in `/`, walks back to the previous segment.
    private static func lastPathSegment(_ path: String) -> String {
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        return parts.last.map(String.init) ?? path
    }

    // MARK: - Selection resolvers

    private static func selectionText(_ c: MonaSnippetVariableContext) -> String? {
        guard let sel = c.selection, let model = c.model else { return nil }
        let range = MonaRange(startPosition: sel.startPosition, endPosition: sel.endPosition)
        if range.isFolded { return "" }
        return model.getValueInRange(range)
    }

    private static func currentLine(_ c: MonaSnippetVariableContext) -> String? {
        guard let sel = c.selection, let model = c.model else { return nil }
        return model.getLineContent(sel.activePosition.line)
    }

    private static func currentWord(_ c: MonaSnippetVariableContext) -> String? {
        guard let sel = c.selection, let model = c.model else { return nil }
        let position = sel.activePosition
        // Use the model's word query first (Phase 02 implements the real query).
        if let wordRange = model.getWordAtPosition(position) {
            return model.getValueInRange(wordRange)
        }
        // Fix-forward: the Phase 02 word query is currently stubbed (returns
        // nil). Provide a minimal alphanumeric word-detection fallback so the
        // variable resolves. When Phase 02 implements the real query, the
        // branch above is taken and this fallback is unused.
        return wordAtPositionFallback(model: model, position: position)
    }

    /// Minimal word detection: the alphanumeric run (`[A-Za-z0-9_]`)
    /// containing `position` in the line's text. Returns `nil` when the
    /// position is on a non-word character or out of range.
    private static func wordAtPositionFallback(
        model: MonaCodeModel, position: MonaPosition
    ) -> String? {
        let line = model.getLineContent(position.line)
        guard !line.isEmpty else { return nil }
        let units = Array(line.utf16)
        let col = position.column - 1  // 0-based
        guard col >= 0, col < units.count else { return nil }
        guard isWordChar(units[col]) else { return nil }
        var start = col
        while start > 0, isWordChar(units[start - 1]) { start -= 1 }
        var end = col
        while end < units.count, isWordChar(units[end]) { end += 1 }
        return String(decoding: Array(units[start..<end]), as: UTF16.self)
    }

    /// `true` for `[A-Za-z0-9_]`.
    private static func isWordChar(_ c: UInt16) -> Bool {
        if c >= 0x41 && c <= 0x5A { return true }  // A-Z
        if c >= 0x61 && c <= 0x7A { return true }  // a-z
        if c >= 0x30 && c <= 0x39 { return true }  // 0-9
        if c == 0x5F { return true }                // _
        return false
    }

    private static func lineIndex(_ c: MonaSnippetVariableContext) -> String? {
        guard let sel = c.selection else { return nil }
        return String(sel.activePosition.line - 1)  // 0-based
    }

    private static func lineNumber(_ c: MonaSnippetVariableContext) -> String? {
        guard let sel = c.selection else { return nil }
        return String(sel.activePosition.line)  // 1-based
    }

    // MARK: - Time resolvers

    private static func timeComponent(
        _ component: Calendar.Component, _ c: MonaSnippetVariableContext
    ) -> Int {
        return c.calendar.component(component, from: c.time)
    }

    private static func milliseconds(_ c: MonaSnippetVariableContext) -> Int {
        // Use the calendar's nanosecond component, divided to milliseconds.
        let ns = c.calendar.component(.nanosecond, from: c.time)
        return ns / 1_000_000
    }

    private static func dayName(_ c: MonaSnippetVariableContext, short: Bool) -> String {
        let weekday = c.calendar.component(.weekday, from: c.time)
        let idx = weekday - 1  // weekday is 1-based (1 = Sunday)
        guard idx >= 0, idx < dayNames.count else { return "" }
        return short ? dayNamesShort[idx] : dayNames[idx]
    }

    private static func monthName(_ c: MonaSnippetVariableContext, short: Bool) -> String {
        let month = c.calendar.component(.month, from: c.time)
        let idx = month - 1  // month is 1-based (1 = January)
        guard idx >= 0, idx < monthNames.count else { return "" }
        return short ? monthNamesShort[idx] : monthNames[idx]
    }

    private static func timezoneOffset(_ c: MonaSnippetVariableContext) -> String {
        let seconds = c.timeZone.secondsFromGMT(for: c.time)
        let totalMinutes = seconds / 60
        let sign = totalMinutes >= 0 ? "+" : "-"
        let absMin = abs(totalMinutes)
        let hours = absMin / 60
        let mins = absMin % 60
        return String(format: "%@%02d:%02d", sign, hours, mins)
    }

    /// Zero-pads `value` to `width` digits.
    private static func zeroPad(_ value: Int, width: Int) -> String {
        var s = String(value)
        while s.count < width { s = "0" + s }
        return s
    }

    // MARK: - Depth-first resolution walker

    /// Resolves `markers` (a parsed snippet tree) against `context`, producing
    /// the rendered text plus the placeholder offset table (UTF-16 offsets into
    /// the rendered text), in depth-first parser walk order.
    ///
    /// Time reads the one captured `context.time`; RANDOM/RANDOM_HEX/UUID draw
    /// from the shared `context.randomSource` / `context.cryptoSource` in walk
    /// order. A bare `$n` tab stop mirrors a prior placeholder of the same index
    /// (or renders empty). When `enforceFinalTabstop` (or `insertFinalTabstop`
    /// with at least one existing placeholder) is set and no `$0` exists, a
    /// final `0` tab stop is appended at the end of the rendered text.
    public static func resolve(
        markers: [MonaSnippetMarker],
        context: MonaSnippetVariableContext,
        enforceFinalTabstop: Bool = false,
        insertFinalTabstop: Bool = false
    ) -> MonaSnippetResolvedSession {
        var walker = _Walker(context: context)
        for marker in markers {
            walker.walk(marker)
        }
        // Final tabstop enforcement.
        let hasZero = walker.placeholders.contains { $0.index == 0 }
        if !hasZero {
            let needsFinal = enforceFinalTabstop
                || (insertFinalTabstop && !walker.placeholders.isEmpty)
            if needsFinal {
                let off = walker.utf16Offset
                walker.placeholders.append(
                    MonaSnippetResolvedPlaceholder(
                        index: 0, startOffset: off, endOffset: off, value: ""
                    )
                )
            }
        }
        return MonaSnippetResolvedSession(
            text: _MonaSnippetStringUnits.toString(walker.out),
            placeholders: walker.placeholders
        )
    }
}

// MARK: - Walker (private)

/// The depth-first resolution walker. Builds the rendered `[UInt16]` output and
/// the placeholder offset table in one pass.
private struct _Walker {

    /// The rendered output buffer (raw UTF-16 code units).
    var out: [UInt16] = []

    /// The current UTF-16 offset (= `out.count`).
    var utf16Offset: Int { return out.count }

    /// The placeholder offset table, in walk order.
    var placeholders: [MonaSnippetResolvedPlaceholder] = []

    /// Resolved placeholder values for mirroring (index → value), so a later
    /// bare `$n` mirrors an earlier `${n:…}`.
    var placeholderValues: [Int: String] = [:]

    /// The resolution context.
    let context: MonaSnippetVariableContext

    init(context: MonaSnippetVariableContext) {
        self.context = context
    }

    /// Appends a string to the output buffer.
    mutating func appendText(_ s: String) {
        out.append(contentsOf: Array(s.utf16))
    }

    /// Walks one marker in depth-first order, appending its rendered text to
    /// `out` and recording any placeholder offsets.
    mutating func walk(_ marker: MonaSnippetMarker) {
        switch marker {
        case .text(let v, _):
            appendText(v)

        case .escape(let c, _):
            appendText(String(c))

        case .tabstop(let idx, _):
            // Bare $n: mirror a prior placeholder of the same index (or empty).
            let value = placeholderValues[idx] ?? ""
            let start = utf16Offset
            appendText(value)
            placeholders.append(
                MonaSnippetResolvedPlaceholder(
                    index: idx, startOffset: start, endOffset: utf16Offset, value: value
                )
            )

        case .placeholder(let idx, let children, _, _):
            // The placeholder's value is its rendered children. Walk children
            // (they append text + any nested placeholders), then record this
            // placeholder's span and store its value for mirroring.
            let start = utf16Offset
            for child in children {
                walk(child)
            }
            let end = utf16Offset
            let value = _MonaSnippetStringUnits.toString(Array(out[start..<end]))
            placeholderValues[idx] = value
            placeholders.append(
                MonaSnippetResolvedPlaceholder(
                    index: idx, startOffset: start, endOffset: end, value: value
                )
            )

        case .choice(let idx, let options, _):
            let value = options.first ?? ""
            let start = utf16Offset
            appendText(value)
            placeholderValues[idx] = value
            placeholders.append(
                MonaSnippetResolvedPlaceholder(
                    index: idx, startOffset: start, endOffset: utf16Offset, value: value
                )
            )

        case .variable(let name, let children, _, let transform):
            if let resolved = MonaSnippetVariableResolver.resolve(
                name: name, context: context
            ) {
                // Resolved: apply the transform (if any) and emit the value.
                let value = transform.map {
                    MonaSnippetTransformExecutor.apply(transform: $0, to: resolved)
                } ?? resolved
                appendText(value)
            } else {
                // Unresolved: render the default children (no transform).
                // Children are walked in place so nested placeholders are
                // recorded; the variable itself emits no extra text.
                for child in children {
                    walk(child)
                }
            }
        }
    }
}
