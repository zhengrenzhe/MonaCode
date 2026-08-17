// MonaAXMutationGateway.swift
//
// P04-T013 — Route accessibility setters through ModelInputBarrier.
//
// `MonaAXMutationGateway` is the accessibility mutation gateway for the AppKit
// editor. It translates VoiceOver / `AXUIElement` setter calls (set-value,
// set-selection, increment, decrement, press, custom) into Core model input
// plans and routes them through `MonaModelInputBarrier` (P04-T005) — the same
// all-or-none transaction path keyboard / IME / multi-cursor input uses — so
// every AX-driven mutation goes through one chokepoint before it may touch the
// text model. This is the Swift counterpart of the AX setter path Monaco routes
// through its command / cursor controller before pushing onto the text model
// (monaco-editor 0.56.0).
//
// Before the barrier commits, the gateway validates FIVE preconditions: focus,
// editability, model version, range, and owner generation. Any failure rejects
// the mutation BEFORE commit — no partial state. Accessibility announcements
// are published ONLY after the barrier's transaction commits successfully
// (`.applied`); if the transaction rolls back or is dropped, NO announcement is
// published.
//
// This gateway sits on top of the AX text surface (P04-T010), the AX element
// graph (P04-T011), and the focus coordinator + announcement bridge (P04-T012).
//
// `MonaCodeAppKit` may `import AppKit`, `import Foundation`, and `import MonaCode`.

import AppKit
import Foundation
import MonaCode

// MARK: - MonaAXMutationAction

/// The six accessibility mutation actions the gateway translates into Core
/// input plans. Each maps to one `MonaMultiCursorInputPlan` consumed by
/// `MonaModelInputBarrier`:
///   - `setValue`: full text replace (the plan's edit covers the full model
///     range and carries the new text).
///   - `setSelection`: selection-only — a folded empty edit at the selection
///     start (no text change); the resulting selection is published through
///     the barrier.
///   - `increment` / `decrement`: adjust the numeric value at `range` by
///     `+delta` / `-delta` (the plan's edit replaces the range with the
///     adjusted value).
///   - `press`: invoke a registered command — a folded empty edit at `position`
///     routes the action through the barrier; the command handler is
///     dispatched post-commit.
///   - `custom`: dispatch `identifier` to a registered handler — a folded
///     empty edit at `position` routes the action through the barrier; the
///     handler is dispatched post-commit.
public enum MonaAXMutationAction: Equatable {
    /// AX set-value: replace the full model text with `text`.
    case setValue(text: String)
    /// AX set-selection: selection-only (no text change).
    case setSelection(range: MonaRange)
    /// AX increment: adjust the numeric value at `range` by `+delta`.
    case increment(delta: Int, range: MonaRange)
    /// AX decrement: adjust the numeric value at `range` by `-delta`.
    case decrement(delta: Int, range: MonaRange)
    /// AX press: invoke the registered command `command` at `position`.
    case press(command: String, at: MonaPosition)
    /// AX custom action: dispatch `identifier` to a registered handler at
    /// `position`.
    case custom(identifier: String, at: MonaPosition)
}

// MARK: - MonaAXMutationRequest

/// One accessibility mutation request: the action plus the issue-time context
/// (model version + geometry generation) the gateway validates against the live
/// model / barrier before commit.
public struct MonaAXMutationRequest: Equatable {
    /// The action to translate and commit.
    public let action: MonaAXMutationAction
    /// The model version id captured when the AX action was issued. The gateway
    /// rejects (`.staleModelVersion`) if this diverges from the live model
    /// version at commit time.
    public let issuedModelVersion: Int
    /// The geometry barrier generation captured when the AX action was issued,
    /// or `nil` to skip the owner-generation check. The gateway rejects
    /// (`.staleGeneration`) if this diverges from the barrier's current
    /// generation.
    public let issuedGeneration: Int?

    /// Creates a mutation request.
    public init(
        action: MonaAXMutationAction,
        issuedModelVersion: Int,
        issuedGeneration: Int? = nil
    ) {
        self.action = action
        self.issuedModelVersion = issuedModelVersion
        self.issuedGeneration = issuedGeneration
    }
}

// MARK: - MonaAXMutationRejection

