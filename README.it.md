# jetvox

*talking synth a fonemi per monome norns*

[English](README.md) · [Italiano](README.it.md)

Uno script per norns (+ grid opzionale) ispirato al **Flame Midi Talking Synth** e al chip
**SpeakJet** di Magnevation. È standalone: parla, canta, balbetta e sequenzia fonemi, sillabe,
lettere, parole e frasi senza MIDI esterno.

**Novità della v3**
- **Pagina SEQ a corsie**: nota, suono, parola, gate, volume, probabilità e componenti si modificano
  direttamente sullo step. E3 su uno step vuoto crea la nota.
- **Corsia PAROLA**: si scorre il vocabolario direttamente sullo step, per costruire frasi senza
  cambiare pagina.
- **Selezione multipla** degli step sul grid (come l'OP-XY), per dare gli stessi componenti a più step insieme.
- **Tastiera di sillabe** sul grid: consonante + vocale + finale, con le varianti SpeakJet scelte da sole.
- **Vocabolario di 5000 parole**, per lettera o in **16 temi** (numeri, colori, tempo, spazio,
  robot, musica, emozioni, animali, corpo, natura, azioni, cibo, città, tecnologia, fantasy,
  parole brevi). Più circa 200 eccezioni di pronuncia.
- **64 frasi pronte** in TALK.
- **Spazio tra parole** regolabile, per mettere le parole ogni 1–8 step.
- **Stutter / beat repeat** sul bus master (grid x14 tenuto, o K1+K2 nella pagina FX).
- **Grafica**: splash animato, oscilloscopio ricostruito dai formanti (PLAY), curva spettrale dei
  formanti (VOICE), SEQ ridisegnata con corsie, frase in costruzione visibile in WORDS, scrollbar.

---

## Installazione

1. Da maiden:

   ```
   ;install https://github.com/unluogomoderatamentesicuro/jetvox
   ```

   oppure copia la cartella in `~/dust/code/jetvox` sul norns (SMB/SFTP).
2. **SYSTEM > RESTART**: serve ogni volta che cambia l'engine, quindi anche aggiornando dalla v1/v2.
3. Seleziona `jetvox` dal menu SELECT. Appare lo splash e la voce dice "ready" (qualsiasi tasto lo salta).

Il riverbero di sistema di norns viene spento perché JetVox ha il suo. Si riaccende da PARAMETERS >
effetti > "riverbero di sistema" e viene ripristinato all'uscita.

```
jetvox/
  jetvox.lua              script principale (pagine, grid, parametri)
  lib/Engine_JetVox.sc    engine: 5-channel synth del chip + catena effetti
  lib/msa.lua             interprete dei codici SpeakJet (0..254)
  lib/seq.lua             sequencer 2 x 64 step
  lib/components.lua      16 step component
  lib/syll.lua            tastiera di sillabe
  lib/allophones.lua      72 allofoni (codici 128..199)
  lib/sfx.lua             55 effetti (codici 200..254)
  lib/tts.lua             testo inglese -> allofoni (regole NRL + eccezioni)
  lib/vocab.lua           vocabolario per lettera
  lib/vocab_more.lua      altre parole, temi, frasi pronte
  lib/ui.lua              grafica (bocca, oscilloscopio, curva formanti, splash)
  lib/presets.lua         frasi iniziali
```

---

## Come costruire una frase nel sequencer

Ci sono quattro modi, dal più veloce al più preciso.

**1. Pagina WORDS (consigliato)**
1. Pagina **SEQ**: con E2 scegli lo step da cui partire (es. A01).
2. Pagina **WORDS**: con E3 scegli la lettera (o, con K1+K2, un tema) e con E2 la parola. K2 la fa sentire.
3. **K3**: la parola va nello step e la selezione avanza. Ripeti per ogni parola.
4. La riga in basso mostra la frase che stai costruendo nella traccia.

"spazio tra parole" (pagina TRACK o PARAMETERS) decide ogni quanti step mettere le parole.

**2. Pagina SEQ, corsia PAROLA**
1. K3 fino alla corsia **WRD**.
2. E2 sceglie lo step, E3 scorre le parole direttamente sullo step (K1+E3 salta di lettera).
3. Ogni parola si sente mentre la scegli.

**3. Pagina TALK**
1. Scrivi la frase con K3, oppure scegline una delle 64 pronte.
2. **K1+K2**: le parole vengono distribuite su step consecutivi a partire da quello selezionato.
3. **K1+K3** invece mette tutta la frase in un solo step.

**4. Grid**
1. Pagina **PAROLE** (x7) e **REC** (x10) accesi.
2. Ogni parola premuta finisce nello step selezionato, che avanza.
3. Con lo SHIFT (x9) puoi ascoltare senza scrivere.

Poi dai a ogni parola la sua nota nella corsia NOTA e aggiungi componenti nella corsia CMP.

---

## Pagine norns

**E1** cambia pagina, **K1** è lo shift. In alto a destra le tab delle 8 pagine e il tempo, che
lampeggia a tempo quando il sequencer gira.

### PLAY: suonare un fonema alla volta
| | |
|---|---|
| E2 | scorre tutti i suoni (72 allofoni, 7 pause, 55 effetti) |
| E3 | nota |
| K2 | suona; tenendolo premuto il suono resta in sustain |
| K3 | voce A / B |
| K1+K3 | scrive il suono nello step selezionato e avanza |

In basso l'oscilloscopio ricostruito dai formanti.

### SEQ: il sequencer a corsie
In alto le due tracce in miniatura, poi le corsie, poi la vista della corsia scelta per i 16 step
della pagina corrente.

| | |
|---|---|
| E2 | seleziona lo step |
| **E3** | **modifica il valore della corsia** sullo step (se lo step è vuoto lo crea) |
| K3 | corsia successiva · K1+E2 sceglie la corsia |
| K1+E3 | variante: ottava (NOTA), salti da 10 (SUONO), lettera (PAROLA), ×10 (VEL/PROB), sceglie il componente (CMP) |
| K2 | play / stop · K1+K2 traccia A / B |
| K1+K3 | cancella lo step |

Le corsie:

| corsia | E3 fa |
|---|---|
| **NOT** nota | alza/abbassa la nota; su uno step vuoto crea uno step con l'ultimo suono suonato |
| **SND** suono | scorre fonemi, pause ed effetti |
| **WRD** parola | scorre il vocabolario direttamente sullo step |
| **GAT** gate | 0 = durata naturale, 1–16 = nota lunga per N step |
| **VEL** volume | 0–127 |
| **PRB** probabilità | 0–100% |
| **CMP** componenti | valore del componente scelto (off, 1…10); K1+E3 cambia componente |

Il "suono pennello" usato per creare step nuovi è sempre l'ultimo suono suonato: un fonema in
PLAY, una parola in WORDS, un pad del grid.

### STEP: tutto lo step in una pagina
| | |
|---|---|
| E2 | campo: suono, nota, volume, gate, probabilità, poi i 16 componenti (griglia 4×4) |
| E3 | valore · K1+E2 cambia step |
| K2 | ascolta · K1+K2 copia |
| K3 | incolla · K1+K3 cancella |

Se sul grid sono selezionati più step, le modifiche valgono per tutti; in alto compare "x3",
"x5", ecc.

### TRACK
tempo, divisione (1/2 … 1/32, terzine), **lunghezza 1–64**, direzione (avanti, indietro,
ping-pong, random, drunk), swing, trasposizione, mute, tremolo, random (stile Flame), retrigger,
root, scala, spazio tra parole, segui playhead.
- K2 play/stop · K3 traccia A/B
- K1+K2 babble con componenti · K1+K3 cancella la traccia

### WORDS: 5000 parole
| | |
|---|---|
| E2 | parola (girandolo veloce accelera) |
| E3 | lettera, oppure tema |
| K2 | ascolta · K1+K2 cambia modo: **per lettera / per tema** |
| **K3** | **inserisce la parola nello step e avanza** |
| K1+K3 | aggiunge la parola alla frase selezionata in TALK |

### TALK: 64 frasi
E2 frase · K2 pronuncia · K3 scrivi/modifica · K1+K2 **una parola per step** · K1+K3 tutta la
frase in uno step.

### VOICE e FX
E2 sceglie il parametro, E3 lo cambia.
- **VOICE**: mostra la bocca e la curva spettrale dei formanti. K2 ripete l'ultimo suono, K3 voce A/B.
- **FX**: K3 salta di sezione, K2 throw su delay e riverbero, **K1+K2 tenuto = stutter**.

---

## Step component (stile OP-XY)

Ogni step può avere **qualsiasi combinazione** dei 16 componenti. Ognuno ha 10 valori, come i
tasti 1…9, 0 dell'OP-XY (il decimo è quasi sempre "random"). I primi 12 seguono l'OP-XY, gli
ultimi 4 sono pensati per la voce.

| # | nome | cosa fa | valori |
|---|---|---|---|
| 1 | **PULS** pulse | ripete lo step N volte senza avanzare | 1–9, rnd |
| 2 | **HOLD** hold | tiene lo step (in sustain) per N step senza avanzare | 1–9, rnd |
| 3 | **MULT** multiply | divide lo step in N trigger (ratchet) | 2,3,4,5,6,7,8,12,16, rnd |
| 4 | **VELO** velocity | volume fisso | 4,8,16,32,64,100,112,127,0, rnd |
| 5 | **RMP+** ramp up | a ogni passaggio la nota sale nella scala | 2–6 posizioni su 1 o 3 ottave |
| 6 | **RMP-** ramp down | come sopra, scendendo | idem |
| 7 | **RAND** random | nota casuale nella scala | 2–6 note su 1 o 3 ottave |
| 8 | **PORT** portamento | glide verso e dallo step | 10–90%, rnd |
| 9 | **BEND** bend | curve di pitch bend | giù-su, su-giù, bump giù/su, spring out/in, fade giù/su, random 1/2 |
| 10 | **TONE** tonality | trasposizione | ottava −/+, quinta +, terza +, quarta +, cromatico +/−, 2 ottave +, quinta −, rnd |
| 11 | **JUMP** jump | salta a un altro step | a 1/5/9/13, avanti, indietro, avanti/indietro, resta, allinea all'altra traccia, rnd |
| 12 | **COND** condition | suona solo 1 volta ogni N passaggi | 1:1 … 1:9, 50% |
| 13 | **TALK** | velocità di pronuncia | ×0.4 … ×4, stress, rnd |
| 14 | **FORM** | formanti: voce più grave o più acuta | ×0.6 … ×2, rnd |
| 15 | **ORDR** | ordine dei fonemi dello step | reverse, shuffle, solo il primo, solo l'ultimo, stutter ×2/×3, solo vocali, solo consonanti, uno sì uno no, rnd |
| 16 | **THRW** | "throw" sugli effetti per la durata dello step | delay basso/medio/alto, riverbero basso/medio/alto, delay+riverbero, crush, ring, rnd |

Esempi:
- una parola con **ORDR shuffle** diventa un balbettio sempre diverso;
- **RMP+** su una vocale con gate 1 produce un arpeggio parlato;
- **COND 1:4 + THRW dly hi** lancia un'eco solo ogni quattro giri.

---

## Grid (16×8)

```
righe 1-5 : pad (cambiano con la pagina grid)
riga  6   : tastiera di 16 gradi della scala
riga  7   : 16 step della pagina visualizzata della traccia selezionata
riga  8   : controlli
```

**Riga 8:**

| x | funzione |
|---|---|
| 1 / 2 | traccia/voce A / B |
| 3 | pagina **FONEMI** |
| 4 | pagina **SILLABE** |
| 5 | pagina **EFFETTI** |
| 6 | pagina **TESTO** (alfabeto, cifre, frasi) |
| 7 | pagina **PAROLE** (vocabolario) |
| 8 | pagina **STEP** (componenti, selezione multipla) |
| 9 | SHIFT (tenere premuto) |
| 10 | REC: i pad premuti vanno nello step selezionato, che avanza |
| 11 | HOLD: tenendo un pad il suono resta in sustain |
| 12 | LOOP: ripete l'ultimo suono |
| 13 | BABBLE · SHIFT+13 con componenti casuali |
| 14 | **STUTTER** (tenuto) |
| 15 | pagina di step successiva (1–4); la luminosità indica la pagina |
| 16 | play / stop · SHIFT+16 riparte da capo |

**Pagine dei pad:**
- **FONEMI**: i 72 allofoni (righe 1–4 + riga 5 x1–8), pause P0–P6 (riga 5 x9–15).
- **SILLABE**:
  - righe 1–2: 24 consonanti iniziali;
  - righe 3–4: 32 vocali e dittonghi;
  - riga 5: 16 consonanti finali.

  **Tieni una consonante (e se vuoi una finale) e premi una vocale**: suona la sillaba, per esempio
  "ba", "kot", "shiyng". La consonante da sola suona da sola. Con REC le sillabe vanno nel sequencer.
- **EFFETTI**: Robot, Alarm, Beeps, Biological (righe 1–4), DTMF + Sonar/Pistol/Wow (riga 5).
- **TESTO**: alfabeto A–Z, cifre 0–9, frasi 1–32 (righe 4–5).
- **PAROLE**:
  - righe 1–2: lettera A–Z;
  - riga 2: x12 modo temi (riga 1 sceglie uno dei 16 temi), x13/x14 pagina, x16 parola a caso;
  - righe 3–5: 48 parole.
- **STEP**:
  - riga 7: **tocca più step per selezionarli insieme** (SHIFT+step azzera la selezione);
  - riga 1: componente; riga 2: valore 1–10 (x16 lo toglie);
  - riga 3: gate; riga 4: volume; riga 5: probabilità; riga 6: nota.

  Ogni modifica vale per tutti gli step selezionati.

**Gesti sugli step (riga 7, pagine diverse da STEP):**
- tocco: seleziona e ascolta
- tieni uno step + premi pad: aggiunge suoni allo step (una sillaba, una parola composta)
- tieni uno step + premi una nota: nota dello step
- tieni uno step + premi un altro step: lunghezza della traccia
- SHIFT (o K1) + step: cancella lo step

---

## Effetti

**Per voce** (PARAMETERS > voce A/B, o pagina VOICE):
- lo-fi PWM, sample rate e bit (il "suono chip")
- drive del mixer
- ring mod (mix, frequenza)
- comb "robot" accordato sul pitch della voce (mix, ratio, feedback)
- mandate verso delay e riverbero

**Master** (PARAMETERS > effetti, o pagina FX):
- **delay** ping-pong a nastro: tempo sincronizzato o libero, feedback (oltre 1 auto-oscilla),
  tono, wow, ritorno, mandata verso il riverbero
- **riverbero** FDN "ambient": size, decay fino a 40 s, damp, predelay, modulazione, **shimmer**
- **chorus**
- **stutter**: ripete l'ultimo frammento (1/32 … 1/4) finché è tenuto
- **saturazione**, **wavefolder**, **bitcrusher**, tono, livello, limiter finale

---

## Come funziona (cosa è stato ricostruito)

### 1. Il sintetizzatore (engine)
Dal manuale SpeakJet (Figura 3, Tabella B, registri 0-15):

| Chip | JetVox |
|---|---|
| Osc 1-3 (0-3999 Hz, volume 0-31) → Mixer 1 | 3 sinusoidi "formanti" |
| Osc 4-5 + *Distortion* (banda di rumore centrata sull'osc) → Mixer 2 | sinusoidi modulate da rumore a banda variabile |
| Envelope generator: saw / sine / tri / square | "glottide" a frequenza di pitch, stesse 4 forme |
| Switch S1 (osc 1-3 inviluppati) / S2 (osc 4-5 ½ inviluppati) | `env1` / `env2` |
| Mixer 5 + master volume → PWM 32 kHz, campioni a 8 kHz | sample&hold + bit reduction (`lofi`, `srate`, `bits`) |

**Estensione:** con `sync formanti` = 1 il glottide resetta la fase degli oscillatori formanti a ogni
periodo. Lo spettro diventa armonico (tipo FOF/VOSIM): voce più intelligibile e intonata.
Con `sync` = 0 torna il carattere inarmonico e metallico dell'AM libero.

### 2. MSA (Mathematical Sound Architecture)
`lib/msa.lua` interpreta **lo stesso set di codici del chip** (Tabella D/E):

| Codice | Funzione |
|---|---|
| 0-6 | pause (0, 100, 200, 700, 30, 60, 90 ms) |
| 7 / 8 | FAST (×0.5) / SLOW (×1.5) sul suono successivo |
| 14 / 15 | STRESS / RELAX |
| 20 X / 21 X / 22 X / 23 X | volume / speed / pitch (Hz) / bend |
| 26 X | repeat · 30 X delay (X·10 ms) · 31 reset |
| 128-199 | 72 allofoni |
| 200-254 | 43 effetti + 12 DTMF |

Ogni allofono è una sequenza di "frame" di registri (formanti, volumi, rumore, distortion).
I passaggi tra un frame e l'altro sono interpolati: è la coarticolazione che l'MSA "calcola"
tra un allofono e l'altro. Le plosive hanno occlusione, burst e aspirazione. I dittonghi
scivolano tra due target.

### 3. Il contenuto del chip
**Non esiste un dump pubblico del SpeakJet.** È un microcontrollore OTP e il "Sound Component
Database" non è mai stato estratto. Ho cercato firmware dump, emulatori (MAME, AtariVox) e
reverse engineering, senza risultati. Per questo:

- **nomi, codici, durate, parole d'esempio** degli allofoni e degli effetti vengono dal manuale (Tabella E);
- **i target formantici** sono ricostruiti da dati fonetici standard dell'inglese americano
  (Peterson & Barney 1952, Hillenbrand 1995, tabelle del sintetizzatore di Klatt 1980) e adattati
  ai 5 oscillatori;
- **gli effetti** (Robot, Alarm, Beeps, Biological, Sonar, Pistol, Wow) sono ricreati nello spirito
  dei nomi. I DTMF usano le frequenze standard, quindi sono esatti;
- **il TTS** usa regole lettera→fonema in stile NRL (Elovitz et al., Naval Research Lab 1976, pubblico
  dominio). È la stessa famiglia del chip TTS256 che veniva abbinato al SpeakJet. Poi sceglie
  automaticamente le varianti SpeakJet secondo la "Phonetic Usage Table": BE/BO all'inizio,
  EB/OB in fine parola, KE/KO, SE/SO, NE/NO ecc. in base alla vocale vicina.

Le fricative sorde (SE, SO, SH, TH, FF) sono state allungate rispetto ai 40-50 ms del chip per
renderle più intelligibili. Il valore originale resta in `chip_ms`.

---

## Suggerimenti

- **Melodia parlata in 30 secondi:** WORDS → K3 su 4–8 parole; SEQ → corsia NOT, E2/E3 per dare
  una nota a ogni parola; K2 play.
- **Scat / beatbox:** grid SILLABE con REC; poi in STEP seleziona alcuni step e dai MULT 3 o RAND.
- **Note lunghe:** corsia GAT (oppure HOLD tra i componenti).
- **Stesso effetto su più step:** grid pagina STEP, tocca gli step, scegli componente e valore.
- **Suono "vero chip":** sync 0.3–0.6, sample rate 8192, bit 8, lo-fi 1, tono 4000.
- **Robot vocoder:** comb robot mix 0.6, ratio 1, feedback 0.8, un po' di chorus.
- **Ambient:** mandata riverbero 0.6, decay 12 s, shimmer 0.5, delay 1/4. con wow 0.5.
- **Glitch:** stutter 1/32 tenuto su una parola lunga, oppure ORDR shuffle + MULT 4.
- **Da maiden:** `jv_say(1, {21,60, 22,120, 14,128, 1, 200})` manda codici SpeakJet grezzi;
  `jv_text(2, "hello world")` usa il TTS.

Pattern (entrambe le tracce con tutti i componenti) e frasi si salvano insieme ai PSET.

---

## Fonti

- *SpeakJet User's Manual* rev 1.0, Magnevation 2004 (in questa cartella)
- *Flame Midi Talking Synth* user manual (in questa cartella)
- Elovitz, Johnson, McHugh, Shore, *Automatic Translation of English Text to Phonetics by Means of
  Letter-to-Sound Rules*, NRL Report 7948, 1976
- Peterson & Barney (1952); Hillenbrand et al. (1995); Klatt (1980) *Software for a
  cascade/parallel formant synthesizer*
- teenage engineering, *OP-XY guide: step components* (https://teenage.engineering/guides/op-xy/step-components) e *OP-Z guide: step components*

SpeakJet è un marchio di Magnevation LLC. Flame e OP-XY/OP-Z appartengono ai rispettivi
proprietari. jetvox è un progetto indipendente, non affiliato né approvato da nessuno di loro, e
non contiene codice o dati del chip originale.

## Licenza

MIT, vedi [LICENSE](LICENSE).
