const { test } = require('node:test');
const assert = require('node:assert/strict');
const lib = require('./lib');

const HEX = '6afeb4a37ab5376904d214ad';
const BUFFER_ID = { buffer: { 0: 106, 1: 254, 2: 180, 3: 163, 4: 122, 5: 181, 6: 55, 7: 105, 8: 4, 9: 210, 10: 20, 11: 173 } };
const valid = (over = {}) => ({ title: 'Titolo', content: 'Contenuto', type: 'note', ...over });
const codeOf = (r) => (r.ok ? null : r.payload.code);

// ---------- Task 4: validazione e forma delle risposte ----------

test('fail uses the message table', () => {
  const r = lib.fail(404, 'NOT_FOUND');
  assert.equal(r.ok, false);
  assert.equal(r.status, 404);
  assert.deepEqual(r.payload, { error: true, code: 'NOT_FOUND', message: 'Nota non trovata' });
});

test('done carries status, payload and extra data', () => {
  assert.deepEqual(lib.done(201, { success: true }, { id: 'x' }), { ok: true, status: 201, payload: { success: true }, id: 'x' });
});

test('isObjectId accepts only 24 hex characters', () => {
  assert.equal(lib.isObjectId(HEX), true);
  for (const bad of ['', '123', HEX + '0', 'zzfeb4a37ab5376904d214ad', null, 42]) assert.equal(lib.isObjectId(bad), false, String(bad));
});

test('toHexId handles all shapes', () => {
  assert.equal(lib.toHexId(HEX), HEX);
  assert.equal(lib.toHexId({ toHexString: () => HEX }), HEX);
  assert.equal(lib.toHexId(BUFFER_ID), HEX);
  assert.equal(lib.toHexId(undefined), null);
});

test('toPublic strips ownerId', () => {
  const out = lib.toPublic({ _id: BUFFER_ID, title: 't', ownerId: 'x' });
  assert.equal('ownerId' in out, false);
  assert.equal(out._id, HEX);
  assert.equal(out.title, 't');
  assert.equal(out.isSample, false);
  assert.equal(out.deletedAt, null);
});

test('normalizeEntryInput rejects non-object bodies', () => {
  for (const body of [[], 'x', null, 42, undefined]) assert.equal(codeOf(lib.normalizeEntryInput(body)), 'BODY_INVALID', JSON.stringify(body));
});

test('normalizeEntryInput validates required fields', () => {
  assert.equal(codeOf(lib.normalizeEntryInput(valid({ title: '  ' }))), 'TITLE_REQUIRED');
  assert.equal(codeOf(lib.normalizeEntryInput({ title: 'T' })), 'CONTENT_REQUIRED');
  assert.equal(codeOf(lib.normalizeEntryInput(valid({ type: 'Bug' }))), 'TYPE_INVALID');
  assert.equal(lib.normalizeEntryInput(valid({ type: undefined })).value.type, 'note');
  assert.equal(lib.normalizeEntryInput(valid({ type: '' })).value.type, 'note');
  assert.equal(lib.normalizeEntryInput(valid({ type: ' Snippet ' })).value.type, 'snippet');
});

test('normalizeEntryInput enforces limits', () => {
  assert.equal(codeOf(lib.normalizeEntryInput(valid({ title: 'a'.repeat(121) }))), 'TITLE_TOO_LONG');
  assert.equal(lib.normalizeEntryInput(valid({ title: 'a'.repeat(120) })).ok, true);
  assert.equal(lib.normalizeEntryInput(valid({ title: '✓'.repeat(120) })).ok, true, 'le emoji contano un carattere');
  assert.equal(codeOf(lib.normalizeEntryInput(valid({ content: 'a'.repeat(10001) }))), 'CONTENT_TOO_LONG');
  assert.equal(codeOf(lib.normalizeEntryInput(valid({ code: 'a'.repeat(10001) }))), 'CODE_TOO_LONG');
  assert.equal(codeOf(lib.normalizeEntryInput(valid({ tags: Array.from({ length: 11 }, (_, i) => `t${i}`) }))), 'TOO_MANY_TAGS');
  assert.equal(codeOf(lib.normalizeEntryInput(valid({ tags: ['a'.repeat(31)] }))), 'TAG_TOO_LONG');
  assert.equal(lib.normalizeEntryInput(valid({ tags: ['a'.repeat(30)] })).ok, true);
});

