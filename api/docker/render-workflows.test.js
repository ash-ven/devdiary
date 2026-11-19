const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { runtimeValues, renderText } = require('./render-workflows');
const { buildWorkflow } = require('../scripts/build-workflow');

const GOOD_TOKEN = 'Abc123-_.~+/='.padEnd(40, 'x');
const env = (over = {}) => ({ RESET_TOKEN: GOOD_TOKEN, DEMO_MODE: 'false', ALLOWED_ORIGINS: '*', ...over });

test('rejects unsafe reset tokens', () => {
  for (const token of ["x'+process.exit()+'".padEnd(40, 'x'), 'a'.repeat(31), 'abc\\def'.padEnd(40, 'x'), 'line\nbreak'.padEnd(40, 'x'), 'con spazio'.padEnd(40, 'x'), '']) {
    assert.throws(() => runtimeValues(env({ RESET_TOKEN: token })), /RESET_TOKEN/, JSON.stringify(token));
  }
  assert.throws(() => runtimeValues({ DEMO_MODE: 'false' }), /RESET_TOKEN/);
});

test('accepts a strong token', () => {
  assert.equal(runtimeValues(env()).__RESET_TOKEN__, GOOD_TOKEN);
});

test('rejects anything but true or false for DEMO_MODE', () => {
  for (const mode of ['True', '1', 'yes', 'TRUE', ' true']) assert.throws(() => runtimeValues(env({ DEMO_MODE: mode })), /DEMO_MODE/, mode);
  assert.equal(runtimeValues(env({ DEMO_MODE: 'true' })).__DEMO_MODE__, 'true');
  assert.equal(runtimeValues(env({ DEMO_MODE: undefined })).__DEMO_MODE__, 'false');
  assert.equal(runtimeValues(env({ DEMO_MODE: '' })).__DEMO_MODE__, 'false');
});

test('rejects invalid allowed origins', () => {
  for (const origins of ["https://a.example'", 'javascript:alert(1)', 'https://a.example, "x"', 'ftp://a.example']) {
    assert.throws(() => runtimeValues(env({ ALLOWED_ORIGINS: origins })), /ALLOWED_ORIGINS/, origins);
  }
  assert.equal(runtimeValues(env({ ALLOWED_ORIGINS: 'https://a.example,https://b.example:8443' })).__ALLOWED_ORIGINS__, 'https://a.example,https://b.example:8443');
  assert.equal(runtimeValues(env({ ALLOWED_ORIGINS: undefined })).__ALLOWED_ORIGINS__, '*');
});

test('rendered workflows are valid JSON and every code node compiles', () => {
  const root = path.resolve(__dirname, '..');
  const lib = fs.readFileSync(path.join(root, 'code', 'lib.js'), 'utf8');
  const seed = JSON.parse(fs.readFileSync(path.join(root, 'seed', 'entries.json'), 'utf8'));
  const values = runtimeValues(env({ DEMO_MODE: 'true' }));
  for (const file of fs.readdirSync(path.join(root, 'workflows')).filter((f) => f.endsWith('.template.json'))) {
    const built = JSON.stringify(buildWorkflow(JSON.parse(fs.readFileSync(path.join(root, 'workflows', file), 'utf8')), lib, seed));
    const rendered = JSON.parse(renderText(built, values));
    assert.equal(JSON.stringify(rendered).includes('__RESET_TOKEN__'), false, file);
    for (const node of rendered.nodes.filter((n) => n.type === 'n8n-nodes-base.code')) {
      assert.doesNotThrow(() => new Function('$json', '$input', '$', node.parameters.jsCode), `${file} ${node.name}`);
      assert.ok(node.parameters.jsCode.includes(`'${GOOD_TOKEN}'`), `${file} ${node.name}: token inserito`);
    }
  }
});
