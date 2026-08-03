---
name: soundboard
description: Soundboard per Google Meet (repo ~/soundboard) — attivazione, spegnimento, installazione e troubleshooting. Trigger — "attiva la soundbar/soundboard", "disattiva/spegni la soundboard", "installa la soundboard", "la soundboard non funziona", "non si sentono i suoni in meet", o qualsiasi richiesta di suoni/effetti sonori durante riunioni Google Meet.
---

# Soundboard per Google Meet

Web app locale + BlackHole per sparare effetti sonori udibili dagli altri partecipanti in Google Meet. Repo: `~/soundboard`.

## Architettura (non cambiarla senza motivo)

```
soundboard (http://localhost:8765) ──► BlackHole 2ch ─┐
                                                      ├─► aggregato "Mic + Soundboard" ──► mic di Meet
microfono fisico ─────────────────────────────────────┘
        └─ monitor locale via afplay (server.py /monitor) — FUORI da Chrome
```

Vincoli scoperti a caro prezzo — violarli rompe tutto in modo silenzioso:

1. **La pagina DEVE girare su localhost**: via `file://` `setSinkId` fallisce silenziosamente e i suoni finiscono sulle casse invece che in BlackHole.
2. **Il monitor locale NON deve mai suonare dentro Chrome**: l'echo cancellation di Chrome lo usa come riferimento e cancella i suoni in Meet (sintomo: i suoni passano solo con "Ascolta anche tu" spento). Per questo il monitor passa da `server.py` → `afplay`.
3. **Niente passthrough sox/mic→BlackHole**: con l'aggregato duplica la voce (metallica). L'aggregato basta: Chrome cattura tutti i suoi canali.
4. **TCC**: binari nuovi compilati al volo NON hanno il permesso microfono (registrano silenzio a -91 dB); usare sox/ffmpeg che ce l'hanno già.

## Attivare ("attiva la soundboard")

1. Esegui `~/soundboard/start.sh` (avvia `server.py` su :8765 se giù e apre Chrome).
2. Verifica: `curl -sf http://localhost:8765/soundboard.html` → 200; `system_profiler SPAudioDataType | grep "Mic + Soundboard"` → esiste.
3. Ricorda all'utente (solo il primo avvio della giornata): in Meet ⋮ → Impostazioni → Audio → **Microfono = "Mic + Soundboard"** e cancellazione del rumore spenta; nella pagina il pallino deve dire "BlackHole collegato".

## Disattivare ("disattiva la soundboard")

Esegui `~/soundboard/stop.sh` (spegne server e monitor). Il dispositivo aggregato e il driver restano: sono passivi, non serve toccarli. L'utente deve solo rimettere il microfono normale in Meet se glielo chiede.

## Installare su un Mac nuovo

Esegui `~/soundboard/setup/setup.sh`: installa il cask `blackhole-2ch`, crea l'aggregato via `setup/create_aggregate.swift`, collega questa skill. Se il driver non è caricato, lo script si ferma e chiede all'utente di eseguire `sudo killall coreaudiod` (serve la sua password; `launchctl kickstart` è bloccato da SIP) e rilanciare.

## Troubleshooting

- **"Non si sente in Meet"** — in ordine di probabilità:
  1. Monitor che suona dentro Chrome (vincolo 2) — verificare che la pagina sia la versione con `/monitor`.
  2. Pagina aperta via `file://` (vincolo 1) — l'URL deve essere `http://localhost:8765/...`.
  3. Microfono sbagliato in Meet (deve essere "Mic + Soundboard").
  4. Uscita sbagliata nella soundboard (deve essere "BlackHole 2ch" o "Mic + Soundboard", equivalenti).
- **Misurare dove si interrompe la catena**: registrare BlackHole con `ffmpeg -f avfoundation -i ":BlackHole 2ch" -t 10 out.wav` mentre l'utente preme un pad, poi `ffmpeg -i out.wav -af volumedetect -f null -` → -91 dB = non arriva niente; per l'aggregato usare `-i ":Mic + Soundboard"` e `astats` per i livelli per-canale (ch1 = mic, ch2-3 = BlackHole).
- **BlackHole sparito dopo un update di macOS**: `ls /Library/Audio/Plug-Ins/HAL/` e se il driver c'è, far eseguire `sudo killall coreaudiod`.
- **Aggregato sparito**: rilanciare `swift ~/soundboard/setup/create_aggregate.swift`.
- **Aggiungere suoni**: trascinarli sulla pagina (persistono in IndexedDB); mp3 di backup in `~/soundboard/sounds/`, scaricabili da myinstants.com (link diretti `https://www.myinstants.com/media/sounds/<file>.mp3`).
