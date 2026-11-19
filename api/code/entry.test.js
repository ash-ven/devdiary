// Test delle funzioni di ingresso dei nodi Code (una per nodo del workflow).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const lib = require('./lib');

const HEX = '6afeb4a37ab5376904d214ad';
const BUFFER_ID = { buffer: { 0: 106, 1: 254, 2: 180, 3: 163, 4: 122, 5: 181, 6: 55, 7: 105, 8: 4, 9: 210, 10: 20, 11: 173 } };
const UUID = '3f1c2a9e-5b7d-4c8e-9a1f-2b3c4d5e6f70';
const DEMO = { demoMode: true, resetToken: 'secret', seed: [] };
const OFF = { demoMode: false, resetToken: 'secret', seed: [] };

// Esegue una funzione di ingresso come farebbe il nodo Code e restituisce il json dell'unico elemento.
function call(name, { json = {}, items, refs = {}, config = OFF } = {}) {
  const out = lib.run(name, { json, items: items || [json], ref: (n) => refs[n], config });
  assert.equal(out.length, 1, `${name} deve restituire un solo elemento`);
  return out[0].json;
}
const code = (r) => r.payload && r.payload.code;

test('run dispatches by name and rejects unknown functions', () => {
  assert.equal(call('statusResult', { items: [{}] }).status, 200);
  assert.throws(() => lib.run('nope', { json: {}, items: [], ref: () => ({}), config: OFF }), /nope/);
});

test('scopeFilter shows only samples to an anonymous demo visitor', () => {
  assert.deepEqual(lib.scopeFilter(null, DEMO), { $or: [{ isSample: true }] });
});

// ---------- status ----------

test('statusResult reports database ok', () => {
  const r = call('statusResult', { items: [{}] });
  assert.equal(r.status, 200);
  assert.deepEqual(r.payload, { status: 'OK', database: 'OK' });
});

test('statusResult reports database error', () => {
  const r = call('statusResult', { items: [{ error: 'connessione rifiutata' }] });
  assert.equal(r.status, 503);
  assert.deepEqual(r.payload, { status: 'OK', database: 'ERROR' });
});

// ---------- lista ----------

test('listPrepare builds filter from query', () => {
  const r = call('listPrepare', { json: { query: { type: 'Snippet' }, headers: {} } });
  assert.equal(r.ok, true);
  assert.equal(r.filter.type, 'snippet');
  assert.deepEqual(r.sort, { createdAt: -1 });
});

test('listPrepare shows only samples to a demo visitor without id', () => {
  const r = call('listPrepare', { json: { query: {}, headers: {} }, config: DEMO });
  assert.equal(r.ok, true);
  assert.deepEqual(r.filter.$or, [{ isSample: true }]);
});

test('listPrepare scopes a demo visitor', () => {
  const r = call('listPrepare', { json: { query: {}, headers: { 'x-demo-visitor': UUID } }, config: DEMO });
  assert.deepEqual(r.filter.$or, [{ isSample: true }, { ownerId: UUID }]);
});

test('listResult returns public notes', () => {
  const r = call('listResult', { items: [{ _id: BUFFER_ID, ownerId: 'x', title: 't' }] });
  assert.equal(r.status, 200);
  assert.equal(r.payload.length, 1);
  assert.equal(r.payload[0]._id, HEX);
  assert.equal('ownerId' in r.payload[0], false);
});

test('listResult returns an empty list for an empty result', () => {
  assert.deepEqual(call('listResult', { items: [{}] }).payload, []);
});

test('listResult reports database error', () => {
  const r = call('listResult', { items: [{ error: 'x' }] });
  assert.equal(r.status, 503);
  assert.equal(code(r), 'DATABASE_UNAVAILABLE');
});

// ---------- dettaglio ----------

test('detailPrepare requires id', () => {
  assert.equal(code(call('detailPrepare', { json: { query: {}, headers: {} } })), 'ID_REQUIRED');
});

test('detailPrepare rejects invalid id', () => {
  assert.equal(code(call('detailPrepare', { json: { query: { id: '123' }, headers: {} } })), 'ID_INVALID');
});

test('detailPrepare excludes trash unless asked', () => {
  const r = call('detailPrepare', { json: { query: { id: HEX }, headers: {} } });
  assert.equal(r.filter._id, HEX);
  assert.equal(r.filter.deletedAt, null);
  const t = call('detailPrepare', { json: { query: { id: HEX, trash: 'true' }, headers: {} } });
  assert.deepEqual(t.filter.deletedAt, { $ne: null });
});

