# jetvox

*a phoneme talking synth for monome norns*

[English](README.md) · [Italiano](README.it.md)

jetvox is a speaking, singing, babbling synth for **norns** (grid optional). It is inspired by the
**Flame MIDI Talking Synth** and by the **SpeakJet** speech chip it was built around. It runs
fully standalone, with no MIDI gear needed. You can play single phonemes, syllables, letters,
words and whole phrases, and sequence them on two voices.

It is not a 1:1 clone. It rebuilds the chip's architecture from its datasheet and adds what you
need to make music with it: sustain, pitch, scales, a 2 × 64-step sequencer with
OP-XY-style step components, a 5000-word vocabulary and its own effects.

## Features

- **SpeakJet-style voice engine**: a SuperCollider rebuild of the chip's
  "5-channel synthesizer":
  - 3 formant oscillators;
  - 2 noise/"distortion" oscillators;
  - an envelope generator (saw/sine/tri/square) acting as the glottis;
  - PWM-style lo-fi output.
- **the full SpeakJet code set**: the 72 allophones (codes 128–199) and 55 sound effects (codes
  200–254: robot, alarm, beeps, biological, DTMF, sonar, pistol, wow). It also understands the
  control codes: pauses, fast/slow, stress/relax, volume, speed, pitch, bend, repeat, delay.
- **two independent voices** (chip A / chip B), like the dual-chip Flame.
- **English text-to-speech**: NRL letter-to-sound rules plus about 550 exceptions. It picks the
  right SpeakJet allophone variants automatically (BE/BO, KE/KO, EB/OB, SE/SO…).
- **5000-word vocabulary**, browsable by letter or by 16 themes (numbers, colours, time, space,
  robot, music, emotions, animals, body, nature, actions, food, city, tech, fantasy, short words).
  It also comes with 64 ready-made phrases.
- **2 × 64-step sequencer**:
  - per step: pitch, gate (long notes), velocity and probability;
  - per track: directions (forward, reverse, ping-pong, random, drunk), swing, straight and
    triplet divisions, transpose, Flame-style tremolo and random.
- **16 step components**, OP-XY style, freely combinable on every step:
  - from the OP-XY: pulse, hold, multiply, velocity, ramp up/down, random, portamento, bend,
    tonality, jump, condition;
  - voice-specific: talk speed, formant shift, phoneme order (reverse, shuffle, stutter…),
    FX throw.
- **lane editor** on the SEQ page: edit note, sound, word, gate, velocity, probability and
  components right on the step.
- **grid**:
  - phoneme, syllable, effect, alphabet, word and step pages;
  - multi-step selection, record mode, hold (sustain), loop, babble generator, stutter.
- **effects**:
  - per voice: lo-fi/bitcrush, mixer drive, ring mod, pitch-tracking comb "robot";
  - master: tape ping-pong delay, ambient FDN reverb with shimmer, chorus, stutter/beat repeat,
    saturation, wavefolder, bitcrusher, limiter.
- **animated UI**: a mouth that follows the formants, a scope rebuilt from the synth registers
  and a formant spectrum curve.

## Requirements

- norns with the current `clock`/`params` API (2.7 or newer recommended)
- grid optional (128, varibright recommended)

## Install

From maiden:

```
;install https://github.com/unluogomoderatamentesicuro/jetvox
```

Then **SYSTEM > RESTART**. The script brings its own SuperCollider engine (`Engine_JetVox`),
which norns only compiles at startup. Restart again whenever you update the script.

On launch you get a splash screen and the voice says "ready" (any key skips it).

jetvox turns off the norns system reverb because it has its own. It turns it back on when you
leave the script, and you can re-enable it in PARAMETERS > effetti > "riverbero di sistema".

## Quick start

1. **PLAY page**: E2 picks a sound, E3 a note, K2 plays it (hold for sustain).
2. **WORDS page**: E2 picks a word, E3 jumps letter, K2 listens. **K3 drops the word into the
   selected step and moves on.** Do it four or five times and you have a phrase.
3. **SEQ page**: K2 starts the sequencer. K3 switches to the NOT lane, then E2/E3 give each word
   its own pitch.
4. Add some flavour in the CMP lane (K1+E3 picks a component, E3 sets its value) or on the grid
   STEP page.

## Pages

E1 changes page, K1 is shift. The UI labels are in Italian; this README uses the on-screen names.

