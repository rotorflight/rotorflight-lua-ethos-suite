-- Configuration -> Flight Tuning -> Tune Advisor page.
--
-- Turns the FC's in-flight rate-loop statistics (lib/msp_tune_advisor.lua,
-- rotorflight-firmware flight/tune_advisor.c) into concrete changes, one axis
-- at a time: what was measured, which setting to change (named by the page
-- it lives on, in the units that page shows), and why. The firmware only
-- measures; the rules below are the advice, kept here so they can change
-- without a flash. Ported from the Wingflight suite.
--
-- The statistics come from the saved flights, not from the FC:
-- tasks/tune_history.lua saves each flight on disarm and clears the FC, and
-- this page combines the last few flights flown on the current tune
-- (lib/tune_history.lua). The aircraft is the session's mcuId. The FC is
-- asked once, on open and on Reload, only to learn whether its firmware has
-- the tune advisor at all.
--
-- Rules, per axis:
-- - Feed-forward match (gyro / setpoint at the best delay), judged only
--   when the ratio is consistent. Above FF_HOT the heli outruns the stick:
--   lower F and scale the rate curve up by the same factor, which keeps the
--   stick feel. Below FF_LOW, the reverse. One step is capped at
--   FF_STEP_MAX so the pilot flies and re-checks rather than jumping. The
--   curve can only be scaled exactly for Actual, Quick and Rotorflight
--   rates; for the others the page gives a percentage. An axis with F = 0
--   (often the tail) gets no F advice: its PID gains set the response.
-- - Full stick (roll and pitch): cyclic saturated and the rate reached well
--   below the rate asked, so the rate is suggested at what the heli reaches.
-- - |Collective| spread is shown as a fact, last, when there is room.
-- - Stick releases: the rebound after a stop. I-term pushing back points at
--   a lower Iterm Relax Cutoff; with F still off, F comes first; otherwise
--   the controller is barely braking, so more P (or B).
--
-- Clear (header Tool button) erases the saved flights and resets the FC's
-- statistics.
--
-- Apply (header Save button) writes the shown axis's changes to the FC. It
-- reads PID tuning, PID profile and rates, checks each reply is long enough
-- to hold every field and that the FC still holds the tune the flights were
-- flown on (the same profiles, and P, F, B, Iterm Relax Cutoff, rates type
-- and rates as the newest flight), changes only the advised fields, writes,
-- commits to EEPROM and reads back to confirm. Anything unexpected stops it
-- before the write. The progress dialog names each stage. A rate change the
-- page can only give as a percentage (Betaflight, Raceflight, KISS rates)
-- is not applied, and neither is the F change that goes with it: F alone
-- would change the stick feel. The saved flights are kept: the next flight
-- is on a new tune, so tune_history.aggregate() starts again from it, and the
-- firmware resets its statistics when it arms on a changed tune. changes.csv
-- beside the history records each value replaced.
--
-- The header and Axis selector are form fields; everything below them is
-- painted (see open()), like app/pages/logs.lua's graph view. Narrow screens
-- (480 wide: X18, X10) cannot always fit every reason, so a Changes/Why
-- selector beside Axis switches to a view of the reasons alone.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local tuneAdvisor = requireModule("lib/msp_tune_advisor.lua")
local tuneHistory = requireModule("lib/tune_history.lua")
local rateCurveScale = requireModule("lib/rate_curve_scale.lua")
local progressDialog = requireModule("app/progress_dialog.lua")
local pidTuning = requireModule("lib/msp_pid_tuning.lua")
local pidProfile = requireModule("lib/msp_pid_profile.lua")
local rcTuning = requireModule("lib/msp_rc_tuning.lua")
local eeprom = requireModule("lib/msp_eeprom.lua")

local PAGE_TITLE = "@i18n(app.modules.tune_advisor.name)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"

