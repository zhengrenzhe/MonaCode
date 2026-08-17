// MonaColorizeView.swift
//
// P05-T010 — Implement editor.colorizeElement as a native view mutation replacement.
//
// `MonaColorizeView` is the native view-mutation replacement for Monaco's
// `editor.colorizeElement` API. Monaco's original `colorizeElement` takes a
// DOM `HTMLElement`, reads its text content, colorizes it into a `<div>` of
// `<span>` runs with inline CSS classes, and replaces the element's
// `innerHTML`. MonaCode is a native macOS/AppKit port: the replacement applies
// a `MonaColorizeSource`'s (P05-T009) attributed token presentation to a frozen
// AppKit-native text host (`MonaColorizeHost` carrying an `NSTextStorage`) —
// no web element, no DOM, no CSS.
//
// The three load-bearing behaviors (matching the spec's implementation ops):
//
//   1. Apply attributed token presentation to an explicit native text host.
//      `render(source:)` colorizes the raw UTF-16 source via the attached
//      `MonaColorizeSource` and replaces the host's `NSTextStorage` with the
//      resulting `NSAttributedString`. The host (not a DOM element) displays
//      the attributed text.
//
//   2. Update only changed theme and token ranges and dispose every
//      observation with the host lifetime. When the active theme
//      (P05-T006 `MonaThemeRegistry`) or the source tokens change, the view
//      re-applies ONLY the ranges whose resolved foreground color actually
//      changed — NOT a full re-render. Theme changes are observed via the
//      registry's `onDidChangeTheme` emitter; token changes are driven by an
//      explicit `refresh()` (e.g. after swapping the token provider). Every
//      observation is disposed in `detach()` (idempotent, reusing
//      `MonaEmitter`'s idempotent `MonaDisposable` — the same pattern as
//      P04-T014's `MonaEditorAttachment`).
//
//   3. Replace the web element parameter with the frozen AppKit-native type
//      adaptation. Monaco's `colorizeElement(element: HTMLElement, …)` takes a
//      DOM element; the native replacement takes a frozen AppKit-native
//      `MonaColorizeHost` (not a DOM/CSS element). No web element, no DOM, no
//      CSS.
//
// `@MainActor` isolation: the view is main-actor-isolated (matching the
// `NSTextStorage` it mutates), so the non-Sendable `NSTextStorage` never
// crosses an actor boundary. The theme-change subscription closure is
// `@Sendable` (non-isolated) to match the `MonaEvent` closure type; it hops
// back to the main actor via `MainActor.assumeIsolated` before touching any
// main-actor state — exactly the pattern P04-T014's `MonaEditorAttachment`
// uses. The theme registry fires its emitter synchronously on the calling
// thread, and in an AppKit host the theme is always switched on the main
// thread, so `assumeIsolated` is safe.
//
// `MonaCodeAppKit` may `import AppKit`, `import Foundation`, `import MonaCode`.

import AppKit
import Foundation
import MonaCode

// MARK: - MonaColorizeHost

/// The frozen AppKit-native text host — the native replacement for Monaco's
/// DOM `HTMLElement` parameter in `editor.colorizeElement`.
///
/// Monaco's `colorizeElement(element: HTMLElement, …)` takes a DOM element;
/// the native replacement takes a `MonaColorizeHost`. The host carries an
/// `NSTextStorage` — AppKit's native attributed-text backing store — to which
/// `MonaColorizeView` applies the colorized attributed string. No web element,
/// no DOM, no CSS.
///
/// Construct with `init()` (a fresh, empty `NSTextStorage`) or
/// `init(textStorage:)` to supply an existing text storage (e.g. one shared
/// with an `NSTextView`).
public final class MonaColorizeHost {

    /// The AppKit-native attributed-text backing store the host displays.
    /// `MonaColorizeView` mutates this storage on render and incremental
    /// updates.
    public let textStorage: NSTextStorage

    /// Creates a host with a fresh, empty `NSTextStorage`.
    public init() {
        self.textStorage = NSTextStorage()
    }

    /// Creates a host wrapping the given `NSTextStorage` (e.g. one shared with
    /// an `NSTextView` so colorization is reflected in a live text view).
    public init(textStorage: NSTextStorage) {
        self.textStorage = textStorage
    }
}

// MARK: - MonaColorizeView

/// The native view-mutation replacement for Monaco's `editor.colorizeElement`.
///
/// Construct with `init(source:host:)`. Call `render(source:)` with the raw
/// UTF-16 source to apply the colorized attributed text to the host. On theme
/// change (observed via `MonaThemeRegistry.onDidChangeTheme`), the view
/// re-applies ONLY the token ranges whose resolved foreground color changed —
/// NOT a full re-render. Call `refresh()` after swapping the token provider to
/// incrementally re-apply changed token ranges. Call `detach()` to dispose
/// every observation (idempotent).
///
/// The host is the frozen AppKit-native `MonaColorizeHost` — never a DOM
/// element. The output is always a native `NSAttributedString` applied to the
/// host's `NSTextStorage` — never HTML, never a DOM/CSS renderer artifact.
@MainActor
public final class MonaColorizeView {

