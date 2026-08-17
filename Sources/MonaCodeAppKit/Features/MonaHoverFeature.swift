// MonaHoverFeature.swift
//
// P05-T125 — Implement retained feature hover.
//
// `MonaHoverFeature` is the Swift counterpart of Monaco's `hover` contribution
// (monaco-editor 0.56.0): it merges, renders, updates the verbosity level of,
// and releases hover provider results. A hover is a list of contents
// (markdown / plain marked strings) paired with an optional range; multiple
// provider results are merged into one hover (contents concatenated in
// provider order, first non-nil range wins), rendered to an `NSAttributedString`
// for display, and their owned provider resources released exactly once on
// publication through the shared `MonaProviderExecutor` (P05-T013) using its
// `.releasable` result shape.
//
// Verbosity is the language-hover verbosity level (Monaco's
// `HoverVerbosityRequest` / `increaseHoverVerbosityLevel` /
// `decreaseHoverVerbosityLevel`): an `Int` level that starts at 0, increases on
// `increaseVerbosity()`, decreases on `decreaseVerbosity()` (clamped at 0), and
// fires a hover event on change. The hover's range is revealed through the
// shared `MonaTransactionGateway` when the user navigates to it.
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode` — the render step produces an `NSAttributedString`). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `mergeHovers(_:)`: merge provider results
//      (concatenate contents, first non-nil range); `renderHover(_:)`: render
//      to `NSAttributedString`; `renderPlainText(_:)`: plain-text render via
//      `MonaPlainTextLanguage`; `increaseVerbosity()` / `decreaseVerbosity()` /
//      `setVerbosityLevel(_:)`: update verbosity; `releaseHover(_:owned:)`:
//      release owned provider resources exactly once.
//   2. Register the exact feature identity `hover` and its declared commands,
//      actions, contributions, options, menus, and keybindings, referenced
//      verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication, releasable shape),
//      `MonaEmitter` (disposal), `MonaLocalization` (localization), and
//      `MonaPlainTextLanguage` (degraded plain text). No parallel mechanisms
//      are introduced.

import AppKit
import Foundation
import MonaCode

/// A single hover content entry: a marked string that is either markdown or
/// plain text. Mirrors Monaco's `MarkedString` / `MarkdownString` hover content
/// union (monaco-editor 0.56.0).
public struct MonaHoverContent: Equatable {

    /// The content text.
    public let text: String

    /// `true` when `text` is markdown; `false` when it is plain text.
    public let isMarkdown: Bool

    /// Creates a hover content entry.
    public init(text: String, isMarkdown: Bool) {
        self.text = text
        self.isMarkdown = isMarkdown
    }
}

/// A hover: a list of contents paired with an optional range. Mirrors Monaco's
/// `Hover` (monaco-editor 0.56.0). Multiple provider hovers are merged into
/// one by `MonaHoverFeature.mergeHovers(_:)`.
public struct MonaHover: Equatable {

    /// The contents (markdown / plain marked strings), in provider order.
    public let contents: [MonaHoverContent]

    /// The range the hover applies to, or `nil` when the hover has no range
    /// (the editor falls back to the word at the current position).
    public let range: MonaRange?

    /// Creates a hover.
    public init(contents: [MonaHoverContent], range: MonaRange? = nil) {
        self.contents = contents
        self.range = range
    }
}

/// A hover event: the staged hover and the current verbosity level. Fired on
/// verbosity change and on stage. `hover` is `nil` when the event is a
/// verbosity-only change with no staged hover.
public struct MonaHoverEvent: Equatable {

    /// The staged hover, or `nil` when no hover is staged.
    public let hover: MonaHover?

    /// The verbosity level in effect after the change.
    public let verbosityLevel: Int

    /// Creates a hover event.
    public init(hover: MonaHover?, verbosityLevel: Int) {
        self.hover = hover
        self.verbosityLevel = verbosityLevel
    }
}

/// The hover feature: merge, render, update verbosity, and release hover
/// provider results.
///
/// The feature identity `hover` and its declared slice are referenced verbatim
/// from the frozen registries. `mergeHovers(_:)` concatenates contents in
/// provider order and takes the first non-nil range; `renderHover(_:)` produces
/// an `NSAttributedString`; `renderPlainText(_:)` degrades through
/// `MonaPlainTextLanguage`; verbosity is an `Int` level clamped at 0;
/// `releaseHover(_:owned:)` releases owned provider resources exactly once;
/// `publishHover(_:executor:ticket:owned:receive:)` publishes through the
/// `MonaProviderExecutor` using its `.releasable` shape. Model mutation is
/// routed through `MonaTransactionGateway`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`.
public final class MonaHoverFeature: MonaDisposable {