/// A typed pre-commit rejection reason. All checks run BEFORE the barrier
/// commits; any failure rejects the mutation with no partial state.
public enum MonaAXMutationRejection: String, Equatable, Sendable {
    /// The focus coordinator is absent or the current focus mode is not
    /// editing-capable (`.editor` / `.accessibilityOptimized`).
    case focusNotEditingCapable
    /// The target is not editable (read-only).
    case notEditable
    /// The model version the AX action was issued against does not match the
    /// live model version (stale action).
    case staleModelVersion
    /// The affected `MonaRange` is not valid for the current model.
    case invalidRange
    /// The geometry barrier generation the AX action was issued against does not
    /// match the current generation.
    case staleGeneration
    /// The model or barrier reference is no longer alive (the editor was torn
    /// down while an AX action was in flight).
    case targetUnavailable
    /// The action could not be translated into a Core input plan (e.g.
    /// increment / decrement on a range whose text is not an integer).
    case untranslatable
}

// MARK: - MonaAXMutationOutcome

/// The typed result of routing an AX mutation through the gateway.
public enum MonaAXMutationOutcome: Equatable {
    /// The mutation committed through the barrier (`.applied`) and the
    /// accessibility announcement was published. For `press` / `custom`, the
    /// registered handler was dispatched post-commit.
    case applied
    /// The mutation was rejected BEFORE the barrier committed (one of the
    /// pre-commit checks failed). No announcement was published.
    case rejected(reason: MonaAXMutationRejection)
    /// The barrier dropped the transaction (the captured version diverged from
    /// the live model between prepare and commit). No announcement was
    /// published.
    case dropped
    /// The barrier rolled back the transaction (overlap rejection or
    /// validation failure). No announcement was published.
    case rolledBack
}

// MARK: - MonaAXMutationGateway

/// The accessibility mutation gateway: translates AX setter calls into Core
/// input plans and routes them through `MonaModelInputBarrier`.
///
/// Construct with
/// `init(model:barrier:geometryBarrier:focusCoordinator:announcementBridge:isEditable:)`.
/// Register press / custom handlers with `registerPressHandler(_:handler:)` and
/// `registerCustomHandler(_:handler:)`. Route a mutation with
/// `perform(_:) -> MonaAXMutationOutcome`.
///
/// The gateway holds its model, barrier, geometry barrier, focus coordinator,
/// and announcement bridge weakly — mirroring `MonaAXTextArea` (P04-T010) and
/// `MonaAXElementGraph` (P04-T011) — so an AX element never extends a disposed
/// model's lifetime.
public final class MonaAXMutationGateway {

    // MARK: - Backing references (weak — mirroring MonaAXTextArea / MonaAXElementGraph)

    /// The model supplying text truth. Held weakly so the gateway never extends
    /// a disposed model's lifetime.
    public private(set) weak var model: MonaCodeModel?

    /// The multi-cursor input barrier (P04-T005) every AX mutation routes
    /// through. Held weakly.
    public private(set) weak var barrier: MonaModelInputBarrier?

    /// The complete-generation geometry barrier (P03-T007) supplying the owner
    /// generation. Held weakly; the same barrier P04-T010 / T011 reuse.
    public private(set) weak var geometryBarrier: MonaQueryGeometryBarrier?

    /// The accessibility focus state machine (P04-T012). Held weakly.
    public private(set) weak var focusCoordinator: MonaAXFocusCoordinator?

    /// The VoiceOver announcement bridge (P04-T012) — the notification text
    /// surface. Held weakly.
    public private(set) weak var announcementBridge: MonaAXAnnouncementBridge?

    // MARK: - Editability + handler registries

    /// Supplies the editability truth (read-only check). Default `{ true }`.
    private let isEditableProvider: () -> Bool

    /// Registered press-command handlers, keyed by command name.
    private var pressHandlers: [String: () -> Void] = [:]

    /// Registered custom-action handlers, keyed by identifier.
    private var customHandlers: [String: () -> Void] = [:]

    // MARK: - Test / audit seams (internal)

    /// Fires after the five validations pass and BEFORE the barrier prepares the
    /// plan. A test can mutate the model here to force the barrier into a
    /// rolled-back outcome (the prepared plan's ranges become invalid for the
    /// mutated model, while prepare re-captures the post-mutation version).
    /// Default: no-op.
    internal var beforePrepare: ((MonaAXMutationRequest, MonaCodeModel) -> Void)?

    /// Fires AFTER the barrier prepares the plan and BEFORE it commits. A test
    /// can mutate the model here to force the barrier into a dropped outcome
    /// (the captured version diverges from the live version). Default: no-op.
    internal var beforeCommit: ((MonaAXMutationRequest, MonaPreparedMultiCursorInput, MonaCodeModel) -> Void)?

    // MARK: - Init

