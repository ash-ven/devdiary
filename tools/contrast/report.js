// Genera la pagina di confronto (frammento per il visualizzatore) da results.json
const fs = require('fs');
const path = require('path');
const R = JSON.parse(fs.readFileSync(path.join(__dirname, 'results.json'), 'utf8'));
const OUT = process.argv[2];
const fmt = n => n.toFixed(2).replace('.', ',');

const MARK_LABEL = { note: 'Appunto', snippet: 'Snippet', idea: 'Idea', errore: 'Errore risolto', link: 'Link' };

function preview(t, theme) {
  const v = Object.entries(t).map(([k, val]) => `--${k}:${val}`).join(';');
  return `<div class="pv pv-${theme}" style="${v}">
    <div class="pv-top"><span class="logo-dot"></span><b>DevDiary</b><span class="pv-field">Cerca nel diario</span></div>
    <div class="pv-sheet">
      <div class="pv-meta"><span class="mk" style="background:var(--markBg_errore);color:var(--markTx_errore)">Errore risolto</span><span class="ink3">oggi alle 09:34</span><span class="star">★</span></div>
      <div class="pv-h">Workflow non pubblicato</div>
      <p class="ink2">La Production URL risponde solo con il workflow attivo. <a>Apri la guida</a></p>
      <div class="pv-code"><span class="ln">1</span><span class="cm">// controllo dello stato</span><br><span class="ln">2</span><span class="kw">final</span> <span class="pl">res =</span> <span class="kw">await</span> <span class="fn">get</span>(<span class="st">'/status'</span>, <span class="nu">200</span>);</div>
      <div class="pv-row"><span class="btn">Salva nota</span><span class="btn-focus">Annulla</span><span class="danger">Sposta nel cestino</span></div>
      <div class="pv-marks">${['note', 'snippet', 'idea', 'errore', 'link'].map(ty => `<span class="mk" style="background:var(--markBg_${ty});color:var(--markTx_${ty})">${MARK_LABEL[ty]}</span>`).join('')}</div>
      <div class="pv-chart">${['note', 'snippet', 'idea', 'errore', 'link'].map((ty, i) => `<span style="flex:${[12, 17, 6, 9, 4][i]};background:var(--strong_${ty})"></span>`).join('')}</div>
    </div>
  </div>`;
}

function changes(p) {
  const items = [];
  for (const [theme, r] of Object.entries(p.themes)) {
    for (const [k, before] of Object.entries(r.changed)) {
      items.push(`<li><span class="chip" style="background:${before}"></span><span class="chip" style="background:${r.tokens[k]}"></span>${({ ruleStrong: 'Bordo dei campi', code_lineNo: 'Numeri di riga del codice', strong_idea: 'Giallo "idea" nei grafici' })[k] || k} <span class="th">${theme === 'light' ? 'chiaro' : 'scuro'}</span> <code>${before} → ${r.tokens[k]}</code></li>`);
    }
  }
  return items.join('');
}

function table(p) {
  return Object.entries(p.themes).map(([theme, r]) => `
    <details><summary>Tutti i ${r.rows.length} controlli, tema ${theme === 'light' ? 'chiaro' : 'scuro'}</summary>
    <table><thead><tr><th>Elemento</th><th>Colori</th><th>Contrasto</th><th>Minimo</th><th></th></tr></thead><tbody>
    ${r.rows.map(x => `<tr><td>${x.label}</td><td><span class="chip" style="background:${x.fgHex}"></span><span class="chip" style="background:${x.bgHex}"></span></td><td>${fmt(x.ratio)}:1${x.before < x.req ? ` <s>${fmt(x.before)}</s>` : ''}</td><td>${fmt(x.req)}:1</td><td>${x.pass ? (x.aaa ? 'AA, anche AAA' : 'AA') : 'non passa'}</td></tr>`).join('')}
    </tbody></table></details>`).join('');
}

const minText = p => Math.min(...Object.values(p.themes).flatMap(r => r.rows.filter(x => x.kind === 'testo').map(x => x.ratio)));
const bodyRatio = (p, theme) => p.themes[theme].rows.find(x => x.label === 'Testo principale sul foglio').ratio;

