// MonaSectionHeadersFeature.swift
//
// P05-T148 — Implement retained feature sectionHeaders.
//
// `MonaSectionHeadersFeature` is the Swift counterpart of Monaco's
// `sectionHeaders` contribution (monaco-editor 0.56.0, registered as
// `editor.sectionHeaderDetector`): it derives section-header decorations from
// configured patterns and renders them as native AppKit decorations.
//
// The configured patterns live inside the `minimap` editor option (the same
// source of truth Monaco's `SectionHeaderDetector` reads):
//   - `markSectionHeaderRegex`     — the regex matching MARK-style section
//                                     headers (default
//                                     `\bMARK:\s*(?<separator>-?)\s*(?<label>.*)$`).
//   - `showMarkSectionHeaders`     — whether MARK headers are derived.
//   - `showRegionSectionHeaders`   — whether `#region` folding markers are
//                                     derived as section headers.
//   - `sectionHeaderFontSize`      — the decoration font size.
//   - `sectionHeaderLetterSpacing` — the decoration letter spacing (kern).
//
// Derivation scans the model line-by-line. MARK headers match the configured
// regex (extracting the `label` named group); region headers match a leading
// `#region` marker with an optional trailing label. Rendering builds a native
// `NSAttributedString` carrying the font size + kern, mirroring Monaco's minimap
// section-header rendering.
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode`). It performs the three implementation operations every
// retained feature performs:
//
//   1. Feature-specific behavior — `pattern(for:)`,
//      `deriveSectionHeaders(in:options:)`, `presentation(for:options:profile:)`,
//      `present(using:options:profile:)`, and `commitRevealSectionHeader(...)`.
//   2. Register the exact feature identity `sectionHeaders` and its declared
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

/// The kind of section header detected.
public enum MonaSectionHeaderKind: Equatable, Hashable, Sendable {

    /// A MARK-style header matched by `markSectionHeaderRegex`.
    case mark

    /// A `#region` folding-marker header.
    case region
}

/// A derived section-header decoration: the line, the label, the kind, and the
/// source range. Mirrors Monaco's `SectionHeader` (monaco-editor 0.56.0).
public struct MonaSectionHeader: Equatable, Hashable {

    /// The 1-based line number of the header.
    public let lineNumber: Int

    /// The extracted label (the MARK `label` group, or the `#region` trailing
    /// text). Empty when no label was captured.
    public let label: String

    /// The kind of section header.
    public let kind: MonaSectionHeaderKind

    /// The range of the header line in the model.
    public let range: MonaRange

    public init(lineNumber: Int, label: String, kind: MonaSectionHeaderKind, range: MonaRange) {
        self.lineNumber = lineNumber
        self.label = label
        self.kind = kind
        self.range = range
    }
}

/// The configured section-header patterns read from the `minimap` editor option.
public struct MonaSectionHeaderPattern: Equatable, Sendable {

    /// The regex matching MARK-style section headers.
    public let markSectionHeaderRegex: String

    /// Whether MARK headers are derived.
    public let showMarkSectionHeaders: Bool

    /// Whether `#region` folding markers are derived as section headers.
    public let showRegionSectionHeaders: Bool

    /// The decoration font size.
    public let sectionHeaderFontSize: Int

    /// The decoration letter spacing (kern).
    public let sectionHeaderLetterSpacing: Int

    public init(
        markSectionHeaderRegex: String,
        showMarkSectionHeaders: Bool,
        showRegionSectionHeaders: Bool,
        sectionHeaderFontSize: Int,
        sectionHeaderLetterSpacing: Int
    ) {
        self.markSectionHeaderRegex = markSectionHeaderRegex
        self.showMarkSectionHeaders = showMarkSectionHeaders
        self.showRegionSectionHeaders = showRegionSectionHeaders
        self.sectionHeaderFontSize = sectionHeaderFontSize
        self.sectionHeaderLetterSpacing = sectionHeaderLetterSpacing
    }
}

/// The native AppKit section-header presentation: the attributed string carrying
/// the rendered decorations, the derived headers, and whether the presentation
/// is visible (at least one header was derived).
public struct MonaSectionHeaderPresentation: Equatable {

    /// The native AppKit attributed string rendering the section headers (font
    /// size + kern). Empty when no headers were derived.
    public let attributedString: NSAttributedString

    /// The derived section headers, in source order.
    public let headers: [MonaSectionHeader]

    /// `true` when at least one section header was derived.
    public let visible: Bool

    public init(attributedString: NSAttributedString, headers: [MonaSectionHeader], visible: Bool) {
        self.attributedString = attributedString
        self.headers = headers
        self.visible = visible
    }
}

/// A section-header event: the current presentation.
public struct MonaSectionHeaderEvent: Equatable {

