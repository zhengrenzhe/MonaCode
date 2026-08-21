// MonaCodeModel.swift
//
// P01-T008 — Implement all 70 retained text-model members on Piece Tree truth.
//
// `MonaCodeModel` is the text model — the Swift counterpart of Monaco's
// `TextModel` / `ITextModel` (monaco-editor 0.56.0). It is a facade over the
// Piece Tree (P01-T007) plus options, version tracking, and event emitters.
//
// Text truth is delegated EXCLUSIVELY to `MonaPieceTree`: every value, line,
// offset, position, and snapshot query reads from the Piece Tree's raw UInt16
// storage (never from a parallel cached copy). Edits (`applyEdits`,
// `pushEditOperations`, `pushEOL`) mutate the Piece Tree and emit a
// `MonaModelContentChangeEvent`. `setValue` rebuilds the tree (a flush).
//
// The 70 retained M1-R2 members (see the `model-m1r2-public-surface-closure`)
// are partitioned into six groups:
//   - Content / snapshot            · 13  (Piece Tree truth)
//   - Position / range              · 11  (Piece Tree coordinates)
//   - Search / word / language      ·  6  (Phase 02 stubs, except `getLanguageId`)
//   - Decorations                   · 12  (Phase 02 stubs)
//   - Options / edits / undo        · 13  (edits via Piece Tree; undo Phase 02)
//   - Identity / version / events   · 15  (version, emitters, lifecycle)
//
// Undo, decorations, word, RegExp, and search behavior are left behind explicit
// Phase 02 interfaces: the member signatures are present (so the 70-member surface
// is complete) but return default values (empty arrays / nil / `false`). The
// `plaintext` language id is the always-present fallback metadata, so
// `getLanguageId()` returns `"plaintext"` in Phase 01.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The MonaCode text model: a facade over `MonaPieceTree` plus options, version
/// tracking, and event emitters, exposing all 70 retained M1-R2 members.
///
/// Create with `init(text:options:uri:)`. Read text via `getValue`,
/// `getLineContent`, `createSnapshot`; mutate via `applyEdits`,
/// `pushEditOperations`, `setValue`, `pushEOL`, `setEOL`. Subscribe to changes
/// via `onDidChangeContent` and the other event properties.
public final class MonaCodeModel {

    // MARK: - Owned truth

    /// The Piece Tree that owns all text truth. Replaced wholesale by `setValue`
    /// (a flush); mutated in place by `applyEdits` / `pushEditOperations`.
    private var pieceTree: MonaPieceTree

    /// The model options (tab size, indent size, insert spaces, trim auto ws).
    private var optionsValue: MonaModelOptions

    /// The EOL sequence metadata. The Piece Tree stores raw units; this records
    /// how line endings are reported by `getEOL`/`getEndOfLineSequence`.
    private var eolValue: MonaEndOfLineSequence

    /// The always-present fallback language id. Phase 01 never changes it.
    private let languageIdValue: String = "plaintext"

    // MARK: - Phase-02 primitive collaborators

    /// The literal-search engine. Stored as a default (empty-needle) instance;
    /// `findMatches` / `findNextMatch` / `findPreviousMatch` rebuild it per call
    /// from `searchString` / `isRegex` / `matchCase` once Task 2 wires the
    /// search members. `MonaLiteralSearch` has no default `init`, so the model
    /// holds the simplest valid form (empty needle) until a real query runs.
    private var searchEngine: MonaLiteralSearch = MonaLiteralSearch(needle: [])

    /// The word classifier (Monaco's default word-separator profile). Backs
    /// `getWordAtPosition` / `getWordUntilPosition` once Task 2 wires them.
    private var wordResolver: MonaWordClassifier = MonaWordClassifier()

    /// The decoration collection. Backs the 12 decoration members once Task 3
    /// wires them; until then it is an empty, ready collection.
    private var decorationStore: MonaDecorationCollection = MonaDecorationCollection()

