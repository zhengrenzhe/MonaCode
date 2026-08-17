// MonaOptionStore.swift
//
// P05-T005 — Implement all 174 editor options and computed option truth.
//
// `MonaOptionStore` holds the live values of the 157 retained-input editor
// options and derives the 6 computed-only options from them. It is the Swift
// counterpart of Monaco's `EditorOptions` + `ComputedEditorOptions` resolution:
//
//   - Retained-input options are mutable: `setValue(_:for:)` validates the
//     value's type against the option's declared kind, enforces inclusive
//     numeric bounds, and — for extensible enums — accepts any string raw
//     value (known member OR future raw value; the set is open, not frozen).
//   - Computed-only options are derived: the store recomputes them in
//     topological dependency order whenever an input they read changes, and
//     exposes them as read-only (NEVER settable as input).
//   - The 11 cut options are excluded from production input APIs: `setValue`
//     returns `.cutOption` and `value(for:)` returns `nil`.
//   - Changed-option events fire via the shared `MonaEmitter` (from
//     `Sources/MonaCode/Base/MonaEmitter.swift`) for both retained-input and
//     computed-only changes, reusing the single base-model event mechanism
//     (no parallel emitter).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// Holds the live values of the 174 builtin editor options: 157 retained-input
/// (mutable), 6 computed-only (read-only derived), and 11 cut (excluded).
///
/// The store validates input types/defaults/bounds, resolves computed-option
/// dependency ordering topologically, and emits changed-option events via the
/// shared `MonaEmitter`. Computed-only options are exposed as read-only
/// computed properties; cut options are excluded from the input API.
public final class MonaOptionStore {

    /// The names of the 11 cut options (excluded from production input APIs).
    public static let cutOptionNames: [String] = MonaBuiltinOptions.cutOptions.map { $0.name }

    /// The names of the 6 computed-only options (read-only derived).
    public static let computedOptionNames: [String] = MonaBuiltinOptions.computedOnlyOptions.map { $0.name }

    /// The topological order in which computed options are recomputed. An option
    /// appears after every option it `reads` (its dependencies).
    private static let computedResolutionOrder: [String] = {
        let computed = MonaBuiltinOptions.computedOnlyOptions
        var byName: [String: MonaEditorOption] = [:]
        for o in computed { byName[o.name] = o }
        var resolved: [String] = []
        var visited: Set<String> = []
        func visit(_ name: String) {
            if visited.contains(name) { return }
            visited.insert(name)
            guard let opt = byName[name] else { return }
            for dep in opt.reads where byName[dep] != nil {
                visit(dep)
            }
            resolved.append(name)
        }
        // Visit in source order for determinism.
        for o in computed { visit(o.name) }
        return resolved
    }()

    // Live retained-input values, keyed by option name.
    private var inputValues: [String: MonaOptionValue]
    // Live computed-only values, keyed by option name.
    private var computedValues: [String: MonaOptionValue]

    private let changeEmitter = MonaEmitter<MonaOptionChangeEvent>()
    private let lock = NSLock()
    private var _isDisposed = false

    /// Creates a store populated with the canonical defaults of all 157
    /// retained-input options, with the 6 computed-only options derived from
    /// those defaults.
    public init() {
        var inputs: [String: MonaOptionValue] = [:]
        for option in MonaBuiltinOptions.retainedInputOptions {
            inputs[option.name] = option.defaultValue
        }
        self.inputValues = inputs
        self.computedValues = [:]
        // Derive the initial computed values from the defaults.
        for name in Self.computedResolutionOrder {
            self.computedValues[name] = Self.deriveComputed(name, inputs: inputs, computed: self.computedValues)
        }
    }

    // MARK: - Read

    /// Returns the live value of the option `name`, or `nil` when the option is
    /// cut, unknown, or the store is disposed.
    ///
    /// Retained-input and computed-only options are readable; cut options are
    /// not (they are excluded from the production surface).
    public func value(for name: String) -> MonaOptionValue? {
        guard let option = MonaBuiltinOptions.option(named: name) else { return nil }
        guard option.disposition.isReadable else { return nil }
        lock.lock()
        let v: MonaOptionValue?
        switch option.disposition {
        case .retainedInput: v = inputValues[name]
        case .computedOnly: v = computedValues[name]
        case .cut: v = nil
        }
        lock.unlock()
        return v
    }

    // MARK: - Write (retained-input only)

