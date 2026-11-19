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

test('normalizeEntryInput keeps code indentation', () => {
  const code = '  final x = 1;\n    return x;\n';
  assert.equal(lib.normalizeEntryInput(valid({ code })).value.code, code);
});