    /// The undo/redo stack. `MonaUndoRedoStack.init` requires a
    /// `MonaTransactionGateway`, which itself wraps `self`; the gateway cannot
    /// exist before `self` is fully initialized, so this property is `lazy` and
    /// the stack + gateway are constructed on first access (once Task 4 wires
    /// the undo/redo members). The surface test never accesses it, so no
    /// gateway is built during Phase-01 member coverage.
    private lazy var undoRedoStack: MonaUndoRedoStack = MonaUndoRedoStack(
        gateway: MonaTransactionGateway(model: self)
    )

    // MARK: - Identity / version

    /// The model URI (immutable).
    public let uri: MonaURI

    /// The model id, derived from the URI's string form.
    public let id: String

    /// The current version id, bumped on every edit batch and flush.
    private var versionIdValue: Int

    /// The alternative version id (pre-edit version, for undo tracking).
    /// Phase 02 owns the real undo/redo alternative-version logic.
    private var alternativeVersionIdValue: Int

    /// Whether the model has been disposed.
    private var disposed: Bool = false

    /// Whether the model is attached to an editor (Phase 01: always false).
    private var attachedToEditor: Bool = false

    // MARK: - Event emitters

    private let contentEmitter = MonaEmitter<MonaModelContentChangeEvent>()
    private let decorationsEmitter = MonaEmitter<MonaModelDecorationChangeEvent>()
    private let optionsEmitter = MonaEmitter<MonaModelOptionsChangeEvent>()
    private let languageEmitter = MonaEmitter<MonaModelLanguageChangeEvent>()
    private let languageConfigEmitter = MonaEmitter<Void>()
    private let attachedEmitter = MonaEmitter<MonaModelAttachedChangeEvent>()
    private let willDisposeEmitter = MonaEmitter<MonaCodeModel>()

    // MARK: - Initialization

    /// Creates a text model with `text` as the initial content.
    ///
    /// `text` is converted to raw UTF-16 units and stored in a new Piece Tree.
    /// The version id starts at 1 (matching Monaco's initial versionId).
    public init(
        text: String,
        options: MonaModelOptions = .defaults,
        uri: MonaURI
    ) {
        self.pieceTree = MonaPieceTree(text: text)
        self.optionsValue = options
        self.eolValue = .lf
        self.uri = uri
        self.id = (try? uri.toString()) ?? "monacode:model"
        self.versionIdValue = 1
        self.alternativeVersionIdValue = 1
    }

    /// Creates a text model from raw UTF-16 `units` (preserving lone surrogates).
    public init(
        units: [UInt16],
        options: MonaModelOptions = .defaults,
        uri: MonaURI
    ) {
        self.pieceTree = MonaPieceTree(units: units)
        self.optionsValue = options
        self.eolValue = .lf
        self.uri = uri
        self.id = (try? uri.toString()) ?? "monacode:model"
        self.versionIdValue = 1
        self.alternativeVersionIdValue = 1
    }

    // MARK: - Content / snapshot · 13 members

    /// Returns the full text. Lone surrogates are repaired to U+FFFD by the
    /// String conversion; raw truth is preserved by `createSnapshot()`.
    public func getValue() -> String {
        return stringFromUnits(pieceTree.getText())
    }

    /// Replaces the entire text. A flush: rebuilds the Piece Tree, bumps the
    /// version id, resets the alternative version, and fires a flush
    /// `onDidChangeContent` event.
    public func setValue(_ newValue: String) {
        pieceTree = MonaPieceTree(text: newValue)
        versionIdValue += 1
        alternativeVersionIdValue = versionIdValue
        fireContentChange(changes: [], isUndoing: false, isRedoing: false, isFlush: true)
    }

    /// Creates an immutable snapshot of the current text, delegating to the
    /// Piece Tree. Edits to the live model never affect the returned snapshot.
    public func createSnapshot() -> MonaTextSnapshot {
        return pieceTree.createSnapshot()
    }

