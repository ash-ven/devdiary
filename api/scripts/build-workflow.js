// Build provvisorio (Task 3): copia i template in workflows/dist senza trasformarli.
// Il Task 6 lo sostituisce con la versione che inietta lib.js e il seed.
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const src = path.join(root, 'workflows');
const out = path.join(src, 'dist');
fs.mkdirSync(out, { recursive: true });
for (const file of fs.readdirSync(src).filter((f) => f.endsWith('.template.json'))) {
  const name = file.replace('.template.json', '.json');
  fs.copyFileSync(path.join(src, file), path.join(out, name));
  console.log(`workflow: ${name}`);
}
