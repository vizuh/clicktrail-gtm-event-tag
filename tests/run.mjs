// Node harness for the ClickTrail Event Tag template.
//
// 1. Checks template.js matches the sandboxed code in template.tpl and
//    tests.yaml matches its ___TESTS___ section ("keep both in sync").
// 2. Runs every tests.yaml scenario against template.js with a small
//    re-implementation of the GTM test API (mock, runCode, assertThat).
//
// Default sandbox mocks follow the documented GTM semantics:
//   - copyFromWindow(key) returns a copy, never a live reference.
//   - setInWindow(key, value, overrideExisting) writes nothing when
//     overrideExisting is false and the key already holds a value.
//   - getUrl(component) returns the full URL when component is omitted and
//     only accepts lowercase components.
//
// Usage: node tests/run.mjs
import { readFileSync } from 'node:fs';
import { isDeepStrictEqual, inspect } from 'node:util';

const root = new URL('../', import.meta.url);
const read = (name) => readFileSync(new URL(name, root), 'utf8');

const js = read('template.js');
const tpl = read('template.tpl');
const yaml = read('tests.yaml');

function section(name) {
  const m = tpl.match(new RegExp('___' + name + '___\\n([\\s\\S]*?)\\n___[A-Z_]+___'));
  if (!m) throw new Error('template.tpl has no ___' + name + '___ section');
  return m[1].trim();
}

let failures = 0;
function check(label, ok, detail) {
  console.log((ok ? 'ok   ' : 'FAIL ') + label + (ok || !detail ? '' : '\n     ' + detail));
  if (!ok) failures++;
}

check('template.js matches template.tpl code section',
  section('SANDBOXED_JS_FOR_WEB_TEMPLATE') === js.trim());
check('tests.yaml matches template.tpl ___TESTS___ section',
  section('TESTS') === yaml.replace(/^#.*\n/gm, '').trim());

// Minimal parser for the fixed layout: "- name:" + "code: |-" scenarios and a
// top-level "setup: |-" block that GTM runs before every scenario.
function parseScenarios(text) {
  const scenarios = [];
  const setup = { code: [], indent: 2 };
  let current = null;
  for (const line of text.split('\n')) {
    const name = line.match(/^- name: (.*)$/);
    if (name) {
      current = { name: name[1], code: [], indent: 4 };
      scenarios.push(current);
    } else if (line === 'setup: |-') {
      current = setup;
    } else if (current && line !== '  code: |-') {
      current.code.push(line.slice(current.indent));
    }
  }
  return scenarios.map((s) => ({
    name: s.name,
    code: setup.code.join('\n') + '\n' + s.code.join('\n')
  }));
}

const URL_PARTS = ['protocol', 'host', 'port', 'path', 'query', 'extension', 'fragment'];
const PAGE_URL = 'https://example.com/page?utm_source=test#top';

function defaultApis() {
  const win = {};
  const copy = (v) => (v === undefined ? undefined : JSON.parse(JSON.stringify(v)));
  return {
    createQueue: (key) => {
      win[key] = win[key] || [];
      return (value) => win[key].push(copy(value));
    },
    copyFromWindow: (key) => copy(win[key]),
    setInWindow: (key, value, overrideExisting) => {
      if (!overrideExisting && win[key] !== undefined) return false;
      win[key] = copy(value);
      return true;
    },
    getUrl: (component) => {
      const u = new URL(PAGE_URL);
      if (component === undefined) return u.href;
      if (URL_PARTS.indexOf(component) < 0) return undefined;
      return {
        protocol: u.protocol.replace(':', ''), host: u.hostname, port: u.port,
        path: u.pathname, query: u.search.slice(1),
        extension: (u.pathname.match(/\.([^./]+)$/) || [])[1] || '',
        fragment: u.hash.slice(1)
      }[component];
    },
    makeTableMap: (rows, keyCol, valueCol) => {
      const out = {};
      rows.forEach((r) => { out[r[keyCol]] = r[valueCol]; });
      return out;
    },
    logToConsole: () => {},
    JSON: JSON
  };
}

function runScenario(scenario) {
  const apis = defaultApis();
  const mocks = {};
  const requireApi = (name) => {
    if (name in mocks) return mocks[name];
    if (!(name in apis)) throw new Error('unmocked sandbox API: ' + name);
    return apis[name];
  };
  const mock = (name, value) => {
    mocks[name] = typeof value === 'function' ? value : () => value;
  };
  const runCode = (data) => {
    const d = Object.assign({ gtmOnSuccess: () => {}, gtmOnFailure: () => {} }, data);
    new Function('require', 'data', js)(requireApi, d);
  };
  const assertThat = (actual) => ({
    isEqualTo(expected) {
      if (!isDeepStrictEqual(actual, expected)) {
        throw new Error('expected ' + inspect(expected) + ' but got ' + inspect(actual));
      }
    }
  });
  new Function('mock', 'runCode', 'assertThat', 'require', scenario.code)(
    mock, runCode, assertThat, requireApi);
}

for (const scenario of parseScenarios(yaml)) {
  try {
    runScenario(scenario);
    check('scenario: ' + scenario.name, true);
  } catch (e) {
    check('scenario: ' + scenario.name, false, e.message);
  }
}

console.log(failures ? failures + ' failure(s)' : 'all checks passed');
process.exit(failures ? 1 : 0);
