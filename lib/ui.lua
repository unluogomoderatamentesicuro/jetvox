-- ui.lua
-- primitive grafiche per lo schermo di norns (128x64)

local UI = {}

-- animazione: insegue dolcemente i registri della voce
function UI.new_anim()
  return {f1 = 500, f2 = 1500, a = 0, n = 0}
end

function UI.update_anim(an, regs)
  local tgt_a = util.clamp(regs.a[1] + regs.a[2] * 0.5, 0, 1)
  local tgt_n = util.clamp(regs.na[1] + regs.na[2], 0, 1)
  an.f1 = an.f1 + (regs.f[1] - an.f1) * 0.45
  an.f2 = an.f2 + (regs.f[2] - an.f2) * 0.45
  an.a = an.a + (tgt_a - an.a) * 0.5
  an.n = an.n + (tgt_n - an.n) * 0.5
  return an.a > 0.01 or an.n > 0.01
end

-- bocca: F1 = apertura, F2 = larghezza (vocali posteriori = labbra arrotondate)
function UI.mouth(cx, cy, w, h, an, bright)
  bright = bright or 15
  local open = util.clamp((an.f1 - 180) / 620, 0.05, 1) * an.a
  local width = w * (0.5 + 0.5 * util.clamp((an.f2 - 600) / 1700, 0, 1))
  if an.a < 0.05 then width = w * 0.8 end
  local hw = width / 2
  local up = 2 + h * 0.45 * open
  local dn = 2 + h * 0.6 * open
  -- labbra
  screen.level(math.floor(bright * 0.75))
  screen.move(cx - hw, cy)
  screen.curve(cx - hw * 0.5, cy - up - 2, cx + hw * 0.5, cy - up - 2, cx + hw, cy)
  screen.curve(cx + hw * 0.5, cy + dn + 2, cx - hw * 0.5, cy + dn + 2, cx - hw, cy)
  screen.fill()
  if open > 0.06 then
    -- cavita'
    local ihw = hw * 0.78
    screen.level(0)
    screen.move(cx - ihw, cy)
    screen.curve(cx - ihw * 0.5, cy - up * 0.75, cx + ihw * 0.5, cy - up * 0.75, cx + ihw, cy)
    screen.curve(cx + ihw * 0.5, cy + dn * 0.8, cx - ihw * 0.5, cy + dn * 0.8, cx - ihw, cy)
    screen.fill()
    -- denti
    if open > 0.25 then
      screen.level(math.floor(bright * 0.55))
      screen.rect(cx - ihw * 0.5, cy - up * 0.55, ihw, 2)
      screen.fill()
    end
    -- lingua
    screen.level(math.floor(bright * 0.3))
    screen.rect(cx - ihw * 0.35, cy + dn * 0.35, ihw * 0.7, 2)
    screen.fill()
  else
    screen.level(0)
    screen.move(cx - hw + 2, cy)
    screen.line(cx + hw - 2, cy)
    screen.stroke()
  end
  -- soffio (fricative / rumore)
  if an.n > 0.05 then
    screen.level(math.floor(bright * 0.6))
    local count = math.floor(an.n * 14)
    for _ = 1, count do
      local px = cx + hw + 2 + math.random(0, 14)
      local py = cy + math.random(-5, 5)
      screen.pixel(px, py)
    end
    screen.fill()
  end
end

-- intestazione: nome pagina, tab, tempo, play
function UI.header(names, page, bpm, playing, beat_on)
  screen.level(15)
  screen.move(0, 6)
  screen.text(names[page])
  -- tab
  local n = #names
  local x0 = 128 - n * 6 - 22
  for i = 1, n do
    screen.level(i == page and 15 or 3)
    screen.rect(x0 + (i - 1) * 6, 1, 4, i == page and 5 or 3)
    screen.fill()
  end
  -- tempo
  screen.level(playing and (beat_on and 15 or 8) or 4)
  screen.move(128, 6)
  screen.text_right(math.floor(bpm + 0.5))
  if playing then
    screen.move(108, 1)
    screen.line(108, 6)
    screen.line(111, 3.5)
    screen.close()
    screen.fill()
  end
  screen.level(2)
  screen.move(0, 9.5)
  screen.line(128, 9.5)
  screen.stroke()
end