    // MARK: - Configuration

    /// The colorize source (P05-T009) producing the attributed string applied
    /// to the host. Holds the theme registry used to resolve token colors.
    public let source: MonaColorizeSource

    /// The frozen AppKit-native text host the view applies colorized text to.
    public let host: MonaColorizeHost

    // MARK: - Subscriptions

    /// Every observation registered while attached. Disposed in `detach()`
    /// BEFORE the view tears down. `MonaDisposable.dispose()` is idempotent
    /// (the base-layer `MonaDisposableImpl` runs its action at most once), so
    /// disposing twice (detach then deinit) is safe.
    private var disposables: [MonaDisposable] = []

    /// `true` while the theme-change observation is attached.
    private var attached: Bool = false

    // MARK: - Last-render state (for incremental diffing)

    /// The last rendered raw UTF-16 source units. Empty before the first
    /// render.
    private var lastUnits: [UInt16] = []

    /// The tokens resolved against `lastUnits` at the last render/refresh.
    private var lastTokens: [MonaColorToken] = []

    /// The resolved foreground hex string (from the active theme's rule) for
    /// each token in `lastTokens`, at the last render/refresh. Diffed against
    /// the newly resolved hex on theme/token change to find the ranges whose
    /// color actually changed.
    private var lastTokenHex: [String?] = []

    // MARK: - Test observability

    /// The number of FULL re-renders (complete `NSTextStorage` replacement)
    /// performed. Incremental updates do NOT bump this. Used by tests to
    /// verify a full re-render does NOT happen on theme/token change.
    internal private(set) var fullRerenderCount: Int = 0

    /// The ranges incrementally re-applied in the last incremental pass. Empty
    /// after a full re-render or when no ranges changed. Used by tests to
    /// verify only changed ranges were re-applied.
    internal private(set) var lastIncrementalRanges: [NSRange] = []

    // MARK: - Init

    /// Creates a colorize view binding `source` to `host`. Subscribes to the
    /// source's theme registry's `onDidChangeTheme` emitter so theme changes
    /// trigger incremental re-application.
    public init(source: MonaColorizeSource, host: MonaColorizeHost) {
        self.source = source
        self.host = host
        attach()
    }

    // MARK: - Render (full)

    /// Renders `units` into the host as a FULL render: colorizes the source via
    /// `MonaColorizeSource.colorize(source:)`, replaces the host's entire
    /// `NSTextStorage` with the attributed result, and caches the token layout
    /// for subsequent incremental updates.
    ///
    /// Use this for the initial render or when the source TEXT changes (a text
    /// change is inherently a full re-render). For theme/token-only changes,
    /// use `refresh()` (incremental).
    public func render(source units: [UInt16]) {
        let attr = self.source.colorize(source: units)
        applyFullRender(attr)

        lastUnits = units
        let tokens = self.source.directTokenProvider?.tokens(for: units) ?? []
        lastTokens = tokens
        lastTokenHex = resolvedHex(for: tokens)

        fullRerenderCount &+= 1
        lastIncrementalRanges = []
    }

    // MARK: - Refresh (incremental)

    /// Re-applies only the token ranges whose resolved foreground color changed
    /// since the last render/refresh. Called automatically on theme change;
    /// also callable manually after swapping the token provider (token change).
    ///
    /// If the token BOUNDARIES changed (different count or offsets), this falls
    /// back to a full re-render — incremental applies only when boundaries are
    /// stable and only colors differ.
    public func refresh() {
        guard !lastUnits.isEmpty else { return }
        reapplyChangedRanges()
    }

    // MARK: - Detach

    /// Detaches every observation (the theme-change subscription). Idempotent.
    /// After detach, theme/token changes no longer mutate the host. The host
    /// and source are NOT disposed — only the observations are removed.
    public func detach() {
        guard attached else { return }
        for disposable in disposables {
            disposable.dispose()
        }
        disposables.removeAll()
        attached = false
    }

    // MARK: - Deinit

    // The view has no deinit of its own: its `disposables` array is
    // main-actor-isolated (non-Sendable — `MonaDisposable` is `AnyObject`
    // without `Sendable` conformance), so it cannot be touched from a
    // non-isolated `deinit` (Swift 6 enforces this). The authoritative
    // teardown is `detach()` — the owner calls it before releasing the view.
    // `detach()` is idempotent, so calling it more than once is a safe no-op.
    //
    // If the owner forgets `detach()`, the theme-change subscription closure
    // captures `self` weakly (`[weak self]`), so when the view is deallocated
    // the handler becomes inert (reads `nil`) — no crash, no incorrect
    // mutation. The lingering listener entry is cleaned up when the emitter
    // (owned by the theme registry, typically co-owned with the source/host)
    // is itself deallocated. This matches the P04-T014 `MonaEditorAttachment`
    // pattern exactly.

