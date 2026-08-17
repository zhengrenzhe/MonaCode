// MonaModelOptions.swift
//
// P01-T008 — Implement all 70 retained text-model members on Piece Tree truth.
//
// `MonaModelOptions` is the text-model configuration value type — the Swift
// counterpart of Monaco's `TextModelTextModelOptions` / `ITextModelOptions`
// (monaco-editor 0.56.0). It carries the small set of options that influence
// text truth and indentation in Phase 01: `tabSize`, `indentSize`,
// `insertSpaces`, and `trimAutoWhitespace`.
//
// `MonaEndOfLineSequence` is the EOL-sequence value type — the counterpart of
// Monaco's `EndOfLineSequence` (`LF = 0`, `CRLF = 1`). The model stores the EOL
// sequence as metadata separate from the Piece Tree's raw units; `getEOL()` and
// `getEndOfLineSequence()` expose it, while `setEOL`/`pushEOL` mutate it.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The end-of-line sequence recorded by a text model.
///
/// Ported from Monaco's `EndOfLineSequence`. The Piece Tree stores text as raw
/// `[UInt16]`; the EOL sequence is metadata that controls how `getEOL()`
/// reports the line ending. Full CRLF normalization on edit is a Phase 02
/// text-model-semantics concern.
public enum MonaEndOfLineSequence: Int, Equatable {

    /// Lines are separated by `\n` (LF).
    case lf = 0

    /// Lines are separated by `\r\n` (CRLF).
    case crlf = 1
}

/// Text-model configuration options.
///
/// Phase 01 carries the options that influence text truth and indentation:
/// `tabSize`, `indentSize`, `insertSpaces`, and `trimAutoWhitespace`. Bracket
/// colorization and large-file optimizations are Phase 02 additions; the model
/// accepts and stores any options value but only the Phase 01 fields are
/// observed here.
public struct MonaModelOptions: Equatable {

    /// The number of spaces a tab character represents.
    public var tabSize: Int

    /// The number of spaces one indentation level occupies. Monaco also accepts
    /// `'tab'`; MonaCode stores an `Int` and treats `indentSize == tabSize` as
    /// the tab form for `normalizeIndentation`.
    public var indentSize: Int

    /// `true` when indentation should be emitted with spaces, `false` for tabs.
    public var insertSpaces: Bool

    /// `true` when trailing auto-whitespace on edit lines should be trimmed.
    public var trimAutoWhitespace: Bool

    /// Creates options. All fields default to Monaco's defaults
    /// (`tabSize = 4`, `indentSize = 4`, `insertSpaces = true`,
    /// `trimAutoWhitespace = true`).
    public init(
        tabSize: Int = 4,
        indentSize: Int = 4,
        insertSpaces: Bool = true,
        trimAutoWhitespace: Bool = true
    ) {
        self.tabSize = tabSize
        self.indentSize = indentSize
        self.insertSpaces = insertSpaces
        self.trimAutoWhitespace = trimAutoWhitespace
    }

    /// The default options, matching Monaco's `DEFAULT_MODEL_OPTIONS`.
    ///
    /// A computed property (rather than a stored `static let`) so the type does
    /// not need to be `Sendable` for Swift 6's global-mutable-state check in
    /// Phase 01; concurrency isolation is established in Phase 02 (A+/R1).
    public static var defaults: MonaModelOptions {
        return MonaModelOptions()
    }
}

/// The options-change event payload, fired by `onDidChangeOptions` after
/// `updateOptions(_:)` applies a new options value.
public struct MonaModelOptionsChangeEvent: Equatable {

    /// The options in effect before the change.
    public let oldOptions: MonaModelOptions

    /// The options in effect after the change.
    public let newOptions: MonaModelOptions

    /// Creates the change event payload.
    public init(oldOptions: MonaModelOptions, newOptions: MonaModelOptions) {
        self.oldOptions = oldOptions
        self.newOptions = newOptions
    }
}
