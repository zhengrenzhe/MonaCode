# MonaCode G4-R full-scope design

Status: adopted and frozen on 2026-08-14.

This document is the repository design entry point. It does not duplicate the complete machine contract. The normative definition is the immutable [G4-R authoritative manifest](../../contracts/monaco-editor-0.56.0/g4-r/artifacts/monacode-g4r-authoritative-manifest.json), selected by [adoption-record.json](../../contracts/monaco-editor-0.56.0/g4-r/adoption-record.json) at SHA-256 `f4d0da0ff6c1ad90ab1376588260afd6c92c1eca236619449c9b6532b5e57021`.

## Product objective

Build a native Swift code-editor component for Apple platforms whose retained behavior and performance do not fall below the fixed `monaco-editor@0.56.0` baselines. The current release target is arm64 macOS on the recorded validation machine. iOS and iPadOS require a later global revision and do not enter the current release verdict.

## Frozen architecture

- `MonaCodeModel` is the single raw UTF-16 text authority and retains the complete contracted `ITextModel` surface.
- The live model, transactions, versioning, undo, decorations, synchronous events, and editor state use the adopted thin-MainActor ownership model.
- Background layout, diff, providers, file preparation, and LSP consume immutable versioned snapshots; stale results pass through an explicit version gate.
- Core Text is the shaping, layout, geometry, and hit-test authority.
- Core Graphics is the first complete renderer. Metal implementation starts only when the fixed renderer-owned gate fires; both renderers consume the same line-layout records.
- AppKit uses a custom `NSView`, `NSTextInputClient`, and native accessibility surface. SwiftUI owns lifecycle and embedding only.
- Language infrastructure retains the contracted provider and LSP architecture. The product bundles no code-language implementation, grammar pack, snippet catalog, or LSP server. Missing language services degrade to plain text.
- Host integration, localization, Markdown, standalone services, snippets, diff, themes, input, accessibility, source/style closure, and all explicit cuts follow their G4-R manifests without phase-level reinterpretation.

## Correctness and performance contract

Correctness gates C01-C10 and performance workloads P00-P13 are blocking. Every registered workload, metric, refresh-rate cell, and M0/M1 comparator cell must pass the paired one-sided 95% bootstrap upper-bound rule `native/comparator <= 1.00`. Refresh rate changes the frame deadline only: 60 Hz uses 16.666... ms and 120 Hz uses 8.333... ms. It never weakens the relative no-worse-than-Monaco threshold.

## Implementation state

At adoption, product Swift source, executables, generated tables, seven candidate manifests, and passed acceptance gates all equal zero. The contract is complete; the product is not implemented and has not passed release acceptance.

## Development rule

Implementation phases decompose and order the frozen work. Each phase must identify its G4-R domain, source manifest, produced candidate artifact, correctness gate, and performance cells. A phase cannot add a feature, cut, fallback, native adaptation, later platform target, or implementation discretion absent from G4-R. Any such request starts a new global revision.