const cards = ['matita', 'ottanio', 'lavagna'].map(id => {
  const p = R[id];
  const L = p.themes.light.tokens, D = p.themes.dark.tokens;
  return `<div class="card" data-choice="${id}" onclick="toggleSelect(this)">
    <div class="card-image">
      <div class="duo">${preview(L, 'light')}${preview(D, 'dark')}</div>
      <div class="sw">${[['Fondo', L.paper], ['Foglio', L.sheet], ['Inchiostro', L.ink], ['Principale', L.primary], ['Rosa', L.accent], ['Viola', L.strong_note === '#6F35D8' ? '#6F35D8' : L.strong_link], ['Notte', D.paper]].map(([n, c]) => `<div><b style="background:${c}"></b>${n}<span>${c}</span></div>`).join('')}</div>
    </div>
    <div class="card-body">
      <h3>${p.name}</h3>
      <p class="res">Passa tutti i controlli AA in chiaro e in scuro. Testo principale ${fmt(bodyRatio(p, 'light'))}:1 in chiaro e ${fmt(bodyRatio(p, 'dark'))}:1 in scuro; il testo più debole arriva a ${fmt(minText(p))}:1.</p>
      <p class="fixh">Colori corretti per arrivare alla soglia:</p>
      <ul class="fix">${changes(p)}</ul>
      ${table(p)}
    </div>
  </div>`;
}).join('');

const m1 = R.mockup1.themes.light.rows.filter(x => !x.pass);