test('normalizeEntryInput dedupes tags', () => {
  assert.deepEqual(lib.normalizeEntryInput(valid({ tags: 'Flutter, flutter , API,,' })).value.tags, ['flutter', 'api']);
  assert.deepEqual(lib.normalizeEntryInput(valid({ tags: [1, 'Dart'] })).value.tags, ['1', 'dart']);
  assert.deepEqual(lib.normalizeEntryInput(valid({ tags: undefined })).value.tags, []);
});

test('normalizeEntryInput normalizes optional fields', () => {
  const v = lib.normalizeEntryInput(valid({ title: '  perché più ✓  ', content: ' testo ', language: '  ', code: '', isFavorite: 'true' })).value;
  assert.equal(v.title, 'perché più ✓');
  assert.equal(v.content, 'testo');
  assert.equal(v.language, null);
  assert.equal(v.code, null);
  assert.equal(v.isFavorite, true);
  assert.equal(lib.normalizeEntryInput(valid({ isFavorite: 'yes' })).value.isFavorite, false);
  assert.equal(lib.normalizeEntryInput(valid({ isFavorite: true })).value.isFavorite, true);
  assert.equal(lib.normalizeEntryInput(valid({ language: ' Dart ' })).value.language, 'dart');
});

test('normalizeEntryInput rejects non-text fields', () => {
  const cases = [
    { title: { toString: 1 } }, { title: { a: 1 } }, { content: ['a', 'b'] }, { type: {} },
    { language: [] }, { code: {} }, { tags: [{}] }, { tags: [['a']] }, { tags: 5 }, { tags: { a: 1 } },
  ];
  for (const over of cases) assert.equal(codeOf(lib.normalizeEntryInput(valid(over))), 'FIELD_INVALID', JSON.stringify(over));
});

test('normalizeEntryInput accepts numbers as text', () => {
  const v = lib.normalizeEntryInput(valid({ title: 2026, content: 42 })).value;
  assert.equal(v.title, '2026');
  assert.equal(v.content, '42');
});

test('normalizeEntryInput keeps code indentation', () => {
  const code = '  final x = 1;\n    return x;\n';
  assert.equal(lib.normalizeEntryInput(valid({ code })).value.code, code);
});

// ---------- Task 5: filtri, visibilità della demo, seed, export ----------

const DEMO = { demoMode: true, resetToken: 't', seed: [] };
const OFF = { demoMode: false, resetToken: 't', seed: [] };
const UUID = '3f1c2a9e-5b7d-4c8e-9a1f-2b3c4d5e6f70';

test('escapeRegex escapes every special character', () => {
  assert.equal(lib.escapeRegex('a.b*c+d?e^f$g{h}i(j)k|l[m]n\\o'), 'a\\.b\\*c\\+d\\?e\\^f\\$g\\{h\\}i\\(j\\)k\\|l\\[m\\]n\\\\o');
});

test('listFilter escapes regex', () => {
  const { filter } = lib.listFilter({ search: 'c++ (' }, null, OFF);
  assert.equal(filter.$or[0].title.$regex, 'c\\+\\+ \\(');
  assert.equal(filter.$or[0].title.$options, 'i');
  assert.equal(filter.$or[1].content.$regex, 'c\\+\\+ \\(');
});

test('listFilter maps query params', () => {
  const r = lib.listFilter({ type: 'Snippet', favorite: 'true', tag: ' Flutter ' }, null, OFF);
  assert.equal(r.filter.type, 'snippet');
  assert.equal(r.filter.isFavorite, true);
  assert.equal(r.filter.tags, 'flutter');
  assert.equal(r.filter.deletedAt, null);
  assert.deepEqual(r.sort, { createdAt: -1 });
  assert.deepEqual(lib.listFilter({ trash: 'true' }, null, OFF).filter.deletedAt, { $ne: null });
  assert.equal(lib.listFilter({ favorite: 'false' }, null, OFF).filter.isFavorite, false);
  assert.equal('isFavorite' in lib.listFilter({ favorite: '' }, null, OFF).filter, false);
  assert.equal('$or' in lib.listFilter({ search: '   ' }, null, OFF).filter, false);
});

test('listFilter combines search and demo scope', () => {
  const { filter } = lib.listFilter({ search: 'mongo' }, UUID, DEMO);
  assert.ok(Array.isArray(filter.$and), 'serve $and quando ci sono due $or');
  assert.deepEqual(filter.$and[0], { $or: [{ isSample: true }, { ownerId: UUID }] });
  assert.equal(filter.$and[1].$or[0].title.$regex, 'mongo');
  assert.equal('$or' in filter, false);
});

test('listFilter applies demo scope without search', () => {
  const { filter } = lib.listFilter({}, UUID, DEMO);
  assert.deepEqual(filter.$or, [{ isSample: true }, { ownerId: UUID }]);
});

