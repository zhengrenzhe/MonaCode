// MonaPasteEditPipeline.swift
//
// P04-T008 — Implement copy, cut, paste, and paste-edit pipelines.
//
// `MonaPasteEditPipeline` runs direct paste-edit providers in deterministic
// order — the Swift counterpart of Monaco's paste-edit provider chain
// (monaco-editor 0.56.0). Each registered provider transforms the clipboard
// content before insertion. The pipeline runs providers in registration order,
// feeding each provider the output of the previous one, and supports
// cancellation (via `MonaCancellationToken` from P01-T006) and validity tickets
// (via `MonaAsyncValidityTicket` from P01-T010, validated against a
// `MonaPublicationGate`).
//
// The pipeline then commits cut and multi-cursor paste through the model input
// barrier (P04-T005 `MonaModelInputBarrier`): the barrier captures one model
// version, applies the replication rules, and publishes all cursor edits in one
// transaction — or none (atomic).
//
// Cancellation / validity semantics:
//
//   - If `cancellationToken.isCancellationRequested` before the pipeline runs,
//     the content is dropped (returns nil) and NO provider runs.
//   - If cancellation is requested MID-pipeline, the pipeline stops at the
//     provider that observed it and returns nil; subsequent providers do not run.
//   - If a `gate` + `ticket` are supplied and the ticket is stale (the gate
//     reports it invalid), the content is dropped before any provider runs.
//   - If a provider returns nil (explicitly drops the paste), the pipeline stops
//     and returns nil; subsequent providers do not run.
//
// `MonaCodeAppKit` may `import AppKit`, `import Foundation`, and `import MonaCode`.

import AppKit
import Foundation
import MonaCode

/// A paste-edit provider: transforms clipboard content before insertion.
///
/// Each provider receives the content produced by the previous provider (or the
/// raw clipboard content for the first provider), plus the cancellation token
/// and validity ticket in force. Return nil to cancel the paste (drop the
/// content); return a transformed value to pass it to the next provider.
public protocol MonaPasteEditProvider: AnyObject {

    /// Stable identifier for this provider (diagnostics / ordering).
    var identifier: String { get }

    /// Transforms `content` before insertion. Return nil to cancel the paste.
    func edit(
        _ content: MonaClipboardContent,
        cancellationToken: MonaCancellationToken,
        ticket: MonaAsyncValidityTicket
    ) -> MonaClipboardContent?
}

/// The typed result of committing a cut or multi-cursor paste through the
/// pipeline + barrier.
///
/// Mirrors `MonaModelInputBarrierOutcome` so callers branch on one type for
/// both pipeline-dropped and barrier-committed outcomes.
public enum MonaPasteEditOutcome: Equatable {

    /// Every cursor edit + selection committed cleanly as one transaction.
    case applied(selections: [MonaSelection])

    /// The paste or cut was dropped before the barrier was invoked: cancellation
    /// requested, validity ticket stale, or a paste-edit provider returned nil.
    case dropped(reason: String)

    /// The barrier rolled back the whole batch (overlap rejection, validation
    /// failure). The model is untouched.
    case rolledBack(reason: String)
}

/// Runs direct paste-edit providers in deterministic order, then commits cut
/// and multi-cursor paste through the model input barrier.
///
/// Register providers with `register(_:)` (appends in order). Run the
/// provider chain with `run(_:cancellationToken:gate:ticket:)`. Commit a
/// multi-cursor paste through the barrier with
/// `commitMultiCursorPaste(_:cursorPositions:barrier:)`, or run the providers
/// AND commit in one call with `pasteThroughBarrier(...)`. Commit a cut with
/// `commitCut(selections:barrier:)`.
public final class MonaPasteEditPipeline {

    /// The registered providers, in registration order.
    private var providers: [MonaPasteEditProvider] = []

    /// Creates an empty pipeline.
    public init() {}

    /// Appends `provider` to the end of the provider chain.
    public func register(_ provider: MonaPasteEditProvider) {
        providers.append(provider)
    }

    // MARK: - Provider chain

    /// Runs the provider chain over `content` in registration order.
    ///
    /// - If `cancellationToken.isCancellationRequested`, drops immediately (nil).
    /// - If `gate` + `ticket` are supplied and the ticket is stale, drops (nil).
    /// - Each provider receives the previous provider's output (or `content` for
    ///   the first). A provider returning nil drops the paste (nil).
    /// - With no providers, the content is returned unchanged.
    public func run(
        _ content: MonaClipboardContent,
        cancellationToken: MonaCancellationToken = .none,
        gate: MonaPublicationGate? = nil,
        ticket: MonaAsyncValidityTicket? = nil
    ) -> MonaClipboardContent? {
        // Cancellation truth: drop before running any provider.
        if cancellationToken.isCancellationRequested {
            return nil
        }
        // Validity truth: a stale ticket drops the paste silently.
        if let gate = gate, let ticket = ticket, !gate.validate(ticket) {
            return nil
        }

        var current = content
        for provider in providers {
            // Re-check cancellation before each provider so a provider that
            // observed cancellation mid-pipeline stops the remaining chain.
            if cancellationToken.isCancellationRequested {
                return nil
            }
            guard let next = provider.edit(
                current,
                cancellationToken: cancellationToken,
                ticket: ticket ?? freshTicket()
            ) else {
                return nil
            }
            current = next
        }
        return current
    }

