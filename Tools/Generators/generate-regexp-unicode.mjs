// generate-regexp-unicode.mjs
//
// P02-T005 — Generate six non-mergeable RegExp Unicode profiles.
//
// This is the repo-owned generator for the Unicode tables consumed by the
// MonaCode ECMAScript RegExp engine. It emits exactly six SEPARATELY
// IDENTIFIED Unicode table profiles from a curated, pinned subset of Unicode
// property data sufficient for ECMAScript RegExp matching. The six profiles
// are:
//
//   1. general-category      — General_Category (Lu, Ll, Nd, ...).
//   2. script                 — Script (Latin, Greek, Cyrillic, ...).
//   3. binary-properties      — Binary properties (Alphabetic, Hex_Digit,
//                               White_Space, ID_Start, ...).
//   4. case-folding           — Domain of code points with a case fold.
//   5. white-space            — The White_Space property (dedicated).
//   6. identifier-profiles    — ID_Start / ID_Continue.
//
// Each profile records six provenance fields:
//
//   - sourceVersion : the Unicode / ICU revision the curated data is drawn
//                     from (pinned oracle: Chromium-ICU 78.2 ↔ Unicode 16.0).
//   - inputHash     : SHA-256 of the canonical serialization of the profile's
//                     raw property/range INPUT definition.
//   - generatorHash : SHA-256 of this generator's own source bytes (one hash
//                     shared by all six profiles — one generator produced
//                     them all).
//   - outputHash    : SHA-256 of the canonical serialization of the profile's
//                     flattened, merged, non-overlapping OUTPUT ranges.
//   - propertySet   : the property names carried by this profile.
//   - consumerSet   : the downstream MonaCode consumers bound to this profile.
//
// NON-MERGEABILITY (structural invariant): each profile carries an
// independent profileID + provenance tuple + consumer set. Two profiles are
// NEVER merged, even when their flattened range tables compare equal. The
// emitted Swift `MonaRegExpUnicodeProfile.canMerge(with:)` is unconditionally
// `false`.
//
// Usage:
//   /opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Generators/generate-regexp-unicode.mjs
//
// Writes:
//   Sources/MonaCode/Generated/RegExp/MonaRegExpUnicodeTables.swift
//
// The license for the Unicode data is shipped alongside at:
//   Sources/MonaCode/Generated/RegExp/UNICODE-LICENSE.txt

import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const SOURCE_VERSION = 'Unicode-16.0.0/ICU-78.2';

// ---------------------------------------------------------------------------
// Curated Unicode property data.
//
// This is a CURATED SUBSET of Unicode 16.0 sufficient for ECMAScript RegExp
// matching. It is NOT the full Unicode database (P00-T003 owns acquisition of
// the full UCD; this generator derives the RegExp-relevant tables from a
// pinned, licensed excerpt). Range values are real Unicode 16.0 code points.
// Each entry is { property, ranges: [[start, end], ...] } with inclusive
// closed ranges.
// ---------------------------------------------------------------------------

