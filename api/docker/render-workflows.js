// Sostituisce i segnaposto di runtime nei workflow compilati.
// Uso: node render-workflows.js <cartella dist> <cartella di uscita>
const fs = require('node:fs');
const path = require('node:path');

const [srcDir, outDir] = process.argv.slice(2);
if (!srcDir || !outDir) {
  console.error('uso: node render-workflows.js <dist> <uscita>');
  process.exit(2);
}

// I segnaposto stanno dentro stringhe JSON: i valori vanno inseriti già escapati.
const escape = (value) => JSON.stringify(String(value)).slice(1, -1);
const values = {
  __DEMO_MODE__: process.env.DEMO_MODE === 'true' ? 'true' : 'false',
  __RESET_TOKEN__: process.env.RESET_TOKEN || '',
  __ALLOWED_ORIGINS__: process.env.ALLOWED_ORIGINS || '*',
};

fs.mkdirSync(outDir, { recursive: true });
for (const file of fs.readdirSync(srcDir).filter((f) => f.endsWith('.json'))) {
  let text = fs.readFileSync(path.join(srcDir, file), 'utf8');
  for (const [placeholder, value] of Object.entries(values)) text = text.split(placeholder).join(escape(value));
  JSON.parse(text); // il risultato deve restare JSON valido
  fs.writeFileSync(path.join(outDir, file), text);
}
