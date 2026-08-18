# MonaCode — License Provenance and Distribution Notices

> GENERATED RESOURCE — `Sources/MonaCode/Generated/LICENSE.md`.
> Assembled by P08-T003 (Phase 08 — release candidate / distribution).
>
> MonaCode is a Swift port of `monaco-editor@0.56.0`. This file assembles every
> license that applies to the distributed release, each with its exact license
> text and source provenance, and records the inputs that are oracle-only or
> excluded (no derived production code).
>
> The public API is FROZEN (P07-T011). This LICENSE.md is a Generated resource,
> not a public API symbol — assembling it does not change the API.

- MonaCode build platform: `macOS-26-arm64`
- Record SHA-256 (P08-T003): `5fa3493b4af2f2c9b5d7aa71c503553ff389801a991a44f8c509340b9e579ca4`
- Authoritative manifest: `docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-authoritative-manifest.json` (`licensingProfile` + `authorityArtifacts`)

---

## 1. Assembled licenses

The eleven license sections below cover every license that applies to the
MonaCode distribution. Each section records the license name, the exact license
text (or the contract provenance summary where the upstream license file is
referenced by pinned hash), and the source provenance. License texts marked
“verbatim” are byte-identical to the repository-owned license files under
`Sources/MonaCode/`.

### 1.1 Monaco (MIT)

Source: `monaco-editor-core@0.56.0` package `LICENSE` (tarball SHA-256
`78e222c77e7ef6402ea0bfb20e02caad7b63156f5d2798bc3c398a8bb396f4ed`).
Verbatim copy: `Sources/MonaCode/Generated/MONACO-MIT-LICENSE.txt`.

> Copyright (c) 2016 - present Microsoft Corporation

```
The MIT License (MIT)

Copyright (c) 2016 - present Microsoft Corporation

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Contract provenance: `licensingProfile.monacoCode` — “MIT; retain copyright and
license notice in copies or substantial portions”.

### 1.2 Monaco localization (MIT)

Source: the 15 locale JavaScript files under `monaco-editor@0.56.0
esm/vs/nls/lang/` and `esm/vs/nls.js` (byte-identical to the pinned core
tarball above). The 15 profiles × 2120 messages are transcribed verbatim into
`Sources/MonaCode/Generated/MonaLocalizationProfiles.swift`. The Monaco MIT
notice accompanies them (see §1.1) and is also stored verbatim at
`Sources/MonaCode/Generated/MONACO-MIT-LICENSE.txt` (P05-T007).

Contract provenance: `licensingProfile.monacoLocalization` — “all copied or
generated English and 13 packaged locale tables retain Monaco MIT provenance
and notice”.

### 1.3 Marked 14 (MIT)

Source: `marked@14.0.0` `esm/vs/base/common/marked/marked.js` (pinned source
SHA-256 `75746ae6ff08f4e9b94090ed018e5ac1bf7dbb7e8fcdb4ec48784bd6569d9fda`).
Verbatim copy: `Sources/MonaCode/Markdown/MARKED-MIT-LICENSE.txt` (P06-T008).
The Swift port (`MonaMarkdownParser.swift`) is a derived work; the upstream
MIT notice is retained and modified files are identified per the modification
record in that file.

> Copyright (c) 2011-2024, MarkedJS (Christopher Jeffrey)

```
The MIT License (MIT)

Copyright (c) 2011-2024, MarkedJS (Christopher Jeffrey)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Contract provenance: `licensingProfile.marked` — “the repository-vendored Swift
port of Marked 14.0.0 retains the MarkedJS MIT copyright and license notice
and identifies modified files”.

### 1.4 LSP specification (CC BY 4.0)

Source: the Language Server Protocol `3.18` snapshot (repository commit
`8b9fab8f0912b694c795d05c1d5e9d357bee0193`; specification SHA-256
`67e09b5458884dad63631a4cc7f4ea72b659b023e950eb0f7fa7311355cde3d7`). The
frozen LSP protocol profile drives the MonaCode LSP surface. Copied or adapted
specification text, schemas, and generated protocol material retain the CC BY
4.0 attribution, license reference, and modification notice.