    /// Sets `value` for the retained-input option `name`.
    ///
    /// Validates the value's type against the option's declared kind and
    /// enforces inclusive numeric bounds. Extensible-enum options accept any
    /// string raw value (known member OR future raw value). On a successful
    /// change, fires a changed-option event and recomputes the computed-only
    /// options that transitively read `name`, firing a change event for each
    /// recomputed computed option whose value changed.
    @discardableResult
    public func setValue(_ value: MonaOptionValue, for name: String) -> MonaOptionSetResult {
        guard let option = MonaBuiltinOptions.option(named: name) else {
            return .unknownOption
        }
        switch option.disposition {
        case .cut:
            return .cutOption(name)
        case .computedOnly:
            return .computedNotSettable(name)
        case .retainedInput:
            break
        }
        guard let kind = option.kind else {
            return .typeMismatch(expected: .object)
        }
        // Type validation.
        if !Self.typeMatches(value, kind: kind) {
            return .typeMismatch(expected: kind)
        }
        // Bounds validation (numeric).
        if let bounds = option.bounds {
            let dv = Self.asDouble(value)
            if !bounds.contains(dv) {
                return .outOfBounds(min: bounds.hasMin ? bounds.min : nil,
                                     max: bounds.hasMax ? bounds.max : nil)
            }
        }
        // Apply under lock; capture old value; determine whether to fire.
        var oldValue: MonaOptionValue? = nil
        var changed = false
        lock.lock()
        if _isDisposed {
            lock.unlock()
            return .success // no-op after dispose (contained)
        }
        oldValue = inputValues[name]
        if oldValue != value {
            inputValues[name] = value
            changed = true
        }
        // Snapshot inputs + computed for recompute outside the lock.
        let inputsSnapshot = inputValues
        var computedSnapshot = computedValues
        lock.unlock()

        guard changed else { return .success }

        // Fire the input change event.
        changeEmitter.fire(MonaOptionChangeEvent(
            optionName: name, oldValue: oldValue, newValue: value, isComputed: false))

        // Recompute computed options in topological order; fire events for the
        // ones whose value changed.
        for computedName in Self.computedResolutionOrder {
            guard let opt = MonaBuiltinOptions.option(named: computedName) else { continue }
            // Only recompute if this computed option (transitively) reads `name`.
            if !Self.readsTransitively(opt, target: name) { continue }
            let prev = computedSnapshot[computedName]
            let next = Self.deriveComputed(computedName, inputs: inputsSnapshot, computed: computedSnapshot)
            if next != prev {
                computedSnapshot[computedName] = next
                changeEmitter.fire(MonaOptionChangeEvent(
                    optionName: computedName, oldValue: prev, newValue: next, isComputed: true))
            }
        }
        // Commit recomputed values back under the lock.
        lock.lock()
        for (k, v) in computedSnapshot where computedValues[k] != v {
            computedValues[k] = v
        }
        lock.unlock()
        return .success
    }

    // MARK: - Computed-only read accessors (read-only)

    /// The derived `fontInfo` (computed from fontFamily/fontSize/...).
    public var fontInfo: MonaOptionValue? { value(for: "fontInfo") }
    /// The derived effective cursor style.
    public var effectiveCursorStyle: MonaOptionValue? { value(for: "effectiveCursorStyle") }
    /// The platform pixel ratio (computed).
    public var pixelRatio: MonaOptionValue? { value(for: "pixelRatio") }
    /// The derived layout info.
    public var layoutInfo: MonaOptionValue? { value(for: "layoutInfo") }
    /// The derived wrapping info.
    public var wrappingInfo: MonaOptionValue? { value(for: "wrappingInfo") }
    /// The derived effective-allow-variable-fonts flag.
    public var effectiveAllowVariableFonts: MonaOptionValue? { value(for: "effectiveAllowVariableFonts") }

    // MARK: - Snapshot

    /// Returns an immutable snapshot of all readable option values (157
    /// retained-input + 6 computed-only = 163). Cut options are excluded.
    public func snapshot() -> MonaOptionSnapshot {
        lock.lock()
        let inputs = inputValues
        let computed = computedValues
        lock.unlock()
        var all: [String: MonaOptionValue] = [:]
        for (k, v) in inputs { all[k] = v }
        for (k, v) in computed { all[k] = v }
        return MonaOptionSnapshot(values: all)
    }

    // MARK: - Events

    /// Subscribe to changed-option events. Returns a disposable whose
    /// `dispose()` removes the listener. After `dispose()`, returns an inert
    /// disposable (the listener is never registered), per `MonaEmitter`.
    public var onDidChangeOption: MonaEvent<MonaOptionChangeEvent> {
        return changeEmitter.event
    }

