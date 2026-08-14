# MonaCode G4-R contract archive

Status: adopted and frozen on 2026-08-14.

This directory is the repository record for the complete MonaCode feature scope and technical contract against `monaco-editor@0.56.0`. It preserves the full convergence history and the final machine-audited contract without changing the audited bytes.

## Authority order

1. [adoption-record.json](adoption-record.json) promotes one exact G4-R artifact hash as the adopted final baseline.
2. [monacode-g4r-authoritative-manifest.json](artifacts/monacode-g4r-authoritative-manifest.json) is the normative full-scope contract.
3. The machine artifacts referenced by that manifest are normative for their declared domains.
4. [global-g4r-authoritative-contract.html](artifacts/global-g4r-authoritative-contract.html) is the human-readable, non-normative visualization.
5. G1, G2, G3 and all adversarial or closure pages are retained as historical evidence. They never override G4-R.

The adopted normative manifest SHA-256 is:

```text
f4d0da0ff6c1ad90ab1376588260afd6c92c1eca236619449c9b6532b5e57021
```

The original manifest identifies itself as `G4-R-full-scope-candidate`. The adoption record promotes those exact immutable bytes to `G4-R-full-scope-final`; the source artifact is not rewritten because rewriting would invalidate its audited hash graph.

## Preserved artifacts

The [artifacts](artifacts) directory contains all 72 content artifacts from the design session:

- 52 HTML visual, adversarial, convergence, and closure pages
- 19 JSON scope, source, type, host, language, runtime, and acceptance manifests
- 1 executable G4-R audit module

[SHA256SUMS](SHA256SUMS) records every archived artifact. Runtime-only companion state is excluded: access token, port cache, PID, server instance ID, and token-bearing server information.

## Verification

Run from this directory:

```sh
node verify-contract.mjs
```

The wrapper verifies the complete archive path set and hashes, the adoption pointer, and the audit JSON. It returns a nonzero exit code on any mismatch. The immutable underlying checks remain directly runnable:

```sh
shasum -a 256 -c SHA256SUMS
node artifacts/monacode-g4r-audit.mjs
```

The accepted audit result is `status=pass`, `failureCount=0`, `unresolvedScopeDecisions=0`, with 42 normative layers, 17 machine artifacts, 60 local hash references, 555 public paths, 10 correctness gates, 14 performance workloads, and 7 required candidate artifacts.

The seven candidate implementation artifacts remain absent until product code generates them. Contract adoption does not claim implementation or release acceptance.

## Freeze rule

Every implementation task must cite the G4-R domain, machine artifact, and acceptance gate it implements. Phase planning can change order and dependency scheduling only. A change to product scope, a cut, a native adaptation, architecture, host behavior, or an acceptance threshold requires a new global revision and a new adoption record.