test('detailResult returns 404 when nothing is found', () => {
  const r = call('detailResult', { items: [{}] });
  assert.equal(r.status, 404);
  assert.equal(code(r), 'NOT_FOUND');
});

test('detailResult returns the public note', () => {
  const r = call('detailResult', { items: [{ _id: BUFFER_ID, ownerId: 'x', title: 't' }] });
  assert.equal(r.status, 200);
  assert.equal(r.payload._id, HEX);
  assert.equal('ownerId' in r.payload, false);
});

// ---------- creazione ----------

test('createPrepare requires a visitor in demo', () => {
  assert.equal(code(call('createPrepare', { json: { body: { title: 't', content: 'c' }, headers: {} }, config: DEMO })), 'VISITOR_REQUIRED');
});

test('createPrepare validates the body', () => {
  assert.equal(code(call('createPrepare', { json: { body: [], headers: {} } })), 'BODY_INVALID');
});

test('createPrepare builds the document', () => {
  const r = call('createPrepare', { json: { body: { title: ' T ', content: 'C', tags: 'A' }, headers: {} } });
  assert.equal(r.ok, true);
  assert.equal(r.doc.title, 'T');
  assert.deepEqual(r.doc.tags, ['a']);
  assert.equal(r.doc.isSample, false);
  assert.equal(r.doc.ownerId, null);
  assert.equal(r.doc.deletedAt, null);
  assert.equal(typeof r.doc.createdAt, 'string');
  assert.equal(r.doc.createdAt, r.doc.updatedAt);
  assert.ok(Array.isArray(r.pipeline));
});

test('createPrepare stores the demo visitor as owner', () => {
  const r = call('createPrepare', { json: { body: { title: 'T', content: 'C' }, headers: { 'x-demo-visitor': UUID } }, config: DEMO });
  assert.equal(r.doc.ownerId, UUID);
});

const prepared = { createPrepare: { ok: true, doc: { title: 'T', content: 'C', type: 'note', ownerId: UUID } } };

test('createCheckLimits passes outside demo', () => {
  const r = call('createCheckLimits', { items: [{ total: [{ n: 9999 }], mine: [{ n: 9999 }] }], refs: prepared });
  assert.equal(r.ok, true);
  assert.equal(r.title, 'T', 'i campi del documento stanno al primo livello per il nodo insert');
});

test('createCheckLimits rejects a visitor over the limit', () => {
  const r = call('createCheckLimits', { items: [{ total: [{ n: 10 }], mine: [{ n: 50 }] }], refs: prepared, config: DEMO });
  assert.equal(r.status, 429);
  assert.equal(code(r), 'DEMO_LIMIT_REACHED');
});

test('createCheckLimits rejects when the demo is full', () => {
  assert.equal(code(call('createCheckLimits', { items: [{ total: [{ n: 300 }], mine: [] }], refs: prepared, config: DEMO })), 'DEMO_LIMIT_REACHED');
});

test('createCheckLimits passes under the limits', () => {
  assert.equal(call('createCheckLimits', { items: [{ total: [], mine: [] }], refs: prepared, config: DEMO }).ok, true);
});

test('createCheckLimits reports database error', () => {
  assert.equal(code(call('createCheckLimits', { items: [{ error: 'x' }], refs: prepared, config: DEMO })), 'DATABASE_UNAVAILABLE');
});

test('createResult returns the new id', () => {
  const r = call('createResult', { items: [{ id: BUFFER_ID, title: 'T' }] });
  assert.equal(r.status, 201);
  assert.deepEqual(r.payload, { success: true, message: 'Nota creata correttamente', _id: HEX });
});

// ---------- modifica ----------

const updatePrepared = { updatePrepare: { ok: true, id: HEX, update: { title: 'Nuovo', content: 'C', type: 'note', language: null, code: null, tags: [], isFavorite: false } } };

test('updatePrepare requires id and a valid body', () => {
  assert.equal(code(call('updatePrepare', { json: { query: {}, body: {}, headers: {} } })), 'ID_REQUIRED');
  assert.equal(code(call('updatePrepare', { json: { query: { id: HEX }, body: 'x', headers: {} } })), 'BODY_INVALID');
});

test('updateCheck returns 404 when the note is missing', () => {
  assert.equal(code(call('updateCheck', { items: [{}], refs: updatePrepared })), 'NOT_FOUND');
});

