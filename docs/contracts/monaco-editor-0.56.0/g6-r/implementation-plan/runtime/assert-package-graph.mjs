// G6-R baseline package-graph checker.
// P00-T001's Red verification pipes `swift package dump-package` into this
// checker. When the package graph is absent (the Red scaffold has not yet
// created Package.swift, so dump-package produces nothing), it emits
// PLAN_PACKAGE_GRAPH_MISSING — the G5-R plan referenced this checker at
// Tools/PlanChecks/assert-package-graph.mjs, which never existed, so the Red
// leaf used to crash with MODULE_NOT_FOUND. This file is the real G6-R
// replacement.
//
// Input: the parsed JSON emitted by `swift package dump-package`
// ({name, products, targets, ...}). The canonical G6-R package-graph record
// ({products, nonProductTargets, resources}) is also accepted for plan-time
// verification.

import { fileURLToPath } from 'node:url';

const REQUIRED_PRODUCTS = 3;
const REQUIRED_NON_PRODUCT_TARGETS = 3;
const REQUIRED_FIXTURE_TARGETS = 0;

/**
 * Test whether a dump-package target is a test target.
 * The `type` field is a string ("test") in modern SwiftPM; older dumps use an
 * object form ({"test": {}}).
 * @param {object} target
 * @returns {boolean}
 */
function isTestTarget(target) {
  if (!target || !target.type) return false;
  const t = target.type;
  if (typeof t === 'string') return t === 'test';
  if (typeof t === 'object' && t !== null) return Object.prototype.hasOwnProperty.call(t, 'test');
  return false;
}

function targetName(target) {
  return target && typeof target.name === 'string' ? target.name : '';
}

function targetPath(target) {
  return target && typeof target.path === 'string' ? target.path : '';
}

/**
 * Verify a parsed package graph against the required three-product graph.
 * @param {unknown} packageJSON parsed `swift package dump-package` output
 *   ({name, products, targets, ...}), or the canonical G6-R package-graph
 *   record ({products, nonProductTargets, resources}).
 * @returns {{exit:number, output:string}}
 */
export function assertPackageGraph(packageJSON) {
  if (packageJSON === null || packageJSON === undefined ||
      typeof packageJSON !== 'object' || Array.isArray(packageJSON)) {
    return { exit: 1, output: 'PLAN_PACKAGE_GRAPH_MISSING' };
  }

  let productCount, nonProductCount, fixtureTargetCount;

  if (Array.isArray(packageJSON.products) && Array.isArray(packageJSON.targets)) {
    // swift package dump-package shape: {name, products, targets, ...}
    productCount = packageJSON.products.length;

    // Collect every target name referenced by a product.
    const productTargetNames = new Set();
    for (const p of packageJSON.products) {
      if (p && Array.isArray(p.targets)) {
        for (const tn of p.targets) {
          if (typeof tn === 'string') productTargetNames.add(tn);
        }
      }
    }

    // nonProductTargets = targets not referenced by any product, excluding
    // test targets (test targets are a separate SwiftPM category, tracked
    // elsewhere). The required graph has exactly three: sample-macOS-host,
    // conformance-and-failure-injection, benchmark-harness.
    const targets = packageJSON.targets;
    nonProductCount = targets.filter(
      (t) => !isTestTarget(t) && !productTargetNames.has(targetName(t)),
    ).length;

    // fixtureTargets = targets whose path is under Tests/Fixtures/. The
    // required graph has zero: DifferentialFixtures is a resource (declared
    // inside a test target's `resources`), never a target.
    fixtureTargetCount = targets.filter(
      (t) => targetPath(t).includes('Tests/Fixtures/'),
    ).length;
  } else if (Array.isArray(packageJSON.products) && Array.isArray(packageJSON.nonProductTargets)) {
    // Canonical G6-R package-graph record: {products, nonProductTargets, resources}.
    productCount = packageJSON.products.length;
    nonProductCount = packageJSON.nonProductTargets.length;
    const resources = Array.isArray(packageJSON.resources) ? packageJSON.resources : [];
    fixtureTargetCount = resources.filter((r) => r && r.isTarget === true).length;
  } else {
    return { exit: 1, output: 'PLAN_PACKAGE_GRAPH_MISSING' };
  }

  const summary =
    `PACKAGE_GRAPH products=${productCount} nonProductTargets=${nonProductCount} fixtureTargets=${fixtureTargetCount}`;
  if (productCount === REQUIRED_PRODUCTS &&
      nonProductCount === REQUIRED_NON_PRODUCT_TARGETS &&
      fixtureTargetCount === REQUIRED_FIXTURE_TARGETS) {
    return { exit: 0, output: summary };
  }
  return { exit: 1, output: summary + ' MISMATCH' };
}

// --- script mode: read stdin (swift package dump-package JSON), emit, exit ---
const __filename = fileURLToPath(import.meta.url);
if (process.argv[1] === __filename) {
  const chunks = [];
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (c) => chunks.push(c));
  process.stdin.on('end', () => {
    const raw = chunks.join('').trim();
    let parsed = null;
    if (raw.length > 0) {
      try { parsed = JSON.parse(raw); } catch { parsed = null; }
    }
    const r = assertPackageGraph(parsed);
    process.stdout.write(r.output + '\n');
    process.exit(r.exit);
  });
  process.stdin.on('error', () => {
    const r = assertPackageGraph(null);
    process.stdout.write(r.output + '\n');
    process.exit(r.exit);
  });
}
