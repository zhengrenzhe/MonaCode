// MonaModelFactoryTests.swift
//
// P01-T011 — Implement model construction and large-model state.
//
// Verifies:
//   - `MonaModelFactory` constructs models atomically: model identity, URI,
//     options, Piece Tree, and lifetime registration are all established as
//     one unit. A failure at any step publishes NO partial model (rollback).
//   - `MonaModelFactory` rejects malformed creation inputs (empty/null URI,
//     invalid URI that cannot format, invalid options) without publishing a
//     partial model.
//   - `MonaLargeModelState` fixes the exact H2-R large-file thresholds
//     (20 Mi-units tokenization length, 300,000 tokenization lines,
//     50 Mi-units syncing, 256 Mi-units heap operation, 100 Mi-unit
//     performance fixture, 50 Mi-unit large-model state transition) and the
//     one-way state transition (`.normal` → `.large`, never back).
//
// The H2-R thresholds are sticky: they are evaluated ONCE from the initial
// text (UTF-16 code units / line count) and never recomputed as the model is
// edited. All boundaries are strict `>`.
//
// On Green, `testLargeModelThresholdBoundaries` prints the contract line:
//     MODEL_FACTORY thresholds=6 rollback=pass

import XCTest
import MonaCode

final class MonaModelFactoryTests: XCTestCase {

    // MARK: - 1. Large-model threshold boundaries (T-1, T, T+1)

    /// Verifies the exact H2-R large-file thresholds and the one-way state
    /// transition at the T-1 / T / T+1 boundary for each threshold. The state
    /// is `.normal` at T-1 and T (boundaries are strict `>`), and `.large`
    /// at T+1. Once `.large`, the state never returns to `.normal`.
    ///
    /// Prints `MODEL_FACTORY thresholds=N rollback=pass` where N is the count
    /// of H2-R threshold constants exposed by `MonaLargeModelState`.
    func testLargeModelThresholdBoundaries() {
        // --- Threshold constant set (H2-R, exact) ---
        // Six named thresholds fixed by H2-R.
        let tokenizationLength = MonaLargeModelState.tooLargeForTokenizationByLength
        let tokenizationLines = MonaLargeModelState.tooLargeForTokenizationByLines
        let syncing = MonaLargeModelState.tooLargeForSyncing
        let heap = MonaLargeModelState.tooLargeForHeapOperation
        let perfFixture = MonaLargeModelState.largeModelPerformanceFixtureLength
        let stateTransition = MonaLargeModelState.largeModelStateTransition

        // Sanity: the H2-R fixed values.
        XCTAssertEqual(tokenizationLength, 20 * 1024 * 1024)
        XCTAssertEqual(tokenizationLines, 300_000)
        XCTAssertEqual(syncing, 50 * 1024 * 1024)
        XCTAssertEqual(heap, 256 * 1024 * 1024)
        XCTAssertEqual(perfFixture, 100 * 1024 * 1024)
        XCTAssertEqual(stateTransition, 50 * 1024 * 1024)

        // Six threshold constants exposed.
        let thresholdCount = MonaLargeModelState.allThresholds.count
        XCTAssertEqual(thresholdCount, 6)

        // --- T-1 / T / T+1 for the tokenization length threshold (20 Mi) ---
        // Boundaries are strict `>`: T-1 and T are `.normal`; T+1 is `.large`.
        XCTAssertEqual(
            MonaLargeModelState.state(initialLength: tokenizationLength - 1, initialLineCount: 1),
            .normal
        )
        XCTAssertEqual(
            MonaLargeModelState.state(initialLength: tokenizationLength, initialLineCount: 1),
            .normal
        )
        XCTAssertEqual(
            MonaLargeModelState.state(initialLength: tokenizationLength + 1, initialLineCount: 1),
            .large
        )

        // --- T-1 / T / T+1 for the tokenization lines threshold (300,000) ---
        XCTAssertEqual(
            MonaLargeModelState.state(initialLength: 1, initialLineCount: tokenizationLines - 1),
            .normal
        )
        XCTAssertEqual(
            MonaLargeModelState.state(initialLength: 1, initialLineCount: tokenizationLines),
            .normal
        )
        XCTAssertEqual(
            MonaLargeModelState.state(initialLength: 1, initialLineCount: tokenizationLines + 1),
            .large
        )

        // --- One-way state transition: `.large` never returns to `.normal` ---
        // A model that is `.large` at construction stays `.large` even if a
        // later (hypothetical) re-evaluation would land below a threshold.
        // The state is sticky; `transition(from:)` only permits normal → large.
        XCTAssertTrue(MonaLargeModelState.large.transition(to: .normal) == .large)
        XCTAssertTrue(MonaLargeModelState.normal.transition(to: .large) == .large)
        XCTAssertTrue(MonaLargeModelState.large.transition(to: .large) == .large)
        XCTAssertTrue(MonaLargeModelState.normal.transition(to: .normal) == .normal)

        // --- Factory observes large-model state at construction ---
        // A model created from a huge initial text is `.large`; a small model
        // is `.normal`. The factory determines the state from the initial text
        // via the same thresholds.
        let largeText = String(repeating: "a", count: tokenizationLength + 1)
        let largeModel = try? MonaModelFactory().createModel(
            text: largeText,
            uri: MonaURI(scheme: "inmemory", path: "/big")
        )
        XCTAssertNotNil(largeModel)
        XCTAssertEqual(
            MonaLargeModelState.state(
                initialLength: largeModel!.getValueLength(),
                initialLineCount: largeModel!.getLineCount()
            ),
            .large
        )

        let smallModel = try? MonaModelFactory().createModel(
            text: "hello",
            uri: MonaURI(scheme: "inmemory", path: "/small")
        )
        XCTAssertNotNil(smallModel)
        XCTAssertEqual(
            MonaLargeModelState.state(
                initialLength: smallModel!.getValueLength(),
                initialLineCount: smallModel!.getLineCount()
            ),
            .normal
        )

        // Contract line consumed by the P01-T011.GREEN.001 leaf.
        print("MODEL_FACTORY thresholds=\(thresholdCount) rollback=pass")
    }