test('updateCheck returns 404 for a note in the trash', () => {
  assert.equal(code(call('updateCheck', { items: [{ _id: HEX, deletedAt: '2026-01-01T00:00:00.000Z' }], refs: updatePrepared })), 'NOT_FOUND');
});

test('updateCheck forbids samples in demo', () => {
  const r = call('updateCheck', { items: [{ _id: HEX, isSample: true }], refs: updatePrepared, config: DEMO });
  assert.equal(r.status, 403);
  assert.equal(code(r), 'SAMPLE_READ_ONLY');
});

test('updateCheck allows samples outside demo', () => {
  assert.equal(call('updateCheck', { items: [{ _id: HEX, isSample: true }], refs: updatePrepared }).ok, true);
});

test('updateCheck builds the update item', () => {
  const r = call('updateCheck', { items: [{ _id: BUFFER_ID }], refs: updatePrepared });
  assert.equal(r._id, HEX, 'il nodo update vuole _id come stringa');
  assert.equal(r.title, 'Nuovo');
  assert.equal(typeof r.updatedAt, 'string');
});

test('updateResult confirms', () => {
  assert.deepEqual(call('updateResult', { items: [{}] }).payload, { success: true, message: 'Nota aggiornata correttamente' });
});

// ---------- eliminazione ----------

const softPrepared = { deletePrepare: { ok: true, id: HEX, action: 'soft' } };
const hardPrepared = { deletePrepare: { ok: true, id: HEX, action: 'hard' } };

test('deletePrepare marks permanent deletes as hard', () => {
  assert.equal(call('deletePrepare', { json: { query: { id: HEX, permanent: 'true' }, headers: {} } }).action, 'hard');
  assert.equal(call('deletePrepare', { json: { query: { id: HEX }, headers: {} } }).action, 'soft');
});

test('deleteCheck rejects hard delete outside trash', () => {
  const r = call('deleteCheck', { items: [{ _id: HEX, deletedAt: null }], refs: hardPrepared });
  assert.equal(r.status, 409);
  assert.equal(code(r), 'NOT_IN_TRASH');
});

test('deleteCheck hides a note already in the trash from soft delete', () => {
  assert.equal(code(call('deleteCheck', { items: [{ _id: HEX, deletedAt: '2026-01-01T00:00:00.000Z' }], refs: softPrepared })), 'NOT_FOUND');
});

test('deleteCheck forbids samples in demo', () => {
  assert.equal(code(call('deleteCheck', { items: [{ _id: HEX, isSample: true }], refs: softPrepared, config: DEMO })), 'SAMPLE_READ_ONLY');
});

test('deleteCheck prepares a soft delete', () => {
  const r = call('deleteCheck', { items: [{ _id: HEX }], refs: softPrepared });
  assert.equal(r.action, 'soft');
  assert.equal(r._id, HEX);
  assert.equal(typeof r.deletedAt, 'string');
});

test('deleteCheck prepares a hard delete filter', () => {
  const r = call('deleteCheck', { items: [{ _id: HEX, deletedAt: '2026-01-01T00:00:00.000Z' }], refs: hardPrepared });
  assert.equal(r.action, 'hard');
  assert.deepEqual(r.filter, { $expr: { $eq: [{ $toString: '$_id' }, HEX] } });
});

test('deleteResult messages', () => {
  assert.equal(call('deleteResult', { items: [{}], refs: { deleteCheck: { action: 'soft' } } }).payload.message, 'Nota spostata nel cestino');
  assert.equal(call('deleteResult', { items: [{ deletedCount: 1 }], refs: { deleteCheck: { action: 'hard' } } }).payload.message, 'Nota eliminata');
});

// ---------- ripristino ----------

test('restorePrepare looks only in the trash', () => {
  const r = call('restorePrepare', { json: { query: { id: HEX }, headers: {} } });
  assert.deepEqual(r.filter.deletedAt, { $ne: null });
});

test('restoreCheck returns 404 when the note is not in the trash', () => {
  assert.equal(code(call('restoreCheck', { items: [{}], refs: { restorePrepare: { ok: true, id: HEX } } })), 'NOT_FOUND');
});

test('restoreCheck prepares the restore', () => {
  const r = call('restoreCheck', { items: [{ _id: HEX, deletedAt: '2026-01-01T00:00:00.000Z' }], refs: { restorePrepare: { ok: true, id: HEX } } });
  assert.equal(r.ok, true);
  assert.equal(r._id, HEX);
  assert.equal(r.deletedAt, null);
});

