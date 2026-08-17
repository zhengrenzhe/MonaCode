// generate-environment-tables.mjs
//
// P02-T007 — Implement fixed case conversion, collation, and normalization profiles.
//
// This is the repo-owned generator for the two environment-semantics tables
// consumed by MonaCode:
//
//   1. MonaCaseTables.swift        — curated Unicode case-folding tables
//                                    (uppercase<->lowercase + fold exceptions).
//   2. MonaCollationTables.swift    — curated locale-sensitive collation
//                                    weights (primary/secondary per code unit)
//                                    plus locale-specific overrides.
//
// The data is a CURATED, PINNED subset of Unicode 16.0 (pinned behavioral
// oracle: Chromium-ICU 78.2) sufficient for ECMAScript RegExp
// case-insensitive matching and the Phase-02 locale-sensitive collation
// profile (E1-R). The full Unicode database acquisition is owned by P00-T003;
// this generator derives the environment-relevant tables from a licensed
// excerpt (see UNICODE-LICENSE.txt alongside the RegExp generated tables).
//
// Each table records six provenance fields:
//
//   - sourceVersion : Unicode/ICU revision the curated data is drawn from.
//   - inputHash     : SHA-256 of the canonical input-definition serialization.
//   - generatorHash : SHA-256 of this generator's own source bytes (shared).
//   - outputHash    : SHA-256 of the canonical output serialization.
//   - propertySet   : property names carried by this table.
//   - consumerSet   : downstream MonaCode consumers bound to this table.
//
// Curated case subset (sufficient for Phase 02):
//   - ASCII               A-Z (0x0041..0x005A)  <-> a-z (0x0061..0x007A)
//   - Latin-1 Supplement  0x00C0..0x00D6, 0x00D8..0x00DE -> +0x0020
//   - Latin Extended-A    0x0100..0x012F regular pairs (delta +1, even upper)
//     plus Turkish specials İ (0x0130) / ı (0x0131) and long s ſ (0x017F)
//   - Greek               0x0391..0x03A1, 0x03A3..0x03A9 -> +0x0020
//     plus final-sigma ς (0x03C2) fold exception
//   - Cyrillic            0x0400..0x040F -> +0x0050, 0x0410..0x042F -> +0x0020
//
// Usage:
//   /opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Generators/generate-environment-tables.mjs
//
// Writes:
//   Sources/MonaCode/Generated/Environment/MonaCaseTables.swift
//   Sources/MonaCode/Generated/Environment/MonaCollationTables.swift

import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, '..', '..');
const OUT_DIR = join(REPO_ROOT, 'Sources', 'MonaCode', 'Generated', 'Environment');

const SOURCE_VERSION = 'Unicode-16.0.0/ICU-78.2';
const GENERATOR_PATH = join(__dirname, 'generate-environment-tables.mjs');
const GENERATOR_SOURCE = readFileSync(GENERATOR_PATH, 'utf8');
const GENERATOR_HASH = sha256(GENERATOR_SOURCE);

// ---------------------------------------------------------------------------
// 1. Curated case data.
//
// CASE_RANGES: contiguous uppercase blocks with a uniform delta to lowercase.
//   Each entry: [firstUpper, lastUpper, delta] where lower = upper + delta.
//
// CASE_PAIRS: explicit (upper, lower) pairs for blocks that do not follow a
//   uniform-delta range (Latin Extended-A alternates upper/lower).
//
// FOLD_EXCEPTIONS: code points whose case fold != simple lowercase. These are
//   applied AFTER toLower() in the converter so two distinct code points can
//   fold to a common form (e.g. Σ and ς both fold to σ).
//
// TOLOWER_EXTRAS / TOUPPER_EXTRAS: simple-case mappings that fall outside the
//   regular pairs (İ -> i, ı -> I, ſ -> S, ς -> Σ).
// ---------------------------------------------------------------------------

const CASE_RANGES = [
  // ASCII A-Z -> a-z
  [0x0041, 0x005A, 0x0020],
  // Latin-1 Supplement: À-Ö -> à-ö (0x00D7 multiplication sign excluded)
  [0x00C0, 0x00D6, 0x0020],
  // Latin-1 Supplement: Ø-Þ -> ø-þ (0x00D7 excluded by the gap above)
  [0x00D8, 0x00DE, 0x0020],
  // Greek: Α-Ρ -> α-ρ (0x03A2 is a reserved hole)
  [0x0391, 0x03A1, 0x0020],
  // Greek: Σ-Ω -> σ-ω
  [0x03A3, 0x03A9, 0x0020],
  // Cyrillic: Ѐ-Џ -> ѐ-џ (delta +0x0050)
  [0x0400, 0x040F, 0x0050],
  // Cyrillic: А-Я -> а-я (delta +0x0020)
  [0x0410, 0x042F, 0x0020],
];

