-- Configuration -> Flight Tuning -> Tune Advisor page.
--
-- Reads the FC's in-flight rate-loop statistics (lib/msp_tune_advisor.lua,
-- rotorflight-firmware flight/tune_advisor.c) and turns them into concrete
-- changes, one axis at a time: what was measured, which setting to change
-- (named by the page it lives on, in the units that page shows), and why.
-- The firmware only measures; the rules below are the advice, kept here so
-- they can change without a flash. Ported from the Wingflight suite.
--
-- One axis at a time: the FC answers one axis per request so the reply
-- fits MSP over telemetry.
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
-- Clear (header Tool button) resets the FC's statistics; they also reset
-- on their own when the tune changes.
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
local rateCurveScale = requireModule("lib/rate_curve_scale.lua")

local PAGE_TITLE = "@i18n(app.modules.tune_advisor.name)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"

local T = {
  axis = "@i18n(app.modules.tune_advisor.axis)@",
  data = "@i18n(app.modules.tune_advisor.data)@",
  dataFmt = "@i18n(app.modules.tune_advisor.data_fmt)@",
  collecting = "@i18n(app.modules.tune_advisor.collecting)@",
  paused = "@i18n(app.modules.tune_advisor.paused)@",
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
}

-- {label, axis}: axis is the FC's 1-based axis (1 roll, 2 pitch, 3 yaw)
local AXES = {
  {"@i18n(app.modules.tune_advisor.roll)@", 1},
  {"@i18n(app.modules.tune_advisor.pitch)@", 2},
  {"@i18n(app.modules.tune_advisor.yaw)@", 3},
}
local AXIS_ROLL, AXIS_PITCH, AXIS_YAW = 1, 2, 3

local REFRESH_INTERVAL_SECONDS = 2

-- Feed-forward match
local FF_MIN_COUNT = 1000       -- 10 s of usable 40-200 deg/s stick
local FF_MIN_CORR = 0.85
local FF_HOT = 1.15
local FF_LOW = 0.85
local FF_STEP_MAX = 0.2         -- change F by at most 20% per step
local F_MAX = 1000
local RATE_RAW_MAX = 255

-- Which rate columns scale the whole curve linearly, per rates_type. The
-- others (Betaflight, Raceflight, KISS) get a percentage instead.
local R = rateCurveScale
local LINEAR_ROLES = {
  [R.RATE_TYPE_ACTUAL] = {"rcRate", "srate"},       -- center sensitivity, max rate
  [R.RATE_TYPE_QUICK] = {"rcRate", "srate"},        -- rc rate, max rate
  [R.RATE_TYPE_ROTORFLIGHT] = {"rcRate"},           -- rate (srate is the shape)
}
-- Max rate asked at full stick (deg/s) from the raw bytes, where the type makes it direct
local function maxRateAsked(a)
  if a.ratesType == R.RATE_TYPE_ACTUAL or a.ratesType == R.RATE_TYPE_QUICK then return a.sRate * 10 end
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

-- Suggests scaling the rate curve by k (e.g. 1.25 = 25% faster everywhere)
local function rateActions(a, name, k, act)
  local roles = LINEAR_ROLES[a.ratesType]
  if not roles then
    local pct = round(math.abs(k - 1) * 100)
    act(string.format(k > 1 and T.actRatePctUpFmt or T.actRatePctDownFmt, name, pct))
    return
  end
  for _, role in ipairs(roles) do
    local raw = (role == "rcRate") and a.rcRate or a.sRate
    local newRaw = clamp(round(raw * k), 1, RATE_RAW_MAX)
    act(string.format(T.actRateFmt, name, (role == "rcRate") and T.rcRate or T.rate,
      rateText(raw, a.ratesType, role), rateText(newRaw, a.ratesType, role)))
  end
end

-- Fills actions/whys (cleared by the caller) for one axis; returns the
-- Response and Stops values.
local function advise(a, axis, name, actions, whys)
  local function act(s) if #actions < MAX_ACTIONS then actions[#actions + 1] = s end end
  local function why(s) if #whys < MAX_WHYS then whys[#whys + 1] = s end end

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
      local newF = clamp(round(a.F * clamp(1 / g, 1 - FF_STEP_MAX, 1 + FF_STEP_MAX)), 1, F_MAX)
      act(string.format(T.actFFmt, name, a.F, newF))
      -- Keep the stick feel: F x rate is what the pilot feels
      rateActions(a, name, a.F / newF, act)
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
        and a.fullMaxRate < FULL_REACH * asked then
      rateActions(a, name, a.fullMaxRate / asked, act)
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
      if a.meanIterm >= ITERM_PUSH and a.relaxCutoff > CUTOFF_MIN then
        act(string.format(T.actRelaxFmt, name, a.relaxCutoff,
          clamp(round(a.relaxCutoff * CUTOFF_STEP), CUTOFF_MIN, a.relaxCutoff - 1)))
        why(T.whyRelax)
      elseif ffOff(a) and a.F > 0 then
        why(string.format(T.whyFixFFmt, rebound))
      else
        act(string.format(T.actPFmt, name, a.P, clamp(round(a.P * P_STEP), a.P + 1, F_MAX)))
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

