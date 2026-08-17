// MonaIndentationFeature.swift
//
// P05-T126 — Implement retained feature indentation.
//
// `MonaIndentationFeature` is the Swift counterpart of Monaco's `indentation`
// contribution (monaco-editor 0.56.0): it detects, converts, and reindents
// whitespace from explicit model options. Indentation is governed by the
// text-model options `tabSize`, `indentSize`, and `insertSpaces` (P01-T008
// `MonaModelOptions`) plus the editor-level indentation options `autoIndent`,
// `autoIndentOnPaste`, and `autoIndentOnPasteWithinString` (read through
// P05-T005 `MonaOptionStore`). The feature performs no model mutation of its
// own — reindent edits are routed through `MonaTransactionGateway` as one
// ordered unit; detection results are published through `MonaProviderExecutor`
// + `MonaMicrotaskQueue` (P05-T013).
//
// Detection scans leading whitespace per line: a space-led majority picks
// `insertSpaces = true` (with the modal leading-space count as `tabSize`); a
// tab-led majority picks `insertSpaces = false` (with the default `tabSize`).
// Conversion expands tabs to tab-stop spaces (`convertToSpaces`) and collapses
// leading spaces to tabs+remainder (`convertToTabs`). `reindentLines` normalizes
// each line's leading whitespace per the model options, reusing
// `normalizeWhitespace` (which mirrors `MonaCodeModel.normalizeWhitespaceUnits`).
//
// The feature is a Foundation-only surface (`import Foundation` only — the
// indentation types live in the MonaCode module). It performs the three
// implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `detectIndentation(_:defaultInsertSpaces:
//      defaultTabSize:)`: detect from content; `convertToSpaces(_:tabSize:)` /
//      `convertToTabs(_:tabSize:)`: convert; `normalizeWhitespace(_:options:)`:
//      normalize a whitespace run per model options; `reindentLines(_:options:)`:
//      reindent each line; `readIndentationOptions(from:)`: read editor-level
//      indentation options from `MonaOptionStore`.
//   2. Register the exact feature identity `indentation` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// An indentation-detection result: whether indentation uses spaces and the
/// detected tab size. Produced by `MonaIndentationFeature.detectIndentation`.
public struct MonaIndentationDetection: Equatable, Sendable {

    /// `true` when indentation should use spaces; `false` for tabs.
    public let insertSpaces: Bool

    /// The detected tab size (number of spaces a tab represents).
    public let tabSize: Int

    /// Creates a detection result.
    public init(insertSpaces: Bool, tabSize: Int) {
        self.insertSpaces = insertSpaces
        self.tabSize = tabSize
    }
}

/// The editor-level indentation options read from `MonaOptionStore` (P05-T005).
/// These are the editor options that govern auto-indentation behavior, distinct
/// from the model options (`tabSize` / `insertSpaces` / `indentSize`) that govern
/// whitespace normalization.
public struct MonaIndentationEditorOptions: Equatable, Sendable {

    /// The auto-indent mode (`"none"`, `"keep"`, `"brackets"`, `"advanced"`,
    /// `"full"`).
    public let autoIndent: String

    /// `true` when pasted text is auto-indented to match the surrounding context.
    public let autoIndentOnPaste: Bool

    /// `true` when auto-indent-on-paste applies inside string literals.
    public let autoIndentOnPasteWithinString: Bool

    /// Creates the editor-level indentation options.
    public init(
        autoIndent: String,
        autoIndentOnPaste: Bool,
        autoIndentOnPasteWithinString: Bool
    ) {
        self.autoIndent = autoIndent
        self.autoIndentOnPaste = autoIndentOnPaste
        self.autoIndentOnPasteWithinString = autoIndentOnPasteWithinString
    }
}

/// An indentation event: the staged detection result. Fired on
/// `stageDetection(_:)`.
public struct MonaIndentationEvent: Equatable {

    /// The staged detection result, or `nil` when none is staged.
    public let detection: MonaIndentationDetection?

