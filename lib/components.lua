-- components.lua
-- Step component in stile OP-XY / OP-Z, adattati a un synth vocale.
-- Ogni step puo' avere QUALSIASI combinazione dei 16 componenti; ognuno
-- ha un valore 1..10 (come i tasti "accidentals" 1..9,0 dell'OP-XY, dove
-- 10 = "0" = di solito random).
--
--  1 PULS  ripete lo step N volte senza avanzare (ritrigger)
--  2 HOLD  tiene lo step N step senza avanzare (sustain, nota lunga)
--  3 MULT  divide lo step in N trigger (ratchet)
--  4 VELO  volume fisso dello step
--  5 RMP+  la nota sale nella scala a ogni passaggio
--  6 RMP-  la nota scende nella scala a ogni passaggio
--  7 RAND  nota casuale nella scala
--  8 PORT  portamento verso e dallo step
--  9 BEND  curve di pitch bend
-- 10 TONE  trasposizione (ottave, quinte, terze, cromatica)
-- 11 JUMP  salta a un altro step
-- 12 COND  suona solo ogni N passaggi (skip trigger)
-- 13 TALK  velocita' di pronuncia (fast/slow/stress)   [JetVox]
-- 14 FORM  formanti: voce maschile/femminile/chipmunk  [JetVox]
-- 15 ORDR  ordine dei fonemi: reverse, shuffle, stutter [JetVox]
-- 16 THRW  "throw" su delay/riverbero/crush/ring        [JetVox]

local C = {}

local function nums(n, last)
  local t = {}
  for i = 1, 9 do t[i] = tostring(i) end
  t[10] = last or "rnd"
  return t
end

C.list = {
  {id = "puls", short = "PULS", name = "pulse", vals = nums()},
  {id = "hold", short = "HOLD", name = "hold", vals = nums()},
  {id = "mult", short = "MULT", name = "multiply",
   vals = {"2", "3", "4", "5", "6", "7", "8", "12", "16", "rnd"}},
  {id = "velo", short = "VELO", name = "velocity",
   vals = {"4", "8", "16", "32", "64", "100", "112", "127", "0", "rnd"}},
  {id = "rmpu", short = "RMP+", name = "ramp up",
   vals = {"2/1o", "3/1o", "4/1o", "5/1o", "6/1o", "2/3o", "3/3o", "4/3o", "5/3o", "6/3o"}},
  {id = "rmpd", short = "RMP-", name = "ramp down",
   vals = {"2/1o", "3/1o", "4/1o", "5/1o", "6/1o", "2/3o", "3/3o", "4/3o", "5/3o", "6/3o"}},
  {id = "rand", short = "RAND", name = "random note",
   vals = {"2/1o", "3/1o", "4/1o", "5/1o", "6/1o", "2/3o", "3/3o", "4/3o", "5/3o", "6/3o"}},
  {id = "port", short = "PORT", name = "portamento",
   vals = {"10%", "20%", "30%", "40%", "50%", "60%", "70%", "80%", "90%", "rnd"}},
  {id = "bend", short = "BEND", name = "bend",
   vals = {"dn-up", "up-dn", "bmp dn", "bmp up", "spr out", "spr in", "fade dn", "fade up", "rnd 1", "rnd 2"}},
  {id = "tone", short = "TONE", name = "tonality",
   vals = {"oct -", "oct +", "5th +", "3rd +", "4th +", "chr +", "chr -", "2oct +", "5th -", "rnd"}},
  {id = "jump", short = "JUMP", name = "jump",
   vals = {"to 1", "to 5", "to 9", "to 13", "fwd", "back", "fwd/bk", "stay", "align", "rnd"}},
  {id = "cond", short = "COND", name = "condition",
   vals = {"1:1", "1:2", "1:3", "1:4", "1:5", "1:6", "1:7", "1:8", "1:9", "50%"}},
  {id = "talk", short = "TALK", name = "talk speed",
   vals = {"x.4", "x.6", "x.8", "x1.25", "x1.5", "x2", "x3", "x4", "stress", "rnd"}},
  {id = "form", short = "FORM", name = "formant",
   vals = {"x.6", "x.7", "x.8", "x.9", "x1.12", "x1.25", "x1.4", "x1.6", "x2", "rnd"}},
  {id = "ordr", short = "ORDR", name = "order",
   vals = {"rev", "shuf", "first", "last", "stut2", "stut3", "vowel", "cons", "skip2", "rnd"}},
  {id = "thrw", short = "THRW", name = "fx throw",
   vals = {"dly lo", "dly mid", "dly hi", "rev lo", "rev mid", "rev hi", "dly+rev", "crush", "ring", "rnd"}},
}

