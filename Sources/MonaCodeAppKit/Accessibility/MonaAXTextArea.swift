// MonaAXTextArea.swift
//
// P04-T010 — Expose the raw UTF-16 native text accessibility surface.
//
// `MonaAXTextArea` is the persistent accessibility text surface for the AppKit
// editor — the value / selection / visible-range / attributed-substring /
// range-for-position / bounds-for-range / position-for-range / line-mapping
// selectors that macOS accessibility clients (VoiceOver, the AXUIElement API)
// call. It sits under the AX element graph (P04-T011) and feeds the AX mutation
// gateway (P04-T013).
//
// The surface reads RAW UTF-16 truth from the model (the Piece Tree preserves
// lone surrogates, never repairs them). The `value` and `attributedSubstring`
// selectors build `NSString` / `NSAttributedString` directly from the raw
// `[UInt16]` storage — bypassing Swift's lossy `String` decoder, which repairs
// lone surrogates to U+FFFD. A lone surrogate therefore counts as exactly one
// UTF-16 unit on both the model side and the AX side. Integer ranges are
// translated by `MonaAXTextRangeMapper`.
//
// Geometry queries (range-for-position, bounds-for-range, position-for-range)
// and the visible range are routed through `MonaQueryGeometryBarrier`
// (P03-T007), the complete-generation barrier. The barrier answers only from
// one frozen generation; when no complete generation has been published, the
// geometry selectors return `nil` (no partial geometry is synthesized) and the
// visible range falls back to the full document range.
//
// Ownership: the model and geometry barrier are held indirectly (weak) so an AX
// element never extends a disposed model's lifetime. The viewport size is
// supplied by a closure (the AX element graph wires it to the live view size).
// The selection is settable AX state synced in by the editor / AX element
// graph; AX clients read it back as an `NSRange`.
//
// `MonaCodeAppKit` may `import AppKit`, `import Foundation`, and `import MonaCode`.

import AppKit
import Foundation
import MonaCode

/// The persistent native-text accessibility surface for the AppKit editor.
///
/// Construct with `init(model:geometryBarrier:viewportSize:)`. Read the full
/// text via `value`; the raw UTF-16 unit count via `numberOfCharacters`. Get/set
/// the selection via `selectionRange`. Read the visible character range via
/// `visibleRange` (gated on the barrier's complete generation). Read a substring
/// via `attributedSubstring(for:)`. Resolve geometry via
/// `range(forPosition:)`, `bounds(forRange:)`, `position(forRange:)` (all routed
/// through the geometry barrier). Map line index ↔ range via
/// `line(forCharacterIndex:)` and `range(forLine:)`.
public final class MonaAXTextArea {

    // MARK: - Backing references (indirect)

    /// The model supplying raw UTF-16 text truth. Held weakly so the AX surface
    /// never extends a disposed model's lifetime; queries return empty/nil when
    /// the model is gone.
    private weak var model: MonaCodeModel?

    /// The complete-generation geometry barrier (P03-T007). Held weakly. All
    /// position↔bounds queries route through this barrier; when it is absent or
    /// has no complete generation, geometry selectors return `nil`.
    private weak var geometryBarrier: MonaQueryGeometryBarrier?

    /// Supplies the current viewport size in viewport-space points (the AX
    /// element graph wires this to the live view size). Used to compute the
    /// visible character range. Returns `nil` when the viewport size is unknown.
    private let viewportSizeProvider: () -> CGSize?

    // MARK: - AX state

    /// The selection as an AX integer range, synced in by the editor / AX
    /// element graph. Defaults to a folded range at offset 0.
    private var selectionRangeValue: NSRange = NSRange(location: 0, length: 0)

    // MARK: - Init

    /// Creates the AX text surface over `model`, optionally wired to a geometry
    /// barrier and viewport size provider.
    ///
    /// - Parameters:
    ///   - model: The text model supplying raw UTF-16 text truth.
    ///   - geometryBarrier: The complete-generation geometry barrier (P03-T007)
    ///     for position↔bounds queries. When `nil`, geometry selectors return
    ///     `nil` and `visibleRange` falls back to the full document range.
    ///   - viewportSize: A closure returning the current viewport size in
    ///     viewport-space points, or `nil` when unknown. Used to compute
    ///     `visibleRange`.
    public init(
        model: MonaCodeModel,
        geometryBarrier: MonaQueryGeometryBarrier? = nil,
        viewportSize: @escaping () -> CGSize? = { nil }
    ) {
        self.model = model
        self.geometryBarrier = geometryBarrier
        self.viewportSizeProvider = viewportSize
    }

