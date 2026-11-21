-- jetvox v3
-- talking synth a fonemi
-- (Flame Talking Synth +
--  SpeakJet + step component)
--
-- E1: pagina   K1: shift
-- PLAY  E2 suono E3 nota
--       K2 suona K3 voce
-- SEQ   E2 step  E3 valore
--       K3 corsia (nota,
--       suono, parola, gate,
--       vel, prob, comp)
--       K2 play K1+K2 traccia
-- STEP  E2 campo E3 valore
-- TRACK E2 campo E3 valore
-- WORDS E2 parola E3 lettera
--       K2 ascolta K3 -> step
-- TALK  E2 frase K2 parla
--       K3 scrivi
-- VOICE / FX  E2 E3
--
-- dettagli: README.md

engine.name = "JetVox"

local musicutil = require "musicutil"
local textentry = require "textentry"

local A = include("lib/allophones")
local S = include("lib/sfx")
local MSA = include("lib/msa")
local TTS = include("lib/tts")
local PRESETS = include("lib/presets")
local V = include("lib/vocab")
local C = include("lib/components")
local Seq = include("lib/seq")
local UI = include("lib/ui")
local Y = include("lib/syll")

-------------------------------------------------------------------------------
-- stato
-------------------------------------------------------------------------------
local g = grid.connect()
local J = {}

local voices = {}
J.voices = voices
local VNAME = {"A", "B"}
local anim = {UI.new_anim(), UI.new_anim()}

local PAGES = {"PLAY", "SEQ", "STEP", "TRACK", "WORDS", "TALK", "VOICE", "FX"}
local P_PLAY, P_SEQ, P_STEP, P_TRACK, P_WORDS, P_TALK, P_VOICE, P_FX = 1, 2, 3, 4, 5, 6, 7, 8
local page = P_PLAY
local sel_voice = 1
local shift = false
local dirty = true
local grid_dirty = true
local beat_flash = false
local message, message_time = nil, 0
local splash_until = 0
local splash_t0 = 0