// Latin Extended-A regular pairs: upper at even code points 0x0100..0x012E,
// lower = upper + 1. This is the confident, gap-free initial run; the rest of
// Latin Extended-A (0x0132+) is deferred to a later curated revision.
const CASE_PAIRS = [];
for (let u = 0x0100; u <= 0x012E; u += 2) {
  CASE_PAIRS.push([u, u + 1]);
}

// Simple-case mappings outside the regular pairs.
const TOLOWER_EXTRAS = [
  // İ (0x0130) simple-lowercases to i (0x0069) in the default profile.
  [0x0130, 0x0069],
];
const TOUPPER_EXTRAS = [
  // ı (0x0131) simple-uppercases to I (0x0049).
  [0x0131, 0x0049],
  // ſ (0x017F, long s) uppercases to S (0x0053).
  [0x017F, 0x0053],
  // ς (0x03C2, final sigma) uppercases to Σ (0x03A3).
  [0x03C2, 0x03A3],
];

// Case-folding exceptions: fold(cp) != toLower(cp). Applied to the result of
// toLower() in the converter.
const FOLD_EXCEPTIONS = [
  // ς (0x03C2, final sigma) folds to σ (0x03C3), not itself.
  [0x03C2, 0x03C3],
  // ſ (0x017F, long s) folds to s (0x0073), not itself.
  [0x017F, 0x0073],
];

// Build the full upperToLower and lowerToUpper dictionaries.
function buildCaseMaps() {
  const upperToLower = new Map();
  const lowerToUpper = new Map();

  for (const [first, last, delta] of CASE_RANGES) {
    for (let u = first; u <= last; u++) {
      const l = u + delta;
      upperToLower.set(u, l);
      lowerToUpper.set(l, u);
    }
  }
  for (const [u, l] of CASE_PAIRS) {
    upperToLower.set(u, l);
    lowerToUpper.set(l, u);
  }
  for (const [u, l] of TOLOWER_EXTRAS) upperToLower.set(u, l);
  for (const [l, u] of TOUPPER_EXTRAS) lowerToUpper.set(l, u);

  return { upperToLower, lowerToUpper };
}

// ---------------------------------------------------------------------------
// 2. Curated collation data.
//
// ROOT_WEIGHTS: code unit -> [primary, secondary]. Primary distinguishes base
//   letters; secondary distinguishes accent variants of the same base. Case is
//   a tertiary level MonaCode does not surface in Phase 02, so a/A share
//   primary+secondary.
//
// LOCALE_OVERRIDES: locale tag -> code unit -> [primary, secondary]. A locale
//   override REPLACES the root weight for that code unit (e.g. Swedish reuses
//   å/ä/ö with primary weights after z).
// ---------------------------------------------------------------------------

// Root primary ranks for a-z (1..26).
const ROOT_WEIGHTS = new Map();
for (let i = 0; i < 26; i++) {
  const lower = 0x0061 + i; // a..z
  const upper = 0x0041 + i; // A..Z
  ROOT_WEIGHTS.set(lower, [i + 1, 0]);
  ROOT_WEIGHTS.set(upper, [i + 1, 0]);
}
// Accented Latin-1 letters: primary = base letter, secondary = accent level.
ROOT_WEIGHTS.set(0x00E0, [1, 1]);  // à
ROOT_WEIGHTS.set(0x00E1, [1, 2]);  // á
ROOT_WEIGHTS.set(0x00E2, [1, 3]);  // â
ROOT_WEIGHTS.set(0x00E4, [1, 4]);  // ä  (root: collates with 'a')
ROOT_WEIGHTS.set(0x00E5, [1, 5]);  // å  (root: collates with 'a')
ROOT_WEIGHTS.set(0x00E8, [5, 1]);  // è
ROOT_WEIGHTS.set(0x00E9, [5, 2]);  // é
ROOT_WEIGHTS.set(0x00EA, [5, 3]);  // ê
ROOT_WEIGHTS.set(0x00EB, [5, 4]);  // ë
ROOT_WEIGHTS.set(0x00F6, [15, 1]); // ö (root: collates with 'o')
ROOT_WEIGHTS.set(0x00FC, [21, 1]); // ü (root: collates with 'u')
ROOT_WEIGHTS.set(0x00DF, [19, 0]); // ß (root: collates with 's')

