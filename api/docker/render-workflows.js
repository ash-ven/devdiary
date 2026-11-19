// Sostituisce i segnaposto di runtime nei workflow compilati, dopo averne validato i valori.
// Uso: node render-workflows.js <cartella dist> <cartella di uscita>
const fs = require('node:fs');
const path = require('node:path');

// Il token finisce dentro una stringa JavaScript di ogni nodo Code: si accettano solo caratteri sicuri.
const TOKEN_RE = /^[A-Za-z0-9._~+/=-]{32,}$/;
const ORIGIN_RE = /^https?:\/\/[A-Za-z0-9.-]+(:\d{1,5})?$/;

function runtimeValues(env) {
  const mode = env.DEMO_MODE === undefined || env.DEMO_MODE === '' ? 'false' : env.DEMO_MODE;
  if (mode !== 'true' && mode !== 'false') {
    throw new Error(`DEMO_MODE deve essere "true" o "false" (ricevuto ${JSON.stringify(env.DEMO_MODE)})`);
  }
  const token = env.RESET_TOKEN || '';
  if (!TOKEN_RE.test(token)) {
    throw new Error('RESET_TOKEN deve avere almeno 32 caratteri tra lettere, cifre e . _ ~ + / = -');
  }
  const origins = env.ALLOWED_ORIGINS === undefined || env.ALLOWED_ORIGINS === '' ? '*' : env.ALLOWED_ORIGINS;
  const list = origins.split(',').map((s) => s.trim());
  if (!list.every((o) => o === '*' || ORIGIN_RE.test(o))) {
    throw new Error(`ALLOWED_ORIGINS deve essere "*" o un elenco di origini http(s) separate da virgola (ricevuto ${JSON.stringify(origins)})`);
  }
  return { __DEMO_MODE__: mode, __RESET_TOKEN__: token, __ALLOWED_ORIGINS__: list.join(',') };
}

// I segnaposto stanno dentro stringhe JSON: i valori, già validati, vanno inseriti escapati.
function renderText(text, values) {
  const escape = (value) => JSON.stringify(String(value)).slice(1, -1);
  let out = text;
  for (const [placeholder, value] of Object.entries(values)) out = out.split(placeholder).join(escape(value));
  return out;
}

function main() {
  const [srcDir, outDir] = process.argv.slice(2);
  if (!srcDir || !outDir) {
    console.error('uso: node render-workflows.js <dist> <uscita>');
    process.exit(2);
  }
  let values;
  try {
    values = runtimeValues(process.env);
  } catch (err) {
    console.error(`DevDiary API: configurazione non valida. ${err.message}`);
    process.exit(1);
  }
  console.log(`DevDiary API: DEMO_MODE=${values.__DEMO_MODE__}, origini consentite: ${values.__ALLOWED_ORIGINS__}`);
  fs.mkdirSync(outDir, { recursive: true });
  for (const file of fs.readdirSync(srcDir).filter((f) => f.endsWith('.json'))) {
    const text = renderText(fs.readFileSync(path.join(srcDir, file), 'utf8'), values);
    JSON.parse(text); // il risultato deve restare JSON valido
    fs.writeFileSync(path.join(outDir, file), text);
  }
}

if (require.main === module) main();

module.exports = { runtimeValues, renderText };
