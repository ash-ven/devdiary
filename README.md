# DevDiary

Il diario di chi programma: appunti, snippet, errori risolti, idee e link, scritti in Markdown con il codice evidenziato.

**Provalo:** https://devdiary-2a6a.onrender.com

Il server è su un piano gratuito: se dorme, la prima apertura impiega circa un minuto e l'app lo mostra mentre si sveglia. Le note di esempio si leggono soltanto. Le note che crei le vedi solo tu e vengono cancellate ogni notte.

## Com'è fatto

- **App:** Flutter web, con temi chiaro (Carta) e scuro (Blueprint), ricerca rapida con Ctrl K e un pannello che mostra le richieste reali all'API.
- **API:** workflow n8n dietro un piccolo proxy Node, in Docker.
- **Dati:** MongoDB Atlas.
- **Pubblicazione:** Render (`render.yaml`), con un reset notturno della demo tramite GitHub Actions.
- **Test:** test Flutter e Node, contratto dell'API con Postman/Newman, contrasto dei colori WCAG 2.1 AA. La CI li esegue a ogni push.

## In locale

```bash
cd api && docker compose up -d          # MongoDB + API su :5678 (contratto) e :5680 (demo)
cd app && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5680/webhook
```

Dettagli su pubblicazione e verifiche in `docs/deploy.md`; il design in `docs/superpowers/specs/`.

## Origine

È nato come esercizio di un corso IFTS. La consegna originale è conservata nel tag `consegna-ifts`.