test('restoreResult confirms', () => {
  assert.deepEqual(call('restoreResult', { items: [{}] }).payload, { success: true, message: 'Nota ripristinata' });
});

// ---------- export ----------

test('exportPrepare excludes the trash', () => {
  const r = call('exportPrepare', { json: { query: { trash: 'true' }, headers: {} } });
  assert.equal(r.filter.deletedAt, null);
});

test('exportJsonResult returns public notes', () => {
  const r = call('exportJsonResult', { items: [{ _id: BUFFER_ID, ownerId: 'x' }] });
  assert.equal(r.payload[0]._id, HEX);
  assert.equal('ownerId' in r.payload[0], false);
});

// ---------- reset della demo ----------

const SEED = [
  { title: 'Uno', content: 'C', type: 'note', language: null, code: null, tags: [], isFavorite: false, daysAgo: 0, time: '09:00' },
  { title: 'Due', content: 'C', type: 'idea', language: null, code: null, tags: ['x'], isFavorite: true, daysAgo: 3, time: '18:30' },
];

test('resetPrepare rejects missing token', () => {
  const r = call('resetPrepare', { json: { query: {}, headers: {} } });
  assert.equal(r.status, 401);
  assert.equal(code(r), 'RESET_UNAUTHORIZED');
});

test('resetPrepare rejects wrong token', () => {
  assert.equal(code(call('resetPrepare', { json: { query: {}, headers: { 'x-reset-token': 'sbagliato' } } })), 'RESET_UNAUTHORIZED');
});

test('resetPrepare rejects everything when no token is configured', () => {
  const r = call('resetPrepare', { json: { query: {}, headers: { 'x-reset-token': '' } }, config: { ...OFF, resetToken: '' } });
  assert.equal(code(r), 'RESET_UNAUTHORIZED');
});

test('resetPrepare accepts the right token', () => {
  const r = call('resetPrepare', { json: { query: { ifEmpty: 'true' }, headers: { 'x-reset-token': 'secret' } } });
  assert.equal(r.ok, true);
  assert.equal(r.ifEmpty, true);
});

test('resetPlan skips when not empty and ifEmpty', () => {
  const r = call('resetPlan', { items: [{ n: 7 }], refs: { resetPrepare: { ok: true, ifEmpty: true } } });
  assert.equal(r.ok, false, 'non prosegue verso la cancellazione');
  assert.equal(r.status, 200);
  assert.deepEqual(r.payload, { success: true, message: 'Demo già pronta', entries: 7 });
});

test('resetPlan proceeds without ifEmpty', () => {
  assert.equal(call('resetPlan', { items: [{ n: 7 }], refs: { resetPrepare: { ok: true, ifEmpty: false } } }).ok, true);
});

test('resetPlan proceeds on an empty database', () => {
  assert.equal(call('resetPlan', { items: [{}], refs: { resetPrepare: { ok: true, ifEmpty: true } } }).ok, true);
});

test('resetSeed returns one item per seed entry with isSample true', () => {
  const out = lib.run('resetSeed', { json: {}, items: [{ deletedCount: 3 }], ref: () => ({}), config: { ...OFF, seed: SEED } });
  assert.equal(out.length, 2);
  for (const { json } of out) {
    assert.equal(json.isSample, true);
    assert.equal(json.ownerId, null);
    assert.equal(json.deletedAt, null);
    assert.equal(typeof json.createdAt, 'string');
  }
});

test('resetSeed fails loudly without seed', () => {
  assert.throws(() => lib.run('resetSeed', { json: {}, items: [{}], ref: () => ({}), config: OFF }), /Seed vuoto/);
});

test('resetResult counts the inserted notes', () => {
  const r = call('resetResult', { items: [{ id: HEX }, { id: HEX }] });
  assert.equal(r.status, 200);
  assert.deepEqual(r.payload, { success: true, message: 'Demo ripristinata', entries: 2 });
});

test('exportMarkdownResult returns markdown text', () => {
  const r = call('exportMarkdownResult', { items: [{ _id: HEX, title: 'T', type: 'note', tags: [], content: 'C' }] });
  assert.equal(r.status, 200);
  assert.ok(r.payload.startsWith('# DevDiary Export'));
  assert.equal(r.contentType, 'text/markdown; charset=utf-8');
});
