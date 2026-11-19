// Verifica WCAG 2.1 AA (1.4.3 testo, 1.4.11 componenti e grafica) per le palette di DevDiary.
// Uso: node check.js  -> stampa il riepilogo e scrive results.json
const fs = require('fs');
const path = require('path');
const palettes = require('./palettes.js');

// ---------- colore ----------
function parse(c) {
  c = c.trim();
  if (c.startsWith('#')) {
    const h = c.slice(1);
    return { r: parseInt(h.slice(0, 2), 16), g: parseInt(h.slice(2, 4), 16), b: parseInt(h.slice(4, 6), 16), a: 1 };
  }
  const m = c.match(/rgba?\(([^)]+)\)/);
  const [r, g, b, a = 1] = m[1].split(',').map(Number);
  return { r, g, b, a };
}
const toHex = ({ r, g, b }) => '#' + [r, g, b].map(v => Math.round(v).toString(16).padStart(2, '0')).join('').toUpperCase();
// composizione come nel browser (spazio sRGB)
function over(fg, bg) {
  const f = parse(fg), b = parse(bg);
  return toHex({ r: f.r * f.a + b.r * (1 - f.a), g: f.g * f.a + b.g * (1 - f.a), b: f.b * f.a + b.b * (1 - f.a) });
}
function lum(hex) {
  const { r, g, b } = parse(hex);
  const ch = v => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
  return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b);
}
function ratio(a, b) {
  const [l1, l2] = [lum(a), lum(b)].sort((x, y) => y - x);
  return (l1 + 0.05) / (l2 + 0.05);
}
// HSL per regolare solo la luminosità, mantenendo tinta e saturazione
function toHsl(hex) {
  let { r, g, b } = parse(hex); r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b); let h, s; const l = (max + min) / 2;
  if (max === min) { h = s = 0; } else {
    const d = max - min; s = l > .5 ? d / (2 - max - min) : d / (max + min);
    h = max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4; h /= 6;
  }
  return { h, s, l };
}
function fromHsl({ h, s, l }) {
  const hue = (p, q, t) => { if (t < 0) t += 1; if (t > 1) t -= 1; if (t < 1 / 6) return p + (q - p) * 6 * t; if (t < 1 / 2) return q; if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6; return p; };
  let r, g, b; if (s === 0) { r = g = b = l; } else {
    const q = l < .5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
    r = hue(p, q, h + 1 / 3); g = hue(p, q, h); b = hue(p, q, h - 1 / 3);
  }
  return toHex({ r: r * 255, g: g * 255, b: b * 255 });
}
// sposta "move" (fg o bg) lontano dall'altro colore finché il rapporto raggiunge target
function nudge(move, other, target) {
  const hsl = toHsl(move);
  const darker = lum(other) > lum(move) || (lum(other) > 0.18 && lum(move) >= lum(other) && false);
  const dir = lum(move) <= lum(other) ? -1 : 1; // allontana in luminosità
  let cur = move;
  for (let i = 0; i < 100 && ratio(cur, other) < target; i++) {
    hsl.l = Math.min(1, Math.max(0, hsl.l + dir * 0.005));
    cur = fromHsl(hsl);
  }
  return cur;
}

// ---------- controlli ----------
const TYPES = ['note', 'snippet', 'idea', 'errore', 'link'];
const TYPE_LABEL = { note: 'appunto', snippet: 'snippet', idea: 'idea', errore: 'errore', link: 'link' };
const CODE = [['code_plain', 'testo'], ['code_kw', 'parole chiave'], ['code_str', 'stringhe'], ['code_fn', 'funzioni'], ['code_num', 'numeri'], ['code_comment', 'commenti'], ['code_lineNo', 'numeri di riga'], ['code_bar', 'barra del blocco']];

