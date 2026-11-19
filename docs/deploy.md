# Pubblicare DevDiary

DevDiary online è fatto di tre pezzi, tutti su piani gratuiti:

| Pezzo | Dove | Cosa contiene |
|---|---|---|
| Database | MongoDB Atlas, cluster gratuito | database `dev_diary`, collection `entries` |
| API | Render, servizio web Docker `devdiary-api` | n8n 1.123.95 dietro il proxy (`api/`) |
| Sito | Render, sito statico `devdiary` | app Flutter web (`app/`) |

Il reset notturno delle note di esempio lo avvia GitHub Actions (`.github/workflows/demo-reset.yml`).

Account, password, stringhe di connessione e segreti li inserisce solo la persona titolare del progetto. Nessun segreto va nel repository.

---

## 1. MongoDB Atlas

1. Crea un account su <https://www.mongodb.com/cloud/atlas/register> e accedi.
2. Crea un progetto chiamato **DevDiary**.
3. Crea un cluster **gratuito** (Free), provider a scelta, regione in Europa (per esempio Francoforte).
4. **Database Access** → *Add New Database User*: autenticazione con password, nome `devdiary-api`, password generata da Atlas (copiala in un posto sicuro), ruolo *Read and write to any database*.
5. **Network Access** → *Add IP Address* → `0.0.0.0/0` (*Allow access from anywhere*). Serve perché il piano gratuito di Render non ha indirizzi IP fissi; l'accesso resta protetto da utente e password.
6. **Connect** → *Drivers* → copia la stringa `mongodb+srv://…`, sostituisci `<password>` e aggiungi in fondo le opzioni:

   ```
   mongodb+srv://devdiary-api:<password>@<cluster>.mongodb.net/?retryWrites=true&w=majority&serverSelectionTimeoutMS=5000&appName=devdiary
   ```

   `serverSelectionTimeoutMS=5000` fa rispondere l'API in 5 secondi se Atlas non è raggiungibile, invece di 30.

## 2. Render

1. Accedi a <https://dashboard.render.com> con il workspace di Loadout e LENA.
2. **New → Blueprint** → collega il repository `ash-ven/devdiary` → Render legge `render.yaml` e propone i due servizi.
3. Inserisci i valori richiesti:
   - `devdiary-api` → `MONGODB_URI`: la stringa del punto 1.6.
   - `devdiary-api` → `ALLOWED_ORIGINS`: per ora `https://devdiary.onrender.com` (l'indirizzo del sito; se Render ne assegna uno diverso lo correggi al punto 5).
   - `devdiary` → `API_BASE_URL`: `https://devdiary-api.onrender.com/webhook` (se Render assegna un indirizzo diverso all'API, usa quello, sempre con `/webhook` in fondo).
4. **Apply**. Il primo deploy dell'API dura qualche minuto; il sito installa Flutter durante il build e ne impiega circa 5–10.
5. Controlla gli indirizzi reali dei due servizi. Se differiscono da quelli inseriti, aggiorna `ALLOWED_ORIGINS` (API) e `API_BASE_URL` (sito) e rilancia il deploy di entrambi (*Manual Deploy → Deploy latest commit*).
6. Da `devdiary-api` → *Environment* copia il valore generato di `RESET_TOKEN` (serve al punto 3).

Le 750 ore gratuite mensili sono condivise fra i servizi del workspace: Loadout, LENA e DevDiary devono potersi addormentare quando nessuno li usa.

## 3. GitHub

Nel repository `ash-ven/devdiary` → *Settings* → *Secrets and variables* → *Actions*:

- **Secret** `RESET_TOKEN`: il valore copiato da Render.
- **Variable** `API_BASE_URL`: lo stesso indirizzo usato per il sito, con `/webhook`.

Poi *Actions* → **Reset della demo** → *Run workflow*: deve finire in verde.

## 4. Verifiche

Compilate dopo la pubblicazione (Task 7 del piano 2).

| Verifica | Esito | Note |
|---|---|---|
| Avvio a freddo (prima risposta dopo 15 minuti di inattività) | | |
| Newman `Produzione (sola lettura)` | | |
| CORS dall'origine del sito / da un'altra origine | | |
| Percorsi bloccati (`/rest/settings`, `/`, traversal) | | |
| X-Forwarded-For (`TRUSTED_PROXY_HOPS=1`) | | |
| Reset da GitHub Actions | | |
| Sito: lista, creazione, modifica, cestino, esempio protetto | | |
| Nessuna richiesta a Google Fonts | | |