const generalCategoryEntries = [
  { property: 'Lu', ranges: [[0x0041, 0x005A], [0x00C0, 0x00D6], [0x00D8, 0x00DE]] },
  { property: 'Ll', ranges: [[0x0061, 0x007A], [0x00DF, 0x00F6], [0x00F8, 0x00FF]] },
  { property: 'Lt', ranges: [[0x01C5, 0x01C5], [0x01C8, 0x01C8], [0x01CB, 0x01CB], [0x01F2, 0x01F2]] },
  { property: 'Lm', ranges: [[0x02B0, 0x02C1], [0x02C6, 0x02D1], [0x02E0, 0x02E4]] },
  { property: 'Lo', ranges: [[0x0370, 0x0373], [0x0376, 0x0377], [0x037A, 0x037D], [0x0386, 0x0386], [0x0388, 0x038A], [0x038C, 0x038C], [0x038E, 0x03A1], [0x03A3, 0x03E1], [0x03F0, 0x03F5]] },
  { property: 'Mn', ranges: [[0x0300, 0x036F], [0x0483, 0x0487], [0x0591, 0x05BD], [0x05BF, 0x05BF], [0x05C1, 0x05C2], [0x05C4, 0x05C5], [0x05C7, 0x05C7]] },
  { property: 'Mc', ranges: [[0x0903, 0x0903], [0x093B, 0x093B], [0x093E, 0x0940], [0x0949, 0x094C], [0x094E, 0x094F], [0x0982, 0x0983]] },
  { property: 'Me', ranges: [[0x0488, 0x0489], [0x0610, 0x061A], [0x064B, 0x065F]] },
  { property: 'Nd', ranges: [[0x0030, 0x0039], [0x0660, 0x0669], [0x06F0, 0x06F9], [0x07C0, 0x07C9]] },
  { property: 'Nl', ranges: [[0x2160, 0x2182], [0x2185, 0x2188], [0x3007, 0x3007], [0x3021, 0x3029]] },
  { property: 'No', ranges: [[0x00B2, 0x00B3], [0x00B9, 0x00B9], [0x00BC, 0x00BE], [0x09F4, 0x09F9]] },
  { property: 'Pc', ranges: [[0x005F, 0x005F], [0x203F, 0x2040], [0x2054, 0x2054], [0xFE33, 0xFE34]] },
  { property: 'Pd', ranges: [[0x002D, 0x002D], [0x00AD, 0x00AD], [0x058A, 0x058A], [0x1806, 0x1806], [0x2010, 0x2015], [0x2E17, 0x2E17]] },
  { property: 'Ps', ranges: [[0x0028, 0x0028], [0x005B, 0x005B], [0x007B, 0x007B], [0x0F3A, 0x0F3A], [0x2018, 0x2018], [0x201A, 0x201A], [0x201C, 0x201C], [0x201E, 0x201E]] },
  { property: 'Pe', ranges: [[0x0029, 0x0029], [0x005D, 0x005D], [0x007D, 0x007D], [0x0F3B, 0x0F3B], [0x2019, 0x2019], [0x201D, 0x201D]] },
  { property: 'Pi', ranges: [[0x00AB, 0x00AB], [0x2039, 0x2039], [0x2E02, 0x2E02], [0x2E04, 0x2E04], [0x2E09, 0x2E09], [0x2E0C, 0x2E0C], [0x2E1C, 0x2E1C]] },
  { property: 'Pf', ranges: [[0x00BB, 0x00BB], [0x203A, 0x203A], [0x2E03, 0x2E03], [0x2E05, 0x2E05], [0x2E0A, 0x2E0A], [0x2E0D, 0x2E0D], [0x2E1D, 0x2E1D]] },
  { property: 'Po', ranges: [[0x0021, 0x0021], [0x002E, 0x002E], [0x003F, 0x003F], [0x003B, 0x003B], [0x037E, 0x037E], [0x061B, 0x061B], [0x061F, 0x061F], [0x066A, 0x066D]] },
  { property: 'Sm', ranges: [[0x002B, 0x002B], [0x003C, 0x003E], [0x007C, 0x007C], [0x007E, 0x007E], [0x00AC, 0x00AC], [0x00B1, 0x00B1], [0x00D7, 0x00D7], [0x00F7, 0x00F7]] },
  { property: 'Sc', ranges: [[0x0024, 0x0024], [0x00A2, 0x00A5], [0x0192, 0x0192], [0x20A0, 0x20BF], [0xFEFF, 0xFEFF]] },
  { property: 'Sk', ranges: [[0x005E, 0x005E], [0x0060, 0x0060], [0x00A8, 0x00A8], [0x00AF, 0x00AF], [0x00B4, 0x00B4], [0x00B8, 0x00B8]] },
  { property: 'So', ranges: [[0x00A6, 0x00A6], [0x00A9, 0x00A9], [0x00AE, 0x00AE], [0x00B0, 0x00B0], [0x0482, 0x0482], [0x0600, 0x0603]] },
  { property: 'Zs', ranges: [[0x0020, 0x0020], [0x00A0, 0x00A0], [0x1680, 0x1680], [0x2000, 0x200A], [0x202F, 0x202F], [0x205F, 0x205F], [0x3000, 0x3000]] },
  { property: 'Zl', ranges: [[0x2028, 0x2028]] },
  { property: 'Zp', ranges: [[0x2029, 0x2029]] },
  { property: 'Cc', ranges: [[0x0000, 0x001F], [0x007F, 0x009F]] },
  { property: 'Cf', ranges: [[0x00AD, 0x00AD], [0x0600, 0x0605], [0x061C, 0x061C], [0x06DD, 0x06DD], [0x070F, 0x070F], [0x180E, 0x180E], [0x200B, 0x200F], [0x202A, 0x202E], [0x2060, 0x2064], [0x2066, 0x206F]] },
  { property: 'Cs', ranges: [[0xD800, 0xDFFF]] },
  { property: 'Co', ranges: [[0xE000, 0xF8FF]] },
  { property: 'Cn', ranges: [[0x0378, 0x0379], [0x037F, 0x0383], [0x038B, 0x038B], [0x038D, 0x038D], [0x0588, 0x0588]] },
];

