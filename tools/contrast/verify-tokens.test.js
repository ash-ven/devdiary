const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const script = path.join(__dirname, 'verify-tokens.js');
const tokens = JSON.parse(fs.readFileSync(path.join(__dirname, 'tokens.json'), 'utf8'));

test('the final palette passes every check', () => {
  const r = spawnSync(process.execPath, [script], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stdout + r.stderr);
});

test('a weaker grey fails with the name of the pair', () => {
  const weak = JSON.parse(JSON.stringify(tokens));
  weak.light.ink3 = '#9AA0B5';
  const file = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'tokens-')), 'tokens.json');
  fs.writeFileSync(file, JSON.stringify(weak));
  const r = spawnSync(process.execPath, [script, file], { encoding: 'utf8' });
  assert.equal(r.status, 1);
  assert.match(r.stdout + r.stderr, /Date e conteggi sul foglio/);
});