    /// Creates the gateway over the given dependencies.
    ///
    /// - Parameters:
    ///   - model: The model the gateway translates actions against and the
    ///     barrier commits through.
    ///   - barrier: The multi-cursor input barrier (P04-T005) every AX mutation
    ///     routes through. Must wrap `model`.
    ///   - geometryBarrier: The complete-generation geometry barrier (P03-T007)
    ///     supplying the owner generation, or `nil` to skip the generation
    ///     check.
    ///   - focusCoordinator: The accessibility focus state machine (P04-T012).
    ///   - announcementBridge: The VoiceOver announcement bridge (P04-T012) —
    ///     the notification text surface.
    ///   - isEditable: Supplies the editability truth (read-only check).
    public init(
        model: MonaCodeModel,
        barrier: MonaModelInputBarrier,
        geometryBarrier: MonaQueryGeometryBarrier? = nil,
        focusCoordinator: MonaAXFocusCoordinator,
        announcementBridge: MonaAXAnnouncementBridge,
        isEditable: @escaping () -> Bool = { true }
    ) {
        self.model = model
        self.barrier = barrier
        self.geometryBarrier = geometryBarrier
        self.focusCoordinator = focusCoordinator
        self.announcementBridge = announcementBridge
        self.isEditableProvider = isEditable
    }

    // MARK: - Handler registration

    /// Registers `handler` for press actions carrying `command`. Invoked
    /// post-commit on a successful `press` action.
    public func registerPressHandler(_ command: String, handler: @escaping () -> Void) {
        pressHandlers[command] = handler
    }

    /// Registers `handler` for custom actions carrying `identifier`. Invoked
    /// post-commit on a successful `custom` action.
    public func registerCustomHandler(_ identifier: String, handler: @escaping () -> Void) {
        customHandlers[identifier] = handler
    }

    // MARK: - Perform (translate → validate → commit → announce)

    /// Routes `request` through the gateway: validates the five preconditions,
    /// translates the action into a Core input plan, commits it through the
    /// model input barrier, and — only on a successful commit — publishes the
    /// accessibility announcement and dispatches any registered press / custom
    /// handler.
    ///
    /// Returns `.applied` when the barrier committed, `.rejected(reason:)` when
    /// a pre-commit check failed, `.dropped` when the barrier dropped the
    /// transaction, or `.rolledBack` when the barrier rolled it back.
    @discardableResult
    public func perform(_ request: MonaAXMutationRequest) -> MonaAXMutationOutcome {
        // 0. Resolve weak backing references.
        guard let model = self.model, let barrier = self.barrier else {
            return .rejected(reason: .targetUnavailable)
        }

        // 1. Focus: the editor must be in an editing-capable focus mode.
        guard let focus = self.focusCoordinator,
              Self.isEditingCapable(focus.currentMode) else {
            return .rejected(reason: .focusNotEditingCapable)
        }

        // 2. Editability: the target must be editable.
        guard isEditableProvider() else {
            return .rejected(reason: .notEditable)
        }

        // 3. Model version: optimistic concurrency — the version the AX action
        //    was issued against must match the live version.
        guard request.issuedModelVersion == model.getVersionId() else {
            return .rejected(reason: .staleModelVersion)
        }

        // 4. Range: the affected MonaRange must be valid for the current model.
        let affectedRange = self.affectedRange(for: request.action, model: model)
        guard model.isValidRange(affectedRange) else {
            return .rejected(reason: .invalidRange)
        }

        // 5. Owner generation: the geometry barrier generation the AX action
        //    was issued against must match the current generation.
        if let issuedGen = request.issuedGeneration {
            if let gb = self.geometryBarrier, let currentGen = gb.currentGeneration {
                guard issuedGen == currentGen else {
                    return .rejected(reason: .staleGeneration)
                }
            }
        }

        // Translate the action into a Core input plan. (e.g. increment on a
        // non-integer range cannot be translated → reject.)
        guard let plan = self.translate(request.action, model: model) else {
            return .rejected(reason: .untranslatable)
        }

        // Commit through the barrier: prepare (capture one immutable model
        // version) → commit (all-or-none in one transaction). The audit seams
        // let a host / test observe or perturb the prepare→commit window.
        beforePrepare?(request, model)
        let prepared = barrier.prepare(plan)
        beforeCommit?(request, prepared, model)
        let outcome = barrier.commit(prepared, overlapPolicy: .reject)

        switch outcome {
        case .applied:
            // Publish the accessibility announcement ONLY after a successful
            // commit. `.selectionChanged` is the mutation-notification key on
            // the P04-T012 announcement bridge surface — the bridge resolves
            // the text through the explicit N1 localization profile, never the
            // runtime system locale. (The full mutation-specific announcement
            // catalog is N1-R closure data.)
            if let bridge = self.announcementBridge {
                _ = try? bridge.enqueue(.selectionChanged)
            }
            // Dispatch press / custom handlers post-commit.
            dispatchPostCommitHandlers(for: request.action)
            return .applied
        case .dropped:
            // Barrier dropped (stale version between prepare and commit): no
            // announcement, no handler dispatch.
            return .dropped
        case .rolledBack:
            // Barrier rolled back (overlap rejection or validation failure): no
            // announcement, no handler dispatch.
            return .rolledBack
        }
    }

