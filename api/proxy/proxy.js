// Proxy davanti a n8n: espone solo i webhook e /healthz, valida percorso e corpo JSON,
// limita le richieste per IP e la dimensione del corpo, aggiunge CORS anche ai propri errori.
const http = require('node:http');

const MESSAGES = {
  NOT_FOUND: 'Percorso non disponibile',
  BODY_INVALID: 'Il corpo della richiesta deve essere un oggetto JSON',
  PAYLOAD_TOO_LARGE: 'Richiesta troppo grande',
  RATE_LIMITED: 'Troppe richieste: riprova tra un minuto',
  API_STARTING: 'Il server si sta avviando, riprova tra qualche secondo',
  PROXY_ERROR: 'Errore interno del proxy',
};

// Intestazioni che valgono per una sola connessione e non vanno inoltrate.
const HOP_BY_HOP = ['connection', 'keep-alive', 'transfer-encoding', 'te', 'trailer', 'upgrade', 'proxy-authenticate', 'proxy-authorization', 'proxy-connection'];
const BODY_METHODS = new Set(['POST', 'PUT', 'PATCH']);

function isAllowedPath(pathname) {
  return pathname === '/healthz' || pathname.startsWith('/webhook/');
}

// Restituisce { pathname, search } solo per percorsi semplici e già normalizzati; altrimenti null.
function safeTarget(rawUrl) {
  if (typeof rawUrl !== 'string' || !rawUrl.startsWith('/') || rawUrl.startsWith('//')) return null;
  const q = rawUrl.indexOf('?');
  const pathname = q === -1 ? rawUrl : rawUrl.slice(0, q);
  const search = q === -1 ? '' : rawUrl.slice(q);
  if (/\\|%2e|%2f|%5c/i.test(pathname)) return null;
  if (pathname.split('/').some((segment) => segment === '.' || segment === '..')) return null;
  let parsed;
  try {
    parsed = new URL(pathname, 'http://proxy');
  } catch {
    return null;
  }
  if (parsed.pathname !== pathname) return null;
  return { pathname, search };
}

function createRateLimiter({ limit = 60, windowMs = 60000, now = Date.now, maxEntries = 20000 } = {}) {
  const hits = new Map(); // chiave -> { start, count }
  let lastSweep = now();
  const sweep = (t) => {
    for (const [key, w] of hits) if (t - w.start >= windowMs) hits.delete(key);
    lastSweep = t;
  };
  return {
    // 0 se la richiesta passa, altrimenti i secondi da attendere.
    hit(key) {
      const t = now();
      if (t - lastSweep >= windowMs) sweep(t);
      let w = hits.get(key);
      if (!w || t - w.start >= windowMs) {
        if (!w && hits.size >= maxEntries) {
          sweep(t);
          if (hits.size >= maxEntries) hits.clear(); // sotto attacco con molti IP: si ricomincia
        }
        w = { start: t, count: 0 };
        hits.set(key, w);
      }
      w.count += 1;
      return w.count <= limit ? 0 : Math.max(1, Math.ceil((w.start + windowMs - t) / 1000));
    },
    size: () => hits.size,
  };
}

// L'IP reale lo aggiunge in fondo il proxy di Render; le voci a sinistra le sceglie il client.
function clientIp(req, trustedHops) {
  const list = String(req.headers['x-forwarded-for'] || '').split(',').map((s) => s.trim()).filter(Boolean);
  if (trustedHops > 0 && list.length) return list[Math.max(0, list.length - trustedHops)];
  return req.socket.remoteAddress || 'unknown';
}

function corsFor(origin, allowed) {
  if (!origin) return {};
  if (allowed.includes('*') || allowed.includes(origin)) return { 'access-control-allow-origin': origin, vary: 'Origin' };
  return {};
}

function withoutHopByHop(headers) {
  const out = { ...headers };
  for (const name of HOP_BY_HOP) delete out[name];
  return out;
}

// Controlla un corpo JSON prima che arrivi a n8n (che altrimenti risponde 422 nel suo formato).
function checkJsonBody(req, pathname, buffer) {
  if (!BODY_METHODS.has(req.method) || buffer.length === 0) return { ok: true, body: buffer };
  if (!String(req.headers['content-type'] || '').toLowerCase().includes('json')) return { ok: true, body: buffer };
  let text = buffer.toString('utf8');
  if (text.charCodeAt(0) === 0xfeff) text = text.slice(1);
  let value;
  try {
    value = JSON.parse(text);
  } catch {
    return { ok: false };
  }
  const isNote = pathname === '/webhook/diary' && (req.method === 'POST' || req.method === 'PUT');
  if (isNote && (value === null || typeof value !== 'object' || Array.isArray(value))) return { ok: false };
  return { ok: true, body: Buffer.from(text, 'utf8') };
}

function createProxy({
  target, maxBody = 32768, rateLimit = 60, windowMs = 60000, now = Date.now,
  allowedOrigins = '*', trustedHops = 1, maxEntries = 20000,
} = {}) {
  const upstream = new URL(target);
  const allowed = String(allowedOrigins).split(',').map((s) => s.trim()).filter(Boolean);
  const limiter = createRateLimiter({ limit: rateLimit, windowMs, now, maxEntries });

  function sendError(req, res, status, code, extraHeaders = {}) {
    if (res.headersSent) return res.end();
    res.writeHead(status, { 'content-type': 'application/json; charset=utf-8', ...corsFor(req.headers.origin, allowed), ...extraHeaders });
    res.end(JSON.stringify({ error: true, code, message: MESSAGES[code] }));
  }

  function forward(req, res, path, body) {
    const headers = withoutHopByHop(req.headers);
    delete headers['content-length'];
    headers.host = upstream.host;
    if (body.length) headers['content-length'] = String(body.length);
    const upReq = http.request({ hostname: upstream.hostname, port: upstream.port, method: req.method, path, headers }, (upRes) => {
      res.writeHead(upRes.statusCode, withoutHopByHop(upRes.headers));
      upRes.pipe(res);
    });
    upReq.on('error', () => sendError(req, res, 503, 'API_STARTING'));
    upReq.end(body);
  }

  function handle(req, res) {
    req.on('error', () => res.destroy());
    const targetPath = safeTarget(req.url);
    if (!targetPath || !isAllowedPath(targetPath.pathname)) {
      req.resume();
      return sendError(req, res, 404, 'NOT_FOUND');
    }

    if (req.method !== 'OPTIONS') {
      const retryAfter = limiter.hit(clientIp(req, trustedHops));
      if (retryAfter) {
        req.resume();
        return sendError(req, res, 429, 'RATE_LIMITED', { 'retry-after': String(retryAfter) });
      }
    }

    const chunks = [];
    let size = 0;
    let tooLarge = false;
    req.on('data', (chunk) => {
      if (tooLarge) return;
      size += chunk.length;
      if (size > maxBody) {
        tooLarge = true;
        chunks.length = 0;
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      if (tooLarge) return sendError(req, res, 413, 'PAYLOAD_TOO_LARGE');
      const checked = checkJsonBody(req, targetPath.pathname, Buffer.concat(chunks));
      if (!checked.ok) return sendError(req, res, 400, 'BODY_INVALID');
      forward(req, res, targetPath.pathname + targetPath.search, checked.body);
    });
  }

  return http.createServer((req, res) => {
    try {
      handle(req, res);
    } catch (err) {
      console.error('DevDiary proxy: errore inatteso', err);
      sendError(req, res, 500, 'PROXY_ERROR');
    }
  });
}

module.exports = { createProxy, createRateLimiter, isAllowedPath, safeTarget };
