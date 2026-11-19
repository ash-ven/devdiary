# DevDiary 2: pubblicazione anticipata, piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** mettere online DevDiary a costo zero: API su Render (container del piano 1) con database su MongoDB Atlas, app Flutter web su Render Static Site con i nuovi colori, il nuovo logo e i font inclusi, reset notturno da GitHub Actions; link funzionante ma non ancora diffuso.

**Architecture:** l'app diventa un progetto solo web, legge l'indirizzo dell'API da `--dart-define=API_BASE_URL`, invia `X-Demo-Visitor` con un UUID conservato nel browser e mostra i messaggi d'errore dell'API. Un `render.yaml` descrive i due servizi Render; i segreti li inserisce la persona titolare. Un workflow pianificato di GitHub Actions chiama il reset protetto. L'interfaccia resta quella attuale (il nuovo design è il piano 3).

**Tech Stack:** Flutter 3.50.0 (Dart 3.14), `http` (+ `http/testing.dart`), `shared_preferences`, Render (Docker web service + static site, piano gratuito), MongoDB Atlas (cluster gratuito), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-19-devdiary-portfolio-design.md` (sezioni 4, 6.2, 6.4 *Configurazione* e *Logo*, 6.5, 6.6, 6.7). Piano precedente: `docs/superpowers/plans/2026-11-19-devdiary-1-repository-e-api.md`.

## Global Constraints

- Flutter fissato a **3.50.0** (stessa versione in locale, in CI e nel build di Render). n8n resta `1.123.95`.
- Il progetto Flutter è **solo web**: nessuna cartella `android`, `ios`, `linux`, `macos`, `windows`.
- Indirizzo API: `const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:5678/webhook')`, normalizzato senza `/` finale.
- Produzione: `DEMO_MODE=true`, `ALLOWED_ORIGINS` = esattamente l'origine del sito (es. `https://devdiary.onrender.com`), `TRUSTED_PROXY_HOPS=1`, `MONGODB_DATABASE=dev_diary`.
- Segreti (`MONGODB_URI`, `RESET_TOKEN`, `N8N_ENCRYPTION_KEY`) mai nel repository. Creazione degli account (Atlas, Render), inserimento di password, stringhe di connessione e segreti li fa **la persona titolare**; l'esecutore prepara i passaggi e verifica il risultato.
- Nessuna richiesta del browser a Google Fonts: font inclusi nell'app, build con `--no-web-resources-cdn`.
- Colori presi da `tools/contrast/tokens.json` (tema chiaro); logo e icone da `branding/`.
- Push su GitHub solo dopo conferma esplicita della persona titolare (una conferma per ogni push).
- Commit in inglese, stile convenzionale, chiusi da `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Lavoro sul branch `feat/deploy`.

## Review Focus

1. **Primo accesso a server addormentato** (Render impiega circa un minuto): l'app non deve restare in attesa per sempre; ogni chiamata ha un timeout di 30 s e porta allo stato di errore con "Riprova". Test: Task 1 `times out slow responses`.
2. **`localStorage` non disponibile** (navigazione privata, cookie bloccati): l'identificativo del visitatore ricade su un valore in memoria, l'app non va in errore. Test: Task 2 `falls back to memory when storage fails`.
3. **`API_BASE_URL` con la barra finale**: niente `//` nei percorsi (il proxy li rifiuta con 404). Test: Task 1 `normalizes the base url`.
4. **Risposta d'errore non JSON** (pagina HTML di Render, 502): eccezione leggibile, nessun `FormatException`. Test: Task 1 `handles non-json error bodies`.
5. **Modifica di una nota di esempio** (403 `SAMPLE_READ_ONLY`): l'utente legge il messaggio dell'API, non "Errore 403". Test: Task 1 `exposes the api error message`.

---

## Mappa dei file

