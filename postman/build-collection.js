// Genera postman/devdiary-api.postman_collection.json da questa descrizione leggibile.
// Uso: node postman/build-collection.js
const fs = require('node:fs');
const path = require('node:path');

const json = (obj) => JSON.stringify(obj, null, 2);
const T = (name, assertion) => `pm.test(${JSON.stringify(name)}, () => { ${assertion} });`;
const status = (code) => T(`status ${code}`, `pm.response.to.have.status(${code});`);
const errorIs = (code) => [
  T('errore con error, code e message', "const e = pm.response.json(); pm.expect(e.error).to.eql(true); pm.expect(e.message).to.be.a('string').and.not.empty;"),
  T(`codice ${code}`, `pm.expect(pm.response.json().code).to.eql(${JSON.stringify(code)});`),
];
const messageIs = (message) => T(`messaggio "${message}"`, `pm.expect(pm.response.json().message).to.eql(${JSON.stringify(message)});`);
const listHas = (varName, expected) => T(
  `${expected ? 'contiene' : 'non contiene'} {{${varName}}}`,
  `const ids = pm.response.json().map(e => e._id); pm.expect(ids.includes(pm.collectionVariables.get('${varName}'))).to.eql(${expected});`,
);

function request(name, method, url, { body, rawBody, headers = [], pre = [], tests = [] } = {}) {
  const item = { name, event: [], request: { method, header: [...headers], url } };
  if (pre.length) item.event.push({ listen: 'prerequest', script: { type: 'text/javascript', exec: pre } });
  if (tests.length) item.event.push({ listen: 'test', script: { type: 'text/javascript', exec: tests } });
  if (body !== undefined || rawBody !== undefined) {
    item.request.header.push({ key: 'Content-Type', value: 'application/json' });
    item.request.body = { mode: 'raw', raw: rawBody !== undefined ? rawBody : json(body) };
  }
  return item;
}

// Controllo comune a tutte le risposte JSON: l'API non deve mai esporre ownerId.
const noOwnerId = [
  "const ct = pm.response.headers.get('Content-Type') || '';",
  "if (ct.includes('json')) pm.test('nessun ownerId nella risposta', () => pm.expect(pm.response.text()).to.not.include('ownerId'));",
];