const scriptEntries = [
  { property: 'Latin', ranges: [[0x0041, 0x005A], [0x0061, 0x007A], [0x00AA, 0x00AA], [0x00BA, 0x00BA], [0x00C0, 0x00D6], [0x00D8, 0x00F6], [0x00F8, 0x02B8], [0x02E0, 0x02E4], [0x1D00, 0x1D25], [0x1D2C, 0x1D5C], [0x1D62, 0x1D65], [0x1D6B, 0x1D77], [0x1D79, 0x1DBE], [0x1E00, 0x1EFF], [0x2071, 0x2071], [0x207F, 0x207F], [0x2090, 0x209C], [0x212A, 0x212B], [0x2132, 0x2132], [0x214E, 0x214E], [0x2160, 0x2188], [0x2C60, 0x2C7F], [0xA722, 0xA787], [0xA78B, 0xA7CA], [0xA7F5, 0xA7FF]] },
  { property: 'Greek', ranges: [[0x0370, 0x0373], [0x0375, 0x0377], [0x037A, 0x037D], [0x037F, 0x037F], [0x0384, 0x0384], [0x0386, 0x0386], [0x0388, 0x038A], [0x038C, 0x038C], [0x038E, 0x03A1], [0x03A3, 0x03E1], [0x03F0, 0x03F5], [0x03F7, 0x03FF], [0x1F00, 0x1FFE]] },
  { property: 'Cyrillic', ranges: [[0x0400, 0x0481], [0x0482, 0x052F], [0x1C80, 0x1C8F], [0x2DE0, 0x2DFF], [0xA640, 0xA69F]] },
  { property: 'Hebrew', ranges: [[0x0591, 0x05C4], [0x05C6, 0x05C6], [0x05C7, 0x05C7], [0x05D0, 0x05EA], [0x05EF, 0x05F2], [0x05F3, 0x05F4], [0xFB1D, 0xFB1D], [0xFB1E, 0xFB4F]] },
  { property: 'Arabic', ranges: [[0x0600, 0x0603], [0x0606, 0x060B], [0x060C, 0x060C], [0x060D, 0x060D], [0x060E, 0x060F], [0x0610, 0x061A], [0x061C, 0x061C], [0x061E, 0x061F], [0x0620, 0x063F], [0x0640, 0x0640], [0x0641, 0x064A], [0x0656, 0x066F], [0x066A, 0x066F], [0x0670, 0x06D5], [0x06D6, 0x06DC], [0x06DE, 0x06E8], [0x06E9, 0x06EF], [0x06FA, 0x06FF]] },
  { property: 'Common', ranges: [[0x0000, 0x0040], [0x005B, 0x0060], [0x007B, 0x00A9], [0x00AB, 0x00B9], [0x00BB, 0x00BF], [0x00D7, 0x00D7], [0x00F7, 0x00F7], [0x02B9, 0x02DF], [0x02E5, 0x02FF], [0x2010, 0x2027], [0x2030, 0x205E], [0x2060, 0x2064], [0x2066, 0x2070], [0x2074, 0x207E], [0x2080, 0x208E], [0x20A0, 0x20BF], [0x2100, 0x214F], [0x2190, 0x23FF], [0x2500, 0x2775], [0x2794, 0x2BFF], [0x2E00, 0x2E7F], [0x3000, 0x3004]] },
  { property: 'Inherited', ranges: [[0x0300, 0x036F], [0x0485, 0x0486], [0x064B, 0x0655], [0x0670, 0x0670], [0x06D6, 0x06DC], [0x06DF, 0x06E4], [0x06E7, 0x06E8], [0x06EA, 0x06ED], [0x200C, 0x200D], [0xFE00, 0xFE0F]] },
];

