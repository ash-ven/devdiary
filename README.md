# DevDiary

DevDiary è un'applicazione web che ho realizzato come progetto finale del corso.

L'idea è quella di avere un diario personale dedicato alla programmazione, in cui posso salvare appunti, errori, snippet di codice, idee e link utili.

Ho cercato di realizzare non solo le funzionalità richieste, ma anche un'interfaccia che fosse più personale e riconoscibile.

## Tecnologie utilizzate

Per il progetto ho utilizzato:

- Flutter per il frontend
- n8n per la gestione delle API e dei workflow
- MongoDB come database
- Postman per testare gli endpoint
- Dart


## Struttura del progetto

Il funzionamento generale è:

Flutter → API n8n → MongoDB

Flutter gestisce l'interfaccia e le azioni dell'utente, n8n riceve le richieste HTTP, esegue le varie operazioni e comunica con MongoDB. MongoDB contiene le note del diario.

Postman è stato utilizzato durante lo sviluppo per verificare le API indipendentemente da Flutter.

## Le note

Ogni elemento salvato nel diario può contenere:

- titolo
- contenuto
- tipo
- tag
- linguaggio
- codice
- preferito/non preferito
- data di creazione
- data dell'ultima modifica

I tipi disponibili sono:

- Note
- Snippet
- Idee
- Errori
- Link

Non tutti i campi sono obbligatori. Ad esempio linguaggio e codice possono rimanere vuoti.

## Funzionalità

Dalla Home è possibile visualizzare tutte le note presenti nel database, con aggiunta di filtri per visualizzare separatamente Note, Snippet, Idee, Errori e Link.

È inoltre possibile:

- cercare una nota tramite titolo o contenuto
- visualizzare solamente i preferiti
- creare nuove note
- modificare note esistenti
- eliminare una nota
- visualizzare il dettaglio di una nota

È presente anche una sezione Preferiti raggiungibile direttamente dalla barra di navigazione.

## Dashboard

Ho realizzato una Dashboard che mostra un piccolo riepilogo dei dati presenti nel diario, vengono mostrati:

- numero totale delle note
- numero degli snippet
- numero dei preferiti
- numero degli errori

## API

Le API sono state realizzate attraverso workflow n8n.

Gli endpoint principali sono:

GET /status

GET /diary

GET /diary/detail?id=...

POST /diary

PUT /diary?id=...

DELETE /diary?id=...

GET /diary/export/json

GET /diary/export/markdown

La GET del diario supporta anche parametri opzionali per filtrare i risultati, ad esempio per tipo, preferiti, tag e ricerca testuale.


## Gestione degli errori

Durante lo sviluppo ho cercato di gestire anche alcuni casi di errore, ad esempio:

- database non disponibile
- nota non trovata
- dati non validi
- problemi durante il caricamento

## Branding e interfaccia

Per DevDiary ho scelto di creare un'identità grafica personalizzata invece di mantenere l'aspetto standard di Flutter, i colori principali sono:

- Viola: #6F35D8
- Azzurro: #7F95D1
- Rosa: #FF2E83
- Sfondo: #FCFCFF
- Testo: #24175E

Come font principale ho utilizzato Manrope.
Ho inoltre realizzato un logo per DevDiary tramite aiuto di Intelligenza Artificiale e utilizzato elementi grafici ondulati nella parte superiore dell'interfaccia, sempre tramite supporto IA.

## MongoDB e PostgreSQL

Il database utilizzato è MongoDB.
Come esercizio di confronto ho anche progettato come potrebbe essere rappresentato lo stesso modello utilizzando PostgreSQL.

Nella versione relazionale ho invece previsto tre tabelle:
- entries
- tags
- entry_tags

La tabella entry_tags permette di creare la relazione tra le note e i rispettivi tag, lo schema si trova nella cartella 07_Database.

## Avvio del progetto

Per utilizzare il progetto è necessario avere MongoDB e n8n attivi, successivamente, dalla cartella del progetto Flutter:
flutter pub get

e poi:
flutter run -d chrome
L'app comunica con gli endpoint n8n tramite HTTP.

## Test

Gli endpoint sono stati testati tramite Postman prima di essere collegati all'interfaccia Flutter.

Al termine dello sviluppo il comando non segnala problemi.

## Utilizzo dell'AI

Durante la realizzazione del progetto ho utilizzato strumenti di AI come supporto allo sviluppo, li ho utilizzati soprattutto per:

- capire alcuni errori non immediatamente comprensibili
- ragionare sulla struttura dei workflow n8n
- correggere e migliorare, ma anche farmi guidare nella creazione di parti di codice
- lavorare sull'interfaccia grafica (logo e abbellimenti)
- organizzare i test

Le modifiche sono state provate progressivamente tramite Flutter, Postman, n8n e MongoDB prima di essere mantenute nel progetto.

## Possibili miglioramenti

Il progetto potrebbe essere ampliato in futuro e solo alcune idee sono:

- realizzare una vera sezione Impostazioni (ora inserita per mera estetica)
- permettere di cambiare tema o colori
- aggiungere altri dati alla Dashboard
- aggiungere autenticazione e utenti diversi
- rendere l'app utilizzabile anche da mobile

## Conclusione

DevDiary nasce come progetto didattico, ma ho cercato di trasformarlo in qualcosa che potesse essere realmente utile anche per me.