C.by_id = {}
for i, c in ipairs(C.list) do
  c.idx = i
  C.by_id[c.id] = c
end

C.MULT = {2, 3, 4, 5, 6, 7, 8, 12, 16}
C.VELO = {4, 8, 16, 32, 64, 100, 112, 127, 0}
C.PORT = {0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9}
C.TALK = {0.4, 0.6, 0.8, 1.25, 1.5, 2, 3, 4}
C.FORM = {0.6, 0.7, 0.8, 0.9, 1.12, 1.25, 1.4, 1.6, 2}

-- tonalita': {gradi di scala, semitoni}
C.TONE = {{0, -12}, {0, 12}, {4, 0}, {2, 0}, {3, 0}, {0, 1}, {0, -1}, {0, 24}, {-4, 0}}

-- curve di bend: {semitoni, frazione della durata dello step}
C.BENDS = {
  {{-2, 0.5}, {0, 0.5}},
  {{2, 0.5}, {0, 0.5}},
  {{-3, 0.1}, {0, 0.35}},
  {{3, 0.1}, {0, 0.35}},
  {{2, 0.1}, {-1.5, 0.1}, {1, 0.1}, {-0.5, 0.1}, {0, 0.1}},
  {{0.5, 0.1}, {-1, 0.1}, {1.5, 0.1}, {-2, 0.1}, {0, 0.1}},
  {{-12, 1}},
  {{12, 1}},
}

-- risolve un valore (10 = random dove previsto)
function C.resolve(id, v)
  if v == 10 then
    if id == "puls" or id == "hold" then return math.random(1, 9)
    elseif id == "mult" or id == "velo" or id == "port" or id == "tone"
        or id == "talk" or id == "form" or id == "ordr" or id == "thrw" then
      return math.random(1, 9)
    end
  end
  return v
end

-- ramp / random: {numero di posizioni, ampiezza in gradi di scala}
function C.span(v)
  local n = ((v - 1) % 5) + 2
  local span = (v <= 5) and 7 or 21
  return n, span
end

-- ORDR: trasforma la lista di codici lavorando per "unita'"
-- (eventuali codici di controllo + il suono che li segue)
local CTRL_ARG = {[20] = true, [21] = true, [22] = true, [23] = true, [24] = true,
                  [25] = true, [26] = true, [28] = true, [29] = true, [30] = true}

local function units(codes)
  local out, cur = {}, {}
  local i = 1
  while i <= #codes do
    local c = codes[i]
    cur[#cur + 1] = c
    if CTRL_ARG[c] then
      i = i + 1
      cur[#cur + 1] = codes[i]
    elseif c >= 128 or c <= 6 then
      out[#out + 1] = cur
      cur = {}
    end
    i = i + 1
  end
  if #cur > 0 then out[#out + 1] = cur end
  return out
end

local function sound_of(u)
  for k = #u, 1, -1 do if u[k] >= 128 then return u[k] end end
  return nil
end

local function flat(us)
  local out = {}
  for _, u in ipairs(us) do for _, c in ipairs(u) do out[#out + 1] = c end end
  return out
end

function C.order(codes, v)
  if v == 10 then v = math.random(1, 9) end
  local us = units(codes)
  if #us <= 1 and v ~= 5 and v ~= 6 then return codes end
  local r = {}
  if v == 1 then
    for k = #us, 1, -1 do r[#r + 1] = us[k] end
  elseif v == 2 then
    for k = 1, #us do r[k] = us[k] end
    for k = #r, 2, -1 do
      local j = math.random(1, k)
      r[k], r[j] = r[j], r[k]
    end
  elseif v == 3 then r = {us[1]}
  elseif v == 4 then r = {us[#us]}
  elseif v == 5 or v == 6 then
    local n = (v == 5) and 2 or 3
    for _ = 1, n do r[#r + 1] = {7, sound_of(us[1]) or 128} end
    for k = 2, #us do r[#r + 1] = us[k] end
  elseif v == 7 or v == 8 then
    for _, u in ipairs(us) do
      local s = sound_of(u)
      local vowel = s and s <= 164 and (s <= 139 or s >= 149)
      if (v == 7 and vowel) or (v == 8 and s and not vowel) then r[#r + 1] = u end
    end
    if #r == 0 then r = us end
  elseif v == 9 then
    for k = 1, #us, 2 do r[#r + 1] = us[k] end
  end
  return flat(r)
end

return C