```
app/
├─ lib/services/api_config.dart          baseUrl normalizzato da API_BASE_URL
├─ lib/services/api_exception.dart       ApiException(statusCode, code, message)
├─ lib/services/diary_api_service.dart   client iniettabile, timeout, intestazione visitatore, errori
├─ lib/services/visitor_id.dart          generateVisitorId(Random), VisitorStore
├─ lib/theme/devdiary_fonts.dart         nomi delle famiglie di font
├─ lib/main.dart                         carica l'id del visitatore; DevDiaryColors con i nuovi colori
├─ assets/fonts/                         Bricolage Grotesque (+ OFL.txt)
├─ assets/images/devdiary_logo.png       nuovo logo
├─ web/                                  favicon.ico/png, icone, manifest.json, index.html
├─ tool/build_web.sh                     build riproducibile (CI e Render)
└─ test/                                 api_config, diary_api_service, visitor_id, widget smoke
render.yaml                              blueprint dei due servizi Render
.github/workflows/ci.yml                 + job Flutter
.github/workflows/demo-reset.yml         reset notturno e manuale
api/Dockerfile                           + N8N_BLOCK_ENV_ACCESS_IN_NODE=true
postman/build-collection.js              + cartella "Produzione (sola lettura)"
docs/deploy.md                           guida Atlas e Render, segreti, verifiche registrate
```

---

### Task 1: app solo web, indirizzo configurabile, errori leggibili

**Files:**
- Delete: `app/android`, `app/ios`, `app/linux`, `app/macos`, `app/windows`
- Create: `app/lib/services/api_config.dart`, `app/lib/services/api_exception.dart`, `app/test/api_config_test.dart`, `app/test/diary_api_service_test.dart`
- Modify: `app/lib/services/diary_api_service.dart`, schermate che mostrano gli errori (solo il testo del messaggio)

**Interfaces:**
- Produces:
  - `String normalizeBaseUrl(String raw)` e `final String apiBaseUrl = normalizeBaseUrl(const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:5678/webhook'));` in `api_config.dart`.
  - `class ApiException implements Exception { final int statusCode; final String code; final String message; }`; `toString()` restituisce `message`.
  - `DiaryApiService({http.Client? client, String? baseUrl, String? visitorId, Duration timeout = const Duration(seconds: 30)})`; metodi pubblici invariati (`getStatus`, `getEntries`, `getEntryById`, `createEntry`, `updateEntry`, `deleteEntry`). Statici `static http.Client? defaultClient` e `static String? defaultVisitorId` (Task 2): il costruttore usa `client ?? defaultClient ?? http.Client()`, `baseUrl ?? apiBaseUrl`, `visitorId ?? defaultVisitorId`. Così le schermate continuano a fare `DiaryApiService()` e i test impostano `defaultClient` con un `MockClient`.
  - Errore: corpo JSON con `message` → `ApiException(status, code ?? 'HTTP_<status>', message)`; corpo non JSON → `ApiException(status, 'HTTP_<status>', 'Il server ha risposto con un errore (<status>). Riprova tra poco.')`; timeout → `ApiException(0, 'TIMEOUT', 'Il server non risponde: potrebbe essere in avvio, riprova tra un minuto.')`; errore di rete → `ApiException(0, 'NETWORK', 'Impossibile raggiungere il server.')`.

- [ ] **Step 1: rimuovere le cartelle native** con `git rm -r`. Verifica: `flutter build web` funziona senza Modalità sviluppatore (nessun messaggio sui symlink).
- [ ] **Step 2: scrivere i test** (`flutter test`), usando `MockClient` di `package:http/testing.dart`:
  - `normalizes the base url`: `normalizeBaseUrl('https://a.example/webhook/')` → `'https://a.example/webhook'`; `'https://a.example/webhook///'` → senza barre finali; senza barra → invariato.
  - `builds urls without double slashes`: con `baseUrl: 'https://a.example/webhook/'`, `getEntries()` chiama esattamente `https://a.example/webhook/diary`.
  - `exposes the api error message`: risposta 403 `{"error":true,"code":"SAMPLE_READ_ONLY","message":"Le note di esempio non si modificano: creane una tua per provare"}` su `updateEntry` → `ApiException` con `code == 'SAMPLE_READ_ONLY'` e quel `message`.
  - `handles non-json error bodies`: 502 con `<html>Bad gateway</html>` → `ApiException(502, 'HTTP_502', 'Il server ha risposto con un errore (502). Riprova tra poco.')`.
  - `times out slow responses`: client che risponde dopo 200 ms, `timeout: Duration(milliseconds: 50)` → `ApiException` con `code == 'TIMEOUT'`.
  - `parses string ids from the new api`: lista con `_id` stringa e campi `isSample`, `deletedAt` → `DiaryEntry` con `id` uguale.
