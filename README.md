# Soundboard per Google Meet

Effetti sonori udibili dagli altri partecipanti nelle riunioni Google Meet, su macOS. Web app locale senza dipendenze + [BlackHole](https://github.com/ExistentialAudio/BlackHole) come cavo audio virtuale.

```
soundboard (http://localhost:8765) ──► BlackHole 2ch ─┐
                                                      ├─► "Mic + Soundboard" ──► mic di Meet
microfono fisico ─────────────────────────────────────┘
        └─ monitor locale via afplay (fuori da Chrome)
```

## Installazione

```sh
./setup/setup.sh
```

Lo script installa il driver BlackHole (brew), crea il dispositivo aggregato "Mic + Soundboard" e collega la skill Claude. Se il driver non risulta caricato ti chiederà di eseguire `sudo killall coreaudiod` e rilanciare.

## Uso

```sh
./start.sh   # avvia il server e apre la soundboard in Chrome
./stop.sh    # spegne tutto a fine giornata
```

In Meet: ⋮ → Impostazioni → Audio → **Microfono → "Mic + Soundboard"**, e cancellazione del rumore spenta (si mangia gli effetti).

Nella soundboard: trascina i tuoi mp3/wav sulla pagina (restano salvati nel browser), hotkey `1`–`9` per riprodurre, `Esc` per fermare tutto, "Test uscita" per verificare il collegamento a BlackHole. Suoni di partenza in `sounds/`.

Con Claude Code basta dire **"attiva la soundboard"** / **"disattiva la soundboard"**.

## Perché è fatta così (vincoli non ovvi)

- **La pagina deve girare su localhost**: aperta via `file://`, `setSinkId` (la selezione dell'uscita audio) fallisce silenziosamente e i suoni non raggiungono BlackHole.
- **Il monitor locale ("Ascolta anche tu") suona fuori da Chrome** (`server.py` → `afplay`): se suonasse nel browser, l'echo cancellation di Chrome lo userebbe come riferimento e cancellerebbe i suoni in Meet.
- **Nessun processo di mixaggio**: Chrome cattura tutti i canali del dispositivo aggregato (mic sul canale 1, BlackHole sui canali 2-3), quindi voce e suoni arrivano insieme senza passthrough.

Dettagli operativi e troubleshooting nella skill: [`skills/soundboard/SKILL.md`](skills/soundboard/SKILL.md).

## Struttura

```
soundboard.html            # la web app (vanilla JS, single file, IndexedDB)
server.py                  # serve la pagina + endpoint /monitor (afplay) e /stop
start.sh / stop.sh         # avvio e spegnimento
setup/setup.sh             # installazione one-shot (idempotente)
setup/create_aggregate.swift  # crea il dispositivo aggregato via CoreAudio
skills/soundboard/         # skill Claude (symlinkata in ~/.claude/skills)
sounds/                    # mp3 di partenza
```
