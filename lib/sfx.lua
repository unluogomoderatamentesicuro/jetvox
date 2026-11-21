-- sfx.lua
-- I 55 effetti del set SpeakJet (codici 200..254): Robot R0-R9, Alarm A0-A9,
-- Beeps B0-B9, Biological C0-C9, DTMF D0-D11, M0 Sonar, M1 Pistol, M2 Wow.
-- Nomi e durate dalla Tabella E del manuale. I suoni originali non sono
-- documentati: sono ricreati "nello spirito" come sequenze di registri del
-- 5-channel synth (stessa macchina che produce il parlato).
--
-- Campi extra rispetto agli allofoni:
--   e1  = 0/1  osc 1..3 inviluppati dal generatore (0 = toni puri, es. DTMF)
--   env = {mode, hz, shape}  mode 1 = generatore a frequenza fissa (AM)
--                            shape 0 saw, 1 sine, 2 tri, 3 square
--   pr  = rapporto di pitch (voce) rispetto alla nota corrente, plag = glide ms

local S = {}

local OFF = {0, 0, 0}
local N0 = {0, 0}

local function tone(ms, f1, opts)
  local s = {ms = ms, f = {f1, f1 * 2.003, f1 * 3.01}, a = {0.8, 0, 0}, na = N0,
             e1 = 0, e2 = 0, dist = 0, lag = 2, alag = 3}
  if opts then for k, v in pairs(opts) do s[k] = v end end
  return s
end

local function gap(ms) return {ms = ms, a = OFF, na = N0, alag = 3} end