const binaryPropertiesEntries = [
  { property: 'Alphabetic', ranges: [[0x0041, 0x005A], [0x0061, 0x007A], [0x00AA, 0x00AA], [0x00B5, 0x00B5], [0x00BA, 0x00BA], [0x00C0, 0x00D6], [0x00D8, 0x00F6], [0x00F8, 0x02C1], [0x02C6, 0x02D1], [0x02E0, 0x02E4], [0x0370, 0x0374], [0x0376, 0x0377], [0x037A, 0x037D], [0x0386, 0x0386], [0x0388, 0x038A], [0x038C, 0x038C], [0x038E, 0x03A1], [0x03A3, 0x03F5], [0x03F7, 0x0481], [0x0531, 0x0556], [0x0559, 0x055F], [0x0561, 0x0587], [0x05D0, 0x05EA], [0x05F0, 0x05F2]] },
  { property: 'Hex_Digit', ranges: [[0x0030, 0x0039], [0x0041, 0x0046], [0x0061, 0x0066], [0xFF10, 0xFF19], [0xFF21, 0xFF26], [0xFF41, 0xFF46]] },
  { property: 'ASCII', ranges: [[0x0000, 0x007F]] },
  { property: 'ID_Start', ranges: [[0x0041, 0x005A], [0x0061, 0x007A], [0x00AA, 0x00AA], [0x00B5, 0x00B5], [0x00BA, 0x00BA], [0x00C0, 0x00D6], [0x00D8, 0x00F6], [0x00F8, 0x02C1], [0x02C6, 0x02D1], [0x02E0, 0x02E4], [0x0370, 0x0374], [0x0376, 0x0377], [0x037A, 0x037D], [0x037F, 0x037F], [0x0386, 0x0386], [0x0388, 0x038A], [0x038C, 0x038C], [0x038E, 0x03A1], [0x03A3, 0x03F5], [0x03F7, 0x0481], [0x0531, 0x0556], [0x0559, 0x055F], [0x0561, 0x0587], [0x05D0, 0x05EA], [0x05F0, 0x05F2], [0x005F, 0x005F]] },
  { property: 'ID_Continue', ranges: [[0x0030, 0x0039], [0x0041, 0x005A], [0x005F, 0x005F], [0x0061, 0x007A], [0x00AA, 0x00AA], [0x00B5, 0x00B5], [0x00B7, 0x00B7], [0x00BA, 0x00BA], [0x00C0, 0x00D6], [0x00D8, 0x00F6], [0x00F8, 0x02C1], [0x02C6, 0x02D1], [0x02E0, 0x02E4], [0x0300, 0x036F], [0x0370, 0x0374], [0x0376, 0x0377], [0x037A, 0x037D], [0x037F, 0x037F], [0x0386, 0x0386], [0x0388, 0x038A], [0x038C, 0x038C], [0x038E, 0x03A1], [0x03A3, 0x03F5], [0x03F7, 0x0481], [0x0531, 0x0556], [0x0559, 0x055F], [0x0561, 0x0587], [0x05D0, 0x05EA], [0x05F0, 0x05F2], [0x0660, 0x0669], [0x066E, 0x066F]] },
  { property: 'XID_Start', ranges: [[0x0041, 0x005A], [0x0061, 0x007A], [0x00AA, 0x00AA], [0x00B5, 0x00B5], [0x00BA, 0x00BA], [0x00C0, 0x00D6], [0x00D8, 0x00F6], [0x00F8, 0x02C1], [0x02C6, 0x02D1], [0x02E0, 0x02E4], [0x0370, 0x0374], [0x0376, 0x0377], [0x037A, 0x037D], [0x0386, 0x0386], [0x0388, 0x038A], [0x038C, 0x038C], [0x038E, 0x03A1], [0x03A3, 0x03F5], [0x03F7, 0x0481], [0x0531, 0x0556], [0x0559, 0x055F], [0x0561, 0x0587], [0x05D0, 0x05EA], [0x05F0, 0x05F2], [0x005F, 0x005F]] },
  { property: 'XID_Continue', ranges: [[0x0030, 0x0039], [0x0041, 0x005A], [0x005F, 0x005F], [0x0061, 0x007A], [0x00AA, 0x00AA], [0x00B5, 0x00B5], [0x00B7, 0x00B7], [0x00BA, 0x00BA], [0x00C0, 0x00D6], [0x00D8, 0x00F6], [0x00F8, 0x02C1], [0x02C6, 0x02D1], [0x02E0, 0x02E4], [0x0300, 0x036F], [0x0370, 0x0374], [0x0376, 0x0377], [0x037A, 0x037D], [0x0386, 0x0386], [0x0388, 0x038A], [0x038C, 0x038C], [0x038E, 0x03A1], [0x03A3, 0x03F5], [0x03F7, 0x0481], [0x0531, 0x0556], [0x0559, 0x055F], [0x0561, 0x0587], [0x05D0, 0x05EA], [0x05F0, 0x05F2], [0x0660, 0x0669], [0x066E, 0x066F]] },
  { property: 'Math', ranges: [[0x002B, 0x002B], [0x003C, 0x003E], [0x007C, 0x007C], [0x007E, 0x007E], [0x00AC, 0x00AC], [0x00B1, 0x00B1], [0x00D7, 0x00D7], [0x00F7, 0x00F7], [0x03D0, 0x03D0], [0x03D1, 0x03D1], [0x03D5, 0x03D5], [0x03D6, 0x03D6], [0x03F0, 0x03F0], [0x03F1, 0x03F1], [0x03F4, 0x03F4], [0x03F5, 0x03F5], [0x2200, 0x22FF], [0x27C0, 0x27EF], [0x2980, 0x29FF], [0x2A00, 0x2AFF]] },
  { property: 'Dash', ranges: [[0x002D, 0x002D], [0x00AD, 0x00AD], [0x058A, 0x058A], [0x1806, 0x1806], [0x2010, 0x2015], [0x2E17, 0x2E17], [0x2E1A, 0x2E1A], [0x2E3A, 0x2E3B], [0x301C, 0x301C], [0x3030, 0x3030], [0x30A0, 0x30A0], [0xFE31, 0xFE32], [0xFE58, 0xFE58], [0xFE63, 0xFE63], [0xFF0D, 0xFF0D]] },
  { property: 'Extender', ranges: [[0x00B7, 0x00B7], [0x02D0, 0x02D1], [0x0640, 0x0640], [0x0E46, 0x0E46], [0x0EC6, 0x0EC6], [0x1843, 0x1843], [0x3005, 0x3005], [0x3031, 0x3035], [0x309D, 0x309E], [0x30FC, 0x30FE], [0xA015, 0xA015], [0xA60C, 0xA60C], [0xA9CF, 0xA9CF], [0xAA70, 0xAA70]] },
  { property: 'Join_Control', ranges: [[0x200C, 0x200D]] },
  { property: 'Bidi_Control', ranges: [[0x200E, 0x200F], [0x202A, 0x202E], [0x2066, 0x2069]] },
  { property: 'Default_Ignorable_Code_Point', ranges: [[0x00AD, 0x00AD], [0x034F, 0x034F], [0x061C, 0x061C], [0x115F, 0x1160], [0x17B4, 0x17B5], [0x180B, 0x180F], [0x200B, 0x200F], [0x202A, 0x202E], [0x2060, 0x206F], [0x3164, 0x3164], [0xFE00, 0xFE0F], [0xFEFF, 0xFEFF], [0xFFA0, 0xFFA0], [0xFFF0, 0xFFF8], [0x1BCA0, 0x1BCA3], [0x1D173, 0x1D17A]] },
  { property: 'Deprecated', ranges: [[0x0149, 0x0149], [0x0673, 0x0673], [0x0F77, 0x0F77], [0x0F79, 0x0F79], [0x17A3, 0x17A4], [0x206A, 0x206F]] },
  { property: 'Noncharacter_Code_Point', ranges: [[0xFDD0, 0xFDEF], [0xFFFE, 0xFFFF], [0x1FFFE, 0x1FFFF], [0x2FFFE, 0x2FFFF], [0x3FFFE, 0x3FFFF], [0x4FFFE, 0x4FFFF], [0x5FFFE, 0x5FFFF], [0x6FFFE, 0x6FFFF], [0x7FFFE, 0x7FFFF], [0x8FFFE, 0x8FFFF], [0x9FFFE, 0x9FFFF], [0xAFFFE, 0xAFFFF], [0xBFFFE, 0xBFFFF], [0xCFFFE, 0xCFFFF], [0xDFFFE, 0xDFFFF], [0xEFFFE, 0xEFFFF], [0xFFFFE, 0xFFFFF], [0x10FFFE, 0x10FFFF]] },
  { property: 'White_Space', ranges: [[0x0009, 0x000D], [0x0020, 0x0020], [0x0085, 0x0085], [0x00A0, 0x00A0], [0x1680, 0x1680], [0x2000, 0x200A], [0x2028, 0x2029], [0x202F, 0x202F], [0x205F, 0x205F], [0x3000, 0x3000]] },
];

