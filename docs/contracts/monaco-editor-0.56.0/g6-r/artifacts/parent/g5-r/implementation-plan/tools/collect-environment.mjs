import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import https from 'node:https';
import { pathToFileURL } from 'node:url';

const CHROME_ROOT = '/Applications/Google Chrome.app/Contents';
const CHROME_BINARY = `${CHROME_ROOT}/MacOS/Google Chrome`;
const CHROME_INFO = `${CHROME_ROOT}/Info.plist`;
const CHROME_ICU = `${CHROME_ROOT}/Frameworks/Google Chrome Framework.framework/Versions/Current/Resources/icudtl.dat`;
const ALLOWED_SOURCE_HOST = 'chromium.googlesource.com';

export const pinnedSourceProvenance = Object.freeze({
  chromiumTagCommit: '41fa82442390a4d4456c78f2d69a832d5720cb27',
  chromiumTagURL: 'https://chromium.googlesource.com/chromium/src/+/41fa82442390a4d4456c78f2d69a832d5720cb27/?format=JSON',
  v8Version: '15.1.206.17',
  v8SourceCommit: '00c2754b59cf5f79b323950c63b07cfb1a8377d4',
  v8SourceURL: 'https://chromium.googlesource.com/v8/v8/+/00c2754b59cf5f79b323950c63b07cfb1a8377d4/?format=JSON',
  icuVersion: '78.2',
  icuSourceCommit: 'd578f2e8b7bd5938e21cfb6bf15c079e0aa5b738',
  icuSourceURL: 'https://chromium.googlesource.com/chromium/deps/icu/+/d578f2e8b7bd5938e21cfb6bf15c079e0aa5b738/?format=JSON',
  timeSourceFile: 'base/time/time_apple.mm',
  timeSourceSha256: '0015cb2fa5ee082bb61f07e24c150d161b08a7148143914d43c58f4850c68134',
  timeSourceURL: 'https://chromium.googlesource.com/chromium/src/+/41fa82442390a4d4456c78f2d69a832d5720cb27/base/time/time_apple.mm?format=TEXT'
});

const text = (file, args) => execFileSync(file, args, { encoding: 'utf8' }).trim();
const sha256 = (value) => createHash('sha256').update(value).digest('hex');
const sha256File = (file) => sha256(fs.readFileSync(file));

function capture(pattern, value, label) {
  const match = value.match(pattern);
  if (!match) throw new Error(`unable to parse ${label}`);
  return match[1];
}

function parseResolution(value) {
  const match = String(value ?? '').match(/(\d+) x (\d+)(?: @ ([0-9.]+)Hz)?/);
  if (!match) return null;
  return {
    width: Number(match[1]),
    height: Number(match[2]),
    refreshHz: match[3] === undefined ? null : Number(match[3])
  };
}

function safeDisplay(display) {
  const builtIn = display.spdisplays_connection_type === 'spdisplays_internal';
  const pixels = parseResolution(display._spdisplays_pixels);
  const logical = parseResolution(display.spdisplays_resolution);
  const backingScale = pixels && logical ? pixels.width / logical.width : null;
  const externalLabel = /^LG\b/i.test(display._name ?? '') ? 'LG display' : 'External display';
  return {
    label: builtIn ? 'Built-in display' : externalLabel,
    connection: builtIn ? 'built-in' : 'external',
    pixels,
    logical,
    backingScale
  };
}