local T = {
  axis = "@i18n(app.modules.tune_advisor.axis)@",
  data = "@i18n(app.modules.tune_advisor.data)@",
  dataFlightsFmt = "@i18n(app.modules.tune_advisor.data_flights_fmt)@",
  noAircraft = "@i18n(app.modules.tune_advisor.no_aircraft)@",
  unsupported = "@i18n(app.modules.tune_advisor.unsupported)@",
  clearPrompt = "@i18n(app.modules.tune_advisor.clear_prompt)@",
  response = "@i18n(app.modules.tune_advisor.response)@",
  stops = "@i18n(app.modules.tune_advisor.stops)@",
  changes = "@i18n(app.modules.tune_advisor.changes)@",
  changesShort = "@i18n(app.modules.tune_advisor.changes_short)@",
  moreWhy = "@i18n(app.modules.tune_advisor.more_why)@",
  why = "@i18n(app.modules.tune_advisor.why)@",

  respMoreFmt = "@i18n(app.modules.tune_advisor.resp_more_fmt)@",
  respUneven = "@i18n(app.modules.tune_advisor.resp_uneven)@",
  respFastFmt = "@i18n(app.modules.tune_advisor.resp_fast_fmt)@",
  respSlowFmt = "@i18n(app.modules.tune_advisor.resp_slow_fmt)@",
  respOk = "@i18n(app.modules.tune_advisor.resp_ok)@",
  stopsMoreFmt = "@i18n(app.modules.tune_advisor.stops_more_fmt)@",
  stopsValueFmt = "@i18n(app.modules.tune_advisor.stops_value_fmt)@",

  actFlyRoll = "@i18n(app.modules.tune_advisor.act_fly_roll)@",
  actFlyPitch = "@i18n(app.modules.tune_advisor.act_fly_pitch)@",
  actFlyYaw = "@i18n(app.modules.tune_advisor.act_fly_yaw)@",
  actFFmt = "@i18n(app.modules.tune_advisor.act_f_fmt)@",
  actRateFmt = "@i18n(app.modules.tune_advisor.act_rate_fmt)@",
  actRatePctUpFmt = "@i18n(app.modules.tune_advisor.act_rate_pct_up_fmt)@",
  actRatePctDownFmt = "@i18n(app.modules.tune_advisor.act_rate_pct_down_fmt)@",
  actRelaxFmt = "@i18n(app.modules.tune_advisor.act_relax_fmt)@",
  actPFmt = "@i18n(app.modules.tune_advisor.act_p_fmt)@",
  actNone = "@i18n(app.modules.tune_advisor.act_none)@",
  rcRate = "@i18n(app.modules.rates.rc_rate)@",
  rate = "@i18n(app.modules.rates.rate)@",

  whyMore = "@i18n(app.modules.tune_advisor.why_more)@",
  whyUneven = "@i18n(app.modules.tune_advisor.why_uneven)@",
  whyFast = "@i18n(app.modules.tune_advisor.why_fast)@",
  whySlow = "@i18n(app.modules.tune_advisor.why_slow)@",
  whyKeepFeel = "@i18n(app.modules.tune_advisor.why_keep_feel)@",
  whyNoF = "@i18n(app.modules.tune_advisor.why_no_f)@",
  whyFullFmt = "@i18n(app.modules.tune_advisor.why_full_fmt)@",
  whyCollHighFmt = "@i18n(app.modules.tune_advisor.why_coll_high_fmt)@",
  whyCollLowFmt = "@i18n(app.modules.tune_advisor.why_coll_low_fmt)@",
  whyRelax = "@i18n(app.modules.tune_advisor.why_relax)@",
  whyFixFFmt = "@i18n(app.modules.tune_advisor.why_fix_f_fmt)@",
  whyBrakeFmt = "@i18n(app.modules.tune_advisor.why_brake_fmt)@",
  whyOk = "@i18n(app.modules.tune_advisor.why_ok)@",

  applyHint = "@i18n(app.modules.tune_advisor.apply_hint)@",
  applyPrompt = "@i18n(app.modules.tune_advisor.apply_prompt)@",
  applied = "@i18n(app.modules.tune_advisor.applied)@",
  stageRead = "@i18n(app.modules.tune_advisor.stage_read)@",
  stageWrite = "@i18n(app.modules.tune_advisor.stage_write)@",
  stageSave = "@i18n(app.modules.tune_advisor.stage_save)@",
  stageVerify = "@i18n(app.modules.tune_advisor.stage_verify)@",
  errRead = "@i18n(app.modules.tune_advisor.err_read)@",
  errChanged = "@i18n(app.modules.tune_advisor.err_changed)@",
  errArmed = "@i18n(app.modules.tune_advisor.err_armed)@",
  errWrite = "@i18n(app.modules.tune_advisor.err_write)@",
  errSave = "@i18n(app.modules.tune_advisor.err_save)@",
  errVerify = "@i18n(app.modules.tune_advisor.err_verify)@",
}

-- {label, axis}: axis is the FC's 1-based axis (1 roll, 2 pitch, 3 yaw)
local AXES = {
  {"@i18n(app.modules.tune_advisor.roll)@", 1},
  {"@i18n(app.modules.tune_advisor.pitch)@", 2},
  {"@i18n(app.modules.tune_advisor.yaw)@", 3},
}
local AXIS_ROLL, AXIS_PITCH, AXIS_YAW = 1, 2, 3

-- Feed-forward match
local FF_MIN_COUNT = 1000       -- 10 s of usable 40-200 deg/s stick
local FF_MIN_CORR = 0.85
local FF_HOT = 1.15
local FF_LOW = 0.85
local FF_STEP_MAX = 0.2         -- change F by at most 20% per step
local GAIN_MAX = 1000           -- firmware PID_GAIN_MAX, the limit for P and F alike
local RATE_RAW_MAX = 255

