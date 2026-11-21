-- allophones.lua
-- I 72 allofoni del set SpeakJet (codici 128..199), con nomi, parole
-- d'esempio e durate presi dal manuale (Tabella E).
--
-- Il contenuto del "MSA Sound Component Database" del chip non e' mai stato
-- estratto pubblicamente: i target formantici qui sotto sono ricostruiti da
-- valori standard dell'inglese americano (Peterson & Barney 1952,
-- Hillenbrand 1995, tabelle di Klatt 1980) e adattati all'architettura a
-- 5 oscillatori del chip:
--   f  = {F1,F2,F3}  -> oscillatori 1..3 (inviluppati dal glottide)
--   a  = {A1,A2,A3}  -> volumi osc 1..3 (0..1)
--   n  = {F4,F5}     -> oscillatori 4..5 (rumore con "distortion")
--   na = {A4,A5}     -> volumi osc 4..5
--   dist             -> distortion (0 = sinusoide pura, 1 = banda di rumore)
--   e2               -> osc 4..5 "half enveloped" (fricative sonore)
-- Ogni allofono e' una lista di segmenti; i campi mancanti ereditano dal
-- segmento precedente (cosi' la coarticolazione nasce dal glide dei registri,
-- esattamente come fa l'MSA che "calcola le transizioni" tra allofoni).
--   d   = frazione della durata dell'allofono
--   ms  = durata assoluta (ms) - usata per occlusioni/burst delle plosive
--   lag = tempo di transizione dei formanti (ms)
--   alag= tempo di transizione dei volumi (ms)

local A = {}

local SIL3 = {0, 0, 0}
local SIL2 = {0, 0}

local function V(f1, f2, f3, a, extra)
  local s = {f = {f1, f2, f3}, a = a or {1, 0.55, 0.3}, na = SIL2, dist = 0, e2 = 0}
  if extra then for k, v in pairs(extra) do s[k] = v end end
  return s
end

-- vocali di riferimento (riusate per dittonghi e R-colorate)
local IY = {270, 2290, 3010}
local IH = {390, 1990, 2550}
local EY = {480, 2050, 2650}
local EH = {530, 1840, 2480}
local AE = {660, 1720, 2410}
local AX = {500, 1500, 2500}
local UX = {640, 1190, 2390}
local OH = {700, 1150, 2500}
local AW = {600, 900, 2450}
local OW = {460, 850, 2400}
local UH = {440, 1050, 2250}
local UW = {300, 870, 2240}
local RR = {320, 1100, 1450}
local WW = {290, 620, 2150}
local LO = {400, 880, 2650}

local function vowel(f, a) return {V(f[1], f[2], f[3], a)} end

-- dittongo: tiene il primo target per p1 della durata poi scivola al secondo
local function diph(fa, fb, p1, aa, ab)
  p1 = p1 or 0.4
  return {
    V(fa[1], fa[2], fa[3], aa, {d = p1}),
    V(fb[1], fb[2], fb[3], ab or aa, {d = 1 - p1, lagf = 1 - p1}),
  }
end

-- plosive -------------------------------------------------------------
-- locus = formanti di partenza, burst = {F4,F5}, voiced = barra di sonorita'
local function stop(o)
  local segs = {}
  local vb = o.voiced and {0.12, 0, 0} or SIL3
  -- occlusione: la voce precedente scivola verso il locus mentre si spegne
  -- (transizione vocale->consonante), poi silenzio / barra di sonorita'
  segs[#segs + 1] = {ms = o.closure or 35, f = o.locus, a = vb, na = SIL2,
                     n = o.burst, dist = 1, e2 = 0, lag = 18, alag = 14}
  -- burst
  segs[#segs + 1] = {ms = o.burstms or 10, na = o.burstamp or {0.55, 0.28},
                     dist = o.bdist or 1, alag = 2}
  if o.asp then
    -- aspirazione (sorde): rumore attraverso le zone formantiche
    segs[#segs + 1] = {ms = o.asp, n = o.aspn or {o.locus[2], o.locus[3]},
                       na = {0.2, 0.14}, dist = 1, alag = 6}
  end
  if o.final then
    segs[#segs + 1] = {ms = 12, a = SIL3, na = SIL2, alag = 10}
  elseif o.voiced then
    -- inizio della sonorizzazione sul locus: la vocale seguente vi scivola
    segs[#segs + 1] = {ms = o.onset or 15, a = {0.65, 0.3, 0.15}, na = SIL2, alag = 6}
  else
    segs[#segs + 1] = {ms = 5, na = SIL2, alag = 6}
  end
  return segs
end

-- fricative -----------------------------------------------------------
local function fric(o)
  local s = {n = o.n, na = o.na, dist = o.dist or 1, e2 = o.voiced and 1 or 0,
             a = o.a or SIL3, alag = 10}
  if o.f then s.f = o.f end
  return {s}
end

-- tabella ---------------------------------------------------------------
-- {code, nome, esempi, tipo, durata_ms, segmenti}
local T = {
  {128, "IY", "See, Even, Feed", "vocale lunga", 70, vowel(IY, {0.9, 0.45, 0.4})},
  {129, "IH", "Sit, Fix, Pin", "vocale breve", 70, vowel(IH, {1, 0.5, 0.35})},
  {130, "EY", "Hair, Gate, Beige", "vocale lunga", 70, vowel(EY)},
  {131, "EH", "Met, Check, Red", "vocale breve", 70, vowel(EH)},
  {132, "AY", "Hat, Fast, Fan", "vocale breve", 70, vowel(AE)},
  {133, "AX", "Cotten", "vocale breve", 70, vowel(AX, {1, 0.5, 0.25})},
  {134, "UX", "Luck, Up, Uncle", "vocale breve", 70, vowel(UX, {1, 0.6, 0.25})},
  {135, "OH", "Hot, Clock, Fox", "vocale breve", 70, vowel(OH, {1, 0.65, 0.2})},
  {136, "AW", "Father, Fall", "vocale breve", 70, vowel(AW, {1, 0.7, 0.15})},
  {137, "OW", "Comb, Over, Hold", "vocale lunga", 70, vowel(OW, {1, 0.6, 0.15})},
  {138, "UH", "Book, Could, Should", "vocale breve", 70, vowel(UH, {1, 0.5, 0.15})},
  {139, "UW", "Food, June", "vocale lunga", 70, vowel(UW, {1, 0.4, 0.1})},
  {140, "MM", "Milk, Famous", "nasale", 70, vowel({250, 1000, 2200}, {0.7, 0.08, 0.05})},
  {141, "NE", "Nip, Danger, Thin", "nasale", 70, vowel({250, 1750, 2600}, {0.7, 0.12, 0.08})},
  {142, "NO", "No, Snow, On", "nasale", 70, vowel({250, 1300, 2450}, {0.7, 0.12, 0.06})},
  {143, "NGE", "Think, Ping", "nasale", 70, vowel({260, 2100, 2700}, {0.65, 0.12, 0.08})},
  {144, "NGO", "Hung, Song", "nasale", 70, vowel({260, 1350, 2300}, {0.65, 0.12, 0.06})},
  {145, "LE", "Lake, Alarm, Lapel", "risonante", 70, vowel({330, 1350, 2750}, {0.85, 0.35, 0.2})},
  {146, "LO", "Clock, Plus, Hello", "risonante", 70, vowel(LO, {0.85, 0.35, 0.15})},
  {147, "WW", "Wool, Sweat", "risonante", 70, vowel(WW, {0.8, 0.3, 0.08})},
  {148, "RR", "Ray, Brain, Over", "risonante", 70, vowel(RR, {0.8, 0.5, 0.4})},
  {149, "IYRR", "Clear, Hear, Year", "vocale+R", 200, diph(IY, RR, 0.45)},
  {150, "EYRR", "Hair, Stair, Repair", "vocale+R", 200, diph(EH, RR, 0.45)},
  {151, "AXRR", "Fir, Bird, Burn", "vocale+R", 190, diph({480, 1350, 1650}, {420, 1250, 1500}, 0.5, {1, 0.55, 0.4})},
  {152, "AWRR", "Part, Farm, Yarn", "vocale+R", 200, diph(OH, RR, 0.45)},
  {153, "OWRR", "Corn, Four, Your", "vocale+R", 185, diph({500, 850, 2400}, RR, 0.45)},
  {154, "EYIY", "Gate, Ate, Ray", "dittongo", 165, diph(EY, IY, 0.4)},
  {155, "OHIY", "Mice, Fight, White", "dittongo", 200, diph({720, 1250, 2550}, {330, 2200, 2900}, 0.4)},
  {156, "OWIY", "Boy, Toy, Voice", "dittongo", 225, diph({520, 850, 2400}, {330, 2200, 2900}, 0.4)},
  {157, "OHIH", "Sky, Five, I", "dittongo", 185, diph({720, 1250, 2550}, IH, 0.4)},
  {158, "IYEH", "Yes, Yarn, Million", "dittongo", 170, diph(IY, EH, 0.25)},
  {159, "EHLL", "Saddle, Angle, Spell", "dittongo", 140, diph(EH, LO, 0.45)},
  {160, "IYUW", "Cute, Few", "dittongo", 180, diph(IY, UW, 0.3)},
  {161, "AXUW", "Brown, Clown, Thousand", "dittongo", 170, diph({680, 1300, 2450}, {320, 870, 2250}, 0.4)},
  {162, "IHWW", "Two, New, Zoo", "dittongo", 170, diph({360, 1700, 2450}, UW, 0.3)},
  {163, "AYWW", "Our, Ouch, Owl", "dittongo", 200, diph({700, 1350, 2450}, WW, 0.45)},
  {164, "OWWW", "Go, Hello, Snow", "dittongo", 131, diph(OW, {320, 800, 2250}, 0.45)},
  {165, "JH", "Dodge, Jet, Savage", "affricata sonora", 70, (function()
    local s = stop({voiced = true, locus = {250, 1900, 2700}, burst = {2800, 3600}, closure = 30, final = false})
    s[#s] = {ms = 50, n = {2600, 3500}, na = {0.4, 0.18}, a = {0.4, 0.1, 0.05}, dist = 0.85, e2 = 1, alag = 8}
    return s
  end)()},
  {166, "VV", "Vest, Even", "fricativa sonora", 70, fric({voiced = true, f = {220, 1100, 2100}, a = {0.55, 0.12, 0.06}, n = {3500, 1800}, na = {0.12, 0.06}})},
  {167, "ZZ", "Zoo, Zap", "fricativa sonora", 70, fric({voiced = true, f = {220, 1600, 2600}, a = {0.4, 0.08, 0.05}, n = {5000, 3900}, na = {0.45, 0.25}, dist = 0.9})},
  {168, "ZH", "Azure, Treasure", "fricativa sonora", 70, fric({voiced = true, f = {220, 1800, 2600}, a = {0.4, 0.08, 0.05}, n = {2600, 3500}, na = {0.45, 0.2}, dist = 0.85})},
  {169, "DH", "There, That, This", "fricativa sonora", 70, fric({voiced = true, f = {250, 1600, 2600}, a = {0.55, 0.15, 0.08}, n = {4500, 2200}, na = {0.1, 0.05}})},
  {170, "BE", "Bear, Bird, Beed", "occlusiva sonora", 45, stop({voiced = true, locus = {220, 1100, 2150}, burst = {700, 1800}})},
  {171, "BO", "Bone, Book, Brown", "occlusiva sonora", 45, stop({voiced = true, locus = {220, 800, 2150}, burst = {600, 1500}})},
  {172, "EB", "Cab, Crib, Web", "occlusiva sonora", 10, stop({voiced = true, final = true, locus = {220, 1100, 2150}, burst = {700, 1800}, burstamp = {0.3, 0.15}})},
  {173, "OB", "Bob, Sub, Tub", "occlusiva sonora", 10, stop({voiced = true, final = true, locus = {220, 800, 2150}, burst = {600, 1500}, burstamp = {0.3, 0.15}})},
  {174, "DE", "Deep, Date, Divide", "occlusiva sonora", 45, stop({voiced = true, locus = {250, 1800, 2700}, burst = {3500, 4500}})},
  {175, "DO", "Do, Dust, Dog", "occlusiva sonora", 45, stop({voiced = true, locus = {250, 1500, 2600}, burst = {3200, 4200}})},
  {176, "ED", "Could, Bird", "occlusiva sonora", 10, stop({voiced = true, final = true, locus = {250, 1800, 2700}, burst = {3500, 4500}, burstamp = {0.3, 0.15}})},
  {177, "OD", "Bud, Food", "occlusiva sonora", 10, stop({voiced = true, final = true, locus = {250, 1500, 2600}, burst = {3200, 4200}, burstamp = {0.3, 0.15}})},
  {178, "GE", "Get, Gate, Guest", "occlusiva sonora", 55, stop({voiced = true, locus = {250, 2200, 2600}, burst = {2300, 3000}, bdist = 0.6})},
  {179, "GO", "Got, Glue, Goo", "occlusiva sonora", 55, stop({voiced = true, locus = {250, 1200, 2300}, burst = {1500, 2500}, bdist = 0.6})},
  {180, "EG", "Peg, Wig", "occlusiva sonora", 55, stop({voiced = true, final = true, locus = {250, 2200, 2600}, burst = {2300, 3000}, bdist = 0.6, burstamp = {0.35, 0.15}})},
  {181, "OG", "Dog, Peg", "occlusiva sonora", 55, stop({voiced = true, final = true, locus = {250, 1200, 2300}, burst = {1500, 2500}, bdist = 0.6, burstamp = {0.35, 0.15}})},
  {182, "CH", "Church, Feature, March", "affricata sorda", 70, (function()
    local s = stop({locus = {300, 1900, 2700}, burst = {3200, 4000}, closure = 35})
    s[#s] = {ms = 60, n = {2600, 3600}, na = {0.7, 0.32}, dist = 0.8, alag = 8}
    s[#s + 1] = {ms = 5, na = SIL2, alag = 8}
    return s
  end)()},
  {183, "HE", "Help, Hand, Hair", "fricativa sorda", 70, fric({n = {1900, 2700}, na = {0.3, 0.2}})},
  {184, "HO", "Hoe, Hot, Hug", "fricativa sorda", 70, fric({n = {1100, 2400}, na = {0.3, 0.2}})},
  {185, "WH", "Who, Whale, White", "fricativa sorda", 70, fric({f = WW, n = {700, 1600}, na = {0.3, 0.15}})},
  {186, "FF", "Food, Effort, Off", "fricativa sorda", 70, fric({n = {4500, 1500}, na = {0.22, 0.08}})},
  {187, "SE", "See, Vest, Plus", "fricativa sorda", 40, fric({n = {5500, 4200}, na = {0.7, 0.35}, dist = 0.75})},
  {188, "SO", "So, Sweat", "fricativa sorda", 40, fric({n = {4600, 3500}, na = {0.65, 0.3}, dist = 0.75})},
  {189, "SH", "Ship, Fiction, Leash", "fricativa sorda", 50, fric({n = {2600, 3600}, na = {0.75, 0.35}, dist = 0.8})},
  {190, "TH", "Thin, Month", "fricativa sorda", 40, fric({n = {5200, 2200}, na = {0.18, 0.06}})},
  {191, "TT", "Part, Little, Sit", "occlusiva sorda", 50, stop({locus = {300, 1800, 2700}, burst = {4500, 3500}, burstamp = {0.6, 0.3}, asp = 15})},
  {192, "TU", "To, Talk, Ten", "occlusiva sorda", 70, stop({locus = {300, 1800, 2700}, burst = {4500, 3500}, burstamp = {0.6, 0.3}, asp = 40, closure = 40})},
  {193, "TS", "Parts, Costs, Robots", "occlusiva sorda", 170, (function()
    local s = stop({locus = {300, 1800, 2700}, burst = {4500, 3500}, burstamp = {0.6, 0.3}, closure = 30})
    s[#s] = {ms = 120, n = {5500, 4200}, na = {0.7, 0.35}, dist = 0.75, alag = 6}
    s[#s + 1] = {ms = 5, na = SIL2, alag = 8}
    return s
  end)()},
  {194, "KE", "Can't, Clown, Key", "occlusiva sorda", 55, stop({locus = {300, 2200, 2700}, burst = {2400, 3200}, bdist = 0.6, asp = 35, burstms = 14})},
  {195, "KO", "Comb, Quick, Fox", "occlusiva sorda", 55, stop({locus = {300, 1200, 2400}, burst = {1500, 2500}, bdist = 0.6, asp = 35, burstms = 14})},
  {196, "EK", "Speak, Task", "occlusiva sorda", 55, stop({final = true, locus = {300, 2200, 2700}, burst = {2400, 3200}, bdist = 0.6, asp = 12, burstms = 14})},
  {197, "OK", "Book, Took, October", "occlusiva sorda", 45, stop({final = true, locus = {300, 1200, 2400}, burst = {1500, 2500}, bdist = 0.6, asp = 12, burstms = 14})},
  {198, "PE", "People, Computer", "occlusiva sorda", 99, stop({locus = {300, 1100, 2200}, burst = {900, 2000}, burstamp = {0.5, 0.25}, asp = 50, closure = 45})},
  {199, "PO", "Paw, Copy", "occlusiva sorda", 99, stop({locus = {300, 800, 2200}, burst = {700, 1500}, burstamp = {0.5, 0.25}, asp = 50, closure = 45})},
}

-- Le fricative sorde del chip durano 40-50 ms: troppo brevi per un
-- "sintetizzatore" e poco intelligibili senza il resto del database MSA.
-- Allunghiamo la durata interna (il valore originale resta in .chip_ms).
local LONGER = {[187] = 95, [188] = 90, [189] = 100, [190] = 80, [186] = 90, [183] = 70, [184] = 70}

A.list = {}
A.by_code = {}
A.by_name = {}
for i, e in ipairs(T) do
  local ph = {code = e[1], name = e[2], words = e[3], kind = e[4], chip_ms = e[5],
              dur = LONGER[e[1]] or e[5], segs = e[6], idx = i}
  A.list[i] = ph
  A.by_code[ph.code] = ph
  A.by_name[ph.name] = ph
end

-- famiglie (per colori sulla grid e babbling)
function A.family(code)
  if code <= 139 then return "vowel"
  elseif code <= 148 then return "reson"
  elseif code <= 164 then return "diph"
  elseif code <= 169 then return "vfric"
  elseif code <= 181 then return "vstop"
  elseif code <= 190 then return "fric"
  else return "stop" end
end

-- l'allofono e' "intonabile" (contiene sonorita')?
function A.voiced(code)
  return code <= 181
end

-- vocale anteriore/posteriore (per la scelta delle varianti in TTS)
A.FRONT = {[128] = true, [129] = true, [130] = true, [131] = true, [132] = true,
           [149] = true, [150] = true, [154] = true, [158] = true, [160] = true}

-- Codici di controllo MSA (Tabella D)
A.CONTROL = {
  [0] = {name = "P0", desc = "pausa 0ms", pause = 0},
  [1] = {name = "P1", desc = "pausa 100ms", pause = 100},
  [2] = {name = "P2", desc = "pausa 200ms", pause = 200},
  [3] = {name = "P3", desc = "pausa 700ms", pause = 700},
  [4] = {name = "P4", desc = "pausa 30ms", pause = 30},
  [5] = {name = "P5", desc = "pausa 60ms", pause = 60},
  [6] = {name = "P6", desc = "pausa 90ms", pause = 90},
  [7] = {name = "FAST", desc = "prossimo suono x0.5"},
  [8] = {name = "SLOW", desc = "prossimo suono x1.5"},
  [14] = {name = "STRESS", desc = "prossimo suono accentato"},
  [15] = {name = "RELAX", desc = "prossimo suono rilassato"},
  [16] = {name = "WAIT", desc = "attesa"},
  [20] = {name = "VOL", desc = "volume X (0-127)", arg = true},
  [21] = {name = "SPEED", desc = "velocita' X (0-127)", arg = true},
  [22] = {name = "PITCH", desc = "pitch X Hz", arg = true},
  [23] = {name = "BEND", desc = "bend X (0-15)", arg = true},
  [26] = {name = "REPEAT", desc = "ripeti X volte", arg = true},
  [30] = {name = "DELAY", desc = "ritardo X*10ms", arg = true},
  [31] = {name = "RESET", desc = "reset default"},
}

return A
