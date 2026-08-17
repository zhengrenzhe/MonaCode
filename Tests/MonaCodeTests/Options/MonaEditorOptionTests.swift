// MonaEditorOptionTests.swift
//
// P05-T005 — Implement all 174 editor options and computed option truth.
//
// Verifies the editor option system ported from monaco-editor@0.56.0:
//   - Exactly 174 options: 157 retained-input (mutable) + 6 computed-only
//     (derived, read-only) + 11 cut (excluded) — transcribed verbatim from the
//     F1-R3 scope manifest (`registries.options`), source-ordered.
//   - Input types, defaults, bounds, and enum membership validated per option.
//   - Extensible enums: a future (unknown) raw value does not break the system;
//     the default is a known member but new raw values are accepted on set.
//   - Dependency ordering: changing a retained-input option recomputes the
//     computed-only options that read it, in topological order, firing change
//     events for each recomputed computed option.
//   - Changed-option events fire via the shared `MonaEmitter` for both
//     retained-input and computed-only options.
//   - The 6 computed-only options are read-only (NOT exposed as mutable input).
//   - The 11 cut options are excluded from production input APIs.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import XCTest
import MonaCode

final class MonaEditorOptionTests: XCTestCase {

    // MARK: - 1. Exactly 174 options: 157 retained + 6 computed + 11 cut

    func testBuiltinTableCountIsExactly174() {
        XCTAssertEqual(MonaBuiltinOptions.options.count, 174,
                       "the F1-R3 builtin option table must contain exactly 174 options")
    }

    func testDispositionSplitIs157Retained6Computed11Cut() {
        let retained = MonaBuiltinOptions.retainedInputOptions
        let computed = MonaBuiltinOptions.computedOnlyOptions
        let cut = MonaBuiltinOptions.cutOptions
        XCTAssertEqual(retained.count, 157, "retained-input (mutable) count")
        XCTAssertEqual(computed.count, 6, "computed-only (derived) count")
        XCTAssertEqual(cut.count, 11, "cut (excluded) count")
        XCTAssertEqual(retained.count + computed.count + cut.count, 174)
    }

    func testOptionIdsAreSourceOrderedZeroBasedAndUnique() {
        let ids = MonaBuiltinOptions.options.map { $0.id }
        XCTAssertEqual(Array(ids.sorted()), Array(0..<174),
                       "ids must be 0…173 in source order")
        XCTAssertEqual(Set(ids).count, 174, "ids must be unique")
        for (index, option) in MonaBuiltinOptions.options.enumerated() {
            XCTAssertEqual(option.id, index,
                           "options[\(index)] must have id \(index) (source order)")
        }
    }

    func testNamesAreUniqueAndNoCoalescing() {
        let names = MonaBuiltinOptions.options.map { $0.name }
        XCTAssertEqual(Set(names).count, names.count,
                       "option names must be unique — no coalescing")
    }

    // MARK: - 2. The 6 computed-only options are exactly the manifest set

    func testComputedOnlyOptionsAreExactlyTheSixFromManifest() {
        let names = Set(MonaBuiltinOptions.computedOnlyOptions.map { $0.name })
        XCTAssertEqual(names, [
            "fontInfo",
            "effectiveCursorStyle",
            "pixelRatio",
            "layoutInfo",
            "wrappingInfo",
            "effectiveAllowVariableFonts",
        ])
        // Each computed-only option has runtimeName "_never_" (never set as
        // input — it is always derived) and declares its reads (which may be
        // empty for a platform-derived option like pixelRatio).
        for option in MonaBuiltinOptions.computedOnlyOptions {
            XCTAssertEqual(option.runtimeName, "_never_")
            XCTAssertEqual(option.disposition, .computedOnly)
        }
        // Five computed options derive from other options (non-empty reads);
        // pixelRatio derives from platform/environment state (empty reads).
        let derivingFromOptions = MonaBuiltinOptions.computedOnlyOptions.filter { !$0.reads.isEmpty }
        XCTAssertEqual(derivingFromOptions.count, 5)
        let pixelRatio = MonaBuiltinOptions.option(named: "pixelRatio")
        XCTAssertEqual(pixelRatio?.reads, [], "pixelRatio is platform-derived")
    }

