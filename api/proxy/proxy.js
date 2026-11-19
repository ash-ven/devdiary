// Proxy davanti a n8n: espone solo i webhook e /healthz, limita richieste e dimensione del corpo.
const http = require('node:http');

const MESSAGES = {
  NOT_FOUND: 'Percorso non disponibile',
  PAYLOAD_TOO_LARGE: 'Richiesta troppo grande',
  RATE_LIMITED: 'Troppe richieste: riprova tra un minuto',
  API_STARTING: 'Il server si sta avviando, riprova tra qualche secondo',
};

function isAllowedPath(pathname) {
  return pathname === '/healthz' || pathname.startsWith('/webhook/');
}

function sendError(res, status, code, extraHeaders = {}) {
  if (res.headersSent) return res.end();
  res.writeHead(status, { 'content-type': 'application/json; charset=utf-8', ...extraHeaders });
  res.end(JSON.stringify({ error: true, code, message: MESSAGES[code] }));
}

function clientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (forwarded) return String(forwarded).split(',')[0].trim();
  return req.socket.remoteAddress || 'unknown';
}

function createProxy({ target, maxBody = 32768, rateLimit = 60, windowMs = 60000, now = Date.now } = {}) {
  const upstream = new URL(target);
  const windows = new Map(); // ip -> { start, count }

  function overLimit(ip) {
    const t = now();
    let w = windows.get(ip);
    if (!w || t - w.start >= windowMs) {
      if (windows.size > 5000) {
        for (const [key, value] of windows) if (t - value.start >= windowMs) windows.delete(key);
      }
      w = { start: t, count: 0 };
      windows.set(ip, w);
    }
    w.count += 1;
    if (w.count <= rateLimit) return null;
    return Math.max(1, Math.ceil((w.start + windowMs - t) / 1000));
  }

  function forward(req, res, body) {
    const headers = { ...req.headers, host: upstream.host };
    if (body.length) headers['content-length'] = String(body.length);
    const upReq = http.request({
      hostname: upstream.hostname,
      port: upstream.port,
      method: req.method,
      path: req.url,
      headers,
    }, (upRes) => {
      res.writeHead(upRes.statusCode, upRes.headers);
      upRes.pipe(res);
    });
    upReq.on('error', () => sendError(res, 503, 'API_STARTING'));
    upReq.end(body);
  }

  return http.createServer((req, res) => {
    const pathname = new URL(req.url, 'http://proxy').pathname;
    if (!isAllowedPath(pathname)) {
      req.resume();
      return sendError(res, 404, 'NOT_FOUND');
    }

    const retryAfter = overLimit(clientIp(req));
    if (retryAfter) {
      req.resume();
      return sendError(res, 429, 'RATE_LIMITED', { 'retry-after': String(retryAfter) });
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
      if (tooLarge) return sendError(res, 413, 'PAYLOAD_TOO_LARGE');
      forward(req, res, Buffer.concat(chunks));
    });
  });
}

module.exports = { createProxy, isAllowedPath };
