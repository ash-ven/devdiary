const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { createProxy, isAllowedPath } = require('./proxy');

// Server finto a monte: risponde con metodo e percorso ricevuti.
let upstream;
let upstreamUrl;
const received = [];

before(async () => {
  upstream = http.createServer((req, res) => {
    let body = '';
    req.on('data', (c) => { body += c; });
    req.on('end', () => {
      received.push({ method: req.method, url: req.url, body });
      res.writeHead(200, { 'content-type': 'application/json', 'access-control-allow-origin': 'x' });
      res.end(JSON.stringify({ method: req.method, url: req.url }));
    });
  });
  await new Promise((r) => upstream.listen(0, '127.0.0.1', r));
  upstreamUrl = `http://127.0.0.1:${upstream.address().port}`;
});

after(() => upstream.close());

async function withProxy(options, fn) {
  const proxy = createProxy({ target: upstreamUrl, ...options });
  await new Promise((r) => proxy.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${proxy.address().port}`;
  try {
    return await fn(base);
  } finally {
    await new Promise((r) => proxy.close(r));
  }
}

test('isAllowedPath accepts only webhooks and healthz', () => {
  for (const p of ['/webhook/status', '/webhook/diary/detail', '/healthz']) assert.equal(isAllowedPath(p), true, p);
  for (const p of ['/', '/rest/login', '/webhook-test/status', '/healthz/readiness', '/webhookx']) assert.equal(isAllowedPath(p), false, p);
});

test('forwards allowed paths', async () => {
  await withProxy({}, async (base) => {
    const res = await fetch(`${base}/webhook/diary?type=snippet`);
    assert.equal(res.status, 200);
    assert.equal(res.headers.get('access-control-allow-origin'), 'x');
    assert.deepEqual(await res.json(), { method: 'GET', url: '/webhook/diary?type=snippet' });
  });
});

test('blocks other paths', async () => {
  const before = received.length;
  await withProxy({}, async (base) => {
    const res = await fetch(`${base}/rest/settings`);
    assert.equal(res.status, 404);
    assert.deepEqual(await res.json(), { error: true, code: 'NOT_FOUND', message: 'Percorso non disponibile' });
  });
  assert.equal(received.length, before, 'nessuna richiesta deve arrivare a monte');
});

test('rejects large bodies', async () => {
  const before = received.length;
  await withProxy({}, async (base) => {
    const res = await fetch(`${base}/webhook/diary`, { method: 'POST', body: 'a'.repeat(32769), headers: { 'content-type': 'application/json' } });
    assert.equal(res.status, 413);
    assert.deepEqual(await res.json(), { error: true, code: 'PAYLOAD_TOO_LARGE', message: 'Richiesta troppo grande' });
  });
  assert.equal(received.length, before, 'il corpo troppo grande non deve arrivare a monte');
});

test('accepts bodies at the limit', async () => {
  await withProxy({}, async (base) => {
    const res = await fetch(`${base}/webhook/diary`, { method: 'POST', body: 'a'.repeat(32768) });
    assert.equal(res.status, 200);
  });
});

test('rate limits per ip', async () => {
  let t = 0;
  await withProxy({ rateLimit: 3, windowMs: 60000, now: () => t }, async (base) => {
    const get = (ip) => fetch(`${base}/webhook/status`, { headers: { 'x-forwarded-for': `${ip}, 10.0.0.1` } });
    for (let i = 0; i < 3; i++) assert.equal((await get('1.2.3.4')).status, 200);
    const limited = await get('1.2.3.4');
    assert.equal(limited.status, 429);
    assert.ok(limited.headers.get('retry-after'), 'serve Retry-After');
    assert.deepEqual(await limited.json(), { error: true, code: 'RATE_LIMITED', message: 'Troppe richieste: riprova tra un minuto' });
    assert.equal((await get('5.6.7.8')).status, 200);
    t = 60000;
    assert.equal((await get('1.2.3.4')).status, 200);
  });
});

test('reports upstream down', async () => {
  const closed = http.createServer();
  await new Promise((r) => closed.listen(0, '127.0.0.1', r));
  const port = closed.address().port;
  await new Promise((r) => closed.close(r));
  const proxy = createProxy({ target: `http://127.0.0.1:${port}` });
  await new Promise((r) => proxy.listen(0, '127.0.0.1', r));
  try {
    const res = await fetch(`http://127.0.0.1:${proxy.address().port}/webhook/status`);
    assert.equal(res.status, 503);
    assert.deepEqual(await res.json(), { error: true, code: 'API_STARTING', message: 'Il server si sta avviando, riprova tra qualche secondo' });
  } finally {
    await new Promise((r) => proxy.close(r));
  }
});
