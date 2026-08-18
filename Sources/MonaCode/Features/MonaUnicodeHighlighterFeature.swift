// MonaUnicodeHighlighterFeature.swift
//
// P05-T157 — Implement retained feature unicodeHighlighter.
//
// `MonaUnicodeHighlighterFeature` is the Swift counterpart of Monaco's
// `unicodeHighlighter` contribution (monaco-editor 0.56.0): it detects
// configured invisible, ambiguous, and non-basic Unicode spans in a model's
// text so a host can decorate them. Detection reads the unicode-highlighter
// option slice (`ambiguousCharacters` / `invisibleCharacters` /
// `nonBasicASCII` booleans plus an `allowedCharacters` allowlist); each
// problematic character is reported as one span carrying its 1-based range,
// its kind, and its code point.
//
// The Foundation-only Core performs no tokenization, so it cannot distinguish
// comments / strings / identifiers (the `includeComments` / `includeStrings`
// / `nonBasicASCII: "inUntrustedWorkspace"` context filters degrade to the
// trusted plain-text default: detect over the whole text). The feature is
// read-only: it performs no model mutation.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `detectHighlights(in:options:)` walks the
//      model text, classifying each unicode scalar as invisible / ambiguous /
//      non-basic-ASCII under the configured options and allowlist.
//   2. Register the exact feature identity `unicodeHighlighter` and its
//      declared commands, actions, contributions, options, menus, and
//      keybindings, referenced verbatim from the frozen registries (no rename
//      / coalesce).
//   3. Route model mutation (read-only — none), asynchronous publication,
//      disposal, localization, and degraded plain-text behavior through the
//      shared gateways — reusing `MonaTransactionGateway` (mutation, vacuous),
//      `MonaProviderExecutor` + `MonaMicrotaskQueue` (async publication),
//      `MonaEmitter` (disposal), `MonaLocalization` (localization), and
//      `MonaPlainTextLanguage` (degraded plain text). No parallel mechanisms
//      are introduced.

import Foundation

/// A unicode-highlight kind: whether a detected character is invisible,
/// ambiguous (confusable with basic ASCII), or non-basic-ASCII.
public enum MonaUnicodeHighlightKind: String, Equatable {

    /// An invisible / format character (e.g. U+200B ZERO WIDTH SPACE).
    case invisible

    /// An ambiguous character confusable with a basic ASCII character (e.g.
    /// U+FF21 FULLWIDTH LATIN CAPITAL LETTER A).
    case ambiguous

    /// A non-basic-ASCII character (any scalar above U+007F not already
    /// classified as invisible or ambiguous).
    case nonBasicAscii
}

/// A detected unicode-highlight span: the 1-based range, the kind, and the
/// code point (unicode scalar value) of the highlighted character.
public struct MonaUnicodeHighlightSpan: Equatable {

    /// The 1-based range of the highlighted character.
    public let range: MonaRange

    /// The detected kind.
    public let kind: MonaUnicodeHighlightKind

    /// The unicode scalar value of the highlighted character.
    public let codePoint: UInt32

    public init(range: MonaRange, kind: MonaUnicodeHighlightKind, codePoint: UInt32) {
        self.range = range
        self.kind = kind
        self.codePoint = codePoint
    }
}

/// The unicode-highlighter options — the configured subset of Monaco's
/// `unicodeHighlight` editor option. The Foundation-only Core degrades the
/// `includeComments` / `includeStrings` / `nonBasicASCII: "inUntrustedWorkspace"`
/// context filters to the trusted plain-text default (detect over the whole
/// text), so the three detection booleans are the live configuration surface.
public struct MonaUnicodeHighlightOptions: Equatable {

    /// `true` to detect ambiguous (ASCII-confusable) characters.
    public let ambiguousCharacters: Bool

    /// `true` to detect invisible / format characters.
    public let invisibleCharacters: Bool

    /// `true` to detect non-basic-ASCII characters (scalars above U+007F not
    /// already classified as invisible or ambiguous).
    public let nonBasicASCII: Bool

    /// The allowlist of unicode scalar values that are never highlighted,
    /// regardless of kind (Monaco's `allowedCharacters`).
    public let allowedCharacters: Set<UInt32>

    /// Creates the options. All detection kinds default to `false`; the
    /// caller opts in to the kinds it wants.
    public init(
        ambiguousCharacters: Bool = false,
        invisibleCharacters: Bool = false,
        nonBasicASCII: Bool = false,
        allowedCharacters: Set<UInt32> = []
    ) {
        self.ambiguousCharacters = ambiguousCharacters
        self.invisibleCharacters = invisibleCharacters
        self.nonBasicASCII = nonBasicASCII
        self.allowedCharacters = allowedCharacters
    }
}

/// A unicode-highlighter event: the staged span set (empty when cleared).
public struct MonaUnicodeHighlighterEvent: Equatable {

    /// The staged spans, or empty when none are staged.
    public let spans: [MonaUnicodeHighlightSpan]

    public init(spans: [MonaUnicodeHighlightSpan]) {
        self.spans = spans
    }
}

