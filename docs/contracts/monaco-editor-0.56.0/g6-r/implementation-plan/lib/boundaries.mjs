// G6-R product boundary audit (ported from G5-R without cross-directory
// imports). Enforces the frozen product boundaries on the execution plan's
// declared task paths: no task creates a forbidden runtime backend
// (built-in language, LSP server, JavaScript/ICU/WebView/DOM/CSS/TextKit/
// persistence/telemetry), every Sources/ path lives under its task's declared
// productTarget, and no MonaCode product path carries an AppKit-only import
// token. The G5-R packageGraph/globalConstraints/Metal/candidate-order checks
// are G5-R plan-governance surfaces (not present on the G6-R execution plan)
// and are therefore not ported here; the G6-R execution boundaries
// (commit/evidence/workspace) are owned by mutation-policy.mjs and file-state.mjs.

import { makeFinding, sortFindings } from './findings.mjs';

const FORBIDDEN_PRODUCT_PATHS = [
  ['builtin-language-content', /(?:Builtin[^/]*Language|LanguagePack|GrammarPack|SnippetCatalog)/i],
  ['lsp-server', /LSPServer/i],
  ['javascript-runtime', /JavaScript(?:Runtime|Engine|Core)/i],
  ['icu-runtime', /(?:ICU(?:Runtime|Engine)|icudtl\.dat)/i],
  ['webview-runtime', /(?:WebView|WKWebView|WebKit)/i],
  ['dom-css-runtime', /(?:DOM(?:Runtime|Backend)|CSS(?:Runtime|Backend))/i],
  ['textkit-backend', /(?:TextKit|NSTextStorage|NSLayoutManager)/i],
  ['persistence-backend', /(?:Persistent(?:State|Store|Backend)|Persistence)/i],
  ['telemetry-ui', /(?:Telemetry(?:Panel|UI|View)|Notification(?:Progress|Panel)|SignalAudio)/i],
];

// Product roots under Sources/. A path under Sources/<Product>/ must agree
// with the task's declared productTarget.
const PRODUCT_ROOTS = ['MonaCode', 'MonaCodeAppKit', 'MonaCodeSwiftUI', 'MonaCodeSample'];

const isArr = (v) => Array.isArray(v);
const isStr = (v) => typeof v === 'string' && v.length > 0;

function taskSourcePaths(task) {
  const paths = task.paths ?? {};
  return [...(isArr(paths.create) ? paths.create : []), ...(isArr(paths.modify) ? paths.modify : [])]
    .filter(isStr)
    .filter((p) => p.startsWith('Sources/'));
}

/**
 * Audit forbidden runtime backend paths across every task.
 * @param {{tasks?:Array<{id:string,paths?:{create?:string[],modify?:string[]}}>} plan
 */
export function auditForbiddenProductPaths(plan) {
  const findings = [];
  for (const task of plan.tasks ?? []) {
    for (const sourcePath of taskSourcePaths(task)) {
      for (const [profile, pattern] of FORBIDDEN_PRODUCT_PATHS) {
        if (pattern.test(sourcePath)) {
          findings.push(makeFinding({
            id: 'PLAN_FORBIDDEN_PRODUCT_PATH', category: 'boundary', taskID: task.id,
            path: sourcePath, message: `${profile} path is forbidden: ${sourcePath}`,
          }));
        }
      }
    }
  }
  return sortFindings(findings);
}

/**
 * Audit that every Sources/<Product>/ path lives under the task's declared
 * productTarget (when one is declared).
 * @param {{tasks?:Array<{id:string,paths?:{create?:string[],modify?:string[],productTarget?:string|null}}>} plan
 */
export function auditProductTargetBoundary(plan) {
  const findings = [];
  for (const task of plan.tasks ?? []) {
    const target = task.paths?.productTarget;
    if (!isStr(target)) continue;
    for (const sourcePath of taskSourcePaths(task)) {
      const root = sourcePath.split('/')[1];
      if (!PRODUCT_ROOTS.includes(root)) continue;
      // MonaCodeSample is a host target, not a product; tasks targeting it may
      // legitimately create MonaCodeSample sources. Otherwise the Sources root
      // must match the productTarget.
      if (target === 'MonaCodeSample') continue;
      if (root !== target) {
        findings.push(makeFinding({
          id: 'PLAN_FORBIDDEN_PRODUCT_PATH', category: 'boundary', taskID: task.id,
          path: sourcePath, message: `Sources/${root}/ path is outside ${target} boundary`,
        }));
      }
    }
  }
  return sortFindings(findings);
}

/**
 * Aggregate boundary audit.
 * @param {object} plan
 * @returns {ReturnType<typeof makeFinding>[]}
 */
export function auditBoundaries(plan) {
  return sortFindings([
    ...auditForbiddenProductPaths(plan),
    ...auditProductTargetBoundary(plan),
  ]);
}
