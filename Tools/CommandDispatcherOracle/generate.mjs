// Tools/CommandDispatcherOracle/generate.mjs
// Drives monaco-editor@0.56.0 headless (jsdom) to emit frozen JSON fixtures
// for the 9 dispatcher commands. Verified feasible (deterministic, 3x, cross-validated).
import { JSDOM } from 'jsdom';
import { register } from 'node:module';
import { pathToFileURL } from 'node:url';
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, '../..');
const fixturesDir = resolve(repo, 'Tests/Fixtures/CommandDispatcherFixtures');
mkdirSync(fixturesDir, { recursive: true });

// CSS no-op loader hook (monaco imports .css)
const loaderHook = resolve(here, 'loader-hook.mjs');
register(loaderHook, pathToFileURL(import.meta.url));

const dom = new JSDOM('<!DOCTYPE html><div id="container"></div>', {
  url: 'http://localhost/', pretendToBeVisual: true,
});
const { window } = dom;
// polyfills monaco needs but jsdom lacks
window.matchMedia = window.matchMedia || (() => ({ matches: false, addListener(){}, removeListener(){}, addEventListener(){}, removeEventListener(){} }));
window.requestAnimationFrame = (cb) => setTimeout(() => cb(Date.now()), 0);
window.cancelAnimationFrame = (id) => clearTimeout(id);
class RO { observe(){} unobserve(){} disconnect(){} }
window.ResizeObserver = RO; window.trustedTypes = undefined;
// jsdom 27 ships no window.CSS; monaco's icon stylesheet calls CSS.escape on
// class names. This only affects CSS rendering, not the model text/selections
// captured below, so a minimal escape is sufficient for fixture generation.
window.CSS = window.CSS || { escape: (s) => String(s), supports: () => false, registerProperty() {} };
Object.defineProperty(window, 'performance', { value: { now: () => Date.now() }, configurable: true });

globalThis.window = window; globalThis.document = window.document;
globalThis.self = window; globalThis.CSS = window.CSS;
for (const k of ['HTMLElement','Node','Element','MutationObserver','customElements','getComputedStyle','URL','Blob']) globalThis[k] = window[k];

// monaco@0.56.0 ships .js (ESM) with no type:module; load via package exports
// subpath so Node treats it as ESM (the .css imports are no-op'd by loader-hook.mjs).
// There is no default export; named exports (editor, Selection) live on the namespace.
const monaco = await import('monaco-editor/editor/editor.api.js');

function selToArr(s) { return [s.startLineNumber, s.startColumn, s.endLineNumber, s.endColumn]; }
function run(model, sel, command, args) {
  const editor = monaco.editor.create(window.document.getElementById('container'), { model });
  try {
    editor.setSelection(sel);
    if (args !== undefined) editor.trigger('keyboard', command, args);
    else editor.trigger('keyboard', command);
    return { value: model.getValue(), selections: editor.getSelections().map(selToArr) };
  } finally { editor.dispose(); }
}

const cases = [
  // [commandId, args|null, initialText, initialSelection]
  ['type', { text: 'X' }, '', [1,1,1,1]],
  ['type', { text: 'X' }, 'abc', [1,1,1,1]],
  ['type', { text: 'X' }, 'abc', [1,1,1,4]],          // replace selection
  ['deleteLeft', null, 'abc', [1,2,1,2]],
  ['deleteLeft', null, 'ab\ncd', [2,1,2,1]],           // cross-line join
  ['deleteRight', null, 'abc', [1,1,1,1]],
  ['deleteRight', null, 'ab\ncd', [1,3,1,3]],          // cross-line join (end of line)
  ['cursorLeft', null, 'abc', [1,2,1,2]],
  ['cursorRight', null, 'abc', [1,1,1,1]],
  ['cursorUp', null, 'ab\ncd', [2,2,2,2]],
  ['cursorDown', null, 'ab\ncd', [1,2,1,2]],
  ['cursorEnd', null, 'abc', [1,1,1,1]],
  ['cursorHome', null, 'abc', [1,3,1,3]],
];

const byCmd = {};
for (const [command, args, text, sel] of cases) {
  const model = monaco.editor.createModel(text, 'plaintext');
  const initialSel = monaco.Selection.fromPositions({ lineNumber: sel[0], column: sel[1] }, { lineNumber: sel[2], column: sel[3] });
  const expected = run(model, initialSel, command, args);
  (byCmd[command] ??= []).push({ command, args, initialText: text, initialSelection: [sel], expected });
  model.dispose();
}
for (const [command, list] of Object.entries(byCmd)) {
  writeFileSync(resolve(fixturesDir, command + '.json'), JSON.stringify(list, null, 2) + '\n');
  console.log('wrote', command, list.length, 'cases');
}
