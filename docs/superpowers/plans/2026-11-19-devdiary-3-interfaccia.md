# DevDiary 3: nuova interfaccia, piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** sostituire l'interfaccia provvisoria con il "quaderno tecnico" del design: tre colonne, temi Carta e Blueprint, diario per giorno, foglio con Markdown e codice evidenziato, cestino, dashboard, pannello delle richieste API, schermata di risveglio, ricerca rapida, note di esempio riconoscibili, accessibilità WCAG 2.1 AA.

**Architecture:** lo stato esce dalle schermate e va in due `ChangeNotifier` condivisi (`DiaryStore`, `SettingsStore`) esposti con un `InheritedNotifier`; il service registra ogni richiesta in un `RequestLog`. I colori vengono generati da `tools/contrast/tokens.json` in una `ThemeExtension`, così l'interfaccia usa solo coppie verificate. Markdown ed evidenziazione del codice sono implementati in piccoli moduli propri e testati (sottoinsieme fisso, nessuna dipendenza abbandonata). I testi stanno in un file ARB italiano.

**Tech Stack:** Flutter 3.50.0, `material_ui`, `http`, `shared_preferences`, `flutter_localizations` + `intl` (gen-l10n), `url_launcher`; font Bricolage Grotesque (già incluso) e JetBrains Mono (da scaricare).

**Spec:** `docs/superpowers/specs/2026-11-19-devdiary-portfolio-design.md` (6.4 interfaccia, 6.5 colori e regole, 6.6 test). Riferimento visivo: `docs/design/mockup-quaderno.html`. Piani precedenti: `…-1-repository-e-api.md`, `…-2-pubblicazione.md`.

## Global Constraints