-- Which rate columns scale the whole curve linearly, per rates_type. The
-- others (Betaflight, Raceflight, KISS) get a percentage instead.
local R = rateCurveScale
local LINEAR_ROLES = {
  [R.RATE_TYPE_ACTUAL] = {"rcRate", "srate"},       -- center sensitivity, max rate
  [R.RATE_TYPE_QUICK] = {"rcRate", "srate"},        -- rc rate, max rate
  [R.RATE_TYPE_ROTORFLIGHT] = {"rcRate"},           -- rate (srate is the shape)
}
-- Max rate asked at full stick (deg/s) from the raw bytes, where the type
-- makes it direct: the firmware's rate curves (fc/rc_rates.c) at full stick.
-- Actual and Quick reach the larger of their two terms.
local function maxRateAsked(a)
  if a.ratesType == R.RATE_TYPE_ACTUAL then return math.max(a.rcRate, a.sRate) * 10 end
  if a.ratesType == R.RATE_TYPE_QUICK then return math.max(a.sRate * 10, a.rcRate * 2) end
  if a.ratesType == R.RATE_TYPE_ROTORFLIGHT then return a.rcRate * 5 end
  return nil
end

-- Collective fact
local BAND_MIN_COUNT = 300
local COLL_SPREAD = 1.25

-- Full stick
local FULL_MIN_COUNT = 100
local FULL_SAT_SHARE = 0.5
local FULL_REACH = 0.8

-- Stick releases
local STOPS_MIN = 10
local REBOUND_BAD = 0.12
local ITERM_PUSH = 0.03         -- I at release, output units
local P_STEP = 1.2
local CUTOFF_STEP = 0.8         -- lower Iterm Relax Cutoff = more relax, less bounce-back
local CUTOFF_MIN = 1

local MAX_ACTIONS = 3
local MAX_WHYS = 3

-- Apply: the FC messages holding the tune, read and written in this order
local SOURCES = {
  {key = "tuning", codec = pidTuning},
  {key = "profile", codec = pidProfile},
  {key = "rates", codec = rcTuning},
}
local SOURCE_BY_KEY = {}
for _, source in ipairs(SOURCES) do
  SOURCE_BY_KEY[source.key] = source
  -- Bytes a reply must hold to carry every field: the codecs read a missing
  -- byte as 0, so a short reply would decode to a plausible tune of zeros.
  -- Encoding an empty table writes every field once, at its wire width.
  source.minBytes = #source.codec.encode({})
end
local AXIS_FIELDS = {"roll", "pitch", "yaw"}
-- The simulator's MSP fixtures do not change on a write, so a read-back
-- there cannot show the new values
local IS_SIM = system.getVersion().simulation == true

-- Where a tune_history TUNE_KEYS value lives on the FC: source key, field
-- name (lib/msp_rc_tuning.lua calls the srate column rates_N)
local function fcField(key, axis)
  if key == "relaxCutoff" then return "profile", "iterm_relax_cutoff_" .. (axis - 1) end
  if key == "ratesType" then return "rates", "rates_type" end
  if key == "rcRate" then return "rates", "rcRates_" .. axis end
  if key == "sRate" then return "rates", "rates_" .. axis end
  return "tuning", AXIS_FIELDS[axis] .. "_" .. string.lower(key)
end

-- Whether value is one the FC accepts for that setting
local function inRange(key, axis, value)
  if key == "rcRate" or key == "sRate" then return value >= 1 and value <= RATE_RAW_MAX end
  local src, field = fcField(key, axis)
  local meta = SOURCE_BY_KEY[src].codec.FIELD_META[field]
  return meta ~= nil and value >= meta.min and value <= meta.max
end

local function round(v)
  return math.floor(v + 0.5)
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function ffJudged(a)
  return a.ffCount >= FF_MIN_COUNT and a.ffCorr >= FF_MIN_CORR
end

local function ffOff(a)
  return ffJudged(a) and (a.ffGain > FF_HOT or a.ffGain < FF_LOW)
end

-- A raw rate byte as the Rates page shows it for this rates_type
local function rateText(raw, rateType, role)
  local scale = R.scaleFor(rateType, role, "main") or 1
  local decimals = R.decimalsFor(rateType, role, "main") or 0
  return string.format("%." .. decimals .. "f", raw * scale / 100)
end

-- Suggests scaling the rate curve by k (e.g. 1.25 = 25% faster everywhere).
-- change(text, key, from, to) adds a line Apply can write; a percentage
-- (no linear column for this rates_type) is only shown.
local function rateActions(a, name, k, act, change)
  local roles = LINEAR_ROLES[a.ratesType]
  if not roles then
    local pct = round(math.abs(k - 1) * 100)
    act(string.format(k > 1 and T.actRatePctUpFmt or T.actRatePctDownFmt, name, pct))
    return
  end
  for _, role in ipairs(roles) do
    local raw = (role == "rcRate") and a.rcRate or a.sRate
    local newRaw = clamp(round(raw * k), 1, RATE_RAW_MAX)
    change(string.format(T.actRateFmt, name, (role == "rcRate") and T.rcRate or T.rate,
      rateText(raw, a.ratesType, role), rateText(newRaw, a.ratesType, role)),
      (role == "rcRate") and "rcRate" or "sRate", raw, newRaw)
  end