    // MARK: - 3. The 11 cut options are exactly the manifest set

    func testCutOptionsAreExactlyTheElevenFromManifest() {
        let names = Set(MonaBuiltinOptions.cutOptions.map { $0.name })
        XCTAssertEqual(names, [
            "disableLayerHinting",
            "domReadOnly",
            "editContext",
            "experimentalGpuAcceleration",
            "experimentalWhitespaceRendering",
            "extraEditorClassName",
            "selectionClipboard",
            "useShadowDOM",
            "wordSegmenterLocales",
            "editorClassName",
            "effectiveEditContextEnabled",
        ])
        for option in MonaBuiltinOptions.cutOptions {
            XCTAssertEqual(option.disposition, .cut)
        }
    }

    // MARK: - 4. Input types / defaults / bounds validated

    func testEveryRetainedInputOptionHasATypeAndDefault() {
        for option in MonaBuiltinOptions.retainedInputOptions {
            guard let kind = option.kind else {
                XCTFail("\(option.name) must declare an input kind")
                continue
            }
            // The default must be non-nil and must match the declared kind.
            let defaultMatches = MonaEditorOptionTests.value(option.defaultValue, matchesKind: kind)
            XCTAssertTrue(defaultMatches,
                          "\(option.name) default \(option.defaultValue) must match kind \(kind)")
        }
    }

    func testBooleanDefaultsAreExactForKnownOptions() {
        // Verbatim from F1-R3 manifest (schema.default / defaultDefaultValue).
        XCTAssertEqual(self.option("acceptSuggestionOnCommitCharacter")?.defaultValue, .bool(true))
        XCTAssertEqual(self.option("folding")?.defaultValue, .bool(true))
        XCTAssertEqual(self.option("readOnly")?.defaultValue, .bool(false))
        XCTAssertEqual(self.option("columnSelection")?.defaultValue, .bool(false))
        XCTAssertEqual(self.option("smoothScrolling")?.defaultValue, .bool(false))
        XCTAssertEqual(self.option("tabFocusMode")?.defaultValue, .bool(false))
    }

    func testIntegerDefaultsAndBoundsAreExactForKnownOptions() {
        let accessibilityPageSize = self.option("accessibilityPageSize")
        XCTAssertEqual(accessibilityPageSize?.defaultValue, .int(500))
        XCTAssertEqual(accessibilityPageSize?.bounds?.min, 1)
        XCTAssertEqual(accessibilityPageSize?.bounds?.max, 1073741824)

        let foldingMaximumRegions = self.option("foldingMaximumRegions")
        XCTAssertEqual(foldingMaximumRegions?.defaultValue, .int(5000))
        XCTAssertEqual(foldingMaximumRegions?.bounds?.min, 10)
        XCTAssertEqual(foldingMaximumRegions?.bounds?.max, 65000)

        let wordWrapColumn = self.option("wordWrapColumn")
        XCTAssertEqual(wordWrapColumn?.defaultValue, .int(80))
        XCTAssertEqual(wordWrapColumn?.bounds?.min, 1)
        XCTAssertEqual(wordWrapColumn?.bounds?.max, 1073741824)
    }

    func testNumberDefaultsAndBoundsAreExactForKnownOptions() {
        let fontSize = self.option("fontSize")
        XCTAssertEqual(fontSize?.defaultValue, .double(12))
        XCTAssertEqual(fontSize?.bounds?.min, 6)
        XCTAssertEqual(fontSize?.bounds?.max, 100)

        let lineHeight = self.option("lineHeight")
        XCTAssertEqual(lineHeight?.defaultValue, .double(0))
        XCTAssertEqual(lineHeight?.bounds?.min, 0)
        XCTAssertEqual(lineHeight?.bounds?.max, 150)
    }

