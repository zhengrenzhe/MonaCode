// MonaFontFallbackResolver.swift
//
// P03-T002 — Shape mixed-script lines with Core Text and deterministic fallback.
//
// `MonaFontFallbackResolver` resolves the deterministic font cascade list used
// by `MonaTextShaper`: the primary font first, then a caller-supplied ordered
// list of fallback fonts for code points the primary font does not cover. This
// is the "deterministic fallback order" required by P03-T002 — Core Text's
// own automatic cascade is NOT the authority for the explicit fallback chain;
// the resolver hands Core Text the exact cascade to use.
//
// The resolver exposes:
//   - `primary` / `fallbacks`              — the caller-supplied descriptors.
//   - `resolveCascade()`                   — builds the (primary CTFont, fallback
//                                            CTFonts) pair, dropping any fallback
//                                            whose family silently substituted
//                                            (so unavailable faces are not added
//                                            to the cascade).
//   - `descriptorCoveringCodePoint(_:)`   — returns the first descriptor whose
//                                            resolved CTFont has a real glyph for
//                                            the code point, or nil if none.
//
// MonaCodeAppKit may import AppKit/CoreText/CoreGraphics; this file imports
// CoreText + CoreGraphics + Foundation.

import Foundation
import CoreText
import CoreGraphics

/// Resolves a deterministic font cascade (primary -> fallback fonts) for
/// `MonaTextShaper`.
///
/// The resolver is the single authority for the explicit fallback order. Core
/// Text's automatic cascade is layered after the explicit list by Core Text
/// itself; the resolver does not synthesize an automatic cascade.
public final class MonaFontFallbackResolver {

    /// The primary font descriptor.
    public let primary: MonaFontDescriptor

    /// The ordered fallback font descriptors.
    public let fallbacks: [MonaFontDescriptor]

    /// Creates a resolver with a `primary` font and an ordered `fallback` list.
    public init(primary: MonaFontDescriptor, fallback: [MonaFontDescriptor]) {
        self.primary = primary
        self.fallbacks = fallback
    }

    // MARK: - Cascade resolution

    /// Resolves the primary `CTFont` and the available fallback `CTFont`s.
    ///
    /// A fallback descriptor whose family name does not match the resolved
    /// CTFont's family name (Core Text silently substituted a different face)
    /// is dropped from the cascade rather than added as a wrong-face entry. This
    /// keeps the cascade deterministic: only faces that actually exist are
    /// included.
    ///
    /// - Returns: The primary CTFont and the list of resolved fallback CTFonts.
    /// - Throws: `MonaTextShaperError.fontDescriptorInvalid` if the primary
    ///   descriptor is malformed, or `MonaTextShaperError.primaryFontUnavailable`
    ///   if the primary font resolves to a different family than requested.
    public func resolveCascade() throws -> (primary: CTFont, fallbacks: [CTFont]) {
        try MonaFontFallbackResolver.validateDescriptor(primary)
        let primaryCT = try MonaFontFallbackResolver.resolveCTFont(for: primary, role: "primary")
        var resolvedFallbacks: [CTFont] = []
        resolvedFallbacks.reserveCapacity(fallbacks.count)
        for desc in fallbacks {
            // Fallbacks that are invalid or unavailable are skipped (not added).
            // The cascade simply omits them; this is NOT a shaping failure.
            guard MonaFontFallbackResolver.isDescriptorValid(desc) else { continue }
            guard let ct = try? MonaFontFallbackResolver.resolveCTFont(for: desc, role: "fallback") else {
                continue
            }
            // Only keep the fallback if its family actually matches the request.
            let resolvedFamily = (CTFontCopyFamilyName(ct) as String?) ?? ""
            if resolvedFamily.caseInsensitiveCompare(desc.familyName) == .orderedSame {
                resolvedFallbacks.append(ct)
            }
        }
        return (primaryCT, resolvedFallbacks)
    }

    /// Returns the first descriptor (primary then fallbacks in order) whose
    /// resolved CTFont has a real glyph for `codePoint`, or `nil` if none.
    ///
    /// `codePoint` is a Unicode scalar value. For supplementary-plane characters
    /// pass the full scalar (e.g. `0x1F600`), not a UTF-16 surrogate.
    public func descriptorCoveringCodePoint(_ codePoint: UInt32) -> MonaFontDescriptor? {
        // Check the primary first.
        if MonaFontFallbackResolver.font(MonaGlyphRun.resolveCTFont(for: primary), coversCodePoint: codePoint) {
            return primary
        }
        // Then the fallbacks in order.
        for desc in fallbacks {
            let ct = MonaGlyphRun.resolveCTFont(for: desc)
            if MonaFontFallbackResolver.font(ct, coversCodePoint: codePoint) {
                return desc
            }
        }
        return nil
    }

    // MARK: - Private: validation + resolution

    /// Returns `true` when the descriptor is well-formed (non-empty family,
    /// positive size).
    fileprivate static func isDescriptorValid(_ descriptor: MonaFontDescriptor) -> Bool {
        return !descriptor.familyName.isEmpty && descriptor.size > 0
    }

    /// Throws `fontDescriptorInvalid` if the descriptor is malformed.
    fileprivate static func validateDescriptor(_ descriptor: MonaFontDescriptor) throws {
        guard isDescriptorValid(descriptor) else {
            throw MonaTextShaperError.fontDescriptorInvalid(descriptor)
        }
    }

    /// Resolves a `CTFont` for `descriptor`, throwing `primaryFontUnavailable`
    /// if Core Text substituted a different family. `role` is included in the
    /// error context for diagnostics.
    ///
    /// Note: this substitution check is only applied for the primary font (via
    /// `resolveCascade`'s call site for the primary). Fallbacks use the
    /// family-match filter in `resolveCascade` instead of throwing.
    fileprivate static func resolveCTFont(
        for descriptor: MonaFontDescriptor,
        role: String
    ) throws -> CTFont {
        let attributes: [CFString: Any] = [
            kCTFontFamilyNameAttribute: descriptor.familyName,
            kCTFontSizeAttribute: descriptor.size,
        ]
        let ctDescriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        let font = CTFontCreateWithFontDescriptor(ctDescriptor, descriptor.size, nil)
        let resolvedFamily = (CTFontCopyFamilyName(font) as String?) ?? ""
        if resolvedFamily.caseInsensitiveCompare(descriptor.familyName) != .orderedSame {
            throw MonaTextShaperError.primaryFontUnavailable(
                descriptor,
                resolvedFamilyName: resolvedFamily.isEmpty ? nil : resolvedFamily
            )
        }
        return font
    }

    /// Returns `true` if `font` has a real (non-.notdef) glyph for `codePoint`.
    ///
    /// Uses `CTFontCopyCharacterSet` + `CFCharacterSetIsLongCharacterMember`,
    /// which is the reliable coverage oracle for supplementary-plane characters
    /// (including color glyphs like emoji) — the glyph-for-characters API does
    /// not reliably report color-glyph coverage.
    fileprivate static func font(_ font: CTFont, coversCodePoint codePoint: UInt32) -> Bool {
        guard codePoint <= 0x10FFFF else { return false }
        let charSet = CTFontCopyCharacterSet(font)
        return CFCharacterSetIsLongCharacterMember(charSet, codePoint)
    }
}