const caseFoldingEntries = [
  { property: 'Simple_Case_Folding', ranges: [[0x0041, 0x005A], [0x0061, 0x007A], [0x00B5, 0x00B5], [0x00C0, 0x00D6], [0x00D8, 0x00DE], [0x00DF, 0x00F6], [0x00F8, 0x00FF], [0x0100, 0x017F], [0x0180, 0x024F], [0x0250, 0x02AF], [0x0370, 0x0373], [0x0375, 0x0377], [0x037A, 0x037D], [0x0386, 0x0386], [0x0388, 0x038A], [0x038C, 0x038C], [0x038E, 0x03A1], [0x03A3, 0x03E1], [0x03F0, 0x03F5], [0x03F7, 0x03FF], [0x0400, 0x0481], [0x048A, 0x052F], [0x0531, 0x0556], [0x0561, 0x0587], [0x10A0, 0x10C5], [0x1E00, 0x1EFF], [0x1F00, 0x1FFE]] },
  { property: 'Full_Case_Folding', ranges: [[0x00DF, 0x00DF], [0x0130, 0x0130], [0x0149, 0x0149], [0x01F0, 0x01F0], [0x0390, 0x0390], [0x03B0, 0x03B0], [0x0587, 0x0587], [0x1E96, 0x1E9F], [0x1EF2, 0x1EF3], [0x1F50, 0x1F50], [0x1F52, 0x1F52], [0x1F54, 0x1F54], [0x1F56, 0x1F56], [0x1F80, 0x1FB4], [0x1FB6, 0x1FBF], [0x1FC2, 0x1FC4], [0x1FC6, 0x1FCF], [0x1FD0, 0x1FD3], [0x1FD6, 0x1FDB], [0x1FE0, 0x1FEC], [0x1FF2, 0x1FF4], [0x1FF6, 0x1FFF], [0xFB00, 0xFB06], [0xFB13, 0xFB17]] },
  { property: 'Turkic_Case_Folding', ranges: [[0x0049, 0x0049], [0x0069, 0x0069], [0x0130, 0x0130], [0x0131, 0x0131]] },
];

const whiteSpaceEntries = [
  { property: 'White_Space', ranges: [[0x0009, 0x000D], [0x0020, 0x0020], [0x0085, 0x0085], [0x00A0, 0x00A0], [0x1680, 0x1680], [0x2000, 0x200A], [0x2028, 0x2029], [0x202F, 0x202F], [0x205F, 0x205F], [0x3000, 0x3000]] },
];