    // MARK: - Disposal

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isDisposed
    }

    /// Disposes the store (and its change emitter). Idempotent.
    public func dispose() {
        lock.lock()
        let already = _isDisposed
        _isDisposed = true
        lock.unlock()
        if !already {
            changeEmitter.dispose()
        }
    }

    // MARK: - Private: derivation

    /// Derives the value of the computed-only option `name` from the current
    /// retained-input values (`inputs`) and already-derived computed values
    /// (`computed`). Must be called in `computedResolutionOrder`.
    private static func deriveComputed(
        _ name: String,
        inputs: [String: MonaOptionValue],
        computed: [String: MonaOptionValue]
    ) -> MonaOptionValue {
        switch name {
        case "pixelRatio":
            // Platform truth: derived from the host environment. The Foundation
            // Core defaults to 1.0 (the host overrides this via the environment
            // boundary, not as a settable input).
            return .double(1.0)
        case "fontInfo":
            let fontFamily = inputs["fontFamily"] ?? .string("")
            let fontSize = (inputs["fontSize"]?.doubleValue) ?? 12
            let lineHeight = (inputs["lineHeight"]?.doubleValue) ?? 0
            let pixelRatio = (computed["pixelRatio"]?.doubleValue) ?? 1.0
            return .object([
                "fontFamily": fontFamily,
                "fontSize": .double(fontSize),
                "lineHeight": .double(lineHeight == 0 ? fontSize * 1.5 : lineHeight),
                "pixelRatio": .double(pixelRatio),
            ])
        case "effectiveCursorStyle":
            // The effective cursor style mirrors the configured cursorStyle
            // (the width/blink inputs refine it but do not change the style
            // identity in the Foundation Core).
            let style = inputs["cursorStyle"] ?? .string("line")
            return style
        case "effectiveAllowVariableFonts":
            let allow = (inputs["allowVariableFonts"]?.boolValue) ?? true
            let allowInA11y = (inputs["allowVariableFontsInAccessibilityMode"]?.boolValue) ?? false
            let a11y = inputs["accessibilitySupport"]?.stringValue ?? "auto"
            // Variable fonts are effectively allowed when allowed, or when
            // explicitly allowed in accessibility mode and a11y is not "off".
            return .bool(allow || (allowInA11y && a11y != "off"))
        case "wrappingInfo":
            let wordWrap = inputs["wordWrap"]?.stringValue ?? "off"
            let column = (inputs["wordWrapColumn"]?.intValue) ?? 80
            let strategy = inputs["wrappingStrategy"]?.stringValue ?? "simple"
            return .object([
                "wordWrap": .string(wordWrap),
                "wordWrapColumn": .int(column),
                "wrappingStrategy": .string(strategy),
            ])
        case "layoutInfo":
            // The layout info is derived from fontInfo + layout inputs. The
            // Foundation Core emits a representative payload; the real geometry
            // is computed by the layout phase (P0x-V1R).
            let fontInfo = computed["fontInfo"] ?? .null
            let glyphMargin = (inputs["glyphMargin"]?.boolValue) ?? false
            let lineDecorationsWidth = (inputs["lineDecorationsWidth"]?.intValue) ?? 10
            return .object([
                "fontInfo": fontInfo,
                "glyphMargin": .bool(glyphMargin),
                "lineDecorationsWidth": .int(lineDecorationsWidth),
            ])
        default:
            return .null
        }
    }

    // MARK: - Private: validation helpers

    private static func typeMatches(_ value: MonaOptionValue, kind: MonaOptionKind) -> Bool {
        switch kind {
        case .boolean: return value.boolValue != nil
        case .integer: return value.intValue != nil
        case .number: return value.doubleValue != nil
        case .string, .enumString: return value.stringValue != nil
        case .object: return value.objectValue != nil || value == .null
        case .array: return value.arrayValue != nil
        }
    }

    private static func asDouble(_ value: MonaOptionValue) -> Double {
        if case .double(let v) = value { return v }
        if case .int(let v) = value { return Double(v) }
        if case .bool(let v) = value { return v ? 1 : 0 }
        return .nan
    }

    /// Returns `true` when `option` (a computed option) transitively reads the
    /// retained-input option named `target`, via its `reads` edges (which may
    /// pass through other computed options).
    private static func readsTransitively(_ option: MonaEditorOption, target: String) -> Bool {
        if option.reads.contains(target) { return true }
        for dep in option.reads {
            if let depOpt = MonaBuiltinOptions.option(named: dep), depOpt.disposition == .computedOnly {
                if readsTransitively(depOpt, target: target) { return true }
            }
        }
        return false
    }
}