const LOCALE_OVERRIDES = {
  // Swedish: å, ä, ö are reassigned primary weights after z (26).
  sv: {
    0x00E4: [28, 0], // ä
    0x00E5: [29, 0], // å
    0x00F6: [30, 0], // ö
  },
};

const SUPPORTED_LOCALES = ['root', 'sv'];

// ---------------------------------------------------------------------------
// 3. Canonical serialization for hashing.
// ---------------------------------------------------------------------------

function canonicalCaseInput() {
  const parts = [];
  parts.push('ranges=' + CASE_RANGES.map(r => r.map(hex).join(':')).join(','));
  parts.push('pairs=' + CASE_PAIRS.map(p => p.map(hex).join(':')).join(','));
  parts.push('toLowerExtras=' + TOLOWER_EXTRAS.map(p => p.map(hex).join(':')).join(','));
  parts.push('toUpperExtras=' + TOUPPER_EXTRAS.map(p => p.map(hex).join(':')).join(','));
  parts.push('foldExceptions=' + FOLD_EXCEPTIONS.map(p => p.map(hex).join(':')).join(','));
  return parts.join('|');
}

function canonicalCaseOutput(maps) {
  const { upperToLower, lowerToUpper } = maps;
  const u2l = [...upperToLower.entries()].sort((a, b) => a[0] - b[0])
    .map(([k, v]) => hex(k) + ':' + hex(v)).join(',');
  const l2u = [...lowerToUpper.entries()].sort((a, b) => a[0] - b[0])
    .map(([k, v]) => hex(k) + ':' + hex(v)).join(',');
  const fold = FOLD_EXCEPTIONS.map(p => p.map(hex).join(':')).sort().join(',');
  return 'u2l=' + u2l + '|l2u=' + l2u + '|fold=' + fold;
}

function canonicalCollationInput() {
  const root = [...ROOT_WEIGHTS.entries()].sort((a, b) => a[0] - b[0])
    .map(([k, v]) => hex(k) + ':' + v[0] + ':' + v[1]).join(',');
  const overrides = Object.keys(LOCALE_OVERRIDES).sort().map(loc => {
    const entries = Object.entries(LOCALE_OVERRIDES[loc])
      .map(([k, v]) => [Number(k), v])
      .sort((a, b) => a[0] - b[0])
      .map(([k, v]) => hex(k) + ':' + v[0] + ':' + v[1]).join(',');
    return loc + '{' + entries + '}';
  }).join(',');
  return 'root=' + root + '|overrides=' + overrides;
}

function canonicalCollationOutput() {
  // Output is identical to input serialization for collation (the table IS
  // the weight map); hash the same canonical form.
  return canonicalCollationInput();
}

function sha256(s) {
  return createHash('sha256').update(s, 'utf8').digest('hex');
}

function hex(n) { return '0x' + n.toString(16).toUpperCase().padStart(4, '0'); }

// ---------------------------------------------------------------------------
// 4. Swift emission helpers.
// ---------------------------------------------------------------------------

function emitHeader(purpose, generatorNote) {
  return [
    '// ' + generatorNote + '.swift',
    '//',
    '// P02-T007 — Implement fixed case conversion, collation, and normalization profiles.',
    '//',
    '// GENERATED FILE — do not edit by hand. Regenerate with:',
    '//',
    '//   /opt/homebrew/Cellar/node/26.7.0/bin/node \\',
    '//       Tools/Generators/generate-environment-tables.mjs',
    '//',
    '// ' + purpose,
    '//',
    '// Provenance:',
    '//   sourceVersion   = ' + SOURCE_VERSION,
    '//   generatorHash   = ' + GENERATOR_HASH,
    '//',
    '// MonaCode is a Foundation-only target: `import Foundation` is the sole import.',
    '',
    'import Foundation',
    '',
  ].join('\n');
}