- Flutter 3.50.0; import da `package:material_ui/material_ui.dart`; `flutter analyze` senza problemi e `dart format --set-exit-if-changed` pulito.
- Colori **solo** da `DevDiaryTokens` (generato da `tools/contrast/tokens.json`), rispettando le coppie verificate: testo `ink`/`ink2`/`ink3` su `paper`/`sheet`; testo dei tipi `markTx_*` su `markBg_*`; grafici con `strong_*`; rosa come testo solo `accentText`; bordi dei campi `ruleStrong`; focus `focus`.
- Regole di visualizzazione della spec 6.5 (colore mai unico segnale, focus visibile 2px staccato di 2px, nessun testo sotto i 12px, rosa raro, tema scuro con i suoi token).
- Font: Bricolage Grotesque per l'interfaccia, JetBrains Mono solo per il codice, legature disattivate (`FontFeature.disable('liga')` e `'calt'`).
- Breakpoint: ≥ 1180 px tre colonne; 820–1179 px menu a icone + diario + foglio; < 820 px una colonna con navigazione diario → nota.
- Testi in `lib/l10n/app_it.arb`, italiano, frasi brevi, niente maiuscolo decorativo; gli errori dell'API si mostrano con il testo dell'ARB associato al `code`, altrimenti con il `message` dell'API.
- Movimento ridotto rispettato (`MediaQuery.disableAnimations`).
- Commit in inglese, stile convenzionale, chiusi da `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; lavoro sul branch `feat/ui`; push (che pubblica su Render) solo dopo conferma.

## Review Focus

1. **Note con testo lunghissimo, titoli di 120 caratteri, 10 tag, codice di 10.000 caratteri:** nessun overflow, il foglio scorre, le righe del diario troncano con ellissi. Test: Task 6 `long content does not overflow`.
2. **Markdown malformato o ostile** (`**` non chiuso, `[link](javascript:alert(1))`, HTML grezzo): testo letterale, nessun link non http(s). Test: Task 6 `markdown keeps broken syntax literal`, `markdown only links http and https`.
3. **Diario vuoto, filtro senza risultati, cestino vuoto:** stato vuoto con un invito ad agire, non una pagina bianca. Test: Task 5 `empty states invite to act`, Task 8 `empty trash`.
4. **Cambio di larghezza durante l'uso** (da tre colonne a una con una nota aperta): la selezione resta, nessuna eccezione di layout. Test: Task 4 `resizing keeps the selected note`.
5. **Tastiera sola:** tutte le azioni raggiungibili, Esc chiude ricerca e finestre, focus visibile. Test: Task 11 `keyboard opens and closes the command palette`, Task 12 (verifica manuale registrata).

---

## Mappa dei file

```
app/lib/
├─ main.dart                         avvio: semantics, visitor id, store, DevDiaryApp
├─ app.dart                          MaterialApp, temi, localizzazioni, scorciatoie globali
├─ l10n/app_it.arb                   testi
├─ theme/tokens.g.dart               GENERATO da tools/contrast/tokens.json
├─ theme/devdiary_theme.dart         ThemeData chiaro/scuro + ThemeExtension DevDiaryTokens
├─ theme/devdiary_fonts.dart         famiglie (ui, code)
├─ state/diary_store.dart            note, filtri, selezione, cestino, caricamento, errori
├─ state/settings_store.dart         tema, avviso demo chiuso (persistiti)
├─ state/scope.dart                  InheritedNotifier per i due store e il RequestLog
├─ services/…                        (esistenti) + request_log.dart
├─ text/markdown.dart                parser del sottoinsieme Markdown → nodi
├─ text/highlight.dart               tokenizzatore per dart, javascript, typescript, json, yaml, sql
├─ text/day_groups.dart              raggruppamento per giorno (Oggi, Ieri, data)
├─ text/activity.dart                mappa di attività (26 settimane)
├─ ui/shell.dart                     layout responsivo, menu, stato API, tema
├─ ui/diary_list.dart                diario per giorno, filtri, ricerca
├─ ui/note_sheet.dart                foglio della nota
├─ ui/markdown_view.dart, code_block.dart, type_mark.dart
├─ ui/note_form.dart                 nuova / modifica
├─ ui/trash_view.dart, dashboard_view.dart, settings_view.dart
├─ ui/request_panel.dart             pannello "Richieste all'API"
├─ ui/wake_screen.dart, demo_notice.dart, command_palette.dart
└─ (rimossi) screens/, widgets/ e DevDiaryColors
tools/contrast/to-dart.js            genera tokens.g.dart; la CI controlla che sia aggiornato
api/code/lib.js                      orari degli esempi di oggi nel passato (Task 13)
```

---

### Task 1: fondamenta (token, temi, font del codice, testi, formattazione)

**Files:** Create `tools/contrast/to-dart.js`, `app/lib/theme/tokens.g.dart`, `app/lib/theme/devdiary_theme.dart`, `app/lib/l10n/app_it.arb`, `app/l10n.yaml`, `app/test/theme_test.dart`; Modify `app/pubspec.yaml` (`flutter_localizations`, `intl`, `generate: true`, font JetBrains Mono), `.github/workflows/ci.yml`.

**Interfaces:**
- Produces: `class DevDiaryTokens extends ThemeExtension<DevDiaryTokens>` con un campo `Color` per ogni chiave di `tokens.json` (nomi camelCase: `paper`, `sheet`, `ink`, `ink2`, `ink3`, `primary`, `onPrimary`, `accent`, `accentText`, `ruleStrong`, `focus`, `ok`, `markBgNote` … `strongLink`, `codeBg`, `codePlain`, `codeKw`, `codeStr`, `codeFn`, `codeNum`, `codeComment`, `codeLineNo`, `codeBar`) e costanti `DevDiaryTokens.light` / `.dark`; i colori `rgba(...)` diventano `Color.fromRGBO`. `ThemeData buildTheme(Brightness b)`; `DevDiaryFonts.code = 'JetBrainsMono'`.
- `node tools/contrast/to-dart.js` scrive `tokens.g.dart`; `node tools/contrast/to-dart.js --check` esce con 1 se il file non corrisponde.

- [ ] **Step 1: chiedere il permesso di scaricare JetBrains Mono** (pesi 400 e 500, TTF statici dall'API CSS di Google Fonts, circa 110 KB l'uno, più `OFL.txt` da `github.com/JetBrains/JetBrainsMono`).
- [ ] **Step 2: test** `theme_test.dart`: `tokens match the verified palette` (`DevDiaryTokens.light.paper == Color(0xFFECEFF5)`, `.dark.markBgNote == Color.fromRGBO(183,155,255,.28)`); `light and dark themes carry the tokens` (`buildTheme(Brightness.dark).extension<DevDiaryTokens>()!.sheet == Color(0xFF16264A)`); `code font has ligatures off` (lo stile del codice contiene `FontFeature.disable('liga')`). Più un test Node `to-dart --check` sul file generato. Atteso: FAIL.
- [ ] **Step 3: implementare** generatore, tema, ARB iniziale (titolo, navigazione, stati vuoti ed errori per codice: `errorSampleReadOnly`, `errorDemoLimit`, `errorVisitorRequired`, `errorNotFound`, `errorDatabase`, `errorTimeout`, `errorNetwork`, `errorFieldInvalid`, `errorInternal`), `l10n.yaml` (`arb-dir: lib/l10n`, `template-arb-file: app_it.arb`).
- [ ] **Step 4: formattazione:** `dart format .` in `app/`; nella CI aggiungere `dart format --output=none --set-exit-if-changed .` e `node tools/contrast/to-dart.js --check`. `.gitattributes`: `* text=auto eol=lf` (rilievo M9 del piano 2).
- [ ] **Step 5: verifica** `flutter analyze`, `flutter test`; **commit** `feat(app): generated theme tokens, light and dark themes, code font, Italian strings`.

---

### Task 2: service completo e registro delle richieste

**Files:** Create `app/lib/services/request_log.dart`, `app/test/request_log_test.dart`; Modify `app/lib/services/diary_api_service.dart`, `app/lib/models/diary_entry.dart`, `app/test/diary_api_service_test.dart`.

**Interfaces:**
- Produces:
  - `DiaryEntry` con `bool isSample` e `String? deletedAt`.
  - `class RequestRecord { String method; String pathAndQuery; int status; int durationMs; DateTime at; }`; `class RequestLog extends ChangeNotifier { List<RequestRecord> get records /* ultime 20, la più recente prima */; void add(RequestRecord r); }`.
  - Service: `Future<ApiStatus> getStatus()` (`ApiStatus { bool databaseOk }`), `getEntries({..., bool trash = false})`, `getEntryById(id, {bool trash = false})`, `Future<String> createEntry(...)` (restituisce l'`_id`), `restoreEntry(id)`, `deleteEntry(id, {bool permanent = false})`, `Future<String> exportMarkdown()`; costruttore con `RequestLog? log` (default `RequestLog.shared`) e `Duration? statusTimeout`.
  - Timeout con annullamento reale (`http.AbortableRequest` con `abortTrigger`) — rilievo M2 del piano 2; corpo 2xx non JSON → `ApiException(status, 'FORMAT', …)` — M3; `code` usato solo se stringa — M4.
- [ ] **Step 1: test:** `logs every request with status and duration`; `keeps only the last 20 records`; `aborts the request on timeout` (il `MockClient` riceve la cancellazione e non completa la scrittura); `non-json success becomes FORMAT`; `numeric error codes fall back to HTTP status`; `restore and permanent delete call the right urls` (`POST …/diary/restore?id=…`, `DELETE …/diary?id=…&permanent=true`); `parses isSample and deletedAt`. Atteso: FAIL.
- [ ] **Step 2: implementare;** `flutter test`; **commit** `feat(app): full api client with trash, restore, request log and abortable timeouts`.

---

### Task 3: stato condiviso

**Files:** Create `app/lib/state/diary_store.dart`, `settings_store.dart`, `scope.dart`, `app/test/diary_store_test.dart`, `settings_store_test.dart`.

**Interfaces:**
- Produces:
  - `enum DiaryView { diary, favorites, dashboard, trash, settings }`; `class DiaryFilter { String? type; String? tag; String search; }`.
  - `class DiaryStore extends ChangeNotifier`: `view`, `filter`, `entries`, `trash`, `selectedId`, `selected`, `loading`, `error` (`ApiException?`), `apiStatus`; metodi `load()`, `setView`, `setFilter`, `select(id)`, `create(DiaryEntry)`, `update(DiaryEntry)`, `moveToTrash(id)`, `restore(id)`, `deletePermanently(id)`, `toggleFavorite(id)`; i preferiti sono il filtro `favorite=true` via API; la ricerca usa il parametro `search` con 300 ms di attesa dopo l'ultima battuta e ignora le risposte arrivate fuori ordine.
  - `class SettingsStore extends ChangeNotifier`: `ThemeMode themeMode` (default `system`), `bool demoNoticeDismissed`, persistiti con `shared_preferences` (chiavi `devdiary.theme`, `devdiary.demoNotice`), con lo stesso ripiego in memoria di `VisitorStore`.
  - `DevDiaryScope.of(context)` → `{diary, settings, log}`.
- [ ] **Step 1: test:** `load fills entries and clears error`; `load keeps the error from the api`; `search waits 300 ms and ignores stale responses`; `moveToTrash removes from the list and selection`; `sample notes cannot be edited` (`update` su `isSample` non chiama l'API e restituisce `errorSampleReadOnly`); `theme mode is persisted`; `storage failure keeps defaults`. Atteso: FAIL.
- [ ] **Step 2: implementare;** **commit** `feat(app): shared diary and settings state`.

---

### Task 4: guscio responsivo

**Files:** Create `app/lib/app.dart`, `app/lib/ui/shell.dart`, `app/test/shell_test.dart`; Modify `app/lib/main.dart`; Delete `app/lib/screens/`, `app/lib/widgets/`, `DevDiaryColors` (alla fine del Task 9, quando nessuna schermata vecchia è più usata).

**Interfaces:**
- Consumes: Task 1–3.
- Produces: `DevDiaryShell` con menu (Diario, Preferiti, Dashboard, Cestino, Impostazioni; conteggi), tag più usati, stato API (pallino + testo, `apiStatus`), selettore tema (Carta, Blueprint, Automatico); area centrale per vista; foglio a destra solo in `diary`/`favorites`/`trash`. `main()` chiama `SemanticsBinding.instance.ensureSemantics()` su web.
- [ ] **Step 1: test** (`tester.view.physicalSize` per le larghezze): `three columns at 1280`; `icon rail at 1000`; `single column at 600 with back navigation`; `resizing keeps the selected note`; `menu items are buttons with labels` (semantica). Atteso: FAIL.
- [ ] **Step 2: implementare;** **commit** `feat(app): responsive notebook shell`.

---

### Task 5: diario

**Files:** Create `app/lib/text/day_groups.dart`, `app/lib/ui/diary_list.dart`, `app/lib/ui/type_mark.dart`, test corrispondenti.

**Interfaces:**
- Produces: `List<DayGroup> groupByDay(List<DiaryEntry>, DateTime now)` con `DayGroup { String label /* Oggi, Ieri, «14 agosto», «14 agosto 2025» se anno diverso */; List<DiaryEntry> entries; }` (ora locale del browser, nomi in italiano con `intl`); `TypeMark(type)` (tinta `markBg_*` + testo `markTx_*` + etichetta scritta); righe con titolo, estratto su una riga, tipo, tag, stella, etichetta "Esempio" per `isSample`.
- [ ] **Step 1: test:** `groups today yesterday and older dates`; `labels other years with the year`; `rows show type label not only color`; `sample rows say Esempio`; `empty states invite to act` (diario vuoto: invito "Crea la prima nota"; filtro senza risultati: "Nessuna nota con questo filtro" + "Azzera filtri"); `long titles ellipsize`.
- [ ] **Step 2: implementare;** **commit** `feat(app): diary grouped by day with type marks and filters`.

---

### Task 6: foglio della nota, Markdown e codice

**Files:** Create `app/lib/text/markdown.dart`, `app/lib/text/highlight.dart`, `app/lib/ui/note_sheet.dart`, `markdown_view.dart`, `code_block.dart`, test corrispondenti; `flutter pub add url_launcher`.

**Interfaces:**
- Produces:
  - `List<MdBlock> parseMarkdown(String)`: blocchi `heading(level 1–3)`, `paragraph`, `bullet`, `numbered`, `codeFence(lang, text)`; inline `text`, `bold`, `italic`, `code`, `link(text, url)`; link accettati solo se `http://` o `https://`, altrimenti testo; nessun HTML.
  - `List<HlToken> highlight(String code, String? language)` con tipi `plain, keyword, string, number, comment, function`; linguaggi `dart, javascript, typescript, json, yaml, sql`; sconosciuto → tutto `plain`.
  - `NoteSheet`: tipo, data, titolo grande, tag, contenuto, blocco codice (numeri di riga, linguaggio, "Copia" → appunti + avviso "Codice copiato"), azioni Preferito / Modifica / Sposta nel cestino; per `isSample` azioni disattivate con il testo `sampleReadOnlyHint`; margine rosa a sinistra.
