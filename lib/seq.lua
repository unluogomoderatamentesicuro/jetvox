-- seq.lua
-- Sequencer a 2 tracce (chip A / chip B), fino a 64 step per traccia,
-- con step component in stile OP-XY (vedi lib/components.lua).
--
-- Uno step:
--   codes  lista di codici SpeakJet (fonema, sillaba, parola, effetto...)
--   label  testo da mostrare (parola) - opzionale
--   note   grado della scala (1 = root)
--   level  volume 0..127 (nil = volume della voce)
--   gate   0 = durata naturale del fonema, 1..16 = sustain per N step
--   prob   probabilita' 0..100
--   comps  {id = valore 1..10}

local C = include("lib/components")

local Seq = {}
local J

Seq.MAX = 64
Seq.DIR_NAMES = {"avanti", "indietro", "ping-pong", "random", "drunk"}
Seq.DIV_NAMES = {"1/2", "1/4", "1/8", "1/8t", "1/16", "1/16t", "1/32"}
Seq.DIVS = {2, 1, 1 / 2, 1 / 3, 1 / 4, 1 / 6, 1 / 8}

function Seq.init(j)
  J = j
  Seq.tracks = {}
  for t = 1, 2 do
    Seq.tracks[t] = {steps = {}, pos = 0, sel = 1, pp = 1, tick = 0,
                     pulse_left = 0, hold_left = 0, jump = nil, stay = false,
                     rt = {}, port_next = nil, bend_co = nil, gate_co = nil, last_fire = 0}
  end
  Seq.playing = false
  Seq.clip = nil
end

local function P(id, t) return params:get(id .. "_" .. t) end

function Seq.len(t) return P("len", t) end

function Seq.step_sec(t)
  return clock.get_beat_sec() * Seq.DIVS[P("div", t)]
end

-------------------------------------------------------------------------------
-- avanzamento
-------------------------------------------------------------------------------
local function advance(t)
  local tr = Seq.tracks[t]
  local len = Seq.len(t)
  if tr.jump then
    tr.pos = util.clamp(tr.jump, 1, len)
    tr.jump = nil
    return
  end
  if tr.stay and tr.pos >= 1 then return end
  local dir = P("dir", t)
  if tr.pos < 1 then
    tr.pos = (dir == 2) and len or 1
    return
  end
  if dir == 1 then
    tr.pos = tr.pos % len + 1
  elseif dir == 2 then
    tr.pos = tr.pos - 1
    if tr.pos < 1 then tr.pos = len end
  elseif dir == 3 then
    if len == 1 then tr.pos = 1 return end
    local n = tr.pos + tr.pp
    if n > len then tr.pp = -1; n = len - 1 elseif n < 1 then tr.pp = 1; n = 2 end
    tr.pos = n
  elseif dir == 4 then
    tr.pos = math.random(1, len)
  else
    tr.pos = tr.pos + math.random(-1, 1)
    if tr.pos < 1 then tr.pos = len elseif tr.pos > len then tr.pos = 1 end
  end
end

-------------------------------------------------------------------------------
-- suonare uno step
-------------------------------------------------------------------------------
local function random_bend(range, n)
  local s = {}
  for k = 1, n do s[k] = {(math.random() * 2 - 1) * range, 1 / (n + 1)} end
  s[n + 1] = {0, 1 / (n + 1)}
  return s
end

