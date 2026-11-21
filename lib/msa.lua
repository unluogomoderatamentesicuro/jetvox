-- msa.lua
-- Ricostruzione del "Mathematical Sound Architecture" del SpeakJet:
-- interpreta una lista di codici (0..254, stesso set del chip) e pilota i
-- registri del 5-channel synth (engine JetVox) segmento per segmento.
--
--   0..6    pause            7 FAST     8 SLOW     14 STRESS   15 RELAX
--   20 X    volume (0-127)   21 X speed (0-127)    22 X pitch (Hz)
--   23 X    bend (0-15)      26 X repeat           30 X delay (X*10ms)
--   31      reset            128..199 allofoni     200..254 effetti
--
-- Ogni voce (chip A / chip B) ha la sua istanza.

local A = include("lib/allophones")
local S = include("lib/sfx")

local MSA = {}
MSA.__index = MSA

local DEFAULTS = {speed = 114, vol = 96, bend = 5}

function MSA.new(v, eng)
  local m = setmetatable({}, MSA)
  m.v = v
  m.eng = eng                -- tabella con frame/pitch/envosc/param
  m.speed = DEFAULTS.speed
  m.vol = DEFAULTS.vol
  m.bend = DEFAULTS.bend
  m.formant = 1              -- "joystick" maschio/femmina (Flame)
  m.length = 1.0             -- moltiplicatore globale durate
  m.shape = 0                -- forma del glottide per il parlato
  m.hz = 110                 -- pitch corrente
  m.glide = 0.02
  m.release_ms = 60
  m.regs = {f = {500, 1500, 2500}, a = {0, 0, 0}, n = {3000, 4000}, na = {0, 0},
            dist = 0, e1 = 1, e2 = 0}
  m.envstate = nil
  m.co = nil
  m.current = nil            -- definizione in riproduzione (per la UI)
  m.on_event = nil           -- callback(v, kind, def)
  m.busy = false
  m.holding = false
  return m
end

-- durata: speed 114 (default chip) = 1.0; 0 = ~5x piu' lento; 127 = ~0.8x
function MSA:time_scale()
  return self.length * (self.tmul or 1) * 2 ^ ((114 - self.speed) / 40)
end

function MSA:bend_scale()
  return 2 ^ ((self.bend - 5) * 0.06) * self.formant
end

function MSA:send_fscale(mul)
  local fs = self:bend_scale() * (mul or self.fmul or 1)
  if fs ~= self.sent_fs then
    self.sent_fs = fs
    self.eng.param(self.v, "fscale", fs)
  end
end

function MSA:send_vol()
  self.eng.param(self.v, "mvol", self.vol / 127)
end

function MSA:set_pitch(hz, glide)
  self.hz = hz
  self.eng.pitch(self.v, hz, glide or self.glide)
end

function MSA:set_env(mode, hz, shape)
  local key = mode .. ":" .. hz .. ":" .. shape
  if self.envstate ~= key then
    self.envstate = key
    self.eng.envosc(self.v, mode, hz, shape)
  end
end

function MSA:speech_env()
  self:set_env(0, 60, self.shape)
end

local function amp_any(r)
  return r.a[1] + r.a[2] + r.a[3] + r.na[1] + r.na[2] > 0.0001
end

function MSA:send(lag_ms, alag_ms)
  local r = self.regs
  self.eng.frame(self.v,
    r.f[1], r.f[2], r.f[3], r.n[1], r.n[2],
    r.a[1], r.a[2], r.a[3], r.na[1], r.na[2],
    r.dist, r.e1, r.e2,
    math.max(lag_ms, 1) / 1000, math.max(alag_ms, 1) / 1000)
end

function MSA:silence(alag_ms)
  local r = self.regs
  if not amp_any(r) then return end
  r.a = {0, 0, 0}
  r.na = {0, 0}
  self:send(5, alag_ms or 20)
end

-- riproduce un allofono o effetto; mods = {fast, slow, stress, relax, pitch_mul}
function MSA:play_def(def, mods)
  mods = mods or {}
  local scale = self:time_scale()
  if mods.fast then scale = scale * 0.5 end
  if mods.slow then scale = scale * 1.5 end
  local base = self.hz * (mods.pitch_mul or 1)
  if mods.stress then base = base * 2 ^ (2 / 12) end
  if mods.relax then base = base * 2 ^ (-1.5 / 12) end
  self.current = def
  if self.on_event then self.on_event(self.v, "play", def) end

  local sfx = def.sfx
  if not sfx then
    self:speech_env()
    self.regs.e1 = 1
  end
  if math.abs(base - self.hz) > 0.01 or mods.force_pitch then
    self.eng.pitch(self.v, base, self.glide)
  end

  local r = self.regs
  local n = #def.segs
  for i, s in ipairs(def.segs) do
    if s.f then r.f = {s.f[1], s.f[2], s.f[3]} end
    if s.a then r.a = {s.a[1], s.a[2], s.a[3]} end
    if s.n then r.n = {s.n[1], s.n[2]} end
    if s.na then r.na = {s.na[1], s.na[2]} end
    if s.dist then r.dist = s.dist end
    if s.e2 then r.e2 = s.e2 end
    if sfx then
      r.e1 = s.e1 or r.e1
      if s.env then
        self:set_env(s.env[1], s.env[2], s.env[3])
      elseif i == 1 then
        self:speech_env()
      end
      if s.pr then self.eng.pitch(self.v, base * s.pr, (s.plag or 20) / 1000) end
    end
    local ms
    if s.ms then ms = s.ms * scale
    else ms = (s.d or (1 / n)) * def.dur * scale end
    local lag
    if s.lag then lag = s.lag
    elseif s.lagf then lag = s.lagf * def.dur * scale
    else lag = math.min(45, math.max(12, 0.45 * def.dur * scale)) end
    local alag = s.alag or 12
    self:send(lag, alag)
    if self.on_event then self.on_event(self.v, "frame", def) end
    if ms > 0 then clock.sleep(ms / 1000) end
  end
  if sfx then
    -- ripristina il pitch base dopo gli effetti con glide di pitch
    self.eng.pitch(self.v, self.hz, 0.01)
  elseif base ~= self.hz then
    self.eng.pitch(self.v, self.hz, self.glide)
  end