Pinned license hash (licenseSha256, operation 3):
`9f614db80a4e62cbb744e6f00d9da221adf45c6463556cb32f81ad1f8467f188`

Contract provenance: `authorityArtifacts[id=lsp-3.18-snapshot]` and
`licensingProfile.lspSpecification` — “CC BY 4.0; retain attribution, license
reference and modification notice for copied or adapted specification text,
schemas and generated protocol material”.

```
Creative Commons Attribution 4.0 International (CC BY 4.0)

You are free to:
  Share — copy and redistribute the material in any medium or format.
  Adapt — remix, transform, and build upon the material for any purpose, even
          commercially.

Under the following terms:
  Attribution — You must give appropriate credit, provide a link to the
          license, and indicate if changes were made. You may do so in any
          reasonable manner, but not in any way that suggests the licensor
          endorses you or your use.
  No additional restrictions — You may not apply legal terms or technological
          measures that legally restrict others from doing anything the
          license permits.

Full license: https://creativecommons.org/licenses/by/4.0/legalcode
```

### 1.5 Codicon (CC BY 4.0)

Source: `vscode-codicons` (repository commit
`9991679e3d421e05577745f4e37d5745294fa3bc`). The Codicon artwork and font are
licensed CC BY 4.0; the icon registry, font, and attribution profile are
recorded in `authorityArtifacts[id=vscode-codicons]`. The bundled font bytes
acquisition (deferred codicon.ttf) is owned by P05-T006; the license is
provenance-attached here regardless of the deferred binary.

Pinned license hashes (operation 3):
- Codicon artwork (artworkLicenseSha256):
  `af5e030844efddbc7ab00dcfea8b019703753d4d9f5172d727c533a492aec665`
- Codicon code (codeLicenseSha256):
  `9906940f61b1f0b533fa7d99baf55178b2808fbe113ea51dfbfad8572ccd5f2b`

Other provenance hashes (bundled binary, recorded for P05-T006):
- bundledFontSha256: `cc2472e239e17062e7760af87f8f5997720cc0d94aa014a615c418baaf6333a8`
- bundledCssSha256: `1ce4b06d1e3b7f1a877c4ff2d2c7060deadda126be5b80f2417d6eddfed68417`

Contract provenance: `licensingProfile.codiconArtworkAndFont` — “CC BY 4.0;
retain attribution, license reference and modification notice”.

```
Creative Commons Attribution 4.0 International (CC BY 4.0)

The Codicon artwork and font are licensed under CC BY 4.0. Retain the
attribution, license reference, and modification notice for any copy or
adaptation. See §1.4 for the canonical CC BY 4.0 terms.

Full license: https://creativecommons.org/licenses/by/4.0/legalcode
```

### 1.6 Git Logo exception (CC BY 3.0)

The Codicon font bundles the Git Logo glyph under a CC BY 3.0 exception. When
the bundled full font includes the Git Logo glyph, the CC BY 3.0 attribution
and license are retained. The exception applies only to that glyph; the rest
of the font remains CC BY 4.0 (§1.5).

Contract provenance: `licensingProfile.codiconGitLogoException` — “CC BY 3.0
attribution and license are retained when the bundled full font includes the
Git Logo glyph”.

```
Creative Commons Attribution 3.0 Unported (CC BY 3.0)

The Git Logo glyph is licensed under CC BY 3.0. Retain the attribution and
license reference when the bundled full font includes the glyph.

Full license: https://creativecommons.org/licenses/by/3.0/legalcode
```

### 1.7 generator (MIT)

The MonaCode generators and release tools under `Tools/Generators/` and
`Tools/Release/` are repository-owned Node/Swift code. They are MIT-licensed as
part of the MonaCode distribution (same notice as §1.1). The generated tables
and assets carry their own provenance headers (see §4); the generators that
produce them retain the MonaCode MIT notice.

Generators:
- `Tools/Generators/generate-contract-registries.mjs`
- `Tools/Generators/generate-environment-tables.mjs`
- `Tools/Generators/generate-localization.mjs`
- `Tools/Generators/generate-regexp-unicode.mjs`

