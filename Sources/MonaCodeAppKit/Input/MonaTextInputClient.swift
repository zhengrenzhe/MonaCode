// MonaTextInputClient.swift
//
// P04-T004 — Implement marked-text input and composition arbitration.
//
// `MonaTextInputClient` implements the marked-text input client surface (the
// macOS `NSTextInputClient` protocol selectors the editor answers). It owns the
// marked-text state (the marked text, its selected range, and the raw UTF-16
// replacement range) and routes every synchronous native geometry query —
// first-rect-for-character-range and character-index-for-point — through the
// geometry barrier (P03-T007) via `MonaCompositionGeometryProvider`. The
// composition path must NOT bypass the barrier.
//
// Raw UTF-16 replacement ranges: the replacement range (where the marked text
// will be inserted) is in UTF-16 code units — NOT graphemes. This matters for
// ABC (Chinese) and Pinyin IMEs where the range spans surrogate pairs. The
// client preserves the replacement range verbatim, and derives the document
// marked range from the replacement range location + the marked text's UTF-16
// code-unit length (never a grapheme count).
//
// `MonaCompositionGeometryProvider` is the protocol the barrier satisfies; the
// real `MonaQueryGeometryBarrier` (P03-T007) conforms via an extension, and
// tests inject a fake. This keeps the "uses the barrier" contract while
// remaining unit-testable without a full view-graph + scroll + builder stack.
//
// MonaCodeAppKit may import AppKit, CoreGraphics, Foundation, and MonaCode.

import AppKit
import CoreGraphics
import Foundation
import MonaCode

// MARK: - MonaCompositionGeometryProvider

/// The synchronous geometry queries the text input client needs, satisfied by
/// `MonaQueryGeometryBarrier` (P03-T007).
///
/// The composition path routes first-rect and character-index queries through
/// this provider and must NOT bypass the barrier. The barrier answers only
/// from one complete generation; partial state is never observed.
public protocol MonaCompositionGeometryProvider {

    /// Returns the caret rect (viewport space) for a model position against the
    /// current complete generation, or a typed unavailable reason.
    func caretRect(for position: MonaPosition) -> MonaGeometryResult<CGRect>

    /// Hit-tests a viewport-space point against the current complete generation,
    /// returning the model position or a typed unavailable reason.
    func hitTest(point: CGPoint) -> MonaGeometryResult<MonaPosition>
}

/// `MonaQueryGeometryBarrier` satisfies the geometry provider protocol: its
/// `caretRect(for:)` and `hitTest(point:)` methods answer from one complete
/// generation. This extension is the composition path's link to the barrier —
/// the composition session never bypasses it for geometry.
extension MonaQueryGeometryBarrier: MonaCompositionGeometryProvider {}

// MARK: - MonaTextInputClient

/// The marked-text input client: implements the `NSTextInputClient` surface for
/// marked text, selected range, replacement range, attributed substring,
/// first-rect, and character-index queries.
///
/// Owns the marked-text state and routes every synchronous geometry query
/// through `MonaCompositionGeometryProvider` (the geometry barrier, P03-T007).
/// Preserves raw UTF-16 replacement ranges verbatim — never converting to
/// graphemes — so ABC/Pinyin IME traces that span surrogate pairs are carried
/// through unchanged.
///
/// The client is not thread-safe; the editor pipeline that owns one client
/// drives it from a single coordinator (the composition arbiter, which owns
/// one session per editor).
///
/// Driving layer (Task 6 / GAP-5): the class owns the `NSTextInputClient`
/// selector implementations but does NOT itself conform to the
/// `NSTextInputClient` ObjC protocol. The macOS 26 SDK imports
/// `hasMarkedText`/`markedRange`/`selectedRange` as protocol *methods*
/// (`func hasMarkedText() -> Bool`, etc.), not properties — so making this
/// class conform would force converting its property accessors to methods,
/// breaking the P04-T004 composition tests that read them as properties
/// (`client.hasMarkedText`, `client.markedRange`, `client.selectedRange`).
/// Approach (a) (client conforms) is therefore blocked by API drift; approach
/// (b) is used instead: `MonaCodeEditorView` (already an `NSView`/`NSObject`)
/// conforms to `NSTextInputClient` and forwards every selector to this client.
/// This task adds the one missing selector — `insertText(_:replacementRange:)`
/// — routing it to the command dispatcher's `type` command via the injected
/// `textInsertionProvider`, plus the `textInsertionProvider` dependency.
public final class MonaTextInputClient {

