# DevDiary per il portfolio: design

Data: 19 novembre 2026. Stato: bozza, in attesa di approvazione.

## 1. Perché

DevDiary è il progetto finale del corso IFTS Backend & AI (estate 2026): un diario tecnico per salvare appunti, snippet, errori risolti, idee e link, con Flutter web come interfaccia, n8n come API e MongoDB come database. È stato consegnato e funziona in locale.

Ora deve diventare un pezzo del portfolio. Chi arriva dal portfolio (selezionatori, responsabili tecnici) deve poter **aprire un link e provare l'app vera**, capire in pochi secondi che dietro c'è un'API costruita con cura e trovarla bella e coerente. Il profilo presentato nel portfolio e nel CV è "backend developer in formazione": il backend deve vedersi, non solo l'interfaccia.

## 2. Obiettivi, non obiettivi, anti-obiettivi

**Obiettivi**
- Demo online gratuita con l'API vera (Flutter web + n8n + MongoDB), raggiungibile da un link.
- Nuova identità visiva: palette "Blu matita e rosa", logo "Foglio a margine", interfaccia "quaderno tecnico" come nel mockup.
- Accessibilità WCAG 2.1 AA (riferimento EN 301 549), già verificata sui colori.
- Correzioni e completamenti del backend previsti dalla traccia (versione avanzata compresa: soft delete).
- Test automatici di API e app, eseguiti in CI.
- Repository pubblico con il prima (consegna) e il dopo, README in inglese e in italiano, GIF e screenshot.

**Non obiettivi**
- Login, utenti, ruoli, multiutenza (esclusi anche dalla traccia).
- App native Android, iOS, Windows, macOS, Linux: il progetto diventa solo web.
- Hosting a pagamento o server sempre acceso.
- Cambiare tecnologie: restano Flutter web, n8n, MongoDB.
- Traduzione inglese dell'interfaccia in questo progetto (l'app è pronta a riceverla, vedi 6.4).

**Anti-obiettivi** (cose che renderebbero il lavoro un fallimento anche se "funziona")
- Credenziali del database o editor n8n raggiungibili da internet.
- Demo pubblica che si può riempire o rovinare in modo permanente.
- Dati o chiamate simulati presentati come reali.
- Pagina bianca o errore muto mentre il server gratuito si risveglia.
- Regressioni di accessibilità rispetto ai controlli già fatti.
- Rompere il contratto API della traccia: la collection Postman originale deve continuare a funzionare sugli endpoint esistenti.
- Modificare la cartella o lo zip della consegna.

## 3. Punto di partenza

**Consegna** in `C:\Users\a.venturi\Downloads\DevDiary_Consegna\DevDiary_Consegna` (e lo zip `DevDiary_Consegna.zip`). Non va toccata.
- `01_Flutter/dev_diary`: Flutter web, circa 2.900 righe in `lib/` (`models/diary_entry.dart`, `services/diary_api_service.dart`, `screens/` lista, dettaglio, form, dashboard, `widgets/diary_entry_card.dart`, `main.dart` con barra di navigazione in basso). Cartella `test/` vuota. Dipendenze: `http`, `google_fonts`. Indirizzo API fisso: `http://localhost:5678/webhook`.
- `02_n8n/DevDiary_API_workflow.json`: un workflow, 8 webhook (status, lista con filtri, dettaglio, creazione, modifica, eliminazione, export JSON e Markdown), nodi Code per validazione e normalizzazione, risposte 400/404/503.
- `03_Postman`: collection con tutte le request. `07_Database`: schema PostgreSQL di confronto. `05_Branding`: vecchio logo e palette.

**Già corretto il 19/11** nel workflow della consegna: `_id` restituito come stringa esadecimale (con n8n 1.123 e 2.47 arrivava come oggetto `{buffer}` e dettaglio, modifica ed eliminazione fallivano); `GET /diary` restituisce `[]` con database vuoto; l'export JSON restituisce tutte le note.