    // MARK: - Translation (action → Core input plan)

    /// Translates `action` into a `MonaMultiCursorInputPlan` against `model`.
    /// Returns `nil` if the action cannot be translated (e.g. increment on a
    /// non-integer range).
    ///
    /// Each action maps to a single-cursor plan:
    ///   - `setValue`             → full-text-replace edit (range = full model
    ///                              range).
    ///   - `setSelection`         → folded empty edit at the selection start
    ///                              (no text change).
    ///   - `increment`/`decrement` → replace the numeric text at `range` with
    ///                              the adjusted value.
    ///   - `press`/`custom`        → folded empty edit at `position` (no text
    ///                              change; the command/handler is dispatched
    ///                              post-commit).
    internal func translate(
        _ action: MonaAXMutationAction,
        model: MonaCodeModel
    ) -> MonaMultiCursorInputPlan? {
        switch action {
        case .setValue(let text):
            let fullRange = model.getFullModelRange()
            let edit = MonaCursorInputEdit(range: fullRange, text: text, kind: .text)
            return MonaMultiCursorInputPlan(primary: edit)

        case .setSelection(let range):
            // Selection-only: a folded empty edit at the selection start. No
            // text changes; the resulting selection is published through the
            // barrier as a collapsed caret at the selection start.
            let start = range.startPosition
            let folded = MonaRange(startPosition: start, endPosition: start)
            let edit = MonaCursorInputEdit(range: folded, text: "", kind: .text)
            return MonaMultiCursorInputPlan(primary: edit)

        case .increment(let delta, let range):
            guard let current = numericValue(at: range, model: model) else { return nil }
            let edit = MonaCursorInputEdit(range: range, text: String(current + delta), kind: .text)
            return MonaMultiCursorInputPlan(primary: edit)

        case .decrement(let delta, let range):
            guard let current = numericValue(at: range, model: model) else { return nil }
            let edit = MonaCursorInputEdit(range: range, text: String(current - delta), kind: .text)
            return MonaMultiCursorInputPlan(primary: edit)

        case .press(_, let position):
            let folded = MonaRange(startPosition: position, endPosition: position)
            let edit = MonaCursorInputEdit(range: folded, text: "", kind: .text)
            return MonaMultiCursorInputPlan(primary: edit)

        case .custom(_, let position):
            let folded = MonaRange(startPosition: position, endPosition: position)
            let edit = MonaCursorInputEdit(range: folded, text: "", kind: .text)
            return MonaMultiCursorInputPlan(primary: edit)
        }
    }

    // MARK: - Affected range (for the pre-commit range check)

    /// The `MonaRange` the pre-commit range check validates against. For
    /// `setValue` this is the full model range; for `setSelection` /
    /// `increment` / `decrement` the action's range; for `press` / `custom` a
    /// folded range at the position.
    private func affectedRange(
        for action: MonaAXMutationAction,
        model: MonaCodeModel
    ) -> MonaRange {
        switch action {
        case .setValue:
            return model.getFullModelRange()
        case .setSelection(let range):
            return range
        case .increment(_, let range):
            return range
        case .decrement(_, let range):
            return range
        case .press(_, let position):
            return MonaRange(startPosition: position, endPosition: position)
        case .custom(_, let position):
            return MonaRange(startPosition: position, endPosition: position)
        }
    }

    // MARK: - Helpers

    /// `true` when `mode` is editing-capable (`.editor` or
    /// `.accessibilityOptimized`). `.widget`, `.tabFocus`, and `.temporary` are
    /// not editing-capable.
    private static func isEditingCapable(_ mode: MonaAXFocusMode) -> Bool {
        switch mode {
        case .editor, .accessibilityOptimized: return true
        case .widget, .tabFocus, .temporary: return false
        }
    }

    /// Parses the integer value of the text at `range` in `model`. Returns `nil`
    /// when the text is not an integer (after trimming whitespace / newlines).
    private func numericValue(at range: MonaRange, model: MonaCodeModel) -> Int? {
        let text = model.getValueInRange(range)
        return Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Dispatches the registered handler for `press` / `custom` actions. Called
    /// only on a successful commit.
    private func dispatchPostCommitHandlers(for action: MonaAXMutationAction) {
        switch action {
        case .press(let command, _):
            pressHandlers[command]?()
        case .custom(let identifier, _):
            customHandlers[identifier]?()
        default:
            break
        }
    }
}