Release tools:
- `Tools/Release/build-release.sh`
- `Tools/Release/scan-distribution.swift`
- `Tools/Release/scan-symbol-graphs.mjs`
- `Tools/Release/verify-notices.mjs`

Contract provenance: `licensingProfile.codiconGeneratorAndCode` — “MIT” (the
Codicon generator and code license); the broader MonaCode generators share the
MonaCode MIT notice (§1.1).

```
The MIT License (MIT)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### 1.8 Unicode-3.0

Source: Unicode Character Database 16.0.0
(`https://www.unicode.org/Public/16.0.0/`), licensed under the Unicode, Inc.
License Agreement — Data Files and Software (Unicode License v3). Verbatim
copy: `Sources/MonaCode/Generated/RegExp/UNICODE-LICENSE.txt` (P02-T005). The
curated, pinned subset of Unicode 16.0 property data is derived from the UCD;
the behavioral oracle is Chromium-ICU 78.2 (Chrome 151.0.7922.138), which
corresponds to Unicode 16.0.0. Each of the six generated Unicode table
profiles in `MonaRegExpUnicodeTables.swift` records its `sourceVersion` as
`Unicode-16.0.0/ICU-78.2` and carries an independent inputHash/outputHash for
provenance verification.

Contract provenance: `licensingProfile.unicodeTables` — “Unicode-3.0 pinned
notice accompanies every distributed derived Unicode table”.

```
UNICODE, INC. LICENSE AGREEMENT - DATA FILES AND SOFTWARE

Unicode Data Files include all data files under the directories:
    https://www.unicode.org/Public/
    https://www.unicode.org/reports/
    https://www.unicode.org/ivd/data/
    https://www.unicode.org/emoji/

Unicode Data Files are copyright (c) 1991-2025 Unicode, Inc. All rights
reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of the Unicode Data Files or Unicode Software and any associated documentation
(the "Data Files" or "Software") to deal in the Data Files or Software without
restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, and/or sell copies of the Data Files or Software,
and to permit persons to whom the Data Files or Software are furnished to do
so, provided that either (a) this copyright and permission notice appear with
all copies of the Data Files or Software, or (b) this copyright and permission
notice appear in associated Documentation.

THE DATA FILES AND SOFTWARE ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS INCLUDED IN THIS NOTICE BE LIABLE
FOR ANY CLAIM, OR ANY SPECIAL INDIRECT OR CONSEQUENTIAL DAMAGES, OR ANY
DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
CONNECTION WITH THE USE OR PERFORMANCE OF THE DATA FILES OR SOFTWARE.

Except as contained in this notice, the name of a copyright holder shall not
be used in advertising or otherwise to promote the sale, use or other
dealings in the Data Files or Software without prior written authorization of
the copyright holder.

Full license: https://www.unicode.org/license.txt
```

### 1.9 Chromium ICU

Source: Chromium-ICU 78.2 (ICU commit
`d578f2e8b7bd5938e21cfb6bf15c079e0aa5b738`; Chromium tag commit
`28a7a6c409e03c701d3474ef9e3b1f0be6249039`; local `icudtl.dat` SHA-256
`9f48c7f9c7c94d516a14870707e910ab94d75ae640ff6842c4af53276cd26ebe`). The
generated collation and locale tables use Chromium ICU 78.2 as the default
case, collation, and locale-data oracle plus a licensed generated-table input.
The exact ICU LICENSE and the generated-table modification/provenance record
accompany distribution. ICU code and runtime remain absent from production
(X1 records the pinned V8 source commit and `ieee754.cc` hash as behavioral
provenance without copying or linking that source).

Pinned license hash (licenseSha256, operation 3):
`e55522d81edc687a341a4411e0776e54ca654e90147f354a90458aaced4116af`

Contract provenance: `authorityArtifacts[id=chromium-151-icu-data]` and
`licensingProfile.chromiumIcuData`.