    /// The frozen feature identity (`"hover"`).
    public static let featureId = "hover"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The
    /// thirteen labeled hover actions (ordinals 113–125): show/focus, definition
    /// preview, hide, the eight scroll/page/go-to-top/bottom navigations, and
    /// the two verbosity-level actions.
    public static let declaredActionIds: [String] = [
        "editor.action.showHover",
        "editor.action.showDefinitionPreviewHover",
        "editor.action.hideHover",
        "editor.action.scrollUpHover",
        "editor.action.scrollDownHover",
        "editor.action.scrollLeftHover",
        "editor.action.scrollRightHover",
        "editor.action.pageUpHover",
        "editor.action.pageDownHover",
        "editor.action.goToTopHover",
        "editor.action.goToBottomHover",
        "editor.action.increaseHoverVerbosityLevel",
        "editor.action.decreaseHoverVerbosityLevel"
    ]

    /// The declared command IDs in source order. These are the hover command
    /// set: the two provider-execute commands, the thirteen action commands,
    /// and the long-line-warning hide command.
    public static let declaredCommandIds: [String] = [
        "_executeHoverProvider",
        "_executeHoverProvider_recursive",
        "editor.action.showHover",
        "editor.action.showDefinitionPreviewHover",
        "editor.action.hideHover",
        "editor.action.scrollUpHover",
        "editor.action.scrollDownHover",
        "editor.action.scrollLeftHover",
        "editor.action.scrollRightHover",
        "editor.action.pageUpHover",
        "editor.action.pageDownHover",
        "editor.action.goToTopHover",
        "editor.action.goToBottomHover",
        "editor.action.increaseHoverVerbosityLevel",
        "editor.action.decreaseHoverVerbosityLevel",
        "editor.action.hideLongLineWarningHover"
    ]

    /// The declared contribution IDs. The two hover contributions: the content
    /// hover widget and the margin hover widget.
    public static let declaredContributionIds: [String] = [
        "editor.contrib.contentHover",
        "editor.contrib.marginHover"
    ]

