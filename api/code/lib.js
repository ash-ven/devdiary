// DevDiary: logica dei nodi Code di n8n.
// Lo stesso file gira in Node (test con node:test) e, tramite il build, dentro ogni nodo Code.
// Niente require, niente dipendenze: deve funzionare nella sandbox di n8n.

const CONFIG = { demoMode: false, resetToken: '', seed: [] };

const TYPES = ['note', 'snippet', 'idea', 'errore', 'link'];
const LIMITS = { title: 120, content: 10000, code: 10000, tags: 10, tag: 30 };

const MESSAGES = {
  ID_REQUIRED: 'Parametro id obbligatorio',
  ID_INVALID: 'ID non valido',
  BODY_INVALID: 'Il corpo della richiesta deve essere un oggetto JSON',
  TITLE_REQUIRED: 'Il titolo è obbligatorio',
  CONTENT_REQUIRED: 'Il contenuto è obbligatorio',
  TYPE_INVALID: 'Tipo non valido: usa note, snippet, idea, errore o link',
  TITLE_TOO_LONG: 'Il titolo supera i 120 caratteri',
  CONTENT_TOO_LONG: 'Il contenuto supera i 10.000 caratteri',
  CODE_TOO_LONG: 'Il codice supera i 10.000 caratteri',
  TOO_MANY_TAGS: 'Puoi usare al massimo 10 tag',
  TAG_TOO_LONG: 'Ogni tag può avere al massimo 30 caratteri',
  VISITOR_REQUIRED: "Manca l'identificativo del visitatore della demo",
  RESET_UNAUTHORIZED: 'Token di reset non valido',
  SAMPLE_READ_ONLY: 'Le note di esempio non si modificano: creane una tua per provare',
  NOT_FOUND: 'Nota non trovata',
  NOT_IN_TRASH: 'La nota non è nel cestino',
  DEMO_LIMIT_REACHED: 'Hai raggiunto il limite della demo: le note si cancellano ogni notte',
  DATABASE_UNAVAILABLE: 'Database non disponibile',
};

// ---------- risposte ----------

function fail(status, code, message) {
  return { ok: false, status, payload: { error: true, code, message: message || MESSAGES[code] || code } };
}

function done(status, payload, extra) {
  return { ok: true, status, payload, ...(extra || {}) };
}

// ---------- id ----------

function isObjectId(id) {
  return typeof id === 'string' && /^[0-9a-fA-F]{24}$/.test(id);
}

function toHexId(id) {
  if (id === null || id === undefined) return null;
  if (typeof id === 'string') return id;
  if (typeof id.toHexString === 'function') return id.toHexString();
  if (id.buffer && typeof id.buffer === 'object') {
    return Object.values(id.buffer).map((b) => Number(b).toString(16).padStart(2, '0')).join('');
  }
  return String(id);
}

function toPublic(doc) {
  const { ownerId, ...rest } = doc || {};
  return {
    ...rest,
    _id: toHexId(rest._id),
    isSample: rest.isSample === true,
    deletedAt: rest.deletedAt ? String(rest.deletedAt) : null,
  };
}

// ---------- validazione ----------

const length = (text) => [...text].length;

function normalizeEntryInput(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return fail(400, 'BODY_INVALID');

  const title = String(body.title ?? '').trim();
  const content = String(body.content ?? '').trim();
  if (!title) return fail(400, 'TITLE_REQUIRED');
  if (!content) return fail(400, 'CONTENT_REQUIRED');
  if (length(title) > LIMITS.title) return fail(400, 'TITLE_TOO_LONG');
  if (length(content) > LIMITS.content) return fail(400, 'CONTENT_TOO_LONG');

  let type = String(body.type ?? '').trim().toLowerCase();
  if (!type) type = 'note';
  if (!TYPES.includes(type)) return fail(400, 'TYPE_INVALID');

  const language = String(body.language ?? '').trim().toLowerCase() || null;

  // Il codice resta com'è: l'indentazione conta. Solo spazi vuoti → null.
  const rawCode = body.code === null || body.code === undefined ? '' : String(body.code);
  const code = rawCode.trim() ? rawCode : null;
  if (code && length(code) > LIMITS.code) return fail(400, 'CODE_TOO_LONG');

  let rawTags = body.tags ?? [];
  if (typeof rawTags === 'string') rawTags = rawTags.split(',');
  if (!Array.isArray(rawTags)) rawTags = [];
  const tags = [];
  for (const tag of rawTags) {
    const t = String(tag).trim().toLowerCase();
    if (t && !tags.includes(t)) tags.push(t);
  }
  if (tags.length > LIMITS.tags) return fail(400, 'TOO_MANY_TAGS');
  if (tags.some((t) => length(t) > LIMITS.tag)) return fail(400, 'TAG_TOO_LONG');

  const isFavorite = body.isFavorite === true || body.isFavorite === 'true';

  return { ok: true, value: { title, content, type, language, code, tags, isFavorite } };
}