end

-- How many lines rateActions() adds for this rates_type
local function rateActionCount(a)
  local roles = LINEAR_ROLES[a.ratesType]
  return roles and #roles or 1
end

-- Fills actions/whys/changes (cleared by the caller) for one axis; returns
-- the Response and Stops values. changes holds what Apply writes, one
-- {key, from, to, text} per setting action: key is a tune_history TUNE_KEYS
-- name, text the action line.
--
-- A change and its reason go in together or not at all, so a reason never
-- shows for a change that was left out: a later change first checks room().
-- The first change (fly more, F with its rates, or full-stick rates) always
-- fits. The reasons for changes stay within MAX_WHYS; only the closing
-- |collective| fact can be cut.
local function advise(a, axis, name, actions, whys, changes)
  local function room(n) return #actions + n <= MAX_ACTIONS end
  local function act(s) if #actions < MAX_ACTIONS then actions[#actions + 1] = s end end
  local function why(s) if #whys < MAX_WHYS then whys[#whys + 1] = s end end
  -- A setting action: callers check room() first, so it is never dropped
  local function change(text, key, from, to)
    act(text)
    if from ~= to then changes[#changes + 1] = {key = key, from = from, to = to, text = text} end
  end

  -- Response: feed-forward match
  local response
  if a.ffCount < FF_MIN_COUNT then
    response = string.format(T.respMoreFmt, math.floor(100 * a.ffCount / FF_MIN_COUNT))
    act(axis == AXIS_ROLL and T.actFlyRoll or axis == AXIS_PITCH and T.actFlyPitch or T.actFlyYaw)
    why(T.whyMore)
  elseif a.ffCorr < FF_MIN_CORR then
    response = T.respUneven
    why(T.whyUneven)
  elseif ffOff(a) then
    local g = a.ffGain
    local hot = g > FF_HOT
    response = string.format(hot and T.respFastFmt or T.respSlowFmt, round(math.abs(g - 1) * 100))
    if a.F > 0 then
      local newF = clamp(round(a.F * clamp(1 / g, 1 - FF_STEP_MAX, 1 + FF_STEP_MAX)), 1, GAIN_MAX)
      -- Keep the stick feel: F x rate is what the pilot feels. F is applied
      -- only with its rates, so a percentage-only rates_type applies neither.
      local text = string.format(T.actFFmt, name, a.F, newF)
      if LINEAR_ROLES[a.ratesType] then change(text, "F", a.F, newF) else act(text) end
      rateActions(a, name, a.F / newF, act, change)
      why(hot and T.whyFast or T.whySlow)
      why(T.whyKeepFeel)
    else
      why(T.whyNoF)
    end
  else
    response = T.respOk
    local asked = maxRateAsked(a)
    if axis ~= AXIS_YAW and asked and a.fullCount >= FULL_MIN_COUNT
        and a.fullSatCount >= FULL_SAT_SHARE * a.fullCount
        and a.fullMaxRate < FULL_REACH * asked and room(rateActionCount(a)) then
      rateActions(a, name, a.fullMaxRate / asked, act, change)
      why(string.format(T.whyFullFmt, asked, a.fullMaxRate))
    end
  end

  -- Stops: rebound after a release
  local stops
  if a.releases < STOPS_MIN then
    stops = string.format(T.stopsMoreFmt, a.releases, STOPS_MIN)
  else
    local rebound = round(a.meanRebound * 100)
    stops = string.format(T.stopsValueFmt, rebound)
    if a.meanRebound >= REBOUND_BAD then
      -- No room for the cutoff only after F and two rate lines; F is off
      -- then, so the next branch says to fix F first.
      if a.meanIterm >= ITERM_PUSH and a.relaxCutoff > CUTOFF_MIN and room(1) then
        local newCutoff = clamp(round(a.relaxCutoff * CUTOFF_STEP), CUTOFF_MIN, a.relaxCutoff - 1)
        change(string.format(T.actRelaxFmt, name, a.relaxCutoff, newCutoff), "relaxCutoff", a.relaxCutoff, newCutoff)
        why(T.whyRelax)
      elseif ffOff(a) and a.F > 0 then
        why(string.format(T.whyFixFFmt, rebound))
      elseif room(1) then
        local newP = clamp(round(a.P * P_STEP), a.P + 1, GAIN_MAX)
        change(string.format(T.actPFmt, name, a.P, newP), "P", a.P, newP)
        why(string.format(T.whyBrakeFmt, rebound))
      end
    end
  end

  -- Least important last: a fact, no action
  if ffJudged(a) then
    local lo, hi = a.collBands[1], a.collBands[3]
    if lo.count >= BAND_MIN_COUNT and hi.count >= BAND_MIN_COUNT and lo.gain > 0 and hi.gain > 0 then
      local spread = math.max(lo.gain, hi.gain) / math.min(lo.gain, hi.gain)
      if spread >= COLL_SPREAD then
        why(string.format(hi.gain > lo.gain and T.whyCollHighFmt or T.whyCollLowFmt, round((spread - 1) * 100)))
      end
    end
  end

  if #actions == 0 then
    act(T.actNone)
    if #whys == 0 then why(T.whyOk) end
  end

  return response, stops
end

-- Painted layout below the form (the header and Axis selector are form
-- fields). Form lines each take a full touch-target row, which left large
-- gaps around short text lines; painting packs the text at font height.
local PAD_X = 8
local VALUE_COL = 0.42          -- value column, fraction of the width
local SECTION_GAP = 0.6         -- extra space before a heading, in line heights
local COMPACT_WIDTH = 600       -- narrower screens show one section at a time
local LINE_PAD = 4              -- pixels between lines
local LINE_PAD_COMPACT = 2
local OVERFLOW_MARK = "..."

local SECTION_CHANGES, SECTION_WHY = 1, 2

local cachedColors, cachedDark = nil, nil

-- Theme colours, rebuilt only when the radio switches light/dark
local function colors()
  local isDark = lcd.darkMode()
  if cachedColors and cachedDark == isDark then return cachedColors end
  cachedDark = isDark
  cachedColors = {
    text = isDark and lcd.RGB(235, 235, 235) or lcd.RGB(20, 20, 20),
    muted = isDark and lcd.GREY(170) or lcd.GREY(90),
    accent = isDark and lcd.RGB(255, 170, 0) or lcd.RGB(200, 90, 0),
    rule = isDark and lcd.GREY(70) or lcd.GREY(200),
  }
  return cachedColors
end

local function isContinuationByte(b)
  return b ~= nil and b >= 0x80 and b < 0xC0
end

-- Bytes of the longest leading piece of word no wider than maxW, cut on a
-- UTF-8 character boundary; at least one character
local function fitBytes(word, maxW)
  for n = #word - 1, 1, -1 do
    if not isContinuationByte(word:byte(n + 1)) and lcd.getTextSize(word:sub(1, n)) <= maxW then
      return n
    end
  end
  local n = 1                     -- not even one character fits: take one anyway
  while isContinuationByte(word:byte(n + 1)) do n = n + 1 end
  return n
end

-- Word-wrap text into lines no wider than maxW (in the current lcd.font).
-- A word too wide for a line of its own (a long token in a translation) is
-- cut into pieces that fit: drawText does not clip.
local function wrapInto(out, text, maxW)
  local line = ""
  for word in text:gmatch("%S+") do
    local candidate = (line == "") and word or (line .. " " .. word)
    if lcd.getTextSize(candidate) <= maxW then
      line = candidate
    else
      if line ~= "" then out[#out + 1] = line end
      while lcd.getTextSize(word) > maxW do
        local n = fitBytes(word, maxW)
        if n >= #word then break end
        out[#out + 1] = word:sub(1, n)
        word = word:sub(n + 1)
      end
      line = word
    end
  end
  if line ~= "" then out[#out + 1] = line end
end

local function clearList(list)
  for i = #list, 1, -1 do list[i] = nil end
end

local function open(opts)
  opts = opts or {}
  local disposed = false
  local headerHandle = nil
  local probing = false
  local unsupported = false       -- the FC refused the command: until Reload
  local mcuId = nil               -- the session's aircraft
  local flights = nil             -- lib/tune_history.lua read(), nil until loaded
  local selected = 1              -- index into AXES
  local section = SECTION_CHANGES -- compact screens only
  local actions, whys = {}, {}
  local compact = lcd.getWindowSize() < COMPACT_WIDTH
  local link = {connected = false, armed = false, pidProfile = nil, rateProfile = nil}

  -- What paint shows. layout (the wrapped lines) is rebuilt on the next
  -- paint after a change, never on a paint with nothing new. changes and
  -- tune (the tune the advice is for) are what Apply writes and checks.
  local view = {data = "-", response = "-", stops = "-", actions = {}, whys = {}, layout = nil,
    axis = nil, changes = {}, tune = {}}

  -- Apply state. applying is set from the press until the wakeup handler
  -- takes applyResult (true, or the error text) set by the MSP callbacks;
  -- applyStage is the progress dialog message, also shown from wakeup.
  local applying = nil
  local applyDialog = nil
  local applyResult = nil
  local applyStage, shownStage = nil, nil
  local applied = {}              -- by axis: written since the flights were loaded
  local saveEnabled = nil

  -- MSP replies and bus events arrive in the background task, where
  -- lcd.invalidate() does not reach this page's window: flag it and
  -- invalidate from our own wakeup (as app/pages/curves.lua and logs.lua do).
  local needsPaint = false
  local function changed()
    view.layout = nil
    needsPaint = true
  end

  local function showOnly(text)
    view.data, view.response, view.stops = text, "-", "-"
    clearList(view.actions)
    clearList(view.whys)
    clearList(view.changes)
    changed()
  end

  local function render()
    if disposed then return end
    if unsupported then showOnly(T.unsupported) return end
    if not mcuId then showOnly(T.noAircraft) return end
    if not flights then return end

    local axis = AXES[selected][2]
    local a, used, seconds = tuneHistory.aggregate(flights, axis)
    view.data = string.format(T.dataFlightsFmt, math.floor(seconds / 60), seconds % 60,
      used, tuneHistory.MAX_FLIGHTS)

    clearList(actions)
    clearList(whys)
    clearList(view.changes)
    view.response, view.stops = advise(a, axis, AXES[selected][1], actions, whys, view.changes)
    view.axis = axis
    for _, k in ipairs(tuneHistory.TUNE_KEYS) do view.tune[k] = a[k] end
    clearList(view.actions)
    clearList(view.whys)
    if applied[axis] then
      -- The advice was for the tune just replaced: nothing to do but fly
      clearList(view.changes)
      view.actions[1] = T.applied
    else
      for i = 1, #actions do view.actions[i] = actions[i] end
      for i = 1, #whys do view.whys[i] = whys[i] end
      -- After the changes, so the compact Changes view never cuts it
      if #view.changes > 0 then view.actions[#view.actions + 1] = T.applyHint end
    end
    changed()
  end

  local function load()
    flights = mcuId and tuneHistory.read(mcuId) or nil
    for k in pairs(applied) do applied[k] = nil end
    render()
  end

  -- reason true is the FC's MSP error reply, the only answer that means the
  -- firmware lacks the command. Any other reason is the link: the saved
  -- flights do not need it.
  local function onProbeData()
    probing = false
  end

  local function onProbeError(reason)
    probing = false
    if disposed or reason ~= true then return end
    unsupported = true
    render()
  end

  local function probe()
    if disposed or probing or not mcuId then return end
    probing = true
    bus.publish("msp.request", tuneAdvisor.buildReadMessage(1, onProbeData, onProbeError))
  end

  local function onSession(snapshot)
    if disposed then return end
    if snapshot then
      link.connected = snapshot.connected == true
      link.armed = snapshot.isArmed == true
      link.pidProfile, link.rateProfile = snapshot.pidProfile, snapshot.rateProfile
    end
    -- A link loss keeps the aircraft: its saved flights do not need the link
    local nextMcuId = snapshot and snapshot.mcuId or nil
    if nextMcuId == nil or nextMcuId == mcuId then return end
    mcuId = nextMcuId
    unsupported = false
    load()
    probe()
  end

  local function onSaved(savedMcuId)
    if disposed or savedMcuId ~= mcuId then return end
    load()
  end

  local function unsubscribe()
    bus.unsubscribe("session.update", onSession)
    bus.unsubscribe("tune_history.saved", onSaved)
  end

  local function clear()
    if disposed or not mcuId then return end
    tuneHistory.erase(mcuId)
    bus.publish("msp.request", tuneAdvisor.buildClearMessage(nil, nil))
    load()
  end

  -- Apply (header Save). Each step runs from the previous one's MSP reply;
  -- any failure ends it through finish(), and the wakeup handler reports.
  local function canApply()
    return not applying and not unsupported and mcuId ~= nil and link.connected
      and not link.armed and #view.changes > 0
  end

  local function finish(result)
    if disposed or not applying or applyResult ~= nil then return end
    applyResult = result
  end

  -- Reads every source into `into`; fails with errText on an error or a
  -- reply too short to hold every field
  local function readAll(index, into, errText, onDone)
    if disposed or not applying or applyResult ~= nil then return end
    local source = SOURCES[index]
    if not source then onDone() return end
    local msg = source.codec.buildReadMessage(function(data)
      into[source.key] = data
      readAll(index + 1, into, errText, onDone)
    end, function() finish(errText) end)
    local decode = msg.processReply
    msg.processReply = function(self, buf)
      if type(buf) ~= "table" or #buf < source.minBytes then finish(errText) return end
      decode(self, buf)
    end
    bus.publish("msp.request", msg)
  end

  local function verify()
    if disposed or not applying then return end
    applyStage = T.stageVerify
    local readBack = {}
    readAll(1, readBack, T.errVerify, function()
      if not IS_SIM then
        for _, c in ipairs(applying.changes) do
          local src, field = fcField(c.key, applying.axis)
          if readBack[src][field] ~= c.to then finish(T.errVerify) return end
        end
      end
      finish(true)
    end)
  end

  local function write()
    local data, axis = applying.data, applying.axis
    -- The FC must still hold the tune the advice was worked out for
    if link.armed then finish(T.errArmed) return end
    if link.pidProfile ~= applying.pidProfile or link.rateProfile ~= applying.rateProfile then
      finish(T.errChanged) return
    end
    for k, value in pairs(applying.tune) do
      local src, field = fcField(k, axis)
      if data[src][field] ~= value then finish(T.errChanged) return end
    end
    local dirty = {}
    for _, c in ipairs(applying.changes) do
      local src, field = fcField(c.key, axis)
      if data[src][field] ~= c.from or not inRange(c.key, axis, c.to) then finish(T.errChanged) return end
      data[src][field] = c.to
      dirty[src] = true
    end

    applyStage = T.stageWrite
    local function writeNext(index)
      if disposed or not applying then return end
      local source = SOURCES[index]
      if not source then
        applyStage = T.stageSave
        bus.publish("msp.request", eeprom.buildWriteMessage(verify, function()
          finish(link.armed and T.errArmed or T.errSave)
        end))
        return
      end
      if not dirty[source.key] then writeNext(index + 1) return end
      bus.publish("msp.request", source.codec.buildWriteMessage(data[source.key],
        function() writeNext(index + 1) end,
        function() finish(T.errWrite) end))
    end
    writeNext(1)
  end

  local function apply()
    if disposed or not canApply() then return end
    local tune, changes = {}, {}
    for k, v in pairs(view.tune) do tune[k] = v end
    for i, c in ipairs(view.changes) do changes[i] = c end
    applying = {axis = view.axis, tune = tune, changes = changes, data = {},
      pidProfile = link.pidProfile, rateProfile = link.rateProfile}
    applyResult = nil
    applyStage, shownStage = T.stageRead, T.stageRead
    applyDialog = progressDialog.open({title = PAGE_TITLE, message = T.stageRead})
    readAll(1, applying.data, T.errRead, write)
  end

  local function confirmApply()
    if not canApply() then return end
    local lines = {}
    for i, c in ipairs(view.changes) do lines[i] = c.text end
    lines[#lines + 1] = ""
    lines[#lines + 1] = T.applyPrompt
    form.openDialog({
      title = PAGE_TITLE,
      message = table.concat(lines, "\n"),
      buttons = {
        {label = BTN_OK, action = function() apply(); return true end},
        {label = BTN_CANCEL, action = function() return true end},
      },
      wakeup = function() end,
      paint = function() end,
      options = TEXT_LEFT,
    })
  end

  local function closeApplyDialog()
    if not applyDialog then return end
    applyDialog:close(true)         -- now: the outcome dialog follows at once
    applyDialog = nil
  end

  -- Wakeup side of Apply: the dialog's stage text and the outcome
  local function updateApply()
    if applyDialog and shownStage ~= applyStage then
      shownStage = applyStage
      applyDialog:message(applyStage)
    end
    if applyResult == nil then return end
    local result, done = applyResult, applying
    applyResult, applying = nil, nil
    closeApplyDialog()
    if result == true then
      tuneHistory.logChanges(mcuId, done.axis, done.changes)
      applied[done.axis] = true
      render()
    end
    form.openDialog({
      title = PAGE_TITLE,
      message = result == true and T.applied or result,
      buttons = {{label = BTN_OK, action = function() return true end}},
      wakeup = function() end,
      paint = function() end,
      options = TEXT_LEFT,
    })
    if headerHandle then headerHandle.focusMenu() end
  end

  local function confirmClear()
    form.openDialog({
      title = PAGE_TITLE,
      message = T.clearPrompt,
      buttons = {
        {label = BTN_OK, action = function() clear(); return true end},
        {label = BTN_CANCEL, action = function() return true end},
      },
      wakeup = function() end,
      paint = function() end,
    })
  end

  local function goBack()
    disposed = true
    unsubscribe()
    closeApplyDialog()
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setPaintHandler then opts.setPaintHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    if opts.onBack then opts.onBack() end
  end

  local function buildLayout(w, showing)
    local layout = {}
    local valueX = math.floor(w * VALUE_COL)
    local indent = PAD_X * 2
    local wrapW = w - PAD_X - indent - PAD_X
    local wrapped = {}

    local function pair(label, value)
      layout[#layout + 1] = {kind = "pair", text = label, value = value, x = PAD_X, valueX = valueX}
    end
    -- The heading is left out on compact screens: the selector names the section
    local function section(title, items, kind, withHeading)
      if #items == 0 then return end
      layout[#layout + 1] = {kind = withHeading and "heading" or "rule", text = title, x = PAD_X}
      for _, s in ipairs(items) do
        clearList(wrapped)
        wrapInto(wrapped, s, wrapW)
        for _, line in ipairs(wrapped) do
          layout[#layout + 1] = {kind = kind, text = line, x = PAD_X + indent}
        end
      end
    end

    pair(T.data, view.data)
    pair(T.response, view.response)
    pair(T.stops, view.stops)
    -- Compact screens: Changes shows the reasons too, as far as they fit
    -- (paint marks the rest with "..."); Why shows only the reasons, in full.
    if not compact or showing == SECTION_CHANGES then
      section(T.changes, view.actions, "action", true)
      section(T.why, view.whys, "why", true)
    else
      section(T.why, view.whys, "why", false)
    end
    return layout
  end

  local function paint()
    if disposed then return end
    local w, h = lcd.getWindowSize()
    lcd.font(FONT_S)
    if not view.layout then view.layout = buildLayout(w, section) end

    local c = colors()
    local _, textH = lcd.getTextSize("Ag")
    local lineH = textH + (compact and LINE_PAD_COMPACT or LINE_PAD)
    local y = form.height() + (compact and 3 or 6)

    for i, item in ipairs(view.layout) do
      if item.kind == "heading" or item.kind == "rule" then
        y = y + math.floor(lineH * SECTION_GAP)
        lcd.color(c.rule)
        lcd.drawLine(PAD_X, y - 3, w - PAD_X, y - 3)
      end
      -- Out of room: the last line that fits says so instead, rather than
      -- showing some reasons and silently dropping the rest. In the compact
      -- Changes view it points at the Why view, which shows them all.
      if y + lineH > h then break end
      if i < #view.layout and y + 2 * lineH > h then
        lcd.color(c.muted)
        lcd.drawText(item.x, y, (compact and section == SECTION_CHANGES) and T.moreWhy or OVERFLOW_MARK, LEFT)
        break
      end
      if item.kind == "rule" then
        -- divider only; the next item takes this y
      elseif item.kind == "pair" then
        lcd.color(c.muted)
        lcd.drawText(item.x, y, item.text, LEFT)
        lcd.color(c.text)
        lcd.drawText(item.valueX, y, item.value, LEFT)
      else
        lcd.color(item.kind == "heading" and c.accent or item.kind == "action" and c.text or c.muted)
        lcd.drawText(item.x, y, item.text, LEFT)
      end
      if item.kind ~= "rule" then y = y + lineH end
    end
  end

  form.clear()
  headerHandle = header.build(PAGE_TITLE, {
    onBack = goBack,
    onSave = confirmApply,
    onReload = function()
      unsupported = false         -- ask again, e.g. after a firmware update
      load()
      probe()
      if headerHandle then headerHandle.focusReload() end
    end,
    onTool = confirmClear,
  })

  if opts.setEventHandler then
    opts.setEventHandler(function(category, value)
      if closeKey.shouldHandleClose(category, value) then
        goBack()
        return true
      end
      return false
    end)
  end
  if opts.setCleanupHandler then
    opts.setCleanupHandler(function()
      disposed = true
      unsubscribe()
      closeApplyDialog()
      applying = nil
      flights = nil
      view.layout = nil
    end)
  end
  if opts.setWakeupHandler then
    opts.setWakeupHandler(function()
      updateApply()
      local canSave = canApply()
      if saveEnabled ~= canSave then
        saveEnabled = canSave
        headerHandle.setSaveEnabled(canSave)
      end
      if needsPaint then
        needsPaint = false
        if lcd.invalidate then lcd.invalidate() end
      end
    end)
  end
  if opts.setPaintHandler then opts.setPaintHandler(paint) end

  local function onAxis(value)
    for i, entry in ipairs(AXES) do
      if entry[2] == value then selected = i end
    end
    render()
  end

  local axisLine = form.addLine(T.axis)
  if compact then
    -- Two equal selectors right of the label, split by hand from one slot
    local row = form.getFieldSlots(axisLine, {0})[1]
    local right = row.x + row.w
    local left = math.floor(right * 0.25)
    local gap = 8
    local w = math.floor((right - left - gap) / 2)
    local slots = {
      {x = left, y = row.y, w = w, h = row.h},
      {x = left + w + gap, y = row.y, w = right - left - w - gap, h = row.h},
    }
    form.addChoiceField(axisLine, slots[1], AXES, function() return AXES[selected][2] end, onAxis)
    form.addChoiceField(axisLine, slots[2], {{T.changesShort, SECTION_CHANGES}, {T.why, SECTION_WHY}},
      function() return section end,
      function(value) section = value; changed() end)
  else
    form.addChoiceField(axisLine, nil, AXES, function() return AXES[selected][2] end, onAxis)
  end

  changed()
  -- session.update is retained: this delivers the current aircraft now
  bus.subscribe("session.update", onSession)
  bus.subscribe("tune_history.saved", onSaved)
  if not mcuId then render() end
end

return {open = open}