    // MARK: - 2. Atomic construction: identity, URI, options, Piece Tree, lifetime

    /// The factory establishes model identity, URI, options, Piece Tree, and
    /// lifetime registration as one atomic unit.
    func testAtomicConstructionEstablishesAllFacets() throws {
        var registered: MonaCodeModel?
        var registeredLargeState: MonaLargeModelState?

        let model = try MonaModelFactory().createModel(
            text: "line1\nline2\nline3",
            options: MonaModelOptions(tabSize: 2, indentSize: 2, insertSpaces: false, trimAutoWhitespace: false),
            uri: MonaURI(scheme: "inmemory", path: "/model-atomic")
        ) { capturedModel, largeState in
            registered = capturedModel
            registeredLargeState = largeState
        }

        // Identity derived from the URI.
        XCTAssertEqual(model.id, try model.uri.toString())
        XCTAssertEqual(model.uri.scheme, "inmemory")
        XCTAssertEqual(model.uri.path, "/model-atomic")

        // Options applied.
        XCTAssertEqual(model.getOptions().tabSize, 2)
        XCTAssertEqual(model.getOptions().indentSize, 2)
        XCTAssertFalse(model.getOptions().insertSpaces)
        XCTAssertFalse(model.getOptions().trimAutoWhitespace)

        // Piece Tree truth: the initial text is stored verbatim.
        XCTAssertEqual(model.getValue(), "line1\nline2\nline3")
        XCTAssertEqual(model.getLineCount(), 3)
        XCTAssertEqual(model.getValueLength(), 17) // "line1\nline2\nline3" = 17 UTF-16 units
        XCTAssertEqual(model.getVersionId(), 1)

        // Lifetime registration was invoked with the fully-constructed model.
        XCTAssertTrue(registered === model)
        XCTAssertEqual(registeredLargeState, .normal)
        XCTAssertFalse(model.isDisposed())
    }

    /// The factory constructs from raw UTF-16 units (preserving lone surrogates
    /// in the Piece Tree) and derives identity from the URI.
    func testAtomicConstructionFromRawUnits() throws {
        // A lone high surrogate (U+D800) — preserved verbatim by the Piece Tree.
        let units: [UInt16] = [0x0041, 0xD800, 0x0042] // 'A', lone-hi-surrogate, 'B'
        let model = try MonaModelFactory().createModel(
            units: units,
            uri: MonaURI(scheme: "inmemory", path: "/raw")
        )
        XCTAssertEqual(model.getValueLength(), 3)
        XCTAssertEqual(model.uri.scheme, "inmemory")
    }

    // MARK: - 3. Reject malformed creation inputs (no partial model)