/// The unicodeHighlighter feature: detect configured invisible, ambiguous, and
/// non-basic Unicode spans.
///
/// The feature identity `unicodeHighlighter` and its declared slice are
/// referenced verbatim from the frozen registries. Detection is read-only: the
/// feature performs no model mutation (the vacuous mutation path is still
/// routed through `MonaTransactionGateway`). Asynchronous publication is routed
/// through `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through
/// `MonaEmitter`; localization through `MonaLocalization`; and degraded
/// plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaUnicodeHighlighterFeature: MonaDisposable {

    /// The frozen feature identity (`"unicodeHighlighter"`).
    public static let featureId = "unicodeHighlighter"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce).
    /// unicodeHighlighter declares no labeled actions — its four entries in the
    /// F1-R3 registries are commands only (they carry no action label).
    public static let declaredActionIds: [String] = []

    /// The declared command IDs in source order. The four unicode-highlight
    /// commands: disable-highlighting-of-ambiguous, disable-highlighting-of-
    /// invisible, disable-highlighting-of-non-basic-ascii, and show-exclude-
    /// options.
    public static let declaredCommandIds: [String] = [
        "editor.action.unicodeHighlight.disableHighlightingOfAmbiguousCharacters",
        "editor.action.unicodeHighlight.disableHighlightingOfInvisibleCharacters",
        "editor.action.unicodeHighlight.disableHighlightingOfNonBasicAsciiCharacters",
        "editor.action.unicodeHighlight.showExcludeOptions"
    ]

    /// The declared contribution ID (`editor.contrib.unicodeHighlighter`,
    /// ordinal 44).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.unicodeHighlighter"
    ]

    /// The declared keybinding commands — unicodeHighlighter carries no
    /// default keybinding in `MonaBuiltinKeybindings`, so this slice is empty.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names. The `unicodeHighlight` editor option (id 142)
    /// owns the detection configuration sub-fields.
    public static let declaredOptionIds: [String] = [
        "unicodeHighlight"
    ]

    /// The declared menu IDs — unicodeHighlighter registers no menu items, so
    /// this slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The staged span set (set by `stageHighlights(_:)`), or empty.
    private var stagedSpans: [MonaUnicodeHighlightSpan] = []

    private let emitter = MonaEmitter<MonaUnicodeHighlighterEvent>()

    /// The event stream for unicode-highlighter changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the
    /// listener.
    public var onChange: MonaEvent<MonaUnicodeHighlighterEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the unicodeHighlighter feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: detect configured Unicode spans

    /// Detects the configured invisible / ambiguous / non-basic-ASCII spans in
    /// `model` under `options`. Each problematic character is reported as one
    /// span (1-based range, kind, code point). Classification precedence is
    /// invisible → ambiguous → non-basic-ASCII (a character is assigned to the
    /// first enabled kind it matches). Characters in
    /// `options.allowedCharacters` are never highlighted. Returns an empty
    /// array after `dispose()`.
    public func detectHighlights(
        in model: MonaCodeModel,
        options: MonaUnicodeHighlightOptions
    ) -> [MonaUnicodeHighlightSpan] {
        guard !isDisposed else { return [] }
        // Fast path: no kinds enabled → nothing to detect.
        guard options.ambiguousCharacters
            || options.invisibleCharacters
            || options.nonBasicASCII else { return [] }

        var spans: [MonaUnicodeHighlightSpan] = []
        var line = 1
        var column = 1 // 1-based UTF-16 code-unit column
        for scalar in model.getValue().unicodeScalars {
            if scalar == "\n" {
                line += 1
                column = 1
                continue
            }
            let value = scalar.value
            let utf16Length = value < 0x10000 ? 1 : 2
            if !options.allowedCharacters.contains(value), let kind = Self.classify(value) {
                let enabled: Bool
                switch kind {
                case .invisible: enabled = options.invisibleCharacters
                case .ambiguous: enabled = options.ambiguousCharacters
                case .nonBasicAscii: enabled = options.nonBasicASCII
                }
                if enabled {
                    spans.append(MonaUnicodeHighlightSpan(
                        range: MonaRange(
                            startLine: line,
                            startColumn: column,
                            endLine: line,
                            endColumn: column + utf16Length
                        ),
                        kind: kind,
                        codePoint: value
                    ))
                }
            }
            column += utf16Length
        }
        return spans
    }

    /// Stages `spans` as the current highlight set and fires an event. A no-op
    /// after `dispose()`.
    public func stageHighlights(_ spans: [MonaUnicodeHighlightSpan]) {
        guard !isDisposed else { return }
        _lock.lock()
        stagedSpans = spans
        _lock.unlock()
        fire(.init(spans: spans))
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway (read-only: none performed)

    /// unicodeHighlighter is a read-only inspection: it performs no model
    /// mutation. Mutation routing is therefore vacuous — the feature introduces
    /// no parallel mutation mechanism, and `detectHighlights` leaves the model
    /// untouched. This no-op is exposed so callers that route every feature
    /// action through the gateway can confirm the model is unchanged.
    @discardableResult
    public func confirmReadOnly(gateway: MonaTransactionGateway) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        // Commit an empty transaction: no edits, no selections, no EOL. The
        // model is untouched; the outcome records that the (non-)mutation was
        // routed through the shared gateway rather than bypassing it.
        let transaction = gateway.beginTransaction()
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `spans` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated. After
    /// `dispose()`, returns `false` and publishes nothing.
    @discardableResult
    public func publishHighlights(
        _ spans: [MonaUnicodeHighlightSpan],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaUnicodeHighlightSpan]) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        return executor.publish(
            .synchronous(spans),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the staged spans are cleared, and
    /// `detectHighlights` returns an empty array.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        stagedSpans = []
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. unicodeHighlighter declares
    /// no labeled actions, so this returns an empty array under every profile.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. unicodeHighlighter degrades to the
    /// plain-text fallback for its tokenization-dependent context filters
    /// (comments / strings): the Foundation-only Core carries no language
    /// provider, so detection runs over the whole text.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — unicodeHighlighter degrades gracefully to the plain-text
    /// fallback when no language provider is registered (Foundation-only Core).
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a unicode-highlighter event when not disposed.
    private func fire(_ event: MonaUnicodeHighlighterEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }

    /// Classifies `value` (a unicode scalar value) into one of the three kinds,
    /// with precedence invisible → ambiguous → non-basic-ASCII, or returns
    /// `nil` when `value` is basic ASCII (value <= U+007F) and so warrants no
    /// highlight. Basic-ASCII characters are never flagged; everything above
    /// U+007F that is not invisible / ambiguous is non-basic-ASCII.
    private static func classify(_ value: UInt32) -> MonaUnicodeHighlightKind? {
        if value <= 0x007F { return nil }
        if isInvisible(value) { return .invisible }
        if isAmbiguous(value) { return .ambiguous }
        return .nonBasicAscii
    }

    /// `true` when `value` is an invisible / format character. This is the
    /// frozen set Monaco's unicode-highlighter flags as invisible: soft hyphen,
    /// zero-width marks, bidi formatting, word joiners, and the BOM.
    private static func isInvisible(_ value: UInt32) -> Bool {
        switch value {
        case 0x00AD: return true // SOFT HYPHEN
        case 0x200B...0x200F: return true // ZERO WIDTH SPACE .. RIGHT-TO-LEFT MARK
        case 0x202A...0x202E: return true // LRE .. RLO bidi formatting
        case 0x2060...0x206F: return true // WORD JOINER .. invisible operators
        case 0xFEFF: return true // ZERO WIDTH NO-BREAK SPACE (BOM)
        default: return false
        }
    }

    /// `true` when `value` is an ambiguous character — a non-basic-ASCII
    /// character confusable with a basic ASCII character. This is a faithful,
    /// documented subset of Monaco's ambiguous set: fullwidth ASCII variants
    /// (U+FF01..U+FF5E), mathematical alphanumeric symbols (U+1D400..U+1D7FF),
    /// and the Greek / Cyrillic letters that are visual confusables for Latin
    /// letters.
    private static func isAmbiguous(_ value: UInt32) -> Bool {
        // Fullwidth ASCII variants.
        if (0xFF01...0xFF5E).contains(value) { return true }
        // Mathematical Alphanumeric Symbols.
        if (0x1D400...0x1D7FF).contains(value) { return true }
        // Greek / Cyrillic Latin-lookalikes (visual confusables).
        return Self.confusableLetters.contains(value)
    }

    /// The Greek and Cyrillic letters that are visual confusables for basic
    /// Latin letters (a documented subset of Unicode's confusables table).
    private static let confusableLetters: Set<UInt32> = [
        // Greek capitals confusable with Latin capitals.
        0x0391, // Α GREEK CAPITAL LETTER ALPHA
        0x0392, // Β GREEK CAPITAL LETTER BETA
        0x0395, // Ε GREEK CAPITAL LETTER EPSILON
        0x0396, // Ζ GREEK CAPITAL LETTER ZETA
        0x0397, // Η GREEK CAPITAL LETTER ETA
        0x0399, // Ι GREEK CAPITAL LETTER IOTA
        0x039A, // Κ GREEK CAPITAL LETTER KAPPA
        0x039C, // Μ GREEK CAPITAL LETTER MU
        0x039D, // Ν GREEK CAPITAL LETTER NU
        0x039F, // Ο GREEK CAPITAL LETTER OMICRON
        0x03A1, // Ρ GREEK CAPITAL LETTER RHO
        0x03A4, // Τ GREEK CAPITAL LETTER TAU
        0x03A5, // Υ GREEK CAPITAL LETTER UPSILON
        0x03A7, // Χ GREEK CAPITAL LETTER CHI
        // Greek small omicron confusable with Latin o.
        0x03BF, // ο GREEK SMALL LETTER OMICRON
        // Cyrillic capitals confusable with Latin capitals.
        0x0410, 0x0412, 0x0415, 0x041A, 0x041C, 0x041D, 0x041E,
        0x0420, 0x0421, 0x0422, 0x0423, 0x0425,
        // Cyrillic smalls confusable with Latin smalls.
        0x0430, 0x0435, 0x043E, 0x0440, 0x0441, 0x0443, 0x0445
    ]
}
