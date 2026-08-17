// MonaCodiconFeature.swift
//
// P05-T107 — Implement retained feature codicon.
//
// `MonaCodiconFeature` is the Swift counterpart of Monaco's `codicon`
// contribution (monaco-editor 0.56.0): it resolves Codicon identifiers and
// licensed glyph assets through the theme registry. The Codicon font/icon set
// is the product-icon glyph source (776 glyphs, 34 deprecated aliases); this
// feature resolves an icon id to its definition, codepoint, and Unicode
// character, and exposes the licensed glyph-map provenance (artwork/font
// license, expected font hash, and font filename).
//
// Per the T1-R closure, the Core is Foundation-only and cannot load fonts
// (CoreText/NSFont live in AppKit). The 776 icon-id -> codepoint mapping is the
// primary exact domain; the TTF hash is a secondary gate. This feature resolves
// glyph IDENTIFIERS and the glyph map — it does NOT bundle the codicon.ttf
// binary (`fontBinaryBundled == false`); the font bytes are acquired by the
// rendering layer, where they must match `expectedFontSHA256`.
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode`). It performs the three implementation operations every
// retained feature performs:
//
//   1. Feature-specific behavior — `resolveCodicon`, `resolveCodepoint`,
//      `resolveCharacter`, `resolveGlyph`, and `resolve`, all resolved through
//      the theme registry (`MonaThemeRegistry` / `MonaIconRegistry` /
//      `MonaCodiconMap`).
//   2. Register the exact feature identity `codicon` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation boundary), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import AppKit
import Foundation
import MonaCode

/// A resolved Codicon glyph: the icon id, its codepoint hex, and the Unicode
/// character at that codepoint (following deprecated alias chains).
public struct MonaCodiconResolution: Equatable {

    /// The icon id that was resolved.
    public let id: String

    /// The Codicon codepoint as a lowercase hex string without the leading
    /// backslash (e.g. "ea60"), or `nil` for an unknown id.
    public let codepointHex: String?

    /// The Unicode character at the codepoint, or `nil` for an unknown id.
    public let character: Character?

    public init(id: String, codepointHex: String?, character: Character?) {
        self.id = id
        self.codepointHex = codepointHex
        self.character = character
    }
}

/// A codicon event: the glyph resolution delivered to listeners.
public struct MonaCodiconEvent: Equatable {

    /// The resolution delivered by this event.
    public let resolution: MonaCodiconResolution

    public init(resolution: MonaCodiconResolution) {
        self.resolution = resolution
    }
}

/// The codicon feature: resolve Codicon identifiers and licensed glyph assets
/// through the theme registry.
///
/// The feature identity `codicon` and its declared slice are referenced
/// verbatim from the frozen registries. codicon declares no commands, actions,
/// contributions, options, menus, or keybindings — it is the icon-font /
/// glyph-map feature. Asynchronous publication is routed through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`. codicon performs no text mutation; the
/// transaction gateway is the mutation boundary it would route through if it
/// mutated.
public final class MonaCodiconFeature: MonaDisposable {

    /// The frozen feature identity (`"codicon"`).
    public static let featureId = "codicon"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs. codicon declares no actions.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs. codicon declares no commands.
    public static let declaredCommandIds: [String] = []

    /// The declared contribution IDs. codicon declares no contributions.
    public static let declaredContributionIds: [String] = []

    /// The declared keybinding commands. codicon declares no keybindings.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names. codicon declares no options.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs. codicon declares no menu items.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The theme registry this feature resolves through (the active theme
    /// context for icon resolution).
    public let themeRegistry: MonaThemeRegistry

    private let emitter = MonaEmitter<MonaCodiconEvent>()

    /// The event stream for codicon resolutions. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaCodiconEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the codicon feature resolving through `themeRegistry` (a fresh
    /// registry booting on Monaco's standalone default, `vs-dark`, by default).
    public init(themeRegistry: MonaThemeRegistry = MonaThemeRegistry()) {
        self.themeRegistry = themeRegistry
    }

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: resolve identifiers + licensed glyph assets

    /// Resolves `id` to its builtin product-icon definition (the icon registry
    /// entry carrying the codepoint and any deprecated-alias target).
    public func resolveCodicon(id: String) -> MonaIconDefinition? {
        return MonaIconRegistry.definition(for: id)
    }

    /// Resolves `id` to its Codicon codepoint hex string, following deprecated
    /// alias chains. Returns `nil` if the id is unknown.
    public func resolveCodepoint(id: String) -> String? {
        return MonaIconRegistry.codepointHex(for: id)
    }

    /// Resolves `id` to its Codicon `Character` (the Unicode scalar at the
    /// codepoint's hex value), following alias chains.
    public func resolveCharacter(id: String) -> Character? {
        return MonaIconRegistry.character(for: id)
    }

    /// Resolves `id` to its Codicon glyph-map entry (the `MonaCodiconMap.Glyph`
    /// carrying the id and codepoint hex).
    public func resolveGlyph(id: String) -> MonaCodiconMap.Glyph? {
        return MonaCodiconMap.glyphs.first { $0.id == id }
    }

    /// Resolves `id` to a combined resolution (id + codepoint + character),
    /// following alias chains. Fires an event with the resolution. After
    /// `dispose()`, returns the resolution unchanged and fires no event.
    @discardableResult
    public func resolve(id: String) -> MonaCodiconResolution {
        let codepoint = resolveCodepoint(id: id)
        let character = resolveCharacter(id: id)
        let resolution = MonaCodiconResolution(id: id, codepointHex: codepoint, character: character)
        guard !isDisposed else { return resolution }
        emitter.fire(MonaCodiconEvent(resolution: resolution))
        return resolution
    }

    /// All 776 builtin Codicon icon ids in source-ordinal order.
    public var availableIconIds: [String] { MonaIconRegistry.ids }

    /// The number of deprecated alias icons (34).
    public var aliasCount: Int { MonaIconRegistry.aliases.count }

    // MARK: - Licensed glyph assets (font provenance — NOT the font bytes)

    /// The Codicon font filename (`"codicon.ttf"`).
    public var fontFilename: String { MonaCodiconMap.fontFilename }

    /// The contract-pinned expected SHA-256 of the codicon.ttf binary. The
    /// rendering layer must acquire font bytes matching this hash; this feature
    /// does NOT bundle the font bytes.
    public var expectedFontSHA256: String { MonaCodiconMap.expectedFontSHA256 }

    /// The contract-pinned expected size of the codicon.ttf binary in bytes.
    public var expectedFontSizeBytes: Int { MonaCodiconMap.expectedFontSizeBytes }

    /// `false` — the codicon.ttf binary is NOT bundled at this layer. This
    /// feature resolves glyph IDENTIFIERS and the glyph map; the font bytes are
    /// acquired by the AppKit rendering layer.
    public var fontBinaryBundled: Bool { false }

    /// The license provenance for the Codicon font/icon set (CC BY 4.0
    /// artwork/font license, MIT generator/code license, and the upstream
    /// Monaco MIT notice).
    public var licensedGlyphAssets: MonaCodiconProvenance { MonaCodiconMap.provenance }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `resolution` through the shared provider executor, normalized
    /// onto the deterministic microtask queue. `receive` runs ONLY when the
    /// queue is drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishResolution(
        _ resolution: MonaCodiconResolution,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaCodiconResolution) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(resolution),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped and `resolve(id:)` fires no event
    /// (it still returns the resolution).
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. codicon declares no actions,
    /// so the list is empty — but the routing path is wired.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. codicon needs no tokenization; it
    /// degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — codicon performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }
}