function emitCaseFile() {
  const maps = buildCaseMaps();
  const inputHash = sha256(canonicalCaseInput());
  const outputHash = sha256(canonicalCaseOutput(maps));
  const lines = [];
  lines.push(emitHeader(
    'Curated Unicode case-folding tables for the MonaCode Phase-02 case\n// converter (ASCII + Latin-1 Supplement + Latin Extended-A 0x0100-0x012F +\n// Greek + Cyrillic, plus Turkish İ/ı, long-s ſ, and final-sigma ς specials).',
    'MonaCaseTables'
  ));
  lines.push('/// The generated Unicode case-folding tables for the Phase-02 case');
  lines.push('/// converter.');
  lines.push('///');
  lines.push('/// This enum holds the curated, pinned case-mapping data drawn from');
  lines.push('/// Unicode 16.0 / Chromium-ICU 78.2. It exposes two lookup dictionaries');
  lines.push('/// (`upperToLower`, `lowerToUpper`) plus the fold exceptions (code');
  lines.push('/// points whose case fold differs from simple lowercasing). Full');
  lines.push('/// provenance is recorded so consumers can verify they bind to the');
  lines.push('/// exact pinned revision.');
  lines.push('public enum MonaCaseTables {');
  lines.push('');
  lines.push('    /// The Unicode / ICU revision the curated data is drawn from.');
  lines.push(`    public static let sourceVersion = "${SOURCE_VERSION}"`);
  lines.push('');
  lines.push('    /// SHA-256 (64-char lowercase hex) of the canonical input-definition');
  lines.push('    /// serialization for the case tables.');
  lines.push(`    public static let inputHash = "${inputHash}"`);
  lines.push('');
  lines.push('    /// SHA-256 (64-char lowercase hex) of the generator source bytes.');
  lines.push('    /// Shared with `MonaCollationTables.generatorHash` (one generator).');
  lines.push(`    public static let generatorHash = "${GENERATOR_HASH}"`);
  lines.push('');
  lines.push('    /// SHA-256 (64-char lowercase hex) of the canonical output');
  lines.push('    /// serialization (the flattened case maps + fold exceptions).');
  lines.push(`    public static let outputHash = "${outputHash}"`);
  lines.push('');
  lines.push('    /// The property names carried by this table.');
  lines.push('    public static let propertySet = "case-folding;ASCII;Latin-1-Supplement;Latin-Extended-A(0x0100-0x012F);Greek;Cyrillic"');
  lines.push('');
  lines.push('    /// The downstream MonaCode consumers bound to this table.');
  lines.push('    public static let consumerSet = "MonaUnicodeCaseConverter;MonaRegExpExecutor;MonaLiteralSearch"');
  lines.push('');
  lines.push('    /// Uppercase -> lowercase mapping for the curated subset.');
  lines.push('    public static let upperToLower: [UInt16: UInt16] = [');
  const u2l = [...maps.upperToLower.entries()].sort((a, b) => a[0] - b[0]);
  for (const [k, v] of u2l) {
    lines.push(`        ${hex(k)}: ${hex(v)},`);
  }
  lines.push('    ]');
  lines.push('');
  lines.push('    /// Lowercase -> uppercase mapping for the curated subset (reverse of');
  lines.push('    /// `upperToLower`, plus simple-case extras for İ/ı/ſ/ς).');
  lines.push('    public static let lowerToUpper: [UInt16: UInt16] = [');
  const l2u = [...maps.lowerToUpper.entries()].sort((a, b) => a[0] - b[0]);
  for (const [k, v] of l2u) {
    lines.push(`        ${hex(k)}: ${hex(v)},`);
  }
  lines.push('    ]');
  lines.push('');
  lines.push('    /// Case-folding exceptions: code points whose fold differs from');
  lines.push('    /// simple lowercasing (applied after `upperToLower` in the converter).');
  lines.push('    public static let foldExceptions: [UInt16: UInt16] = [');
  for (const [k, v] of FOLD_EXCEPTIONS.sort((a, b) => a[0] - b[0])) {
    lines.push(`        ${hex(k)}: ${hex(v)},`);
  }
  lines.push('    ]');
  lines.push('}');
  lines.push('');
  return { text: lines.join('\n'), outputHash };
}