function UI.chip(x, y, w, h, txt, lvl, filled)
  if filled then
    screen.level(lvl)
    screen.rect(x, y, w, h)
    screen.fill()
    screen.level(0)
  else
    screen.level(lvl)
    screen.rect(x + 0.5, y + 0.5, w - 1, h - 1)
    screen.stroke()
  end
  screen.move(x + w / 2, y + h - 2)
  screen.text_center(txt)
end

function UI.hbar(x, y, w, h, frac, lvl)
  screen.level(2)
  screen.rect(x + 0.5, y + 0.5, w - 1, h - 1)
  screen.stroke()
  screen.level(lvl or 12)
  screen.rect(x + 1, y + 1, math.max(0, (w - 2) * util.clamp(frac, 0, 1)), h - 2)
  screen.fill()
end

-- pseudo-oscilloscopio: ricostruisce la forma d'onda dai registri
-- (3 formanti sincronizzate al glottide + rumore)
local scope_phase = 0
function UI.scope(x0, yc, w, amp, an, regs, hz, bright)
  scope_phase = (scope_phase + 0.07) % 1
  local f0 = math.max(40, hz or 110)
  local r = {an.f1 / f0, an.f2 / f0, (regs.f[3] or 2500) / f0}
  local a = {regs.a[1], regs.a[2], regs.a[3]}
  local tot = a[1] + a[2] + a[3] + 0.0001
  local level = an.a
  screen.level(bright or 12)
  for px = 0, w - 1 do
    local t = (px / w * 2 + scope_phase) % 1
    local env = 1 - t
    local s = 0
    for k = 1, 3 do s = s + a[k] * math.sin(2 * math.pi * r[k] * t) end
    s = s / tot * env * level
    s = s + (math.random() * 2 - 1) * an.n * 0.6
    local y = yc - util.clamp(s, -1, 1) * amp
    if px == 0 then screen.move(x0, y) else screen.line(x0 + px, y) end
  end
  screen.stroke()
end

-- curva dello spettro: picchi formantici (osc 1-3) e bande di rumore (osc 4-5)
function UI.formant_curve(x0, y0, w, h, regs, fscale, bright)
  local fmax = 6000
  local peaks = {}
  for k = 1, 3 do peaks[#peaks + 1] = {regs.f[k] * (fscale or 1), regs.a[k], 90 + k * 40} end
  for k = 1, 2 do peaks[#peaks + 1] = {regs.n[k], regs.na[k] * 0.8, 300 + regs.dist * 900} end
  screen.level(2)
  screen.move(x0, y0 + h + 0.5)
  screen.line(x0 + w, y0 + h + 0.5)
  screen.stroke()
  screen.level(bright or 10)
  screen.move(x0, y0 + h)
  for px = 0, w do
    local f = px / w * fmax
    local v = 0
    for _, p in ipairs(peaks) do
      local d = (f - p[1]) / p[3]
      v = v + p[2] * math.exp(-d * d)
    end
    screen.line(x0 + px, y0 + h - util.clamp(v, 0, 1.2) / 1.2 * h)
  end
  screen.line(x0 + w, y0 + h)
  screen.close()
  screen.fill()
end

-- schermata iniziale
function UI.splash(t, an)
  screen.level(15)
  screen.font_face(1)
  screen.font_size(16)
  screen.move(64, 22)
  screen.text_center("JETVOX")
  screen.font_size(8)
  screen.level(5)
  screen.move(64, 31)
  screen.text_center("talking synth  v3")
  UI.mouth(64, 46, 46, 14, an, 15)
  screen.level(3)
  screen.move(64, 63)
  screen.text_center(string.rep(".", math.floor(t * 10) % 4))
end

function UI.trunc(s, n)
  s = s or ""
  if #s > n then return s:sub(1, n - 1) .. "~" end
  return s
end

-- barre dei 5 oscillatori
function UI.osc_bars(x0, y0, regs, hmax)
  hmax = hmax or 14
  local vals = {regs.a[1], regs.a[2], regs.a[3], regs.na[1], regs.na[2]}
  for i = 1, 5 do
    local hh = math.floor(util.clamp(vals[i], 0, 1) * hmax)
    screen.level(i <= 3 and 10 or 4)
    screen.rect(x0 + (i - 1) * 4, y0 - hh, 3, math.max(1, hh))
    screen.fill()
  end
end

return UI