const html = `<link href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,400;12..96,600;12..96,800&family=JetBrains+Mono:wght@400&display=swap" rel="stylesheet">
<style>
  .intro { max-width: 78ch; }
  .intro p { margin: 0 0 .6rem; }
  .cards { grid-template-columns: repeat(auto-fit, minmax(380px, 1fr)); }
  .cards .card-image { display: block; aspect-ratio: auto; padding: 12px; background: #E9ECF2; color: #1B1F4B; }
  .duo { display: grid; grid-template-columns: 1fr; gap: 8px; }
  .pv { font-family: "Bricolage Grotesque", system-ui, sans-serif; border-radius: 10px; padding: 12px; color: var(--ink); background: var(--paper);
        background-image: linear-gradient(color-mix(in srgb, var(--ink) 6%, transparent) 1px, transparent 1px), linear-gradient(90deg, color-mix(in srgb, var(--ink) 6%, transparent) 1px, transparent 1px); background-size: 18px 18px; }
  .pv-top { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; font-size: 15px; }
  .pv-top b { font-weight: 800; letter-spacing: -.02em; }
  .logo-dot { width: 16px; height: 16px; border-radius: 4px; background: var(--primary); box-shadow: 4px 4px 0 -1px var(--accent); }
  .pv-field { margin-left: auto; font-size: 12px; color: var(--ink3); background: var(--sheet); border: 1px solid var(--ruleStrong); border-radius: 7px; padding: 3px 9px; }
  .pv-sheet { position: relative; background: var(--sheet); border-radius: 9px; padding: 10px 12px 10px 26px; }
  .pv-sheet::before { content: ""; position: absolute; left: 13px; top: 0; bottom: 0; width: 2px; background: var(--accent); }
  .pv-meta { display: flex; align-items: center; gap: 8px; font-size: 12px; }
  .pv-meta .star { margin-left: auto; color: var(--accent); font-size: 15px; }
  .ink3 { color: var(--ink3); } .ink2 { color: var(--ink2); }
  .pv-h { font-size: 19px; font-weight: 800; letter-spacing: -.03em; margin: 5px 0 2px; }
  .pv p { margin: 0 0 7px; font-size: 13px; line-height: 1.45; }
  .pv a { color: var(--primary); text-decoration: underline; text-underline-offset: 2px; }
  .mk { font-size: 11px; font-weight: 700; padding: 0 .45em; line-height: 1.65; border-radius: 3px 7px 4px 8px / 7px 3px 8px 4px; }
  .pv-code { font-family: "JetBrains Mono", monospace; font-size: 11px; line-height: 1.6; background: var(--codeBg); color: var(--code_plain); border-radius: 7px; padding: 6px 9px; margin-bottom: 8px; white-space: nowrap; overflow: hidden; }
  .pv-code .ln { color: var(--code_lineNo); display: inline-block; width: 14px; } .pv-code .cm { color: var(--code_comment); font-style: italic; }
  .pv-code .kw { color: var(--code_kw); } .pv-code .fn { color: var(--code_fn); } .pv-code .st { color: var(--code_str); } .pv-code .nu { color: var(--code_num); } .pv-code .pl { color: var(--code_plain); }
  .pv-row { display: flex; gap: 6px; align-items: center; font-size: 12px; font-weight: 700; margin-bottom: 8px; }
  .btn { background: var(--primary); color: var(--onPrimary); border-radius: 7px; padding: 4px 10px; }
  .btn-focus { border-radius: 7px; padding: 3px 9px; border: 1px solid var(--ruleStrong); outline: 2px solid var(--focus); outline-offset: 2px; }
  .danger { color: var(--accentText); margin-left: auto; }
  .pv-marks { display: flex; gap: 4px; flex-wrap: wrap; margin-bottom: 8px; }
  .pv-chart { display: flex; gap: 2px; height: 10px; border-radius: 4px; overflow: hidden; }
  .sw { display: grid; grid-template-columns: repeat(7, 1fr); gap: 4px; margin-top: 10px; font-size: 10.5px; line-height: 1.3; }
  .sw b { display: block; height: 24px; border-radius: 5px; margin-bottom: 2px; box-shadow: inset 0 0 0 1px rgba(0,0,0,.1); }
  .sw span { display: block; font-family: "JetBrains Mono", monospace; opacity: .7; }
  .res { color: var(--text-primary) !important; }
  .fixh { margin: .6rem 0 .2rem !important; }
  .fix { margin: 0 0 .6rem; padding: 0; list-style: none; font-size: .82rem; color: var(--text-secondary); }
  .fix li { display: flex; align-items: center; gap: 4px; margin: 2px 0; flex-wrap: wrap; }
  .fix code { font-size: .78rem; } .fix .th { opacity: .7; }
  .chip { display: inline-block; width: 13px; height: 13px; border-radius: 3px; box-shadow: inset 0 0 0 1px rgba(255,255,255,.25); vertical-align: middle; margin-right: 2px; }
  details { margin-top: .4rem; font-size: .8rem; color: var(--text-secondary); }
  summary { cursor: pointer; }
  table { width: 100%; border-collapse: collapse; margin-top: .4rem; }
  td, th { text-align: left; padding: 3px 4px; border-bottom: 1px solid var(--border); font-weight: 400; }
  th { color: var(--text-primary); font-weight: 600; }
  s { opacity: .6; }
  .rules { max-width: 82ch; margin-top: 1.6rem; }
  .rules ol { padding-left: 1.2rem; } .rules li { margin: .35rem 0; }
  .m1 { max-width: 82ch; margin-top: 1rem; font-size: .9rem; color: var(--text-secondary); }
</style>

<h2>Contrasto verificato: le tre palette passano tutte le WCAG 2.1 AA</h2>
<div class="subtitle intro">
  <p>Il riferimento di legge in Italia e nell'Unione europea è la norma EN 301 549, che rimanda alle WCAG 2.1 livello AA: contrasto di almeno 4,5:1 per il testo normale, 3:1 per il testo grande e per bordi dei campi, focus, icone di stato e grafici.</p>
  <p>Ho controllato 34 coppie di colori per palette, in chiaro e in scuro: testi, etichette dei tipi, pulsanti, codice, bordi, focus, stella e grafici. Gli sfondi non sono più bianchi. Il rosa e il viola dell'originale restano come accenti: margine del quaderno, preferiti e un tipo di nota.</p>
</div>

<div class="cards">${cards}</div>

<div class="rules">
  <h3>Regole di visualizzazione (valgono per qualsiasi palette)</h3>
  <ol>
    <li>Testo normale almeno 4,5:1 sul suo sfondo; 3:1 solo per titoli da 24px in su (19px se in grassetto).</li>
    <li>Bordi dei campi, anello di focus, icone che indicano uno stato e parti dei grafici almeno 3:1 rispetto a ciò che hanno accanto.</li>
    <li>Il colore non è mai l'unico segnale: ogni tipo di nota ha l'etichetta scritta, il preferito ha la stella piena e il testo per lettori di schermo, lo stato dell'API ha il pallino e la frase.</li>
    <li>Il rosa è un accento raro: margine, preferiti, errori e azioni che cancellano. Come testo si usa la sua versione scura, quella verificata.</li>
    <li>Nei grafici si usano i colori pieni dei tipi, non le tinte chiare degli evidenziatori, e accanto ci sono sempre i numeri.</li>
    <li>Il focus da tastiera è sempre visibile, con un anello di 2px staccato dal componente.</li>
    <li>Nessun testo sotto i 12px; le date e i conteggi usano il terzo grigio, che resta sopra 4,5:1.</li>
    <li>Il tema scuro non è il chiaro invertito: ogni colore ha la sua versione verificata per lo scuro.</li>
  </ol>
</div>

<p class="m1">Per confronto, il primo mockup falliva ${m1.length} controlli su 34, tra cui date e conteggi (${fmt(m1.find(x => x.label === 'Date e conteggi sul foglio').ratio)}:1), testo rosa di errore (${fmt(m1.find(x => x.label.startsWith('Testo di errore')).ratio)}:1), bordi dei campi (${fmt(m1.find(x => x.label === 'Bordo dei campi sul foglio').ratio)}:1) e tutti i colori dei grafici.</p>
`;
fs.writeFileSync(OUT, html);
console.log('scritto', OUT, html.length, 'byte');