    /// Creates an indentation event.
    public init(detection: MonaIndentationDetection?) {
        self.detection = detection
    }
}

/// The indentation feature: detect, convert, and reindent whitespace from
/// explicit model options.
///
/// The feature identity `indentation` and its declared slice are referenced
/// verbatim from the frozen registries. `detectIndentation` scans leading
/// whitespace per line (space-led vs tab-led majority); `convertToSpaces` /
/// `convertToTabs` convert tabs↔spaces; `reindentLines` normalizes each line's
/// leading whitespace per the model options (reusing `normalizeWhitespace`,
/// which mirrors `MonaCodeModel.normalizeWhitespaceUnits`); and
/// `readIndentationOptions` reads the editor-level indentation options from
/// `MonaOptionStore`. Model mutation is routed through `MonaTransactionGateway`;
/// asynchronous publication through `MonaProviderExecutor` +
/// `MonaMicrotaskQueue`; disposal through `MonaEmitter`; localization through
/// `MonaLocalization`; and degraded plain-text behavior through
/// `MonaPlainTextLanguage`.
public final class MonaIndentationFeature: MonaDisposable {

    /// The frozen feature identity (`"indentation"`).
    public static let featureId = "indentation"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The
    /// nine labeled indentation actions (ordinals 82, 83, 126–129, 131–133):
    /// indent/outdent lines, convert to spaces/tabs, indent using tabs/spaces,
    /// detect indentation, and reindent (all / selected) lines.
    public static let declaredActionIds: [String] = [
        "editor.action.indentLines",
        "editor.action.outdentLines",
        "editor.action.indentationToSpaces",
        "editor.action.indentationToTabs",
        "editor.action.indentUsingTabs",
        "editor.action.indentUsingSpaces",
        "editor.action.detectIndentation",
        "editor.action.reindentlines",
        "editor.action.reindentselectedlines"
    ]

    /// The declared command IDs in source order. The nine indentation actions are
    /// also registered as editor commands, so this slice equals
    /// `declaredActionIds`.
    public static let declaredCommandIds: [String] = declaredActionIds

    /// The declared contribution ID. The auto-indent-on-paste controller — the
    /// single indentation contribution.
    public static let declaredContributionIds: [String] = [
        "editor.contrib.autoIndentOnPaste"
    ]