| page | E2 | E3 | K2 | K3 |
|---|---|---|---|---|
| **PLAY** | sound | note | play (hold = sustain) | voice A/B · K1: write to step |
| **SEQ** | step · K1: lane | edit lane value (creates the step if empty) | play/stop · K1: track A/B | next lane · K1: clear step |
| **STEP** | field (sound, note, vol, gate, prob, 16 components) · K1: step | value | preview · K1: copy | paste · K1: clear |
| **TRACK** | field | value | play/stop · K1: babble | track A/B · K1: clear track |
| **WORDS** | word | letter / theme | listen · K1: letter/theme mode | **word → step** · K1: append to phrase |
| **TALK** | phrase (64) | – | speak · K1: one word per step | edit text · K1: whole phrase → step |
| **VOICE** | parameter | value | repeat last sound | voice A/B |
| **FX** | parameter | value | FX throw · K1+K2 held: stutter | next section |

### SEQ lanes

| lane | E3 | K1+E3 |
|---|---|---|
| **NOT** note | pitch (an empty step is created with the last sound you played) | octave |
| **SND** sound | phonemes, pauses, effects | jumps of 10 |
| **WRD** word | scroll the vocabulary right on the step | jump letter |
| **GAT** gate | 0 = natural length, 1–16 = hold for N steps | – |
| **VEL** velocity | 0–127 | ×10 |
| **PRB** probability | 0–100 % | ×10 |
| **CMP** components | value of the selected component (off, 1…10) | choose component |

### Building a phrase

- **WORDS + K3**: word by word. The bottom line shows the phrase so far. "spazio parole"
  (word gap, TRACK page) places words every 1–8 steps.
- **SEQ, WRD lane**: dial words directly on each step.
- **TALK + K1+K2**: type a sentence (or pick one of the 64 presets) and spread it one word per step.
- **grid**: words page + REC.

## Step components

Each step can carry any combination of the 16 components. Each has 10 values (like the OP-XY's
1…9, 0 keys); the last one is usually "random".

| # | name | does | values |
|---|---|---|---|
| 1 | **PULS** pulse | repeat the step N times without advancing | 1–9, rnd |
| 2 | **HOLD** hold | hold (sustain) the step for N steps | 1–9, rnd |
| 3 | **MULT** multiply | ratchet: N triggers inside the step | 2,3,4,5,6,7,8,12,16, rnd |
| 4 | **VELO** velocity | fixed volume | 4,8,16,32,64,100,112,127,0, rnd |
| 5 | **RMP+** ramp up | note climbs the scale on each pass | 2–6 positions over 1 or 3 octaves |
| 6 | **RMP-** ramp down | same, going down | same |
| 7 | **RAND** random | random note in scale | 2–6 notes over 1 or 3 octaves |
| 8 | **PORT** portamento | glide into and out of the step | 10–90 %, rnd |
| 9 | **BEND** bend | pitch bend shapes | down-up, up-down, bump down/up, spring out/in, fade down/up, random ×2 |
| 10 | **TONE** tonality | transpose | octave −/+, 5th +, 3rd +, 4th +, chromatic +/−, 2 oct +, 5th −, rnd |
| 11 | **JUMP** jump | jump elsewhere | to 1/5/9/13, fwd, back, fwd/back, stay, align to other track, rnd |
| 12 | **COND** condition | play only every Nth pass | 1:1 … 1:9, 50 % |
| 13 | **TALK** | speech speed | ×0.4 … ×4, stress, rnd |
| 14 | **FORM** | formant shift (deeper ↔ higher voice) | ×0.6 … ×2, rnd |
| 15 | **ORDR** | phoneme order | reverse, shuffle, first, last, stutter ×2/×3, vowels only, consonants only, every other, rnd |
| 16 | **THRW** | FX throw for the step | delay lo/mid/hi, reverb lo/mid/hi, delay+reverb, crush, ring, rnd |

## Grid

```
rows 1-5 : pads (depend on the grid page)
row  6   : 16 scale degrees (keyboard)
row  7   : 16 steps of the visible page of the selected track
row  8   : controls
```

**Row 8**

| x | function |
|---|---|
| 1 / 2 | track/voice A / B |
| 3 | **phonemes** page |
| 4 | **syllables** page |
| 5 | **effects** page |
| 6 | **text** page (alphabet, digits, phrases) |
| 7 | **words** page (vocabulary) |
| 8 | **step** page (components, multi-select) |
| 9 | shift (hold) |
| 10 | REC: pads you press are written to the selected step, which then advances |
| 11 | HOLD: pads sustain while held |
| 12 | LOOP: repeat the last sound |
| 13 | babble (shift: with random components) |
| 14 | **stutter** (hold) |
| 15 | next 16-step page (1–4) |
| 16 | play/stop (shift: restart) |

**Pad pages**

- **phonemes**: the 72 allophones (rows 1–4, row 5 x1–8) and pauses P0–P6 (row 5 x9–15).
- **syllables**: 24 onsets (rows 1–2), 32 vowels and diphthongs (rows 3–4), 16 codas (row 5).
  **Hold an onset (and a coda if you like), then press a vowel** to get "ba", "kot",
  "shiyng"… Front/back allophone variants are picked automatically.
