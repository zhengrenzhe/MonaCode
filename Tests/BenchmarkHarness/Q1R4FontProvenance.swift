// Q1R4FontProvenance.swift
//
// P00-T010 — Enforce font provenance, cold launch, display isolation, and refresh cells.
//
// `Q1R4FontProvenance` hashes every used font file and table and records the
// variation axes plus run coverage for each face. The signed manifest rejects
// any unmanifested face or run: a face not registered (by family + PostScript +
// file hash) is rejected, and a run whose glyph/run/code-point coverage exceeds
// the declared envelope is rejected.
//
// Q1-R4 environment/font/cold closure (verification-q1r4-environment-font-cold-closure):
//   - Font base: Menlo/Monaco/Courier New file hashes; size 12, normal weight,
//     lineHeight 18, letterSpacing 0, zoom 0.
//   - Font fallback (per rendered corpus): family, PostScript, file/table hash,
//     variation axes, glyph/run coverage.
//   - Chrome resolves via the pinned CDP protocol (CSS.getPlatformFontsForNode);
//     native resolves via CTRun/kCTFontAttributeName. The CDP protocol hash and
//     the returned face list both enter the product-specific manifest.
//   - Any unmanifested face or run invalidates the measurement.
//
// MonaCode is a Foundation-only boundary: `import Foundation` is the sole
// import. SHA-256 is the pure-Swift implementation already present in this
// target (BootstrapStatistics.swift from P00-T009), reused verbatim so the
// provenance recorder stays reproducible without CryptoKit. This file lives in
// the `benchmark-harness` non-product target.

import Foundation

// MARK: - Font variation axes and run coverage

/// One variation axis declared by a font (e.g. `wght` 100–900, default 400).
/// Recorded verbatim from the resolved font so a re-resolution that changes the
/// axis envelope is detectable.
public struct FontVariationAxis: Equatable, Sendable {
    /// The 4-character axis tag (e.g. `"wght"`, `"wdth"`, `"ital"`).
    public let tag: String
    public let minimum: Double
    public let maximum: Double
    public let defaultValue: Double

    public init(tag: String, minimum: Double, maximum: Double, defaultValue: Double) {
        self.tag = tag
        self.minimum = minimum
        self.maximum = maximum
        self.defaultValue = defaultValue
    }
}

/// The glyph/run coverage recorded for one face: how many glyphs the face
/// provides, how many runs it was used in, and the set of code points the runs
/// touched. A used run is "unmanifested" when its coverage exceeds this
/// declared envelope.
public struct FontRunCoverage: Equatable, Sendable {
    public let glyphCount: Int
    public let runCount: Int
    public let coveredCodePoints: Set<UInt32>

    public init(glyphCount: Int, runCount: Int, coveredCodePoints: Set<UInt32>) {
        self.glyphCount = glyphCount
        self.runCount = runCount
        self.coveredCodePoints = coveredCodePoints
    }

    /// An empty coverage envelope (no glyphs, no runs, no code points). The
    /// default for a face whose coverage has not yet been probed.
    public static let empty = FontRunCoverage(glyphCount: 0, runCount: 0, coveredCodePoints: [])

    /// `true` iff `other` fits within this declared envelope: no more glyphs,
    /// no more runs, and no code point outside the declared set.
    public func contains(_ other: FontRunCoverage) -> Bool {
        guard other.glyphCount <= glyphCount else { return false }
        guard other.runCount <= runCount else { return false }
        return other.coveredCodePoints.isSubset(of: coveredCodePoints)
    }
}

// MARK: - FontRecord

/// One resolved font face with its provenance hashes, variation axes, and run
/// coverage. Two records are equal iff every field matches; the `fileHash`
/// alone identifies the font file bytes, and the per-table hashes identify each
/// OpenType table (cmap, glyf, head, …) independently.
public struct FontRecord: Equatable, Sendable {
    public let familyName: String
    public let postScriptName: String
    /// Hex SHA-256 of the font file bytes.
    public let fileHash: String
    /// OpenType table tag → hex SHA-256 of that table's bytes.
    public let tableHashes: [String: String]
    public let variationAxes: [FontVariationAxis]
    public let runCoverage: FontRunCoverage

