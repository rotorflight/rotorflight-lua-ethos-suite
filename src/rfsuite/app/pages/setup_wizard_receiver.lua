-- Setup Wizard step: Receiver. Opened by app/pages/setup_wizard.lua.
--
-- The radio's part of rotorflight-configurator's StepReceiver.svelte. The
-- radio talks to the flight controller through this very receiver, so the
-- protocol, port and wiring stay in the Configurator; this step never
-- touches them. What it does:
--
--   intro     is the receiver sending (MSP_STATUS, RX_FAILSAFE clear), with
--             a live bar per function
--   order     the channel order (MSP_SET_RX_MAP): a live bar per function,
--             read through the current map, so a wrong order shows as a bar
--             that follows the wrong stick; then a preset, or
--   detect    found from the sticks, one at a time (collective, roll,
--             pitch, yaw, throttle) on MSP_RX_CHANNELS, as the
--             configurator's "Detect from the sticks" (heli.moved()), with a
--             live bar per receiver channel and the moving one highlighted
--   sticks    each stick read back by function (MSP_RC) as a live bar, to
--             check the order and the directions
--   throttle  the throttle range (MSP_SET_RC_CONFIG rc_min/max_throttle):
--             measured from the throttle channel's travel, or the defaults,
--             drawn as one bar with the FC's end points and the measured ones
--
-- Every change is sent straight away (the RX map and RC config apply in RAM)
-- and registered with wiz.change() for Discard.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local ui = requireModule("app/setup_wizard_ui.lua")
-- Freed when the step closes (app/setup_wizard_ui.lua's notLoaded()). Not
-- msp_rx_map: the background task's session reads it on every connect.
local OWNED = ui.notLoaded({"rfsuite.lib.msp_rc_config"})
local heli = requireModule("lib/setup_wizard_heli.lua")
local status = requireModule("lib/msp_status.lua")
local rxMapCodec = requireModule("lib/msp_rx_map.lua")
local rcConfigCodec = requireModule("lib/msp_rc_config.lua")

local floor = math.floor

local T = {
  title = "@i18n(app.modules.setup_wizard.rcv_title)@",
  intro = "@i18n(app.modules.setup_wizard.rcv_intro)@",
  signalOk = "@i18n(app.modules.setup_wizard.rcv_signal_ok)@",
  signalNone = "@i18n(app.modules.setup_wizard.rcv_signal_none)@",
  orderTitle = "@i18n(app.modules.setup_wizard.rcv_order_title)@",
  orderText = "@i18n(app.modules.setup_wizard.rcv_order_text)@",
  orderNow = "@i18n(app.modules.setup_wizard.rcv_order_now_fmt)@",
  presets = "@i18n(app.modules.setup_wizard.rcv_presets)@",
  presetsText = "@i18n(app.modules.setup_wizard.rcv_presets_text)@",
  custom = "@i18n(app.modules.setup_wizard.rcv_custom)@",
  detect = "@i18n(app.modules.setup_wizard.rcv_detect)@",
  detectText = "@i18n(app.modules.setup_wizard.rcv_detect_text_fmt)@",
  detectDone = "@i18n(app.modules.setup_wizard.rcv_detect_done)@",
  channel = "@i18n(app.modules.setup_wizard.rcv_ch_fmt)@",
  skip = "@i18n(app.modules.setup_wizard.rcv_skip)@",
  sticksTitle = "@i18n(app.modules.setup_wizard.rcv_sticks_title)@",
  sticksText = "@i18n(app.modules.setup_wizard.rcv_sticks_text)@",
  throttleTitle = "@i18n(app.modules.setup_wizard.rcv_throttle_title)@",
  throttleText = "@i18n(app.modules.setup_wizard.rcv_throttle_text)@",
  throttleLegend = "@i18n(app.modules.setup_wizard.rcv_throttle_legend)@",
  bladesOff = "@i18n(app.modules.setup_wizard.rcv_blades_off)@",
  measure = "@i18n(app.modules.setup_wizard.rcv_measure)@",
  stop = "@i18n(app.modules.setup_wizard.rcv_stop)@",
  use = "@i18n(app.modules.setup_wizard.rcv_use)@",
  defaults = "@i18n(app.modules.setup_wizard.rcv_defaults)@",
  tooShort = "@i18n(app.modules.setup_wizard.rcv_too_short)@",
  rangeFmt = "@i18n(app.modules.setup_wizard.rcv_range_fmt)@",
  doneTitle = "@i18n(app.modules.setup_wizard.rcv_done_title)@",
  done = "@i18n(app.modules.setup_wizard.rcv_done)@",
  progress = "@i18n(app.modules.setup_wizard.progress_fmt)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
}

local PRESET_NAMES = {
  elrs = "@i18n(app.modules.setup_wizard.rcv_preset_elrs)@",
  frsky = "@i18n(app.modules.setup_wizard.rcv_preset_frsky)@",
  futaba = "@i18n(app.modules.setup_wizard.rcv_preset_futaba)@",
  spektrum = "@i18n(app.modules.setup_wizard.rcv_preset_spektrum)@",
}

-- Function names, by RX map slot (1 roll ... 5 throttle).
local FUNCTION_NAMES = {
  "@i18n(app.modules.setup_wizard.rcv_ch_roll)@",
  "@i18n(app.modules.setup_wizard.rcv_ch_pitch)@",
  "@i18n(app.modules.setup_wizard.rcv_ch_yaw)@",
  "@i18n(app.modules.setup_wizard.rcv_ch_collective)@",
  "@i18n(app.modules.setup_wizard.rcv_ch_throttle)@",
}

-- What to do with each stick while detecting, by RX map slot.
local DETECT_HINTS = {
  [1] = "@i18n(app.modules.setup_wizard.rcv_move_roll)@",
  [2] = "@i18n(app.modules.setup_wizard.rcv_move_pitch)@",
  [3] = "@i18n(app.modules.setup_wizard.rcv_move_yaw)@",
  [4] = "@i18n(app.modules.setup_wizard.rcv_move_collective)@",
  [5] = "@i18n(app.modules.setup_wizard.rcv_move_throttle)@",
}

local RX_FAILSAFE_BIT = 2
local STATUS_POLL = 1.0
local DETECT_MIN_US = 300
-- A channel moving at least this far while detecting is highlighted.
local DETECT_SHOW_US = 60
local FUNCTION_ROWS = 5
local RAW_ROWS = 8
-- Bars are redrawn when a reading moves by a step of this many per mille.
local QUANT = 1000 / 200
-- The throttle bar's span, us.
local THR_MIN, THR_MAX = 900, 2100

-- Label kinds: how a bar's label is coloured.
local KIND_TEXT, KIND_MUTED, KIND_ACTIVE = 1, 2, 3

local function rxFailsafe(flags)
  flags = tonumber(flags)
  if not flags then return nil end
  return ((math.floor(flags) >> RX_FAILSAFE_BIT) & 1) == 1
end

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)

  local screen = "intro"
  local rxMap = nil        -- decoded MSP_RX_MAP (named fields)
  local rcConfig = nil     -- decoded MSP_RC_CONFIG
  local loadFailed = false
  local signal = nil       -- true / false / nil (unknown)
  local statusAt = 0
  local note, noteAccent = nil, nil

  -- Detection: reused tables, cleared in place.
  local detectIndex = 1
  local detected = {}      -- RX map slot -> channel (0-based)
  local taken = {}         -- channel (1-based) -> true
  local baseline = {}
  local peaks = {}
  local haveBaseline = false

  -- Live bars: labels and label colours set on build; fractions (0..1, or
  -- false when there is no reading) set from wakeup. barCount rows are drawn.
  local labels = {}
  local kinds = {}
  local fracs = {}
  local lastShown = {}     -- quantized reading last drawn, by row
  local barCount = 0
  local hotRow = nil       -- detect: the channel moving now

  -- Throttle range.
  local measuring = false
  local low, high = nil, nil
  local thrNow = nil

  wiz.fetch({
    map = function(ok, err) return rxMapCodec.buildReadMessage(ok, err) end,
    rc = function(ok, err) return rcConfigCodec.buildReadMessage(ok, err) end,
  }, function(results, failed)
    rxMap, rcConfig = results.map, results.rc
    loadFailed = failed or not rxMap or not rcConfig
    wiz.rebuild()
  end)

  local function mapArray(named)
    local out = {}
    for i, key in ipairs(rxMapCodec.FIELDS) do out[i] = named[key] end
    return out
  end

  local function mapNamed(arr)
    local out = {}
    for i, key in ipairs(rxMapCodec.FIELDS) do out[key] = arr[i] end
    return out
  end

  local function writeMap(arr)
    local now = rxMap and mapArray(rxMap)
    if now then
      local same = true
      for i = 1, #rxMapCodec.FIELDS do
        if now[i] ~= arr[i] then same = false; break end
      end
      if same then return end
    end
    wiz.change("rx_map", rxMap, function(o)
      bus.publish("msp.request", rxMapCodec.buildWriteMessage(o))
      bus.publish("rx.map.saved", o)
    end)
    rxMap = mapNamed(arr)
    bus.publish("msp.request", rxMapCodec.buildWriteMessage(rxMap))
    -- tasks/session.lua keeps its own copy for the throttle and switch signals.
    bus.publish("rx.map.saved", rxMap)
  end

  local function writeThrottle(minUs, maxUs)
    wiz.change("rc_config", rcConfig, function(o)
      bus.publish("msp.request", rcConfigCodec.buildWriteMessage(o))
    end)
    rcConfig.rc_min_throttle = minUs
    rcConfig.rc_max_throttle = maxUs
    bus.publish("msp.request", rcConfigCodec.buildWriteMessage(rcConfig))
  end

  local function setLive()
    if screen == "intro" or screen == "order" or screen == "presets" or screen == "detect" then
      self.liveRc = "raw"
    elseif screen == "sticks" or screen == "throttle" then
      self.liveRc = "rc"
    else
      self.liveRc = nil
    end
  end

  local function go(name)
    screen, note, noteAccent, measuring = name, nil, nil, false
    setLive()
    wiz.rebuild()
  end

  local function presetName(arr)
    local key = heli.presetOf(arr)
    return key and PRESET_NAMES[key] or T.custom
  end

  -- Readings ---------------------------------------------------------------

  -- us -> 0..1 along a bar centred on rc_center, full scale at +-rc_deflection.
  local function fraction(us)
    if not us or us <= 0 then return false end
    local centre = rcConfig and rcConfig.rc_center or 1500
    local defl = rcConfig and rcConfig.rc_deflection or 500
    if defl <= 0 then defl = 500 end
    local f = ((us - centre) / defl + 1) / 2
    if f < 0 then f = 0 elseif f > 1 then f = 1 end
    return f
  end

  -- The raw channel behind RX map slot i, through the map as it stands.
  local function mappedRaw(slot)
    local ch = rxMap and rxMap[rxMapCodec.FIELDS[slot]]
    return ch and wiz.rcRaw[ch + 1] or nil
  end

  -- Fills fracs[] for the screen; true when a bar moved enough to redraw.
  local function readBars()
    local changed = false
    for i = 1, barCount do
      local us
      if screen == "sticks" then
        us = wiz.rc[i]
      elseif screen == "detect" then
        us = wiz.rcRaw[i]
      else
        us = mappedRaw(i)
      end
      local f = fraction(us)
      fracs[i] = f
      local q = f and floor(f * 1000 / QUANT) or -1
      if q ~= lastShown[i] then
        lastShown[i] = q
        changed = true
      end
    end
    return changed
  end

  -- Drawing (paint: no allocation) -------------------------------------------

  local function labelColor(kind, colors)
    if kind == KIND_ACTIVE then return colors.active end
    if kind == KIND_MUTED then return colors.muted end
    return colors.text
  end

  -- barCount rows of "label  [bar]", in two columns when one is too tight.
  local function drawBars(x, y, w, h, colors)
    if barCount == 0 or h < 10 then return end
    lcd.font(FONT_S)
    local _, th = lcd.getTextSize("Ag")
    local cols = 1
    local rows = barCount
    if floor(h / rows) < th + 2 then
      cols = 2
      rows = math.ceil(barCount / 2)
    end
    local rowH = math.min(floor(h / rows), th + 12)
    local gap = 16
    local colW = floor((w - gap * (cols - 1)) / cols)
    local labelW = floor(colW * (cols == 1 and 0.26 or 0.42))
    for i = 1, barCount do
      local c = floor((i - 1) / rows)
      local r = (i - 1) % rows
      local bx = x + c * (colW + gap)
      local by = y + r * rowH
      lcd.color(labelColor(kinds[i], colors))
      lcd.drawText(bx, by + floor((rowH - th) / 2), labels[i], LEFT)
      local f = fracs[i]
      ui.gauge(bx + labelW, by + 2, colW - labelW - 8, rowH - 4, f or nil, colors, 0.48, 0.52)
      if i == hotRow and f then
        -- The moving channel's mark, drawn heavier.
        lcd.color(colors.active)
        local gx = bx + labelW + floor((colW - labelW - 8) * f)
        lcd.drawFilledRectangle(gx - 5, by + 2, 10, rowH - 4)
      end
    end
  end

  local function thrFrac(us)
    local f = (us - THR_MIN) / (THR_MAX - THR_MIN)
    if f < 0 then f = 0 elseif f > 1 then f = 1 end
    return f
  end

  -- One wide bar: the FC's end points (muted ticks), the measured travel
  -- (an accent band), and the throttle now (the gauge mark).
  local function drawThrottle(x, y, w, h, colors)
    if h < 20 then return end
    local barH = math.min(h - 4, 36)
    local by = y + floor((h - barH) / 2)
    local zero, full = heli.throttleEnds(rcConfig)
    -- Measured travel, under the mark.
    if low and high then
      lcd.color(colors.surface)
      local lx = x + floor(w * thrFrac(low))
      local hx = x + floor(w * thrFrac(high))
      lcd.drawFilledRectangle(lx, by + floor(barH / 2) - 6, math.max(2, hx - lx), 12)
    end
    ui.gauge(x, by, w, barH, thrNow and thrFrac(thrNow) or nil, colors)
    -- The FC's end points.
    lcd.color(colors.muted)
    lcd.drawFilledRectangle(x + floor(w * thrFrac(zero)) - 1, by - 4, 3, barH + 8)
    lcd.drawFilledRectangle(x + floor(w * thrFrac(full)) - 1, by - 4, 3, barH + 8)
  end

  -- Bar setups (build only) ----------------------------------------------------

  local function clearBars()
    barCount = 0
    hotRow = nil
    for k in pairs(lastShown) do lastShown[k] = nil end
    for k in pairs(fracs) do fracs[k] = nil end
  end

  local function functionBars(activeSlot)
    clearBars()
    barCount = FUNCTION_ROWS
    for i = 1, FUNCTION_ROWS do
      labels[i] = FUNCTION_NAMES[i]
      kinds[i] = (i == activeSlot) and KIND_ACTIVE or KIND_TEXT
      fracs[i] = false
    end
    scr:draw(drawBars)
  end

  -- Detect: one bar per receiver channel. A channel already given a function
  -- says which, in grey; the others are plain.
  local function channelBars()
    clearBars()
    local n = math.min(RAW_ROWS, math.max(#wiz.rcRaw, FUNCTION_ROWS))
    barCount = n
    for ch = 1, n do
      local label = string.format(T.channel, ch)
      local kind = KIND_TEXT
      if taken[ch] then
        kind = KIND_MUTED
        for slot, c in pairs(detected) do
          if c == ch - 1 then label = label .. " " .. FUNCTION_NAMES[slot] end
        end
      end
      labels[ch] = label
      kinds[ch] = kind
      fracs[ch] = false
    end
    scr:draw(drawBars)
  end

  -- Detection ------------------------------------------------------------

  local function resetPeaks()
    haveBaseline = false
    for k in pairs(peaks) do peaks[k] = nil end
    for k in pairs(baseline) do baseline[k] = nil end
  end

  local function startDetect()
    detectIndex = 1
    for k in pairs(detected) do detected[k] = nil end
    for k in pairs(taken) do taken[k] = nil end
    resetPeaks()
    go("detect")
  end

  local function finishDetect()
    local arr = heli.mapFromDetected(detected, #rxMapCodec.FIELDS)
    writeMap(arr)
    go("order")
    note = T.detectDone
  end

  local function nextStick(channel)
    local slot = heli.DETECT_ORDER[detectIndex]
    if channel then
      detected[slot] = channel - 1
      taken[channel] = true
    end
    detectIndex = detectIndex + 1
    resetPeaks()
    if detectIndex > #heli.DETECT_ORDER then
      finishDetect()
    else
      wiz.rebuild()
    end
  end

  local function detectWakeup()
    local raw = wiz.rcRaw
    local n = #raw
    if n == 0 then return end
    if not haveBaseline then
      for i = 1, n do
        baseline[i] = raw[i]
        peaks[i] = 0
      end
      haveBaseline = true
      return
    end
    local hot, hotMove = nil, DETECT_SHOW_US
    for i = 1, n do
      local d = math.abs((raw[i] or 0) - (baseline[i] or raw[i] or 0))
      if d > (peaks[i] or 0) then peaks[i] = d end
      if not taken[i] and d >= hotMove then hot, hotMove = i, d end
    end
    if hot ~= hotRow then
      hotRow = hot
      wiz.invalidate()
    end
    local ch = heli.moved(peaks, taken, DETECT_MIN_US)
    if ch then nextStick(ch) end
  end

  -- Throttle ------------------------------------------------------------------

  local function throttleWakeup()
    local us = wiz.rc[5]
    if not us then return end
    local changed = false
    if us ~= thrNow then
      thrNow = us
      changed = true
    end
    if measuring then
      if not low or us < low then low, changed = us, true end
      if not high or us > high then high, changed = us, true end
    end
    if changed then wiz.invalidate() end
  end

  local function fcRangeText()
    local zero, full = heli.throttleEnds(rcConfig)
    return string.format(T.rangeFmt, zero, full)
  end

  -- Screens -----------------------------------------------------------------

  function self.build()
    scr:begin()
    clearBars()
    if not rxMap and not loadFailed then
      scr:text(T.title, "@i18n(app.msg_loading)@")
      return nil
    end
    if loadFailed then
      scr:text(T.title, "@i18n(app.msg_load_failed_body)@")
      return scr:row(nil)
    end

    if screen == "intro" then
      local accent = nil
      if signal == true then accent = T.signalOk elseif signal == false then accent = T.signalNone end
      scr:text(T.title, T.intro, accent)
      functionBars(nil)
      return scr:row(nil, {{text = T.start, primary = true, press = function() go("order") end}})

    elseif screen == "order" then
      scr:text(T.orderTitle, T.orderText .. " " .. string.format(T.orderNow, presetName(mapArray(rxMap))),
        noteAccent or note, string.format(T.progress, 1, 3))
      functionBars(nil)
      return scr:row(function() go("intro") end, {
        {text = T.presets, press = function() go("presets") end},
        {text = T.detect, needsMotion = true, press = startDetect},
      }, {text = T.next, press = function() go("sticks") end})

    elseif screen == "presets" then
      scr:text(T.orderTitle, T.presetsText .. " " .. string.format(T.orderNow, presetName(mapArray(rxMap))))
      local specs = {}
      local current = heli.presetOf(mapArray(rxMap))
      for _, p in ipairs(heli.CHANNEL_PRESETS) do
        local arr = p.map
        specs[#specs + 1] = {text = PRESET_NAMES[p.key], primary = p.key == current, press = function()
          writeMap(arr)
          go("order")
        end}
      end
      scr:row(function() go("order") end, nil, false)
      return scr:grid(specs, 2)

    elseif screen == "detect" then
      local slot = heli.DETECT_ORDER[detectIndex]
      scr:text(FUNCTION_NAMES[slot], string.format(T.detectText, DETECT_HINTS[slot]), nil,
        string.format(T.progress, detectIndex, #heli.DETECT_ORDER))
      channelBars()
      return scr:row(function() go("order") end, {
        {text = T.skip, press = function() nextStick(nil) end},
      }, false)

    elseif screen == "sticks" then
      scr:text(T.sticksTitle, T.sticksText, nil, string.format(T.progress, 2, 3))
      functionBars(nil)
      return scr:row(function() go("order") end, nil, {text = T.next, press = function() go("throttle") end})

    elseif screen == "throttle" then
      local accent = noteAccent or T.bladesOff
      local body = T.throttleText .. " " .. fcRangeText()
      if low and high then body = body .. " / " .. string.format(T.rangeFmt, low, high) end
      scr:text(T.throttleTitle, body, accent, string.format(T.progress, 3, 3))
      scr:draw(drawThrottle, T.throttleLegend)
      local canUse = heli.throttleFromMeasured(low, high) ~= nil and not measuring
      return scr:row(function() go("sticks") end, {
        {text = measuring and T.stop or T.measure, primary = not canUse, press = function()
          if measuring then
            measuring = false
            if not heli.throttleFromMeasured(low, high) then noteAccent = T.tooShort end
          else
            measuring, low, high, noteAccent = true, nil, nil, nil
          end
          wiz.rebuild()
        end},
        {text = T.use, disabled = not canUse, primary = canUse, press = function()
          local minUs, maxUs = heli.throttleFromMeasured(low, high)
          if minUs then writeThrottle(minUs, maxUs) end
          wiz.rebuild()
        end},
        {text = T.defaults, small = true, press = function()
          writeThrottle(0, 0)
          wiz.rebuild()
        end},
      }, {text = T.next, disabled = measuring, press = function() go("done") end})

    else -- done
      scr:text(T.doneTitle, T.done)
      return scr:row(function() go("throttle") end)
    end
  end

  function self.paint() scr:paint() end

  function self.wakeup(now)
    if screen == "intro" then
      if now >= statusAt then
        statusAt = now + STATUS_POLL
        bus.publish("msp.request", status.buildReadMessage(function(data)
          local fs = rxFailsafe(data and data.arming_disable_flags)
          if fs == nil then return end
          local ok = not fs
          if ok ~= signal then
            signal = ok
            wiz.rebuild()
          end
        end))
      end
    elseif screen == "detect" then
      detectWakeup()
    elseif screen == "throttle" then
      throttleWakeup()
    end
    if barCount > 0 and readBars() then wiz.invalidate() end
  end

  function self.released() scr:refresh() end
  function self.leave()
    measuring = false
    self.liveRc = nil
  end

  setLive()
  return self
end

return {new = new, owned = OWNED}