-- Word-wrap text into lines no wider than maxW (in the current lcd.font)
local function wrapInto(out, text, maxW)
  local line = ""
  for word in text:gmatch("%S+") do
    local candidate = (line == "") and word or (line .. " " .. word)
    if line ~= "" and lcd.getTextSize(candidate) > maxW then
      out[#out + 1] = line
      line = word
    else
      line = candidate
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
  local pending = false
  local lastPoll = 0
  local lastData = nil
  local lastSignature = nil
  local selected = 1              -- index into AXES
  local section = SECTION_CHANGES -- compact screens only
  local actions, whys = {}, {}
  local compact = lcd.getWindowSize() < COMPACT_WIDTH

  -- What paint shows. layout (the wrapped lines) is rebuilt on the next
  -- paint after a change, never on a paint with nothing new.
  local view = {data = "-", response = "-", stops = "-", actions = {}, whys = {}, layout = nil}

  -- MSP replies arrive in the background task, where lcd.invalidate() does
  -- not reach this page's window: flag it and invalidate from our own wakeup
  -- (as app/pages/curves.lua and logs.lua do).
  local needsPaint = false
  local function changed()
    view.layout = nil
    needsPaint = true
  end

  local function showUnsupported()
    view.data, view.response, view.stops = T.unsupported, "-", "-"
    clearList(view.actions)
    clearList(view.whys)
    changed()
  end

  local function render()
    local data = lastData
    local axis = AXES[selected][2]
    if not data or data.axis ~= axis then return end

    view.data = string.format(T.dataFmt, math.floor(data.seconds / 60), data.seconds % 60,
      data.collecting and T.collecting or T.paused)

    clearList(actions)
    clearList(whys)
    view.response, view.stops = advise(data.a, axis, AXES[selected][1], actions, whys)
    clearList(view.actions)
    clearList(view.whys)
    for i = 1, #actions do view.actions[i] = actions[i] end
    for i = 1, #whys do view.whys[i] = whys[i] end
    changed()
  end

  local function apply(data)
    -- Skip the rebuild when nothing new was collected
    local a = data.a
    local signature = ((data.seconds * 2 + (data.collecting and 1 or 0)) * 4 + data.axis) * 31
      + a.ffCount + a.releases + a.fullCount + a.F + a.P + a.rcRate + a.sRate + a.ratesType + a.relaxCutoff
    if signature == lastSignature then return end
    lastSignature = signature
    lastData = data
    render()
  end

  local poll
  poll = function()
    -- Reload stays enabled: this polls every 2 s, and greying the button for
    -- each request made it flicker. A press while a request is out is a no-op.
    if disposed or pending then return end
    pending = true
    bus.publish("msp.request", tuneAdvisor.buildReadMessage(AXES[selected][2], function(data)
      pending = false
      if disposed then return end
      if data.axis ~= AXES[selected][2] then
        poll()      -- the axis changed while this request was out
        return
      end
      apply(data)
    end, function()
      pending = false
      if disposed then return end
      lastSignature = nil
      lastData = nil
      showUnsupported()
    end))
  end

  local function clear()
    if disposed then return end
    bus.publish("msp.request", tuneAdvisor.buildClearMessage(function()
      if disposed then return end
      lastSignature = nil
      poll()
    end))
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
    onReload = function()
      lastSignature = nil
      poll()
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
      lastData = nil
      view.layout = nil
    end)
  end
  if opts.setWakeupHandler then
    opts.setWakeupHandler(function()
      if needsPaint then
        needsPaint = false
        if lcd.invalidate then lcd.invalidate() end
      end
      local now = os.clock()
      if not pending and now - lastPoll >= REFRESH_INTERVAL_SECONDS then
        lastPoll = now
        poll()
      end
    end)
  end
  if opts.setPaintHandler then opts.setPaintHandler(paint) end

  local function onAxis(value)
    for i, entry in ipairs(AXES) do
      if entry[2] == value then selected = i end
    end
    -- Each axis is its own request: fetch the new one now
    lastSignature = nil
    lastPoll = os.clock()
    poll()
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
  poll()
end

return {open = open}