    // MARK: - Dependencies

    /// The geometry provider (the barrier). Every first-rect and
    /// character-index query is routed through here.
    private let geometryProvider: MonaCompositionGeometryProvider

    /// Supplies the full document text (UTF-16) for attributed-substring and
    /// UTF-16 ↔ position conversion. Injected so the client does not own the
    /// model.
    private let documentTextProvider: () -> String

    /// Supplies the current document selection (UTF-16 range) for the
    /// `selectedRange` selector. Injected so the client does not own the
    /// selection.
    private let documentSelectionProvider: () -> NSRange

    /// Routes `insertText(_:replacementRange:)` to the command dispatcher's
    /// `type` command. Injected so the client does not own the dispatcher.
    /// Driving layer (Task 6 / GAP-5).
    private let textInsertionProvider: (String, NSRange) -> Void

    // MARK: - Marked-text state

    /// The currently marked attributed string, or `nil` when not composing.
    private var markedAttributed: NSAttributedString?

    /// The selection within the marked text (UTF-16 offsets relative to the
    /// marked text start).
    private var markedSelected: NSRange = .notFound

    /// The raw UTF-16 replacement range in the document — where the marked text
    /// is inserted. Preserved verbatim (NOT converted to graphemes). `NSNotFound`
    /// location means "replace the current marked range or selection."
    private var rawReplacement: NSRange = .notFound

    // MARK: - Init

    /// Creates a text input client over the given dependencies.
    ///
    /// - Parameters:
    ///   - geometryProvider: The geometry barrier (or a test fake) answering
    ///     first-rect and character-index queries from one complete generation.
    ///   - documentTextProvider: Supplies the full document text for
    ///     attributed-substring and UTF-16 ↔ position conversion.
    ///   - documentSelectionProvider: Supplies the current document selection
    ///     (UTF-16 range) for the `selectedRange` selector.
    ///   - textInsertionProvider: Routes `insertText(_:replacementRange:)` to
    ///     the command dispatcher's `type` command. Driving layer (Task 6).
    ///     Defaults to a no-op so existing P04-T004 composition-test call sites
    ///     (which predate this parameter) compile unchanged.
    public init(
        geometryProvider: MonaCompositionGeometryProvider,
        documentTextProvider: @escaping () -> String,
        documentSelectionProvider: @escaping () -> NSRange,
        textInsertionProvider: @escaping (String, NSRange) -> Void = { _, _ in }
    ) {
        self.geometryProvider = geometryProvider
        self.documentTextProvider = documentTextProvider
        self.documentSelectionProvider = documentSelectionProvider
        self.textInsertionProvider = textInsertionProvider
    }

    // MARK: - Marked text (NSTextInputClient: setMarkedText / unmarkText / hasMarkedText / markedRange)