**Ancora aperto**
- `DELETE` risponde "Nota aggiornata correttamente" invece di "Nota eliminata".
- `GET /status` risponde `{"Status":"Ok"}`; la traccia chiede `{"status":"OK"}`.
- Nella consegna il database si chiama `App`; la traccia dice `dev_diary`.
- Impostazioni è solo decorativa; layout da telefono stirato su desktop; 13 controlli di contrasto falliti nel primo mockup.
- Su Windows `flutter build web` si ferma senza Modalità sviluppatore (symlink dei plugin per le piattaforme native). Compilando un progetto senza cartelle native il problema sparisce (verificato).

## 4. Vincoli

- **Render, piano gratuito**: il servizio web si spegne dopo 15 minuti senza traffico e si risveglia in circa un minuto; il filesystem si cancella a ogni riavvio, deploy o spegnimento; 750 ore al mese per workspace. I siti statici non si spengono. DevDiary va nello **stesso workspace di Loadout e LENA**: le 750 ore sono condivise, quindi nessuno dei servizi deve restare sempre acceso.
- **MongoDB Atlas**: l'account non esiste ancora; lo crea la persona titolare seguendo i passaggi del piano (creazione account e inserimento password non sono delegabili).
- **MongoDB Atlas, cluster gratuito**: 0,5 GB, circa 100 operazioni al secondo, un cluster per progetto, nessun backup; può essere disattivato se inattivo a lungo.
- **n8n**: versione fissata a `1.123.95` (provata il 19/11 con questo workflow). Il nodo MongoDB di questa versione non converte l'ObjectId in stringa: la conversione resta nelle risposte del workflow.
- **CORS**: l'app e l'API stanno su origini diverse.
- **Segreti** (stringa di connessione Atlas, chiave di cifratura n8n) solo nelle variabili d'ambiente di Render e nei secret di GitHub, mai nel repository.
- **Privacy**: nessuna richiesta a server di terzi dal browser oltre all'API (niente Google Fonts a runtime, niente analytics).
- **Accessibilità**: WCAG 2.1 AA, contrasti come da sezione 6.5.

## 5. Strade considerate

| Strada | Come | Pro | Contro |
|---|---|---|---|
| **A. Tutto online, gratuito** (scelta) | App Flutter come sito statico su Render; n8n su Render in un container che a ogni avvio reimporta workflow e credenziali; database su Atlas; reset notturno dei dati demo. | L'API è vera e si vede lavorare; costo zero; Render è già usato per Loadout e LENA. | Chi arriva dopo una pausa aspetta circa un minuto la prima risposta. |
| B. Demo senza backend | Dati di esempio nel browser, solo sito statico. | Istantanea, non si rompe mai. | Il backend non si vede; chiamate solo simulate. |
| C. Ibrida | Come A, ma l'app parte con dati locali e passa all'API quando è sveglia. | Esperienza più fluida. | Due fonti di dati da mantenere e testare. |