    /// The UTF-16 length of the full text.
    public func getValueLength() -> Int {
        return pieceTree.length
    }

    /// Returns the text within `range`.
    public func getValueInRange(_ range: MonaRange) -> String {
        let startOff = pieceTree.getOffsetAt(range.startPosition)
        let endOff = pieceTree.getOffsetAt(range.endPosition)
        let lo = min(startOff, endOff)
        let hi = max(startOff, endOff)
        return stringFromUnits(unitsInRange(lo..<hi))
    }

    /// The UTF-16 length of the text within `range`.
    public func getValueLengthInRange(_ range: MonaRange) -> Int {
        let startOff = pieceTree.getOffsetAt(range.startPosition)
        let endOff = pieceTree.getOffsetAt(range.endPosition)
        return max(endOff - startOff, 0)
    }

    /// The character count within `range`, porting Monaco's
    /// `getCharacterCountInRange`: a basic-ASCII fast path returns the UTF-16
    /// length; otherwise a high surrogate counts as one character and
    /// unconditionally skips the next unit, an isolated low surrogate counts
    /// one, and every other unit counts one.
    public func getCharacterCountInRange(_ range: MonaRange) -> Int {
        let startOff = pieceTree.getOffsetAt(range.startPosition)
        let endOff = pieceTree.getOffsetAt(range.endPosition)
        let lo = min(startOff, endOff)
        let hi = max(startOff, endOff)
        let units = unitsInRange(lo..<hi)

        // Basic-ASCII fast path.
        if units.allSatisfy({ $0 < 0x80 }) {
            return units.count
        }
        // Slow path: high surrogate counts one and skips next unconditionally.
        var count = 0
        var i = 0
        while i < units.count {
            let unit = Int(units[i])
            if (0xD800...0xDBFF).contains(unit) {
                count += 1
                i += 2
            } else {
                count += 1
                i += 1
            }
        }
        return count
    }

    /// The number of lines. An empty document has 1 line.
    public func getLineCount() -> Int {
        return pieceTree.lineCount
    }

    /// The content of `lineNumber` (1-based) excluding its trailing newline.
    public func getLineContent(_ lineNumber: Int) -> String {
        return stringFromUnits(pieceTree.getLineContent(lineNumber))
    }

    /// The UTF-16 length of `lineNumber`'s content (excluding the newline).
    public func getLineLength(_ lineNumber: Int) -> Int {
        return pieceTree.getLineContent(lineNumber).count
    }

    /// The content of every line, as an array.
    public func getLinesContent() -> [String] {
        return (1...pieceTree.lineCount).map { getLineContent($0) }
    }

    /// The EOL string (`"\n"` or `"\r\n"`).
    public func getEOL() -> String {
        return eolValue == .lf ? "\n" : "\r\n"
    }

    /// The EOL sequence.
    public func getEndOfLineSequence() -> MonaEndOfLineSequence {
        return eolValue
    }

    // MARK: - Position / range · 11 members

    /// The minimum column for `lineNumber` (always 1 in Monaco).
    public func getLineMinColumn(_ lineNumber: Int) -> Int {
        return 1
    }

    /// The maximum column for `lineNumber` (line length + 1).
    public func getLineMaxColumn(_ lineNumber: Int) -> Int {
        guard lineNumber >= 1, lineNumber <= pieceTree.lineCount else {
            return 1
        }
        return getLineLength(lineNumber) + 1
    }

    /// The column of the first non-whitespace character on `lineNumber`, or 0
    /// if the line is empty or all whitespace.
    public func getLineFirstNonWhitespaceColumn(_ lineNumber: Int) -> Int {
        let units = pieceTree.getLineContent(lineNumber)
        for i in 0..<units.count {
            let u = units[i]
            if u != 0x20 && u != 0x09 { // not space, not tab
                return i + 1
            }
        }
        return 0
    }

