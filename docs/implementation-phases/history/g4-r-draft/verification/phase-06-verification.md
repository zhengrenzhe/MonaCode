# Phase 6 Adversarial Verification Report

Three independent rounds. **No BLOCKING, no MAJOR** — the cleanest phase. All five dimensions clean. Citation integrity verified: 30/25/5 surfaces, 22 adapters+3 bridges=25 mappings, 11/15/39/7/7/4/0 snippet, 2/7/6/1/11/15 markdown, LSP commit `8b9fab8f`/spec SHA `67e09b54`/CC BY 4.0, Marked SHA `75746ae6`, SN1-R/MD1-R manifest SHAs — all match.

## MINOR (noted; high-value applied)

- Task 6.6 probe vector `${NAME/…/upcase}` → `MIXEDCASE`: `NAME` is not among the 39 known variables; document the fixture injection (NAME="mixedcase") or use a known variable. [applied]
- Task 6.7 enumerate the 6 model variable names; add Workspace/Random to the selection-insert per-cursor resolver list (SN1-R: per-cursor = Clipboard/Selection/Comment/Time/Workspace/Random; only Model shared). [applied]
- Task 6.8 enumerate all 6 retained `MonaMarkdownString` members (value, isTrusted, supportThemeIcons, baseUri, uris, enabledCommands). [applied]
- Task 6.8 native projection is consumer-side (Phase 3/4/7); Phase 6 builds the semantic tree. [applied]
- Task 6.8 label 67 tags / 27 attrs as the **cut `baselineWebPolicy`** reference (absent in production due to supportHtml cut), not a production allowlist. [applied]
- Task 6.8 Marked-14 SHA cites MD1-R machine artifact as source (not in `authorityArtifacts`). [applied]
- Task 6.7 document the clipboard-injection path into the ClipboardBased resolver (Phase 4 I4-R provides clipboard data; Foundation-only snippet engine receives it via the session). [applied]
- Task 6.3 scope "clear transient UI + diagnostics" on unexpected exit to **transient session diagnostics**, not ServerAuthoritativePush project markers. [applied]
- Task 6.3 "didClose does NOT clear markers" cites **R1 ServerAuthoritativePush** (not "per LSP" — LSP says clear; R1 overrides). [applied]
- Exit-gate phrasing "30 total / 25 LSP-backed / 5 direct-only". [applied]

## Outcome
Phase 6 approved. No blocking/major issues. All MINOR applied. C06 pass framing honest (30/25/5, framing/JSON/session/malformed matrices, 1 client + 3 cut transports, plain-text fallback, M0+M1).