    /// Sets the marked text, its selected range, and the replacement range.
    ///
    /// The marked text is stored; the selected range is within the marked text
    /// (UTF-16 offsets relative to the marked text start); the replacement range
    /// is the raw UTF-16 document range where the marked text is inserted,
    /// preserved verbatim (NOT converted to graphemes). When the replacement
    /// range location is `NSNotFound`, the previous marked range (or the
    /// document selection) is used.
    ///
    /// - Parameters:
    ///   - string: The marked text, as a `String` or `NSAttributedString`.
    ///   - selectedRange: The selection within the marked text.
    ///   - replacementRange: The raw UTF-16 document range to replace.
    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        markedAttributed = coerceMarkedText(string)
        markedSelected = selectedRange
        if replacementRange.location == NSNotFound {
            // Use the previous marked range's location, or the document selection.
            let anchor = currentMarkedAnchorLocation()
            rawReplacement = NSRange(location: anchor, length: 0)
        } else {
            rawReplacement = replacementRange
        }
    }

    /// Clears the marked text.
    public func unmarkText() {
        markedAttributed = nil
        markedSelected = .notFound
        rawReplacement = .notFound
    }

    /// `true` when marked text is active.
    public var hasMarkedText: Bool {
        return markedAttributed != nil
    }

    /// The document range of the marked text (UTF-16). Derived from the raw
    /// replacement range location + the marked text's UTF-16 code-unit length
    /// — NOT a grapheme count. `NSNotFound` when no marked text is active.
    public var markedRange: NSRange {
        guard let marked = markedAttributed, rawReplacement.location != NSNotFound else {
            return .notFound
        }
        let markedUTF16Length = marked.string.utf16.count
        return NSRange(location: rawReplacement.location, length: markedUTF16Length)
    }

    // MARK: - Selection (NSTextInputClient: selectedRange)

    /// The current document selection (UTF-16 range), from the selection
    /// provider.
    public var selectedRange: NSRange {
        return documentSelectionProvider()
    }

    // MARK: - Insertion (NSTextInputClient: insertText(_:replacementRange:))

    /// Inserts `string` at the replacement range, routing through
    /// `textInsertionProvider` to the command dispatcher's `type` command.
    ///
    /// The `string` argument is `Any` (the ObjC `id`) per the
    /// `NSTextInputClient` contract; it is coerced to a `String` (an
    /// `NSAttributedString` contributes its `.string`). An empty string is a
    /// no-op.
    ///
    /// `replacementRange` is the raw UTF-16 document range to replace. When
    /// its location is `NSNotFound` (the common case — AppKit passes
    /// `NSNotFound` when the input layer has no explicit replacement target),
    /// the `type` command inserts at the current selection
    /// (`gateway.lastCommittedSelections`; the barrier defaults to a collapsed
    /// caret at `(1,1)` when none are committed). v1 ignores a specific range
    /// and always inserts at the current selection — the `type` command's edit
    /// plan derives its range from the committed selections, not from this
    /// parameter; specific-range handling is deferred.
    ///
    /// - Parameters:
    ///   - string: The text to insert, as a `String` or `NSAttributedString`.
    ///   - replacementRange: The UTF-16 document range to replace. `NSNotFound`
    ///     location means "insert at the current selection."
    public func insertText(_ string: Any, replacementRange: NSRange) {
        let text: String
        if let s = string as? String {
            text = s
        } else if let attr = string as? NSAttributedString {
            text = attr.string
        } else {
            // Defensive fallback — the NSTextInputClient contract guarantees
            // String or NSAttributedString; mirror `coerceMarkedText`'s path.
            text = "\(string)"
        }
        guard !text.isEmpty else { return }
        textInsertionProvider(text, replacementRange)
    }

    // MARK: - Attributed substring (NSTextInputClient: attributedSubstringForProposedRange)

    /// Returns the attributed substring of the document at the proposed range,
    /// clamped to the document length.
    ///
    /// - Parameters:
    ///   - range: The proposed UTF-16 document range.
    ///   - actualRange: On return, the actual range used (clamped). Pass `nil`
    ///     to ignore.
    /// - Returns: The attributed substring, or `nil` if the range is empty or
    ///   out of bounds.
    public func attributedSubstring(
        forProposedRange range: NSRange,
        actualRange: NSRangePointer?
    ) -> NSAttributedString? {
        let document = documentTextProvider()
        let docUTF16Count = document.utf16.count
        let clamped = clampRange(range, toLength: docUTF16Count)
        actualRange?.pointee = clamped
        guard clamped.length > 0 else { return nil }
        let start = document.utf16.index(document.utf16.startIndex, offsetBy: clamped.location)
        let end = document.utf16.index(start, offsetBy: clamped.length)
        let substring = String(decoding: document.utf16[start..<end], as: UTF16.self)
        return NSAttributedString(string: substring)
    }

    // MARK: - Geometry: first-rect (NSTextInputClient: firstRectForCharacterRange)

    /// Returns the rect (viewport space) for the first character in the given
    /// document range, routed through the geometry barrier.
    ///
    /// The range is in document UTF-16 coordinates. The start offset is
    /// converted to a `MonaPosition` (line + 1-based UTF-16 column), then the
    /// barrier's `caretRect(for:)` answers. Returns `.zero` when the geometry
    /// is unavailable (the barrier reports no complete generation, the
    /// position is out of bounds, or bounded completion failed).
    ///
    /// - Parameters:
    ///   - range: The UTF-16 document range.
    ///   - actualRange: On return, the actual range used. Pass `nil` to ignore.
    /// - Returns: The first-character rect, or `.zero` if unavailable.
    public func firstRect(
        forCharacterRange range: NSRange,
        actualRange: NSRangePointer?
    ) -> NSRect {
        let document = documentTextProvider()
        let docUTF16Count = document.utf16.count
        let clamped = clampRange(range, toLength: docUTF16Count)
        actualRange?.pointee = clamped
        let position = positionForUTF16Offset(clamped.location, in: document)
        switch geometryProvider.caretRect(for: position) {
        case .available(let rect):
            return rect
        case .unavailable:
            return .zero
        }
    }

    // MARK: - Geometry: character-index (NSTextInputClient: characterIndexForPoint)

    /// Returns the UTF-16 character index for a viewport-space point, routed
    /// through the geometry barrier.
    ///
    /// The barrier's `hitTest(point:)` answers a `MonaPosition`, which is
    /// converted to a UTF-16 document offset. Returns `NSNotFound` when the
    /// geometry is unavailable.
    ///
    /// - Parameter point: The viewport-space point.
    /// - Returns: The UTF-16 character index, or `NSNotFound` if unavailable.
    public func characterIndex(for point: NSPoint) -> Int {
        switch geometryProvider.hitTest(point: point) {
        case .available(let position):
            let document = documentTextProvider()
            return utf16OffsetForPosition(position, in: document)
        case .unavailable:
            return NSNotFound
        }
    }

    // MARK: - Public state accessors (for the composition session / arbiter)

    /// The currently marked attributed string, or `nil` when not composing.
    public var markedAttributedText: NSAttributedString? {
        return markedAttributed
    }

    /// The selection within the marked text (UTF-16 offsets relative to the
    /// marked text start).
    public var markedSelectedRange: NSRange {
        return markedSelected
    }

    /// The raw UTF-16 replacement range, preserved verbatim (NOT converted to
    /// graphemes). `NSNotFound` location when no marked text is active.
    public var rawReplacementRange: NSRange {
        return rawReplacement
    }

    // MARK: - Private: marked-text coercion

    /// Coerces the `Any` marked-text argument (a `String` or
    /// `NSAttributedString`) to an `NSAttributedString`.
    private func coerceMarkedText(_ value: Any) -> NSAttributedString {
        if let attr = value as? NSAttributedString {
            return attr
        }
        if let str = value as? String {
            return NSAttributedString(string: str)
        }
        // Fallback: coerce via description. The NSTextInputClient contract
        // guarantees String or NSAttributedString; this path is defensive.
        return NSAttributedString(string: "\(value)")
    }

    /// Returns the anchor location for a `NSNotFound` replacement range: the
    /// previous marked range's location if marked text is active, else the
    /// document selection's location.
    private func currentMarkedAnchorLocation() -> Int {
        if markedAttributed != nil, rawReplacement.location != NSNotFound {
            return rawReplacement.location
        }
        let selection = documentSelectionProvider()
        return selection.location == NSNotFound ? 0 : selection.location
    }

    // MARK: - Private: UTF-16 ↔ MonaPosition conversion

    /// Converts a UTF-16 document offset to a `MonaPosition` (1-based line +
    /// 1-based UTF-16 column). Walks the document's UTF-16 view counting
    /// newlines (U+000A). Out-of-range offsets clamp to the document end.
    private func positionForUTF16Offset(_ offset: Int, in text: String) -> MonaPosition {
        var line = 1
        var column = 1
        var consumed = 0
        for unit in text.utf16 {
            if consumed == offset {
                return MonaPosition(line: line, column: column)
            }
            if unit == 0x000A { // newline
                line += 1
                column = 1
            } else {
                column += 1
            }
            consumed += 1
        }
        // Offset at or past the end → end-of-document position.
        if offset >= consumed {
            return MonaPosition(line: line, column: column)
        }
        return MonaPosition(line: line, column: column)
    }

    /// Converts a `MonaPosition` (1-based line + 1-based UTF-16 column) to a
    /// UTF-16 document offset. Walks the document's UTF-16 view. Returns 0 for
    /// a position that cannot be resolved (defensive; should not occur for
    /// positions returned by the barrier).
    private func utf16OffsetForPosition(_ position: MonaPosition, in text: String) -> Int {
        var line = 1
        var column = 1
        var offset = 0
        for unit in text.utf16 {
            if line == position.line && column == position.column {
                return offset
            }
            if unit == 0x000A { // newline
                line += 1
                column = 1
            } else {
                column += 1
            }
            offset += 1
        }
        // Position at end-of-document.
        if line == position.line && column == position.column {
            return offset
        }
        return NSNotFound
    }

    // MARK: - Private: range clamping

    /// Clamps a UTF-16 range to the document length. A `NSNotFound` location
    /// becomes an empty range at 0.
    private func clampRange(_ range: NSRange, toLength length: Int) -> NSRange {
        if range.location == NSNotFound {
            return NSRange(location: 0, length: 0)
        }
        let location = max(0, min(range.location, length))
        let maxLength = length - location
        let clampedLength = max(0, min(range.length, maxLength))
        return NSRange(location: location, length: clampedLength)
    }
}