    // MARK: - Theme observation

    /// Subscribes to the source's theme registry `onDidChangeTheme` emitter.
    /// The closure is `@Sendable` (non-isolated) to match the `MonaEvent`
    /// closure type; it hops back to the main actor via
    /// `MainActor.assumeIsolated` before touching any main-actor state — the
    /// same pattern as P04-T014's `MonaEditorAttachment`. The registry fires
    /// synchronously on the calling thread, which in an AppKit host is the main
    /// thread, so `assumeIsolated` is safe.
    private func attach() {
        guard !attached else { return }
        attached = true

        let handler: @Sendable (MonaThemeChange) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleThemeChange()
            }
        }
        disposables.append(source.themeRegistry.onDidChangeTheme(handler))
    }

    /// Invoked (on the main actor) when the active theme switches. Re-applies
    /// only the changed token ranges — NOT a full re-render.
    private func handleThemeChange() {
        guard !lastUnits.isEmpty else { return }
        reapplyChangedRanges()
    }

    // MARK: - Incremental re-application

    /// Re-resolves the token foreground colors against the (possibly new)
    /// theme and re-applies ONLY the ranges whose color actually changed. If
    /// the token boundaries changed, falls back to a full re-render.
    private func reapplyChangedRanges() {
        let tokens = source.directTokenProvider?.tokens(for: lastUnits) ?? []
        let newHex = resolvedHex(for: tokens)

        // If the token BOUNDARIES changed (different count or offsets), fall
        // back to a full re-render — incremental applies only when boundaries
        // are stable and only colors differ.
        let boundariesStable = tokens.count == lastTokens.count
            && zip(tokens, lastTokens).allSatisfy {
                $0.startUTF16 == $1.startUTF16 && $0.endUTF16 == $1.endUTF16
            }

        guard boundariesStable else {
            let attr = source.colorize(source: lastUnits)
            applyFullRender(attr)
            lastTokens = tokens
            lastTokenHex = newHex
            fullRerenderCount &+= 1
            lastIncrementalRanges = []
            return
        }

        // Same boundaries — apply ONLY the ranges whose color changed.
        var changedRanges: [NSRange] = []
        var edits: [(range: NSRange, color: NSColor)] = []
        let length = host.textStorage.length
        for i in 0..<tokens.count {
            let oldHex = lastTokenHex[i]
            let newHexI = newHex[i]
            // Skip unchanged colors (nil → nil, or same hex → same hex).
            guard let hex = newHexI, hex != oldHex else { continue }
            guard let color = MonaColorizeSource.nsColor(fromHex: hex) else { continue }
            let start = max(0, min(tokens[i].startUTF16, length))
            let end = max(start, min(tokens[i].endUTF16, length))
            guard end > start else { continue }
            let range = NSRange(location: start, length: end - start)
            changedRanges.append(range)
            edits.append((range: range, color: color))
        }

        guard !edits.isEmpty else {
            // No color changed — not even an incremental update.
            lastTokens = tokens
            lastTokenHex = newHex
            lastIncrementalRanges = []
            return
        }

        // Apply only the changed ranges to the host's text storage, coalesced
        // in a single editing transaction.
        host.textStorage.beginEditing()
        for edit in edits {
            host.textStorage.addAttribute(.foregroundColor,
                                            value: edit.color,
                                            range: edit.range)
        }
        host.textStorage.endEditing()

        lastTokens = tokens
        lastTokenHex = newHex
        lastIncrementalRanges = changedRanges
    }

    // MARK: - Full render

    /// Replaces the host's entire `NSTextStorage` with `attr` in a single
    /// editing transaction.
    private func applyFullRender(_ attr: NSAttributedString) {
        let storage = host.textStorage
        storage.beginEditing()
        if storage.length > 0 {
            storage.replaceCharacters(
                in: NSRange(location: 0, length: storage.length),
                with: attr
            )
        } else {
            storage.append(attr)
        }
        storage.endEditing()
    }

    // MARK: - Color resolution

    /// Resolves the foreground hex string for each token against the active
    /// theme's rule. Returns `nil` for tokens whose scope has no rule or no
    /// foreground.
    private func resolvedHex(for tokens: [MonaColorToken]) -> [String?] {
        let theme = source.themeRegistry.currentTheme
        return tokens.map { theme.rule(for: $0.scope)?.foreground }
    }
}
