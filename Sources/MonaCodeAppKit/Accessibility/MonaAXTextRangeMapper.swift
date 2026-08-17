// MonaAXTextRangeMapper.swift
//
// P04-T010 — Expose the raw UTF-16 native text accessibility surface.
//
// `MonaAXTextRangeMapper` converts between accessibility integer ranges
// (`NSRange` — `NSInteger` location + length over the UTF-16 string as macOS
// accessibility clients see it) and raw model UTF-16 offsets / `MonaRange`.
//
// This is a PURE INTEGER TRANSLATION WITH NO SURROGATE REPAIR. The model stores
// raw `[UInt16]` (the Piece Tree preserves lone surrogates, never repairs them),
// and accessibility clients see the text as a UTF-16 `NSString`/`CFString` whose
// code-unit count matches the raw model unit count. A lone surrogate therefore
// counts as exactly one UTF-16 unit on both sides. The mapper never normalizes,
// never merges, and never substitutes U+FFFD. This is consistent with how
// `MonaPieceTree`, `MonaTextShaper`, and `MonaLiteralSearch` treat raw units.
//
// The offset conversion itself is identity: an accessibility UTF-16 offset maps
// 1:1 to a raw model offset, because both index the same raw `[UInt16]` storage.
// The mapper's real work is translating between `NSRange` (integer offsets) and
// `MonaRange` (1-based line + column positions) via the model's offset↔position
// conversion, which operates over raw UTF-16 units — never over a repaired
// `String`.
//
// `MonaCodeAppKit` may `import AppKit`, `import Foundation`, and `import MonaCode`.

import Foundation
import MonaCode

/// Converts between accessibility integer ranges (`NSRange`) and raw model
/// UTF-16 offsets / `MonaRange` with no surrogate repair.
///
/// Construct with `init(model:)`. An AX integer offset maps 1:1 to a raw model
/// offset (both are UTF-16 code-unit indices over the same raw `[UInt16]`
/// storage); the mapper additionally converts between `NSRange` and
/// `MonaRange` (1-based line + column) via the model's offset↔position
/// conversion over raw units.
public struct MonaAXTextRangeMapper {

    /// The model whose raw UTF-16 storage the mapper translates against. Held
    /// transiently (the mapper is typically created per query).
    private let model: MonaCodeModel

    /// Creates a mapper translating against `model`'s raw UTF-16 storage.
    public init(model: MonaCodeModel) {
        self.model = model
    }

    // MARK: - NSRange → MonaRange

    /// Converts an accessibility integer range to a `MonaRange` via raw model
    /// UTF-16 offsets.
    ///
    /// `axRange.location` and `axRange.location + axRange.length` are raw UTF-16
    /// offsets; the model's `getPositionAt` (which reads raw `[UInt16]`) maps
    /// them to 1-based positions. No surrogate repair: a lone surrogate is one
    /// unit and maps to one column.
    ///
    /// Out-of-range offsets are clamped to `[0, length]` by the model.
    public func monaRange(for axRange: NSRange) -> MonaRange {
        let startOffset = axRange.location
        let endOffset = axRange.location + axRange.length
        let startPos = model.getPositionAt(startOffset)
        let endPos = model.getPositionAt(endOffset)
        return MonaRange(startPosition: startPos, endPosition: endPos)
    }

    // MARK: - MonaRange → NSRange

    /// Converts a `MonaRange` to an accessibility integer range via raw model
    /// UTF-16 offsets.
    ///
    /// The model's `getOffsetAt` (which reads raw `[UInt16]`) maps the 1-based
    /// positions to UTF-16 offsets; the `NSRange` is `[start, end)`. No surrogate
    /// repair: a lone surrogate contributes one unit to the length.
    public func axRange(for monaRange: MonaRange) -> NSRange {
        let startOffset = model.getOffsetAt(monaRange.startPosition)
        let endOffset = model.getOffsetAt(monaRange.endPosition)
        let lo = min(startOffset, endOffset)
        let hi = max(startOffset, endOffset)
        return NSRange(location: lo, length: max(hi - lo, 0))
    }

    // MARK: - Offset conversion (identity)

    /// Converts an accessibility UTF-16 offset to a raw model UTF-16 offset.
    ///
    /// Identity: both index the same raw `[UInt16]` storage, so an AX offset
    /// maps 1:1 to a model offset with no normalization. Exposed as an explicit
    /// method so the translation lives in one place.
    public func modelOffset(forAxOffset axOffset: Int) -> Int {
        return axOffset
    }

    /// Converts a raw model UTF-16 offset to an accessibility UTF-16 offset.
    ///
    /// Identity (see `modelOffset(forAxOffset:)`).
    public func axOffset(forModelOffset modelOffset: Int) -> Int {
        return modelOffset
    }
}