- [ ] **Step 1: test:** `parses headings lists bold italic code links`; `markdown keeps broken syntax literal`; `markdown only links http and https`; `highlights dart keywords strings comments`; `unknown language stays plain`; `copy puts the code on the clipboard`; `sample note actions are disabled with an explanation`; `long content does not overflow` (titolo 120, 10 tag, codice 10.000).
- [ ] **Step 2: implementare;** **commit** `feat(app): note sheet with markdown and highlighted code`.

---

### Task 7: nuova e modifica

**Files:** Create `app/lib/ui/note_form.dart`, test.

**Interfaces:** form con titolo, tipo (5 tipi), tag (separati da virgola), contenuto (Markdown), linguaggio, codice (font del codice); validazione con gli stessi limiti dell'API (titolo 120, contenuto 10.000, codice 10.000, 10 tag da 30); scegliendo il tipo `errore` con contenuto vuoto il campo si riempie con `## Problema\n\n## Causa\n\n## Soluzione\n`; salvataggio → selezione della nota salvata; errori dell'API mostrati con il testo per `code`.

- [ ] **Step 1: test:** `validates limits like the api`; `error type prefills the template`; `save selects the new note`; `api errors use the localized text` (403 `SAMPLE_READ_ONLY` → testo ARB).
- [ ] **Step 2: implementare;** **commit** `feat(app): note form with limits and error template`.

