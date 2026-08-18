// MonaStickyScrollFeature.swift
//
// P05-T152 — Implement retained feature stickyScroll.
//
// `MonaStickyScrollFeature` is the Swift counterpart of Monaco's `stickyScroll`
// contribution (monaco-editor 0.56.0, registered as
// `store.contrib.stickyScrollController`): it projects the nested symbol and
// folding context onto sticky viewport rows — the ancestor symbols of the line
// at the top of the viewport, stopping descent at a collapsed (folded) symbol.
//
// The feature reuses the Phase 05 document-symbols surface (P05-T115,
// `MonaDocumentSymbol`) for the nested outline and the Phase 05 folding surface
// (P05-T119, `MonaFoldingFeature.foldedRangesProjection() -> [MonaRange]`) for
// the collapsed subset. The host supplies both: a document-symbols result and
// the folded ranges; this feature projects them into sticky rows. It performs no
// symbol / folding computation of its own.
//
// Projection (frozen, derived from Monaco's `StickyScrollController`):
//   - A symbol is a sticky ancestor of `viewportTopLine` when its range start
//     is strictly above `viewportTopLine` and its range end is at or below it
//     (the symbol spans the viewport top but starts above it).
//   - The chain walks outermost → innermost. At each symbol, if the symbol's
//     range is in the folded set, the symbol is marked collapsed and descent
//     stops (its children are hidden by the fold); otherwise descent continues
//     into the child that spans `viewportTopLine`.
//   - The chain is capped to `stickyScroll.maxLineCount`, keeping the innermost
//     rows (the outermost are dropped), re-based to depth 0.
//   - When `stickyScroll.enabled` is false, the projection is empty.
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode`). It performs the three implementation operations every
// retained feature performs:
//
//   1. Feature-specific behavior — `projectStickyRows`, `presentation`,
//      `present`, `commitRevealStickyLine`, all reusing T115 document symbols +
//      T119 folding ranges.
//   2. Register the exact feature identity `stickyScroll` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import AppKit
import Foundation
import MonaCode

/// A sticky viewport row: the line number of the ancestor symbol, the symbol
/// itself, its nesting depth (0 = outermost), and whether the symbol is
/// collapsed (folded) — in which case descent stopped at it.
public struct MonaStickyScrollRow: Equatable {

    /// The 1-based line number of the ancestor symbol's range start.
    public let lineNumber: Int

    /// The ancestor document symbol.
    public let symbol: MonaDocumentSymbol

    /// The nesting depth (0 = outermost ancestor).
    public let depth: Int

    /// `true` when the symbol's range is in the folded set (descent stopped).
    public let isCollapsed: Bool

    public init(lineNumber: Int, symbol: MonaDocumentSymbol, depth: Int, isCollapsed: Bool) {
        self.lineNumber = lineNumber
        self.symbol = symbol
        self.depth = depth
        self.isCollapsed = isCollapsed
    }
}

/// The native AppKit sticky-scroll presentation: the rendered attributed
/// string (one symbol name per row), the projected rows, and whether the
/// presentation is visible (at least one sticky row was projected).
public struct MonaStickyScrollPresentation: Equatable {

    /// The rendered sticky rows as an attributed string (symbol names joined by
    /// newlines). Empty when no rows were projected.
    public let attributedString: NSAttributedString

    /// The projected sticky rows, outermost → innermost.
    public let rows: [MonaStickyScrollRow]

    /// `true` when at least one sticky row was projected.
    public let visible: Bool

    public init(attributedString: NSAttributedString, rows: [MonaStickyScrollRow], visible: Bool) {
        self.attributedString = attributedString
        self.rows = rows
        self.visible = visible
    }
}

/// A sticky-scroll event: the current presentation.
public struct MonaStickyScrollEvent: Equatable {

    /// The presentation after the change.
    public let presentation: MonaStickyScrollPresentation

    public init(presentation: MonaStickyScrollPresentation) {
        self.presentation = presentation
    }
}

/// The stickyScroll feature: project nested symbol + folding context into
/// sticky viewport rows.
///
/// The feature identity `stickyScroll` and its declared slice are referenced
/// verbatim from the frozen registries. The projection reuses the T115
/// document-symbols surface (`MonaDocumentSymbol`) and the T119 folding surface
/// (`foldedRangesProjection() -> [MonaRange]`); the host supplies both.
/// Revealing a sticky line routes a selection through
/// `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`.
public final class MonaStickyScrollFeature: MonaDisposable {

    /// The frozen feature identity (`"stickyScroll"`).
    public static let featureId = "stickyScroll"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce).
    /// stickyScroll declares no labeled editor actions — its commands carry no
    /// action labels.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs in source order (alphabetical, no rename /
    /// coalesce). The five sticky-scroll commands: focus, go-to-focused-line,
    /// select next / previous line, and toggle.
    public static let declaredCommandIds: [String] = [
        "editor.action.focusStickyScroll",
        "editor.action.goToFocusedStickyScrollLine",
        "editor.action.selectNextStickyScrollLine",
        "editor.action.selectPreviousStickyScrollLine",
        "editor.action.toggleStickyScroll"
    ]

    /// The declared contribution ID (`store.contrib.stickyScrollController`).
    public static let declaredContributionIds: [String] = [
        "store.contrib.stickyScrollController"
    ]

    /// The declared keybinding commands — the three sticky-scroll commands that
    /// carry a default keybinding in `MonaBuiltinKeybindings`. The focus and
    /// toggle commands carry no default keybinding.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.goToFocusedStickyScrollLine",
        "editor.action.selectNextStickyScrollLine",
        "editor.action.selectPreviousStickyScrollLine"
    ]

    /// The declared option name — `stickyScroll` (the object option carrying
    /// `enabled`, `maxLineCount`, `defaultModel`, `scrollWithEditor`).
    public static let declaredOptionIds: [String] = [
        "stickyScroll"
    ]

    /// The declared menu IDs — the three menus that carry sticky-scroll menu
    /// items: the command palette, the menubar appearance menu, and the sticky
    /// scroll context menu.
    public static let declaredMenuIds: [String] = [
        "CommandPalette",
        "MenubarAppearanceMenu",
        "StickyScrollContext"
    ]

    // MARK: - Routing state

    private var _currentPresentation: MonaStickyScrollPresentation = MonaStickyScrollPresentation(
        attributedString: NSAttributedString(),
        rows: [],
        visible: false
    )
    private let emitter = MonaEmitter<MonaStickyScrollEvent>()

    /// The event stream for sticky-scroll presentations. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaStickyScrollEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the stickyScroll feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// The current (last presented) presentation. Empty until the first
    /// successful `present(...)`.
    public var currentPresentation: MonaStickyScrollPresentation {
        _lock.lock(); defer { _lock.unlock() }
        return _currentPresentation
    }

    // MARK: - 1. Feature-specific behavior: project nested symbol + folding context

    /// Projects the nested symbol + folding context into sticky viewport rows
    /// for `viewportTopLine`, reading `stickyScroll.enabled` / `maxLineCount`
    /// from `options`. The chain walks outermost → innermost ancestor whose
    /// range spans `viewportTopLine`; descent stops at a collapsed (folded)
    /// symbol. The chain is capped to `maxLineCount`, keeping the innermost
    /// rows. Returns an empty array after `dispose()` or when sticky scroll is
    /// disabled.
    public func projectStickyRows(
        symbols: [MonaDocumentSymbol],
        foldedRanges: [MonaRange],
        viewportTopLine: Int,
        options: MonaOptionStore
    ) -> [MonaStickyScrollRow] {
        guard !isDisposed else { return [] }
        let stickyOpt = options.value(for: "stickyScroll")?.objectValue ?? [:]
        let enabled = stickyOpt["enabled"]?.boolValue ?? true
        guard enabled else { return [] }
        let maxLineCount = stickyOpt["maxLineCount"]?.intValue ?? 5
        let folded = Set(foldedRanges)
        var rows: [MonaStickyScrollRow] = []
        var current = symbols
        var depth = 0
        while let s = current.first(where: { Self.spans($0.range, viewportTopLine: viewportTopLine) }) {
            let collapsed = folded.contains(s.range)
            rows.append(MonaStickyScrollRow(
                lineNumber: s.range.startPosition.line,
                symbol: s,
                depth: depth,
                isCollapsed: collapsed
            ))
            if collapsed { break }
            depth += 1
            current = s.children
        }
        if rows.count > maxLineCount {
            let kept = Array(rows.suffix(maxLineCount))
            rows = kept.enumerated().map { index, row in
                MonaStickyScrollRow(
                    lineNumber: row.lineNumber,
                    symbol: row.symbol,
                    depth: index,
                    isCollapsed: row.isCollapsed
                )
            }
        }
        return rows
    }

    /// Returns `true` when `range` spans `viewportTopLine` (start strictly above,
    /// end at or below) — the symbol is a sticky ancestor of the viewport top.
    private static func spans(_ range: MonaRange, viewportTopLine: Int) -> Bool {
        return range.startPosition.line < viewportTopLine
            && range.endPosition.line >= viewportTopLine
    }

    /// Builds the native AppKit sticky-scroll presentation for `symbols` /
    /// `foldedRanges` at `viewportTopLine` under `options` and `profile`: the
    /// projected rows rendered as an attributed string (symbol names joined by
    /// newlines). The presentation is hidden (empty) after `dispose()` or when
    /// no rows were projected.
    public func presentation(
        for symbols: [MonaDocumentSymbol],
        foldedRanges: [MonaRange],
        options: MonaOptionStore,
        profile: MonaCodeEnvironmentProfile,
        viewportTopLine: Int
    ) -> MonaStickyScrollPresentation {
        guard !isDisposed else {
            return MonaStickyScrollPresentation(
                attributedString: NSAttributedString(),
                rows: [],
                visible: false
            )
        }
        let rows = projectStickyRows(
            symbols: symbols,
            foldedRanges: foldedRanges,
            viewportTopLine: viewportTopLine,
            options: options
        )
        guard !rows.isEmpty else {
            return MonaStickyScrollPresentation(
                attributedString: NSAttributedString(),
                rows: [],
                visible: false
            )
        }
        let font = NSFont.systemFont(ofSize: 11)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        let joined = rows.map { $0.symbol.name }.joined(separator: "\n")
        let attributed = NSAttributedString(string: joined, attributes: attrs)
        return MonaStickyScrollPresentation(
            attributedString: attributed,
            rows: rows,
            visible: true
        )
    }

    /// Presents the sticky-scroll rows when at least one row was projected,
    /// firing an event with the current presentation and retaining it as
    /// `currentPresentation`. Returns `true` when a presentation was fired;
    /// `false` when no rows were projected or after `dispose()`.
    @discardableResult
    public func present(
        using symbols: [MonaDocumentSymbol],
        foldedRanges: [MonaRange],
        options: MonaOptionStore,
        profile: MonaCodeEnvironmentProfile,
        viewportTopLine: Int
    ) -> Bool {
        guard !isDisposed else { return false }
        let presentation = self.presentation(
            for: symbols,
            foldedRanges: foldedRanges,
            options: options,
            profile: profile,
            viewportTopLine: viewportTopLine
        )
        guard presentation.visible else { return false }
        _lock.lock()
        _currentPresentation = presentation
        _lock.unlock()
        emitter.fire(MonaStickyScrollEvent(presentation: presentation))
        return true
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Reveals `row` through the shared transaction gateway: begins a
    /// transaction, prepares a collapsed selection at the row's line first
    /// column, and commits the unit. Returns the reconciliation outcome. A
    /// no-op after `dispose()` (returns `.dropped`).
    @discardableResult
    public func commitRevealStickyLine(
        _ row: MonaStickyScrollRow,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let position = MonaPosition(line: row.lineNumber, column: 1)
        let selection = MonaSelection(anchor: position, activePosition: position)
        let transaction = gateway.beginTransaction()
        transaction.prepareSelections([selection])
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `rows` through the shared provider executor, normalized onto the
    /// deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated. After
    /// `dispose()`, returns `false` and publishes nothing.
    @discardableResult
    public func publishStickyScroll(
        _ rows: [MonaStickyScrollRow],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaStickyScrollRow]) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        return executor.publish(
            .synchronous(rows),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the current presentation is cleared,
    /// and `projectStickyRows` / `presentation` / `present` /
    /// `commitRevealStickyLine` / `publishStickyScroll` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _currentPresentation = MonaStickyScrollPresentation(
            attributedString: NSAttributedString(),
            rows: [],
            visible: false
        )
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. stickyScroll declares no
    /// actions, so this returns an empty array under every profile.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. stickyScroll needs no tokenization; it
    /// degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — stickyScroll performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }
}