const contratto = [
  request('GET status', 'GET', '{{baseUrl}}/status', { tests: [status(200), T('stato e database OK', "pm.expect(pm.response.json()).to.eql({ status: 'OK', database: 'OK' });")] }),
  request('POST crea nota', 'POST', '{{baseUrl}}/diary', {
    pre: ["pm.collectionVariables.set('runTag', 'newman' + Date.now());"],
    body: { title: 'Nota {{runTag}}', content: 'Creata dai test di contratto', type: 'note', tags: 'newman, test' },
    tests: [status(201), messageIs('Nota creata correttamente'),
      T('_id esadecimale di 24 caratteri', "pm.expect(pm.response.json()._id).to.match(/^[0-9a-f]{24}$/);"),
      "pm.collectionVariables.set('noteId', pm.response.json()._id);"],
  }),
  request('GET lista', 'GET', '{{baseUrl}}/diary?search={{runTag}}', {
    tests: [status(200), T('array', "pm.expect(pm.response.json()).to.be.an('array');"),
      T('ogni _id e esadecimale', "pm.response.json().forEach(e => pm.expect(e._id).to.match(/^[0-9a-f]{24}$/));"),
      listHas('noteId', true)],
  }),
  request('GET dettaglio', 'GET', '{{baseUrl}}/diary/detail?id={{noteId}}', {
    tests: [status(200), T('e la nota richiesta', "pm.expect(pm.response.json()._id).to.eql(pm.collectionVariables.get('noteId'));")],
  }),
  request('PUT modifica', 'PUT', '{{baseUrl}}/diary?id={{noteId}}', {
    body: { title: 'Nota {{runTag}} modificata', content: 'Contenuto aggiornato', type: 'idea', tags: ['newman'], isFavorite: true },
    tests: [status(200), messageIs('Nota aggiornata correttamente')],
  }),
  request('POST Unicode', 'POST', '{{baseUrl}}/diary', {
    body: { title: 'perché più ✓ {{runTag}}', content: 'Accenti, emoji ✓ e virgolette “tipografiche”', type: 'note' },
    tests: [status(201), "pm.collectionVariables.set('unicodeId', pm.response.json()._id);"],
  }),
  request('GET Unicode round-trip', 'GET', '{{baseUrl}}/diary/detail?id={{unicodeId}}', {
    tests: [status(200), T('titolo identico', "pm.expect(pm.response.json().title).to.eql('perché più ✓ ' + pm.collectionVariables.get('runTag'));"),
      T('contenuto identico', "pm.expect(pm.response.json().content).to.eql('Accenti, emoji ✓ e virgolette “tipografiche”');")],
  }),
  request('GET ricerca con caratteri speciali', 'GET', '{{baseUrl}}/diary?search=c%2B%2B%20(', {
    tests: [status(200), T('array', "pm.expect(pm.response.json()).to.be.an('array');")],
  }),
  request('POST corpo array', 'POST', '{{baseUrl}}/diary', { rawBody: '[]', tests: [status(400), ...errorIs('BODY_INVALID')] }),
  request('POST corpo stringa', 'POST', '{{baseUrl}}/diary', { rawBody: '"x"', tests: [status(400), ...errorIs('BODY_INVALID')] }),
  request('POST titolo troppo lungo', 'POST', '{{baseUrl}}/diary', {
    pre: ["pm.variables.set('longTitle', 'a'.repeat(121));"],
    body: { title: '{{longTitle}}', content: 'x', type: 'note' },
    tests: [status(400), ...errorIs('TITLE_TOO_LONG')],
  }),
  request('POST senza titolo', 'POST', '{{baseUrl}}/diary', { body: { content: 'Senza titolo', type: 'note' }, tests: [status(400), ...errorIs('TITLE_REQUIRED')] }),
  request('POST senza contenuto', 'POST', '{{baseUrl}}/diary', { body: { title: 'Senza contenuto', type: 'note' }, tests: [status(400), ...errorIs('CONTENT_REQUIRED')] }),
  request('POST tipo non valido', 'POST', '{{baseUrl}}/diary', { body: { title: 'Tipo sbagliato', content: 'x', type: 'bug' }, tests: [status(400), ...errorIs('TYPE_INVALID')] }),
  request('GET dettaglio senza id', 'GET', '{{baseUrl}}/diary/detail', { tests: [status(400), ...errorIs('ID_REQUIRED')] }),
  request('GET dettaglio id non valido', 'GET', '{{baseUrl}}/diary/detail?id=123', { tests: [status(400), ...errorIs('ID_INVALID')] }),
  request('GET dettaglio inesistente', 'GET', '{{baseUrl}}/diary/detail?id=000000000000000000000000', { tests: [status(404), ...errorIs('NOT_FOUND')] }),
  request('GET export json', 'GET', '{{baseUrl}}/diary/export/json', { tests: [status(200), T('array', "pm.expect(pm.response.json()).to.be.an('array');"), listHas('noteId', true)] }),
  request('GET export markdown', 'GET', '{{baseUrl}}/diary/export/markdown', {
    tests: [status(200), T('testo Markdown', "pm.expect(pm.response.text().startsWith('# DevDiary Export')).to.eql(true);")],
  }),
  request('DELETE definitivo fuori dal cestino', 'DELETE', '{{baseUrl}}/diary?id={{noteId}}&permanent=true', { tests: [status(409), ...errorIs('NOT_IN_TRASH')] }),
  request('DELETE sposta nel cestino', 'DELETE', '{{baseUrl}}/diary?id={{noteId}}', { tests: [status(200), messageIs('Nota spostata nel cestino')] }),
  request('GET lista senza la nota nel cestino', 'GET', '{{baseUrl}}/diary?search={{runTag}}', { tests: [status(200), listHas('noteId', false)] }),
  request('GET cestino', 'GET', '{{baseUrl}}/diary?trash=true&search={{runTag}}', {
    tests: [status(200), listHas('noteId', true),
      T('deletedAt valorizzato', "const n = pm.response.json().find(e => e._id === pm.collectionVariables.get('noteId')); pm.expect(n.deletedAt).to.be.a('string');")],
  }),
  request('GET dettaglio nota nel cestino', 'GET', '{{baseUrl}}/diary/detail?id={{noteId}}', { tests: [status(404), ...errorIs('NOT_FOUND')] }),
  request('GET dettaglio nel cestino con trash', 'GET', '{{baseUrl}}/diary/detail?id={{noteId}}&trash=true', { tests: [status(200)] }),
  request('GET export json senza cestino', 'GET', '{{baseUrl}}/diary/export/json', { tests: [status(200), listHas('noteId', false)] }),
  request('POST ripristina', 'POST', '{{baseUrl}}/diary/restore?id={{noteId}}', { tests: [status(200), messageIs('Nota ripristinata')] }),
  request('GET lista dopo il ripristino', 'GET', '{{baseUrl}}/diary?search={{runTag}}', { tests: [status(200), listHas('noteId', true)] }),
  request('DELETE di nuovo nel cestino', 'DELETE', '{{baseUrl}}/diary?id={{noteId}}', { tests: [status(200)] }),
  request('DELETE definitivo', 'DELETE', '{{baseUrl}}/diary?id={{noteId}}&permanent=true', { tests: [status(200), messageIs('Nota eliminata')] }),
  request('POST ripristina nota eliminata', 'POST', '{{baseUrl}}/diary/restore?id={{noteId}}', { tests: [status(404), ...errorIs('NOT_FOUND')] }),
  request('DELETE pulizia nota Unicode', 'DELETE', '{{baseUrl}}/diary?id={{unicodeId}}', { tests: [status(200)] }),
];

const demo = [];

const collection = {
  info: {
    name: 'DevDiary API',
    description: "Test di contratto dell'API DevDiary (n8n + MongoDB). Cartella Contratto: comportamento della traccia (DEMO_MODE=false). Cartella Demo: regole della demo pubblica (DEMO_MODE=true). File generato da postman/build-collection.js.",
    schema: 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
  },
  event: [{ listen: 'test', script: { type: 'text/javascript', exec: noOwnerId } }],
  item: [
    { name: 'Contratto', item: contratto },
    { name: 'Demo', item: demo },
  ],
};

fs.writeFileSync(path.join(__dirname, 'devdiary-api.postman_collection.json'), json(collection) + '\n');
console.log(`collection: ${contratto.length} richieste Contratto, ${demo.length} Demo`);
