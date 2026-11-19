const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { createProxy, createRateLimiter, isAllowedPath } = require('./proxy');

// Server finto a monte: risponde con metodo, percorso e corpo ricevuti.
let upstream;
let upstreamUrl;
const received = [];

before(async () => {
  upstream = http.createServer((req, res) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      const body = Buffer.concat(chunks).toString('utf8');
      received.push({ method: req.method, url: req.url, body, headers: req.headers });
      res.writeHead(200, { 'content-type': 'application/json', 'access-control-allow-origin': 'x' });
      res.end(JSON.stringify({ method: req.method, url: req.url, body }));
    });
  });
  await new Promise((r) => upstream.listen(0, '127.0.0.1', r));
  upstreamUrl = `http://127.0.0.1:${upstream.address().port}`;
});

after(() => upstream.close());

async function withProxy(options, fn) {
  const proxy = createProxy({ target: upstreamUrl, ...options });
  await new Promise((r) => proxy.listen(0, '127.0.0.1', r));
  const port = proxy.address().port;
  try {
    return await fn(`http://127.0.0.1:${port}`, port);
  } finally {
    await new Promise((r) => proxy.close(r));
  }
}

// Richiesta HTTP con il percorso grezzo, senza la normalizzazione di fetch.
function raw(port, path, { method = 'GET', headers = {}, body } = {}) {
  return new Promise((resolve, reject) => {
    const req = http.request({ host: '127.0.0.1', port, path, method, headers }, (res) => {
      let data = '';
      res.on('data', (c) => { data += c; });
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: data }));
    });
    req.on('error', reject);
    if (body !== undefined) req.write(body);
    req.end();
  });
}
const json = (r) => JSON.parse(r.body);

test('isAllowedPath accepts only webhooks and healthz', () => {
  for (const p of ['/webhook/status', '/webhook/diary/detail', '/healthz']) assert.equal(isAllowedPath(p), true, p);
  for (const p of ['/', '/rest/login', '/webhook-test/status', '/healthz/readiness', '/webhookx']) assert.equal(isAllowedPath(p), false, p);
});