function checks(t) {
  const list = [];
  const txt = (label, fg, bg, fix = 'fg') => list.push({ kind: 'testo', crit: '1.4.3', req: 4.5, label, fg, bg, fix });
  const ui = (label, fg, bg, fix = 'fg') => list.push({ kind: 'grafica', crit: '1.4.11', req: 3, label, fg, bg, fix });
  txt('Testo principale sul fondo', 'ink', 'paper'); txt('Testo principale sul foglio', 'ink', 'sheet');
  txt('Testo secondario sul fondo', 'ink2', 'paper'); txt('Testo secondario sul foglio', 'ink2', 'sheet');
  txt('Date e conteggi sul fondo', 'ink3', 'paper'); txt('Date e conteggi sul foglio', 'ink3', 'sheet');
  txt('Link e filtro attivo sul fondo', 'primary', 'paper'); txt('Link e filtro attivo sul foglio', 'primary', 'sheet');
  txt('Etichetta del pulsante principale', 'onPrimary', 'primary', 'bg');
  txt('Testo di errore e "Elimina"', 'accentText', 'sheet');
  for (const ty of TYPES) list.push({ kind: 'testo', crit: '1.4.3', req: 4.5, label: `Etichetta "${TYPE_LABEL[ty]}"`, fg: `markTx_${ty}`, bg: `@mark_${ty}`, fix: 'fg' });
  for (const [k, l] of CODE) txt(`Codice: ${l}`, k, 'codeBg');
  ui('Bordo dei campi sul fondo', 'ruleStrong', 'paper'); ui('Bordo dei campi sul foglio', 'ruleStrong', 'sheet');
  ui('Anello di focus sul fondo', 'focus', 'paper'); ui('Anello di focus sul foglio', 'focus', 'sheet');
  ui('Stella preferiti e margine', 'accent', 'sheet');
  ui('Pallino "API online"', 'ok', 'paper');
  for (const ty of TYPES) ui(`Grafici: colore pieno "${TYPE_LABEL[ty]}"`, `strong_${ty}`, 'sheet');
  return list;
}
const resolve = (t, key) => key.startsWith('@mark_') ? over(t['markBg_' + key.slice(6)], t.sheet) : t[key];

function run(tokens, autofix) {
  const t = { ...tokens };
  const changed = {};
  for (let pass = 0; pass < 6; pass++) {
    let fixedSomething = false;
    for (const c of checks(t)) {
      const fg = resolve(t, c.fg), bg = resolve(t, c.bg);
      if (ratio(fg, bg) >= c.req) continue;
      if (!autofix) continue;
      const key = c.fix === 'fg' ? c.fg : c.bg;
      if (key.startsWith('@')) continue;
      const before = t[key];
      t[key] = c.fix === 'fg' ? nudge(fg, bg, c.req + 0.05) : nudge(bg, fg, c.req + 0.05);
      if (!changed[key]) changed[key] = before;
      fixedSomething = true;
    }
    if (!fixedSomething) break;
  }
  const rows = checks(t).map(c => {
    const fg = resolve(t, c.fg), bg = resolve(t, c.bg);
    const r = ratio(fg, bg);
    const orig = checks(tokens).find(x => x.label === c.label);
    const r0 = ratio(resolve(tokens, orig.fg), resolve(tokens, orig.bg));
    return { ...c, fgHex: fg, bgHex: bg, ratio: +r.toFixed(2), before: +r0.toFixed(2), pass: r >= c.req, aaa: c.kind === 'testo' ? r >= 7 : null };
  });
  return { tokens: t, changed, rows };
}

const out = {};
for (const [id, p] of Object.entries(palettes)) {
  out[id] = { name: p.name, checkOnly: !!p.checkOnly, themes: {} };
  for (const theme of ['light', 'dark']) {
    if (!p[theme]) continue;
    out[id].themes[theme] = run(p[theme], !p.checkOnly);
  }
}
fs.writeFileSync(path.join(__dirname, 'results.json'), JSON.stringify(out, null, 2));

for (const [id, p] of Object.entries(out)) {
  for (const [theme, r] of Object.entries(p.themes)) {
    const failsBefore = r.rows.filter(x => x.before < x.req).length;
    const failsAfter = r.rows.filter(x => !x.pass).length;
    console.log(`\n== ${p.name} / ${theme}: ${r.rows.length} controlli, falliti all'inizio ${failsBefore}, dopo le correzioni ${failsAfter}`);
    for (const x of r.rows.filter(x => x.before < x.req || !x.pass))
      console.log(`  ${x.pass ? 'OK ' : 'NO '} ${x.label.padEnd(36)} ${String(x.before).padStart(5)} -> ${String(x.ratio).padStart(5)} (min ${x.req})  ${x.fgHex} su ${x.bgHex}`);
    for (const [k, v] of Object.entries(r.changed)) console.log(`     corretto ${k}: ${v} -> ${r.tokens[k]}`);
  }
}
