# DevDiary 1: repository e API, piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** creare il repository `C:\Dev\devdiary` con la storia della consegna e un'API n8n completa, testata e pronta per la produzione (cestino, demo protetta, reset, limiti, codici di errore), eseguibile in locale con un solo `docker compose up`.

**Architecture:** la logica dei nodi Code vive in un unico file JavaScript (`api/code/lib.js`) testato con `node:test`; uno script di build la inietta nel workflow n8n. Un container basato su `n8nio/n8n:1.123.95` importa workflow e credenziali a ogni avvio e mette davanti a n8n un piccolo proxy Node che espone solo `/webhook/*` e `/healthz`. I test di contratto sono una collection Postman eseguita con Newman contro due istanze locali: `DEMO_MODE=false` e `DEMO_MODE=true`.

**Tech Stack:** n8n 1.123.95, MongoDB 6.0 (locale) / Atlas (produzione, piano 2), Node 22 (`node:test`, nessuna dipendenza npm a runtime), Docker Compose, Postman + Newman 6.2.1, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-19-devdiary-portfolio-design.md` (sezioni 6.1, 6.2, 6.3, 6.6, 6.7).

**Piani successivi** (scritti al termine di questo): 2. pubblicazione anticipata (Atlas, Render, cron di reset, app web-only con `API_BASE_URL` e intestazione `X-Demo-Visitor`); 3. nuova interfaccia; 4. documentazione e materiali per il portfolio.

## Global Constraints

- n8n fissato a `n8nio/n8n:1.123.95`; MongoDB locale `mongo:6.0`; Newman `newman@6.2.1`.
- Database `dev_diary` (contratto) e `dev_diary_demo` (demo locale); collection `entries`.
- Percorsi e metodi dei webhook della traccia invariati: `GET /status`, `GET /diary`, `GET /diary/detail?id=`, `POST /diary`, `PUT /diary?id=`, `DELETE /diary?id=`, `GET /diary/export/json`, `GET /diary/export/markdown`. Nuovi: `POST /diary/restore?id=`, `POST /demo/reset`.
- Tipi ammessi: `note`, `snippet`, `idea`, `errore`, `link`.
- Limiti: titolo ≤ 120 caratteri, contenuto ≤ 10.000, codice ≤ 10.000, al massimo 10 tag da ≤ 30 caratteri.
- Demo (`DEMO_MODE=true`): ≤ 50 note per visitatore, ≤ 300 in totale; intestazione `X-Demo-Visitor` con UUID; note di esempio `isSample: true` in sola lettura.
- Errori: sempre `{"error":true,"code":"...","message":"..."}`; `code` in inglese maiuscolo, `message` in italiano (tabella nel Task 4).
- `_id` sempre stringa esadecimale di 24 caratteri nelle risposte; `ownerId` mai nelle risposte.
- Proxy: espone solo `/webhook/*` e `/healthz`; 60 richieste/minuto per IP in produzione (variabile `RATE_LIMIT_PER_MINUTE`, default 60; 1000 nello stack locale e in CI, così i test di contratto non inciampano nel limite); corpo ≤ 32 KB.
- Segreti mai nel repository: in locale valori di sviluppo dichiarati nel `docker-compose.yml`, in produzione variabili di Render (piano 2).
- La cartella `Downloads\DevDiary_Consegna` e il suo zip non si toccano.
- Messaggi di commit in inglese, stile convenzionale (`feat:`, `fix:`, `test:`, `chore:`, `docs:`), chiusi dalla riga `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Nulla viene pubblicato su GitHub prima del Task 10.
- Flutter non si tocca in questo piano (cartella `app/` spostata e basta).

## Review Focus

1. **Testo con accenti ed emoji** (`perché più ✓`): deve tornare identico da `POST` a `GET`. Test: Task 6, `Contratto / Unicode round-trip`.
2. **Caratteri speciali nella ricerca** (`c++`, `(`, `[a-`): devono cercare il testo letterale e rispondere 200, non 503. Test: Task 5 `listFilter escapes regex`, Task 6 `Contratto / ricerca con caratteri speciali`.
3. **Corpo non valido** (array, stringa, `null`, JSON rotto) in `POST` e `PUT`: 400 `BODY_INVALID`, mai 500. Test: Task 4 `normalizeEntryInput rejects non-object bodies`, Task 6 `Contratto / corpo non valido`.
4. **Identificativo visitatore malformato** (vuoto, `abc`, 200 caratteri) in demo: 400 `VISITOR_REQUIRED`. Test: Task 5 `visitorFrom rejects malformed ids`, Task 8 `Demo / visitatore malformato`.
5. **Tag duplicati o con maiuscole** (`"Flutter, flutter , API"`): salvati come `["flutter","api"]`. Test: Task 4 `normalizeEntryInput dedupes tags`.

---

## Mappa dei file

```
C:\Dev\devdiary\
├─ .gitignore                         (_archivio/, node_modules/, api/workflows/dist/, .dart_tool/, build/)
├─ README.md                          breve segnaposto (sostituito nel piano 4)
├─ app/                               ex 01_Flutter/dev_diary (invariata)
├─ api/
│  ├─ package.json                    script: test, build (nessuna dipendenza)
│  ├─ code/lib.js                     tutta la logica dei nodi Code + run(name, ctx)
│  ├─ code/lib.test.js                test unitari della logica
│  ├─ scripts/build-workflow.js       template + lib.js + seed → workflows/dist/*.json
│  ├─ scripts/build-workflow.test.js
│  ├─ workflows/devdiary-api.template.json     workflow principale (riscritto nel Task 6)
│  ├─ workflows/devdiary-reset.template.json   workflow di reset (Task 8)
│  ├─ seed/entries.json               note di esempio (Task 8)
│  ├─ proxy/proxy.js                  createProxy(...) e isAllowedPath(...)
│  ├─ proxy/proxy.test.js
│  ├─ proxy/main.js                   avvia n8n come processo figlio + proxy + seed iniziale
│  ├─ docker/entrypoint.sh            credenziale, segnaposto, import, attivazione, avvio
│  ├─ docker/render-workflows.js      sostituisce i segnaposto di runtime
│  ├─ Dockerfile
│  └─ docker-compose.yml              mongo + api (contratto, :5678) + api-demo (:5680)
├─ postman/devdiary-api.postman_collection.json   cartelle "Contratto" e "Demo"
├─ postman/local-contratto.postman_environment.json   baseUrl http://localhost:5678/webhook
├─ postman/local-demo.postman_environment.json        baseUrl http://localhost:5680/webhook, resetToken
├─ docs/consegna/                     README, postman, mongodb, branding-v1, screenshot della consegna
├─ docs/postgresql/schema.sql         ex 07_Database
├─ tools/contrast/verify-tokens.js    controllo dei token per la CI (Task 9)
└─ .github/workflows/ci.yml
```

---

### Task 1: repository di base e storia della consegna

**Files:**
- Create: `C:\Dev\devdiary\.git`, `.gitignore` (estendere quello esistente), `README.md`
- Move: contenuto della consegna nella struttura della mappa

**Interfaces:**
- Produces: tag `consegna-ifts`; `api/workflows/devdiary-api.template.json` (per ora il workflow del 19/11 con la credenziale `DevDiaryMongo001`); `app/` con il progetto Flutter.

- [ ] **Step 1: chiedere all'utente nome ed email dell'autore dei commit.** Il repository sarà pubblico: proporre l'email noreply di GitHub dell'account `ash-ven` invece di un'email personale o di lavoro. Impostarli solo nel repository (`git config user.name`, `git config user.email`), non globalmente.
- [ ] **Step 2: estrarre lo zip originale nella radice.** `C:\Dev\devdiary\_archivio\DevDiary_Consegna_originale.zip` contiene la cartella `DevDiary_Consegna/`: estrarne il contenuto direttamente in `C:\Dev\devdiary` (cartelle `01_Flutter` … `07_Database` e `README.md` della consegna). Prima spostare temporaneamente `README.md` esistente se c'è conflitto (non c'è: la radice non ha README).
- [ ] **Step 3: primo commit e tag.**
```bash
git init -b main
git add 01_Flutter 02_n8n 03_Postman 04_MongoDB 05_Branding 06_Screemshot_App 07_Database README.md
git commit -m "chore: import IFTS course delivery as submitted"   # + riga Co-Authored-By
git tag -a consegna-ifts -m "DevDiary come consegnato al corso IFTS (estate 2026)"
```
Verifica: `git show --stat consegna-ifts | head` elenca solo file della consegna; `git status` mostra come non tracciati `branding/ docs/ tools/`.
- [ ] **Step 4: commit delle correzioni del 19/11.** Copiare `C:\Users\a.venturi\Downloads\DevDiary_Consegna\DevDiary_Consegna\02_n8n\DevDiary_API_workflow.json` su `02_n8n/DevDiary_API_workflow.json`. Verifica: `git diff --stat` mostra solo quel file, 5 nodi cambiati (`_id` stringa, `[]` con database vuoto, export JSON completo). Commit `fix(api): return string ids, empty list and full JSON export`.
- [ ] **Step 5: ristrutturazione.** Con `git mv`: `01_Flutter/dev_diary` → `app`; `02_n8n/DevDiary_API_workflow.json` → `api/workflows/devdiary-api.template.json`; `03_Postman` → `docs/consegna/postman`; `04_MongoDB` → `docs/consegna/mongodb`; `05_Branding` → `docs/consegna/branding-v1`; `06_Screemshot_App` → `docs/consegna/screenshot`; `07_Database/--Schema PostgreSQL.sql` → `docs/postgresql/schema.sql`; `README.md` → `docs/consegna/README.md`. Nel template sostituire ovunque l'id credenziale `XxVRGSGikKpeeW6o` con `DevDiaryMongo001` e il nome con `MongoDB DevDiary`. Nuovo `README.md` di 3 righe ("DevDiary, diario tecnico. Lavori in corso: vedi docs/superpowers/specs."). Aggiungere a `.gitignore`: `node_modules/`, `api/workflows/dist/`, `.dart_tool/`, `build/`.
- [ ] **Step 6: commit.** `git add -A` poi verificare con `git status` che `_archivio/` non compaia. Commit `chore: restructure repository and add design docs, branding and tools`.

---

### Task 2: proxy davanti a n8n

**Files:**
- Create: `api/package.json`, `api/proxy/proxy.js`, `api/proxy/proxy.test.js`

**Interfaces:**
- Produces: `createProxy({ target: string, maxBody?: number = 32768, rateLimit?: number = 60, windowMs?: number = 60000, now?: () => number }) -> http.Server` e `isAllowedPath(pathname: string) -> boolean`, esportati da `api/proxy/proxy.js` (CommonJS).
- `api/package.json`: `{"name":"devdiary-api","private":true,"scripts":{"test":"node --test","build":"node scripts/build-workflow.js"}}`.

- [ ] **Step 1: scrivere i test** in `api/proxy/proxy.test.js` con `node:test` e `assert/strict`; un server finto a monte (porta 0) che risponde con metodo e percorso ricevuti e un'intestazione `access-control-allow-origin: x`.
  - `isAllowedPath`: `true` per `/webhook/status`, `/webhook/diary/detail`, `/healthz`; `false` per `/`, `/rest/login`, `/webhook-test/status`, `/healthz/readiness`, `/webhookx`.
  - `forwards allowed paths`: `GET /webhook/diary?type=snippet` arriva a monte con la stessa query; risposta 200 con corpo e intestazione CORS del server a monte.
  - `blocks other paths`: `GET /rest/settings` → 404, JSON `{"error":true,"code":"NOT_FOUND","message":"Percorso non disponibile"}`, nessuna richiesta a monte.
  - `rejects large bodies`: `POST /webhook/diary` con 32.769 byte → 413 `PAYLOAD_TOO_LARGE`, messaggio "Richiesta troppo grande".
  - `rate limits per ip`: con `rateLimit: 3` la quarta richiesta dallo stesso `X-Forwarded-For: 1.2.3.4` → 429 `RATE_LIMITED`, "Troppe richieste: riprova tra un minuto", intestazione `Retry-After`; una richiesta da `5.6.7.8` passa; dopo `windowMs` (clock finto `now`) la stessa IP passa.
  - `reports upstream down`: target su una porta chiusa → 503 `API_STARTING`, "Il server si sta avviando, riprova tra qualche secondo".
- [ ] **Step 2: eseguire `npm test` in `api/`.** Atteso: FAIL (modulo mancante).
- [ ] **Step 3: implementare `api/proxy/proxy.js`** con il solo modulo `http`: IP = prima voce di `X-Forwarded-For`, altrimenti indirizzo del socket; finestra fissa per IP in una `Map`; il conteggio del corpo interrompe a `maxBody + 1` byte.
- [ ] **Step 4: eseguire `npm test`.** Atteso: PASS, 7 test.
- [ ] **Step 5: commit** `feat(api): add webhook-only proxy with rate and size limits`.

---

### Task 3: immagine Docker, avvio e ambiente locale

**Files:**
- Create: `api/Dockerfile`, `api/docker/entrypoint.sh`, `api/docker/render-workflows.js`, `api/proxy/main.js`, `api/docker-compose.yml`, `postman/devdiary-api.postman_collection.json`, `postman/local-contratto.postman_environment.json`, `postman/local-demo.postman_environment.json`
- Temporaneo: `api/scripts/build-workflow.js` minimale (copia i template in `api/workflows/dist/` senza trasformarli); il Task 6 lo sostituisce.

**Interfaces:**
- Consumes: `createProxy` (Task 2).
- Produces:
  - Variabili d'ambiente del container: `MONGODB_URI` (obbligatoria), `MONGODB_DATABASE` (default `dev_diary`), `N8N_ENCRYPTION_KEY` (obbligatoria), `RESET_TOKEN` (obbligatoria), `ALLOWED_ORIGINS` (default `*`, separate da virgola), `DEMO_MODE` (default `false`), `PORT` (default `10000`).
  - Segnaposto di runtime sostituiti da `render-workflows.js` in ogni `dist/*.json`: `__DEMO_MODE__`, `__RESET_TOKEN__`, `__ALLOWED_ORIGINS__` (valori come stringhe JSON-escaped).
  - Credenziale importata: `{"id":"DevDiaryMongo001","name":"MongoDB DevDiary","type":"mongoDb","data":{"configurationType":"connectionString","connectionString":MONGODB_URI,"database":MONGODB_DATABASE}}`.
  - Porte locali: contratto `http://localhost:5678/webhook`, demo `http://localhost:5680/webhook`.

- [ ] **Step 1: liberare la porta 5678.** Rimuovere i container temporanei creati il 19/11 (contengono solo le 5 note di prova ricreate quel giorno): `docker rm -f devdiary-n8n devdiary-mongo` e `docker volume rm devdiary_n8n devdiary_mongo`, `docker network rm devdiary`. Verifica: `docker ps -a | grep devdiary` vuoto.
- [ ] **Step 2: `Dockerfile`.** `FROM n8nio/n8n:1.123.95`; copia `api/` in `/opt/devdiary` con proprietario `node`; `RUN node /opt/devdiary/scripts/build-workflow.js`; variabili: `N8N_DISABLE_UI=true`, `N8N_PORT=5679`, `N8N_LISTEN_ADDRESS=127.0.0.1`, `N8N_DIAGNOSTICS_ENABLED=false`, `N8N_PERSONALIZATION_ENABLED=false`, `N8N_HIRING_BANNER_ENABLED=false`, `EXECUTIONS_DATA_SAVE_ON_SUCCESS=none`, `GENERIC_TIMEZONE=Europe/Rome`, `TZ=Europe/Rome`; `EXPOSE 10000`; `ENTRYPOINT ["tini","--","/opt/devdiary/docker/entrypoint.sh"]`.
- [ ] **Step 3: `entrypoint.sh`** (`#!/bin/sh`, `set -eu`): esce con messaggio chiaro se mancano `MONGODB_URI`, `N8N_ENCRYPTION_KEY` o `RESET_TOKEN`; genera la credenziale con `node` (mai con `echo` di stringhe non escapate) in `/tmp/devdiary/cred.json`; `node render-workflows.js /opt/devdiary/workflows/dist /tmp/devdiary/workflows`; `n8n import:credentials --input=/tmp/devdiary/cred.json`; `n8n import:workflow --separate --input=/tmp/devdiary/workflows`; `n8n update:workflow --all --active=true`; `exec node /opt/devdiary/proxy/main.js`.
- [ ] **Step 4: `proxy/main.js`.** Avvia `n8n start` come processo figlio (eredita l'ambiente), avvia `createProxy({ target: 'http://127.0.0.1:5679', rateLimit: Number(process.env.RATE_LIMIT_PER_MINUTE || 60) })` su `PORT`, termina con lo stesso codice se il figlio termina, inoltra `SIGTERM`. Quando `http://127.0.0.1:5679/healthz` risponde 200 e il webhook `POST /webhook/demo/reset?ifEmpty=true` esiste, lo chiama una volta con `X-Reset-Token: $RESET_TOKEN`, ignorando 404 (prima del Task 8 il webhook non esiste).
- [ ] **Step 5: `docker-compose.yml`.** Servizi: `mongo` (`mongo:6.0`, volume `devdiary_mongo_data`, healthcheck `mongosh --quiet --eval 'db.runCommand({ping:1}).ok'`); `api` (build `.`, porta `5678:10000`, `MONGODB_URI=mongodb://mongo:27017`, `MONGODB_DATABASE=dev_diary`, `DEMO_MODE=false`, `ALLOWED_ORIGINS=*`, `RESET_TOKEN=dev-reset-token`, `N8N_ENCRYPTION_KEY=dev-encryption-key-not-secret`, `RATE_LIMIT_PER_MINUTE=1000`); `api-demo` (come `api` ma porta `5680:10000`, `MONGODB_DATABASE=dev_diary_demo`, `DEMO_MODE=true`); healthcheck di `api` e `api-demo`: `node -e "fetch('http://127.0.0.1:10000/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"`.
- [ ] **Step 6: collection Postman di base.** Variabili d'ambiente `baseUrl`, `resetToken`, `visitorA`, `visitorB`. Cartella `Contratto` con i test del comportamento **attuale** (prima delle modifiche): `GET status` → 200; `POST crea nota` → 201, salva l'`_id` letto dalla lista in `{{noteId}}`; `GET lista` → 200, array, ogni `_id` stringa di 24 caratteri esadecimali; `GET dettaglio` → 200; `PUT modifica` → 200; `DELETE elimina` → 200; `GET export json` → 200, array; `GET export markdown` → 200, testo che inizia con `# DevDiary Export`; casi 400 (titolo mancante, contenuto mancante, tipo non valido, id mancante). Cartella `Demo` vuota.
- [ ] **Step 7: verificare.** `docker compose up -d --build --wait` in `api/`, poi `npx newman@6.2.1 run postman/devdiary-api.postman_collection.json -e postman/local-contratto.postman_environment.json --folder Contratto`. Atteso: tutti i test verdi. Controlli manuali: `curl -i http://localhost:5678/rest/settings` → 404; `curl -i http://localhost:5678/` → 404; `curl -s http://localhost:5678/healthz` → `{"status":"ok"}`.
- [ ] **Step 8: commit** `feat(api): containerised n8n with import-on-boot and local compose stack`.

---

### Task 4: logica dei nodi Code, parte 1: validazione e forma delle risposte

**Files:**
- Create: `api/code/lib.js`, `api/code/lib.test.js`

**Interfaces:**
- Produces, da `api/code/lib.js` (funziona sia in Node sia incollato in un nodo Code: in fondo `if (typeof module !== 'undefined') module.exports = {...}`):
  - `const CONFIG = { demoMode: false, resetToken: '', seed: [] };` (riga sostituita dal build, Task 6)
  - `fail(status: number, code: string, message?: string) -> { ok: false, status, payload: { error: true, code, message } }` (messaggio predefinito dalla tabella)
  - `done(status: number, payload: any, extra?: object) -> { ok: true, status, payload, ...extra }`
  - `isObjectId(id: unknown) -> boolean` (stringa di 24 caratteri esadecimali)
  - `toHexId(id: unknown) -> string | null` (stringa, oggetto con `toHexString()`, oggetto `{ buffer: {0..11} }`)
  - `toPublic(doc: object) -> object` (`_id` esadecimale, senza `ownerId`, `isSample` booleano, `deletedAt` stringa o `null`)
  - `normalizeEntryInput(body: unknown) -> { ok: true, value: { title, content, type, language, code, tags, isFavorite } } | fail(...)`
  - `MESSAGES: Record<string, string>` con la tabella sotto.

| status | code | message |
|---|---|---|
| 400 | `ID_REQUIRED` | Parametro id obbligatorio |
| 400 | `ID_INVALID` | ID non valido |
| 400 | `BODY_INVALID` | Il corpo della richiesta deve essere un oggetto JSON |
| 400 | `TITLE_REQUIRED` | Il titolo è obbligatorio |
| 400 | `CONTENT_REQUIRED` | Il contenuto è obbligatorio |
| 400 | `TYPE_INVALID` | Tipo non valido: usa note, snippet, idea, errore o link |
| 400 | `TITLE_TOO_LONG` | Il titolo supera i 120 caratteri |
| 400 | `CONTENT_TOO_LONG` | Il contenuto supera i 10.000 caratteri |
| 400 | `CODE_TOO_LONG` | Il codice supera i 10.000 caratteri |
| 400 | `TOO_MANY_TAGS` | Puoi usare al massimo 10 tag |
| 400 | `TAG_TOO_LONG` | Ogni tag può avere al massimo 30 caratteri |
| 400 | `VISITOR_REQUIRED` | Manca l'identificativo del visitatore della demo |
| 401 | `RESET_UNAUTHORIZED` | Token di reset non valido |
| 403 | `SAMPLE_READ_ONLY` | Le note di esempio non si modificano: creane una tua per provare |
| 404 | `NOT_FOUND` | Nota non trovata |
| 409 | `NOT_IN_TRASH` | La nota non è nel cestino |
| 429 | `DEMO_LIMIT_REACHED` | Hai raggiunto il limite della demo: le note si cancellano ogni notte |
| 503 | `DATABASE_UNAVAILABLE` | Database non disponibile |

- [ ] **Step 1: scrivere i test** in `api/code/lib.test.js`:
  - `fail uses the message table`: `fail(404,'NOT_FOUND').payload` deep-equal `{error:true,code:'NOT_FOUND',message:'Nota non trovata'}`.
  - `toHexId handles all shapes`: `'6afeb4a37ab5376904d214ad'` → stessa stringa; `{toHexString:()=>'6afe…ad'}` → `'6afe…ad'`; `{buffer:{0:106,1:254,2:180,3:163,4:122,5:181,6:55,7:105,8:4,9:210,10:20,11:173}}` → `'6afeb4a37ab5376904d214ad'`; `undefined` → `null`.
  - `toPublic strips ownerId`: input con `ownerId:'x'`, `_id` a buffer → output senza chiave `ownerId`, `_id` stringa, `isSample:false`, `deletedAt:null` se assenti.
  - `normalizeEntryInput rejects non-object bodies`: `[]`, `'x'`, `null`, `42` → `code === 'BODY_INVALID'`.
  - `normalizeEntryInput validates required fields`: titolo `'  '` → `TITLE_REQUIRED`; contenuto mancante → `CONTENT_REQUIRED`; `type:'Bug'` → `TYPE_INVALID`; `type` assente o `''` → `'note'`.
  - `normalizeEntryInput enforces limits`: titolo 121 caratteri → `TITLE_TOO_LONG` (120 passa); contenuto 10.001 → `CONTENT_TOO_LONG`; codice 10.001 → `CODE_TOO_LONG`; 11 tag → `TOO_MANY_TAGS`; tag di 31 caratteri → `TAG_TOO_LONG`.
  - `normalizeEntryInput dedupes tags`: `tags:'Flutter, flutter , API,,'` → `['flutter','api']`; `tags:[1,'Dart']` → `['1','dart']`.
  - `normalizeEntryInput normalizes optional fields`: `language:'  '` → `null`; `code:''` → `null`; `isFavorite:'true'` → `true`; `isFavorite:'yes'` → `false`; titolo e contenuto trimmati; `title:'perché più ✓'` invariato.
- [ ] **Step 2: `node --test` in `api/`.** Atteso: FAIL.
- [ ] **Step 3: implementare** le funzioni dell'Interfaces in `api/code/lib.js`. I limiti si contano in caratteri dopo il trim (`[...str].length`, così le emoji contano 1).
- [ ] **Step 4: `node --test`.** Atteso: PASS (i test del Task 2 restano verdi).
- [ ] **Step 5: commit** `feat(api): shared validation and response helpers with unit tests`.

---

### Task 5: logica dei nodi Code, parte 2: filtri, visibilità della demo, seed, export

**Files:**
- Modify: `api/code/lib.js`, `api/code/lib.test.js`

**Interfaces:**
- Consumes: Task 4.
- Produces:
  - `escapeRegex(text: string) -> string`
  - `visitorFrom(headers: object, config: typeof CONFIG) -> { ok: true, visitorId: string | null } | fail(400,'VISITOR_REQUIRED')` (in demo l'intestazione `x-demo-visitor` deve essere un UUID: `/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i`; fuori demo restituisce sempre `visitorId: null`)
  - `scopeFilter(visitorId: string | null, config) -> object` (`{}` fuori demo; `{ $or: [{ isSample: true }, { ownerId: visitorId }] }` in demo)
  - `listFilter(query: object, visitorId, config) -> { filter: object, sort: { createdAt: -1 } }` (parametri `type`, `favorite`, `tag`, `search`, `trash`; `trash=true` → `deletedAt: { $ne: null }`, altrimenti `deletedAt: null`; scope combinato con `$and` quando servono due `$or`)
  - `romeWallTimeToUtc(y: number, m: number, d: number, hh: number, mm: number) -> Date`
  - `seedToDocs(seed: Array<{title,content,type,language,code,tags,isFavorite,daysAgo,time}>, now: Date) -> object[]` (aggiunge `createdAt` = `updatedAt` = giorno di Roma di `now` meno `daysAgo`, all'ora `time`; `isSample: true`, `ownerId: null`, `deletedAt: null`; rimuove `daysAgo` e `time`)
  - `buildMarkdown(entries: object[]) -> string` (stesso formato del nodo "Build Markdown Export" attuale)
- Algoritmo per `romeWallTimeToUtc` (il fuso non è determinato dalla firma):
```js
const guess = Date.UTC(y, m - 1, d, hh, mm);
const p = Object.fromEntries(new Intl.DateTimeFormat('en-GB', { timeZone: 'Europe/Rome', hourCycle: 'h23',
  year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })
  .formatToParts(new Date(guess)).map(x => [x.type, x.value]));
const asRome = Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour, +p.minute);
return new Date(guess - (asRome - guess));
```

- [ ] **Step 1: scrivere i test:**
  - `listFilter escapes regex`: `search:'c++ ('` → `filter.$or[0].title.$regex === 'c\\+\\+ \\('`, `$options === 'i'`.
  - `listFilter maps query params`: `type:'Snippet'` → `filter.type === 'snippet'`; `favorite:'true'` → `isFavorite === true`; `tag:' Flutter '` → `tags === 'flutter'`; senza `trash` → `deletedAt === null`; `trash:'true'` → `deletedAt` deep-equal `{ $ne: null }`; `sort` deep-equal `{ createdAt: -1 }`.
  - `listFilter combines search and demo scope`: demo + `search` → `filter.$and` contiene sia lo scope sia la ricerca.
  - `visitorFrom rejects malformed ids`: demo, intestazioni `{}`, `{'x-demo-visitor':''}`, `{'x-demo-visitor':'abc'}`, stringa di 200 caratteri → `VISITOR_REQUIRED`; UUID v4 valido → `ok:true`; fuori demo, intestazioni vuote → `{ok:true, visitorId:null}`.
  - `scopeFilter`: fuori demo `{}`; in demo `{ $or: [{ isSample: true }, { ownerId: 'u' }] }`.
  - `romeWallTimeToUtc handles daylight saving`: `(2026,11,19,9,34)` → `'2026-11-19T08:34:00.000Z'`; `(2026,8,14,22,58)` → `'2026-08-14T20:58:00.000Z'`.
  - `seedToDocs dates relative to now`: `now = new Date('2026-11-19T10:00:00Z')`, voce `{daysAgo:1, time:'18:20', …}` → `createdAt === '2026-11-18T17:20:00.000Z'`, `isSample === true`, chiavi `daysAgo` e `time` assenti.
  - `buildMarkdown`: due note (una con `language:'dart'` e `code`) → inizia con `# DevDiary Export\n\n`, contiene `## <titolo>`, `**Tipo:** snippet`, `**Tag:** #a #b` e un blocco ```` ```dart ````.
- [ ] **Step 2: `node --test`.** Atteso: FAIL sui nuovi test.
- [ ] **Step 3: implementare** le funzioni dell'Interfaces.
- [ ] **Step 4: `node --test`.** Atteso: PASS.
- [ ] **Step 5: commit** `feat(api): filters, demo visibility, seed dating and markdown export`.

---

### Task 6: nuovo workflow principale e build

**Files:**
- Modify: `api/workflows/devdiary-api.template.json` (riscritto), `api/scripts/build-workflow.js` (versione completa), `api/code/lib.js` (funzioni di ingresso), `api/code/lib.test.js`, `postman/devdiary-api.postman_collection.json`
- Create: `api/scripts/build-workflow.test.js`

**Interfaces:**
- Consumes: Task 4 e 5.
- Produces:
  - Dispatcher in `lib.js`: `run(name: string, ctx: { json: object, ref: (nodeName: string) => object, config: typeof CONFIG }) -> Array<{ json: object }>`. Ogni funzione di ingresso restituisce un solo elemento `{ json: { ok, status, payload, ...dati per il nodo successivo } }`.
  - Funzioni di ingresso (nome = nome del nodo Code nel template, in inglese camelCase): `statusResult`, `listPrepare`, `listResult`, `detailPrepare`, `detailResult`, `createPrepare`, `createCheckLimits`, `createResult`, `updatePrepare`, `updateCheck`, `updateResult`, `deletePrepare`, `deleteCheck`, `deleteResult`, `restorePrepare`, `restoreCheck`, `restoreResult`, `exportPrepare`, `exportJsonResult`, `exportMarkdownResult`.
  - Build: nel template ogni nodo Code ha `"jsCode": "@@lib:<nomeFunzione>@@"`; il build lo sostituisce con il contenuto di `lib.js` (con `CONFIG` riscritto come `{ demoMode: '__DEMO_MODE__' === 'true', resetToken: '__RESET_TOKEN__', seed: <JSON di api/seed/entries.json, [] se manca> }`) seguito da `return run('<nomeFunzione>', { json: $json, ref: (n) => $(n).item.json, config: CONFIG });`. Scrive `api/workflows/dist/<nome>.json` per ogni `*.template.json`.

**Grafo del workflow** (stesso nome "DevDiary API", stesso `id` del template attuale; tutti i webhook con `responseMode: "responseNode"` e `options.allowedOrigins: "__ALLOWED_ORIGINS__"`; ogni ramo termina in un nodo Respond):

| Webhook | Catena |
|---|---|
| `GET status` | Mongo aggregate `[{"$limit":1}]` → `statusResult` → Respond |
| `GET diary` | `listPrepare` → IF ok → Mongo find (`filter`, `sort`) → `listResult` → Respond; ramo false → Respond |
| `GET diary/detail` | `detailPrepare` → IF → Mongo find limit 1 → `detailResult` → Respond |
| `POST diary` | `createPrepare` → IF → Mongo aggregate (conteggi) → `createCheckLimits` → IF → Mongo insert → `createResult` → Respond |
| `PUT diary` | `updatePrepare` → IF → Mongo find → `updateCheck` → IF → Mongo update → `updateResult` → Respond |
| `DELETE diary` | `deletePrepare` → IF → Mongo find → `deleteCheck` → Switch su `action` (`soft` → Mongo update `deletedAt`; `hard` → Mongo delete) → `deleteResult` → Respond |
| `POST diary/restore` | `restorePrepare` → IF → Mongo find → `restoreCheck` → IF → Mongo update `deletedAt: null` → `restoreResult` → Respond |
| `GET diary/export/json` | `exportPrepare` → Mongo find → `exportJsonResult` → Respond |
| `GET diary/export/markdown` | `exportPrepare` → Mongo find → `exportMarkdownResult` → Respond testo (`Content-Type: text/markdown; charset=utf-8`) |

Forme dei nodi da usare (n8n 1.123.95; parametri non elencati lasciati ai default):
```json
{"type":"n8n-nodes-base.mongoDb","typeVersion":1.2,"alwaysOutputData":true,"onError":"continueRegularOutput",
 "credentials":{"mongoDb":{"id":"DevDiaryMongo001","name":"MongoDB DevDiary"}},
 "parameters":{"operation":"find","collection":"entries","query":"={{ JSON.stringify($json.filter) }}","options":{"sort":"={{ JSON.stringify($json.sort) }}"}}}
{"parameters":{"operation":"aggregate","collection":"entries","query":"={{ JSON.stringify($json.pipeline) }}"}}
{"parameters":{"operation":"insert","collection":"entries","fields":"title,content,type,language,code,tags,isFavorite,isSample,ownerId,deletedAt,createdAt,updatedAt","options":{}}}
{"parameters":{"operation":"update","collection":"entries","updateKey":"_id","fields":"title,content,type,language,code,tags,isFavorite,updatedAt","options":{}}}
{"parameters":{"operation":"delete","collection":"entries","query":"={{ JSON.stringify($json.filter) }}"}}
{"type":"n8n-nodes-base.if","typeVersion":2.3,"parameters":{"conditions":{"options":{"caseSensitive":true,"typeValidation":"loose","version":3},"conditions":[{"leftValue":"={{ $json.ok }}","rightValue":"","operator":{"type":"boolean","operation":"true","singleValue":true}}],"combinator":"and"}}}
{"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.5,"parameters":{"respondWith":"json","responseBody":"={{ $json.payload }}","options":{"responseCode":"={{ $json.status }}"}}}
```
Se n8n 1.123.95 non accetta l'espressione in `responseCode`, sostituire ogni Respond con un nodo Switch su `$json.status` seguito da un Respond per ciascun codice usato da quel ramo; il resto non cambia.

Ogni funzione `*Result`/`*Check` legge i dati del proprio `*Prepare` con `ctx.ref('<nome nodo>')` e riconosce l'errore del nodo Mongo (`ctx.json.error` presente) restituendo `fail(503,'DATABASE_UNAVAILABLE')`. Gli id nelle query Mongo restano stringhe (`{"_id":"<hex>"}`): il nodo li converte in ObjectId.

Comportamenti (oltre a validazione e visibilità dei Task 4 e 5):
- `statusResult`: 200 `{"status":"OK","database":"OK"}`; con errore Mongo 503 `{"status":"OK","database":"ERROR"}`.
- `createCheckLimits` (solo in demo): pipeline `[{"$facet":{"total":[{"$count":"n"}],"mine":[{"$match":{"ownerId":visitorId}},{"$count":"n"}]}}]`; `total ≥ 300` o `mine ≥ 50` → 429 `DEMO_LIMIT_REACHED`. Fuori demo passa sempre. Il documento inserito ha `isSample:false`, `ownerId` = visitatore o `null`, `deletedAt:null`, `createdAt` = `updatedAt` = ora corrente ISO.
- `createResult`: 201 `{"success":true,"message":"Nota creata correttamente","_id":"<hex>"}`.
- `updateCheck`: nota assente, nel cestino o fuori scope → 404 `NOT_FOUND`; `isSample:true` in demo → 403 `SAMPLE_READ_ONLY`. `updateResult`: 200 `{"success":true,"message":"Nota aggiornata correttamente"}`.
- `deletePrepare`: `permanent=true` → `action:'hard'`. `deleteCheck`: assente o fuori scope → 404; campione in demo → 403; `hard` su nota non nel cestino → 409 `NOT_IN_TRASH`; `soft` su nota già nel cestino → 404. `deleteResult`: `soft` → 200 `"Nota spostata nel cestino"`; `hard` → 200 `"Nota eliminata"`.
- `restoreCheck`: assente, fuori scope o non nel cestino → 404. `restoreResult`: 200 `"Nota ripristinata"`.
- `detailPrepare`/`listPrepare`/`exportPrepare`: le note nel cestino si vedono solo con `trash=true` (l'export le esclude sempre).
- Risposte con note: sempre passate da `toPublic`.

- [ ] **Step 1: estendere la cartella `Contratto` della collection** aggiornando i casi del Task 3 che cambiano (`status` con la nuova forma, `DELETE` che ora sposta nel cestino) e aggiungendo i nuovi casi (scritti prima del codice): `status` → `pm.response.json()` deep-equal `{status:'OK',database:'OK'}`; `POST` restituisce `_id` di 24 caratteri; `Unicode round-trip` (titolo `perché più ✓` identico nel dettaglio); `ricerca con caratteri speciali` (`?search=c%2B%2B%20(` → 200, array); `corpo non valido` (`POST` con `[]` e con `"x"` → 400 `BODY_INVALID`); limiti (titolo 121 caratteri → 400 `TITLE_TOO_LONG`); ogni errore ha `error`, `code`, `message`; `DELETE` → 200 `"Nota spostata nel cestino"`, la nota sparisce da `GET /diary`, compare in `GET /diary?trash=true`, dettaglio → 404, dettaglio con `trash=true` → 200; `DELETE … permanent=true` su nota non nel cestino → 409 `NOT_IN_TRASH`; `POST /diary/restore` → 200 e la nota torna in lista; `DELETE` poi `DELETE permanent=true` → 200 `"Nota eliminata"`, poi `restore` → 404; `export/json` esclude il cestino; nessuna risposta contiene la chiave `ownerId`.
- [ ] **Step 2: eseguire la cartella `Contratto`** contro lo stack del Task 3. Atteso: FAIL sui nuovi casi.
- [ ] **Step 3: test del build** in `api/scripts/build-workflow.test.js`: `build replaces every code placeholder` (nessuna stringa `@@lib:` nel risultato); `every code node names an existing entry function` (per ogni `@@lib:x@@` del template, `x` è una chiave del dispatcher); `every mongo node uses the shared credential` (`DevDiaryMongo001`); `runtime placeholders survive the build` (`__DEMO_MODE__`, `__RESET_TOKEN__`, `__ALLOWED_ORIGINS__` presenti nell'output).
- [ ] **Step 4: test unitari delle funzioni di ingresso** in `lib.test.js`, con `ctx` finti: un test per ciascun comportamento elencato sopra (nome `<funzione> <comportamento>`, es. `deleteCheck rejects hard delete outside trash` → `status 409`, `payload.code 'NOT_IN_TRASH'`).
- [ ] **Step 5: implementare** dispatcher, funzioni di ingresso, `build-workflow.js` e il nuovo template secondo grafo e forme sopra.
- [ ] **Step 6: verificare.** `node --test` in `api/` → PASS; `docker compose up -d --build --wait`; cartella `Contratto` con Newman → tutti verdi.
- [ ] **Step 7: commit** `feat(api): rebuild workflow around tested code library; soft delete, restore, limits, error codes`.

---

### Task 7: workflow di reset e note di esempio

**Files:**
- Create: `api/workflows/devdiary-reset.template.json`, `api/seed/entries.json`
- Modify: `api/code/lib.js`, `api/code/lib.test.js`, `postman/devdiary-api.postman_collection.json`

**Interfaces:**
- Consumes: `seedToDocs` (Task 5), build (Task 6), chiamata di avvio in `proxy/main.js` (Task 3).
- Produces: `POST /webhook/demo/reset[?ifEmpty=true]` con intestazione `X-Reset-Token`; funzioni di ingresso `resetPrepare`, `resetPlan`, `resetSeed`, `resetResult`.
- Grafo: webhook `POST demo/reset` → `resetPrepare` (token diverso da `CONFIG.resetToken` o vuoto → 401 `RESET_UNAUTHORIZED`) → IF → Mongo aggregate `[{"$count":"n"}]` → `resetPlan` (con `ifEmpty=true` e conteggio > 0 → 200 `{"success":true,"message":"Demo già pronta","entries":n}` senza modifiche) → IF → Mongo delete `{}` → `resetSeed` (un elemento per documento da `seedToDocs(CONFIG.seed, new Date())`) → Mongo insert → `resetResult` → 200 `{"success":true,"message":"Demo ripristinata","entries":<numero di note di esempio>}`.

- [ ] **Step 1: scrivere `api/seed/entries.json`.** Circa 20 note in italiano realistico, almeno 2 per tipo, con `daysAgo` da 0 a 150 (servono note "Oggi" e "Ieri" e attività sparsa per la mappa). Includere le 8 del mockup (`docs/design/mockup-quaderno.html`): "n8n restituisce _id come {buffer}", "getEntries con filtro per tipo", "Flutter web senza Modalità sviluppatore", "Mostrare le chiamate API dentro l'app", "Documentazione del package http", "Workflow non risponde perché non pubblicato", "Query MongoDB per tipo", "Appunti Flutter". Le note `errore` usano nel contenuto i titoli `## Problema`, `## Causa`, `## Soluzione`. Ogni voce rispetta i limiti del Task 4.
- [ ] **Step 2: test unitari** (`resetPrepare rejects missing token`, `resetPrepare rejects wrong token`, `resetPlan skips when not empty and ifEmpty`, `resetPlan proceeds without ifEmpty`, `resetSeed returns one item per seed entry with isSample true`) e un test sul file: `seed entries pass normalizeEntryInput` (ogni voce senza `daysAgo`/`time` è valida) e `seed covers all five types`.
- [ ] **Step 3: test Newman** nella cartella `Contratto`: reset senza token → 401 `RESET_UNAUTHORIZED`; reset con `{{resetToken}}` → 200, `entries` uguale al numero di voci del seed; `GET /diary` dopo il reset contiene "Appunti Flutter".
- [ ] **Step 4: eseguire** `node --test` e Newman. Atteso: FAIL.
- [ ] **Step 5: implementare** funzioni di ingresso e template di reset.
- [ ] **Step 6: verificare** `node --test` → PASS; `docker compose up -d --build --wait` → dopo l'avvio `GET http://localhost:5678/webhook/diary` restituisce le note di esempio (seed iniziale da `main.js`); Newman `Contratto` → verde.
- [ ] **Step 7: commit** `feat(api): token-protected demo reset with relative-date seed`.

---

### Task 8: regole della demo

**Files:**
- Modify: `postman/devdiary-api.postman_collection.json` (cartella `Demo`), eventuali correzioni in `api/code/lib.js`

**Interfaces:**
- Consumes: Task 5, 6, 7. Ambiente `local-demo` con `visitorA` e `visitorB` (UUID v4 fissi diversi) e `resetToken: dev-reset-token`.

- [ ] **Step 1: scrivere la cartella `Demo`** (prima richiesta: reset con token per partire da uno stato noto):
  - `visitatore malformato`: `POST /diary` senza intestazione, con `X-Demo-Visitor: abc` e con una stringa di 200 caratteri → 400 `VISITOR_REQUIRED`.
  - `campioni in sola lettura`: per una nota con `isSample:true`, `PUT`, `DELETE` e `DELETE permanent=true` come `visitorA` → 403 `SAMPLE_READ_ONLY`.
  - `isolamento`: `visitorA` crea una nota; `GET /diary` come `visitorA` la contiene; come `visitorB` no; dettaglio, `PUT`, `DELETE` della nota di A come `visitorB` → 404; export JSON di `visitorB` non la contiene.
  - `cestino del visitatore`: `visitorA` sposta la sua nota nel cestino, la ritrova con `trash=true`, la ripristina.
  - `limite per visitatore`: un visitatore nuovo (`visitorC` generato nello script di pre-request) crea 50 note → la 51ª risponde 429 `DEMO_LIMIT_REACHED` (richieste in ciclo con `pm.execution.setNextRequest`; nello stack locale il limite del proxy è 1000/minuto, quindi nessun ritardo necessario).
  - `nessun ownerId`: nessuna risposta contiene la chiave `ownerId`.
- [ ] **Step 2: eseguire** `npx newman@6.2.1 run postman/devdiary-api.postman_collection.json -e postman/local-demo.postman_environment.json --folder Demo`. Atteso: verde se i Task 5–7 sono corretti; altrimenti correggere `lib.js` con un test unitario che riproduca il caso prima della correzione.
- [ ] **Step 3: verificare che la cartella `Contratto` resti verde** contro `local-contratto`.
- [ ] **Step 4: commit** `test(api): demo isolation, read-only samples and limits`.

---

### Task 9: CORS e integrazione continua

**Files:**
- Create: `.github/workflows/ci.yml`, `tools/contrast/verify-tokens.js`, `tools/contrast/tokens.json`
- Modify: `tools/contrast/check.js` (esportare `ratio`, `over`, `checks` e `resolve` senza eseguire nulla quando è richiesto come modulo)

**Interfaces:**
- Produces: `tools/contrast/tokens.json` = token finali della palette A (`light` e `dark`) presi da `tools/contrast/results.json` → `matita.themes.*.tokens`; è la fonte unica dei colori che il piano 3 userà nel tema Flutter. `node tools/contrast/verify-tokens.js` esce con codice 1 e l'elenco delle coppie fallite se un controllo non passa.

- [ ] **Step 1: test CORS a mano sullo stack locale.** Impostare temporaneamente `ALLOWED_ORIGINS=http://localhost:8090` sul servizio `api` e ricostruire; `curl -i -X OPTIONS -H "Origin: http://localhost:8090" -H "Access-Control-Request-Method: POST" http://localhost:5678/webhook/diary` → intestazione `Access-Control-Allow-Origin: http://localhost:8090`; con `Origin: https://example.com` → nessuna intestazione `Access-Control-Allow-Origin` per quell'origine. Riportare `ALLOWED_ORIGINS=*`. Annotare il risultato nel messaggio di commit.
- [ ] **Step 2: `verify-tokens.js`.** Test: eseguirlo sui token attuali → codice 0; cambiando a mano `ink3` chiaro in `#9AA0B5` in una copia temporanea → codice 1 e la riga "Date e conteggi sul foglio".
- [ ] **Step 3: `ci.yml`** su `push` e `pull_request`, job:
  - `api-unit`: Node 22, `npm test` in `api/`.
  - `api-contract`: `docker compose -f api/docker-compose.yml up -d --build --wait`; Newman `Contratto` su `local-contratto`; Newman `Demo` su `local-demo`; in caso di errore `docker compose logs`.
  - `contrast`: `node tools/contrast/verify-tokens.js`.
- [ ] **Step 4: verificare in locale** i tre comandi dei job (Docker e Newman come nel Task 8). Atteso: tutti verdi. L'esecuzione su GitHub avviene dopo il Task 10.
- [ ] **Step 5: commit** `ci: api unit and contract tests, contrast check`.

---

### Task 10: pubblicazione su GitHub

**Files:** nessuno nuovo.

- [ ] **Step 1: chiedere conferma esplicita all'utente** prima di creare il repository e fare il push (azione pubblica): repository `ash-ven/devdiary`, pubblico, con branch `main` e tag `consegna-ifts`. Mostrare `git log --oneline` e confermare che `_archivio/` non è tracciato (`git ls-files | grep _archivio` vuoto) e che non ci sono segreti (`git grep -n "mongodb+srv\|RESET_TOKEN=" -- ':!api/docker-compose.yml'` vuoto).
- [ ] **Step 2: creare e pubblicare.** Se `gh auth status` mostra l'account `ash-ven`: `gh repo create ash-ven/devdiary --public --source . --remote origin --push` poi `git push origin consegna-ifts`. Altrimenti guidare l'utente a creare il repository vuoto su github.com e poi `git remote add origin …`, `git push -u origin main`, `git push origin consegna-ifts`.
- [ ] **Step 3: verificare la CI** su GitHub: i tre job verdi sul commit di `main`. Se `api-contract` fallisce solo su GitHub, leggere i log e correggere con un nuovo commit.

---

## Copertura della spec in questo piano

| Spec | Task |
|---|---|
| 6.1 repository, storia, `consegna-ifts`, struttura, PDF non pubblicato | 1 (il riassunto della traccia è nel piano 4) |
| 6.2 container stateless, proxy, editor non raggiungibile, limiti, CORS, database `dev_diary` | 2, 3, 9 |
| 6.2 protezione della demo, tetti | 5, 6, 8 |
| 6.2 reset e seed con date relative | 5, 7 (il cron di GitHub Actions è nel piano 2) |
| 6.3 contratto, modifiche agli endpoint, codici di errore, Markdown export, Postman | 4, 5, 6, 7, 8 |
| 6.5 controllo dei contrasti in CI | 9 |
| 6.6 test API, CI | 3, 6, 7, 8, 9 |
| 6.7 sviluppo locale con Docker | 3 |
| 6.2 hosting Render/Atlas, pubblicazione anticipata; 6.4 interfaccia; 6.8 documentazione | piani 2, 3, 4 |
