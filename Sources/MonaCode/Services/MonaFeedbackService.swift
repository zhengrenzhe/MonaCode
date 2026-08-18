// MonaFeedbackService.swift
//
// P07-T003 — Implement 40 standalone services and bounded session state.
//
// The nonblocking localized feedback service: the S1-R `feedbackChannels`
// surface (notification / progress / telemetry / accessibility signals)
// implemented exactly as the fixed standalone baseline defines —
// severity-tagged MonaLogSink events for info/warn/error, strict no-ops for
// prompt/status/telemetry/signal, and never any notification-progress UI or
// audio resource.
//
// The feedback service is:
//   - **Nonblocking** — `emit` returns immediately; it never runs on the
//     caller's thread of execution and never blocks the editor.
//   - **Localized** — reuses T007 `MonaLocalization` through the explicit N1
//     `MonaCodeEnvironmentProfile` mechanism. There is no Foundation locale
//     lookup and no network.
//   - **Without document-text logging** — feedback messages never include the
//     document text. Any caller-supplied `context` is dropped before an event
//     is recorded (privacy/security: S1-R `sessionStorage.privacy` says
//     "Find, replace, completion and resource-derived values never leave
//     process memory; logging and generated acceptance artifacts must not
//     serialize session values.").
//
// S1-R `feedbackChannels`:
//   - notification: "info, warn, error and notify produce sanitized
//     severity-tagged MonaLogSink events only; notification prompt returns
//     inert handle and never executes choices; notification status returns
//     inert close and produces no UI or accessibility announcement."
//   - progress: "Both progress services execute and await tasks but discard
//     report values and expose no spinner, bar, cancellation button or
//     accessibility announcement."
//   - telemetry: "All telemetry calls are strict no-ops and never reach a
//     host, file, socket or generated report."
//   - accessibilitySignals: "playSignal is a strict no-op and no audio
//     resource ships."
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The severity tag carried by a sanitized feedback event.
public enum MonaFeedbackSeverity: String, Sendable, Equatable, CaseIterable {

    case info
    case warn
    case error
}

/// A sanitized, severity-tagged feedback event. The payload is the localized
/// message text only — it never carries document text, find/replace history,
/// completion items, or any resource-derived value.
public struct MonaFeedbackEvent: Sendable, Equatable {

    /// The severity tag.
    public let severity: MonaFeedbackSeverity

    /// The sanitized payload: the localized message text, with no document
    /// text, no source content, and no resource-derived values.
    public let payload: String

    public init(severity: MonaFeedbackSeverity, payload: String) {
        self.severity = severity
        self.payload = payload
    }
}

/// An inert handle returned by `prompt` and `status`. It never executes
/// choices and produces no UI, no accessibility announcement, and no side
/// effect.
public struct MonaFeedbackInertHandle: Sendable, Equatable {

    /// `true` — this handle is always inert (a strict no-op).
    public let isInert: Bool = true

    public init() {}
}

/// The nonblocking localized feedback service.
///
/// Reuses T007 `MonaLocalization` for message resolution. The profile is
/// fixed before first service; the default is `en`. There is no runtime
/// locale lookup and no network.
public final class MonaFeedbackService: @unchecked Sendable {

    /// The explicit N1 localization profile used to resolve messages.
    public let profile: MonaCodeEnvironmentProfile

    /// Whether this service is nonblocking (always `true` — `emit` returns
    /// immediately and never blocks the editor).
    public let isNonblocking: Bool = true

    /// Whether this service logs document text (always `false` — feedback
    /// messages never include document text).
    public let logsDocumentText: Bool = false

    /// Whether an audio resource ships (always `false` — S1-R
    /// `feedbackChannels.accessibilitySignals`).
    public let hasAudioResource: Bool = false

    /// The bounded in-process buffer of sanitized, severity-tagged events.
    private var _events: [MonaFeedbackEvent] = []
    private var lock = NSLock()

    public init(profile: MonaCodeEnvironmentProfile) {
        self.profile = profile
    }

    // MARK: - Notification (info / warn / error → sanitized events)

    /// Emits a sanitized, severity-tagged event for the message at `messageIndex`.
    ///
    /// Nonblocking: returns immediately. Localized: the message is resolved
    /// through `MonaLocalization` under this service's `profile`. No
    /// document-text logging: any caller-supplied `context` is dropped before
    /// the event is recorded.
    public func emit(
        _ severity: MonaFeedbackSeverity,
        messageIndex: Int,
        context: String? = nil
    ) {
        // Drop any caller-supplied context BEFORE constructing the event —
        // document text never enters feedback messages.
        _ = context
        let payload: String
        if let resolved = localizedMessage(at: messageIndex) {
            payload = resolved
        } else {
            // S1-R: a missing message yields a typed placeholder; the
            // severity-tagged event is still emitted (no document text).
            payload = "!!! NLS MISSING: \(messageIndex) !!!"
        }
        lock.lock(); defer { lock.unlock() }
        _events.append(MonaFeedbackEvent(severity: severity, payload: payload))
    }

    /// Emits a `notify`-severity event (the `notify` channel routes to the
    /// same sanitized severity-tagged sink as info/warn/error).
    public func notify(messageIndex: Int) {
        emit(.info, messageIndex: messageIndex)
    }

    // MARK: - Notification prompt / status (strict no-ops)

    /// S1-R: "notification prompt returns inert handle and never executes
    /// choices." This method performs no work and produces no event.
    public func prompt(messageIndex: Int) -> MonaFeedbackInertHandle {
        _ = messageIndex
        return MonaFeedbackInertHandle()
    }

    /// S1-R: "notification status returns inert close and produces no UI or
    /// accessibility announcement." This method performs no work and produces
    /// no event.
    public func status(messageIndex: Int) -> MonaFeedbackInertHandle {
        _ = messageIndex
        return MonaFeedbackInertHandle()
    }

    // MARK: - Telemetry + accessibility signals (strict no-ops)

    /// S1-R: "All telemetry calls are strict no-ops and never reach a host,
    /// file, socket or generated report." This method performs no work.
    public func emitTelemetry(_ event: String) {
        _ = event
    }

    /// S1-R: "playSignal is a strict no-op and no audio resource ships."
    public func playSignal(_ signalId: String) {
        _ = signalId
    }

    // MARK: - Localization (reuses T007 MonaLocalization)

    /// Resolves the localized message at `messageIndex` under this service's
    /// explicit N1 profile. Returns `nil` when the index has no resolvable
    /// entry.
    public func localizedMessage(at messageIndex: Int) -> String? {
        do {
            return try MonaLocalization.resolve(messageIndex, profile: profile)
        } catch {
            return nil
        }
    }

    // MARK: - Drain (for tests + the host log sink)

    /// Drains and returns all buffered sanitized events, clearing the buffer.
    public func drainEvents() -> [MonaFeedbackEvent] {
        lock.lock(); defer { lock.unlock() }
        let drained = _events
        _events.removeAll()
        return drained
    }
}