---

### Task 8: cestino

**Files:** Create `app/lib/ui/trash_view.dart`, test.

- [ ] **Step 1: test:** `lists trashed notes`; `restore brings the note back`; `permanent delete asks for confirmation` (dialog con "Elimina definitivamente" e "Annulla"; Esc annulla); `empty trash` (testo "Il cestino è vuoto").
- [ ] **Step 2: implementare;** **commit** `feat(app): trash with restore and permanent delete`.

---

### Task 9: dashboard

**Files:** Create `app/lib/text/activity.dart`, `app/lib/ui/dashboard_view.dart`, test; Delete vecchie schermate e `DevDiaryColors`.

**Interfaces:** `List<List<int>> activityGrid(List<DiaryEntry>, DateTime now)` (26 colonne × 7 righe, lunedì primo, conta `createdAt` e `updatedAt` diverso); livelli 0–4 con soglie fisse (0, 1, 2–3, 4–5, ≥6); dashboard con frase di riepilogo (numeri per tipo come `TypeMark`), mappa con legenda e numeri nel tooltip, barre per tipo con colori `strong_*` e numeri, cinque tag più usati, tre ultimi errori risolti.

- [ ] **Step 1: test:** `activity grid counts the last 26 weeks`; `levels follow fixed thresholds`; `dashboard shows numbers next to every chart`; `no data shows an empty state`.
- [ ] **Step 2: implementare;** rimuovere `screens/`, `widgets/`, `DevDiaryColors` e i test vecchi non più validi (`widget_smoke_test` riscritto sul guscio); **commit** `feat(app): dashboard with activity map; remove interim screens`.

