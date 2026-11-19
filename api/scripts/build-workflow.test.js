const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { buildWorkflow } = require('./build-workflow');
const lib = require('../code/lib');

const root = path.resolve(__dirname, '..');
const libSource = fs.readFileSync(path.join(root, 'code', 'lib.js'), 'utf8');
const templates = fs.readdirSync(path.join(root, 'workflows'))
  .filter((f) => f.endsWith('.template.json'))
  .map((f) => ({ file: f, template: JSON.parse(fs.readFileSync(path.join(root, 'workflows', f), 'utf8')) }));

const codeNodes = (wf) => wf.nodes.filter((n) => n.type === 'n8n-nodes-base.code');

for (const { file, template } of templates) {
  const built = buildWorkflow(template, libSource, [{ title: 'Seed', content: 'x', type: 'note', tags: [], isFavorite: false, daysAgo: 0, time: '09:00' }]);
  const text = JSON.stringify(built);

  test(`${file}: build replaces every code placeholder`, () => {
    assert.equal(text.includes('@@lib:'), false);
  });

  test(`${file}: every code node names an existing entry function`, () => {
    for (const node of codeNodes(template)) {
      const m = /^@@lib:(\w+)@@$/.exec(node.parameters.jsCode);
      assert.ok(m, `${node.name}: jsCode deve essere @@lib:<funzione>@@`);
      assert.equal(typeof lib.ENTRY[m[1]], 'function', `${node.name}: funzione ${m[1]} inesistente`);
    }
  });

  test(`${file}: built code nodes compile`, () => {
    for (const node of codeNodes(built)) {
      assert.doesNotThrow(() => new Function('$json', '$input', '$', node.parameters.jsCode), node.name);
    }
  });

  test(`${file}: every mongo node uses the shared credential`, () => {
    for (const node of built.nodes.filter((n) => n.type === 'n8n-nodes-base.mongoDb')) {
      assert.equal(node.credentials.mongoDb.id, 'DevDiaryMongo001', node.name);
    }
  });

  test(`${file}: runtime placeholders survive the build`, () => {
    assert.ok(text.includes('__DEMO_MODE__'));
    assert.ok(text.includes('__RESET_TOKEN__'));
    if (built.nodes.some((n) => n.type === 'n8n-nodes-base.webhook')) assert.ok(text.includes('__ALLOWED_ORIGINS__'));
  });

  test(`${file}: every connection points to an existing node`, () => {
    const names = new Set(built.nodes.map((n) => n.name));
    for (const [from, outputs] of Object.entries(built.connections)) {
      assert.ok(names.has(from), `sorgente ${from}`);
      for (const branch of outputs.main) for (const c of branch || []) assert.ok(names.has(c.node), `${from} → ${c.node}`);
    }
  });
}

test('the main workflow keeps the course webhook paths', () => {
  const main = templates.find((t) => t.file === 'devdiary-api.template.json').template;
  const hooks = main.nodes.filter((n) => n.type === 'n8n-nodes-base.webhook').map((n) => `${n.parameters.httpMethod || 'GET'} ${n.parameters.path}`).sort();
  assert.deepEqual(hooks, [
    'DELETE diary', 'GET diary', 'GET diary/detail', 'GET diary/export/json', 'GET diary/export/markdown',
    'GET status', 'POST diary', 'POST diary/restore', 'PUT diary',
  ]);
});