-- suoni navigabili: 72 allofoni + 7 pause + 55 effetti
local SOUNDS = {}
for _, ph in ipairs(A.list) do SOUNDS[#SOUNDS + 1] = {codes = {ph.code}, def = ph, name = ph.name} end
for c = 0, 6 do SOUNDS[#SOUNDS + 1] = {codes = {c}, pause = A.CONTROL[c], name = A.CONTROL[c].name} end
for _, fx in ipairs(S.list) do SOUNDS[#SOUNDS + 1] = {codes = {fx.code}, def = fx, name = fx.name} end
local SOUND_BY_CODE = {}
for i, s in ipairs(SOUNDS) do SOUND_BY_CODE[s.codes[1]] = i end
local sound_idx = 1

-- scala
local scale_full, root_idx = {}, 37
local cur_note = {5, 5}
local last_codes = {{128}, {128}}
local last_label = {"IY", "IY"}

-- frasi (64 slot)
local NPHRASES = 64
local phrases = {}
local phrase_sel = 1

-- vocabolario: modo 1 = per lettera, 2 = per tema
local word_idx = 1
local wmode = 1
local theme_sel = 1
local theme_idx = 1

-- grid
local GP_PHON, GP_SYLL, GP_SFX, GP_TEXT, GP_WORDS, GP_STEP = 1, 2, 3, 4, 5, 6
local grid_page = GP_PHON
local rec = false
local hold_mode = true
local loop_mode = {false, false}
local grid_shift = false
local held_step = nil
local held_step_used = false
local pad_flash = {}
local view_page = {1, 1}
local word_page = 1
local word_letter = "A"
local grid_theme_mode = false
local comp_sel = 1
local sel_set = {{}, {}}          -- selezione multipla (pagina STEP del grid)
local syl_onset, syl_coda = nil, nil

-- SEQ: corsie
local LANES = {"NOTA", "SUONO", "PAROLA", "GATE", "VEL", "PROB", "COMP"}
local LANE_SHORT = {"NOT", "SND", "WRD", "GAT", "VEL", "PRB", "CMP"}
local lane = 1

-- campi pagina STEP
local STEP_FIELDS = {"suono", "nota", "volume", "gate", "prob"}
local step_field = 1

-- campi pagina TRACK
local TRACK_FIELDS = {
  {id = "clock_tempo", name = "tempo", global = true},
  {id = "div", name = "divisione"}, {id = "len", name = "lunghezza"},
  {id = "dir", name = "direzione"}, {id = "swing", name = "swing"},
  {id = "transpose", name = "trasposizione"}, {id = "mute", name = "mute"},
  {id = "trem", name = "tremolo"}, {id = "trem_div", name = "tremolo 8/16"},
  {id = "rnd", name = "random"}, {id = "retrig", name = "retrigger"},
  {id = "root_note", name = "root", global = true}, {id = "scale", name = "scala", global = true},
  {id = "word_gap", name = "spazio parole", global = true},
  {id = "follow", name = "segui playhead", global = true},
}
local track_field = 1

local VOICE_PARAMS = {"speed", "bend", "formant", "length", "vol", "shape", "sync", "glide",
                      "vibrate", "vibdepth", "lofi", "srate", "bits", "tone", "drive",
                      "ringmix", "ringhz", "combmix", "combratio", "combfb",
                      "dsend", "rsend", "amp", "pan"}
local voice_param_sel = 1

local FX_PARAMS = {
  {"DELAY", {"dly_div", "dly_ms", "dly_fb", "dly_tone", "dly_wow", "dly_pp", "dly_ret", "dly2rev"}},
  {"REVERB", {"rev_size", "rev_decay", "rev_damp", "rev_pre", "rev_mod", "rev_shim", "rev_ret"}},
  {"CHORUS", {"ch_mix", "ch_rate", "ch_depth"}},
  {"STUTTER", {"stut_div"}},
  {"MASTER", {"m_drive", "m_fold", "m_crush", "m_bits", "m_rate", "m_tone", "m_level", "norns_rev"}},
}
local FX_LIST = {}
for _, sec in ipairs(FX_PARAMS) do
  for _, id in ipairs(sec[2]) do FX_LIST[#FX_LIST + 1] = {id = id, sec = sec[1]} end
end
local fx_sel = 1

local function flash_msg(txt)
  message = txt
  message_time = util.time()
  dirty = true
end

-------------------------------------------------------------------------------
-- scala e note
-------------------------------------------------------------------------------
local function build_scale()
  local root = params:get("root_note")
  scale_full = musicutil.generate_scale_of_length(root - 36, params:get("scale"), 120)
  root_idx = 1
  for i, n in ipairs(scale_full) do
    if n >= root then root_idx = i break end
  end
  grid_dirty = true
end

local function note_num(deg, semis)
  local idx = util.clamp(root_idx + deg - 1, 1, #scale_full)
  return scale_full[idx] + params:get("octave") * 12 + (semis or 0)
end

function J.note_hz(deg, semis) return musicutil.note_num_to_freq(note_num(deg, semis)) end
function J.glide(v) return params:get("glide_" .. v) / 1000 end
function J.release_ms() return params:get("release") end

local function note_name(deg)
  return musicutil.note_num_to_name(math.floor(note_num(deg) + 0.5), true)
end

-------------------------------------------------------------------------------
-- frasi e parole
-------------------------------------------------------------------------------
local function phrase_codes(i)
  local p = phrases[i]
  if not p then return {} end
  if not p.codes then
    p.codes = TTS.text_to_codes(p.text, {stress_first = params:get("tts_stress") == 2})
  end
  return p.codes
end

local word_cache = {}
local function word_codes(w)
  if not word_cache[w] then word_cache[w] = TTS.text_to_codes(w) end
  return word_cache[w]
end

local function current_word()
  if wmode == 2 then
    local th = V.themes[theme_sel]
    return th.words[util.clamp(theme_idx, 1, #th.words)]
  end
  return V.all[word_idx].word
end

local function sync_word_browser(w)
  local i = V.index[w]
  if i then
    word_idx = i
    word_letter = V.all[i].letter
  end
end

-------------------------------------------------------------------------------
-- engine adapter + throw
-------------------------------------------------------------------------------
local eng = {
  frame = function(...) engine.frame(...) end,
  pitch = function(...) engine.pitch(...) end,
  envosc = function(...) engine.envosc(...) end,
  param = function(...) engine.param(...) end,
}

local function restore_voice_fx(v)
  engine.param(v, "dsend", params:get("dsend_" .. v))
  engine.param(v, "rsend", params:get("rsend_" .. v))
  engine.param(v, "lofi", params:get("lofi_" .. v))
  engine.param(v, "srate", params:get("srate_" .. v))
  engine.param(v, "bits", params:get("bits_" .. v))
  engine.param(v, "ringmix", params:get("ringmix_" .. v))
end

local throw_id = {0, 0}
function J.throw(v, kind, dur)
  if kind <= 3 then engine.param(v, "dsend", ({0.35, 0.65, 1})[kind])
  elseif kind <= 6 then engine.param(v, "rsend", ({0.45, 0.75, 1})[kind - 3])
  elseif kind == 7 then engine.param(v, "dsend", 1); engine.param(v, "rsend", 1)
  elseif kind == 8 then engine.param(v, "lofi", 1); engine.param(v, "srate", 2600); engine.param(v, "bits", 4)
  else engine.param(v, "ringmix", 1) end
  throw_id[v] = throw_id[v] + 1
  local id = throw_id[v]
  clock.run(function()
    clock.sleep(dur)
    if throw_id[v] == id then restore_voice_fx(v) end
  end)
end

local STUT_DIVS = {1 / 8, 1 / 6, 1 / 4, 1 / 3, 1 / 2, 1}
local STUT_NAMES = {"1/32", "1/16t", "1/16", "1/8t", "1/8", "1/4"}
local function stutter(on)
  engine.fx("stutlen", clock.get_beat_sec() * STUT_DIVS[params:get("stut_div")])
  engine.fx("stut", on and 1 or 0)
end

-------------------------------------------------------------------------------
-- suonare
-------------------------------------------------------------------------------
local function play_codes(v, codes, label, opts)
  opts = opts or {}
  if not codes or #codes == 0 then return end
  last_codes[v] = codes
  last_label[v] = label or MSA.codes_to_string(codes)
  voices[v]:set_pitch(J.note_hz(opts.note or cur_note[v]))
  voices[v]:say(codes, {hold = opts.hold})
  dirty = true
end

local function release_voice(v)
  if hold_mode then voices[v]:release(params:get("release")) end
end

local function on_voice_event(v, kind)
  if kind == "done" and loop_mode[v] and not Seq.playing then
    clock.run(function()
      clock.sleep(0.001)
      if loop_mode[v] then voices[v]:say(last_codes[v]) end
    end)
  end
  dirty = true
end

function J.on_tick(t)
  if t == 1 then beat_flash = (Seq.tracks[1].tick % 4) == 1 end
  if params:get("follow") == 2 then
    local tr = Seq.tracks[t]
    if tr.pos >= 1 then view_page[t] = math.floor((tr.pos - 1) / 16) + 1 end
  end
  grid_dirty = true
  dirty = true
end

local function select_step(t, i)
  local tr = Seq.tracks[t]
  tr.sel = util.clamp(i, 1, Seq.MAX)
  view_page[t] = math.floor((tr.sel - 1) / 16) + 1
end

local function preview_step(t)
  if not Seq.playing then Seq.fire(t, Seq.tracks[t].sel, {preview = true}) end
end

-- inserisce codici nello step selezionato e avanza
-- (gap = di quanti step avanzare: "spazio parole" per le parole)
local function insert_at_selection(t, codes, label, gap)
  local tr = Seq.tracks[t]
  Seq.write(t, tr.sel, codes, label, false, cur_note[t])
  local len = Seq.len(t)
  select_step(t, (tr.sel - 1 + (gap or 1)) % len + 1)
  grid_dirty = true
end

local function word_gap() return params:get("word_gap") end

-- step bersaglio delle modifiche: selezione multipla o step selezionato
local function targets(t)
  local list = {}
  for i in pairs(sel_set[t]) do list[#list + 1] = i end
  if #list == 0 then list[1] = Seq.tracks[t].sel end
  table.sort(list)
  return list
end

local function ensure_step(t, i)
  local tr = Seq.tracks[t]
  if not tr.steps[i] then
    tr.steps[i] = Seq.new_step(last_codes[t], last_label[t], cur_note[t])
  end
  return tr.steps[i]
end

-------------------------------------------------------------------------------
-- salvataggio (con i PSET)
-------------------------------------------------------------------------------
local function data_file(n)
  return _path.data .. "jetvox/jetvox-" .. string.format("%02d", n) .. ".data"
end

local function save_state(n)
  util.make_dir(_path.data .. "jetvox")
  local ph = {}
  for i = 1, NPHRASES do ph[i] = phrases[i] and phrases[i].text or "" end
  tab.save({version = 3, tracks = {Seq.tracks[1].steps, Seq.tracks[2].steps}, phrases = ph}, data_file(n))
end

local function load_state(n)
  local d = tab.load(data_file(n))
  if not d then return end
  for t = 1, 2 do
    if d.tracks and d.tracks[t] then
      local steps = d.tracks[t]
      if (d.version or 1) < 2 and steps.steps then steps = steps.steps end
      for _, st in pairs(steps) do
        st.comps = st.comps or {}
        st.gate = st.gate or 0
        st.prob = st.prob or 100
        st.note = st.note or 1
      end
      Seq.tracks[t].steps = steps
      Seq.tracks[t].rt = {}
    end
  end
  if d.phrases then
    for i, txt in ipairs(d.phrases) do phrases[i] = (txt ~= "") and {text = txt} or nil end
  end
  grid_dirty = true
  dirty = true
end

-------------------------------------------------------------------------------
-- parametri
-------------------------------------------------------------------------------
local DLY_DIVS = {1 / 4, 1 / 3, 1 / 2, 3 / 4, 1, 1.5, 2}
local DLY_DIV_NAMES = {"1/16", "1/8t", "1/8", "1/8.", "1/4", "1/4.", "1/2", "libero"}

local function update_delay()
  local d = params:get("dly_div")
  local secs
  if d == #DLY_DIV_NAMES then secs = params:get("dly_ms") / 1000
  else secs = clock.get_beat_sec() * DLY_DIVS[d] end
  engine.fx("dtime", util.clamp(secs, 0.01, 2.4))
end

local function fxp(id, name, cs, key, fn)
  params:add_control(id, name, cs)
  params:set_action(id, function(x) engine.fx(key, fn and fn(x) or x) end)
end

local function setup_params()
  params:add_separator("jetvox_sep", "JETVOX")

  params:add_group("jetvox_global", "globale", 11)
  params:add_number("root_note", "root", 24, 72, 45, function(p) return musicutil.note_num_to_name(p:get(), true) end)
  params:set_action("root_note", function() build_scale() end)
  local scale_names = {}
  for i = 1, #musicutil.SCALES do scale_names[i] = musicutil.SCALES[i].name end
  params:add_option("scale", "scala", scale_names, 1)
  params:set_action("scale", function() build_scale() end)
  params:add_number("octave", "ottava", -2, 2, 0)
  params:add_control("release", "release hold (ms)", controlspec.new(5, 2000, "exp", 1, 80, "ms"))
  params:add_option("trem_phase", "fase tremolo B", {"0", "180"}, 1)
  params:add_option("tts_stress", "TTS accento", {"off", "on"}, 1)
  params:set_action("tts_stress", function() for _, p in pairs(phrases) do p.codes = nil end end)
  params:add_option("hold_mode", "grid hold", {"off", "on"}, 2)
  params:set_action("hold_mode", function(x) hold_mode = (x == 2); grid_dirty = true end)
  params:add_option("babble_auto", "babble continuo", {"off", "on"}, 1)
  params:add_number("babble_rate", "babble ogni (step)", 1, 64, 16)
  params:add_option("follow", "segui playhead", {"off", "on"}, 2)
  params:add_number("word_gap", "spazio tra parole (step)", 1, 8, 1)

  for v = 1, 2 do
    params:add_group("jetvox_voice_" .. v, "voce " .. VNAME[v], 24)
    params:add_number("speed_" .. v, "speed (chip)", 0, 127, 114)
    params:set_action("speed_" .. v, function(x) voices[v].speed = x end)
    params:add_number("bend_" .. v, "bend (chip)", 0, 15, 5)
    params:set_action("bend_" .. v, function(x) voices[v].bend = x; voices[v]:send_fscale() end)
    params:add_control("formant_" .. v, "formanti M/F", controlspec.new(0.5, 2, "exp", 0, 1, "x"))
    params:set_action("formant_" .. v, function(x) voices[v].formant = x; voices[v]:send_fscale() end)
    params:add_control("length_" .. v, "lunghezza", controlspec.new(0.25, 6, "exp", 0, 1.2, "x"))
    params:set_action("length_" .. v, function(x) voices[v].length = x end)
    params:add_number("vol_" .. v, "volume (chip)", 0, 127, 96)
    params:set_action("vol_" .. v, function(x) voices[v].vol = x; voices[v]:send_vol() end)
    params:add_option("shape_" .. v, "glottide", {"saw", "sine", "tri", "square"}, 1)
    params:set_action("shape_" .. v, function(x) voices[v].shape = x - 1; voices[v]:speech_env() end)
    params:add_control("sync_" .. v, "sync formanti", controlspec.new(0, 1, "lin", 0, 1))
    params:set_action("sync_" .. v, function(x) engine.param(v, "sync", x) end)
    params:add_control("glide_" .. v, "glide (ms)", controlspec.new(0, 1000, "lin", 1, 20, "ms"))
    params:set_action("glide_" .. v, function(x) voices[v].glide = x / 1000 end)
    params:add_control("vibrate_" .. v, "vibrato rate", controlspec.new(0.1, 12, "exp", 0, 5.5, "hz"))
    params:set_action("vibrate_" .. v, function(x) engine.param(v, "vibrate", x) end)
    params:add_control("vibdepth_" .. v, "vibrato depth", controlspec.new(0, 0.1, "lin", 0, 0))
    params:set_action("vibdepth_" .. v, function(x) engine.param(v, "vibdepth", x) end)
    params:add_control("lofi_" .. v, "lo-fi (PWM)", controlspec.new(0, 1, "lin", 0, 0.5))
    params:set_action("lofi_" .. v, function(x) engine.param(v, "lofi", x) end)
    params:add_control("srate_" .. v, "sample rate", controlspec.new(1000, 48000, "exp", 1, 16384, "hz"))
    params:set_action("srate_" .. v, function(x) engine.param(v, "srate", x) end)
    params:add_number("bits_" .. v, "bit", 2, 16, 8)
    params:set_action("bits_" .. v, function(x) engine.param(v, "bits", x) end)
    params:add_control("tone_" .. v, "tono (LPF)", controlspec.new(300, 16000, "exp", 1, 7500, "hz"))
    params:set_action("tone_" .. v, function(x) engine.param(v, "tone", x) end)
    params:add_control("drive_" .. v, "drive (mixer)", controlspec.new(0, 1, "lin", 0, 0))
    params:set_action("drive_" .. v, function(x) engine.param(v, "drive", x) end)
    params:add_control("ringmix_" .. v, "ring mod mix", controlspec.new(0, 1, "lin", 0, 0))
    params:set_action("ringmix_" .. v, function(x) engine.param(v, "ringmix", x) end)
    params:add_control("ringhz_" .. v, "ring mod freq", controlspec.new(5, 3000, "exp", 0, 180, "hz"))
    params:set_action("ringhz_" .. v, function(x) engine.param(v, "ringhz", x) end)
    params:add_control("combmix_" .. v, "comb robot mix", controlspec.new(0, 1, "lin", 0, 0))
    params:set_action("combmix_" .. v, function(x) engine.param(v, "combmix", x) end)
    params:add_control("combratio_" .. v, "comb ratio", controlspec.new(0.25, 4, "exp", 0, 1, "x"))
    params:set_action("combratio_" .. v, function(x) engine.param(v, "combratio", x) end)
    params:add_control("combfb_" .. v, "comb feedback", controlspec.new(0, 1, "lin", 0, 0.7))
    params:set_action("combfb_" .. v, function(x) engine.param(v, "combfb", x) end)
    params:add_control("dsend_" .. v, "mandata delay", controlspec.new(0, 1, "lin", 0, 0))
    params:set_action("dsend_" .. v, function(x) engine.param(v, "dsend", x) end)
    params:add_control("rsend_" .. v, "mandata riverbero", controlspec.new(0, 1, "lin", 0, 0.15))
    params:set_action("rsend_" .. v, function(x) engine.param(v, "rsend", x) end)
    params:add_control("amp_" .. v, "livello", controlspec.new(0, 1, "lin", 0, 0.7))
    params:set_action("amp_" .. v, function(x) engine.param(v, "amp", x) end)
    params:add_control("pan_" .. v, "pan", controlspec.new(-1, 1, "lin", 0, v == 1 and -0.35 or 0.35))
    params:set_action("pan_" .. v, function(x) engine.param(v, "pan", x) end)
  end

  for t = 1, 2 do
    params:add_group("jetvox_track_" .. t, "traccia " .. VNAME[t], 10)
    params:add_option("div_" .. t, "divisione", Seq.DIV_NAMES, 5)
    params:add_number("len_" .. t, "lunghezza", 1, Seq.MAX, 16)
    params:set_action("len_" .. t, function() grid_dirty = true; dirty = true end)
    params:add_option("dir_" .. t, "direzione", Seq.DIR_NAMES, 1)
    params:add_number("swing_" .. t, "swing %", 50, 80, 50)
    params:add_number("transpose_" .. t, "trasposizione", -24, 24, 0)
    params:add_option("mute_" .. t, "mute", {"off", "on"}, 1)
    params:add_option("trem_" .. t, "tremolo", {"off", "on"}, 1)
    params:add_option("trem_div_" .. t, "tremolo 8/16", {"8", "16"}, 2)
    params:add_number("rnd_" .. t, "random", 0, 100, 0)
    params:add_option("retrig_" .. t, "retrigger", {"taglia", "salta se occupato"}, 1)
  end

  params:add_group("jetvox_fx", "effetti", 27)
  params:add_option("dly_div", "delay tempo", DLY_DIV_NAMES, 6)
  params:set_action("dly_div", update_delay)
  params:add_control("dly_ms", "delay libero (ms)", controlspec.new(10, 2400, "exp", 1, 400, "ms"))
  params:set_action("dly_ms", update_delay)
  fxp("dly_fb", "delay feedback", controlspec.new(0, 1.05, "lin", 0, 0.45), "dfb")
  fxp("dly_tone", "delay tono", controlspec.new(300, 16000, "exp", 0, 4500, "hz"), "dtone")
  fxp("dly_wow", "delay wow (nastro)", controlspec.new(0, 1, "lin", 0, 0.2), "dwow")
  params:add_option("dly_pp", "delay ping-pong", {"off", "on"}, 2)
  params:set_action("dly_pp", function(x) engine.fx("dpp", x - 1) end)
  fxp("dly_ret", "delay ritorno", controlspec.new(0, 1.5, "lin", 0, 0.8), "dret")
  fxp("dly2rev", "delay -> riverbero", controlspec.new(0, 1, "lin", 0, 0.2), "d2r")
  fxp("rev_size", "riverbero size", controlspec.new(0.2, 3, "exp", 0, 1), "rsize")
  fxp("rev_decay", "riverbero decay", controlspec.new(0.2, 40, "exp", 0, 3.5, "s"), "rdecay")
  fxp("rev_damp", "riverbero damp", controlspec.new(500, 18000, "exp", 0, 6000, "hz"), "rdamp")
  fxp("rev_pre", "riverbero predelay", controlspec.new(0, 0.28, "lin", 0, 0.02, "s"), "rpre")
  fxp("rev_mod", "riverbero modulazione", controlspec.new(0, 1, "lin", 0, 0.5), "rmod")
  fxp("rev_shim", "shimmer (+8va)", controlspec.new(0, 1, "lin", 0, 0), "rshim")
  fxp("rev_ret", "riverbero ritorno", controlspec.new(0, 1.5, "lin", 0, 0.8), "rret")
  fxp("ch_mix", "chorus mix", controlspec.new(0, 1, "lin", 0, 0), "chmix")
  fxp("ch_rate", "chorus rate", controlspec.new(0.05, 5, "exp", 0, 0.3, "hz"), "chrate")
  fxp("ch_depth", "chorus depth", controlspec.new(0, 1, "lin", 0, 0.5), "chdepth")
  params:add_option("stut_div", "stutter lunghezza", STUT_NAMES, 3)
  fxp("m_drive", "saturazione", controlspec.new(0, 1, "lin", 0, 0), "mdrive")
  fxp("m_fold", "wavefolder", controlspec.new(0, 1, "lin", 0, 0), "mfold")
  fxp("m_crush", "bitcrusher mix", controlspec.new(0, 1, "lin", 0, 0), "mcrush")
  fxp("m_bits", "bitcrusher bit", controlspec.new(1, 16, "lin", 1, 6), "mbits")
  fxp("m_rate", "bitcrusher rate", controlspec.new(500, 48000, "exp", 1, 8000, "hz"), "mrate")
  fxp("m_tone", "master tono", controlspec.new(300, 20000, "exp", 0, 18000, "hz"), "mtone")
  fxp("m_level", "master livello", controlspec.new(0, 2, "lin", 0, 1), "mlevel")
  params:add_option("norns_rev", "riverbero di sistema", {"off", "on"}, 1)
  params:set_action("norns_rev", function(x)
    if audio and audio.rev_on then
      if x == 2 then audio.rev_on() else audio.rev_off() end
    end
  end)

  params.action_write = function(filename, name, number) save_state(number) end
  params.action_read = function(filename, silent, number) load_state(number) end
  params.action_delete = function(filename, name, number) os.remove(data_file(number)) end
end

-------------------------------------------------------------------------------
-- modifica degli step (condivisa da SEQ, STEP e grid)
-------------------------------------------------------------------------------
local function accel(d) return (math.abs(d) > 2) and d * 4 or d end

local function cycle_sound_idx(st, d)
  local idx = 0
  if st and #st.codes == 1 then idx = SOUND_BY_CODE[st.codes[1]] or 0 end
  if idx == 0 and d > 0 then return sound_idx end
  return util.clamp(idx + d, 0, #SOUNDS)
end

local function next_letter_idx(i, d)
  local li = V.all[i].letter:byte() - 64
  local nl = li + d
  while nl >= 1 and nl <= 26 and not V.first[string.char(64 + nl)] do nl = nl + (d > 0 and 1 or -1) end
  if nl >= 1 and nl <= 26 then return V.first[string.char(64 + nl)] end
  return i
end

-- corsie della pagina SEQ (alt = K1 tenuto)
local function edit_lane(t, d, alt)
  local tr = Seq.tracks[t]
  local i = tr.sel
  local st = tr.steps[i]
  local L = lane
  if L == 1 then
    -- NOTA: crea lo step se vuoto (con l'ultimo suono suonato)
    if not st then
      st = ensure_step(t, i)
      st.note = cur_note[t]
    else
      st.note = util.clamp(st.note + (alt and d * 7 or d), -13, 40)
    end
    cur_note[t] = st.note
    preview_step(t)
  elseif L == 2 then
    -- SUONO: scorre fonemi / pause / effetti (K1: salti da 10)
    local idx = cycle_sound_idx(st, alt and d * 10 or d)
    if idx == 0 then tr.steps[i] = nil
    else
      sound_idx = idx
      Seq.write(t, i, SOUNDS[idx].codes, nil, false, st and st.note or cur_note[t])
      preview_step(t)
    end
  elseif L == 3 then
    -- PAROLA: scorre il vocabolario direttamente sullo step (K1: lettera)
    local idx = (st and st.label and V.index[st.label]) or word_idx
    if alt then idx = next_letter_idx(idx, d) else idx = util.clamp(idx + accel(d), 1, V.count) end
    word_idx = idx
    word_letter = V.all[idx].letter
    local w = V.all[idx].word
    Seq.write(t, i, word_codes(w), w, false, st and st.note or cur_note[t])
    preview_step(t)
  elseif L == 7 then
    -- COMP: K1+E3 sceglie il componente, E3 il valore (0 = off)
    if alt then
      comp_sel = util.clamp(comp_sel + d, 1, #C.list)
    else
      for _, k in ipairs(targets(t)) do
        local s = ensure_step(t, k)
        local id = C.list[comp_sel].id
        local nv = util.clamp((s.comps[id] or 0) + d, 0, 10)
        s.comps[id] = (nv > 0) and nv or nil
      end
    end
  else
    if not st then return end
    for _, k in ipairs(targets(t)) do
      local s = tr.steps[k]
      if s then
        if L == 4 then s.gate = util.clamp(s.gate + d, 0, 16)
        elseif L == 5 then s.level = util.clamp((s.level or params:get("vol_" .. t)) + (alt and d * 10 or d * 4), 0, 127)
        elseif L == 6 then s.prob = util.clamp(s.prob + (alt and d * 10 or d * 5), 0, 100) end
      end
    end
  end
end

-- campi della pagina STEP
local function edit_step_field(t, f, d)
  local tr = Seq.tracks[t]
  local i = tr.sel
  local st = tr.steps[i]
  if f == 1 then
    local idx = cycle_sound_idx(st, d)
    if idx == 0 then tr.steps[i] = nil
    else Seq.write(t, i, SOUNDS[idx].codes, nil, false, st and st.note or cur_note[t]) end
    return
  end
  for _, k in ipairs(targets(t)) do
    local s = (f > #STEP_FIELDS) and ensure_step(t, k) or tr.steps[k]
    if s then
      if f == 2 then s.note = util.clamp(s.note + d, -13, 40)
      elseif f == 3 then s.level = util.clamp((s.level or params:get("vol_" .. t)) + d, 0, 127)
      elseif f == 4 then s.gate = util.clamp(s.gate + d, 0, 16)
      elseif f == 5 then s.prob = util.clamp(s.prob + d, 0, 100)
      else
        local c = C.list[f - #STEP_FIELDS]
        comp_sel = c.idx
        local nv = util.clamp((s.comps[c.id] or 0) + d, 0, 10)
        s.comps[c.id] = (nv > 0) and nv or nil
      end
    end
  end
end

-------------------------------------------------------------------------------
-- grid
-------------------------------------------------------------------------------
local FAM_LEVEL = {vowel = 10, reson = 7, diph = 12, vfric = 5, vstop = 4, fric = 6, stop = 3}

local function words_of_letter(l) return V.by_letter[l] or {} end

local function grid_word_list()
  if grid_theme_mode then return V.themes[theme_sel].words end
  return words_of_letter(word_letter)
end

-- contenuto dei pad (righe 1..5): codes, label, livello
local function pad_content(x, y)
  if grid_page == GP_PHON then
    local i = (y - 1) * 16 + x - 1
    if i < 72 then
      local code = 128 + i
      return {code}, A.by_code[code].name, FAM_LEVEL[A.family(code)]
    elseif y == 5 and x >= 9 and x <= 15 then
      local c = x - 9
      return {c}, A.CONTROL[c].name, 2
    end
  elseif grid_page == GP_SFX then
    if y <= 4 and x <= 10 then
      local code = 200 + (y - 1) * 10 + (x - 1)
      return {code}, S.by_code[code].name, ({8, 11, 6, 9})[y]
    elseif y == 5 and x <= 15 then
      local code = 240 + x - 1
      return {code}, S.by_code[code].name, x <= 12 and 5 or 12
    end
  elseif grid_page == GP_TEXT then
    if y == 1 then
      local ch = string.char(64 + x)
      return TTS.letter_codes(ch), ch, 9
    elseif y == 2 and x <= 10 then
      local ch = string.char(80 + x)
      return TTS.letter_codes(ch), ch, 9
    elseif (y == 2 and x > 10) or (y == 3 and x <= 4) then
      local d = (y == 2) and (x - 11) or (x + 5)
      return TTS.letter_codes(tostring(d)), tostring(d), 5
    elseif y >= 4 then
      local i = (y - 4) * 16 + x
      if phrases[i] then return phrase_codes(i), phrases[i].text, 7 end
    end
  elseif grid_page == GP_WORDS then
    if y >= 3 then
      local list = grid_word_list()
      local i = (word_page - 1) * 48 + (y - 3) * 16 + x
      local w = list[i]
      if w then return word_codes(w), w, 6 end
    end
  end
  return nil
end

local function grid_redraw()
  if not g then return end
  g:all(0)
  local v = sel_voice
  local tr = Seq.tracks[v]
  local st = tr.steps[tr.sel]

  if grid_page == GP_STEP then
    -- componenti, valori, gate, volume, probabilita'
    for x = 1, 16 do
      local id = C.list[x].id
      local active = st and st.comps[id]
      local l = active and 9 or 2
      if x == comp_sel then l = active and 15 or 6 end
      g:led(x, 1, l)
    end
    local cid = C.list[comp_sel].id
    local cv = st and st.comps[cid]
    for x = 1, 10 do g:led(x, 2, (cv == x) and 15 or 4) end
    g:led(16, 2, cv and 8 or 2)
    local gate = st and st.gate or 0
    for x = 1, 16 do g:led(x, 3, (x - 1 <= gate) and (x == gate + 1 and 13 or 6) or 1) end
    local lvl = st and (st.level or params:get("vol_" .. v)) or 0
    local lx = math.floor(lvl / 127 * 15 + 0.5) + 1
    for x = 1, 16 do g:led(x, 4, x <= lx and (x == lx and 13 or 5) or 1) end
    local prob = st and st.prob or 100
    local px = math.max(1, math.floor(prob / 100 * 16 + 0.5))
    for x = 1, 16 do g:led(x, 5, x <= px and (x == px and 13 or 5) or 1) end
  elseif grid_page == GP_SYLL then
    for k, _ in ipairs(Y.ONSETS) do
      local x, y = (k - 1) % 16 + 1, (k <= 16) and 1 or 2
      g:led(x, y, syl_onset == k and 15 or 6)
    end
    for k, n in ipairs(Y.NUCLEI) do
      local x, y = (k - 1) % 16 + 1, (k <= 16) and 3 or 4
      g:led(x, y, pad_flash[x .. "," .. y] and 15 or (n[2] <= 139 and 10 or (n[2] <= 164 and 8 or 4)))
    end
    for k, _ in ipairs(Y.CODAS) do g:led(k, 5, syl_coda == k and 15 or 4) end
  else
    for y = 1, 5 do
      for x = 1, 16 do
        local codes, _, lvl = pad_content(x, y)
        if codes then g:led(x, y, pad_flash[x .. "," .. y] and 15 or lvl) end
      end
    end
    if grid_page == GP_WORDS then
      if grid_theme_mode then
        for k = 1, math.min(16, #V.themes) do g:led(k, 1, k == theme_sel and 15 or 4) end
        for x = 1, 10 do g:led(x, 2, 0) end
      else
        for k = 1, 26 do
          local l = string.char(64 + k)
          local x = (k - 1) % 16 + 1
          local y = (k <= 16) and 1 or 2
          g:led(x, y, l == word_letter and 15 or (#words_of_letter(l) > 0 and 4 or 1))
        end
      end
      local pages = math.max(1, math.ceil(#grid_word_list() / 48))
      g:led(12, 2, grid_theme_mode and 12 or 3)
      g:led(13, 2, word_page > 1 and 8 or 2)
      g:led(14, 2, word_page < pages and 8 or 2)
      g:led(16, 2, 5)
    end
  end

  -- riga 6: tastiera dei gradi di scala
  local shown_note = (grid_page == GP_STEP and st) and st.note or cur_note[v]
  for x = 1, 16 do
    local n = scale_full[root_idx + x - 1]
    local is_root = n and ((n - params:get("root_note")) % 12 == 0)
    g:led(x, 6, x == shown_note and 15 or (is_root and 6 or 3))
  end
  -- riga 7: step della pagina visualizzata
  local len = Seq.len(v)
  local base = (view_page[v] - 1) * 16
  for x = 1, 16 do
    local i = base + x
    local l = 0
    if i <= len then l = 2 end
    if tr.steps[i] then l = (Seq.comp_count(tr.steps[i]) > 0) and 8 or 6 end
    if sel_set[v][i] then l = 12 end
    if i == tr.sel then l = math.max(l, 11) end
    if Seq.playing and i == tr.pos then l = 15 end
    g:led(x, 7, l)
  end
  -- riga 8: controlli
  g:led(1, 8, v == 1 and 15 or 4)
  g:led(2, 8, v == 2 and 15 or 4)
  for k = 1, 6 do g:led(2 + k, 8, grid_page == k and 13 or 3) end
  g:led(9, 8, grid_shift and 15 or 2)
  g:led(10, 8, rec and 15 or 3)
  g:led(11, 8, hold_mode and 10 or 3)
  g:led(12, 8, loop_mode[v] and 10 or 3)
  g:led(13, 8, 5)
  g:led(14, 8, 4)
  g:led(15, 8, 2 + view_page[v] * 3)
  g:led(16, 8, Seq.playing and (beat_flash and 15 or 10) or 4)
  g:refresh()
end

local function flash(x, y)
  local key = x .. "," .. y
  pad_flash[key] = true
  grid_dirty = true
  clock.run(function()
    clock.sleep(0.12)
    pad_flash[key] = nil
    grid_dirty = true
  end)
end

local function grid_step_page_key(x, y, v)
  if y == 1 then
    comp_sel = x
    page = P_STEP
    step_field = #STEP_FIELDS + x
    return
  end
  for _, i in ipairs(targets(v)) do
    local st = ensure_step(v, i)
    if y == 2 then
      local id = C.list[comp_sel].id
      if x <= 10 then st.comps[id] = x elseif x == 16 then st.comps[id] = nil end
    elseif y == 3 then st.gate = x - 1
    elseif y == 4 then st.level = math.floor((x - 1) / 15 * 127 + 0.5)
    elseif y == 5 then st.prob = math.floor(x / 16 * 100 + 0.5)
    end
  end
end

-- un pad "sonoro" e' stato premuto: suona e (se REC / step tenuto) scrive
local function pad_pressed(v, codes, label, is_word)
  if held_step then
    Seq.write(v, held_step, codes, label, true)
    held_step_used = true
  elseif rec and not grid_shift then
    insert_at_selection(v, codes, label, is_word and word_gap() or 1)
  end
  play_codes(v, codes, label, {hold = hold_mode})
end

local function syll_key(x, y, z, v)
  if y <= 2 then
    local k = (y - 1) * 16 + x
    if not Y.ONSETS[k] then return end
    if z == 1 then
      syl_onset = k
      local codes, label = Y.build(k, nil, nil)
      play_codes(v, codes, label, {hold = false})
    elseif syl_onset == k then
      syl_onset = nil
    end
  elseif y <= 4 then
    local k = (y - 3) * 16 + x
    if not Y.NUCLEI[k] then return end
    if z == 1 then
      flash(x, y)
      local codes, label = Y.build(syl_onset, k, syl_coda)
      pad_pressed(v, codes, label, false)
    else
      release_voice(v)
    end
  elseif y == 5 then
    if not Y.CODAS[x] then return end
    if z == 1 then syl_coda = x elseif syl_coda == x then syl_coda = nil end
  end
end

g.key = function(x, y, z)
  local v = sel_voice
  local tr = Seq.tracks[v]
  if y <= 5 then
    if grid_page == GP_STEP then
      if z == 1 then grid_step_page_key(x, y, v) end
    elseif grid_page == GP_SYLL then
      syll_key(x, y, z, v)
    elseif grid_page == GP_WORDS and y <= 2 then
      if z == 1 then
        local k = (y - 1) * 16 + x
        if grid_theme_mode and y == 1 then
          if V.themes[x] then theme_sel = x; word_page = 1 end
        elseif not grid_theme_mode and k <= 26 then
          word_letter = string.char(64 + k)
          word_page = 1
          word_idx = V.first[word_letter] or word_idx
        elseif y == 2 and x == 12 then
          grid_theme_mode = not grid_theme_mode
          word_page = 1
        elseif y == 2 and x == 13 then word_page = math.max(1, word_page - 1)
        elseif y == 2 and x == 14 then
          word_page = math.min(math.max(1, math.ceil(#grid_word_list() / 48)), word_page + 1)
        elseif y == 2 and x == 16 then
          local list = grid_word_list()
          if #list > 0 then
            local w = list[math.random(#list)]
            pad_pressed(v, word_codes(w), w, true)
            sync_word_browser(w)
          end
        end
      end
    else
      local codes, label = pad_content(x, y)
      if not codes then return end
      if z == 1 then
        flash(x, y)
        local is_text = (grid_page == GP_TEXT or grid_page == GP_WORDS)
        pad_pressed(v, codes, is_text and label or nil, grid_page == GP_WORDS)
        if grid_page == GP_WORDS then sync_word_browser(label) end
      else
        release_voice(v)
      end
    end
  elseif y == 6 then
    if z == 1 then
      if held_step and tr.steps[held_step] then
        tr.steps[held_step].note = x
        held_step_used = true
      elseif grid_page == GP_STEP then
        for _, i in ipairs(targets(v)) do ensure_step(v, i).note = x end
      elseif rec and tr.steps[tr.sel] then
        tr.steps[tr.sel].note = x
      end
      cur_note[v] = x
      play_codes(v, last_codes[v], last_label[v], {hold = hold_mode})
    else
      if cur_note[v] == x then release_voice(v) end
    end
  elseif y == 7 then
    local i = (view_page[v] - 1) * 16 + x
    if grid_page == GP_STEP then
      -- selezione multipla stile OP-XY
      if z == 1 then
        if grid_shift then
          sel_set[v] = {}
        else
          if sel_set[v][i] then sel_set[v][i] = nil else sel_set[v][i] = true end
          select_step(v, i)
        end
      end
    elseif z == 1 then
      if held_step and held_step ~= i then
        params:set("len_" .. v, i)
        held_step_used = true
        flash_msg("lunghezza " .. VNAME[v] .. ": " .. i)
      else
        held_step = i
        held_step_used = false
        select_step(v, i)
        if grid_shift or shift then
          tr.steps[i] = nil
          held_step_used = true
        end
      end
    elseif held_step == i then
      if not held_step_used and tr.steps[i] then
        Seq.fire(v, i, {preview = true})
      end
      held_step = nil
    end
  elseif y == 8 then
    if x == 9 then grid_shift = (z == 1) end
    if x == 14 then stutter(z == 1) end
    if z == 1 then
      if x == 1 or x == 2 then sel_voice = x
      elseif x >= 3 and x <= 8 then
        grid_page = x - 2
        if grid_page ~= GP_STEP then sel_set = {{}, {}} end
      elseif x == 10 then rec = not rec
      elseif x == 11 then params:set("hold_mode", hold_mode and 1 or 2)
      elseif x == 12 then
        loop_mode[v] = not loop_mode[v]
        if loop_mode[v] then play_codes(v, last_codes[v], last_label[v]) end
      elseif x == 13 then
        if grid_shift then Seq.babble(v, true); flash_msg("babble + componenti " .. VNAME[v])
        else Seq.babble(v, false); flash_msg("babble " .. VNAME[v]) end
      elseif x == 15 then
        local pages = math.max(1, math.ceil(Seq.len(v) / 16))
        view_page[v] = view_page[v] % pages + 1
        select_step(v, (view_page[v] - 1) * 16 + 1)
      elseif x == 16 then
        if Seq.playing and not grid_shift then Seq.stop() else Seq.start() end
      end
    end
  end
  grid_dirty = true
  dirty = true
end

-------------------------------------------------------------------------------
-- encoder / tasti
-------------------------------------------------------------------------------
local function dismiss_splash()
  if splash_until > 0 then splash_until = 0; dirty = true; return true end
  return false
end

function enc(n, d)
  if dismiss_splash() then return end
  local v = sel_voice
  local tr = Seq.tracks[v]
  if n == 1 then
    page = util.clamp(page + d, 1, #PAGES)
  elseif page == P_PLAY then
    if n == 2 then sound_idx = util.clamp(sound_idx + d, 1, #SOUNDS)
    elseif n == 3 then
      cur_note[v] = util.clamp(cur_note[v] + d, -13, 40)
      voices[v]:set_pitch(J.note_hz(cur_note[v]))
    end
  elseif page == P_SEQ then
    if n == 2 then
      if shift then lane = util.clamp(lane + d, 1, #LANES)
      else select_step(v, util.clamp(tr.sel + d, 1, Seq.len(v))) end
    elseif n == 3 then edit_lane(v, d, shift) end
  elseif page == P_STEP then
    if n == 2 then
      if shift then select_step(v, util.clamp(tr.sel + d, 1, Seq.len(v)))
      else step_field = util.clamp(step_field + d, 1, #STEP_FIELDS + #C.list) end
      if step_field > #STEP_FIELDS then comp_sel = step_field - #STEP_FIELDS end
    elseif n == 3 then edit_step_field(v, step_field, d) end
  elseif page == P_TRACK then
    if n == 2 then track_field = util.clamp(track_field + d, 1, #TRACK_FIELDS)
    elseif n == 3 then
      local f = TRACK_FIELDS[track_field]
      params:delta(f.global and f.id or (f.id .. "_" .. v), d)
    end
  elseif page == P_WORDS then
    if wmode == 1 then
      if n == 2 then word_idx = util.clamp(word_idx + accel(d), 1, V.count)
      elseif n == 3 then word_idx = next_letter_idx(word_idx, d) end
      word_letter = V.all[word_idx].letter
    else
      if n == 2 then theme_idx = util.clamp(theme_idx + d, 1, #V.themes[theme_sel].words)
      elseif n == 3 then theme_sel = util.clamp(theme_sel + d, 1, #V.themes); theme_idx = 1 end
    end
  elseif page == P_TALK then
    if n == 2 then phrase_sel = util.clamp(phrase_sel + d, 1, NPHRASES) end
  elseif page == P_VOICE then
    if n == 2 then voice_param_sel = util.clamp(voice_param_sel + d, 1, #VOICE_PARAMS)
    elseif n == 3 then params:delta(VOICE_PARAMS[voice_param_sel] .. "_" .. v, d) end
  elseif page == P_FX then
    if n == 2 then fx_sel = util.clamp(fx_sel + d, 1, #FX_LIST)
    elseif n == 3 then params:delta(FX_LIST[fx_sel].id, d) end
  end
  grid_dirty = true
  dirty = true
end

local function toggle_play()
  if Seq.playing then Seq.stop() else Seq.start() end
end

function key(n, z)
  if z == 1 and dismiss_splash() then return end
  local v = sel_voice
  local tr = Seq.tracks[v]
  if n == 1 then shift = (z == 1); dirty = true; return end

  if page == P_PLAY then
    local s = SOUNDS[sound_idx]
    if n == 2 then
      if z == 1 then play_codes(v, s.codes, s.name, {hold = true})
      else voices[v]:release(params:get("release")) end
    elseif n == 3 and z == 1 then
      if shift then insert_at_selection(v, s.codes, nil); flash_msg(s.name .. " -> step")
      else sel_voice = 3 - sel_voice end
    end
  elseif page == P_FX and n == 2 and (shift or z == 0) then
    -- K1+K2 tenuto: stutter (il rilascio di K2 lo spegne sempre)
    stutter(z == 1)
  elseif z == 1 then
    if page == P_SEQ then
      if n == 2 then
        if shift then sel_voice = 3 - sel_voice else toggle_play() end
      elseif n == 3 then
        if shift then tr.steps[tr.sel] = nil; flash_msg("step " .. tr.sel .. " cancellato")
        else lane = lane % #LANES + 1 end
      end
    elseif page == P_STEP then
      if n == 2 then
        if shift then Seq.copy(v, tr.sel); flash_msg("copiato")
        else Seq.fire(v, tr.sel, {preview = true}) end
      elseif n == 3 then
        if shift then
          for _, i in ipairs(targets(v)) do tr.steps[i] = nil end
          flash_msg("step cancellati")
        else
          for _, i in ipairs(targets(v)) do Seq.paste(v, i) end
          flash_msg("incollato")
        end
      end
    elseif page == P_TRACK then
      if n == 2 then
        if shift then Seq.babble(v, true); flash_msg("babble + componenti") else toggle_play() end
      elseif n == 3 then
        if shift then Seq.clear(v); flash_msg("traccia cancellata") else sel_voice = 3 - sel_voice end
      end
    elseif page == P_WORDS then
      local w = current_word()
      if n == 2 then
        if shift then
          wmode = 3 - wmode
          flash_msg(wmode == 1 and "per lettera" or "per tema")
        else
          play_codes(v, word_codes(w), w)
        end
      elseif n == 3 then
        if shift then
          local p = phrases[phrase_sel]
          local txt = (p and p.text ~= "") and (p.text .. " " .. w) or w
          phrases[phrase_sel] = {text = txt}
          flash_msg("frase " .. phrase_sel .. ": " .. UI.trunc(txt, 14))
        else
          local at = tr.sel
          insert_at_selection(v, word_codes(w), w, word_gap())
          flash_msg(w .. " -> " .. VNAME[v] .. at)
        end
      end
    elseif page == P_TALK then
      if n == 2 then
        if shift then
          local p = phrases[phrase_sel]
          if p then
            local items = {}
            for w in p.text:gmatch("[%a']+") do items[#items + 1] = {codes = word_codes(w:lower()), label = w:lower()} end
            local start = tr.sel
            local len = Seq.len(v)
            local i = start
            for _, it in ipairs(items) do
              Seq.write(v, i, it.codes, it.label, false, cur_note[v])
              i = (i - 1 + word_gap()) % len + 1
            end
            select_step(v, i)
            flash_msg(#items .. " parole -> " .. VNAME[v] .. start)
          end
        else
          play_codes(v, phrase_codes(phrase_sel), phrases[phrase_sel] and phrases[phrase_sel].text)
        end
      elseif n == 3 then
        if shift then
          if phrases[phrase_sel] then
            insert_at_selection(v, phrase_codes(phrase_sel), phrases[phrase_sel].text)
            flash_msg("frase -> step")
          end
        else
          local cur = phrases[phrase_sel] and phrases[phrase_sel].text or ""
          textentry.enter(function(txt)
            if txt and #txt > 0 then
              phrases[phrase_sel] = {text = txt}
              phrase_codes(phrase_sel)
            end
            dirty = true
          end, cur, "frase " .. phrase_sel .. " (inglese)")
        end
      end
    elseif page == P_VOICE then
      if n == 3 then sel_voice = 3 - sel_voice
      elseif n == 2 then play_codes(v, last_codes[v], last_label[v]) end
    elseif page == P_FX then
      if n == 3 then
        local cur = FX_LIST[fx_sel].sec
        local i = fx_sel
        repeat i = i % #FX_LIST + 1 until FX_LIST[i].sec ~= cur
        fx_sel = i
      elseif n == 2 then
        for vv = 1, 2 do J.throw(vv, 7, clock.get_beat_sec() * 2) end
        flash_msg("throw!")
      end
    end
  end
  grid_dirty = true
  dirty = true
end

-------------------------------------------------------------------------------
-- disegno
-------------------------------------------------------------------------------
local function draw_message()
  if message and util.time() - message_time < 1.2 then
    screen.level(0)
    screen.rect(0, 54, 128, 10)
    screen.fill()
    screen.level(15)
    screen.rect(0.5, 54.5, 127, 9)
    screen.stroke()
    screen.move(64, 62)
    screen.text_center(UI.trunc(message, 30))
  end
end

local function step_label(st, n)
  if not st then return "--" end
  return UI.trunc(st.label or MSA.codes_to_string(st.codes), n)
end

local function draw_play()
  local v = sel_voice
  local s = SOUNDS[sound_idx]
  UI.mouth(26, 28, 44, 18, anim[v], 15)
  UI.mouth(120, 15, 12, 4, anim[3 - v], 5)
  screen.level(3)
  screen.move(0, 18)
  screen.text(VNAME[v])
  -- info
  screen.level(15)
  screen.font_size(16)
  screen.move(56, 27)
  screen.text(s.name)
  screen.font_size(8)
  screen.level(6)
  screen.move(56, 36)
  if s.def and not s.def.sfx then
    screen.text(UI.trunc(s.def.words, 14))
    screen.level(3)
    screen.move(56, 44)
    screen.text(UI.trunc(s.def.kind, 14))
  elseif s.def then
    screen.text(S.GROUP_NAMES[s.def.group])
  else
    screen.text(s.pause.desc)
  end
  -- oscilloscopio
  screen.level(1)
  screen.rect(0, 47, 100, 17)
  screen.fill()
  UI.scope(0, 55, 100, 7, anim[v], voices[v].regs, voices[v].hz, 13)
  screen.level(10)
  screen.move(128, 54)
  screen.text_right(note_name(cur_note[v]))
  screen.level(3)
  screen.move(128, 62)
  screen.text_right(sound_idx .. "/" .. #SOUNDS)
end

-- panoramica compatta di una traccia
local function draw_mini_lane(t, y0, focus)
  local tr = Seq.tracks[t]
  local len = Seq.len(t)
  local base = (view_page[t] - 1) * 16
  screen.level(focus and 15 or 3)
  screen.move(0, y0 + 5)
  screen.text(VNAME[t])
  for x = 1, 16 do
    local i = base + x
    local cx = 9 + (x - 1) * 7
    if i <= len then
      local st = tr.steps[i]
      local l = st and (focus and 8 or 4) or 1
      if Seq.playing and i == tr.pos then l = 15 end
      screen.level(l)
      screen.rect(cx, y0, 6, 5)
      screen.fill()
    end
  end
  local pages = math.max(1, math.ceil(len / 16))
  screen.level(focus and 6 or 2)
  screen.move(128, y0 + 5)
  screen.text_right(view_page[t] .. "/" .. pages)
end

local function draw_seq()
  local v = sel_voice
  local tr = Seq.tracks[v]
  local len = Seq.len(v)
  draw_mini_lane(1, 12, v == 1)
  draw_mini_lane(2, 19, v == 2)
  -- tab delle corsie
  for k = 1, #LANES do
    local x = (k - 1) * 18 + 1
    local sel = (k == lane)
    if sel then
      screen.level(12)
      screen.rect(x, 26, 17, 8)
      screen.fill()
      screen.level(0)
    else
      screen.level(4)
    end
    screen.move(x + 9, 32)
    screen.text_center(LANE_SHORT[k])
  end
  -- vista della corsia
  local base = (view_page[v] - 1) * 16
  local y0, h = 36, 18
  for x = 1, 16 do
    local i = base + x
    local cx = 9 + (x - 1) * 7
    local st = tr.steps[i]
    if i <= len then
      screen.level(1)
      screen.rect(cx, y0, 6, h)
      screen.fill()
      if st then
        local lvl = (i == tr.sel) and 15 or 7
        screen.level(lvl)
        if lane == 1 then
          local ny = y0 + h - 1 - util.clamp(math.floor((st.note + 13) / 53 * (h - 3)), 0, h - 3)
          screen.rect(cx, ny - 1, 6, 3)
          screen.fill()
        elseif lane == 2 or lane == 3 then
          local isw = st.label ~= nil
          screen.rect(cx + 1, y0 + h - (isw and 12 or 6), 4, isw and 12 or 6)
          screen.fill()
        elseif lane == 4 then
          local gl = st.gate or 0
          if gl == 0 then
            screen.rect(cx, y0 + h - 3, 3, 3)
          else
            screen.rect(cx, y0 + h - 3, math.min(gl * 7 - 1, (16 - x) * 7 + 6), 3)
          end
          screen.fill()
        elseif lane == 5 then
          local lv = (st.level or params:get("vol_" .. v)) / 127
          local bh = math.max(1, math.floor(lv * h))
          screen.rect(cx, y0 + h - bh, 6, bh)
          screen.fill()
        elseif lane == 6 then
          local bh = math.max(1, math.floor(st.prob / 100 * h))
          screen.rect(cx, y0 + h - bh, 6, bh)
          screen.fill()
        else
          local id = C.list[comp_sel].id
          local cnt = Seq.comp_count(st)
          for k = 1, math.min(cnt, 5) do
            screen.rect(cx + 1, y0 + h - k * 3, 4, 2)
          end
          screen.fill()
          if st.comps[id] then
            screen.level(15)
            screen.rect(cx, y0, 6, 2)
            screen.fill()
          end
        end
      end
      if sel_set[v][i] then
        screen.level(10)
        screen.rect(cx, y0 - 2, 6, 1)
        screen.fill()
      end
      if i == tr.sel then
        screen.level(15)
        screen.rect(cx - 0.5, y0 - 0.5, 7, h + 1)
        screen.stroke()
      end
      if Seq.playing and i == tr.pos then
        screen.level(15)
        screen.rect(cx, y0 + h + 1, 6, 1)
        screen.fill()
      end
    end
  end
  -- riga info
  local st = tr.steps[tr.sel]
  screen.level(15)
  screen.move(0, 63)
  screen.text(string.format("%s%02d", VNAME[v], tr.sel))
  screen.move(22, 63)
  local txt
  if lane == 1 then txt = st and ("nota " .. note_name(st.note)) or ("E3: crea nota " .. note_name(cur_note[v]))
  elseif lane == 2 then txt = st and step_label(st, 18) or "E3: scegli suono"
  elseif lane == 3 then txt = st and st.label and UI.trunc(st.label, 14) or ("E3: " .. UI.trunc(V.all[word_idx].word, 14))
  elseif lane == 4 then txt = st and ("gate " .. ((st.gate == 0) and "naturale" or (st.gate .. " step"))) or "--"
  elseif lane == 5 then txt = st and ("volume " .. (st.level or params:get("vol_" .. v))) or "--"
  elseif lane == 6 then txt = st and ("prob " .. st.prob .. "%") or "--"
  else
    local c = C.list[comp_sel]
    local cv = st and st.comps[c.id]
    txt = c.short .. " " .. (cv and c.vals[cv] or "off") .. "  K1+E3 >"
  end
  screen.level(st and 12 or 5)
  screen.text(UI.trunc(txt, 21))
end

local function draw_step()
  local v = sel_voice
  local tr = Seq.tracks[v]
  local st = tr.steps[tr.sel]
  local nsel = 0
  for _ in pairs(sel_set[v]) do nsel = nsel + 1 end
  screen.level(15)
  screen.move(0, 18)
  screen.text(string.format("%s%02d", VNAME[v], tr.sel))
  if nsel > 1 then
    screen.level(8)
    screen.text(" x" .. nsel)
  end
  local vals = {
    step_label(st, 9),
    st and note_name(st.note) or "-",
    st and tostring(st.level or params:get("vol_" .. v)) or "-",
    st and ((st.gate == 0) and "nat" or (st.gate .. " st")) or "-",
    st and (st.prob .. "%") or "-",
  }
  for k = 1, #STEP_FIELDS do
    local y = 26 + (k - 1) * 8
    local sel = (step_field == k)
    screen.level(sel and 15 or 4)
    screen.move(0, y)
    screen.text(STEP_FIELDS[k])
    screen.move(62, y)
    screen.text_right(vals[k])
  end
  for k, c in ipairs(C.list) do
    local cx = 66 + ((k - 1) % 4) * 15
    local cy = 12 + math.floor((k - 1) / 4) * 10
    local active = st and st.comps[c.id]
    local focused = (step_field == #STEP_FIELDS + k)
    local lvl = active and (focused and 15 or 9) or (focused and 8 or 2)
    UI.chip(cx, cy, 14, 9, c.short:sub(1, 3), lvl, active)
    if focused and not active then
      screen.level(15)
      screen.rect(cx + 0.5, cy + 0.5, 13, 8)
      screen.stroke()
    end
  end
  if step_field > #STEP_FIELDS then
    local c = C.list[step_field - #STEP_FIELDS]
    local cv = st and st.comps[c.id]
    screen.level(15)
    screen.move(66, 62)
    screen.text(UI.trunc(c.name, 8) .. " ")
    screen.level(cv and 15 or 4)
    screen.text(cv and c.vals[cv] or "off")
  end
end

local function draw_list(items, sel, x, y0, w, valfn, rows)
  rows = rows or 5
  local half = math.floor(rows / 2)
  local first = util.clamp(sel - half, 1, math.max(1, #items - rows + 1))
  for k = 0, rows - 1 do
    local i = first + k
    if items[i] then
      local y = y0 + k * 9
      local s = (i == sel)
      if s then
        screen.level(2)
        screen.rect(x, y - 7, w, 9)
        screen.fill()
      end
      screen.level(s and 15 or 5)
      screen.move(x + 1, y)
      screen.text(items[i].name)
      if valfn then
        screen.move(x + w - 1, y)
        screen.text_right(valfn(items[i]))
      end
    end
  end
  -- scrollbar
  if #items > rows then
    local bh = math.max(3, math.floor(rows / #items * 45))
    local by = 12 + math.floor((sel - 1) / math.max(1, #items - 1) * (45 - bh))
    screen.level(4)
    screen.rect(x + w + 1, by, 1, bh)
    screen.fill()
  end
end

local function draw_track()
  local v = sel_voice
  draw_list(TRACK_FIELDS, track_field, 0, 19, 98, function(f)
    return params:string(f.global and f.id or (f.id .. "_" .. v))
  end)
  screen.level(15)
  screen.move(128, 19)
  screen.text_right(VNAME[v])
  local tr = Seq.tracks[v]
  local len = Seq.len(v)
  for i = 1, 64 do
    local cx = 104 + ((i - 1) % 8) * 3
    local cy = 24 + math.floor((i - 1) / 8) * 3
    local l = 0
    if i <= len then l = tr.steps[i] and 8 or 2 end
    if Seq.playing and i == tr.pos then l = 15 end
    if l > 0 then
      screen.level(l)
      screen.rect(cx, cy, 2, 2)
      screen.fill()
    end
  end
end

-- fila delle parole gia' nella traccia (la "frase" costruita)
local function track_phrase(t, maxc)
  local tr = Seq.tracks[t]
  local words = {}
  for i = 1, Seq.len(t) do
    local st = tr.steps[i]
    if st and st.label then words[#words + 1] = st.label end
  end
  return UI.trunc(table.concat(words, " "), maxc)
end

local function draw_words()
  local w = current_word()
  if wmode == 1 then
    local e = V.all[word_idx]
    for k = 1, 26 do
      local l = string.char(64 + k)
      screen.level(l == e.letter and 15 or (V.first[l] and 3 or 1))
      screen.move(1 + (k - 1) * 4.9, 17)
      screen.text(l)
    end
    for k = -2, 2 do
      local it = V.all[word_idx + k]
      if it and k ~= 0 then
        screen.level((math.abs(k) == 1) and 6 or 2)
        screen.move(82, 33 + k * 7)
        screen.text(UI.trunc(it.word, 9))
      end
    end
    screen.level(3)
    screen.move(0, 52)
    local li = word_idx - V.first[e.letter] + 1
    screen.text(e.letter .. " " .. li .. "/" .. #V.by_letter[e.letter] .. "  tot " .. V.count)
  else
    local th = V.themes[theme_sel]
    screen.level(15)
    screen.move(0, 17)
    screen.text("< " .. th.name .. " >")
    screen.level(3)
    screen.move(128, 17)
    screen.text_right(theme_sel .. "/" .. #V.themes)
    for k = -2, 2 do
      local it = th.words[theme_idx + k]
      if it and k ~= 0 then
        screen.level((math.abs(k) == 1) and 6 or 2)
        screen.move(82, 33 + k * 7)
        screen.text(UI.trunc(it, 9))
      end
    end
    screen.level(3)
    screen.move(0, 52)
    screen.text("tema " .. theme_idx .. "/" .. #th.words)
  end
  screen.level(15)
  screen.font_size(16)
  screen.move(0, 37)
  screen.text(UI.trunc(w, 10))
  screen.font_size(8)
  screen.level(5)
  screen.move(0, 45)
  screen.text(UI.trunc(MSA.codes_to_string(word_codes(w)), 20))
  -- frase in costruzione
  screen.level(2)
  screen.rect(0, 55, 128, 9)
  screen.fill()
  screen.level(12)
  screen.move(1, 62)
  screen.text(VNAME[sel_voice] .. string.format("%02d", Seq.tracks[sel_voice].sel) .. " ")
  screen.level(7)
  screen.text(track_phrase(sel_voice, 25))
end

local function draw_talk()
  local items = {}
  for i = 1, NPHRASES do
    items[i] = {name = string.format("%2d %s", i, UI.trunc(phrases[i] and phrases[i].text or "-", 22))}
  end
  draw_list(items, phrase_sel, 0, 19, 125, nil, 4)
  screen.level(5)
  screen.move(0, 61)
  local cs = phrases[phrase_sel] and MSA.codes_to_string(phrase_codes(phrase_sel)) or ""
  screen.text(UI.trunc(cs, 31))
end

local function draw_voice()
  local v = sel_voice
  local items = {}
  for _, id in ipairs(VOICE_PARAMS) do
    items[#items + 1] = {name = params:lookup_param(id .. "_" .. v).name, id = id .. "_" .. v}
  end
  draw_list(items, voice_param_sel, 0, 19, 76, function(it) return params:string(it.id) end)
  screen.level(15)
  screen.move(128, 18)
  screen.text_right(VNAME[v])
  UI.mouth(105, 30, 26, 9, anim[v], 12)
  UI.formant_curve(80, 43, 47, 18, voices[v].regs, voices[v]:bend_scale(), 9)
end

local function draw_fx()
  local items = {}
  for _, f in ipairs(FX_LIST) do
    items[#items + 1] = {name = params:lookup_param(f.id).name, id = f.id}
  end
  draw_list(items, fx_sel, 0, 19, 125, function(it) return params:string(it.id) end)
  screen.level(4)
  screen.move(0, 63)
  screen.text(FX_LIST[fx_sel].sec)
  screen.move(128, 63)
  screen.text_right("K2 throw K1K2 stut")
end

function redraw()
  screen.clear()
  screen.font_face(1)
  screen.font_size(8)
  if splash_until > 0 and util.time() < splash_until then
    UI.splash(util.time() - splash_t0, anim[1])
    screen.update()
    return
  end
  UI.header(PAGES, page, clock.get_tempo(), Seq.playing, beat_flash)
  if page == P_PLAY then draw_play()
  elseif page == P_SEQ then draw_seq()
  elseif page == P_STEP then draw_step()
  elseif page == P_TRACK then draw_track()
  elseif page == P_WORDS then draw_words()
  elseif page == P_TALK then draw_talk()
  elseif page == P_VOICE then draw_voice()
  elseif page == P_FX then draw_fx() end
  if shift then
    screen.level(15)
    screen.rect(0, 0, 2, 2)
    screen.fill()
  end
  draw_message()
  screen.update()
end

-------------------------------------------------------------------------------
-- tremolo (Flame): gate audio sincronizzato
-------------------------------------------------------------------------------
local function trem_loop(t)
  local state = true
  while true do
    local d = params:get("trem_div_" .. t) == 1 and 1 / 4 or 1 / 8
    clock.sync(d)
    state = not state
    local on = state
    if params:get("trem_phase") == 2 and t == 2 then on = not on end
    if Seq.playing and params:get("trem_" .. t) == 2 then
      engine.param(t, "trem", on and 1 or 0)
    else
      engine.param(t, "trem", 1)
    end
  end
end

-------------------------------------------------------------------------------
-- init
-------------------------------------------------------------------------------
function init()
  Seq.init(J)
  for v = 1, 2 do
    voices[v] = MSA.new(v, eng)
    voices[v].on_event = on_voice_event
  end
  -- 64 slot frasi: preset + frasi pronte del vocabolario
  local seen = {}
  local n = 0
  local function addp(txt)
    if n < NPHRASES and not seen[txt] then
      n = n + 1
      seen[txt] = true
      phrases[n] = {text = txt}
    end
  end
  for _, txt in ipairs(PRESETS) do addp(txt) end
  for _, txt in ipairs(V.phrases or {}) do addp(txt) end

  setup_params()
  build_scale()
  params:bang()
  update_delay()
  clock.tempo_change_handler = function() update_delay() end

  -- pattern dimostrativo: una frase con note, nota lunga e componenti
  local demo = {
    {1, "hello", 5}, {5, "i", 3}, {7, "am", 4}, {9, "a", 5}, {11, "talking", 7}, {14, "robot", 5},
  }
  for _, d in ipairs(demo) do
    Seq.write(1, d[1], word_codes(d[2]), d[2], false, d[3])
  end
  Seq.tracks[1].steps[11].gate = 2
  Seq.tracks[1].steps[14].comps.bend = 1
  Seq.tracks[1].steps[14].comps.thrw = 2

  for t = 1, 2 do
    clock.run(Seq.loop, t)
    clock.run(trem_loop, t)
  end

  -- babble continuo opzionale
  clock.run(function()
    local count = 0
    while true do
      clock.sync(1 / 4)
      if Seq.playing and params:get("babble_auto") == 2 then
        count = count + 1
        if count >= params:get("babble_rate") then
          count = 0
          Seq.babble(math.random(1, 2))
        end
      end
    end
  end)

  -- refresh schermo / grid / animazione
  clock.run(function()
    while true do
      clock.sleep(1 / 20)
      local moving = false
      for v = 1, 2 do
        if UI.update_anim(anim[v], voices[v].regs) then moving = true end
      end
      if splash_until > 0 then
        if util.time() >= splash_until then splash_until = 0 end
        dirty = true
      end
      if moving and (page == P_PLAY or page == P_VOICE) then dirty = true end
      if message and util.time() - message_time > 1.25 then message = nil; dirty = true end
      if dirty then redraw(); dirty = false end
      if grid_dirty then grid_redraw(); grid_dirty = false end
    end
  end)

  -- splash + "ready"
  splash_t0 = util.time()
  splash_until = splash_t0 + 2.2
  clock.run(function()
    clock.sleep(0.4)
    play_codes(1, word_codes("ready"), "ready")
  end)
end

-- accesso da maiden:
--   jv_say(1, {21,60, 22,120, 14,128, 1, 200})   -- codici SpeakJet grezzi
--   jv_text(2, "hello world")                    -- testo inglese
function jv_say(v, codes) play_codes(util.clamp(v, 1, 2), codes) end
function jv_text(v, txt) play_codes(util.clamp(v, 1, 2), TTS.text_to_codes(txt), txt) end

function cleanup()
  Seq.stop()
  for v = 1, 2 do if voices[v] then voices[v]:stop() end end
  if engine.fx then engine.fx("stut", 0) end
  if audio and audio.rev_on then audio.rev_on() end
end