Scartati: n8n Cloud e Render a pagamento (inutili per un portfolio, restano un'evoluzione possibile).

È stata scelta **A**, perché mostra il backend vero, che è il punto di forza del profilo, a costo zero. L'attesa del risveglio va gestita con una schermata chiara (6.4).

## 6. Decisioni prese

### 6.1 Repository e storia

- Repository Git nuovo in `C:\Dev\devdiary`, pubblicato su GitHub come repository pubblico **`ash-ven/devdiary`**.
- **Primo commit**: il contenuto della consegna così com'è, estratto da `C:\Dev\devdiary\_archivio\DevDiary_Consegna_originale.zip` (lo zip originale del 6 ottobre, prima delle correzioni del 19/11; cartella esclusa da Git), con tag `consegna-ifts`. Secondo commit: le correzioni del 19/11 al workflow (identiche a quelle ora presenti nella cartella della consegna). Poi l'evoluzione in commit leggibili. Così il prima e il dopo restano consultabili e onesti.
- La traccia del corso (PDF) **non** viene pubblicata: in `docs/` va un riassunto scritto da noi dei requisiti e della rubrica. *(Scelta di chi ha scritto il design: i diritti sul PDF sono dell'ente del corso.)*
- Struttura proposta: `app/` (Flutter web), `api/` (workflow n8n, Dockerfile, script di avvio, seed), `postman/`, `docs/` (design, mockup, schema PostgreSQL, materiali del corso), `branding/`, `tools/` (controllo contrasti, generazione icone), `.github/workflows/`.
- Le cartelle e i file già presenti in `C:\Dev\devdiary` (`branding/`, `docs/design/`, `tools/`, questo documento) entrano nel repository.

### 6.2 Architettura e hosting

```
Browser ──► Render Static Site (Flutter web, build release)
   │
   └─HTTPS─► Render Web Service (Docker)
               ├─ proxy: espone solo /webhook/* e /healthz, limita richieste e dimensione
               └─ n8n 1.123.95 (porta interna, editor disattivato)
                     └─► MongoDB Atlas (cluster gratuito, database dev_diary, collection entries)
```

- **Frontend**: Render Static Site. Il build installa Flutter stabile fissato a una versione precisa ed esegue `flutter build web --release --dart-define=API_BASE_URL=...`. Se il build su Render risultasse impraticabile, ripiego: build in GitHub Actions e pubblicazione su GitHub Pages (stesso risultato per l'utente).
- **API**: Render Web Service gratuito da `api/Dockerfile` basato su `n8nio/n8n:1.123.95`. Lo script di avvio: genera la credenziale MongoDB dalla variabile `MONGODB_URI`, sostituisce nei JSON dei workflow i segnaposto (origini CORS consentite, ecc.), esegue `n8n import:credentials`, `n8n import:workflow`, attiva i workflow e avvia n8n. Il database interno di n8n (SQLite) può andare perso a ogni riavvio: tutto si ricostruisce dai file del repository.
- **Esposizione**: da internet devono essere raggiungibili solo `/webhook/*` e un endpoint di salute. Editor, API REST di n8n e pagina di configurazione iniziale **non** devono essere raggiungibili (`N8N_DISABLE_UI=true` più un piccolo proxy davanti a n8n nello stesso container che inoltra solo quei percorsi). Il proxy applica anche un limite per IP (indicativo: 60 richieste al minuto) e una dimensione massima del corpo (indicativo: 32 KB).
- **CORS**: i webhook accettano solo l'origine del sito pubblicato e, in sviluppo, `http://localhost:*`.
- **Database**: Atlas, database `dev_diary` (allineato alla traccia), collection `entries`.
- **Reset notturno**: il container gratuito di notte è spento, quindi un trigger pianificato dentro n8n non partirebbe. Il reset lo avvia **GitHub Actions** con un cron giornaliero (03:00 ora italiana): chiama `POST /webhook/demo/reset` con l'intestazione `X-Reset-Token` (segreto salvato nei secret di GitHub e nelle variabili di Render; senza token il webhook risponde 401). Il risveglio dura qualche minuto al giorno, poche ore al mese. Il workflow n8n di reset svuota le note non di esempio, ripristina quelle di esempio dal seed (`api/seed/entries.json`) e ricalcola le date (vedi sotto). Tiene la demo in ordine e il cluster Atlas attivo. *(Scelta di chi ha scritto il design: la logica resta in n8n, che è parte di ciò che il progetto mostra.)*
- **Date del seed**: il seed salva per ogni nota "giorni fa" e un orario; al reset le date diventano reali rispetto a quel giorno. Così "Oggi", "Ieri" e la mappa di attività restano vive. L'app dice chiaramente che sono note di esempio (vedi 6.4). *(Scelta di chi ha scritto il design.)*
- **Protezione della demo condivisa** (scelta della persona titolare: "esempi protetti, note private"):
  - Le note del seed hanno `isSample: true` e sono in sola lettura per tutti: modifica, preferito, cestino ed eliminazione rispondono 403 con codice `SAMPLE_READ_ONLY`. *(Che anche il preferito sia bloccato è una scelta di chi ha scritto il design: è una modifica come le altre.)*
  - L'app genera al primo avvio un identificativo anonimo casuale (UUID), lo conserva nel browser (`localStorage`) e lo invia in ogni richiesta con l'intestazione `X-Demo-Visitor`. Non contiene dati personali; il README e le Impostazioni lo spiegano.
  - Ogni visitatore vede le note di esempio più le proprie (`ownerId` uguale al suo identificativo); le note degli altri visitatori non sono visibili né raggiungibili (404). Lista, dettaglio, dashboard ed export seguono la stessa regola.
  - Il reset notturno elimina tutte le note con `isSample` diverso da `true`.
  - La protezione è attiva solo con la variabile d'ambiente `DEMO_MODE=true` (produzione). Con `DEMO_MODE=false` (sviluppo locale e test di contratto in CI) l'API si comporta come nella traccia: nessuna intestazione richiesta, tutte le note modificabili. In produzione una scrittura senza `X-Demo-Visitor` risponde 400 con codice `VISITOR_REQUIRED`.
- **Tetti alla demo**: al massimo 50 note per visitatore e 300 in totale; oltre, `POST /diary` risponde 429 con messaggio chiaro ("Hai raggiunto il limite della demo: le note si cancellano ogni notte").
- **Nessun ping** oltre al reset giornaliero: l'attesa al primo accesso è accettata e spiegata.
- **Pubblicazione anticipata**: appena backend e pipeline sono pronti si pubblica con l'interfaccia esistente aggiornata ai nuovi colori, senza diffondere il link; il nuovo design arriva poi per gradi. Riduce il rischio di scoprire tardi problemi di hosting. *(Scelta di chi ha scritto il design.)*

### 6.3 API: contratto e modifiche

Il contratto della traccia resta valido (endpoint, query parameter, niente `/:id` nel path). Modifiche:

| Endpoint | Cambiamento |
|---|---|
| `GET /status` | Risponde `{"status":"OK","database":"OK"}`; `database` è `"ERROR"` (e codice 503) se MongoDB non risponde. |
| `GET /diary` | Esclude le note nel cestino. Nuovo parametro `trash=true` per elencare solo il cestino. `_id` sempre stringa, `[]` se vuoto (già fatto). |
| `GET /diary/detail?id=` | `_id` stringa (già fatto); 404 anche per note nel cestino, a meno di `trash=true`. |
| `POST /diary` | Limiti: titolo ≤ 120 caratteri, contenuto ≤ 10.000, codice ≤ 10.000, al massimo 10 tag da ≤ 30 caratteri. 429 oltre il tetto della demo. |
| `PUT /diary?id=` | Stessi limiti; non modifica note nel cestino. |
| `DELETE /diary?id=` | **Soft delete** (versione avanzata della traccia): imposta `deletedAt`; risponde `{"success":true,"message":"Nota spostata nel cestino"}`. Con `permanent=true` elimina definitivamente una nota già nel cestino: `"Nota eliminata"`. |
| `POST /diary/restore?id=` | Nuovo: riporta una nota dal cestino. |
| `GET /diary/export/json`, `/markdown` | Escludono il cestino; `_id` stringa. |

- Nuovi campi: `deletedAt` (stringa ISO o `null`), `isSample` (booleano, `true` solo per il seed), `ownerId` (stringa o `null`; identificativo anonimo del visitatore in produzione). Nessun altro cambiamento al modello dati. `ownerId` non viene mai restituito nelle risposte.
- Nuovo endpoint `POST /demo/reset`, protetto da `X-Reset-Token` (401 senza token valido), usato solo dal cron di GitHub Actions.
- Errori sempre in JSON `{"error":true,"code":"TITLE_REQUIRED","message":"..."}`: il campo `code` è nuovo e stabile (in inglese, maiuscolo), `message` resta in italiano; codici HTTP 400, 401, 404, 429, 503. L'app mostra i propri testi in base a `code`, così una futura versione inglese non tocca l'API. *(Scelta di chi ha scritto il design.)*
- Il `content` può contenere **Markdown** (titoli, elenchi, grassetto, corsivo, codice in linea, link): l'app lo mostra formattato. Per le note di tipo `errore` il form propone un modello con `## Problema`, `## Causa`, `## Soluzione`.
- **Compatibilità con la traccia** significa: gli endpoint, i parametri e la forma delle risposte della traccia restano validi. La collection consegnata ha richieste incomplete (host letterale `Production_URL`, export senza URL, id fissi del vecchio database): resta in `docs/consegna/` come documento storico. In `postman/` c'è una copia ripulita con la variabile `{{baseUrl}}`, id presi dalle risposte precedenti, i nuovi casi e test automatici; gira in CI contro lo stack Docker locale. In produzione si esegue a mano solo la parte in sola lettura. *(Scelta di chi ha scritto il design.)*

### 6.4 Interfaccia

Riferimenti: `docs/design/mockup-quaderno.html` (struttura e comportamento), `docs/design/contrasto-wcag.html` (colori verificati), `docs/design/logo-finale.html`.

- **Identità**: quaderno tecnico. Tema chiaro "Carta" (carta a quadretti) e scuro "Blueprint" (cianografia), più "Automatico" che segue il sistema. Margine rosa sul foglio della nota. Tipi di nota come tratti di evidenziatore con etichetta scritta.
- **Caratteri**: Bricolage Grotesque per l'interfaccia, JetBrains Mono solo per il codice, legature disattivate. Inclusi come asset dell'app (licenza OFL), nessuna richiesta a Google a runtime.
- **Logo**: `branding/devdiary-logo.svg` nell'app; `branding/png/` sostituisce favicon e icone in `web/` (`favicon.ico`, `Icon-192/512`, `Icon-maskable-192/512`, `apple-touch-icon`); `manifest.json` con nome "DevDiary", colori di tema dalla palette.
- **Layout**: da 1180px in su tre colonne (menu, diario, foglio); 820–1179px menu a icone + diario + foglio; sotto 820px una colonna, con navigazione diario → nota.
- **Schermate e funzioni**
  - *Diario*: note raggruppate per giorno (Oggi, Ieri, data), filtri per tipo, preferiti e tag, ricerca.
  - *Foglio della nota*: tipo, data, titolo grande, tag, contenuto Markdown, blocco codice con colori della sintassi, numeri di riga, pulsante Copia, linguaggio. Azioni: preferito, modifica, sposta nel cestino.
  - *Nuova / modifica nota*: stesso form, validazione lato app coerente con i limiti dell'API, modello per gli errori.
  - *Cestino*: elenco, ripristina, elimina definitivamente (con conferma).
  - *Dashboard*: frase di riepilogo con i numeri per tipo, mappa dell'attività degli ultimi sei mesi (da `createdAt` e `updatedAt`), distribuzione per tipo, cinque tag più usati, ultimi errori risolti.
  - *Impostazioni*: tema (Carta, Blueprint, Automatico), indirizzo e stato dell'API, link al repository e al README.
  - *Ricerca rapida* con Ctrl K (Cmd K su Mac): titoli, testi e codice delle note.
- **Pannello "Richieste all'API"**: elenca le ultime 20 richieste **reali** fatte dall'app (metodo, percorso con parametri, codice di risposta, durata in ms), registrate nel livello service; schema Flutter → n8n → MongoDB che si anima a ogni richiesta (statico se l'utente ha chiesto meno movimento). Aperto di default da 1180px in su, chiuso sotto.
- **Note di esempio**: nel diario e nel foglio hanno un'etichetta "Esempio"; i pulsanti Modifica, Preferito e Cestino sono disattivati con una spiegazione ("Le note di esempio non si modificano: creane una tua per provare"). Un avviso discreto, chiudibile, spiega al primo accesso che si tratta di una demo: le tue note le vedi solo tu e si cancellano ogni notte.
- **Risveglio del server**: all'avvio l'app chiama `GET /status`. Se non risponde entro 3 secondi mostra una schermata dedicata: spiega che l'API è su un piano gratuito e si sta avviando, mostra il tempo trascorso, riprova a intervalli crescenti per 120 secondi, poi offre "Riprova". L'interfaccia (menu, logo) è visibile subito.
- **Configurazione**: indirizzo API da `--dart-define=API_BASE_URL`, predefinito `http://localhost:5678/webhook` in sviluppo.
- **Testi**: italiano, frasi brevi, verbi attivi, nessun maiuscolo decorativo; errori che dicono cosa è successo e cosa fare. Tutti i testi stanno in file di traduzione (ARB) fin dall'inizio, così aggiungere l'inglese in futuro non richiede di riscrivere le schermate; per ora si pubblica solo l'italiano. *(Scelta di chi ha scritto il design.)*

### 6.5 Colori e accessibilità

Token verificati (rapporto di contrasto ≥ 4,5:1 per il testo, ≥ 3:1 per bordi, focus, icone di stato e grafici; dettagli e script in `tools/contrast/`).

| Token | Carta (chiaro) | Blueprint (scuro) |
|---|---|---|
| fondo `paper` | `#ECEFF5` | `#0E1A33` |
| foglio `sheet` | `#F7F8FC` | `#16264A` |
| testo `ink` / `ink2` / `ink3` | `#14213D` / `#3D4663` / `#5C6378` | `#EAF0FF` / `#B8C4E3` / `#8D9BC0` |
| principale `primary` / su principale | `#2445A8` / `#FFFFFF` | `#9DB4FF` / `#0E1A33` |
| rosa `accent` (margine, stella, decorazioni) | `#FF2E83` | `#FF6FA8` |
| rosa come testo `accentText` | `#C2185B` | `#FF8DBA` |
| bordi dei campi `ruleStrong` | `#7E88A5` | `#5971A9` |
| focus | `#2445A8` | `#FFE066` |
| stato ok | `#1E7B45` | `#5FE39A` |
| appunto: tinta / testo / pieno | `#E4D9FB` / `#5321B5` / `#6F35D8` | `rgba(183,155,255,.28)` / `#DCCFFF` / `#B79BFF` |
| snippet | `#CDEFF0` / `#0A6670` / `#0E7C86` | `rgba(96,214,235,.26)` / `#A8EEF8` / `#5FD4E0` |
| idea | `#FFEFA6` / `#6E5300` / `#B28800` | `rgba(255,222,90,.26)` / `#FFE98F` / `#F2CE4A` |
| errore | `#FFD3E4` / `#A3104F` / `#E0186E` | `rgba(255,111,168,.28)` / `#FFC6DC` / `#FF6FA8` |
| link | `#D3F0DF` / `#1F6A43` / `#2E8B57` | `rgba(126,226,160,.24)` / `#C3F5D2` / `#6ED69A` |
| codice: fondo / testo | `#14213D` / `#EEF0FA` | `#0A1428` / `#EEF0FA` |
| codice: parole chiave, stringhe, funzioni, numeri | `#9DB4FF`, `#FF9CC5`, `#7FD8F0`, `#FFC37A` | `#9DB4FF`, `#FF9AA7`, `#7FD8F0`, `#FFC37A` |
| codice: commenti, numeri di riga, barra | `#8F98B8`, `#828AA2`, `#A9B3D6` | `#8F98B8`, `#767F99`, `#A9B3D6` |

**Regole di visualizzazione**
1. Testo normale almeno 4,5:1 sul suo sfondo; 3:1 solo per testo da 24px in su (19px in grassetto).
2. Bordi dei campi, focus, icone di stato e parti dei grafici almeno 3:1 rispetto a ciò che hanno accanto.
3. Il colore non è mai l'unico segnale: etichetta scritta per i tipi, stella piena più testo per i lettori di schermo per i preferiti, pallino più frase per lo stato dell'API.
4. Il rosa è un accento raro (margine, preferiti, errori, azioni che cancellano); come testo si usa `accentText`.
5. Nei grafici si usano i colori pieni dei tipi, mai le tinte, sempre con i numeri accanto.
6. Focus da tastiera sempre visibile: anello di 2px staccato di 2px dal componente.
7. Nessun testo sotto i 12px.
8. Il tema scuro usa i suoi token, non il chiaro invertito.

Oltre ai colori: tutte le funzioni raggiungibili da tastiera in ordine logico, Esc chiude ricerca e finestre, semantica attivata in Flutter web per i lettori di schermo, layout integro al 200% di zoom, movimento ridotto rispettato, aree cliccabili di almeno 44×44px dove possibile.

### 6.6 Qualità e test

- **Flutter**: `flutter analyze` senza avvisi; test unitari del modello (anche `_id` come stringa, oggetto `{buffer}` o assente; campi mancanti), del raggruppamento per giorno e del service con un client HTTP finto (codici di risposta, errori, risveglio con tentativi); test dei widget per lista, stato vuoto, errore con Riprova, schermata di risveglio, foglio con Markdown e codice, validazione del form.
- **API**: collection Postman con test (codici, forma delle risposte, `_id` stringa, validazioni, limiti, soft delete e ripristino, 429), eseguita con Newman contro lo stack locale in Docker due volte: con `DEMO_MODE=false` (contratto della traccia) e con `DEMO_MODE=true` (note di esempio in sola lettura, isolamento fra due visitatori diversi, `VISITOR_REQUIRED`, reset con e senza token).
- **CI** (GitHub Actions a ogni push): analisi e test Flutter, build web, stack API in Docker con test Newman, controllo dei contrasti dei token.
- **Verifiche manuali prima della pubblicazione**: giro completo solo da tastiera, prova con NVDA, zoom al 200%, Chrome e Firefox, primo accesso a server spento.

### 6.7 Sviluppo locale

- `docker compose up` in `api/` avvia MongoDB e n8n con la stessa immagine e lo stesso script di avvio della produzione, più il seed.
- L'app si avvia con `flutter run -d chrome` e `--dart-define=API_BASE_URL=http://localhost:5678/webhook`. Il progetto non ha cartelle native, quindi non serve la Modalità sviluppatore di Windows.
- Flutter è già installato in `C:\Dev\flutter` (stabile, Dart 3.14), non nel PATH.

### 6.8 Documentazione e materiali per il portfolio

- `README.md` in inglese e `README.it.md` in italiano: cosa fa, link alla demo (con nota sul risveglio), screenshot chiaro e scuro, GIF del flusso principale, schema dell'architettura, contratto API, come avviarlo in locale, scelte tecniche (perché n8n, perché MongoDB, confronto con PostgreSQL), prima e dopo (tag `consegna-ifts` e screenshot della consegna), cosa ho imparato, uso dell'AI.
- Video di 1–2 minuti: chi costruisce prepara la scaletta; la registrazione la fa la persona titolare del portfolio.

## 7. Lasciato a chi costruisce

- Gestione dello stato (preferire soluzioni semplici), suddivisione in componenti, librerie per Markdown, evidenziazione del codice e SVG.
- Ordine interno dei lavori, purché: base del repository → backend e test API → interfaccia → pubblicazione → documentazione.
- Contenuto del seed: circa 20 note realistiche in italiano su tutti e cinque i tipi, comprese quelle del mockup.
- Calcolo della mappa di attività, forma esatta del form, animazioni, testi di dettaglio secondo le regole della sezione 6.4.
- Dettagli del proxy (es. Caddy o un piccolo server Node nello stesso container), purché rispetti la sezione 6.2.

## 8. Domande emerse dalla revisione e risposte

1. **Protezione della demo condivisa**: note di esempio protette, note dei visitatori private nel loro browser (sezione 6.2).
2. **Account e nomi**: GitHub `ash-ven/devdiary` pubblico; Render nello stesso workspace di Loadout e LENA; account Atlas da creare (passaggi guidati nel piano). Gli indirizzi pubblici definitivi (sito e API) si conoscono dopo la creazione dei servizi su Render e alimentano `API_BASE_URL` e l'elenco delle origini CORS.
3. **Workflow consegnato prima delle correzioni**: esiste in `_archivio/DevDiary_Consegna_originale.zip` (sezione 6.1).
4. **Reset con il server addormentato, date del seed, collection Postman, lingua, pubblicazione anticipata, traccia del corso**: decisi da chi ha scritto il design, segnati come tali nelle sezioni 6.1–6.4.

Nessuna domanda aperta.