    // MARK: - Value (full text, raw UTF-16, no repair)

    /// The full document text as an `NSString` built from the model's raw
    /// `[UInt16]` storage.
    ///
    /// Bypasses Swift's lossy `String` decoder (which repairs lone surrogates to
    /// U+FFFD); the `NSString` is constructed directly from the raw UTF-16 units
    /// so lone surrogates survive verbatim. AX clients read `length` and
    /// `character(at:)`, both of which report raw UTF-16 units.
    public var value: NSString {
        guard let model = self.model else { return "" }
        let units = model.createSnapshot().units
        return MonaAXTextArea.nsString(fromRawUnits: units)
    }

    /// The raw UTF-16 unit count of the full text. AX clients use this to bound
    /// ranges.
    public var numberOfCharacters: Int {
        guard let model = self.model else { return 0 }
        return model.getValueLength()
    }

    // MARK: - Selection (settable NSRange)

    /// The selection as an AX integer range. Settable AX state: the editor /
    /// AX element graph syncs the selection in; AX clients read it back.
    public var selectionRange: NSRange {
        get { return selectionRangeValue }
        set { selectionRangeValue = newValue }
    }

    // MARK: - Attributed substring (raw UTF-16, no repair)

    /// Returns an `NSAttributedString` for `range`, built from the model's raw
    /// `[UInt16]` storage (no surrogate repair), or `nil` when `range` is out
    /// of bounds or the model is gone.
    ///
    /// A zero-length in-bounds range returns an empty attributed string.
    public func attributedSubstring(for range: NSRange) -> NSAttributedString? {
        guard let model = self.model else { return nil }
        let length = model.getValueLength()
        let lo = range.location
        let hi = lo + range.length
        // Out-of-bounds: return nil.
        guard lo >= 0, lo <= length, hi >= lo, hi <= length else { return nil }
        if hi == lo {
            return NSAttributedString(string: "")
        }
        let units = model.createSnapshot().units
        let sub = Array(units[lo..<hi])
        let str = MonaAXTextArea.nsString(fromRawUnits: sub)
        // Bridge the NSString to String for the attributed string initializer.
        // The NSString→String bridge preserves raw UTF-16 units (it backs the
        // String with the NSString rather than decoding+repairing), so lone
        // surrogates survive in the attributed string's backing store.
        return NSAttributedString(string: str as String)
    }

    // MARK: - Visible range (gated on the barrier's complete generation)

    /// The visible character range as an AX integer range.
    ///
    /// Computed by hit-testing the top-left and bottom-right of the viewport
    /// through the geometry barrier. When the barrier is absent, has no
    /// complete generation, or the viewport size is unknown, falls back to the
    /// full document range (the safe default for AX clients — VoiceOver reads
    /// the whole document rather than nothing).
    public var visibleRange: NSRange {
        guard let model = self.model else { return NSRange(location: 0, length: 0) }
        let fullLength = model.getValueLength()
        let fullRange = NSRange(location: 0, length: fullLength)
        guard let barrier = self.geometryBarrier,
              let viewport = self.viewportSizeProvider() else {
            return fullRange
        }
        let topResult = barrier.hitTest(point: CGPoint(x: 0, y: 0))
        let bottomResult = barrier.hitTest(point: CGPoint(x: 0, y: viewport.height))
        guard case .available(let topPos) = topResult,
              case .available(let bottomPos) = bottomResult else {
            // No complete generation or unresolvable: fall back to the full
            // range rather than synthesizing partial geometry.
            return fullRange
        }
        let startOff = model.getOffsetAt(topPos)
        let endOff = model.getOffsetAt(bottomPos)
        let lo = min(startOff, endOff)
        let hi = max(startOff, endOff)
        return NSRange(location: lo, length: max(hi - lo, 0))
    }

    // MARK: - Geometry queries (routed through the complete-generation barrier)

