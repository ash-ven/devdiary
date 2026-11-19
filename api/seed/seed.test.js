const { test } = require('node:test');
const assert = require('node:assert/strict');
const lib = require('../code/lib');
const seed = require('./entries.json');

test('seed entries pass normalizeEntryInput', () => {
  for (const entry of seed) {
    const { daysAgo, time, ...note } = entry;
    const r = lib.normalizeEntryInput(note);
    assert.equal(r.ok, true, `${entry.title}: ${r.ok ? '' : r.payload.code}`);
    assert.equal(Number.isInteger(daysAgo) && daysAgo >= 0 && daysAgo <= 150, true, `${entry.title}: daysAgo`);
    assert.match(time, /^([01]\d|2[0-3]):[0-5]\d$/, `${entry.title}: time`);
  }
});

test('seed covers all five types', () => {
  for (const type of lib.TYPES) {
    assert.ok(seed.filter((e) => e.type === type).length >= 2, `almeno due note di tipo ${type}`);
  }
});

test('seed has notes for today and yesterday', () => {
  assert.ok(seed.some((e) => e.daysAgo === 0));
  assert.ok(seed.some((e) => e.daysAgo === 1));
});

test('seed error notes follow the problem, cause, solution template', () => {
  for (const entry of seed.filter((e) => e.type === 'errore')) {
    for (const heading of ['## Problema', '## Causa', '## Soluzione']) assert.ok(entry.content.includes(heading), `${entry.title}: ${heading}`);
  }
});

test('seed includes the mockup notes', () => {
  const titles = seed.map((e) => e.title);
  for (const title of [
    'n8n restituisce _id come {buffer}', 'getEntries con filtro per tipo', 'Flutter web senza Modalità sviluppatore',
    "Mostrare le chiamate API dentro l'app", 'Documentazione del package http', 'Workflow non risponde perché non pubblicato',
    'Query MongoDB per tipo', 'Appunti Flutter',
  ]) assert.ok(titles.includes(title), title);
});