    func testStringDefaultsAreExactForKnownOptions() {
        XCTAssertEqual(self.option("fontFamily")?.defaultValue,
                       .string("Menlo, Monaco, 'Courier New', monospace"))
        XCTAssertEqual(self.option("mouseStyle")?.defaultValue, .string("text"))
        XCTAssertEqual(self.option("wordWrap")?.defaultValue, .string("off"))
        XCTAssertEqual(self.option("wrappingStrategy")?.defaultValue, .string("simple"))
    }

    func testEnumOptionDefaultsResolveToCanonicalStringMember() {
        // Monaco stores some enum defaults as numeric indices in the probe; the
        // canonical default is the string member (schema.default). MonaCode emits
        // the canonical string.
        XCTAssertEqual(self.option("accessibilitySupport")?.defaultValue, .string("auto"))
        XCTAssertEqual(self.option("autoIndent")?.defaultValue, .string("full"))
        XCTAssertEqual(self.option("cursorBlinking")?.defaultValue, .string("blink"))
        XCTAssertEqual(self.option("cursorStyle")?.defaultValue, .string("line"))
        XCTAssertEqual(self.option("overtypeCursorStyle")?.defaultValue, .string("block"))
        XCTAssertEqual(self.option("multiCursorModifier")?.defaultValue, .string("alt"))
        XCTAssertEqual(self.option("lineNumbers")?.defaultValue, .string("on"))
    }

    func testEveryEnumOptionDeclaresItsKnownMembers() {
        let enumOptions = MonaBuiltinOptions.retainedInputOptions.filter { $0.kind == .enumString }
        XCTAssertEqual(enumOptions.count, 34, "F1-R3 declares exactly 34 enum (extensible) options")
        for option in enumOptions {
            XCTAssertNotNil(option.enumMembers, "\(option.name) must declare enum members")
            XCTAssertFalse(option.enumMembers!.isEmpty, "\(option.name) members must be non-empty")
            // The canonical default must be a known member.
            if case .string(let defaultValue) = option.defaultValue {
                XCTAssertTrue(option.enumMembers!.contains(defaultValue),
                              "\(option.name) default '\(defaultValue)' must be a known member of \(option.enumMembers!)")
            } else {
                XCTFail("\(option.name) enum default must be a string")
            }
        }
    }

    func testArrayOptionRulers() {
        let rulers = self.option("rulers")
        XCTAssertEqual(rulers?.kind, .array)
        XCTAssertEqual(rulers?.defaultValue, .array([]))
    }

    func testObjectOptionMinimapHasObjectDefault() {
        let minimap = self.option("minimap")
        XCTAssertEqual(minimap?.kind, .object)
        if case .object = minimap?.defaultValue { } else {
            XCTFail("minimap default must be an object value")
        }
    }

    // MARK: - 5. Enum extensibility: a future raw value does not break

    func testEnumExtensibilityAcceptsUnknownRawValueOnSet() {
        let store = MonaOptionStore()
        // cursorStyle has known members line/block/underline/...; a future raw
        // value "phantom" is NOT a known member but is ACCEPTED (extensible).
        let result = store.setValue(.string("phantom"), for: "cursorStyle")
        XCTAssertEqual(result, .success)
        XCTAssertEqual(store.value(for: "cursorStyle"), .string("phantom"))
    }

    func testEnumExtensibilityUnknownRawValueDoesNotBreakKnownMembers() {
        let store = MonaOptionStore()
        _ = store.setValue(.string("phantom"), for: "wordWrap")
        // After accepting an unknown raw value, known members still validate.
        let result = store.setValue(.string("bounded"), for: "wordWrap")
        XCTAssertEqual(result, .success)
        XCTAssertEqual(store.value(for: "wordWrap"), .string("bounded"))
    }

    // MARK: - 6. Dependency ordering resolved (computed recompute in order)

