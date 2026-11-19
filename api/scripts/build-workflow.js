// Build dei workflow n8n: ogni nodo Code con jsCode "@@lib:<funzione>@@" riceve il contenuto di
// code/lib.js (con CONFIG legato ai segnaposto di runtime e al seed) e la chiamata al dispatcher.
// Uso: node scripts/build-workflow.js  → scrive workflows/dist/<nome>.json
const fs = require('node:fs');
const path = require('node:path');

const CONFIG_LINE = "const CONFIG = { demoMode: false, resetToken: '', seed: [] };";
const PLACEHOLDER = /^@@lib:(\w+)@@$/;

function libWithConfig(libSource, seed) {
  if (!libSource.includes(CONFIG_LINE)) throw new Error('lib.js: riga CONFIG non trovata');
  const config = `const CONFIG = { demoMode: '__DEMO_MODE__' === 'true', resetToken: '__RESET_TOKEN__', seed: ${JSON.stringify(seed || [])} };`;
  return libSource.replace(CONFIG_LINE, config);
}

function buildWorkflow(template, libSource, seed) {
  const source = libWithConfig(libSource, seed);
  const workflow = JSON.parse(JSON.stringify(template));
  for (const node of workflow.nodes) {
    if (node.type !== 'n8n-nodes-base.code') continue;
    const m = PLACEHOLDER.exec(node.parameters.jsCode || '');
    if (!m) throw new Error(`${node.name}: jsCode deve essere @@lib:<funzione>@@`);
    node.parameters.jsCode = `${source}\nreturn run('${m[1]}', { json: $input.first().json, items: $input.all().map((i) => i.json), ref: (n) => $(n).first().json, config: CONFIG });\n`;
  }
  return workflow;
}

function main() {
  const root = path.resolve(__dirname, '..');
  const libSource = fs.readFileSync(path.join(root, 'code', 'lib.js'), 'utf8');
  const seedFile = path.join(root, 'seed', 'entries.json');
  const seed = fs.existsSync(seedFile) ? JSON.parse(fs.readFileSync(seedFile, 'utf8')) : [];
  const src = path.join(root, 'workflows');
  const out = path.join(src, 'dist');
  fs.mkdirSync(out, { recursive: true });
  for (const file of fs.readdirSync(src).filter((f) => f.endsWith('.template.json'))) {
    const template = JSON.parse(fs.readFileSync(path.join(src, file), 'utf8'));
    const name = file.replace('.template.json', '.json');
    fs.writeFileSync(path.join(out, name), JSON.stringify(buildWorkflow(template, libSource, seed), null, 2));
    console.log(`workflow: ${name}`);
  }
}

if (require.main === module) main();

module.exports = { buildWorkflow, libWithConfig };
