// Verifica WCAG 2.1 AA dei token di colore finali (tema chiaro e scuro), senza correggerli.
// Uso: node tools/contrast/verify-tokens.js [tokens.json]  → codice 1 se una coppia non passa.
const fs = require('node:fs');
const path = require('node:path');
const { checks, resolve, ratio } = require('./check.js');

const file = process.argv[2] || path.join(__dirname, 'tokens.json');
const palette = JSON.parse(fs.readFileSync(file, 'utf8'));

let failures = 0;
let total = 0;
for (const theme of ['light', 'dark']) {
  const tokens = palette[theme];
  for (const c of checks(tokens)) {
    total += 1;
    const fg = resolve(tokens, c.fg);
    const bg = resolve(tokens, c.bg);
    const r = ratio(fg, bg);
    if (r < c.req) {
      failures += 1;
      console.log(`NON PASSA [${theme === 'light' ? 'chiaro' : 'scuro'}] ${c.label}: ${r.toFixed(2)}:1 (minimo ${c.req}:1) ${fg} su ${bg}`);
    }
  }
}

console.log(`${palette.name || 'Palette'}: ${total - failures}/${total} coppie conformi a WCAG 2.1 AA`);
process.exit(failures ? 1 : 0);
