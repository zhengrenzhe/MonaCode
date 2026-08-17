// MonaEvent.swift
//
// P01-T005 — Implement deterministic events and idempotent disposal.
//
// `MonaEvent<T>` is the typed subscribe function — the Swift counterpart of
// Monaco's `Event<T>` (monaco-editor 0.56.0, vendored from vscode's
// `vs/base/common/event.ts`):
//
//     export type Event<T> = (
//         listener: (e: T) => void, thisArgs?: any, disposables?: IDisposable[]
//     ) => IDisposable;
//
// In Swift the `thisArgs` binding is unnecessary (closures capture `self`
// directly) and the `disposables` auto-collection convenience is omitted, so
// `MonaEvent<T>` is the function type that accepts a listener callback and
// returns a `MonaDisposable` whose `dispose()` removes the listener:
//
//     public typealias MonaEvent<T> = (@escaping (T) throws -> Void) -> MonaDisposable
//
// The listener is `@escaping` because the emitter stores it. The listener
// callback receives the fired value `T`. It may throw: Monaco's delivery wraps
// each listener invoke in a try/catch and routes failures to a declared error
// boundary (`onListenerError`) without aborting delivery to later listeners.
// The Swift port preserves that runtime behavior — the callback type is
// `(T) throws -> Void` so failures are real and catchable, while
// `MonaEmitter.fire(_:)` itself is non-throwing (it contains every failure
// through the boundary). A non-throwing `(T) -> Void` closure is a valid
// argument, since a non-throwing closure is a subtype of a throwing one.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The typed subscribe function for a `MonaEmitter<T>`.
///
/// A value of type `MonaEvent<T>` accepts a listener callback `(T) throws
/// -> Void` and returns a `MonaDisposable` whose `dispose()` removes that
/// listener. `MonaEmitter.event` exposes a value of this type; model surfaces
/// typically expose `var onDidChange: MonaEvent<Void>` and consumers subscribe
/// by calling it.
///
/// The listener is `@escaping` because the emitter stores it for later
/// delivery. The listener may throw; the owning emitter routes any thrown
/// error through its declared `onListenerError` boundary without skipping
/// later listeners.
public typealias MonaEvent<T> = (@escaping (T) throws -> Void) -> MonaDisposable