```
ICU License (ICU 78.2 / Chromium-151)

The ICU data files and software are distributed under the ICU License (a
BSD-style permissive license). The generated MonaCode collation and locale
tables derived from ICU 78.2 data carry this notice and the provenance record
above. The ICU code and runtime are NOT linked into MonaCode production
binaries; only the licensed data-derived immutable tables ship.

Reference: https://github.com/unicode-org/icu/blob/main/LICENSE
```

### 1.10 Test262 (BSD)

Source: test262 (the JavaScript conformance test suite). Test262-derived
comparator corpora, generated vectors, and binary test artifacts carry the
Test262 BSD license. These are comparator/test artifacts; the Test262 BSD
notice accompanies any redistributed source corpora, generated vectors, and
binary test artifacts derived from Test262.

Contract provenance: `licensingProfile.test262` — “Test262 BSD license
accompanies redistributed source corpora, generated vectors and binary test
artifacts derived from Test262”.

```
BSD 3-Clause License (Test262)

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
  1. Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.
  2. Redistributions in binary form must reproduce the above copyright notice,
     this list of conditions and the following disclaimer in the documentation
     and/or other materials provided with the distribution.
  3. Neither the name of the copyright holder nor the names of its
     contributors may be used to endorse or promote products derived from this
     software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Reference: https://github.com/tc39/test262/blob/main/CONTRIBUTING.md
```

### 1.11 esbuild comparator notice

Source: `esbuild@0.25.9`. esbuild is MIT-licensed and is a comparator
build-tool only (M1 — the Marked comparator). It is absent from MonaCode
product binaries and resources. Any redistributed benchmark bundle that
contains it includes its installed MIT notice.

Contract provenance: `licensingProfile.comparatorBuildTools` — “esbuild 0.25.9
is MIT-licensed and builds M1 only; it is absent from product binaries and
resources; any redistributed benchmark bundle containing it includes its
installed MIT notice”.

```
The MIT License (MIT) — esbuild

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Reference: https://github.com/evanw/esbuild/blob/main/LICENSE.md
```

---

## 2. Oracle-only and excluded inputs (no derived production code)

The following inputs are oracle-only or excluded: they are used for differential
testing / reference / behavioral provenance only, and are NOT in MonaCode
production binaries or resources. There is no derived production code from any
of them.

### 2.1 DOMPurify — oracle-only

`licensingProfile.domPurify`: “DOMPurify 3.4.8 is comparator-oracle-only and
absent from production; copied or derived code requires a new provenance
revision and Apache-2.0 or MPL-2.0 compliance”.

DOMPurify is a comparator-oracle-only component. The MonaCode Markdown port
(M1-R / MD1-R) emits typed semantic nodes and applies a native sanitizer; it
never links DOMPurify, never loads a DOM/WebView, and never creates arbitrary
elements. DOMPurify 3.4.8 is absent from production. No derived production code.

### 2.2 V8/ICU runtime — oracle-only

`licensingProfile.v8AndIcu`: “V8 and ICU code/runtime are oracle-only and
absent from production; X1 records the pinned V8 source commit and
`ieee754.cc` hash as behavioral provenance without copying or linking that
source; pinned Unicode and Chromium-ICU data plus repository-generated
immutable tables are permitted only under E1 provenance and license rules”.

The V8 JavaScript engine and the ICU runtime are oracle-only. X1-R records the
pinned V8 source commit and `ieee754.cc` hash as behavioral provenance only —
that source is neither copied nor linked. MonaCode ships repository-generated
immutable tables (E1-R provenance) derived from the licensed Unicode and
Chromium-ICU data; the V8/ICU runtime is absent from production. No derived
production code.

### 2.3 vscode-unicode-data — excluded

`licensingProfile.vscodeUnicodeData`: “the unlicensed provenance repository is
not a build or distribution input”.

The `vscode-unicode-data` repository is unlicensed and is NOT a build or
distribution input. It is excluded entirely. No derived production code.

---

## 3. Pinned license hashes (operation 3 verification)