local list = {}
local function add(code, name, group, ms, segs)
  list[#list + 1] = {code = code, name = name, group = group, chip_ms = ms, dur = ms, segs = segs, sfx = true}
end

-- ROBOT R0..R9 (80 ms): bleep "da computer" con AM quadra -------------------
local rbase = {300, 450, 600, 800, 1000, 1200, 1500, 1800, 2200, 2600}
local rratio = {1.5, 0.75, 2, 1.25, 0.5, 1.33, 0.8, 1.5, 0.66, 1.2}
for k = 0, 9 do
  local b = rbase[k + 1]
  add(200 + k, "R" .. k, "robot", 80, {
    tone(40, b, {e1 = 1, env = {1, 28 + k * 9, 3}, a = {0.8, 0.35, 0.15}, f = {b, b * 2.41, b * 3.7}}),
    tone(40, b * rratio[k + 1], {e1 = 1, env = {1, 28 + k * 9, 3}, a = {0.8, 0.35, 0.15},
      f = {b * rratio[k + 1], b * rratio[k + 1] * 2.41, b * rratio[k + 1] * 3.7}}),
  })
end

-- ALARM A0..A9 ------------------------------------------------------------
add(210, "A0", "alarm", 300, {tone(1, 600), tone(300, 1400, {lag = 300})})
add(211, "A1", "alarm", 101, {tone(101, 2000, {e1 = 1, env = {1, 40, 3}})})
add(212, "A2", "alarm", 102, {tone(102, 1000, {e1 = 1, env = {1, 40, 3}})})
add(213, "A3", "alarm", 540, {tone(135, 960), tone(135, 770), tone(135, 960), tone(135, 770)})
add(214, "A4", "alarm", 530, {tone(1, 300, {e1 = 1, env = {1, 55, 3}, a = {0.8, 0.4, 0.2}}),
  tone(380, 620, {e1 = 1, env = {1, 55, 3}, a = {0.8, 0.4, 0.2}, lag = 380}), tone(150, 620, {e1 = 1, env = {1, 55, 3}, a = {0.8, 0.4, 0.2}})})
add(215, "A5", "alarm", 500, {tone(1, 1500), tone(500, 500, {lag = 500})})
add(216, "A6", "alarm", 135, {tone(34, 1800), tone(34, 1400), tone(34, 1800), tone(33, 1400)})
add(217, "A7", "alarm", 600, {tone(1, 700), tone(300, 1500, {lag = 300}), tone(300, 700, {lag = 300})})
add(218, "A8", "alarm", 300, {tone(300, 1000, {e1 = 1, env = {1, 120, 3}, a = {0.8, 0.3, 0.2}})})
add(219, "A9", "alarm", 250, {tone(120, 1200, {alag = 2}), tone(130, 950, {alag = 2})})

-- BEEPS B0..B9 -------------------------------------------------------------
add(220, "B0", "beeps", 200, {tone(200, 1000)})
add(221, "B1", "beeps", 270, {tone(100, 1500), gap(70), tone(100, 1500)})
add(222, "B2", "beeps", 280, {tone(90, 800), tone(90, 1000), tone(100, 1200)})
add(223, "B3", "beeps", 260, {tone(85, 1200), tone(85, 1000), tone(90, 800)})
add(224, "B4", "beeps", 300, {tone(300, 440)})
add(225, "B5", "beeps", 100, {tone(100, 2500)})
add(226, "B6", "beeps", 104, {tone(104, 3000)})
add(227, "B7", "beeps", 100, {tone(100, 600)})
add(228, "B8", "beeps", 270, {tone(60, 2000), gap(45), tone(60, 2000), gap(45), tone(60, 2000)})
add(229, "B9", "beeps", 262, {tone(1, 500), tone(262, 2500, {lag = 262})})

-- BIOLOGICAL C0..C9 --------------------------------------------------------
add(230, "C0", "bio", 160, {tone(1, 4000, {e1 = 1, env = {1, 25, 1}}), tone(160, 2000, {e1 = 1, env = {1, 25, 1}, lag = 160})})
add(231, "C1", "bio", 300, {{ms = 300, f = {500, 1100, 2400}, a = {0.9, 0.4, 0.1}, na = N0, e1 = 1, e2 = 0,
  env = {1, 30, 0}, dist = 0, lag = 40, alag = 10}})
add(232, "C2", "bio", 182, {tone(182, 4500, {e1 = 1, env = {1, 50, 3}})})
add(233, "C3", "bio", 120, {tone(1, 2000), tone(120, 3800, {lag = 120})})
add(234, "C4", "bio", 175, {{ms = 175, a = OFF, n = {300, 600}, na = {0.8, 0.5}, dist = 1, e1 = 1, e2 = 1,
  env = {1, 25, 3}, alag = 10}})
add(235, "C5", "bio", 350, {
  {ms = 150, f = {460, 850, 2400}, a = {1, 0.6, 0.15}, na = N0, e1 = 1, e2 = 0, dist = 0, pr = 1.4, plag = 60, lag = 30, alag = 20},
  {ms = 200, f = {300, 870, 2240}, a = {1, 0.4, 0.1}, pr = 0.8, plag = 200, lag = 200},
})
add(236, "C6", "bio", 160, {tone(1, 3000), tone(160, 3500, {lag = 80})})
add(237, "C7", "bio", 260, {{ms = 260, f = {600, 900, 2450}, a = {1, 0.7, 0.15}, n = {400, 900}, na = {0.3, 0.2},
  dist = 1, e1 = 1, e2 = 1, env = {1, 45, 0}, lag = 30, alag = 15}})
add(238, "C8", "bio", 95, {{ms = 95, a = OFF, n = {2500, 1200}, na = {0.6, 0.4}, dist = 1, e1 = 0, e2 = 0, alag = 20}})
add(239, "C9", "bio", 75, {{ms = 8, a = OFF, n = {900, 2500}, na = {1, 0.6}, dist = 0.4, e1 = 0, e2 = 0, alag = 1},
  {ms = 67, na = N0, alag = 30}})

-- DTMF D0..D11 (frequenze standard) ---------------------------------------
local ROW = {697, 770, 852, 941}
local COL = {1209, 1336, 1477}
local keys = {
  [0] = {4, 2}, {1, 1}, {1, 2}, {1, 3}, {2, 1}, {2, 2}, {2, 3}, {3, 1}, {3, 2}, {3, 3},
  {4, 1}, {4, 3}, -- 10 = *, 11 = #
}
for k = 0, 11 do
  local rc = keys[k]
  add(240 + k, "D" .. k, "dtmf", 95, {
    {ms = 95, f = {ROW[rc[1]], COL[rc[2]], 0}, a = {0.6, 0.6, 0}, na = N0, e1 = 0, e2 = 0, dist = 0, lag = 1, alag = 2},
    gap(1),
  })
end

-- MISC M0..M2 -------------------------------------------------------------
add(252, "M0", "misc", 125, {
  {ms = 6, f = {1500, 3005, 0}, a = {1, 0.15, 0}, na = N0, e1 = 0, e2 = 0, dist = 0, lag = 1, alag = 1},
  {ms = 119, a = OFF, alag = 420, tail = 500},
})
add(253, "M1", "misc", 250, {
  {ms = 4, a = OFF, n = {1200, 400}, na = {1, 0.9}, dist = 1, e1 = 0, e2 = 0, alag = 1, lag = 1},
  {ms = 246, n = {500, 150}, na = N0, alag = 160, lag = 200},
})
add(254, "M2", "misc", 530, {
  {ms = 80, f = {290, 620, 2150}, a = {0.8, 0.3, 0.08}, na = N0, e1 = 1, e2 = 0, dist = 0, pr = 0.9, plag = 20, lag = 20, alag = 20},
  {ms = 250, f = {700, 1200, 2450}, a = {1, 0.65, 0.2}, pr = 1.5, plag = 250, lag = 180},
  {ms = 200, f = {320, 800, 2240}, a = {0.9, 0.4, 0.1}, pr = 0.75, plag = 200, lag = 200},
})

S.list = list
S.by_code = {}
S.by_name = {}
for i, e in ipairs(list) do
  e.idx = i
  S.by_code[e.code] = e
  S.by_name[e.name] = e
end

S.GROUP_NAMES = {robot = "Robot", alarm = "Alarm", beeps = "Beeps", bio = "Biological", dtmf = "DTMF", misc = "Misc"}

return S