    func testChangingFontSizeRecomputesFontInfoThenLayoutInfoInOrder() {
        let store = MonaOptionStore()
        var events: [MonaOptionChangeEvent] = []
        let disposable = store.onDidChangeOption { event in
            events.append(event)
        }
        defer { disposable.dispose() }

        // Change fontSize (a retained-input that fontInfo reads, and fontInfo is
        // read by layoutInfo). The store must recompute fontInfo BEFORE layoutInfo
        // (topological dependency order).
        _ = store.setValue(.double(20), for: "fontSize")

        // The change events fired include fontSize (input), fontInfo (computed),
        // and layoutInfo (computed, depends on fontInfo) — in that order.
        let names = events.map { $0.optionName }
        let fontSizeIdx = names.firstIndex(of: "fontSize")
        let fontInfoIdx = names.firstIndex(of: "fontInfo")
        let layoutInfoIdx = names.firstIndex(of: "layoutInfo")
        XCTAssertNotNil(fontSizeIdx)
        XCTAssertNotNil(fontInfoIdx)
        XCTAssertNotNil(layoutInfoIdx)
        XCTAssertLessThan(fontSizeIdx!, fontInfoIdx!, "fontInfo must recompute after fontSize")
        XCTAssertLessThan(fontInfoIdx!, layoutInfoIdx!, "layoutInfo must recompute after fontInfo")

        // The computed change events are flagged isComputed.
        XCTAssertTrue(events[fontInfoIdx!].isComputed)
        XCTAssertTrue(events[layoutInfoIdx!].isComputed)
        XCTAssertFalse(events[fontSizeIdx!].isComputed)
    }

    func testChangingCursorStyleRecomputesEffectiveCursorStyle() {
        let store = MonaOptionStore()
        var events: [MonaOptionChangeEvent] = []
        let disposable = store.onDidChangeOption { event in events.append(event) }
        defer { disposable.dispose() }

        _ = store.setValue(.string("block"), for: "cursorStyle")
        let names = events.map { $0.optionName }
        XCTAssertTrue(names.contains("cursorStyle"))
        XCTAssertTrue(names.contains("effectiveCursorStyle"))
        // effectiveCursorStyle derives from cursorStyle → it fires AFTER.
        XCTAssertLessThan(names.firstIndex(of: "cursorStyle")!,
                          names.firstIndex(of: "effectiveCursorStyle")!)
    }

    // MARK: - 7. Changed-option events fire (input + computed)

    func testChangingRetainedInputFiresChangeEvent() {
        let store = MonaOptionStore()
        var events: [MonaOptionChangeEvent] = []
        let disposable = store.onDidChangeOption { event in events.append(event) }
        defer { disposable.dispose() }

        let old = store.value(for: "wordWrap")
        XCTAssertEqual(old, .string("off"))
        _ = store.setValue(.string("on"), for: "wordWrap")
        // The input change event for wordWrap is present among the fired events.
        let wordWrapEvent = events.first { $0.optionName == "wordWrap" }
        XCTAssertNotNil(wordWrapEvent)
        XCTAssertEqual(wordWrapEvent?.oldValue, .string("off"))
        XCTAssertEqual(wordWrapEvent?.newValue, .string("on"))
        XCTAssertFalse(wordWrapEvent?.isComputed ?? true)
    }

    func testNoChangeEventWhenValueUnchanged() {
        let store = MonaOptionStore()
        var count = 0
        let disposable = store.onDidChangeOption { _ in count += 1 }
        defer { disposable.dispose() }
        // wordWrap default is "off"; setting "off" again must NOT fire.
        _ = store.setValue(.string("off"), for: "wordWrap")
        XCTAssertEqual(count, 0)
    }

    // MARK: - 8. The 6 computed-only are read-only (NOT settable)

    func testComputedOnlyOptionsAreNotSettable() {
        let store = MonaOptionStore()
        for name in MonaOptionStore.computedOptionNames {
            let result = store.setValue(.bool(true), for: name)
            XCTAssertEqual(result, .computedNotSettable(name),
                           "\(name) is computed-only and must not be settable as input")
        }
    }