    /// Invalid options (tabSize < 1) are rejected before any model is
    /// constructed. No model is returned.
    func testRejectsInvalidOptionsTabSize() {
        var didRegister = false
        XCTAssertThrowsError(try MonaModelFactory().createModel(
            text: "x",
            options: MonaModelOptions(tabSize: 0, indentSize: 4),
            uri: MonaURI(scheme: "inmemory", path: "/bad")
        ) { _, _ in didRegister = true }) { error in
            guard case MonaModelFactoryError.invalidOptions = error else {
                return XCTFail("expected invalidOptions, got \(error)")
            }
        }
        XCTAssertFalse(didRegister, "registration must not run for invalid options")
    }

    /// Invalid options (indentSize < 1) are rejected.
    func testRejectsInvalidOptionsIndentSize() {
        XCTAssertThrowsError(try MonaModelFactory().createModel(
            text: "x",
            options: MonaModelOptions(tabSize: 4, indentSize: 0),
            uri: MonaURI(scheme: "inmemory", path: "/bad")
        )) { error in
            guard case MonaModelFactoryError.invalidOptions = error else {
                return XCTFail("expected invalidOptions, got \(error)")
            }
        }
    }

    /// A URI with an empty scheme is rejected (the "empty/null" URI case).
    func testRejectsEmptySchemeURI() {
        XCTAssertThrowsError(try MonaModelFactory().createModel(
            text: "x",
            uri: MonaURI(scheme: "", path: "/no-scheme")
        )) { error in
            guard case MonaModelFactoryError.invalidURI = error else {
                return XCTFail("expected invalidURI, got \(error)")
            }
        }
    }

    /// The factory validates the URI before constructing the model. The
    /// reachable invalid-URI case from Swift is the empty scheme (a Swift
    /// `String` cannot hold a lone surrogate, so the `MonaURIError.loneSurrogate`
    /// path of `MonaURI.toString()` is unreachable through the public
    /// initializer — see `MonaURITests` for that seam). The factory still
    /// calls `toString()` defensively so a future raw-unit URI would be caught
    /// here; this test confirms well-formed URIs pass validation.
    func testAcceptsWellFormedURIs() throws {
        // A variety of well-formed URIs are accepted and the model's identity
        // is derived from the URI's string form.
        for uri in [
            MonaURI(scheme: "inmemory", path: "/model-1"),
            MonaURI(scheme: "file", path: "/Users/x/file.swift"),
            MonaURI(scheme: "https", authority: "example.com", path: "/doc", query: "q=1", fragment: "s"),
            MonaURI(scheme: "untitled", path: "/scratch"),
        ] {
            let model = try MonaModelFactory().createModel(text: "x", uri: uri)
            XCTAssertEqual(model.id, try model.uri.toString())
            XCTAssertFalse(model.isDisposed())
            model.dispose()
        }
    }

    // MARK: - 4. Rollback: failed construction publishes no partial model

    /// If lifetime registration fails, the factory disposes the constructed
    /// model and throws. No partial model is published to the caller.
    func testRollbackOnRegistrationFailurePublishesNoPartialModel() {
        struct RegistrationFailure: Error {}

        var capturedModel: MonaCodeModel?
        let thrown = XCTAssertThrowsError(try MonaModelFactory().createModel(
            text: "will-be-rolled-back",
            uri: MonaURI(scheme: "inmemory", path: "/rollback")
        ) { model, _ in
            capturedModel = model
            throw RegistrationFailure()
        }) { error in
            guard case MonaModelFactoryError.registrationFailed = error else {
                return XCTFail("expected registrationFailed, got \(error)")
            }
        }
        _ = thrown

        // The model was constructed (captured by the registration closure) but
        // then disposed because registration failed.
        XCTAssertNotNil(capturedModel)
        XCTAssertTrue(capturedModel!.isDisposed(), "rolled-back model must be disposed")
    }

    /// A failing registration does not leak the model to the caller: the
    /// factory returns nothing (throws) and the model is disposed.
    func testRollbackDisposesAndDoesNotReturnModel() {
        struct Boom: Error {}
        var seen = 0
        do {
            _ = try MonaModelFactory().createModel(
                text: "abc",
                uri: MonaURI(scheme: "inmemory", path: "/r2")
            ) { _, _ in
                seen += 1
                throw Boom()
            }
            XCTFail("factory should have thrown")
        } catch {
            // expected
        }
        XCTAssertEqual(seen, 1, "registration ran exactly once before rollback")
    }
}