function parseInputSourceIDs(value) {
  const ids = [];
  for (const match of value.matchAll(/KeyboardLayout Name\"? = \"?([^;\n\"]+)/g)) {
    ids.push(`keyboard-layout:${match[1].trim()}`);
  }
  for (const match of value.matchAll(/\"Input Mode\" = \"([^\"]+)\"/g)) {
    ids.push(`input-mode:${match[1]}`);
  }
  return [...new Set(ids)].sort();
}

function parseAppleLanguages(value) {
  return [...value.matchAll(/\"([^\"]+)\"/g)].map((match) => match[1]);
}

function currentTimeZone() {
  const resolved = fs.realpathSync('/etc/localtime');
  const marker = '/zoneinfo/';
  return resolved.includes(marker) ? resolved.slice(resolved.indexOf(marker) + marker.length) : resolved;
}

export async function collectEnvironment() {
  const xcode = text('/usr/bin/xcodebuild', ['-version']);
  const swift = text('/usr/bin/xcrun', ['swift', '--version']);
  const profiler = JSON.parse(text('/usr/sbin/system_profiler', [
    'SPHardwareDataType',
    'SPDisplaysDataType',
    '-json'
  ]));
  const hardware = profiler.SPHardwareDataType[0];
  const gpu = profiler.SPDisplaysDataType[0];
  const displays = gpu.spdisplays_ndrvs.map(safeDisplay);
  const builtIn = displays.filter((display) => display.connection === 'built-in');
  const external = displays.filter((display) => display.connection === 'external');
  const enabledInputSources = text('/usr/bin/defaults', [
    'read',
    'com.apple.HIToolbox',
    'AppleEnabledInputSources'
  ]);
  const appleLanguages = text('/usr/bin/defaults', ['read', '-g', 'AppleLanguages']);

  const observation = {
    schemaVersion: 1,
    collectedAt: new Date().toISOString(),
    macOS: {
      version: text('/usr/bin/sw_vers', ['-productVersion']),
      build: text('/usr/bin/sw_vers', ['-buildVersion'])
    },
    xcode: {
      version: capture(/^Xcode ([^\n]+)$/m, xcode, 'Xcode version'),
      build: capture(/^Build version ([^\n]+)$/m, xcode, 'Xcode build')
    },
    macOSSDK: text('/usr/bin/xcrun', ['--show-sdk-version']),
    swift: {
      version: capture(/Apple Swift version ([^\s]+)/, swift, 'Swift version')
    },
    architecture: text('/usr/bin/uname', ['-m']),
    hardwareClass: {
      formFactor: hardware.machine_name,
      modelClass: hardware.machine_model,
      chipClass: hardware.chip_type,
      memoryGiB: Number(capture(/^(\d+) GB$/, hardware.physical_memory, 'physical memory')),
      gpuCoreCount: Number(gpu.sppci_cores),
      metalVersion: gpu.spdisplays_mtlgpufamilysupport === 'spdisplays_metal4' ? 'Metal 4' : gpu.spdisplays_mtlgpufamilysupport
    },
    displays: {
      builtIn,
      externalDisplayCount: external.length,
      external
    },
    chrome: {
      version: text('/usr/libexec/PlistBuddy', ['-c', 'Print :CFBundleShortVersionString', CHROME_INFO]),
      binarySha256: sha256File(CHROME_BINARY),
      chromiumTagCommit: pinnedSourceProvenance.chromiumTagCommit,
      v8: {
        version: pinnedSourceProvenance.v8Version,
        sourceCommit: pinnedSourceProvenance.v8SourceCommit
      },
      icu: {
        version: pinnedSourceProvenance.icuVersion,
        sourceCommit: pinnedSourceProvenance.icuSourceCommit,
        dataSha256: sha256File(CHROME_ICU)
      },
      timeSource: {
        file: pinnedSourceProvenance.timeSourceFile,
        sha256: pinnedSourceProvenance.timeSourceSha256
      }
    },
    locale: {
      appleLocale: text('/usr/bin/defaults', ['read', '-g', 'AppleLocale']),
      appleLanguages: parseAppleLanguages(appleLanguages),
      timeZone: currentTimeZone()
    },
    inputSourceIDs: parseInputSourceIDs(enabledInputSources),
    externalDisplayCountRequired: 0
  };

  const findings = auditEnvironment(observation);
  if (findings.length !== 0) {
    throw new Error(`privacy audit failed: ${JSON.stringify(findings)}`);
  }
  return observation;
}

function privacyViolations(value, path = '$') {
  if (Array.isArray(value)) {
    return value.flatMap((item, index) => privacyViolations(item, `${path}[${index}]`));
  }
  if (value !== null && typeof value === 'object') {
    return Object.entries(value).flatMap(([key, item]) => {
      const own = /serial|uuid|udid|account|user/i.test(key) ? [`${path}.${key}`] : [];
      return own.concat(privacyViolations(item, `${path}.${key}`));
    });
  }
  if (typeof value === 'string' && /\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/i.test(value)) {
    return [path];
  }
  return [];
}

export function auditEnvironment(observation) {
  return privacyViolations(observation).map((path) => ({
    id: 'PLAN_ENVIRONMENT_PRIVACY',
    subject: path,
    message: 'forbidden persistent environment identity'
  }));
}

function fetchChromiumSource(sourceURL) {
  const parsed = new URL(sourceURL);
  if (parsed.protocol !== 'https:' || parsed.hostname !== ALLOWED_SOURCE_HOST) {
    return Promise.reject(new Error(`source host not allowed: ${parsed.hostname}`));
  }
  return new Promise((resolve, reject) => {
    https.get(parsed, (response) => {
      if (response.statusCode !== 200) {
        response.resume();
        reject(new Error(`source request failed: HTTP ${response.statusCode}`));
        return;
      }
      const chunks = [];
      response.on('data', (chunk) => chunks.push(chunk));
      response.on('end', () => resolve(Buffer.concat(chunks)));
    }).on('error', reject);
  });
}

export async function verifyPinnedSourceProvenance() {
  const commitURLs = [
    pinnedSourceProvenance.chromiumTagURL,
    pinnedSourceProvenance.v8SourceURL,
    pinnedSourceProvenance.icuSourceURL
  ];
  const commitPayloads = await Promise.all(commitURLs.map(fetchChromiumSource));
  for (const payload of commitPayloads) {
    JSON.parse(payload.toString('utf8').replace(/^\)\]\}'\n/, ''));
  }
  const encodedTimeSource = await fetchChromiumSource(pinnedSourceProvenance.timeSourceURL);
  const timeSource = Buffer.from(encodedTimeSource.toString('utf8'), 'base64');
  const timeSourceSha256 = sha256(timeSource);
  if (timeSourceSha256 !== pinnedSourceProvenance.timeSourceSha256) {
    throw new Error(`time source hash mismatch: ${timeSourceSha256}`);
  }
  return {
    allowedHost: ALLOWED_SOURCE_HOST,
    commitSourcesVerified: commitPayloads.length,
    timeSourceSha256
  };
}

const invokedPath = process.argv[1] ? pathToFileURL(process.argv[1]).href : null;
if (invokedPath === import.meta.url) {
  const result = process.argv.includes('--verify-source-provenance')
    ? await verifyPinnedSourceProvenance()
    : await collectEnvironment();
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}