    /// A default fresh ticket for providers when the caller did not supply one.
    /// Providers may ignore it; it carries no cancellation/version truth when
    /// the caller did not arm a gate.
    private func freshTicket() -> MonaAsyncValidityTicket {
        return MonaAsyncValidityTicket(
            modelIdentityHash: "",
            versionId: 0,
            alternativeVersionId: 0,
            ownerGeneration: 0,
            cancellationGeneration: 0
        )
    }

    // MARK: - Multi-cursor paste through the barrier

    /// Commits a multi-cursor clipboard paste through the model input barrier.
    /// Builds a `.clipboard` plan replicating `text` at each cursor position and
    /// commits it via `barrier`. The barrier publishes all cursor edits + selections
    /// in one transaction, or none (atomic).
    @discardableResult
    public func commitMultiCursorPaste(
        text: String,
        cursorPositions: [MonaPosition],
        barrier: MonaModelInputBarrier
    ) -> MonaModelInputBarrierOutcome {
        let plan = MonaMultiCursorInputPlan.replicateClipboardPaste(
            cursorPositions: cursorPositions,
            text: text
        )
        return barrier.commit(plan)
    }

    // MARK: - Cut through the barrier

    /// Commits a cut (delete selections) through the model input barrier. Each
    /// selection becomes a cursor edit replacing the selection range with the
    /// empty string. The first selection is the primary; the rest are secondary.
    /// The barrier publishes all deletions in one transaction, or none (atomic).
    @discardableResult
    public func commitCut(
        selections: [MonaSelection],
        barrier: MonaModelInputBarrier
    ) -> MonaModelInputBarrierOutcome {
        guard !selections.isEmpty else {
            // No selections: nothing to delete. The barrier commits an empty
            // plan that publishes no edits but still records the transaction.
            let empty = MonaMultiCursorInputPlan(
                primary: MonaCursorInputEdit(
                    range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                    text: "",
                    kind: .text
                )
            )
            return barrier.commit(empty)
        }
        let edits = selections.map { selection -> MonaCursorInputEdit in
            return MonaCursorInputEdit(
                range: MonaRange(
                    startPosition: selection.startPosition,
                    endPosition: selection.endPosition
                ),
                text: "",
                kind: .text,
                forceMoveMarkers: false
            )
        }
        let plan = MonaMultiCursorInputPlan(
            primary: edits[0],
            secondary: Array(edits.dropFirst())
        )
        return barrier.commit(plan)
    }

    // MARK: - Paste-edit providers + barrier commit in one call

    /// Runs the paste-edit providers over a clipboard paste built from `text`,
    /// then commits the (possibly transformed) pasted text at each cursor
    /// position through the barrier.
    ///
    /// - If cancellation is requested, a validity ticket is stale, or a provider
    ///   returns nil, the paste is dropped (`.dropped`) and the barrier is NOT
    ///   invoked (the model is untouched).
    /// - Otherwise the provider-transformed plain text is replicated as a
    ///   `.clipboard` plan at each cursor position and committed through the
    ///   barrier.
    @discardableResult
    public func pasteThroughBarrier(
        text: String,
        cursorPositions: [MonaPosition],
        barrier: MonaModelInputBarrier,
        cancellationToken: MonaCancellationToken = .none,
        gate: MonaPublicationGate? = nil,
        ticket: MonaAsyncValidityTicket? = nil
    ) -> MonaPasteEditOutcome {
        let input = MonaClipboardContent(plainText: text, richText: nil, metadata: nil)
        guard let transformed = run(
            input,
            cancellationToken: cancellationToken,
            gate: gate,
            ticket: ticket
        ) else {
            return .dropped(reason: MonaPasteEditPipelineReason.cancelled)
        }
        let pastedText = transformed.plainText ?? ""
        let outcome = commitMultiCursorPaste(
            text: pastedText,
            cursorPositions: cursorPositions,
            barrier: barrier
        )
        switch outcome {
        case .applied(let selections):
            return .applied(selections: selections)
        case .dropped(let reason):
            return .dropped(reason: reason)
        case .rolledBack(let reason):
            return .rolledBack(reason: reason)
        }
    }
}

// MARK: - Stable reason strings

/// Internal stable reason strings for `MonaPasteEditOutcome`.
internal enum MonaPasteEditPipelineReason {
    static let cancelled = "cancelled"
    static let staleTicket = "stale ticket"
    static let providerDropped = "provider dropped"
}