---

### Task 10: pannello "Richieste all'API"

**Files:** Create `app/lib/ui/request_panel.dart`, test.

**Interfaces:** pannello in fondo all'area del foglio: righe con metodo, percorso con parametri, codice, durata in ms (ultime 20 dal `RequestLog`); schema Flutter → n8n → MongoDB che si anima a ogni nuova richiesta, statico con movimento ridotto; aperto di default ≥ 1180 px, chiuso sotto; titolo "Richieste all'API" e sottotitolo "cosa succede dietro ogni clic".

- [ ] **Step 1: test:** `shows real requests newest first`; `open by default only on wide screens`; `no animation with reduced motion`.
- [ ] **Step 2: implementare;** **commit** `feat(app): live api request panel`.

---

### Task 11: risveglio, avviso demo, impostazioni, ricerca rapida

**Files:** Create `app/lib/ui/wake_screen.dart`, `demo_notice.dart`, `settings_view.dart`, `command_palette.dart`, test.

**Interfaces:**
- Risveglio: all'avvio `getStatus` con 3 s; se non risponde, schermata dentro il guscio con spiegazione ("L'API è su un piano gratuito e si sta avviando"), secondi trascorsi, nuovi tentativi a intervalli crescenti (3, 5, 8, 13, 20 s…) fino a 120 s, poi pulsante "Riprova"; appena risponde carica il diario.
- Avviso demo: barra chiudibile al primo accesso ("È una demo: le note di esempio non si modificano, le tue le vedi solo tu e si cancellano ogni notte"), chiusura ricordata.
- Impostazioni: tema; indirizzo e stato dell'API; spiegazione dell'identificativo anonimo; link al repository e al README.
- Ricerca rapida: Ctrl K / Cmd K apre una finestra con campo di ricerca su titoli, contenuti e codice delle note caricate; frecce per scegliere, Invio apre, Esc chiude.
- [ ] **Step 1: test:** `wake screen retries with growing intervals and offers retry after 120 s` (`fakeAsync`); `wake screen disappears when the api answers`; `demo notice is remembered once closed`; `settings switch the theme`; `keyboard opens and closes the command palette`; `palette searches code too`.
- [ ] **Step 2: implementare;** **commit** `feat(app): wake screen, demo notice, settings and command palette`.