end

local function lookup(code)
  return A.by_code[code] or S.by_code[code]
end
MSA.lookup = lookup

-- interpreta la lista di codici (gira dentro una coroutine di clock)
function MSA:run(codes, opts)
  opts = opts or {}
  local mods = {}
  local rep = 0
  local i = 1
  local last_sound = 0
  for k = #codes, 1, -1 do
    if codes[k] >= 128 then last_sound = k break end
  end
  while i <= #codes do
    local c = codes[i]
    if c >= 128 then
      local def = lookup(c)
      if def then
        mods.pitch_mul = opts.pitch_mul
        for _ = 0, rep do self:play_def(def, mods) end
      end
      rep = 0
      mods = {}
      if i == last_sound and opts.hold and not self.hold_cancel then
        self.holding = true
        self.busy = false
        if self.on_event then self.on_event(self.v, "hold", def) end
        return
      end
    elseif A.CONTROL[c] and A.CONTROL[c].pause then
      local p = A.CONTROL[c].pause
      self:silence(p == 0 and 25 or 15)
      if p > 0 then clock.sleep(p * self:time_scale() / 1000) end
    elseif c == 7 then mods.fast = true
    elseif c == 8 then mods.slow = true
    elseif c == 14 then mods.stress = true
    elseif c == 15 then mods.relax = true
    elseif c == 20 then i = i + 1; self.vol = util.clamp(codes[i] or 96, 0, 127); self:send_vol()
    elseif c == 21 then i = i + 1; self.speed = util.clamp(codes[i] or 114, 0, 127)
    elseif c == 22 then i = i + 1; self:set_pitch(util.clamp(codes[i] or 88, 1, 255))
    elseif c == 23 then i = i + 1; self.bend = util.clamp(codes[i] or 5, 0, 15); self:send_fscale()
    elseif c == 26 then i = i + 1; rep = util.clamp(codes[i] or 0, 0, 255)
    elseif c == 30 then i = i + 1; clock.sleep((codes[i] or 0) * 0.01)
    elseif c == 31 then
      self.speed, self.vol, self.bend = DEFAULTS.speed, DEFAULTS.vol, DEFAULTS.bend
      self:send_vol(); self:send_fscale()
    elseif c == 24 or c == 25 or c == 28 or c == 29 then
      i = i + 1 -- comandi con argomento non gestiti
    end
    i = i + 1
  end
  if not opts.no_silence then self:silence(opts.release or 25) end
  self.busy = false
  self.current = nil
  if self.on_event then self.on_event(self.v, "done", nil) end
end

-- API pubblica ----------------------------------------------------------
function MSA:say(codes, opts)
  opts = opts or {}
  if (opts.interrupt ~= false) and self.co then
    clock.cancel(self.co)
    self.co = nil
  end
  self.holding = false
  self.hold_cancel = false
  self.busy = true
  self.say_id = (self.say_id or 0) + 1
  self.tmul = opts.time_mul or 1
  self.fmul = opts.fscale_mul or 1
  self:send_fscale()
  self.co = clock.run(function() self:run(codes, opts) end)
end

-- rilascio: se sta ancora articolando, finisce la frase e poi tace;
-- se e' in sustain, sfuma subito
function MSA:release(ms)
  self.hold_cancel = true
  if self.holding then
    self.holding = false
    self:silence(ms or self.release_ms)
    if self.on_event then self.on_event(self.v, "done", nil) end
  end
end

function MSA:stop()
  if self.co then clock.cancel(self.co) end
  self.co = nil
  self.busy = false
  self.holding = false
  self:silence(15)
end

-- nome leggibile di una lista di codici
function MSA.codes_to_string(codes)
  local out = {}
  local i = 1
  while i <= #codes do
    local c = codes[i]
    if c >= 128 then
      local d = lookup(c)
      out[#out + 1] = d and d.name or tostring(c)
    elseif A.CONTROL[c] then
      local ctl = A.CONTROL[c]
      if ctl.arg then
        i = i + 1
        out[#out + 1] = ctl.name .. ":" .. tostring(codes[i])
      else
        out[#out + 1] = ctl.name
      end
    end
    i = i + 1
  end
  return table.concat(out, " ")
end

return MSA