    func testComputedOnlyOptionsAreReadableOnStore() {
        let store = MonaOptionStore()
        // Each computed-only option has a read accessor returning a derived value.
        XCTAssertNotNil(store.value(for: "fontInfo"))
        XCTAssertNotNil(store.value(for: "effectiveCursorStyle"))
        XCTAssertNotNil(store.value(for: "pixelRatio"))
        XCTAssertNotNil(store.value(for: "layoutInfo"))
        XCTAssertNotNil(store.value(for: "wrappingInfo"))
        XCTAssertNotNil(store.value(for: "effectiveAllowVariableFonts"))
    }

    func testComputedDerivedValueReflectsInputs() {
        let store = MonaOptionStore()
        // effectiveCursorStyle derives from cursorStyle: setting cursorStyle to
        // "block" makes the effective style "block".
        _ = store.setValue(.string("block"), for: "cursorStyle")
        XCTAssertEqual(store.effectiveCursorStyle, .string("block"))
        // effectiveAllowVariableFonts is false when allowVariableFonts is false.
        _ = store.setValue(.bool(false), for: "allowVariableFonts")
        XCTAssertEqual(store.effectiveAllowVariableFonts, .bool(false))
    }

    // MARK: - 9. The 11 cut options are excluded from input APIs

    func testCutOptionsAreExcludedFromInputAPI() {
        let store = MonaOptionStore()
        for name in MonaOptionStore.cutOptionNames {
            // setValue on a cut option is rejected as cut (excluded).
            let result = store.setValue(.bool(false), for: name)
            XCTAssertEqual(result, .cutOption(name),
                           "\(name) is cut and must be excluded from input APIs")
            // value(for:) returns nil — cut options are not readable inputs.
            XCTAssertNil(store.value(for: name),
                         "\(name) is cut and must not be exposed as a readable input")
        }
    }

    func testCutOptionNamesAreExactlyEleven() {
        XCTAssertEqual(MonaOptionStore.cutOptionNames.count, 11)
        XCTAssertEqual(Set(MonaOptionStore.cutOptionNames),
                       Set(MonaBuiltinOptions.cutOptions.map { $0.name }))
    }

    func testComputedOptionNamesAreExactlySix() {
        XCTAssertEqual(MonaOptionStore.computedOptionNames.count, 6)
        XCTAssertEqual(Set(MonaOptionStore.computedOptionNames),
                       Set(MonaBuiltinOptions.computedOnlyOptions.map { $0.name }))
    }

    // MARK: - 10. Type / bounds validation on set

    func testTypeMismatchRejected() {
        let store = MonaOptionStore()
        // folding is boolean; setting an int must be a type mismatch.
        let result = store.setValue(.int(3), for: "folding")
        if case .typeMismatch = result {
            // expected
        } else {
            XCTFail("expected typeMismatch for boolean option folding, got \(result)")
        }
    }

    func testOutOfBoundsRejected() {
        let store = MonaOptionStore()
        // fontSize bounds: [6, 100]. Setting 0 (below min) must be rejected.
        let tooSmall = store.setValue(.double(0), for: "fontSize")
        if case .outOfBounds = tooSmall {
            // expected
        } else {
            XCTFail("expected outOfBounds for fontSize=0 (min 6), got \(tooSmall)")
        }
        let tooLarge = store.setValue(.double(200), for: "fontSize")
        if case .outOfBounds = tooLarge {
            // expected
        } else {
            XCTFail("expected outOfBounds for fontSize=200 (max 100), got \(tooLarge)")
        }
    }

    func testBoundsAcceptedAtExtrema() {
        let store = MonaOptionStore()
        // fontSize bounds [6, 100]: both 6 and 100 are accepted (inclusive).
        XCTAssertEqual(store.setValue(.double(6), for: "fontSize"), .success)
        XCTAssertEqual(store.setValue(.double(100), for: "fontSize"), .success)
    }

    func testUnknownOptionRejected() {
        let store = MonaOptionStore()
        let result = store.setValue(.bool(true), for: "no.such.option")
        XCTAssertEqual(result, .unknownOption)
        XCTAssertNil(store.value(for: "no.such.option"))
    }