    /// The declared keybinding commands — the nine hover actions that carry a
    /// default keybinding in `MonaBuiltinKeybindings` (show, the four scrolls,
    /// the two pages, and go-to-top/bottom), in declared action order.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.showHover",
        "editor.action.scrollUpHover",
        "editor.action.scrollDownHover",
        "editor.action.scrollLeftHover",
        "editor.action.scrollRightHover",
        "editor.action.pageUpHover",
        "editor.action.pageDownHover",
        "editor.action.goToTopHover",
        "editor.action.goToBottomHover"
    ]

    /// The declared option names — the hover editor option (`hover`, an object
    /// carrying `delay`, `enabled`, `hidingDelay`, `showLongLineWarning`,
    /// `sticky`, and `above`).
    public static let declaredOptionIds: [String] = [
        "hover"
    ]

    /// The declared menu IDs — hover registers no menu items, so this slice is
    /// empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The staged hover (set by `stageHover(_:)`), or `nil` when none is staged.
    private var stagedHover: MonaHover? = nil

    /// The current verbosity level (clamped at 0).
    private var _verbosityLevel: Int = 0

    private let emitter = MonaEmitter<MonaHoverEvent>()

    /// The event stream for hover changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaHoverEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the hover feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// The current verbosity level (clamped at 0).
    public var verbosityLevel: Int {
        _lock.lock(); defer { _lock.unlock() }
        return _verbosityLevel
    }

    // MARK: - 1. Feature-specific behavior: merge + render + verbosity + release

    /// Merges `hovers` into one hover: contents are concatenated in provider
    /// order (the order received — no re-sort), and the first non-nil `range`
    /// wins. An empty input returns an empty hover with no range. A no-op after
    /// `dispose()` (returns an empty hover).
    public func mergeHovers(_ hovers: [MonaHover]) -> MonaHover {
        guard !isDisposed else { return MonaHover(contents: [], range: nil) }
        var contents: [MonaHoverContent] = []
        var range: MonaRange? = nil
        for hover in hovers {
            contents.append(contentsOf: hover.contents)
            if range == nil, let r = hover.range {
                range = r
            }
        }
        return MonaHover(contents: contents, range: range)
    }

    /// Renders `hover` to an `NSAttributedString` for display. Markdown
    /// contents are rendered with a bold attribute to distinguish them from
    /// plain contents; entries are joined with a newline. Returns an empty
    /// attributed string after `dispose()`.
    public func renderHover(_ hover: MonaHover) -> NSAttributedString {
        guard !isDisposed else { return NSAttributedString() }
        let result = NSMutableAttributedString()
        let bold = NSFont.boldSystemFont(ofSize: 0)
        let plain = NSFont.systemFont(ofSize: 0)
        for (index, content) in hover.contents.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n"))
            }
            let attrs: [NSAttributedString.Key: Any] =
                content.isMarkdown
                ? [.font: bold]
                : [.font: plain]
            result.append(NSAttributedString(string: content.text, attributes: attrs))
        }
        return result
    }

    /// Renders `hover` to a plain-text string, joining contents with a newline.
    /// This is the degraded render path through `MonaPlainTextLanguage` — hover
    /// needs no tokenization and degrades to plain text for rendering.
    public func renderPlainText(_ hover: MonaHover) -> String {
        guard !isDisposed else { return "" }
        return hover.contents.map { $0.text }.joined(separator: "\n")
    }

    /// Stages `hover` for reveal (the hover whose range `commitReveal(_:)`
    /// will reveal). A no-op after `dispose()`.
    public func stageHover(_ hover: MonaHover) {
        guard !isDisposed else { return }
        _lock.lock()
        stagedHover = hover
        _lock.unlock()
        fire(.init(hover: hover, verbosityLevel: verbosityLevel))
    }

    /// Increases the verbosity level by one and fires a verbosity-change event.
    /// A no-op after `dispose()`.
    public func increaseVerbosity() {
        guard !isDisposed else { return }
        _lock.lock()
        _verbosityLevel += 1
        let level = _verbosityLevel
        let staged = stagedHover
        _lock.unlock()
        fire(.init(hover: staged, verbosityLevel: level))
    }

    /// Decreases the verbosity level by one, clamped at 0, and fires a
    /// verbosity-change event. A no-op after `dispose()`.
    public func decreaseVerbosity() {
        guard !isDisposed else { return }
        _lock.lock()
        _verbosityLevel = Swift.max(0, _verbosityLevel - 1)
        let level = _verbosityLevel
        let staged = stagedHover
        _lock.unlock()
        fire(.init(hover: staged, verbosityLevel: level))
    }

    /// Sets the verbosity level to `level`, clamped at 0, and fires a
    /// verbosity-change event. A no-op after `dispose()`.
    public func setVerbosityLevel(_ level: Int) {
        guard !isDisposed else { return }
        _lock.lock()
        _verbosityLevel = Swift.max(0, level)
        let staged = stagedHover
        let resolved = _verbosityLevel
        _lock.unlock()
        fire(.init(hover: staged, verbosityLevel: resolved))
    }

    /// Releases the owned provider resources in `owned` exactly once (each
    /// `MonaDisposable.dispose()` is idempotent). Returns `true` when at least
    /// one owned resource was released, `false` when `owned` is empty or the
    /// feature is disposed. This is the standalone release path for dismissing
    /// a hover without publication; `publishHover(_:executor:ticket:owned:receive:)`
    /// releases the same list on publication through the `.releasable` shape.
    @discardableResult
    public func releaseHover(_ hover: MonaHover, owned: [MonaDisposable]) -> Bool {
        guard !isDisposed, !owned.isEmpty else { return false }
        for disposable in owned {
            disposable.dispose()
        }
        return true
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Reveals the staged hover's range through the shared transaction gateway:
    /// begins a transaction, prepares a collapsed selection at the staged
    /// hover's range start position, and commits the unit. Returns the
    /// committed selections (empty when the feature is disposed, no hover is
    /// staged, the staged hover has no range, or the commit dropped).
    @discardableResult
    public func commitReveal(gateway: MonaTransactionGateway) -> [MonaSelection] {
        guard !isDisposed else { return [] }
        _lock.lock()
        let position = stagedHover?.range?.startPosition
        _lock.unlock()
        guard let position = position else { return [] }
        let tx = gateway.beginTransaction()
        let selection = MonaSelection(anchor: position, activePosition: position)
        tx.prepareSelections([selection])
        _ = gateway.commit(tx)
        return gateway.lastCommittedSelections
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `hover` through the shared provider executor using its
    /// `.releasable` result shape, normalized onto the deterministic microtask
    /// queue. The owned provider resources in `owned` are released exactly once
    /// after publication (on `drain()`). `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated. A stale /
    /// cancelled ticket drops the publication silently but still releases
    /// `owned` exactly once.
    @discardableResult
    public func publishHover(
        _ hover: MonaHover,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        owned: [MonaDisposable],
        receive: @escaping (MonaHover) -> Void
    ) -> Bool {
        return executor.publish(
            .releasable(hover, owned),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the staged hover is cleared, and
    /// `mergeHovers` / `renderHover` / `stageHover` / `increaseVerbosity` /
    /// `releaseHover` / `commitReveal` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        stagedHover = nil
        _verbosityLevel = 0
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. hover needs no tokenization; it
    /// degrades to plain text for its rendering needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — hover performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a hover event when not disposed.
    private func fire(_ event: MonaHoverEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
