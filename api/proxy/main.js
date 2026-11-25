// Processo principale del container: avvia n8n come figlio e il proxy davanti.
const { spawn } = require('node:child_process');
const { createProxy } = require('./proxy');

const N8N = 'http://127.0.0.1:5679';
const port = Number(process.env.PORT || 10000);

const n8n = spawn('n8n', ['start'], { stdio: 'inherit', env: process.env });
n8n.on('exit', (code, signal) => {
  console.error(`DevDiary API: n8n terminato (codice ${code}, segnale ${signal})`);
  process.exit(code ?? 1);
});
for (const sig of ['SIGTERM', 'SIGINT']) process.on(sig, () => n8n.kill(sig));

// Ultima rete di sicurezza: un errore inatteso si registra, ma non deve spegnere l'API pubblica.
process.on('uncaughtException', (err) => console.error('DevDiary API: eccezione non gestita', err));

// I webhook diventano utilizzabili solo quando n8n ha attivato i workflow.
let webhooksReady = false;

const proxy = createProxy({
  target: N8N,
  isReady: () => webhooksReady,
  rateLimit: Number(process.env.RATE_LIMIT_PER_MINUTE || 60),
  allowedOrigins: process.env.ALLOWED_ORIGINS || '*',
  trustedHops: Number(process.env.TRUSTED_PROXY_HOPS ?? 1),
});
proxy.listen(port, '0.0.0.0', () => console.log(`DevDiary API: proxy in ascolto sulla porta ${port}`));

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Al primo avvio con database vuoto carica le note di esempio (il webhook esiste dal Task 7).
async function seedIfEmpty() {
  for (let i = 0; i < 120; i++) {
    try {
      if ((await fetch(`${N8N}/healthz`)).ok) break;
    } catch { /* n8n non ancora in ascolto */ }
    await sleep(1000);
  }
  for (let attempt = 0; attempt < 30; attempt++) {
    try {
      const res = await fetch(`${N8N}/webhook/demo/reset?ifEmpty=true`, {
        method: 'POST',
        headers: { 'x-reset-token': process.env.RESET_TOKEN || '' },
      });
      if (res.status !== 404) {
        webhooksReady = true;
        console.log(`DevDiary API: seed iniziale, risposta ${res.status}`);
        return;
      }
    } catch { /* riprova */ }
    await sleep(2000);
  }
  // Non si blocca l'API per sempre: si apre comunque e si registra il problema.
  webhooksReady = true;
  console.log('DevDiary API: webhook di reset non disponibile, seed iniziale saltato');
}
seedIfEmpty();