    public init(
        familyName: String,
        postScriptName: String,
        fileHash: String,
        tableHashes: [String: String],
        variationAxes: [FontVariationAxis],
        runCoverage: FontRunCoverage
    ) {
        self.familyName = familyName
        self.postScriptName = postScriptName
        self.fileHash = fileHash
        self.tableHashes = tableHashes
        self.variationAxes = variationAxes
        self.runCoverage = runCoverage
    }

    /// The canonical identity key used for manifest registration and dedup. Two
    /// faces with the same key are the same provenance face.
    public var identityKey: String {
        return familyName + "\u{0}" + postScriptName + "\u{0}" + fileHash
    }
}

// MARK: - FontProvenanceManifest

/// The signed font provenance manifest: the base fonts (Menlo/Monaco/Courier
/// New), the per-corpus resolved fonts, and the pinned CDP protocol hash. The
/// `manifestHash` is the hex SHA-256 of a canonical, order-independent
/// serialization, so it is a pure function of the signed content.
public struct FontProvenanceManifest: Equatable, Sendable {
    public let baseFonts: [FontRecord]
    public let corpusFonts: [FontRecord]
    public let cdpProtocolHash: String
    public let manifestHash: String

    public init(
        baseFonts: [FontRecord],
        corpusFonts: [FontRecord],
        cdpProtocolHash: String,
        manifestHash: String
    ) {
        self.baseFonts = baseFonts
        self.corpusFonts = corpusFonts
        self.cdpProtocolHash = cdpProtocolHash
        self.manifestHash = manifestHash
    }
}

// MARK: - Q1R4FontProvenance

/// Hashes every used font file and table, records variation axes and run
/// coverage, and builds the signed provenance manifest that rejects any
/// unmanifested face or run.
public final class Q1R4FontProvenance {

    public init() {}

    // MARK: - Hashing

    /// Hashes one font file and its OpenType tables, recording the variation
    /// axes and run coverage. The returned record is a pure function of the
    /// inputs — re-hashing the same bytes reproduces the identical record.
    ///
    /// - Parameters:
    ///   - familyName: The resolved font family (e.g. `"Menlo"`).
    ///   - postScriptName: The resolved PostScript name (e.g. `"Menlo-Regular"`).
    ///   - fileBytes: The raw font file bytes.
    ///   - tableBytes: OpenType table tag → that table's raw bytes.
    ///   - variationAxes: The face's variation axis envelope (default empty).
    ///   - runCoverage: The face's declared glyph/run/code-point coverage
    ///     envelope (default empty).
    public func hashFontFile(
        familyName: String,
        postScriptName: String,
        fileBytes: [UInt8],
        tableBytes: [String: [UInt8]],
        variationAxes: [FontVariationAxis] = [],
        runCoverage: FontRunCoverage = .empty
    ) -> FontRecord {
        let fileHash = Self.hexSHA256(fileBytes)
        var tableHashes: [String: String] = [:]
        for (tag, bytes) in tableBytes {
            tableHashes[tag] = Self.hexSHA256(bytes)
        }
        return FontRecord(
            familyName: familyName,
            postScriptName: postScriptName,
            fileHash: fileHash,
            tableHashes: tableHashes,
            variationAxes: variationAxes,
            runCoverage: runCoverage
        )
    }

    // MARK: - Manifest

    /// Builds the signed provenance manifest from the base and per-corpus
    /// records plus the pinned CDP protocol hash. The `manifestHash` is the
    /// hex SHA-256 of a canonical, order-independent serialization of all
    /// signed faces, so reordering base/corpus entries does not change it.
    public func buildManifest(
        base: [FontRecord],
        corpus: [FontRecord],
        cdpProtocolHash: String
    ) -> FontProvenanceManifest {
        let sortedBase = Self.sorted(base)
        let sortedCorpus = Self.sorted(corpus)
        let manifestHash = Self.hexSHA256(Array(
            Self.canonicalSerialization(base: sortedBase, corpus: sortedCorpus, cdpProtocolHash: cdpProtocolHash).utf8
        ))
        return FontProvenanceManifest(
            baseFonts: base,
            corpusFonts: corpus,
            cdpProtocolHash: cdpProtocolHash,
            manifestHash: manifestHash
        )
    }