test('forwards allowed paths', async () => {
  await withProxy({}, async (base) => {
    const res = await fetch(`${base}/webhook/diary?type=snippet`);
    assert.equal(res.status, 200);
    assert.equal(res.headers.get('access-control-allow-origin'), 'x');
    assert.deepEqual(await res.json(), { method: 'GET', url: '/webhook/diary?type=snippet', body: '' });
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

test('survives malformed request targets', async () => {
  const before = received.length;
  await withProxy({}, async (base, port) => {
    for (const path of ['//:/webhook/x', '//@/x', '//a:99999/x', '//%/x', '//[/x', 'http://[/x']) {
      const r = await raw(port, path);
      assert.equal(r.status, 404, path);
      assert.equal(json(r).code, 'NOT_FOUND', path);
    }
    assert.equal((await fetch(`${base}/webhook/status`)).status, 200, 'il proxy deve restare in piedi');
  });
  assert.equal(received.length, before + 1, 'solo la richiesta valida arriva a monte');
});

test('blocks dot segments and encoded traversal', async () => {
  const before = received.length;
  await withProxy({}, async (base, port) => {
    for (const path of [
      '/webhook-test/x/../../webhook/y', '/form/x/../../webhook/y', '/api/v1/workflows/../../../webhook/x',
      '/webhook/../rest/settings', '/webhook/./status', '/webhook/%2e%2e/rest/settings', '/webhook/%2E%2e/x',
      '/webhook/x%2f..%2fy', '/webhook/x\\..\\y', '//webhook/status',
    ]) {
      const r = await raw(port, path);
      assert.equal(r.status, 404, path);
    }
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

test('rejects broken JSON', async () => {
  const before = received.length;
  await withProxy({}, async (base) => {
    for (const method of ['POST', 'PUT']) {
      const res = await fetch(`${base}/webhook/diary?id=6afeb4a37ab5376904d214ad`, { method, body: '{broken', headers: { 'content-type': 'application/json' } });
      assert.equal(res.status, 400, method);
      assert.deepEqual(await res.json(), { error: true, code: 'BODY_INVALID', message: 'Il corpo della richiesta deve essere un oggetto JSON' });
    }
  });
  assert.equal(received.length, before);
});

test('rejects bodies that are not an object for notes', async () => {
  await withProxy({}, async (base) => {
    for (const body of ['null', '[]', '"x"', '42']) {
      for (const method of ['POST', 'PUT']) {
        const res = await fetch(`${base}/webhook/diary`, { method, body, headers: { 'content-type': 'application/json' } });
        assert.equal(res.status, 400, `${method} ${body}`);
        assert.equal((await res.json()).code, 'BODY_INVALID');
      }
    }
  });
});

test('strips a byte order mark and forwards clean JSON', async () => {
  await withProxy({}, async (base) => {
    const res = await fetch(`${base}/webhook/diary`, { method: 'POST', body: '﻿{"title":"perché"}', headers: { 'content-type': 'application/json' } });
    assert.equal(res.status, 200);
    const last = received[received.length - 1];
    assert.equal(last.body, '{"title":"perché"}');
    assert.equal(Number(last.headers['content-length']), Buffer.byteLength('{"title":"perché"}'));
  });
});

test('forwards chunked request bodies with a single length', async () => {
  await withProxy({}, async (base, port) => {
    const r = await raw(port, '/webhook/diary', { method: 'POST', headers: { 'content-type': 'application/json', 'transfer-encoding': 'chunked' }, body: '{"title":"a"}' });
    assert.equal(r.status, 200);
    const last = received[received.length - 1];
    assert.equal(last.body, '{"title":"a"}');
    assert.equal(last.headers['transfer-encoding'], undefined);
  });
});

test('allows an empty body on actions without payload', async () => {
  await withProxy({}, async (base) => {
    const res = await fetch(`${base}/webhook/diary/restore?id=6afeb4a37ab5376904d214ad`, { method: 'POST', headers: { 'content-type': 'application/json' } });
    assert.equal(res.status, 200);
  });
});

test('rate limits per client ip', async () => {
  let t = 0;
  await withProxy({ rateLimit: 3, windowMs: 60000, now: () => t }, async (base) => {
    const get = (xff) => fetch(`${base}/webhook/status`, { headers: { 'x-forwarded-for': xff } });
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

test('ignores spoofed forwarded-for entries', async () => {
  await withProxy({ rateLimit: 2, trustedHops: 1 }, async (base) => {
    // Il proxy di Render aggiunge in fondo l'IP reale: le voci a sinistra le sceglie il client.
    const get = (xff) => fetch(`${base}/webhook/status`, { headers: { 'x-forwarded-for': xff } });
    assert.equal((await get('fake-1, 9.9.9.9')).status, 200);
    assert.equal((await get('fake-2, 9.9.9.9')).status, 200);
    assert.equal((await get('fake-3, 9.9.9.9')).status, 429);
  });
});

test('does not count preflight requests', async () => {
  await withProxy({ rateLimit: 1 }, async (base) => {
    for (let i = 0; i < 5; i++) {
      const res = await fetch(`${base}/webhook/diary`, { method: 'OPTIONS', headers: { origin: 'https://site', 'access-control-request-method': 'POST' } });
      assert.equal(res.status, 200, 'le preflight passano sempre');
    }
    assert.equal((await fetch(`${base}/webhook/status`)).status, 200, 'la prima richiesta vera è ancora nel limite');
  });
});

test('adds CORS headers to proxy errors', async () => {
  await withProxy({ allowedOrigins: '*' }, async (base) => {
    const res = await fetch(`${base}/rest/settings`, { headers: { origin: 'https://site.example' } });
    assert.equal(res.status, 404);
    assert.equal(res.headers.get('access-control-allow-origin'), 'https://site.example');
  });
  await withProxy({ allowedOrigins: 'https://site.example' }, async (base) => {
    const ok = await fetch(`${base}/rest/settings`, { headers: { origin: 'https://site.example' } });
    assert.equal(ok.headers.get('access-control-allow-origin'), 'https://site.example');
    const other = await fetch(`${base}/rest/settings`, { headers: { origin: 'https://evil.example' } });
    assert.equal(other.headers.get('access-control-allow-origin'), null);
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

test('rate limiter keeps memory bounded and fast', () => {
  let t = 0;
  const limiter = createRateLimiter({ limit: 60, windowMs: 60000, now: () => t, maxEntries: 20000 });
  const start = process.hrtime.bigint();
  for (let i = 0; i < 60000; i++) limiter.hit(`10.${(i >> 16) & 255}.${(i >> 8) & 255}.${i & 255}`);
  const ms = Number(process.hrtime.bigint() - start) / 1e6;
  assert.ok(limiter.size() <= 20000, `dimensione ${limiter.size()}`);
  assert.ok(ms < 1000, `troppo lento: ${ms.toFixed(0)} ms`);
  t = 60000;
  limiter.hit('1.1.1.1');
  assert.equal(limiter.size(), 1, 'le voci scadute vengono rimosse');
});