// ---------- filtri e visibilità ----------

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function escapeRegex(text) {
  return String(text).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function visitorFrom(headers, config) {
  if (!config.demoMode) return { ok: true, visitorId: null };
  const raw = String((headers || {})['x-demo-visitor'] ?? '').trim();
  if (!UUID_RE.test(raw)) return fail(400, 'VISITOR_REQUIRED');
  return { ok: true, visitorId: raw.toLowerCase() };
}

function scopeFilter(visitorId, config) {
  if (!config.demoMode) return {};
  return { $or: [{ isSample: true }, { ownerId: visitorId }] };
}

function listFilter(query, visitorId, config) {
  const q = query || {};
  const filter = {};
  if (q.type) filter.type = String(q.type).trim().toLowerCase();
  if (q.favorite !== undefined && q.favorite !== '') filter.isFavorite = String(q.favorite).toLowerCase() === 'true';
  if (q.tag) filter.tags = String(q.tag).trim().toLowerCase();
  filter.deletedAt = String(q.trash ?? '').toLowerCase() === 'true' ? { $ne: null } : null;

  const conditions = [];
  const scope = scopeFilter(visitorId, config);
  if (scope.$or) conditions.push(scope);
  const search = String(q.search ?? '').trim();
  if (search) {
    const regex = escapeRegex(search);
    conditions.push({ $or: [{ title: { $regex: regex, $options: 'i' } }, { content: { $regex: regex, $options: 'i' } }] });
  }
  if (conditions.length === 1) Object.assign(filter, conditions[0]);
  if (conditions.length > 1) filter.$and = conditions;

  return { filter, sort: { createdAt: -1 } };
}

// ---------- date e note di esempio ----------

function romeParts(date) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Europe/Rome', hourCycle: 'h23',
    year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit',
  }).formatToParts(date);
  return Object.fromEntries(parts.map((x) => [x.type, x.value]));
}

function romeWallTimeToUtc(y, m, d, hh, mm) {
  const guess = Date.UTC(y, m - 1, d, hh, mm);
  const p = romeParts(new Date(guess));
  const asRome = Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour, +p.minute);
  return new Date(guess - (asRome - guess));
}

function seedToDocs(seed, now) {
  const today = romeParts(now);
  return (seed || []).map((entry) => {
    const { daysAgo = 0, time = '09:00', ...rest } = entry;
    const day = new Date(Date.UTC(+today.year, +today.month - 1, +today.day - daysAgo));
    const [hh, mm] = String(time).split(':').map(Number);
    const at = romeWallTimeToUtc(day.getUTCFullYear(), day.getUTCMonth() + 1, day.getUTCDate(), hh, mm).toISOString();
    return { ...rest, isSample: true, ownerId: null, deletedAt: null, createdAt: at, updatedAt: at };
  });
}

// ---------- export ----------

function buildMarkdown(entries) {
  let markdown = '# DevDiary Export\n\n';
  for (const entry of entries || []) {
    markdown += `## ${entry.title ?? 'Senza titolo'}\n\n`;
    markdown += `**Tipo:** ${entry.type ?? 'note'}\n\n`;
    if (Array.isArray(entry.tags) && entry.tags.length > 0) {
      markdown += `**Tag:** ${entry.tags.map((tag) => `#${tag}`).join(' ')}\n\n`;
    }
    markdown += `${entry.content ?? ''}\n\n`;
    if (entry.language) markdown += `**Linguaggio:** ${entry.language}\n\n`;
    if (entry.code) markdown += '```' + (entry.language ?? '') + '\n' + entry.code + '\n```\n\n';
    markdown += '---\n\n';
  }
  return markdown;
}

if (typeof module !== 'undefined') {
  module.exports = {
    CONFIG, TYPES, LIMITS, MESSAGES,
    fail, done, isObjectId, toHexId, toPublic, normalizeEntryInput,
    escapeRegex, visitorFrom, scopeFilter, listFilter,
    romeWallTimeToUtc, seedToDocs, buildMarkdown,
  };
}