-- opts.preview: suona lo step senza toccare lo stato del sequencer
function Seq.fire(t, i, opts)
  opts = opts or {}
  local tr = Seq.tracks[t]
  local st = tr.steps[i]
  if not st or not st.codes or #st.codes == 0 then return false end
  local v = t
  local m = J.voices[v]
  local comps = st.comps or {}
  local rt = tr.rt[i] or {count = 0, ramp = 0}
  tr.rt[i] = rt
  local dur = Seq.step_sec(t)

  if not opts.preview and not opts.pulse then
    rt.count = rt.count + 1
    -- JUMP (deciso anche se il trigger viene saltato)
    local jv = comps.jump
    tr.stay = false
    if jv then
      if jv == 10 then jv = math.random(1, 9) end
      local len = Seq.len(t)
      if jv <= 4 then tr.jump = (jv - 1) * 4 + 1
      elseif jv == 5 then tr.jump = (i + 1) % len + 1
      elseif jv == 6 then tr.jump = ((i - 2) % len) + 1
      elseif jv == 7 then tr.jump = ((i - 1 + (math.random() < 0.5 and -1 or 2)) % len) + 1
      elseif jv == 8 then tr.stay = true
      elseif jv == 9 then tr.jump = Seq.tracks[3 - t].pos % len + 1 end
    end
    -- COND: suona solo ogni N passaggi
    local cv = comps.cond
    if cv then
      if cv == 10 then
        if math.random() < 0.5 then return false end
      elseif cv > 1 and ((rt.count - 1) % cv) ~= 0 then
        return false
      end
    end
    if math.random(100) > (st.prob or 100) then return false end
    -- PULS / HOLD
    if comps.puls then tr.pulse_left = C.resolve("puls", comps.puls) end
    if comps.hold then tr.hold_left = C.resolve("hold", comps.hold) end
  end

  if not opts.preview and P("mute", t) == 2 then return false end
  if not opts.preview and P("retrig", t) == 2 and (m.busy or m.holding) then return false end

  -- NOTA ---------------------------------------------------------------
  local deg = st.note or 1
  local semis = P("transpose", t)
  local up = comps.rmpu or comps.rmpd
  if up then
    local n, span = C.span(up)
    local off = math.floor(rt.ramp * span / (n - 1) + 0.5)
    deg = deg + (comps.rmpu and off or -off)
    if not opts.preview then rt.ramp = (rt.ramp + 1) % n end
  end
  if comps.rand then
    local n, span = C.span(comps.rand)
    deg = deg + math.floor((math.random(1, n) - 1) * span / (n - 1) + 0.5)
  end
  if comps.tone then
    local tv = C.resolve("tone", comps.tone)
    deg = deg + C.TONE[tv][1]
    semis = semis + C.TONE[tv][2]
  end
  -- RANDOM della traccia (come il Flame: pitch, poi speed, poi volume)
  local rnd = P("rnd", t) / 100
  if rnd > 0 then semis = semis + (math.random() * 2 - 1) * rnd * 7 end
  local hz = J.note_hz(deg, semis)

  -- PORTAMENTO -----------------------------------------------------------
  local glide = J.glide(v)
  if comps.port then
    local pv = C.resolve("port", comps.port)
    glide = C.PORT[pv] * dur * 1.5
    if not opts.preview then tr.port_next = glide end
  elseif tr.port_next and not opts.preview then
    glide = tr.port_next
    tr.port_next = nil
  end

  -- CODICI -----------------------------------------------------------------
  local codes = st.codes
  if comps.ordr then codes = C.order(codes, comps.ordr) end
  local speed = P("speed", v)
  local vol = st.level or P("vol", v)
  if rnd > 0.33 then speed = util.clamp(math.floor(speed + (math.random() * 2 - 1) * (rnd - 0.33) * 90), 20, 127) end
  if rnd > 0.66 then vol = util.clamp(math.floor(vol - math.random() * (rnd - 0.66) * 200), 10, 127) end
  if comps.velo then vol = C.VELO[C.resolve("velo", comps.velo)] end
  local pre = {21, speed, 20, vol}
  local time_mul = 1
  if comps.talk then
    local tv = comps.talk
    if tv == 10 then tv = math.random(1, 9) end
    if tv == 9 then pre[#pre + 1] = 14 else time_mul = C.TALK[tv] end
  end
  local fmul = 1
  if comps.form then fmul = C.FORM[C.resolve("form", comps.form)] end
  for _, c in ipairs(codes) do pre[#pre + 1] = c end
  codes = pre

  -- GATE ---------------------------------------------------------------------
  local gate = st.gate or 0
  if comps.hold and not opts.preview then gate = math.max(gate, tr.hold_left + 1) end
  local mult = comps.mult and C.MULT[C.resolve("mult", comps.mult)] or 1

  -- THROW ----------------------------------------------------------------------
  if comps.thrw then
    J.throw(v, C.resolve("thrw", comps.thrw), dur * math.max(1, gate))
  end

  -- BEND -------------------------------------------------------------------------
  if tr.bend_co then clock.cancel(tr.bend_co); tr.bend_co = nil end
  if tr.gate_co then clock.cancel(tr.gate_co); tr.gate_co = nil end

  local function trigger(hold)
    m:set_pitch(hz, glide)
    m:say(codes, {hold = hold, time_mul = time_mul, fscale_mul = fmul})
  end

  if mult > 1 then
    tr.gate_co = clock.run(function()
      for r = 1, mult do
        trigger(r == mult and gate > 0)
        if r < mult then clock.sleep(dur / mult) end
      end
      if gate > 0 then
        local id = m.say_id
        clock.sleep(math.max(0.01, gate * dur * 0.97 - dur * (mult - 1) / mult))
        if m.say_id == id then m:release(J.release_ms()) end
      end
    end)
  else
    trigger(gate > 0)
    if gate > 0 then
      local id = m.say_id
      tr.gate_co = clock.run(function()
        clock.sleep(gate * dur * 0.97)
        if m.say_id == id then m:release(J.release_ms()) end
      end)
    end
  end

  if comps.bend then
    local bv = comps.bend
    local shape
    if bv <= 8 then shape = C.BENDS[bv]
    elseif bv == 9 then shape = random_bend(5, 3)
    else shape = random_bend(12, 4) end
    local bdur = dur * math.max(1, gate)
    tr.bend_co = clock.run(function()
      clock.sleep(0.005)
      for _, seg in ipairs(shape) do
        local tt = math.max(0.005, seg[2] * bdur)
        engine.pitch(v, hz * 2 ^ (seg[1] / 12), tt)
        clock.sleep(tt)
      end
    end)
  end

  tr.last_fire = util.time()
  return true
end

-------------------------------------------------------------------------------
-- tick
-------------------------------------------------------------------------------
function Seq.tick(t)
  local tr = Seq.tracks[t]
  if tr.hold_left > 0 then
    tr.hold_left = tr.hold_left - 1
    return
  end
  if tr.pulse_left > 0 then
    tr.pulse_left = tr.pulse_left - 1
    Seq.fire(t, tr.pos, {pulse = true})
    return
  end
  advance(t)
  Seq.fire(t, tr.pos)
end

function Seq.loop(t)
  while true do
    clock.sync(Seq.DIVS[P("div", t)])
    if Seq.playing then
      local tr = Seq.tracks[t]
      tr.tick = tr.tick + 1
      local sw = P("swing", t)
      if sw > 50 and tr.tick % 2 == 0 then
        clock.sleep(Seq.step_sec(t) * (sw - 50) / 50)
      end
      Seq.tick(t)
      J.on_tick(t)
    end
  end
end

function Seq.start()
  for t = 1, 2 do
    local tr = Seq.tracks[t]
    tr.pos = 0
    tr.tick = 0
    tr.pp = 1
    tr.pulse_left, tr.hold_left = 0, 0
    tr.jump, tr.stay, tr.port_next = nil, false, nil
    tr.rt = {}
  end
  Seq.playing = true
end

function Seq.stop()
  Seq.playing = false
  for t = 1, 2 do
    local tr = Seq.tracks[t]
    if tr.bend_co then clock.cancel(tr.bend_co); tr.bend_co = nil end
    if tr.gate_co then clock.cancel(tr.gate_co); tr.gate_co = nil end
  end
end

-------------------------------------------------------------------------------
-- editing
-------------------------------------------------------------------------------
local function copy_codes(codes)
  local cc = {}
  for k, c in ipairs(codes) do cc[k] = c end
  return cc
end

function Seq.new_step(codes, label, note)
  return {codes = copy_codes(codes), label = label, note = note or 1, gate = 0, prob = 100, comps = {}}
end

function Seq.write(t, i, codes, label, append, note)
  local tr = Seq.tracks[t]
  local st = tr.steps[i]
  if append and st then
    for _, c in ipairs(codes) do st.codes[#st.codes + 1] = c end
    if st.label and label then st.label = st.label .. " " .. label else st.label = nil end
  elseif st then
    st.codes = copy_codes(codes)
    st.label = label
    if note then st.note = note end
  else
    tr.steps[i] = Seq.new_step(codes, label, note)
  end
end

-- scrive una lista di {codes, label} su step consecutivi
function Seq.spread(t, start, items, note)
  local len = Seq.len(t)
  local i = start
  for _, it in ipairs(items) do
    Seq.write(t, i, it.codes, it.label, false, note)
    i = i % len + 1
  end
  return i
end

function Seq.clear(t)
  Seq.tracks[t].steps = {}
  Seq.tracks[t].rt = {}
end

function Seq.copy(t, i)
  local st = Seq.tracks[t].steps[i]
  if not st then Seq.clip = nil return end
  local c = {}
  for k, v in pairs(st) do c[k] = v end
  c.codes = copy_codes(st.codes)
  c.comps = {}
  for k, v in pairs(st.comps or {}) do c.comps[k] = v end
  Seq.clip = c
end

function Seq.paste(t, i)
  if not Seq.clip then return end
  local c = {}
  for k, v in pairs(Seq.clip) do c[k] = v end
  c.codes = copy_codes(Seq.clip.codes)
  c.comps = {}
  for k, v in pairs(Seq.clip.comps) do c.comps[k] = v end
  Seq.tracks[t].steps[i] = c
end

-- BABBLE: riempie la traccia con sillabe casuali (consonante + vocale)
local CONS = {170, 171, 174, 175, 178, 179, 194, 195, 198, 199, 192, 140, 141, 142,
              145, 146, 147, 148, 183, 187, 188, 189, 186, 166, 167, 165, 182, 169}
local VOWS = {128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139,
              154, 155, 156, 157, 158, 160, 161, 162, 163, 164}
local FINALS = {172, 176, 180, 196, 197, 191, 140, 141, 143, 146, 187}
local COMP_IDS = {"puls", "mult", "rmpu", "rand", "port", "bend", "tone", "cond", "talk", "form", "thrw"}

function Seq.babble(t, with_comps)
  local tr = Seq.tracks[t]
  local len = Seq.len(t)
  for i = 1, len do
    if math.random() < 0.8 then
      local codes = {}
      if math.random() < 0.85 then codes[#codes + 1] = CONS[math.random(#CONS)] end
      codes[#codes + 1] = VOWS[math.random(#VOWS)]
      if math.random() < 0.25 then codes[#codes + 1] = FINALS[math.random(#FINALS)] end
      local st = Seq.new_step(codes, nil, math.random(1, 8))
      if with_comps and math.random() < 0.3 then
        local id = COMP_IDS[math.random(#COMP_IDS)]
        st.comps[id] = math.random(1, 10)
      end
      if math.random() < 0.15 then st.gate = math.random(1, 3) end
      tr.steps[i] = st
    else
      tr.steps[i] = nil
    end
  end
  tr.rt = {}
end

function Seq.comp_count(st)
  local n = 0
  if st and st.comps then for _ in pairs(st.comps) do n = n + 1 end end
  return n
end

return Seq