test('visitorFrom rejects malformed ids', () => {
  for (const headers of [{}, { 'x-demo-visitor': '' }, { 'x-demo-visitor': 'abc' }, { 'x-demo-visitor': 'a'.repeat(200) }]) {
    assert.equal(codeOf(lib.visitorFrom(headers, DEMO)), 'VISITOR_REQUIRED', JSON.stringify(headers));
  }
  assert.deepEqual(lib.visitorFrom({ 'x-demo-visitor': UUID }, DEMO), { ok: true, visitorId: UUID });
  assert.deepEqual(lib.visitorFrom({ 'x-demo-visitor': UUID.toUpperCase() }, DEMO), { ok: true, visitorId: UUID });
  assert.deepEqual(lib.visitorFrom({}, OFF), { ok: true, visitorId: null });
  assert.deepEqual(lib.visitorFrom({ 'x-demo-visitor': UUID }, OFF), { ok: true, visitorId: null });
});

test('scopeFilter', () => {
  assert.deepEqual(lib.scopeFilter('u', OFF), {});
  assert.deepEqual(lib.scopeFilter('u', DEMO), { $or: [{ isSample: true }, { ownerId: 'u' }] });
});

test('romeWallTimeToUtc handles daylight saving', () => {
  assert.equal(lib.romeWallTimeToUtc(2026, 11, 19, 9, 34).toISOString(), '2026-11-19T08:34:00.000Z');
  assert.equal(lib.romeWallTimeToUtc(2026, 8, 14, 22, 58).toISOString(), '2026-08-14T20:58:00.000Z');
});

test('seedToDocs dates relative to now', () => {
  const seed = [{ title: 'T', content: 'C', type: 'idea', language: null, code: null, tags: ['x'], isFavorite: false, daysAgo: 1, time: '18:20' }];
  const [doc] = lib.seedToDocs(seed, new Date('2026-11-19T10:00:00Z'));
  assert.equal(doc.createdAt, '2026-11-18T17:20:00.000Z');
  assert.equal(doc.updatedAt, doc.createdAt);
  assert.equal(doc.isSample, true);
  assert.equal(doc.ownerId, null);
  assert.equal(doc.deletedAt, null);
  assert.equal('daysAgo' in doc, false);
  assert.equal('time' in doc, false);
  assert.equal(doc.title, 'T');
});

test('seedToDocs counts days in Rome, not UTC', () => {
  // 23:30 UTC del 19/11 è già il 20/11 a Roma: "oggi" è il 20, "ieri" il 19.
  const [doc] = lib.seedToDocs([{ title: 'T', content: 'C', type: 'note', tags: [], isFavorite: false, daysAgo: 1, time: '09:00' }], new Date('2026-11-19T23:30:00Z'));
  assert.equal(doc.createdAt, '2026-11-19T08:00:00.000Z');
});

test('seedToDocs never dates today\'s notes in the future', () => {
  // Reset delle 3 di notte a Roma: le note di oggi delle 10:12 e delle 09:00 non sono ancora avvenute.
  const now = new Date('2026-11-20T02:17:00Z');
  const note = (time) => ({ title: 'T', content: 'C', type: 'note', tags: [], isFavorite: false, daysAgo: 0, time });
  const docs = lib.seedToDocs([note('00:30'), note('10:12'), note('09:00')], now);
  assert.equal(docs[0].createdAt, '2026-11-19T23:30:00.000Z');
  // indice nel seed + 1 minuti prima di adesso
  assert.equal(docs[1].createdAt, '2026-11-20T02:15:00.000Z');
  assert.equal(docs[2].createdAt, '2026-11-20T02:14:00.000Z');
  for (const doc of docs) {
    assert.ok(doc.createdAt <= now.toISOString());
    assert.equal(doc.updatedAt, doc.createdAt);
  }
});

test('buildMarkdown', () => {
  const md = lib.buildMarkdown([
    { title: 'Prima', type: 'note', tags: ['a', 'b'], content: 'Testo' },
    { title: 'Seconda', type: 'snippet', tags: [], content: 'Codice', language: 'dart', code: 'void main() {}' },
  ]);
  assert.ok(md.startsWith('# DevDiary Export\n\n'));
  assert.ok(md.includes('## Prima\n\n'));
  assert.ok(md.includes('**Tipo:** snippet'));
  assert.ok(md.includes('**Tag:** #a #b'));
  assert.ok(md.includes('```dart\nvoid main() {}\n```'));
  assert.ok(md.includes('**Linguaggio:** dart'));
});
