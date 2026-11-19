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

if (typeof module !== 'undefined') {
  module.exports = {
    CONFIG, TYPES, LIMITS, MESSAGES,
    fail, done, isObjectId, toHexId, toPublic, normalizeEntryInput,
  };
}
