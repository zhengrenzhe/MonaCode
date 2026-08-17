// MonaWordClassifier.swift
//
// P02-T003 — Implement word, grapheme, literal search, and replacement primitives.
//
// `MonaWordClassifier` is the MonaCode port of Monaco's
// `WordCharacterClassifier` (monaco-editor 0.56.0, vendored from vscode's
// `vs/editor/common/model/wordHelper.ts`). It classifies a raw UTF-16 code unit
// into one of three classes — `.other` (a word character), `.wordSeparator`
// (one of the configured separator code units), or `.whitespace` — matching
// Monaco's `WordCharClassification` three-way split.
//
// Frozen profile (M1-R model, raw UTF-16):
//
//   - The default separator set is Monaco's `USUAL_WORD_SEPARATORS`:
//     `` ` ~ ! @ # $ % ^ & * ( ) - = + [ { ] } \ | ; : ' " , . < > / ? ``.
//     Every code unit in this set is ASCII (< 0x80) and classifies as
//     `.wordSeparator`.
//   - ASCII letters (a-z, A-Z), digits (0-9), and underscore (`_`) are word
//     characters (`.other`), as is any code unit not in the separator set and
//     not whitespace — including non-ASCII and isolated surrogates. Monaco's
//     `CharacterClassifier` defaults unknown code units to the `Other` class,
//     and a lone surrogate is never a separator nor whitespace, so it is
//     preserved as `.other` (the raw-UTF-16 invariant: isolated surrogates are
//     never repaired or reclassified).
//   - Whitespace is its own class (`.whitespace`), NOT `.wordSeparator`: this
//     matches Monaco, where `cursorWordOperations` checks `_isWordSeparator`
//     and whitespace separately. `isWordSeparator` returns `false` for
//     whitespace.
//
// `isWordSeparator(_:)` is the primary entry point named by P02-T003; `wordClass`
// exposes the full three-way classification and `isWhitespace` / `isWordCharacter`
// are conveniences.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The three-way classification of a UTF-16 code unit under Monaco's
/// `WordCharacterClassifier`.
///
/// Mirrors Monaco's `WordCharClassification` enum (`wordHelper.ts`):
/// `.other` is the default for any code unit that is neither a configured
/// separator nor whitespace.
public enum MonaWordClass: UInt8, Equatable, Hashable {

    /// A word character — the default class for any code unit that is neither a
    /// configured separator nor whitespace. Includes ASCII letters, digits,
    /// underscore, non-ASCII, and isolated surrogates.
    case other

    /// One of the configured word-separator code units (Monaco's
    /// `USUAL_WORD_SEPARATORS` by default).
    case wordSeparator

    /// A whitespace code unit (space, tab, line feed, carriage return, form
    /// feed, vertical tab).
    case whitespace
}

/// The frozen word-separator classifier over raw UTF-16 code units.
///
/// The Swift counterpart of Monaco's `WordCharacterClassifier`. Construct with
/// the default profile (`MonaWordClassifier()`) or a custom separator set
/// (`MonaWordClassifier(separators:)`).
public struct MonaWordClassifier: Equatable, Hashable {

    /// The default word-separator code units — Monaco's `USUAL_WORD_SEPARATORS`:
    /// `` ` ~ ! @ # $ % ^ & * ( ) - = + [ { ] } \ | ; : ' " , . < > / ? ``.
    public static let defaultSeparators: Set<UInt16> = {
        let usual = "`~!@#$%^&*()-=+[{]}\\|;:'\",.<>/?"
        var set: Set<UInt16> = []
        set.reserveCapacity(usual.unicodeScalars.count)
        for scalar in usual.unicodeScalars {
            set.insert(UInt16(scalar.value))
        }
        return set
    }()

    /// The configured separator code units. A code unit is a `.wordSeparator`
    /// iff it is in this set.
    public let separators: Set<UInt16>

    /// Creates a classifier with Monaco's default word-separator profile.
    public init() {
        self.separators = MonaWordClassifier.defaultSeparators
    }

    /// Creates a classifier with a custom separator set.
    public init(separators: Set<UInt16>) {
        self.separators = separators
    }

    /// Returns the three-way class of `codeUnit`.
    public func wordClass(_ codeUnit: UInt16) -> MonaWordClass {
        if separators.contains(codeUnit) {
            return .wordSeparator
        }
        if Self.whitespaceCodeUnits.contains(codeUnit) {
            return .whitespace
        }
        return .other
    }

    /// Returns `true` if `codeUnit` is one of the configured word separators.
    ///
    /// Whitespace is NOT a word separator (it has its own class); this matches
    /// Monaco's `WordCharacterClassifier`, which keeps `WordSeparator` and
    /// `Whitespace` distinct.
    public func isWordSeparator(_ codeUnit: UInt16) -> Bool {
        return separators.contains(codeUnit)
    }

    /// Returns `true` if `codeUnit` is whitespace (space, tab, line feed,
    /// carriage return, form feed, or vertical tab).
    public func isWhitespace(_ codeUnit: UInt16) -> Bool {
        return Self.whitespaceCodeUnits.contains(codeUnit)
    }

    /// Returns `true` if `codeUnit` is a word character (`.other`) — i.e. not a
    /// separator and not whitespace.
    public func isWordCharacter(_ codeUnit: UInt16) -> Bool {
        return !separators.contains(codeUnit) && !Self.whitespaceCodeUnits.contains(codeUnit)
    }

    /// The ASCII whitespace code units classified as `.whitespace`.
    private static let whitespaceCodeUnits: Set<UInt16> = [
        0x0009, // horizontal tab
        0x000A, // line feed
        0x000B, // vertical tab
        0x000C, // form feed
        0x000D, // carriage return
        0x0020, // space
    ]
}