    /// `true` iff `face` is registered in the manifest (matched by family +
    /// PostScript + file hash). An unmanifested face is rejected.
    public func allows(face: FontRecord, in manifest: FontProvenanceManifest) -> Bool {
        return Self.registered(face: face, in: manifest) != nil
    }

    /// `true` iff `face` is registered AND `coverage` fits within the face's
    /// declared run-coverage envelope. A run exceeding the declared glyph count,
    /// run count, or touching an unmanifested code point is rejected, as is any
    /// run on an unmanifested face.
    public func allowsRun(
        coverage: FontRunCoverage,
        forFace face: FontRecord,
        in manifest: FontProvenanceManifest
    ) -> Bool {
        guard let registered = Self.registered(face: face, in: manifest) else { return false }
        return registered.runCoverage.contains(coverage)
    }

    // MARK: - Internal

    /// Finds the registered record matching `face` by identity key, returning
    /// the registered record (which carries the declared coverage envelope).
    static func registered(
        face: FontRecord, in manifest: FontProvenanceManifest
    ) -> FontRecord? {
        let key = face.identityKey
        for r in manifest.baseFonts where r.identityKey == key { return r }
        for r in manifest.corpusFonts where r.identityKey == key { return r }
        return nil
    }

    /// Sorts records by identity key so the manifest hash is order-independent.
    static func sorted(_ records: [FontRecord]) -> [FontRecord] {
        return records.sorted { $0.identityKey < $1.identityKey }
    }

    /// Canonical, order-independent serialization of the signed manifest
    /// content. Each face is serialized as
    /// `family \0 postScript \0 fileHash \0 tables \0 axes \0 coverage \0`,
    /// where tables, axes, and code points are themselves sorted, so identical
    /// signed content always produces identical bytes regardless of input order.
    static func canonicalSerialization(
        base: [FontRecord],
        corpus: [FontRecord],
        cdpProtocolHash: String
    ) -> String {
        var out = ""
        out += "base:"
        for r in base { out += Self.recordLine(r) }
        out += "corpus:"
        for r in corpus { out += Self.recordLine(r) }
        out += "cdp:" + cdpProtocolHash
        return out
    }

    private static func recordLine(_ r: FontRecord) -> String {
        let tables = r.tableHashes.keys.sorted()
        var tablePart = ""
        for t in tables {
            tablePart += t + "=" + (r.tableHashes[t] ?? "") + ";"
        }
        let axes = r.variationAxes.sorted { $0.tag < $1.tag }
        var axisPart = ""
        for a in axes {
            axisPart += a.tag + ","
                + Self.fmt(a.minimum) + "," + Self.fmt(a.maximum) + ","
                + Self.fmt(a.defaultValue) + ";"
        }
        let points = r.runCoverage.coveredCodePoints.sorted()
        var pointPart = ""
        for p in points { pointPart += String(p) + "," }
        return r.familyName + "\u{0}" + r.postScriptName + "\u{0}" + r.fileHash
            + "\u{0}" + tablePart + "\u{0}" + axisPart + "\u{0}"
            + "\(r.runCoverage.glyphCount)" + "\u{0}"
            + "\(r.runCoverage.runCount)" + "\u{0}" + pointPart + "\u{0}"
    }

    private static func fmt(_ d: Double) -> String {
        // Canonical double formatting: round-trippable, locale-independent.
        return String(d)
    }

    /// Hex SHA-256 of bytes via the pure-Swift SHA256 in this target.
    static func hexSHA256(_ bytes: [UInt8]) -> String {
        return SHA256.hash(bytes).map { String(format: "%02x", $0) }.joined()
    }
}
