// MonaTransportEvent.swift
//
// P06-T001 — Define a transport-neutral byte channel in Core.
//
// `MonaTransportEvent` is the event value emitted by a `MonaMessageTransport`
// — the LSP message transport's lowest layer. It is the transport-neutral
// surface: the byte channel knows only ordered bytes in, ordered bytes out,
// and the two terminal conditions (clean close and error). It does NOT know
// about LSP framing (Content-Length headers), JSON-RPC, session state, process
// launch, file descriptors, or platform lifecycle — those are T002–T004 +
// T009 and live above this protocol.
//
// The four cases are the entire event stream a byte channel emits:
//
//   - `.received(Data)`: ordered bytes that arrived from the transport's peer.
//     Delivered in the exact arrival order the host adapter observed.
//   - `.sent(Data)`: bytes that were sent to the transport's peer. Delivered in
//     issuance order, interleaved with `.received` as issued.
//   - `.closed`: the transport closed cleanly. Terminal — fires at most once.
//   - `.errored(Error)`: the transport failed. Terminal — fires at most once.
//
// The terminal cases (`closed`/`errored`) are serialized and fire exactly once
// (idempotent), mirroring `MonaEmitter`'s idempotent disposal pattern. After a
// terminal fires, the transport delivers no further `.received`/`.sent` events.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A transport-neutral event emitted by a `MonaMessageTransport`.
///
/// The byte channel emits exactly these four events. The two terminal cases
/// (`.closed`, `.errored`) each fire at most once; after a terminal fires, no
/// further `.received`/`.sent` events are delivered. The first terminal wins —
/// a clean close suppresses a later error, and a later close is suppressed by
/// an earlier error.
public enum MonaTransportEvent {

    /// Ordered bytes received from the transport's peer. Delivered in arrival
    /// order. Not delivered after the transport has reached a terminal state.
    case received(Data)

    /// Bytes sent to the transport's peer. Delivered in issuance order,
    /// interleaved with `.received` as issued. Not delivered after the
    /// transport has reached a terminal state.
    case sent(Data)

    /// The transport closed cleanly. Terminal: fires at most once. After it
    /// fires, no further `.received`/`.sent` events are delivered.
    case closed

    /// The transport failed with `error`. Terminal: fires at most once. After
    /// it fires, no further `.received`/`.sent` events are delivered.
    case errored(Error)
}