- [ ] **Step 3: `flutter test`.** Atteso: FAIL (file mancanti).
- [ ] **Step 4: implementare** `api_config.dart`, `api_exception.dart` e il service (client iniettato, `timeout` su ogni chiamata, nessun `http.get` di livello superiore). Le schermate mostrano `e.toString()` delle eccezioni: con `ApiException` diventa il messaggio dell'API.
- [ ] **Step 5: `flutter analyze` e `flutter test`.** Atteso: nessun problema, test verdi.
- [ ] **Step 6: commit** `feat(app): web-only project, configurable api url, readable api errors`.

---

### Task 2: identificativo anonimo del visitatore

**Files:**
- Create: `app/lib/services/visitor_id.dart`, `app/test/visitor_id_test.dart`
- Modify: `app/pubspec.yaml` (`flutter pub add shared_preferences`), `app/lib/services/diary_api_service.dart`, `app/lib/main.dart`, `app/test/diary_api_service_test.dart`

**Interfaces:**
- Consumes: `DiaryApiService` (Task 1).
- Produces:
  - `String generateVisitorId([Random? random])`: UUID v4 minuscolo con `Random.secure()` di default.
  - `class VisitorStore { static const key = 'devdiary.visitorId'; Future<String> load(); }`: legge l'id da `SharedPreferences`, lo crea e lo salva se manca o non è un UUID valido; se lo storage lancia un'eccezione restituisce un id in memoria (stabile per la sessione).
  - `DiaryApiService.defaultVisitorId` (dichiarato nel Task 1, impostato all'avvio in `main()` da `VisitorStore().load()`); ogni richiesta del service include `X-Demo-Visitor` se l'id è disponibile.

- [ ] **Step 1: scrivere i test:**
  - `generates uuid v4`: 100 id tutti conformi a `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$` e diversi tra loro.
  - `keeps the same id across loads`: con `SharedPreferences.setMockInitialValues({})`, due `load()` restituiscono lo stesso valore, salvato sotto `devdiary.visitorId`.
  - `replaces a malformed stored id`: valore iniziale `'abc'` → nuovo UUID valido.
  - `falls back to memory when storage fails`: `VisitorStore` con un fornitore di preferenze che lancia → `load()` restituisce un UUID valido, due chiamate stesso valore.
  - `sends the visitor header`: `MockClient` che registra le richieste; `getEntries`, `createEntry`, `updateEntry`, `deleteEntry` portano tutte `X-Demo-Visitor` uguale all'id configurato.
- [ ] **Step 2: `flutter test`.** Atteso: FAIL.
- [ ] **Step 3: implementare.** `VisitorStore` accetta nel costruttore `Future<SharedPreferences> Function()? prefs` per i test. `main()` diventa `async`: `WidgetsFlutterBinding.ensureInitialized()`, poi `DiaryApiService.defaultVisitorId = await VisitorStore().load();`, poi `runApp`.
- [ ] **Step 4: `flutter analyze` e `flutter test`.** Atteso: verdi.
- [ ] **Step 5: commit** `feat(app): anonymous demo visitor id sent with every request`.

---

### Task 3: font inclusi, nuovi colori, nuovo logo e icone

**Files:**
- Create: `app/assets/fonts/` (file `.ttf` + `OFL.txt`), `app/lib/theme/devdiary_fonts.dart`, `app/test/widget_smoke_test.dart`
- Modify: `app/pubspec.yaml` (rimuovere `google_fonts`, dichiarare i font), `app/lib/main.dart` e le schermate (sostituzione meccanica delle chiamate `GoogleFonts.manrope(...)`), `app/assets/images/devdiary_logo.png`, `app/web/*`

**Interfaces:**
- Produces: `class DevDiaryFonts { static const ui = 'BricolageGrotesque'; }`; `DevDiaryColors` con gli stessi nomi di oggi e i nuovi valori:

| nome | nuovo valore | token |
|---|---|---|
| `background` | `#ECEFF5` | `paper` |
| `card` | `#F7F8FC` | `sheet` |
| `blue` | `#2445A8` | `primary` |
| `lightBlue` | `#D6E0FA` | tinta del blu (derivata, non in `tokens.json`) |
| `purple` | `#6F35D8` | `strong_note` |
| `darkPurple` | `#5321B5` | `markTx_note` |
| `lightPurple` | `#E4D9FB` | `markBg_note` |
| `pink` | `#FF2E83` | `accent` |
| `lightPink` | `#FFD3E4` | `markBg_errore` |
| `text` | `#14213D` | `ink` |
| `secondaryText` | `#5C6378` | `ink3` |
| `border` | `#7E88A5` | `ruleStrong` |

- [ ] **Step 1: chiedere il permesso di scaricare i font.** File: Bricolage Grotesque, istanze statiche 400, 500, 600, 700, 800 (formato TTF, circa 60–80 KB l'una) dall'API CSS di Google Fonts (`fonts.googleapis.com/css2?family=Bricolage+Grotesque:wght@400;500;600;700;800`, che rimanda a `fonts.gstatic.com`), più il file di licenza OFL dal repository `github.com/google/fonts`. Elencare nome, fonte e dimensione prima di scaricare.
- [ ] **Step 2: scrivere il test** `widget_smoke_test.dart`: `app uses the bundled font and new colors` → `DiaryApiService.defaultClient` = `MockClient` che risponde `[]`, poi `pumpWidget(DevDiaryApp())`; il `Theme` ha `textTheme.bodyMedium!.fontFamily == 'BricolageGrotesque'` e `scaffoldBackgroundColor == Color(0xFFECEFF5)`; nessuna eccezione. Atteso: FAIL.
- [ ] **Step 3: implementare.** Dichiarare la famiglia `BricolageGrotesque` in `pubspec.yaml` con i pesi; sostituire `GoogleFonts.manrope(` con `TextStyle(fontFamily: DevDiaryFonts.ui, ` e `GoogleFonts.manropeTextTheme(x)` con `x.apply(fontFamily: DevDiaryFonts.ui)`; rimuovere l'import e la dipendenza; aggiornare `DevDiaryColors`. Copiare `branding/png/devdiary-logo-256.png` su `assets/images/devdiary_logo.png`; `web/`: `favicon.png` ← `branding/png/favicon-32.png`, aggiungere `favicon.ico`, icone ← `branding/png/Icon-*.png`, `apple-touch-icon.png`; `manifest.json`: `name`/`short_name` "DevDiary", `description` "Diario tecnico per sviluppatori", `background_color` `#ECEFF5`, `theme_color` `#2445A8`; `index.html`: `<title>DevDiary</title>`, stessa descrizione, `lang="it"`, link a `favicon.ico` e `apple-touch-icon.png`.
- [ ] **Step 4: `flutter analyze`, `flutter test`, `flutter build web --release --no-web-resources-cdn`.** Atteso: verdi; `grep -rl "fonts.googleapis.com\|fonts.gstatic.com" build/web` non trova riferimenti dell'app (annotare nel registro eventuali riferimenti del motore Flutter per i font di riserva: si risolvono nel piano 3).
- [ ] **Step 5: verifica visiva** nel pannello browser con lo stack locale: lista con le note di esempio, nuovi colori, nuovo logo e favicon. Screenshot nel registro.
- [ ] **Step 6: commit** `feat(app): bundled fonts, new palette, logo and web icons`.

---

### Task 4: build riproducibile e CI dell'app

**Files:**
- Create: `app/tool/build_web.sh`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Produces: `app/tool/build_web.sh` (bash, `set -euo pipefail`): se `flutter` non è nel PATH clona `https://github.com/flutter/flutter.git` al tag `3.50.0` (`--depth 1`) in `$HOME/flutter` e lo aggiunge al PATH; esce con errore chiaro se `API_BASE_URL` è vuota; esegue `flutter config --no-analytics`, `flutter pub get`, `flutter build web --release --no-web-resources-cdn --dart-define=API_BASE_URL="$API_BASE_URL"` dalla cartella `app/`. Output in `app/build/web`.

- [ ] **Step 1: verificare lo script in locale** (Git Bash, con Flutter già nel PATH): `API_BASE_URL=http://localhost:5678/webhook app/tool/build_web.sh` → `app/build/web/index.html` presente; senza `API_BASE_URL` → codice 1 e messaggio "API_BASE_URL mancante".
- [ ] **Step 2: job `app` in `ci.yml`**: `subosito/flutter-action@v2` con `flutter-version: 3.50.0`, `flutter analyze`, `flutter test`, poi `API_BASE_URL=http://localhost:5678/webhook app/tool/build_web.sh`, poi un passo che fallisce se `app/build/web` contiene `fonts.googleapis.com`.
- [ ] **Step 3: validare il YAML** (`npx -y js-yaml@4.1.0 .github/workflows/ci.yml`).
- [ ] **Step 4: commit** `ci: flutter analyze, tests and web build`.

---

### Task 5: blueprint Render, irrobustimento e guida

**Files:**
- Create: `render.yaml`, `docs/deploy.md`
- Modify: `api/Dockerfile`

**Interfaces:**
- Produces `render.yaml`:
  - servizio `devdiary-api`: `type: web`, `runtime: docker`, `plan: free`, `region: frankfurt`, `dockerfilePath: ./api/Dockerfile`, `dockerContext: ./api`, `healthCheckPath: /healthz`; variabili: `MONGODB_URI` (`sync: false`), `MONGODB_DATABASE=dev_diary`, `DEMO_MODE=true`, `ALLOWED_ORIGINS` (`sync: false`), `RESET_TOKEN` (`generateValue: true`), `N8N_ENCRYPTION_KEY` (`generateValue: true`), `TRUSTED_PROXY_HOPS=1`, `RATE_LIMIT_PER_MINUTE=60`.
  - servizio `devdiary`: `type: web`, `runtime: static`, `buildCommand: ./app/tool/build_web.sh`, `staticPublishPath: ./app/build/web`, variabile `API_BASE_URL` (`sync: false`), `routes: [{ type: rewrite, source: /*, destination: /index.html }]`, intestazioni `X-Content-Type-Options: nosniff` e `Referrer-Policy: strict-origin-when-cross-origin` su `/*`.
- `docs/deploy.md`, in italiano, sezioni: *MongoDB Atlas* (account, progetto "DevDiary", cluster gratuito in Europa, utente del database con password generata, accesso di rete `0.0.0.0/0` con la motivazione: Render gratuito non ha IP fissi, stringa di connessione `mongodb+srv://…/?retryWrites=true&w=majority&serverSelectionTimeoutMS=5000&appName=devdiary`); *Render* (Blueprint dal repository, valori da inserire: `MONGODB_URI`, `ALLOWED_ORIGINS` = URL del sito, `API_BASE_URL` = URL dell'API + `/webhook`; ordine: prima l'API, poi il sito, poi aggiornare `ALLOWED_ORIGINS`); *GitHub* (secret `RESET_TOKEN` copiato da Render, variabile `API_BASE_URL`); *Verifiche* (tabella compilata nel Task 7).

- [ ] **Step 1: `api/Dockerfile`**: aggiungere `N8N_BLOCK_ENV_ACCESS_IN_NODE=true` (rilievo M10 del piano 1). Verifica: `docker compose -f api/docker-compose.yml up -d --build --wait` e Newman `Contratto` e `Demo` → verdi.
- [ ] **Step 2: scrivere `render.yaml`** e validarlo come YAML; controllare che nessun valore segreto sia scritto in chiaro (`grep -nE "mongodb\+srv|value: .{30,}" render.yaml` vuoto).
- [ ] **Step 3: scrivere `docs/deploy.md`**.
- [ ] **Step 4: commit** `chore(deploy): render blueprint, deployment guide, block env access in code nodes`.

---

### Task 6: reset notturno da GitHub Actions

**Files:**
- Create: `.github/workflows/demo-reset.yml`

**Interfaces:**
- Consumes: `POST /webhook/demo/reset` con `X-Reset-Token` (piano 1); secret `RESET_TOKEN` e variabile di repository `API_BASE_URL` (Task 7).
- Produces: workflow "Reset della demo" su `schedule: cron "0 2 * * *"` (03:00 in inverno, 04:00 in estate, ora italiana) e `workflow_dispatch`; `permissions: {}`; un passo che, se mancano secret o variabile, scrive un avviso e termina con successo; altrimenti `curl --fail-with-body --retry 6 --retry-delay 20 --retry-all-errors --max-time 120 -X POST -H "X-Reset-Token: $RESET_TOKEN" "$API_BASE_URL/demo/reset"` e controlla che la risposta contenga `"Demo ripristinata"`. Il token passa solo da `env:` (mai nella riga di comando stampata).

- [ ] **Step 1: scrivere il workflow** e validarlo (`npx -y js-yaml@4.1.0`).
- [ ] **Step 2: prova in locale** della stessa riga `curl` contro `http://localhost:5680/webhook` con il token di sviluppo → risposta con `"Demo ripristinata"`; con token sbagliato → codice d'uscita diverso da 0.
- [ ] **Step 3: commit** `ci: nightly demo reset`.

---

### Task 7: pubblicazione guidata e verifiche in produzione

**Files:**
- Modify: `postman/build-collection.js` (cartella `Produzione (sola lettura)`), `docs/deploy.md` (sezione *Verifiche*)

**Interfaces:**
- Consumes: tutto quanto sopra.
- Produces: cartella Postman `Produzione (sola lettura)`: `GET status` → 200 `{status:'OK',database:'OK'}`; `GET lista anonima` → 200, solo `isSample:true`, `length == seedCount`; `GET dettaglio di un esempio` → 200; `POST senza visitatore` → 400 `VISITOR_REQUIRED` (non scrive nulla). Ambiente `postman/produzione.postman_environment.json` con `baseUrl` dell'API pubblica (senza segreti).

- [ ] **Step 1: unire `feat/deploy` in `main` e chiedere conferma per il push.** Prima del push: tutta la CI locale verde (test API, Newman, contrasti, `flutter analyze`/`test`/build).
- [ ] **Step 2: guida passo passo alla persona titolare** secondo `docs/deploy.md`: Atlas (account, cluster, utente, rete, stringa), Render (Blueprint, `MONGODB_URI`, primo deploy dell'API, URL dell'API; poi il sito con `API_BASE_URL`; poi `ALLOWED_ORIGINS` con l'URL del sito e nuovo deploy dell'API), GitHub (secret `RESET_TOKEN`, variabile `API_BASE_URL`). L'esecutore non inserisce credenziali né segreti.
- [ ] **Step 3: verifiche, registrate in `docs/deploy.md`:**
  - avvio a freddo: tempo della prima risposta di `GET /webhook/status` dopo almeno 15 minuti di inattività (`curl -w "%{time_total}"`);
  - Newman `Produzione (sola lettura)` → verde;
  - CORS: preflight con l'origine del sito → `Access-Control-Allow-Origin` uguale; con `https://example.com` → valore diverso dall'origine richiesta;
  - percorsi bloccati in produzione: `/rest/settings`, `/`, `/webhook-test/x/../../webhook/y` → 404;
  - X-Forwarded-For: 61 richieste a `/webhook/status` con prima voce falsa diversa a ogni richiesta → la 61ª risponde 429 (conferma che conta l'IP aggiunto da Render; se non risponde 429, registrare il comportamento e correggere `TRUSTED_PROXY_HOPS` con un nuovo deploy);
  - reset: la persona titolare avvia "Reset della demo" da GitHub (Run workflow) → job verde; la lista mostra 21 esempi;
  - sito: si apre all'URL di Render, mostra le note di esempio, crea una nota propria, la modifica, la sposta nel cestino; modifica di un esempio → messaggio "Le note di esempio non si modificano…"; nessuna richiesta a `fonts.googleapis.com`/`fonts.gstatic.com` nel registro di rete (annotare eventuali richieste del motore per i font di riserva).
- [ ] **Step 4: commit** `docs(deploy): production checks` e push dopo conferma.

---

## Copertura della spec in questo piano

| Spec | Task |
|---|---|
| 6.2 hosting Render e Atlas, CORS, segreti, reset notturno da GitHub Actions, pubblicazione anticipata | 5, 6, 7 |
| 6.4 *Configurazione* (`API_BASE_URL`), *Logo* (favicon, icone, manifest), *Note di esempio* (intestazione visitatore) | 1, 2, 3 |
| 4 *Privacy* (niente Google Fonts a runtime) | 3, 4, 7 |
| 6.5 colori dai token verificati | 3 (valori), piano 3 (verifica delle combinazioni nell'interfaccia nuova) |
| 6.6 CI dell'app | 4 |
| 6.7 progetto senza cartelle native | 1 |
| Rilievi rimandati dal piano 1: M10 (`N8N_BLOCK_ENV_ACCESS_IN_NODE`), avvio a freddo, timeout Atlas, X-Forwarded-For, origine CORS | 5, 7 |
| 6.4 resto dell'interfaccia (layout, temi, pannello API, risveglio, Markdown, Ctrl K, cestino, dashboard), 6.8 documentazione | piani 3 e 4 |