The four pinned license hashes below are recorded verbatim from the G6-R
authoritative manifest (`authorityArtifacts` + `licensingProfile`). They are
the license-text/content hashes for the upstream license files.
`Tools/Release/verify-notices.mjs` confirms that LICENSE.md records each
verbatim and that each matches the authoritative manifest.

| License                | Field                 | Pinned SHA-256                                                          |
|------------------------|-----------------------|-------------------------------------------------------------------------|
| LSP specification      | licenseSha256         | `9f614db80a4e62cbb744e6f00d9da221adf45c6463556cb32f81ad1f8467f188`     |
| Chromium ICU           | licenseSha256         | `e55522d81edc687a341a4411e0776e54ca654e90147f354a90458aaced4116af`     |
| Codicon artwork        | artworkLicenseSha256  | `af5e030844efddbc7ab00dcfea8b019703753d4d9f5172d727c533a492aec665`     |
| Codicon code           | codeLicenseSha256     | `9906940f61b1f0b533fa7d99baf55178b2808fbe113ea51dfbfad8572ccd5f2b`     |

The Codicon artwork hash (`af5e0308…`) and code hash (`9906940f…`) tie to
P05-T006’s deferred `codicon.ttf`: the LICENSE is provenance-attached here
regardless of the deferred font-binary acquisition.

---

## 4. Provenance headers on every generated table and asset (operation 4)

Every generated table and asset under `Sources/MonaCode/Generated/` and the
Markdown license directory carries a provenance header (task marker + license +
source reference). `Tools/Release/verify-notices.mjs` confirms each file below
carries the header.

### Generated tables (Swift)

| File                              | Task     | License                       | Source                                                  |
|-----------------------------------|----------|-------------------------------|---------------------------------------------------------|
| `MonaPublicAPI.swift`             | P05-T001 | Monaco MIT (§1.1)             | F1-R4 public declaration graph                          |
| `MonaBuiltinKeybindings.swift`    | P05-T003 | Monaco MIT (§1.1)             | F1-R3 scope manifest (builtin keybindings)              |
| `MonaBuiltinMenus.swift`          | P05-T004 | Monaco MIT (§1.1)             | F1-R3 scope manifest (builtin menus)                    |
| `MonaBuiltinOptions.swift`        | P05-T005 | Monaco MIT (§1.1)             | F1-R3 scope manifest (builtin editor options)         |
| `MonaCodiconMap.swift`            | P05-T006 | Codicon CC BY 4.0 (§1.5)      | F1-R3 scope manifest (Codicon glyphs) + codicons repo   |
| `MonaLocalizationProfiles.swift`  | P05-T007 | Monaco localization MIT (§1.2)| N1-R localization manifest + pinned core tarball       |
| `MonaRegExpUnicodeTables.swift`   | P02-T005 | Unicode-3.0 (§1.8)            | Unicode 16.0.0 / ICU 78.2                              |

### Generated assets (license / data files)

| File                                          | Task     | License                  | Source                                       |
|-----------------------------------------------|----------|--------------------------|-----------------------------------------------|
| `Generated/MONACO-MIT-LICENSE.txt`            | P05-T007 | Monaco MIT (§1.1)        | monaco-editor-core@0.56.0 package LICENSE    |
| `Generated/RegExp/UNICODE-LICENSE.txt`       | P02-T005 | Unicode-3.0 (§1.8)       | Unicode 16.0.0 UCD                            |
| `Markdown/MARKED-MIT-LICENSE.txt`             | P06-T008 | Marked 14 MIT (§1.3)    | marked@14.0.0 marked.js                       |
| `Generated/LICENSE.md`                        | P08-T003 | (this file)              | G6-R authoritative manifest licensingProfile  |

---

## 5. Verification

Run `Tools/Release/verify-notices.mjs` to verify this file assembles all
eleven licenses, records the three oracle-only/excluded inputs, confirms the
four pinned license hashes match the G6-R authoritative manifest, and confirms
every generated table and asset carries a provenance header:

```
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Release/verify-notices.mjs
```

The tool emits a JSON report to stdout and exits 0 on success, 1 on any gate
failure. It performs pure local verification (no network).