    /// Resolves a viewport-space `point` to the `NSRange` of the character at
    /// that position through the geometry barrier.
    ///
    /// Returns the single-character range at the hit-tested position, or a
    /// zero-length range at the position when it lands at the end of the
    /// document. Returns `nil` when there is no barrier, no complete
    /// generation, or the position is unresolvable (no partial geometry is
    /// synthesized).
    public func range(forPosition point: CGPoint) -> NSRange? {
        guard let model = self.model, let barrier = self.geometryBarrier else {
            return nil
        }
        let result = barrier.hitTest(point: point)
        guard case .available(let position) = result else {
            return nil
        }
        let offset = model.getOffsetAt(position)
        let length = model.getValueLength()
        // The character at the caret position: one unit forward, clamped to the
        // document end (zero length at the end).
        let charLength = offset < length ? 1 : 0
        return NSRange(location: offset, length: charLength)
    }

    /// Resolves an `NSRange` to its bounding `CGRect` through the geometry
    /// barrier.
    ///
    /// The barrier's `rangeRects(for:)` produces one rect per spanned view
    /// line; this returns their union. Returns `nil` when there is no barrier,
    /// no complete generation, or the range cannot be resolved.
    public func bounds(forRange range: NSRange) -> CGRect? {
        guard let model = self.model, let barrier = self.geometryBarrier else {
            return nil
        }
        let mapper = MonaAXTextRangeMapper(model: model)
        let monaRange = mapper.monaRange(for: range)
        let result = barrier.rangeRects(for: monaRange)
        guard case .available(let rects) = result, !rects.isEmpty else {
            return nil
        }
        return rects.reduce(CGRect.null) { $0.union($1) }
    }

    /// Resolves an `NSRange` to the viewport-space point at the start of the
    /// range (the origin of the first character's rect) through the geometry
    /// barrier.
    ///
    /// Returns `nil` when there is no barrier, no complete generation, or the
    /// range's start position cannot be resolved.
    public func position(forRange range: NSRange) -> CGPoint? {
        guard let model = self.model, let barrier = self.geometryBarrier else {
            return nil
        }
        let mapper = MonaAXTextRangeMapper(model: model)
        let monaRange = mapper.monaRange(for: range)
        let result = barrier.caretRect(for: monaRange.startPosition)
        guard case .available(let rect) = result else {
            return nil
        }
        return rect.origin
    }

    // MARK: - Line mapping (line index ↔ range)

    /// Maps a UTF-16 character index (offset) to a 1-based line number.
    ///
    /// Returns 0 when the model is gone or `index` is negative. Out-of-range
    /// indices clamp to the document end.
    public func line(forCharacterIndex index: Int) -> Int {
        guard let model = self.model, index >= 0 else { return 0 }
        let length = model.getValueLength()
        let clamped = min(index, length)
        return model.getPositionAt(clamped).line
    }

    /// Maps a 1-based line number to the `NSRange` spanning that line's content,
    /// including a trailing newline for non-final lines.
    ///
    /// Returns an empty range when the model is gone or `line` is out of range.
    public func range(forLine line: Int) -> NSRange {
        guard let model = self.model else { return NSRange(location: 0, length: 0) }
        let lineCount = model.getLineCount()
        guard line >= 1, line <= lineCount else {
            return NSRange(location: 0, length: 0)
        }
        let startOff = model.getOffsetAt(MonaPosition(line: line, column: 1))
        let endOff: Int
        if line < lineCount {
            endOff = model.getOffsetAt(MonaPosition(line: line + 1, column: 1))
        } else {
            endOff = model.getValueLength()
        }
        return NSRange(location: startOff, length: max(endOff - startOff, 0))
    }

    // MARK: - Private: raw UTF-16 → NSString (no repair)

    /// Builds an `NSString` from raw `[UInt16]` units without surrogate repair.
    ///
    /// Uses `NSString(utf16CodeUnits:count:)` (which stores the UTF-16 code
    /// units verbatim — `NSString` is a UTF-16 container) instead of
    /// `String(decoding:as:UTF16.self)` (which repairs lone surrogates to
    /// U+FFFD).
    private static func nsString(fromRawUnits units: [UInt16]) -> NSString {
        guard !units.isEmpty else { return "" }
        return units.withUnsafeBufferPointer { buffer -> NSString in
            NSString(characters: buffer.baseAddress!, length: buffer.count)
        }
    }
}