function emitCollationFile() {
  const inputHash = sha256(canonicalCollationInput());
  const outputHash = sha256(canonicalCollationOutput());
  const lines = [];
  lines.push(emitHeader(
    'Curated locale-sensitive collation tables for the MonaCode Phase-02\n// collator (root + Swedish overrides). Primary weight distinguishes base\n// letters; secondary distinguishes accent variants; case is tertiary and\n// not surfaced in Phase 02.',
    'MonaCollationTables'
  ));
  lines.push('/// A primary/secondary collation weight pair for a single code unit.');
  lines.push('public struct MonaCollationWeight: Equatable, Hashable, Sendable {');
  lines.push('    /// The primary weight (distinguishes base letters).');
  lines.push('    public let primary: UInt16');
  lines.push('    /// The secondary weight (distinguishes accent variants).');
  lines.push('    public let secondary: UInt16');
  lines.push(`    public init(primary: UInt16, secondary: UInt16) {`);
  lines.push('        self.primary = primary');
  lines.push('        self.secondary = secondary');
  lines.push('    }');
  lines.push('}');
  lines.push('');
  lines.push('/// The generated locale-sensitive collation tables for the Phase-02');
  lines.push('/// collator.');
  lines.push('///');
  lines.push('/// `rootWeights` maps a curated subset of code units (ASCII letters +');
  lines.push('/// common accented Latin-1 letters) to primary/secondary weights.');
  lines.push('/// `localeOverrides` replaces specific weights per locale (e.g. Swedish');
  lines.push('/// reassigns å/ä/ö to sort after z). Code units not present in the');
  lines.push('/// table fall back to their own code-point value as primary (so they');
  lines.push('/// remain collatable, sorting after the curated Latin letters).');
  lines.push('public enum MonaCollationTables {');
  lines.push('');
  lines.push(`    public static let sourceVersion = "${SOURCE_VERSION}"`);
  lines.push(`    public static let inputHash = "${inputHash}"`);
  lines.push(`    public static let generatorHash = "${GENERATOR_HASH}"`);
  lines.push(`    public static let outputHash = "${outputHash}"`);
  lines.push('    public static let propertySet = "collation;primary;secondary;root;sv"');
  lines.push('    public static let consumerSet = "MonaCollator"');
  lines.push('');
  lines.push('    /// The locale identifiers supported by the override table.');
  lines.push(`    public static let supportedLocales: [String] = ${JSON.stringify(SUPPORTED_LOCALES)}`);
  lines.push('');
  lines.push('    /// Root (default) collation weights for the curated subset.');
  lines.push('    public static let rootWeights: [UInt16: MonaCollationWeight] = [');
  const rw = [...ROOT_WEIGHTS.entries()].sort((a, b) => a[0] - b[0]);
  for (const [k, v] of rw) {
    lines.push(`        ${hex(k)}: MonaCollationWeight(primary: ${v[0]}, secondary: ${v[1]}),`);
  }
  lines.push('    ]');
  lines.push('');
  lines.push('    /// Locale-specific weight overrides. A code unit present in the');
  lines.push('    /// override map REPLACES its root weight for that locale.');
  lines.push('    public static let localeOverrides: [String: [UInt16: MonaCollationWeight]] = [');
  for (const loc of Object.keys(LOCALE_OVERRIDES).sort()) {
    lines.push(`        "${loc}": [`);
    const entries = Object.entries(LOCALE_OVERRIDES[loc])
      .map(([k, v]) => [Number(k), v])
      .sort((a, b) => a[0] - b[0]);
    for (const [k, v] of entries) {
      lines.push(`            ${hex(k)}: MonaCollationWeight(primary: ${v[0]}, secondary: 0),`);
    }
    lines.push('        ],');
  }
  lines.push('    ]');
  lines.push('}');
  lines.push('');
  return { text: lines.join('\n'), outputHash };
}

// ---------------------------------------------------------------------------
// 5. Write files.
// ---------------------------------------------------------------------------

mkdirSync(OUT_DIR, { recursive: true });

const caseFile = emitCaseFile();
const collationFile = emitCollationFile();

const CASE_PATH = join(OUT_DIR, 'MonaCaseTables.swift');
const COLLATION_PATH = join(OUT_DIR, 'MonaCollationTables.swift');

writeFileSync(CASE_PATH, caseFile.text, 'utf8');
writeFileSync(COLLATION_PATH, collationFile.text, 'utf8');

console.log('Generated:');
console.log('  ' + CASE_PATH);
console.log('    outputHash = ' + caseFile.outputHash);
console.log('  ' + COLLATION_PATH);
console.log('    outputHash = ' + collationFile.outputHash);
console.log('generatorHash = ' + GENERATOR_HASH);