const identifierProfilesEntries = [
  { property: 'ID_Start', ranges: [[0x0041, 0x005A], [0x0061, 0x007A], [0x00AA, 0x00AA], [0x00B5, 0x00B5], [0x00BA, 0x00BA], [0x00C0, 0x00D6], [0x00D8, 0x00F6], [0x00F8, 0x02C1], [0x02C6, 0x02D1], [0x02E0, 0x02E4], [0x0370, 0x0374], [0x0376, 0x0377], [0x037A, 0x037D], [0x037F, 0x037F], [0x0386, 0x0386], [0x0388, 0x038A], [0x038C, 0x038C], [0x038E, 0x03A1], [0x03A3, 0x03F5], [0x03F7, 0x0481], [0x0531, 0x0556], [0x0559, 0x055F], [0x0561, 0x0587], [0x05D0, 0x05EA], [0x05F0, 0x05F2], [0x005F, 0x005F]] },
  { property: 'ID_Continue', ranges: [[0x0030, 0x0039], [0x0041, 0x005A], [0x005F, 0x005F], [0x0061, 0x007A], [0x00AA, 0x00AA], [0x00B5, 0x00B5], [0x00B7, 0x00B7], [0x00BA, 0x00BA], [0x00C0, 0x00D6], [0x00D8, 0x00F6], [0x00F8, 0x02C1], [0x02C6, 0x02D1], [0x02E0, 0x02E4], [0x0300, 0x036F], [0x0370, 0x0374], [0x0376, 0x0377], [0x037A, 0x037D], [0x037F, 0x037F], [0x0386, 0x0386], [0x0388, 0x038A], [0x038C, 0x038C], [0x038E, 0x03A1], [0x03A3, 0x03F5], [0x03F7, 0x0481], [0x0531, 0x0556], [0x0559, 0x055F], [0x0561, 0x0587], [0x05D0, 0x05EA], [0x05F0, 0x05F2], [0x0660, 0x0669], [0x066E, 0x066F]] },
];

const PROFILES = [
  {
    profileID: 'general-category',
    propertySet: ['Lu','Ll','Lt','Lm','Lo','Mn','Mc','Me','Nd','Nl','No','Pc','Pd','Ps','Pe','Pi','Pf','Po','Sm','Sc','Sk','So','Zs','Zl','Zp','Cc','Cf','Cs','Co','Cn'],
    consumerSet: ['MonaRegExpParser','MonaRegExpExecutor'],
    entries: generalCategoryEntries,
  },
  {
    profileID: 'script',
    propertySet: ['Latin','Greek','Cyrillic','Hebrew','Arabic','Common','Inherited'],
    consumerSet: ['MonaRegExpExecutor'],
    entries: scriptEntries,
  },
  {
    profileID: 'binary-properties',
    propertySet: ['Alphabetic','Hex_Digit','ASCII','ID_Start','ID_Continue','XID_Start','XID_Continue','Math','Dash','Extender','Join_Control','Bidi_Control','Default_Ignorable_Code_Point','Deprecated','Noncharacter_Code_Point','White_Space'],
    consumerSet: ['MonaRegExpExecutor'],
    entries: binaryPropertiesEntries,
  },
  {
    profileID: 'case-folding',
    propertySet: ['Simple_Case_Folding','Full_Case_Folding','Turkic_Case_Folding'],
    consumerSet: ['MonaRegExpExecutor','MonaCaseConverter'],
    entries: caseFoldingEntries,
  },
  {
    profileID: 'white-space',
    propertySet: ['White_Space'],
    consumerSet: ['MonaRegExpExecutor','MonaWordClassifier'],
    entries: whiteSpaceEntries,
  },
  {
    profileID: 'identifier-profiles',
    propertySet: ['ID_Start','ID_Continue'],
    consumerSet: ['MonaRegExpParser','MonaRegExpExecutor'],
    entries: identifierProfilesEntries,
  },
];

// ---------------------------------------------------------------------------
// Range merge: produce a sorted, non-overlapping list of [start, end] pairs.
// Touching ranges (end + 1 == next.start) are coalesced so the output never
// contains adjacent-but-touching fragments.
// ---------------------------------------------------------------------------

