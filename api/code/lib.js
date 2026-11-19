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
  if (!visitorId) return { $or: [{ isSample: true }] };
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

// ---------- funzioni di ingresso dei nodi Code ----------
// ctx = { json, items, ref(nomeNodo) -> json, config }. Ogni funzione restituisce il json
// dell'elemento in uscita: { ok, status, payload, ...dati per il nodo successivo }.

const DEMO_LIMITS = { total: 300, perVisitor: 50 };
const nowIso = () => new Date().toISOString();
const dbError = (items) => (items || []).some((i) => i && i.error);
const found = (items) => (items || []).filter((i) => i && i._id !== undefined && i._id !== null);
const isTrue = (value) => String(value ?? '').trim().toLowerCase() === 'true';
const readerId = (json, config) => {
  const v = visitorFrom(json.headers, config);
  return v.ok ? v.visitorId : null; // in lettura un visitatore senza id vede solo gli esempi
};

function idFrom(query) {
  const id = String((query || {}).id ?? '').trim();
  if (!id) return fail(400, 'ID_REQUIRED');
  if (!isObjectId(id)) return fail(400, 'ID_INVALID');
  return { ok: true, id: id.toLowerCase() };
}

const ENTRY = {
  statusResult({ items }) {
    if (dbError(items)) return { ok: false, status: 503, payload: { status: 'OK', database: 'ERROR' } };
    return done(200, { status: 'OK', database: 'OK' });
  },

  listPrepare({ json, config }) {
    const { filter, sort } = listFilter(json.query, readerId(json, config), config);
    return done(200, null, { filter, sort });
  },
  listResult({ items }) {
    if (dbError(items)) return fail(503, 'DATABASE_UNAVAILABLE');
    return done(200, found(items).map(toPublic));
  },

  detailPrepare({ json, config }) {
    const idr = idFrom(json.query);
    if (!idr.ok) return idr;
    const trash = isTrue((json.query || {}).trash);
    const filter = { _id: idr.id, deletedAt: trash ? { $ne: null } : null, ...scopeFilter(readerId(json, config), config) };
    return done(200, null, { filter });
  },
  detailResult({ items }) {
    if (dbError(items)) return fail(503, 'DATABASE_UNAVAILABLE');
    const doc = found(items)[0];
    if (!doc) return fail(404, 'NOT_FOUND');
    return done(200, toPublic(doc));
  },

  createPrepare({ json, config }) {
    const v = visitorFrom(json.headers, config);
    if (!v.ok) return v;
    const n = normalizeEntryInput(json.body);
    if (!n.ok) return n;
    const now = nowIso();
    const doc = { ...n.value, isSample: false, ownerId: v.visitorId, deletedAt: null, createdAt: now, updatedAt: now };
    const pipeline = [{ $facet: { total: [{ $count: 'n' }], mine: [{ $match: { ownerId: v.visitorId } }, { $count: 'n' }] } }];
    return done(201, null, { doc, pipeline });
  },
  createCheckLimits({ items, ref, config }) {
    if (dbError(items)) return fail(503, 'DATABASE_UNAVAILABLE');
    const prep = ref('createPrepare');
    if (config.demoMode) {
      const counts = (items || [])[0] || {};
      const total = ((counts.total || [])[0] || {}).n || 0;
      const mine = ((counts.mine || [])[0] || {}).n || 0;
      if (total >= DEMO_LIMITS.total || mine >= DEMO_LIMITS.perVisitor) return fail(429, 'DEMO_LIMIT_REACHED');
    }
    return done(201, null, { ...prep.doc }); // campi al primo livello per il nodo insert
  },
  createResult({ items }) {
    if (dbError(items)) return fail(503, 'DATABASE_UNAVAILABLE');
    const inserted = (items || [])[0] || {};
    return done(201, { success: true, message: 'Nota creata correttamente', _id: toHexId(inserted.id ?? inserted._id) });
  },

  updatePrepare({ json, config }) {
    const v = visitorFrom(json.headers, config);
    if (!v.ok) return v;
    const idr = idFrom(json.query);
    if (!idr.ok) return idr;
    const n = normalizeEntryInput(json.body);
    if (!n.ok) return n;
    return done(200, null, { id: idr.id, update: n.value, filter: { _id: idr.id, ...scopeFilter(v.visitorId, config) } });
  },
  updateCheck({ items, ref, config }) {
    if (dbError(items)) return fail(503, 'DATABASE_UNAVAILABLE');
    const prep = ref('updatePrepare');
    const doc = found(items)[0];
    if (!doc || doc.deletedAt) return fail(404, 'NOT_FOUND');
    if (config.demoMode && doc.isSample === true) return fail(403, 'SAMPLE_READ_ONLY');
    return done(200, null, { _id: prep.id, ...prep.update, updatedAt: nowIso() });
  },
  updateResult({ items }) {
    if (dbError(items)) return fail(503, 'DATABASE_UNAVAILABLE');
    return done(200, { success: true, message: 'Nota aggiornata correttamente' });
  },

  deletePrepare({ json, config }) {
    const v = visitorFrom(json.headers, config);
    if (!v.ok) return v;
    const idr = idFrom(json.query);
    if (!idr.ok) return idr;
    const action = isTrue((json.query || {}).permanent) ? 'hard' : 'soft';
    return done(200, null, { id: idr.id, action, filter: { _id: idr.id, ...scopeFilter(v.visitorId, config) } });
  },
  deleteCheck({ items, ref, config }) {
    if (dbError(items)) return fail(503, 'DATABASE_UNAVAILABLE');
    const prep = ref('deletePrepare');
    const doc = found(items)[0];
    if (!doc) return fail(404, 'NOT_FOUND');
    if (config.demoMode && doc.isSample === true) return fail(403, 'SAMPLE_READ_ONLY');
    if (prep.action === 'hard') {
      if (!doc.deletedAt) return fail(409, 'NOT_IN_TRASH');
      // Il nodo delete non converte _id: si confronta la sua forma testuale.
      return done(200, null, { action: 'hard', filter: { $expr: { $eq: [{ $toString: '$_id' }, prep.id] } } });
    }
    if (doc.deletedAt) return fail(404, 'NOT_FOUND');
    const now = nowIso();
    return done(200, null, { action: 'soft', _id: prep.id, deletedAt: now, updatedAt: now });
  },
  deleteResult({ items, ref }) {
    if (dbError(items)) return fail(503, 'DATABASE_UNAVAILABLE');
    const hard = ref('deleteCheck').action === 'hard';
    return done(200, { success: true, message: hard ? 'Nota eliminata' : 'Nota spostata nel cestino' });
  },

  restorePrepare({ json, config }) {
    const v = visitorFrom(json.headers, config);
    if (!v.ok) return v;
    const idr = idFrom(json.query);
    if (!idr.ok) return idr;
    return done(200, null, { id: idr.id, filter: { _id: idr.id, deletedAt: { $ne: null }, ...scopeFilter(v.visitorId, config) } });
  },
  restoreCheck({ items, ref }) {
    if (dbError(items)) return fail(503, 'DATABASE_UNAVAILABLE');
    const prep = ref('restorePrepare');
    if (!found(items)[0]) return fail(404, 'NOT_FOUND');
    return done(200, null, { _id: prep.id, deletedAt: null, updatedAt: nowIso() });
  },
  restoreResult({ items }) {
    if (dbError(items)) return fail(503, 'DATABASE_UNAVAILABLE');
    return done(200, { success: true, message: 'Nota ripristinata' });
  },

  exportPrepare({ json, config }) {
    const { filter, sort } = listFilter({}, readerId(json, config), config);
    return done(200, null, { filter, sort });
  },
  exportJsonResult({ items }) {
    if (dbError(items)) return fail(503, 'DATABASE_UNAVAILABLE');
    return done(200, found(items).map(toPublic));
  },
  exportMarkdownResult({ items }) {
    if (dbError(items)) return { ...fail(503, 'DATABASE_UNAVAILABLE'), contentType: 'application/json; charset=utf-8' };
    return done(200, buildMarkdown(found(items)), { contentType: 'text/markdown; charset=utf-8' });
  },

  // Reset della demo: chiamato dal cron di GitHub Actions e, con ifEmpty, all'avvio del container.
  resetPrepare({ json, config }) {
    const token = String((json.headers || {})['x-reset-token'] ?? '');
    if (!config.resetToken || token !== config.resetToken) return fail(401, 'RESET_UNAUTHORIZED');
    return done(200, null, { ifEmpty: isTrue((json.query || {}).ifEmpty) });
  },
  resetPlan({ items, ref }) {
    if (dbError(items)) return fail(503, 'DATABASE_UNAVAILABLE');
    const count = ((items || [])[0] || {}).n || 0;
    // ok = prosegui verso la cancellazione; con ifEmpty e dati presenti si risponde subito.
    if (ref('resetPrepare').ifEmpty && count > 0) return { ok: false, status: 200, payload: { success: true, message: 'Demo già pronta', entries: count } };
    return done(200, null, { count });
  },
  resetSeed({ config }) {
    const docs = seedToDocs(config.seed, new Date());
    if (!docs.length) throw new Error('Seed vuoto: manca api/seed/entries.json nel build');
    return docs;
  },
  resetResult({ items }) {
    if (dbError(items)) return fail(503, 'DATABASE_UNAVAILABLE');
    return done(200, { success: true, message: 'Demo ripristinata', entries: (items || []).filter((i) => i && i.id).length });
  },
};

// Dispatcher usato da ogni nodo Code: restituisce gli elementi n8n in uscita.
function run(name, ctx) {
  const fn = ENTRY[name];
  if (!fn) throw new Error(`Funzione di ingresso sconosciuta: ${name}`);
  const result = fn(ctx);
  return (Array.isArray(result) ? result : [result]).map((json) => ({ json }));
}

if (typeof module !== 'undefined') {
  module.exports = {
    CONFIG, TYPES, LIMITS, MESSAGES, DEMO_LIMITS, ENTRY, run,
    fail, done, isObjectId, toHexId, toPublic, normalizeEntryInput,
    escapeRegex, visitorFrom, scopeFilter, listFilter,
    romeWallTimeToUtc, seedToDocs, buildMarkdown,
  };
}