---

### Task 12: accessibilità, verifica visiva, pubblicazione

**Files:** Modify dove serve; Create `docs/design/screenshot/` (chiaro e scuro, tre larghezze).

- [ ] **Step 1: verifica manuale registrata nel registro:** giro completo solo da tastiera (Tab, Invio, Esc, Ctrl K); NVDA su lista, foglio, form; zoom 200%; movimento ridotto; temi chiaro e scuro; nessuna richiesta a Google anche con una nota che contiene emoji (registro di rete). Ogni problema trovato: test che lo riproduce, correzione.
- [ ] **Step 2: screenshot** del sito locale in Carta e Blueprint a 1440, 1000 e 390 px in `docs/design/screenshot/` (serviranno al piano 4).
- [ ] **Step 3: unione in `main` e conferma per il push** (il push ridistribuisce il sito su Render); poi controllo del sito pubblicato: apertura, una nota creata, modificata, spostata nel cestino e ripristinata.

---

### Task 13: API, orari degli esempi di oggi nel passato

**Files:** Modify `api/code/lib.js`, `api/code/lib.test.js`.

**Interfaces:** `seedToDocs(seed, now)`: per le voci con `daysAgo: 0` e orario successivo a `now`, la data diventa `now` meno (indice nel seed + 1) minuti, così dopo il reset delle 3 nessuna nota ha un orario futuro (rilievo M4 del piano 1).

- [ ] **Step 1: test** `seedToDocs never dates today's notes in the future` (`now = 2026-11-20T02:17:00Z`, voce `daysAgo:0, time:'10:12'` → `createdAt <= now`). Atteso: FAIL.
- [ ] **Step 2: implementare;** `npm test` in `api/`; **commit** `fix(api): sample notes of today are never dated in the future`.

---

## Copertura della spec

| Spec 6.4 / 6.5 | Task |
|---|---|
| Identità, temi Carta / Blueprint / Automatico, margine rosa, tipi come evidenziatori | 1, 4, 5, 6 |
| Caratteri, legature disattivate | 1 |
| Layout a tre breakpoint | 4 |
| Diario per giorno, filtri, ricerca | 5, 3 |
| Foglio con Markdown, codice, Copia, azioni | 6 |
| Nuova / modifica, modello per gli errori | 7 |
| Cestino | 8 |
| Dashboard | 9 |
| Impostazioni, ricerca rapida | 11 |
| Pannello "Richieste all'API" | 10, 2 |
| Risveglio del server | 11 |
| Note di esempio (etichetta, azioni disattivate, avviso) | 5, 6, 11 |
| Testi in ARB, errori per codice | 1, 7 |
| Regole di visualizzazione e accessibilità | 1, 12 (e ogni task) |
| Rilievi rimandati: M2–M4, M9 del piano 2; M4 del piano 1 | 2, 1, 13 |