- **effects**: robot, alarm, beeps, biological (rows 1–4); DTMF, sonar, pistol, wow (row 5).
- **text**: A–Z, digits 0–9, phrases 1–32.
- **words**: letters on rows 1–2. Row 2 also has x12 theme mode, x13/x14 page and x16 random
  word. Rows 3–5 hold 48 words.
- **step**: tap several steps on row 7 to select them together (shift+step clears the selection).
  Then:
  - row 1: component;
  - row 2: its value (x16 removes it);
  - row 3: gate;
  - row 4: velocity;
  - row 5: probability;
  - row 6: note.

  Every edit applies to all selected steps.

**Step gestures (row 7, on any page other than step)**

- tap: select and preview
- hold a step + press pads: append sounds to the step (build a syllable or a word)
- hold a step + press a note: set the step's note
- hold a step + press another step: set the track length
- shift (or K1) + step: clear it

## Effects

**Per voice** (PARAMETERS > voce A/B, or the VOICE page):
- lo-fi PWM amount, sample rate and bit depth (the "chip" sound)
- mixer drive
- ring mod
- pitch-tracking comb "robot" (mix, ratio, feedback)
- delay and reverb sends

**Master** (PARAMETERS > effetti, or the FX page):
- **delay**: tape ping-pong, tempo-synced or free; feedback above 1 self-oscillates
- **reverb**: FDN, decay up to 40 s, shimmer
- **chorus**
- **stutter**: 1/32 … 1/4
- **master**: saturation, wavefolder, bitcrusher, tone, level, limiter

## How it works / what was rebuilt

**There is no public dump of the SpeakJet.** It is a one-time-programmable microcontroller and its
"MSA sound component database" has never been extracted, so jetvox is a reconstruction:

- **the synth** follows the datasheet (figure 3, table B): register layout, oscillator ranges,
  envelope shapes, the S1/S2 envelope switches and the distortion oscillators.
  - jetvox adds **formant sync**: the glottal envelope resets the formant oscillators. This gives
    a harmonic, singable, more intelligible voice. Set sync to 0 for the chip's inharmonic AM
    character.
- **allophone names, codes, durations and example words** come from the datasheet (table E).
  The formant targets were rebuilt from standard American-English phonetic data (Peterson &
  Barney 1952, Hillenbrand 1995, Klatt 1980) and mapped onto the 5 oscillators.
  - Each allophone is a list of register frames. The transitions between frames are interpolated,
    which is the coarticulation the chip's MSA "calculates".
- **sound effects** are recreated from their names; DTMF uses the standard frequencies.
- **text-to-speech** uses NRL letter-to-sound rules (Elovitz et al., Naval Research Laboratory,
  1976, public domain), the same family as the TTS256 chip paired with the SpeakJet, plus a
  hand-made exception list.

Tip for a more "real chip" sound: sync 0.3–0.6, sample rate 8192, bits 8, lo-fi 1, tone 4000.

## Scripting from maiden

```lua
jv_say(1, {21,60, 22,120, 14,128, 1, 200})  -- raw SpeakJet codes on voice A
jv_text(2, "hello world")                   -- text-to-speech on voice B
```

Patterns (both tracks with all components) and phrases are saved with PSETs.

## Files

```
jetvox.lua              main script (pages, grid, params)
lib/Engine_JetVox.sc    engine: chip synth + effects bus
lib/msa.lua             SpeakJet code interpreter (0..254)
lib/seq.lua             2 x 64-step sequencer
lib/components.lua      16 step components
lib/syll.lua            syllable keyboard
lib/allophones.lua      72 allophones
lib/sfx.lua             55 sound effects
lib/tts.lua             English text -> allophones
lib/vocab.lua           vocabulary by letter
lib/vocab_more.lua      more words, themes, phrases
lib/ui.lua              graphics
lib/presets.lua         starting phrases
```

## Credits and references

- *SpeakJet User's Manual* rev 1.0, Magnevation LLC, 2004
- *Flame MIDI Talking Synth* user manual, Flame (fortschritt-musik)
- Elovitz, Johnson, McHugh, Shore, *Automatic Translation of English Text to Phonetics by Means of
  Letter-to-Sound Rules*, NRL Report 7948, 1976
- Peterson & Barney (1952); Hillenbrand et al. (1995); Klatt (1980), *Software for a
  cascade/parallel formant synthesizer*
- teenage engineering, OP-XY and OP-Z guides, step components

SpeakJet is a trademark of Magnevation LLC. Flame and OP-XY/OP-Z belong to their respective
owners. jetvox is an independent project, not affiliated with or endorsed by any of them, and it
contains no code or data from the original chip.

## License

MIT, see [LICENSE](LICENSE).