    // MARK: - 11. Snapshot exposes retained + computed (not cut), read-only

    func testSnapshotContainsRetainedPlusComputedExcludesCut() {
        let store = MonaOptionStore()
        let snapshot = store.snapshot()
        // 157 retained + 6 computed = 163 readable values; cut excluded.
        XCTAssertEqual(snapshot.count, 163)
        // A retained-input option is in the snapshot.
        XCTAssertNotNil(snapshot.value(for: "wordWrap"))
        // A computed-only option is in the snapshot.
        XCTAssertNotNil(snapshot.value(for: "fontInfo"))
        // A cut option is NOT in the snapshot.
        XCTAssertNil(snapshot.value(for: "disableLayerHinting"))
    }

    func testSnapshotReflectsCurrentValues() {
        let store = MonaOptionStore()
        _ = store.setValue(.string("bounded"), for: "wordWrap")
        let snapshot = store.snapshot()
        XCTAssertEqual(snapshot.value(for: "wordWrap"), .string("bounded"))
    }

    // MARK: - 12. Disposal is idempotent (reuse MonaEmitter semantics)

    func testStoreDisposalIsIdempotent() {
        let store = MonaOptionStore()
        store.dispose()
        store.dispose()
        XCTAssertTrue(store.isDisposed)
        // After dispose, onDidChangeOption returns an inert disposable (emitter
        // semantics) and setValue is a no-op / safe.
        let disposable = store.onDidChangeOption { _ in }
        disposable.dispose() // must not crash
    }

    // MARK: - 13. Contract leaf

    func testOptionsContractLeaf() {
        let store = MonaOptionStore()
        let retained = MonaBuiltinOptions.retainedInputOptions.count
        let computed = MonaBuiltinOptions.computedOnlyOptions.count
        let cut = MonaBuiltinOptions.cutOptions.count
        let total = MonaBuiltinOptions.options.count
        let snapshotCount = store.snapshot().count

        let excludedPass = MonaOptionStore.cutOptionNames.count == 11 &&
            MonaOptionStore.computedOptionNames.count == 6
        let readOnlyPass = store.setValue(.bool(true), for: "fontInfo") == .computedNotSettable("fontInfo")
        let eventsPass: Bool
        do {
            var fired = false
            let d = store.onDidChangeOption { _ in fired = true }
            _ = store.setValue(.string("on"), for: "wordWrap")
            d.dispose()
            eventsPass = fired
        }
        store.dispose()
        let idempotentPass = store.isDisposed

        print("OPTIONS total=\(total) retained=\(retained) computed=\(computed) cut=\(cut) snapshot=\(snapshotCount) excluded=\(excludedPass ? "pass" : "fail") readonly=\(readOnlyPass ? "pass" : "fail") events=\(eventsPass ? "pass" : "fail") idempotent=\(idempotentPass ? "pass" : "fail")")

        XCTAssertEqual(total, 174)
        XCTAssertEqual(retained, 157)
        XCTAssertEqual(computed, 6)
        XCTAssertEqual(cut, 11)
        XCTAssertTrue(excludedPass)
        XCTAssertTrue(readOnlyPass)
        XCTAssertTrue(eventsPass)
        XCTAssertTrue(idempotentPass)
    }

    // MARK: - Helpers

    private func option(_ name: String) -> MonaEditorOption? {
        return MonaBuiltinOptions.options.first { $0.name == name }
    }

    /// Returns `true` when `value` matches `kind`.
    private static func value(_ value: MonaOptionValue, matchesKind kind: MonaOptionKind) -> Bool {
        switch kind {
        case .boolean:
            if case .bool = value { return true }
            return false
        case .integer:
            if case .int = value { return true }
            return false
        case .number:
            if case .double = value { return true }
            return false
        case .string, .enumString:
            if case .string = value { return true }
            return false
        case .object:
            if case .object = value { return true }
            if case .null = value { return true } // placeholder/readOnlyMessage $undefined
            return false
        case .array:
            if case .array = value { return true }
            return false
        }
    }
}