function mergeRanges(ranges) {
  const sorted = ranges.slice().sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  const out = [];
  for (const [start, end] of sorted) {
    const last = out[out.length - 1];
    if (last && start <= last[1] + 1) {
      if (end > last[1]) last[1] = end;
    } else {
      out.push([start, end]);
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Canonical serializations for provenance hashing (deterministic).
// ---------------------------------------------------------------------------

function canonicalInput(entries) {
  const normalized = entries
    .map((e) => ({ property: e.property, ranges: e.ranges.map((r) => ({ s: r[0], e: r[1] })) }))
    .slice()
    .sort((a, b) => (a.property < b.property ? -1 : a.property > b.property ? 1 : 0));
  return JSON.stringify(normalized);
}

function canonicalOutput(merged) {
  return merged
    .map((r) => r[0].toString(16).padStart(4, '0').toLowerCase() + '-' + r[1].toString(16).padStart(4, '0').toLowerCase())
    .join(';');
}

function sha256Hex(text) {
  return createHash('sha256').update(text, 'utf8').digest('hex');
}

// ---------------------------------------------------------------------------
// Generator hash: SHA-256 of this generator's own source bytes. One hash
// shared by all six profiles — one generator produced them all.
// ---------------------------------------------------------------------------

const generatorPath = fileURLToPath(new URL(import.meta.url));
const generatorSource = readFileSync(generatorPath, 'utf8');
const GENERATOR_HASH = sha256Hex(generatorSource);

// ---------------------------------------------------------------------------
// Build the six profiles with provenance.
// ---------------------------------------------------------------------------

const builtProfiles = PROFILES.map((p) => {
  const merged = mergeRanges(p.entries.flatMap((e) => e.ranges));
  return {
    profileID: p.profileID,
    sourceVersion: SOURCE_VERSION,
    inputHash: sha256Hex(canonicalInput(p.entries)),
    generatorHash: GENERATOR_HASH,
    outputHash: sha256Hex(canonicalOutput(merged)),
    propertySet: p.propertySet.slice(),
    consumerSet: p.consumerSet.slice(),
    ranges: merged,
  };
});

// ---------------------------------------------------------------------------
// Swift emission.
// ---------------------------------------------------------------------------

function emitCodeRange(r) {
  return `MonaRegExpUnicodeProfile.CodeRange(start: 0x${r[0].toString(16).padStart(4, '0').toUpperCase()}, end: 0x${r[1].toString(16).padStart(4, '0').toUpperCase()})`;
}

function emitStringArray(arr) {
  return '[' + arr.map((s) => `"${s}"`).join(', ') + ']';
}

function emitRanges(ranges) {
  if (ranges.length === 0) return '[]';
  const lines = ranges.map((r) => '            ' + emitCodeRange(r) + ',');
  return '[\n' + lines.join('\n') + '\n        ]';
}

function emitProfile(p, accessorName) {
  return `    /// ${accessorName} — profile \`${p.profileID}\`.
    public static let ${accessorName}: MonaRegExpUnicodeProfile = MonaRegExpUnicodeProfile(
        profileID: "${p.profileID}",
        sourceVersion: "${p.sourceVersion}",
        inputHash: "${p.inputHash}",
        generatorHash: "${p.generatorHash}",
        outputHash: "${p.outputHash}",
        propertySet: ${emitStringArray(p.propertySet)},
        consumerSet: ${emitStringArray(p.consumerSet)},
        ranges: ${emitRanges(p.ranges)}
    )`;
}

const accessors = [
  ['generalCategory', builtProfiles[0]],
  ['script', builtProfiles[1]],
  ['binaryProperties', builtProfiles[2]],
  ['caseFolding', builtProfiles[3]],
  ['whiteSpace', builtProfiles[4]],
  ['identifierProfiles', builtProfiles[5]],
];

const profileBlocks = accessors.map(([name, p]) => emitProfile(p, name)).join('\n\n');

const allProfilesList = accessors
  .map(([name]) => `            MonaRegExpUnicodeTables.${name}`)
  .join(',\n');

const header = `// MonaRegExpUnicodeTables.swift
//
// P02-T005 — Generate six non-mergeable RegExp Unicode profiles.
//
// GENERATED FILE — do not edit by hand. Regenerate with:
//
//   /opt/homebrew/Cellar/node/26.7.0/bin/node \\
//       Tools/Generators/generate-regexp-unicode.mjs
//
// This file is the repo-owned Swift port of the Unicode tables consumed by
// the MonaCode ECMAScript RegExp engine. It is a curated, pinned subset of
// Unicode 16.0 (pinned behavioral oracle: Chromium-ICU 78.2) sufficient for
// ECMAScript RegExp matching. The full Unicode database acquisition is owned
// by P00-T003; this generator derives the RegExp-relevant tables from a
// licensed excerpt (see UNICODE-LICENSE.txt alongside this file).
//
// Six SEPARATELY IDENTIFIED profiles are generated:
//
//   1. general-category      — General_Category (Lu, Ll, Nd, ...).
//   2. script                — Script (Latin, Greek, Cyrillic, ...).
//   3. binary-properties     — Binary properties (Alphabetic, Hex_Digit,
//                              White_Space, ID_Start, ...).
//   4. case-folding          — Domain of code points with a case fold.
//   5. white-space           — The White_Space property (dedicated).
//   6. identifier-profiles   — ID_Start / ID_Continue.
//
// Each profile records six provenance fields:
//
//   - sourceVersion : Unicode/ICU revision the curated data is drawn from.
//   - inputHash     : SHA-256 of the canonical input-definition serialization.
//   - generatorHash : SHA-256 of the generator source (shared by all six).
//   - outputHash    : SHA-256 of the canonical merged-range serialization.
//   - propertySet   : property names carried by this profile.
//   - consumerSet   : downstream MonaCode consumers bound to this profile.
//
// NON-MERGEABILITY (structural invariant): each profile carries an
// independent profileID + provenance tuple + consumer set. Two profiles are
// NEVER merged, even when their flattened range tables compare equal. The
// \`MonaRegExpUnicodeProfile.canMerge(with:)\` accessor is unconditionally
// \`false\`.
//
// Provenance summary:
//   sourceVersion   = ${SOURCE_VERSION}
//   generatorHash   = ${GENERATOR_HASH}
//
// MonaCode is a Foundation-only target: \`import Foundation\` is the sole import.

import Foundation

/// A separately identified Unicode table profile with full provenance.
///
/// A profile is the smallest non-mergeable unit of Unicode data consumed by
/// the MonaCode RegExp engine. Each profile carries:
///
///   - a unique \`profileID\` that names the profile's identity;
///   - six provenance fields (\`sourceVersion\`, \`inputHash\`,
///     \`generatorHash\`, \`outputHash\`, \`propertySet\`, \`consumerSet\`);
///   - the flattened, merged, non-overlapping \`ranges\` it emits.
///
/// Identity is the FULL provenance tuple (profileID + the six fields),
/// NOT the range bytes. Two profiles whose \`ranges\` compare equal remain
/// distinct identities. \`canMerge(with:)\` is therefore unconditionally
/// \`false\`: merging is forbidden because each profile carries independent
/// provenance and a distinct consumer set that must be preserved separately.
public struct MonaRegExpUnicodeProfile: Equatable, Hashable, Sendable {

    /// The profile's unique identifier (e.g. \`"general-category"\`).
    public let profileID: String

    /// The Unicode / ICU revision the curated data is drawn from.
    public let sourceVersion: String

    /// SHA-256 (64-char lowercase hex) of the canonical input-definition
    /// serialization for this profile.
    public let inputHash: String

    /// SHA-256 (64-char lowercase hex) of the generator source bytes. Shared
    /// by all six profiles — one generator produced them all.
    public let generatorHash: String

    /// SHA-256 (64-char lowercase hex) of the canonical merged-range
    /// serialization for this profile.
    public let outputHash: String

    /// The property names carried by this profile (e.g. \`["Lu", "Ll"]\`).
    public let propertySet: [String]

    /// The downstream MonaCode consumers bound to this profile.
    public let consumerSet: [String]

    /// The flattened, merged, non-overlapping code-point ranges.
    public let ranges: [CodeRange]

    /// A single inclusive code-point range \[start, end\].
    public struct CodeRange: Equatable, Hashable, Sendable {

        /// Inclusive start code point.
        public let start: UInt32

        /// Inclusive end code point (>= \`start\`).
        public let end: UInt32

        public init(start: UInt32, end: UInt32) {
            self.start = start
            self.end = end
        }
    }

    public init(
        profileID: String,
        sourceVersion: String,
        inputHash: String,
        generatorHash: String,
        outputHash: String,
        propertySet: [String],
        consumerSet: [String],
        ranges: [CodeRange]
    ) {
        self.profileID = profileID
        self.sourceVersion = sourceVersion
        self.inputHash = inputHash
        self.generatorHash = generatorHash
        self.outputHash = outputHash
        self.propertySet = propertySet
        self.consumerSet = consumerSet
        self.ranges = ranges
    }

    /// Profiles are NEVER mergeable.
    ///
    /// Merging is forbidden because each profile carries independent
    /// provenance (source version, input hash, generator hash, output hash,
    /// property set) and a distinct consumer set that must be preserved
    /// separately. This returns \`false\` unconditionally — even when called
    /// with a profile whose \`ranges\` compare equal to this profile's, and
    /// even when called with \`self\`.
    public func canMerge(with other: MonaRegExpUnicodeProfile) -> Bool {
        _ = other
        return false
    }
}

/// The six generated Unicode table profiles consumed by the MonaCode
/// ECMAScript RegExp engine.
public enum MonaRegExpUnicodeTables {

${profileBlocks}

    /// All six profiles, in canonical order.
    public static let allProfiles: [MonaRegExpUnicodeProfile] = [
${allProfilesList}
    ]
}
`;

const outPath = new URL('../../Sources/MonaCode/Generated/RegExp/MonaRegExpUnicodeTables.swift', import.meta.url);
writeFileSync(outPath, header, 'utf8');

// ---------------------------------------------------------------------------
// Emit a small provenance manifest to stderr for auditability.
// ---------------------------------------------------------------------------

for (const p of builtProfiles) {
  process.stderr.write(
    `[generate-regexp-unicode] ${p.profileID}\n` +
    `  sourceVersion = ${p.sourceVersion}\n` +
    `  inputHash     = ${p.inputHash}\n` +
    `  generatorHash = ${p.generatorHash}\n` +
    `  outputHash    = ${p.outputHash}\n` +
    `  properties    = ${p.propertySet.length}\n` +
    `  ranges        = ${p.ranges.length}\n` +
    `  consumers     = ${p.consumerSet.join(', ')}\n`
  );
}
process.stderr.write(`[generate-regexp-unicode] wrote ${fileURLToPath(outPath)}\n`);