    /// The declared keybinding commands — the two indentation actions that carry
    /// a default keybinding in `MonaBuiltinKeybindings` (`Cmd+]` indents,
    /// `Cmd+[` outdents), in declared action order.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.indentLines",
        "editor.action.outdentLines"
    ]

    /// The declared option names — the editor-level indentation options read
    /// through `MonaOptionStore`. (The model options `tabSize` / `insertSpaces` /
    /// `indentSize` are text-model options, not editor options, and are read
    /// directly from `MonaModelOptions`.)
    public static let declaredOptionIds: [String] = [
        "autoIndent",
        "autoIndentOnPaste",
        "autoIndentOnPasteWithinString"
    ]

    /// The declared menu IDs — indentation registers no menu items, so this
    /// slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The staged detection result (set by `stageDetection(_:)`), or `nil`.
    private var stagedDetection: MonaIndentationDetection? = nil

    private let emitter = MonaEmitter<MonaIndentationEvent>()

    /// The event stream for indentation changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaIndentationEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the indentation feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: detect + convert + reindent

    /// Detects the indentation of `text`: scans leading whitespace per line,
    /// classifying each indented line as tab-led or space-led. A space-led
    /// majority picks `insertSpaces = true` with the modal leading-space count
    /// as `tabSize` (clamped to 1…8); a tab-led majority (or tie) picks
    /// `insertSpaces = false` with `defaultTabSize`. When `text` has no
    /// indentation, the defaults are returned. After `dispose()`, returns the
    /// defaults.
    public func detectIndentation(
        _ text: String,
        defaultInsertSpaces: Bool,
        defaultTabSize: Int
    ) -> MonaIndentationDetection {
        let lines = text.components(separatedBy: "\n")
        var tabLed = 0
        var spaceLed = 0
        var spaceCounts: [Int] = []
        for line in lines {
            var leadingSpaces = 0
            var hasTab = false
            var seenNonWhitespace = false
            for ch in line {
                if seenNonWhitespace { break }
                if ch == "\t" {
                    hasTab = true
                    seenNonWhitespace = true // a tab in leading whitespace ends the space-only run
                    break
                } else if ch == " " {
                    leadingSpaces += 1
                } else {
                    seenNonWhitespace = true
                    break
                }
            }
            if hasTab {
                tabLed += 1
            } else if leadingSpaces > 0 {
                spaceLed += 1
                spaceCounts.append(leadingSpaces)
            }
        }

        if spaceLed == 0 && tabLed == 0 {
            return MonaIndentationDetection(
                insertSpaces: defaultInsertSpaces,
                tabSize: defaultTabSize
            )
        }

        if spaceLed >= tabLed {
            let tabSize = Self.modalTabSize(spaceCounts, default: defaultTabSize)
            return MonaIndentationDetection(insertSpaces: true, tabSize: tabSize)
        }
        return MonaIndentationDetection(insertSpaces: false, tabSize: defaultTabSize)
    }

    /// Converts tabs to spaces in `text`, expanding each tab to the next tab
    /// stop (column-aligned, not a flat `tabSize` spaces). Mid-line tabs advance
    /// to the next tab stop. Returns `text` unchanged after `dispose()`.
    public func convertToSpaces(_ text: String, tabSize: Int) -> String {
        guard !isDisposed else { return text }
        let resolved = max(tabSize, 1)
        var result = ""
        var col = 0
        for ch in text {
            if ch == "\t" {
                let spaces = resolved - (col % resolved)
                result.append(String(repeating: " ", count: spaces))
                col += spaces
            } else if ch == "\n" {
                result.append("\n")
                col = 0
            } else {
                result.append(ch)
                col += 1
            }
        }
        return result
    }

    /// Converts leading spaces to tabs in `text`: for each line, the leading
    /// whitespace is collapsed to `tabSize`-sized tabs plus a remainder of
    /// spaces. Mid-line whitespace is left untouched. Returns `text` unchanged
    /// after `dispose()`.
    public func convertToTabs(_ text: String, tabSize: Int) -> String {
        guard !isDisposed else { return text }
        let resolved = max(tabSize, 1)
        let lines = text.components(separatedBy: "\n")
        let converted = lines.map { line -> String in
            // Collect leading whitespace (spaces/tabs).
            var leading = ""
            var rest = line
            for ch in line {
                if ch == " " || ch == "\t" {
                    leading.append(ch)
                } else {
                    break
                }
            }
            rest = String(line.dropFirst(leading.count))
            // Compute the visual column of the leading whitespace.
            var col = 0
            for ch in leading {
                if ch == "\t" {
                    col += resolved - (col % resolved)
                } else {
                    col += 1
                }
            }
            let tabs = col / resolved
            let spaces = col % resolved
            return String(repeating: "\t", count: tabs)
                + String(repeating: " ", count: spaces)
                + rest
        }
        return converted.joined(separator: "\n")
    }

    /// Normalizes a whitespace-only `whitespace` run per `options`, mirroring
    /// `MonaCodeModel.normalizeWhitespaceUnits`: compute the visual column
    /// (tabs advance to tab stops, spaces +1), then emit `col` spaces under
    /// `insertSpaces = true`, or `col / tabSize` tabs + `col % tabSize` spaces
    /// under `insertSpaces = false`. Returns an empty string after `dispose()`.
    public func normalizeWhitespace(
        _ whitespace: String,
        options: MonaModelOptions
    ) -> String {
        guard !isDisposed else { return "" }
        let tabSize = max(options.tabSize, 1)
        var col = 0
        for ch in whitespace {
            if ch == "\t" {
                col += tabSize - (col % tabSize)
            } else {
                col += 1
            }
        }
        if options.insertSpaces {
            return String(repeating: " ", count: col)
        }
        let tabs = col / tabSize
        let spaces = col % tabSize
        return String(repeating: "\t", count: tabs)
            + String(repeating: " ", count: spaces)
    }

    /// Reindents each line of `text` by normalizing its leading whitespace per
    /// `options` (reusing `normalizeWhitespace`). Mid-line whitespace and
    /// non-whitespace content are preserved. Returns `text` unchanged after
    /// `dispose()`.
    public func reindentLines(
        _ text: String,
        options: MonaModelOptions
    ) -> String {
        guard !isDisposed else { return text }
        let lines = text.components(separatedBy: "\n")
        let reindented = lines.map { line -> String in
            var leading = ""
            for ch in line {
                if ch == " " || ch == "\t" {
                    leading.append(ch)
                } else {
                    break
                }
            }
            let rest = String(line.dropFirst(leading.count))
            let normalized = normalizeWhitespace(leading, options: options)
            return normalized + rest
        }
        return reindented.joined(separator: "\n")
    }

    /// Reads the editor-level indentation options from `store` (P05-T005):
    /// `autoIndent` (enum string), `autoIndentOnPaste` (bool), and
    /// `autoIndentOnPasteWithinString` (bool). Missing or unknown values fall
    /// back to the canonical defaults.
    public func readIndentationOptions(
        from store: MonaOptionStore
    ) -> MonaIndentationEditorOptions {
        let autoIndent = store.value(for: "autoIndent")?.stringValue ?? "full"
        let autoIndentOnPaste = store.value(for: "autoIndentOnPaste")?.boolValue ?? false
        let autoIndentOnPasteWithinString =
            store.value(for: "autoIndentOnPasteWithinString")?.boolValue ?? true
        return MonaIndentationEditorOptions(
            autoIndent: autoIndent,
            autoIndentOnPaste: autoIndentOnPaste,
            autoIndentOnPasteWithinString: autoIndentOnPasteWithinString
        )
    }

    /// Stages `detection` as the current detection result and fires an event.
    /// A no-op after `dispose()`.
    public func stageDetection(_ detection: MonaIndentationDetection) {
        guard !isDisposed else { return }
        _lock.lock()
        stagedDetection = detection
        _lock.unlock()
        fire(.init(detection: detection))
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Commits a reindent edit through the shared transaction gateway: begins a
    /// transaction, prepares a single edit operation replacing `range` with
    /// `newText`, and commits the unit. Returns the reconciliation outcome
    /// (`.applied` on success, `.dropped` when the feature is disposed or the
    /// commit dropped).
    @discardableResult
    public func commitReindent(
        gateway: MonaTransactionGateway,
        range: MonaRange,
        newText: String
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let tx = gateway.beginTransaction()
        tx.prepareEdits([MonaModelEditOperation(range: range, text: newText)])
        return gateway.commit(tx)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `detection` through the shared provider executor, normalized
    /// onto the deterministic microtask queue. `receive` runs ONLY when the
    /// queue is drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishIndentationDetection(
        _ detection: MonaIndentationDetection,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaIndentationDetection) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(detection),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the staged detection is cleared, and
    /// `detectIndentation` / `convertToSpaces` / `convertToTabs` /
    /// `reindentLines` / `stageDetection` / `commitReindent` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        stagedDetection = nil
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

    /// The plain-text fallback language. indentation needs no tokenization; it
    /// degrades to plain text for any tokenization need.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — indentation performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires an indentation event when not disposed.
    private func fire(_ event: MonaIndentationEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }

    /// Returns the modal (most common) value in `counts`, clamped to 1…8, or
    /// `default` when `counts` is empty.
    private static func modalTabSize(_ counts: [Int], default fallback: Int) -> Int {
        guard !counts.isEmpty else { return fallback }
        var frequencies: [Int: Int] = [:]
        for value in counts {
            frequencies[value, default: 0] += 1
        }
        let modal = frequencies.max { $0.value < $1.value }?.key ?? fallback
        return min(max(modal, 1), 8)
    }
}