    /// The presentation after the change.
    public let presentation: MonaSectionHeaderPresentation

    public init(presentation: MonaSectionHeaderPresentation) {
        self.presentation = presentation
    }
}

/// The sectionHeaders feature: derive and render section-header decorations
/// from configured patterns.
///
/// The feature identity `sectionHeaders` and its declared slice are referenced
/// verbatim from the frozen registries. Model mutation (revealing a section
/// header line) is routed through `MonaTransactionGateway`; asynchronous
/// publication through `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal
/// through `MonaEmitter`; localization through `MonaLocalization`; and degraded
/// plain-text behavior through `MonaPlainTextLanguage`. The configured patterns
/// are read from the `minimap` editor option's section-header sub-fields.
public final class MonaSectionHeadersFeature: MonaDisposable {

    /// The frozen feature identity (`"sectionHeaders"`).
    public static let featureId = "sectionHeaders"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce).
    /// sectionHeaders declares no labeled actions, so this slice is empty.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs in source order. sectionHeaders declares no
    /// commands, so this slice is empty.
    public static let declaredCommandIds: [String] = []

    /// The declared contribution ID (`editor.sectionHeaderDetector`).
    public static let declaredContributionIds: [String] = [
        "editor.sectionHeaderDetector"
    ]

    /// The declared keybinding commands — sectionHeaders registers no default
    /// keybindings, so this slice is empty.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option name — sectionHeaders owns no top-level option (the
    /// section-header configuration lives inside the `minimap` option's
    /// sub-fields, owned by the minimap surface), so this slice is empty.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — sectionHeaders registers no menu items, so this
    /// slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The default mark-section-header regex (the minimap option's default).
    private static let defaultMarkRegex =
        "\\bMARK:\\s*(?<separator>-?)\\s*(?<label>.*)$"

    /// The default `#region` folding-marker prefix.
    private static let regionPrefix = "#region"

    private var _currentPresentation: MonaSectionHeaderPresentation = MonaSectionHeaderPresentation(
        attributedString: NSAttributedString(),
        headers: [],
        visible: false
    )
    private let emitter = MonaEmitter<MonaSectionHeaderEvent>()

    /// The event stream for section-header presentations. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaSectionHeaderEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the sectionHeaders feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// The current (last presented) presentation. Empty until the first
    /// successful `present(...)`.
    public var currentPresentation: MonaSectionHeaderPresentation {
        _lock.lock(); defer { _lock.unlock() }
        return _currentPresentation
    }

    // MARK: - 1. Feature-specific behavior: derive + render section-header decorations

    /// Reads the configured section-header patterns from the `minimap` editor
    /// option's sub-fields. A pure query: it reads the option and never mutates
    /// the model. When the `minimap` option is absent or a sub-field is missing,
    /// the corresponding default is used.
    public func pattern(for options: MonaOptionStore) -> MonaSectionHeaderPattern {
        let minimap = options.value(for: "minimap")?.objectValue ?? [:]
        return MonaSectionHeaderPattern(
            markSectionHeaderRegex: minimap["markSectionHeaderRegex"]?.stringValue ?? Self.defaultMarkRegex,
            showMarkSectionHeaders: minimap["showMarkSectionHeaders"]?.boolValue ?? true,
            showRegionSectionHeaders: minimap["showRegionSectionHeaders"]?.boolValue ?? true,
            sectionHeaderFontSize: minimap["sectionHeaderFontSize"]?.intValue ?? 9,
            sectionHeaderLetterSpacing: minimap["sectionHeaderLetterSpacing"]?.intValue ?? 1
        )
    }

    /// Derives section-header decorations from the configured patterns by
    /// scanning `model` line-by-line. MARK headers match the configured regex
    /// (extracting the `label` named group); region headers match a leading
    /// `#region` marker with an optional trailing label. Headers appear in
    /// source order. A pure query: it never mutates the model. After
    /// `dispose()`, returns an empty array.
    public func deriveSectionHeaders(
        in model: MonaCodeModel,
        options: MonaOptionStore
    ) -> [MonaSectionHeader] {
        guard !isDisposed else { return [] }
        let pattern = self.pattern(for: options)
        let regex = try? NSRegularExpression(pattern: pattern.markSectionHeaderRegex, options: [])
        var headers: [MonaSectionHeader] = []
        let lineCount = model.getLineCount()
        for lineNumber in 1...lineCount {
            let content = model.getLineContent(lineNumber)
            let maxColumn = model.getLineMaxColumn(lineNumber)
            let range = MonaRange(
                startPosition: MonaPosition(line: lineNumber, column: 1),
                endPosition: MonaPosition(line: lineNumber, column: maxColumn)
            )
            if pattern.showMarkSectionHeaders, let r = regex,
               let match = r.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let labelRange = Range(match.range(withName: "label"), in: content) {
                let label = String(content[labelRange]).trimmingCharacters(in: .whitespaces)
                headers.append(MonaSectionHeader(
                    lineNumber: lineNumber,
                    label: label,
                    kind: .mark,
                    range: range
                ))
                continue
            }
            if pattern.showRegionSectionHeaders {
                let trimmed = content.trimmingCharacters(in: .whitespaces)
                if trimmed.lowercased().hasPrefix(Self.regionPrefix) {
                    let after = trimmed.dropFirst(Self.regionPrefix.count)
                        .trimmingCharacters(in: .whitespaces)
                    headers.append(MonaSectionHeader(
                        lineNumber: lineNumber,
                        label: String(after),
                        kind: .region,
                        range: range
                    ))
                }
            }
        }
        return headers
    }

    /// Builds the native AppKit section-header presentation for `model` under
    /// `options` and `profile`: the derived headers rendered as an attributed
    /// string carrying the configured font size + kern. The presentation is
    /// hidden (empty) after `dispose()` or when no headers were derived.
    public func presentation(
        for model: MonaCodeModel,
        options: MonaOptionStore,
        profile: MonaCodeEnvironmentProfile
    ) -> MonaSectionHeaderPresentation {
        guard !isDisposed else {
            return MonaSectionHeaderPresentation(
                attributedString: NSAttributedString(),
                headers: [],
                visible: false
            )
        }
        let pattern = self.pattern(for: options)
        let headers = deriveSectionHeaders(in: model, options: options)
        guard !headers.isEmpty else {
            return MonaSectionHeaderPresentation(
                attributedString: NSAttributedString(),
                headers: [],
                visible: false
            )
        }
        let font = NSFont.systemFont(ofSize: CGFloat(pattern.sectionHeaderFontSize))
        let kern = NSNumber(value: pattern.sectionHeaderLetterSpacing)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: kern,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let joined = headers.map { $0.label }.joined(separator: "\n")
        let attributed = NSAttributedString(string: joined, attributes: attrs)
        return MonaSectionHeaderPresentation(
            attributedString: attributed,
            headers: headers,
            visible: true
        )
    }

    /// Presents the section-header decorations when at least one header was
    /// derived, firing an event with the current presentation and retaining it
    /// as `currentPresentation`. Returns `true` when a presentation was fired
    /// (at least one header); `false` when no headers were derived or after
    /// `dispose()`.
    @discardableResult
    public func present(
        using model: MonaCodeModel,
        options: MonaOptionStore,
        profile: MonaCodeEnvironmentProfile
    ) -> Bool {
        guard !isDisposed else { return false }
        let presentation = self.presentation(for: model, options: options, profile: profile)
        guard presentation.visible else { return false }
        _lock.lock()
        _currentPresentation = presentation
        _lock.unlock()
        emitter.fire(MonaSectionHeaderEvent(presentation: presentation))
        return true
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Reveals `header` through the shared transaction gateway: begins a
    /// transaction, prepares a collapsed selection at the header's line first
    /// column, and commits the unit. Returns the reconciliation outcome. A
    /// no-op after `dispose()` (returns `.dropped`).
    @discardableResult
    public func commitRevealSectionHeader(
        _ header: MonaSectionHeader,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let position = MonaPosition(line: header.lineNumber, column: 1)
        let selection = MonaSelection(anchor: position, activePosition: position)
        let transaction = gateway.beginTransaction()
        transaction.prepareSelections([selection])
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `headers` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated. After
    /// `dispose()`, returns `false` and publishes nothing.
    @discardableResult
    public func publishSectionHeaders(
        _ headers: [MonaSectionHeader],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaSectionHeader]) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        return executor.publish(
            .synchronous(headers),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the current presentation is cleared,
    /// and `deriveSectionHeaders` / `presentation` / `present` /
    /// `commitRevealSectionHeader` / `publishSectionHeaders` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _currentPresentation = MonaSectionHeaderPresentation(
            attributedString: NSAttributedString(),
            headers: [],
            visible: false
        )
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. sectionHeaders declares no
    /// actions, so this returns an empty array under every profile.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. sectionHeaders needs no tokenization;
    /// it degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — sectionHeaders performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }
}

// MARK: - MonaSectionHeaderPresentation convenience

extension MonaSectionHeaderPresentation {

    /// The empty presentation (no headers, hidden).
    fileprivate static func empty() -> MonaSectionHeaderPresentation {
        return MonaSectionHeaderPresentation(
            attributedString: NSAttributedString(),
            headers: [],
            visible: false
        )
    }
}
