// Rasterizza gli SVG del logo in PNG trasparenti (via canvas in Edge headless) e compone favicon.ico.
// Uso: node render-logo.js <cartella branding>
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const dir = path.resolve(process.argv[2]);
const out = path.join(dir, 'png');
fs.mkdirSync(out, { recursive: true });
const svg = name => 'data:image/svg+xml;base64,' + fs.readFileSync(path.join(dir, name)).toString('base64');

const jobs = [
  // [svg, lato in px, file di uscita]
  ['devdiary-logo-16.svg', 16, 'favicon-16.png'],
  ['devdiary-logo.svg', 32, 'favicon-32.png'],
  ['devdiary-logo.svg', 48, 'favicon-48.png'],
  ['devdiary-logo.svg', 64, 'devdiary-logo-64.png'],
  ['devdiary-logo.svg', 128, 'devdiary-logo-128.png'],
  ['devdiary-logo.svg', 192, 'Icon-192.png'],
  ['devdiary-logo.svg', 256, 'devdiary-logo-256.png'],
  ['devdiary-logo.svg', 512, 'Icon-512.png'],
  ['devdiary-logo.svg', 1024, 'devdiary-logo-1024.png'],
  ['devdiary-logo-maskable.svg', 180, 'apple-touch-icon.png'],
  ['devdiary-logo-maskable.svg', 192, 'Icon-maskable-192.png'],
  ['devdiary-logo-maskable.svg', 512, 'Icon-maskable-512.png'],
  ['devdiary-logo-mono.svg', 512, 'devdiary-logo-mono-512.png'],
];

const html = `<!doctype html><meta charset="utf-8"><body><script>
const jobs = ${JSON.stringify(jobs.map(([s, n, f]) => [svg(s), n, f]))};
(async () => {
  const res = {};
  for (const [src, n, file] of jobs) {
    const img = new Image(); img.src = src; await img.decode();
    const c = document.createElement('canvas'); c.width = n; c.height = n;
    const ctx = c.getContext('2d'); ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(img, 0, 0, n, n);
    res[file] = c.toDataURL('image/png').split(',')[1];
  }
  const pre = document.createElement('pre'); pre.id = 'out'; pre.textContent = ['@@', 'PNG', '@@'].join('') + JSON.stringify(res) + ['##', 'PNG', '##'].join('');
  document.body.appendChild(pre);
})();
</script>`;

const tmp = path.join(__dirname, 'render-logo-tmp');
fs.mkdirSync(tmp, { recursive: true });
const page = path.join(tmp, 'render.html');
fs.writeFileSync(page, html);

const edge = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const dom = execFileSync(edge, [
  '--headless=new', '--disable-gpu', '--no-first-run', `--user-data-dir=${path.join(tmp, 'profile')}`,
  '--virtual-time-budget=10000', '--dump-dom', 'file:///' + page.replace(/\\/g, '/'),
], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
const m = dom.match(/@@PNG@@(.*?)##PNG##/s);
if (!m) { console.error(dom.slice(0, 2000)); throw new Error('rendering non riuscito'); }
const res = JSON.parse(m[1]);
for (const [file, b64] of Object.entries(res)) fs.writeFileSync(path.join(out, file), Buffer.from(b64, 'base64'));

// favicon.ico con PNG incorporati (16, 32, 48)
const icoParts = ['favicon-16.png', 'favicon-32.png', 'favicon-48.png'].map(f => fs.readFileSync(path.join(out, f)));
const header = Buffer.alloc(6); header.writeUInt16LE(0, 0); header.writeUInt16LE(1, 2); header.writeUInt16LE(icoParts.length, 4);
let offset = 6 + 16 * icoParts.length;
const entries = icoParts.map((buf, i) => {
  const size = [16, 32, 48][i];
  const e = Buffer.alloc(16);
  e.writeUInt8(size, 0); e.writeUInt8(size, 1); e.writeUInt8(0, 2); e.writeUInt8(0, 3);
  e.writeUInt16LE(1, 4); e.writeUInt16LE(32, 6); e.writeUInt32LE(buf.length, 8); e.writeUInt32LE(offset, 12);
  offset += buf.length; return e;
});
fs.writeFileSync(path.join(out, 'favicon.ico'), Buffer.concat([header, ...entries, ...icoParts]));

// controllo: dimensioni reali dei PNG e trasparenza degli angoli
for (const f of fs.readdirSync(out).filter(f => f.endsWith('.png')).sort()) {
  const b = fs.readFileSync(path.join(out, f));
  console.log(f.padEnd(28), b.readUInt32BE(16) + 'x' + b.readUInt32BE(20), (b.length / 1024).toFixed(1) + ' KB');
}
console.log('favicon.ico'.padEnd(28), (fs.statSync(path.join(out, 'favicon.ico')).size / 1024).toFixed(1) + ' KB');