    /// The column after the last non-whitespace character on `lineNumber`, or 0
    /// if the line is empty or all whitespace.
    public func getLineLastNonWhitespaceColumn(_ lineNumber: Int) -> Int {
        let units = pieceTree.getLineContent(lineNumber)
        var lastNonWs = -1
        for i in 0..<units.count {
            let u = units[i]
            if u != 0x20 && u != 0x09 {
                lastNonWs = i
            }
        }
        if lastNonWs < 0 {
            return 0
        }
        return lastNonWs + 2
    }

    /// Validates `position`, clamping line and column to valid bounds.
    public func validatePosition(_ position: MonaPosition) -> MonaPosition {
        let lineCount = pieceTree.lineCount
        var line = position.line
        if line < 1 { line = 1 }
        if line > lineCount { line = lineCount }
        let minCol = getLineMinColumn(line)
        let maxCol = getLineMaxColumn(line)
        var col = position.column
        if col < minCol { col = minCol }
        if col > maxCol { col = maxCol }
        return MonaPosition(line: line, column: col)
    }

    /// Returns a new position offset from `position` by `offset` UTF-16 units,
    /// clamped to valid bounds. Ports Monaco's `modifyPosition`.
    public func modifyPosition(_ position: MonaPosition, offset: Int) -> MonaPosition {
        let baseOffset = pieceTree.getOffsetAt(position)
        let raw = pieceTree.getPositionAt(baseOffset + offset)
        return validatePosition(raw)
    }

    /// Validates `range`: clamps both endpoints and expands across any surrogate
    /// pair that an endpoint lands inside. Ports Monaco's `validateRange`
    /// surrogate-pair block via `MonaRange.expandedAcrossSurrogatePair`.
    public func validateRange(_ range: MonaRange) -> MonaRange {
        let startPos = validatePosition(range.startPosition)
        let endPos = validatePosition(range.endPosition)
        let normalized = MonaRange(startPosition: startPos, endPosition: endPos)
        let startOff = pieceTree.getOffsetAt(startPos)
        let endOff = pieceTree.getOffsetAt(endPos)
        return normalized.expandedAcrossSurrogatePair(
            startLandsInsideSurrogatePair: landsInsideSurrogatePair(at: startOff),
            endLandsInsideSurrogatePair: landsInsideSurrogatePair(at: endOff)
        )
    }

    /// `true` when `range` is already valid (validation does not change it).
    public func isValidRange(_ range: MonaRange) -> Bool {
        return validateRange(range) == range
    }

    /// The 0-based UTF-16 offset for `position`. Delegates to the Piece Tree.
    public func getOffsetAt(_ position: MonaPosition) -> Int {
        return pieceTree.getOffsetAt(position)
    }

    /// The 1-based position for a 0-based UTF-16 `offset`. Delegates to the
    /// Piece Tree.
    public func getPositionAt(_ offset: Int) -> MonaPosition {
        return pieceTree.getPositionAt(offset)
    }

    /// The full model range: `(1, 1)` to `(lineCount, lastLineMaxColumn)`.
    public func getFullModelRange() -> MonaRange {
        let lineCount = pieceTree.lineCount
        return MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: lineCount, column: getLineMaxColumn(lineCount))
        )
    }

    // MARK: - Search / word / language · 6 members (Phase 02 stubs except language)

    /// Phase 02 search stub. Returns an empty array; the real search contract
    /// (RegExp, capture groups, scope) is implemented in Phase 02.
    public func findMatches(
        searchString: String,
        searchScope: MonaModelSearchScope,
        isRegex: Bool,
        matchCase: Bool,
        captureMatches: Bool
    ) -> [MonaFindMatch] {
        return []
    }

    /// Phase 02 search stub. Returns `nil`.
    public func findNextMatch(
        searchString: String,
        searchScope: MonaModelSearchScope,
        isRegex: Bool,
        matchCase: Bool,
        captureMatches: Bool
    ) -> MonaFindMatch? {
        return nil
    }

    /// Phase 02 search stub. Returns `nil`.
    public func findPreviousMatch(
        searchString: String,
        searchScope: MonaModelSearchScope,
        isRegex: Bool,
        matchCase: Bool,
        captureMatches: Bool
    ) -> MonaFindMatch? {
        return nil
    }

    /// The language id. Always `"plaintext"` in Phase 01 — the always-present
    /// fallback metadata per the M1-R2 closure.
    public func getLanguageId() -> String {
        return languageIdValue
    }

    /// Phase 02 word stub. Returns `nil`.
    public func getWordAtPosition(_ position: MonaPosition) -> MonaRange? {
        return nil
    }

    /// Phase 02 word stub. Returns `nil`.
    public func getWordUntilPosition(_ position: MonaPosition) -> MonaRange? {
        return nil
    }

    // MARK: - Decorations · 12 members (Phase 02 stubs)

    /// Phase 02 decorations stub. Returns an empty array of ids.
    public func deltaDecorations(
        _ oldDecorations: [String],
        _ newDecorations: [MonaModelDecorationOptions]
    ) -> [String] {
        return []
    }

    /// Phase 02 decorations stub. Returns `nil`.
    public func getDecorationOptions(_ id: String) -> MonaModelDecorationOptions? {
        return nil
    }

    /// Phase 02 decorations stub. Returns `nil`.
    public func getDecorationRange(_ id: String) -> MonaRange? {
        return nil
    }

    /// Phase 02 decorations stub. Returns an empty array.
    public func getLineDecorations(
        _ lineNumber: Int,
        ownerId: Int = 0,
        filterOutValidation: Bool = false
    ) -> [MonaModelDecoration] {
        return []
    }

    /// Phase 02 decorations stub. Returns an empty array.
    public func getLinesDecorations(
        _ startLineNumber: Int,
        _ endLineNumber: Int,
        ownerId: Int = 0,
        filterOutValidation: Bool = false
    ) -> [MonaModelDecoration] {
        return []
    }

    /// Phase 02 decorations stub. Returns an empty array.
    public func getDecorationsInRange(
        _ range: MonaRange,
        ownerId: Int = 0,
        filterOutValidation: Bool = false
    ) -> [MonaModelDecoration] {
        return []
    }

    /// Phase 02 decorations stub. Returns an empty array.
    public func getAllDecorations(
        ownerId: Int = 0,
        filterOutValidation: Bool = false
    ) -> [MonaModelDecoration] {
        return []
    }

    /// Phase 02 decorations stub. Returns an empty array.
    public func getAllMarginDecorations(ownerId: Int = 0) -> [MonaModelDecoration] {
        return []
    }

    /// Phase 02 decorations stub. Returns an empty array.
    public func getOverviewRulerDecorations(
        ownerId: Int = 0,
        filterOutValidation: Bool = false
    ) -> [MonaModelDecoration] {
        return []
    }

    /// Phase 02 decorations stub. Returns an empty array.
    public func getInjectedTextDecorations(ownerId: Int = 0) -> [MonaModelDecoration] {
        return []
    }

    /// Phase 02 decorations stub. Returns an empty array.
    public func getCustomLineHeightsDecorations() -> [MonaModelDecoration] {
        return []
    }

    /// Phase 02 decorations stub. Returns an empty array.
    public func getCustomLineHeightsDecorationsInRange(_ range: MonaRange) -> [MonaModelDecoration] {
        return []
    }

    // MARK: - Options / edits / undo · 13 members

    /// Normalizes the leading indentation of `str` per the current options.
    public func normalizeIndentation(_ str: String) -> String {
        let units = Array(str.utf16)
        var firstNonWs = -1
        for i in 0..<units.count {
            if units[i] != 0x20 && units[i] != 0x09 {
                firstNonWs = i
                break
            }
        }
        if firstNonWs == -1 {
            // All whitespace (or empty): normalize the whole string.
            return normalizeWhitespaceUnits(units)
        }
        let indentation = Array(units[0..<firstNonWs])
        let restUnits = Array(units[firstNonWs...])
        return normalizeWhitespaceUnits(indentation) + stringFromUnits(restUnits)
    }

    /// Applies `newOptions`, firing `onDidChangeOptions`.
    public func updateOptions(_ newOptions: MonaModelOptions) {
        let old = optionsValue
        optionsValue = newOptions
        optionsEmitter.fire(MonaModelOptionsChangeEvent(oldOptions: old, newOptions: newOptions))
    }

    /// Phase 02 indent-detection stub. A no-op in Phase 01 (matching Monaco when
    /// detection is disabled); the real detection algorithm is Phase 02.
    public func detectIndentation(defaultInsertSpaces: Bool, defaultTabSize: Int) {
        // No-op until Phase 02 text-model-semantics.
    }

    /// Phase 02 undo-stack stub. A no-op in Phase 01.
    public func pushStackElement() {
        // No-op until Phase 02 undo/redo.
    }

    /// Phase 02 undo-stack stub. A no-op in Phase 01.
    public func popStackElement() {
        // No-op until Phase 02 undo/redo.
    }

    /// Applies `editOperations` through the Piece Tree, bumping the version and
    /// firing `onDidChangeContent`. Cursor-state tracking and the undo stack are
    /// Phase 02; in Phase 01 the edits are applied and the event is emitted.
    public func pushEditOperations(
        _ beforeCursorState: [MonaSelection],
        _ editOperations: [MonaModelEditOperation],
        _ cursorStateComputer: (([MonaModelEditOperation]) -> [MonaSelection])? = nil
    ) {
        _ = applyOperationsInternal(
            editOperations,
            isUndoing: false,
            isRedoing: false,
            isFlush: false
        )
    }

    /// Changes the EOL sequence, bumps the version, and fires a content-change
    /// event. Ports Monaco's `pushEOL` (the version-bumping public API).
    public func pushEOL(_ eol: MonaEndOfLineSequence) {
        alternativeVersionIdValue = versionIdValue
        versionIdValue += 1
        eolValue = eol
        fireContentChange(changes: [], isUndoing: false, isRedoing: false, isFlush: false)
    }

    /// Applies `operations` through the Piece Tree and returns the inverse
    /// (reverse) edits. Bumps the version and fires `onDidChangeContent`.
    public func applyEdits(_ operations: [MonaModelEditOperation]) -> [MonaModelEditOperation] {
        return applyOperationsInternal(
            operations,
            isUndoing: false,
            isRedoing: false,
            isFlush: false
        ).reverse
    }

    /// Sets the EOL sequence and fires a content-change event (no version bump;
    /// the version-bumping public API is `pushEOL`).
    public func setEOL(_ eol: MonaEndOfLineSequence) {
        eolValue = eol
        fireContentChange(changes: [], isUndoing: false, isRedoing: false, isFlush: false)
    }

    /// Phase 02 undo stub. A no-op in Phase 01.
    public func undo() {
        // No-op until Phase 02 undo/redo.
    }

    /// Phase 02 undo stub. Returns `false` in Phase 01 (no undo stack).
    public func canUndo() -> Bool {
        return false
    }

    /// Phase 02 redo stub. A no-op in Phase 01.
    public func redo() {
        // No-op until Phase 02 undo/redo.
    }

    /// Phase 02 redo stub. Returns `false` in Phase 01 (no redo stack).
    public func canRedo() -> Bool {
        return false
    }

    // MARK: - Identity / version / events / lifecycle · 15 members

    // (`uri` and `id` are `let` properties declared above.)

    /// The current options.
    public func getOptions() -> MonaModelOptions {
        return optionsValue
    }

    /// The current version id.
    public func getVersionId() -> Int {
        return versionIdValue
    }

    /// The alternative version id (pre-edit version, for undo tracking).
    public func getAlternativeVersionId() -> Int {
        return alternativeVersionIdValue
    }

    /// `true` when the model has been disposed.
    public func isDisposed() -> Bool {
        return disposed
    }

    /// Subscribe to content-change events.
    public var onDidChangeContent: MonaEvent<MonaModelContentChangeEvent> {
        return contentEmitter.event
    }

    /// Subscribe to decorations-change events. Phase 01 never fires this.
    public var onDidChangeDecorations: MonaEvent<MonaModelDecorationChangeEvent> {
        return decorationsEmitter.event
    }

    /// Subscribe to options-change events.
    public var onDidChangeOptions: MonaEvent<MonaModelOptionsChangeEvent> {
        return optionsEmitter.event
    }

    /// Subscribe to language-change events. Phase 01 never fires this.
    public var onDidChangeLanguage: MonaEvent<MonaModelLanguageChangeEvent> {
        return languageEmitter.event
    }

    /// Subscribe to language-configuration-change events. Phase 01 never fires
    /// this.
    public var onDidChangeLanguageConfiguration: MonaEvent<Void> {
        return languageConfigEmitter.event
    }

    /// Subscribe to attached-change events. Phase 01 never fires this.
    public var onDidChangeAttached: MonaEvent<MonaModelAttachedChangeEvent> {
        return attachedEmitter.event
    }

    /// Subscribe to will-dispose events. Fired once, synchronously, from
    /// `dispose()` before the model is marked disposed.
    public var onWillDispose: MonaEvent<MonaCodeModel> {
        return willDisposeEmitter.event
    }

    /// Disposes the model: fires `onWillDispose`, then disposes all emitters.
    /// Idempotent.
    public func dispose() {
        guard !disposed else { return }
        willDisposeEmitter.fire(self)
        disposed = true
        contentEmitter.dispose()
        decorationsEmitter.dispose()
        optionsEmitter.dispose()
        languageEmitter.dispose()
        languageConfigEmitter.dispose()
        attachedEmitter.dispose()
        willDisposeEmitter.dispose()
    }

    /// `true` when the model is attached to an editor. Phase 01 never attaches.
    public func isAttachedToEditor() -> Bool {
        return attachedToEditor
    }

    // MARK: - Private: edit application (delegates to the Piece Tree)

    /// Applies `operations` to the Piece Tree, collecting text changes and
    /// reverse edits. All offsets are computed against the pre-edit tree; edits
    /// are applied in descending start-offset order so earlier offsets remain
    /// valid. The deleted text is read from a pre-edit snapshot.
    private func applyOperationsInternal(
        _ operations: [MonaModelEditOperation],
        isUndoing: Bool,
        isRedoing: Bool,
        isFlush: Bool
    ) -> (changes: [MonaModelTextChange], reverse: [MonaModelEditOperation]) {
        // Snapshot the pre-edit state for deleted-text lookup.
        let snapshotUnits = pieceTree.createSnapshot().units

        // Compute every op's offsets against the ORIGINAL (pre-edit) tree.
        struct ComputedOp {
            let originalIndex: Int
            let op: MonaModelEditOperation
            let startOff: Int
            let endOff: Int
        }
        var computed: [ComputedOp] = []
        computed.reserveCapacity(operations.count)
        for (i, op) in operations.enumerated() {
            let s = pieceTree.getOffsetAt(op.range.startPosition)
            let e = pieceTree.getOffsetAt(op.range.endPosition)
            computed.append(ComputedOp(originalIndex: i, op: op, startOff: s, endOff: e))
        }
        // Descending start offset; stable tie-break by original index so the
        // reverse array maps back to the input order.
        computed.sort { a, b in
            if a.startOff != b.startOff { return a.startOff > b.startOff }
            return a.originalIndex < b.originalIndex
        }

        var changes: [MonaModelTextChange] = []
        changes.reserveCapacity(operations.count)
        var reverse = Array<MonaModelEditOperation>(
            repeating: MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                text: ""
            ),
            count: operations.count
        )

        for entry in computed {
            let op = entry.op
            let startOff = entry.startOff
            let endOff = entry.endOff
            let rangeLength = max(endOff - startOff, 0)
            let lo = min(startOff, endOff)
            let hi = max(startOff, endOff)
            let deletedUnits: [UInt16] = (lo < hi && hi <= snapshotUnits.count)
                ? Array(snapshotUnits[lo..<hi])
                : []
            let deletedText = stringFromUnits(deletedUnits)

            if rangeLength > 0 {
                pieceTree.delete(startOff..<endOff)
            }
            let insertUnits = Array(op.text.utf16)
            if !insertUnits.isEmpty {
                pieceTree.insert(insertUnits, at: startOff)
            }

            let newRange = MonaRange(
                startPosition: pieceTree.getPositionAt(startOff),
                endPosition: pieceTree.getPositionAt(startOff + insertUnits.count)
            )
            changes.append(MonaModelTextChange(
                range: newRange,
                rangeLength: rangeLength,
                rangeOffset: startOff,
                text: op.text
            ))
            reverse[entry.originalIndex] = MonaModelEditOperation(
                range: newRange,
                text: deletedText,
                forceMoveMarkers: op.forceMoveMarkers
            )
        }

        // Bump version + emit. The flush path is only used by `setValue`, which
        // does not route through this method; non-flush bumps the version.
        alternativeVersionIdValue = versionIdValue
        versionIdValue += 1
        fireContentChange(
            changes: changes,
            isUndoing: isUndoing,
            isRedoing: isRedoing,
            isFlush: isFlush
        )
        return (changes, reverse)
    }

    /// Fires a content-change event with the current version id.
    private func fireContentChange(
        changes: [MonaModelTextChange],
        isUndoing: Bool,
        isRedoing: Bool,
        isFlush: Bool
    ) {
        let event = MonaModelContentChangeEvent(
            changes: changes,
            eol: eolValue,
            versionId: versionIdValue,
            isUndoing: isUndoing,
            isRedoing: isRedoing,
            isFlush: isFlush
        )
        contentEmitter.fire(event)
    }

    // MARK: - Private: raw-unit helpers

    /// Converts raw `[UInt16]` to a `String`. Lone surrogates are repaired to
    /// U+FFFD by Foundation's lossy decoder; raw truth lives in the Piece Tree
    /// and snapshots.
    private func stringFromUnits(_ units: [UInt16]) -> String {
        return String(decoding: units, as: UTF16.self)
    }

    /// Returns the raw `[UInt16]` text in `range` (half-open) from the live
    /// tree. O(n) in the document length.
    private func unitsInRange(_ range: Range<Int>) -> [UInt16] {
        let all = pieceTree.getText()
        let lo = min(max(range.lowerBound, 0), all.count)
        let hi = min(max(range.upperBound, lo), all.count)
        if lo == hi { return [] }
        return Array(all[lo..<hi])
    }

    /// `true` when the UTF-16 unit immediately before `offset` is a high
    /// surrogate — i.e. the position sits between a high and low surrogate and
    /// should be expanded across the pair by `validateRange`.
    private func landsInsideSurrogatePair(at offset: Int) -> Bool {
        let all = pieceTree.getText()
        if offset <= 0 || offset > all.count { return false }
        let prev = Int(all[offset - 1])
        return (0xD800...0xDBFF).contains(prev)
    }

    /// Normalizes a whitespace-only `[UInt16]` run per the current options.
    private func normalizeWhitespaceUnits(_ units: [UInt16]) -> String {
        let tabSize = max(optionsValue.tabSize, 1)
        let insertSpaces = optionsValue.insertSpaces
        // Compute the visual column the whitespace occupies.
        var col = 0
        for ch in units {
            if ch == 0x09 { // tab → advance to next tab stop
                col += tabSize - (col % tabSize)
            } else { // space or other → one column
                col += 1
            }
        }
        if insertSpaces {
            return String(repeating: " ", count: col)
        }
        let tabs = col / tabSize
        let spaces = col % tabSize
        return String(repeating: "\t", count: tabs) + String(repeating: " ", count: spaces)
    }
}
