-- Setup Wizard step: Receiver. Opened by app/pages/setup_wizard.lua.
--
-- The radio's part of rotorflight-configurator's StepReceiver.svelte, and the
-- EdgeTX suite's receiver card. The radio talks to the flight controller
-- through this very receiver, so a wrong protocol cuts the link (the warning
-- on the link card says so); the port and wiring stay in the Configurator.
-- What it does:
--
--   prepare   the EdgeTX card "Before this step": blades off and servos
--             unplugged, both Yes before Next
--   link      the protocol (its own grid of choices), and Save & restart, which
--             reopens on this card
--   order     the receiver sending (MSP_STATUS, RX_FAILSAFE clear, the signal
--             line), a live bar per function, and the channel order
--             (MSP_SET_RX_MAP), read through the current map, so a wrong order
--             shows as a bar that follows the wrong stick; then a preset, or
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
local art = requireModule("app/setup_wizard_art.lua")
-- Freed when the step closes (app/setup_wizard_ui.lua's notLoaded()). Not
-- msp_rx_map: the background task's session reads it on every connect.
local OWNED = ui.notLoaded({"rfsuite.lib.msp_rc_config"})
local heli = requireModule("lib/setup_wizard_heli.lua")
local status = requireModule("lib/msp_status.lua")
local rxMapCodec = requireModule("lib/msp_rx_map.lua")
local rcConfigCodec = requireModule("lib/msp_rc_config.lua")
local rxConfigCodec = requireModule("lib/msp_rx_config.lua")
local featureCodec = requireModule("lib/msp_feature_config.lua")
local rcChannels = requireModule("lib/msp_rc_channels.lua")

local floor = math.floor

local T = {
  title = "@i18n(app.modules.setup_wizard.rcv_title)@",
  signalOk = "@i18n(app.modules.setup_wizard.rcv_signal_ok)@",
  signalNone = "@i18n(app.modules.setup_wizard.rcv_signal_none)@",
  orderTitle = "@i18n(app.modules.setup_wizard.rcv_order_title)@",
  orderText = "@i18n(app.modules.setup_wizard.rcv_order_text)@",
  standardOrder = "@i18n(app.modules.setup_wizard.rcv_standard_order)@",
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
  prepareTitle = "@i18n(app.modules.setup_wizard.rcv_prepare_title)@",
  prepareText = "@i18n(app.modules.setup_wizard.rcv_prepare_text)@",
  unplugged = "@i18n(app.modules.setup_wizard.sen_servos_unplugged)@",
  blades = "@i18n(app.modules.setup_wizard.sen_blades_removed)@",
  linkText = "@i18n(app.modules.setup_wizard.rcv_link_text)@",
  linkWarn = "@i18n(app.modules.setup_wizard.rcv_link_warning)@",
  protocol = "@i18n(app.modules.setup_wizard.rcv_protocol)@",
  protocolTitle = "@i18n(app.modules.setup_wizard.rcv_protocol_title)@",
  saveRestart = "@i18n(app.modules.setup_wizard.btn_save_restart)@",
  dirLeft = "@i18n(app.modules.setup_wizard.role_left)@",
  dirBack = "@i18n(app.modules.setup_wizard.rcv_dir_back)@",
  dirDown = "@i18n(app.modules.setup_wizard.rcv_dir_down)@",
  dirRight = "@i18n(app.modules.setup_wizard.role_right)@",
  dirForward = "@i18n(app.modules.setup_wizard.rcv_dir_forward)@",
  dirUp = "@i18n(app.modules.setup_wizard.rcv_dir_up)@",
  yes ="@i18n(app.modules.setup_wizard.btn_yes)@",
  no = "@i18n(app.modules.setup_wizard.btn_no)@",
  throttleText = "@i18n(app.modules.setup_wizard.rcv_throttle_text)@",
  throttleName = "@i18n(app.modules.setup_wizard.rcv_ch_throttle)@",
  fcRange = "@i18n(app.modules.setup_wizard.rcv_fc_range)@",
  mismatchFmt = "@i18n(app.modules.setup_wizard.rcv_link_mismatch_fmt)@",
  measured = "@i18n(app.modules.setup_wizard.rcv_measured)@",
  bladesOff = "@i18n(app.modules.setup_wizard.rcv_blades_off)@",
  measure = "@i18n(app.modules.setup_wizard.rcv_measure)@",
  stop = "@i18n(app.modules.setup_wizard.rcv_stop)@",
  use = "@i18n(app.modules.setup_wizard.rcv_use)@",
  defaults = "@i18n(app.modules.setup_wizard.rcv_defaults)@",
  tooShort = "@i18n(app.modules.setup_wizard.rcv_too_short)@",
  doneTitle = "@i18n(app.modules.setup_wizard.rcv_done_title)@",
  doneSave = "@i18n(app.modules.setup_wizard.rcv_done_save)@",
  doneKeep = "@i18n(app.modules.setup_wizard.rcv_done_keep)@",
  progress = "@i18n(app.modules.setup_wizard.progress_fmt)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
}

-- The screens of the step, in order: prepare, link (and its protocol), order
-- (and its presets, with the signal check), detect, sticks, throttle, done.
local RECEIVER_SCREENS = 6

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
-- On S.Port, F.Port and FBUS each MSP reply blanks the FC's sensor telemetry for
-- 250 ms (firmware telemetry/smartport.c, SMARTPORT_MSP_SILENCE_US): read often,
-- Ethos reports the sensors lost. So the bars of this step read the radio's own
-- channel outputs, which the receiver passes on one to one (the FC maps them, it
-- does not reverse them: firmware rx/rx.c readRxChannels). MSP is left to the
-- signal check and a cross-check of the radio against the FC, both seldom.
local STATUS_POLL = 3.0
local LOCAL_CHANNELS = 16
-- Ethos -1024..1024 is -100..+100 %: 1500 +- 512 us on F.Port, FBUS and CRSF.
local US_PER_UNIT = 512 / 1024
-- The cross-check: one MSP_RX_CHANNELS read this often, compared with the radio
-- for each stick that held still (CHECK_STILL) while the read was out.
local CHECK_POLL = 5.0
local CHECK_FIRST = 1.5
local CHECK_GIVE_UP = 3.0
local CHECK_STILL = 8
local CHECK_TOLERANCE = 30
-- The radio is read (and the bars redrawn) at most this often.
local LOCAL_READ = 0.1
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

  -- The EdgeTX suite's "Before this step" card: blades off and servos
  -- unplugged, both answered Yes before the step goes on.
  -- Back from a restart the step reopens on the link card (the new protocol is
  -- live then); otherwise the safety card comes first.
  local screen = wiz.takeResume() or "prepare"
  local answers = {blades = false, unplugged = false}
  local answered = nil     -- the answer just pressed keeps the focus
  local receiverPicture = art.image("receiver", 140, 70)
  local rxMap = nil        -- decoded MSP_RX_MAP (named fields)
  local rcConfig = nil     -- decoded MSP_RC_CONFIG
  local rxConfig = nil     -- decoded MSP_RX_CONFIG (the protocol)
  local feature = nil      -- decoded MSP_FEATURE_CONFIG (the serial receiver bit)
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

  -- Sticks: the travel each of the four sticks reached, in percent of the FC's
  -- range (low, high). Both ends must reach TRAVEL_OK before Next.
  local TRAVEL_OK = 95
  local travel = {{0, 0}, {0, 0}, {0, 0}, {0, 0}}
  local pcts = {}                      -- the live percentage of each row, or nil
  local sideWords = {T.dirRight, T.dirForward, T.dirRight, T.dirUp, T.dirUp}
  local oppWords = {T.dirLeft, T.dirBack, T.dirLeft, T.dirDown, T.dirDown}
  local travelWasOk = false
  local function resetTravel()
    for i = 1, 4 do travel[i][1], travel[i][2] = 0, 0 end
    travelWasOk = false
  end
  local function travelOk()
    for i = 1, 4 do
      if travel[i][1] > -TRAVEL_OK or travel[i][2] < TRAVEL_OK then return false end
    end
    return true
  end
  -- A reading in percent of the FC's range, centred on rc_center.
  local function percentOf(us)
    if not us or us <= 0 then return nil end
    local centre = rcConfig and rcConfig.rc_center or 1500
    local defl = rcConfig and rcConfig.rc_deflection or 500
    if defl <= 0 then defl = 500 end
    return floor((us - centre) * 100 / defl + (us >= centre and 0.5 or -0.5))
  end

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
  local applied = false      -- the measured range has been written to the FC
  local thrNow = nil
  -- The cross-check (see CHECK_POLL); mismatch is the function slot that differs.
  local checkRaw, checkSnap = {}, {}
  local checkInFlight, checkAt = false, 0
  local mismatch = nil

  -- The radio's channel outputs, in us: raw by receiver channel, rc by function
  -- through the receiver map (as MSP_RX_CHANNELS and MSP_RC would answer).
  local chanSources = {}
  local localAt = 0
  local localRaw, localRc = {}, {}
  local simSweep = {}
  local function readLocal()
    local n = 0
    if CATEGORY_CHANNEL ~= nil then
      for i = 1, LOCAL_CHANNELS do
        local src = chanSources[i]
        if src == nil then
          src = system.getSource({category = CATEGORY_CHANNEL, member = i - 1, options = 0}) or false
          chanSources[i] = src
        end
        local v = src and src:value()
        if type(v) ~= "number" then break end
        localRaw[i] = floor(1500 + v * US_PER_UNIT + 0.5)
        n = i
      end
    end
    for i = n + 1, #localRaw do localRaw[i] = nil end
    -- The simulator's sticks stay centred: the four stick channels sweep as the
    -- simulator's MSP replies do. The throttle and the switches stay the radio's.
    if rcChannels.SIMULATED and rxMap then
      rcChannels.sweepChannelsUs(os.clock(), simSweep)
      for slot = 1, 4 do
        local ch = rxMap[rxMapCodec.FIELDS[slot]]
        if ch then
          for i = #localRaw + 1, ch do localRaw[i] = 1500 end
          localRaw[ch + 1] = simSweep[slot]
        end
      end
    end
    for slot = 1, #rxMapCodec.FIELDS do
      local ch = rxMap and rxMap[rxMapCodec.FIELDS[slot]]
      localRc[slot] = ch and localRaw[ch + 1] or nil
    end
  end

  wiz.fetch({
    map = function(ok, err) return rxMapCodec.buildReadMessage(ok, err) end,
    rc = function(ok, err) return rcConfigCodec.buildReadMessage(ok, err) end,
    rx = function(ok, err) return rxConfigCodec.buildReadMessage(ok, err) end,
    feature = function(ok, err) return featureCodec.buildReadMessage(ok, err) end,
  }, function(results, failed)
    rxMap, rcConfig = results.map, results.rc
    rxConfig, feature = results.rx, results.feature
    loadFailed = failed or not rxMap or not rcConfig or not rxConfig or not feature
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

  -- The protocol, as the EdgeTX suite lists it: the firmware's provider numbers.
  -- The later ones need the newer API.
  local FEATURE_SERIAL_RX = 3
  local FEATURE_CLASH = {0, 3, 13, 14, 25}
  local function protocolList()
    local e = {{9, "CRSF / ELRS"}, {2, "S.BUS"}, {0, "DSM/1024"}, {1, "DSM/2048"}, {10, "SRXL"},
      {13, "SRXL2"}, {14, "GHOST"}, {3, "SUMD"}, {4, "SUMH"}, {7, "IBUS"}, {5, "XBUS B"},
      {6, "XBUS RJ01"}, {8, "Jeti EXBUS"}, {12, "F.PORT"}}
    if wiz.apiAtLeast(7) then e[#e + 1] = {15, "S.BUS2"}; e[#e + 1] = {16, "F.PORT2"}; e[#e + 1] = {17, "FBUS"} end
    if wiz.apiAtLeast(8) then e[#e + 1] = {18, "XBUS A"} end
    if wiz.apiAtLeast(9) then e[#e + 1] = {19, "IBUS2"} end
    return e
  end

  -- The protocol the FC uses: only once the serial receiver is on.
  local function currentProtocol()
    if not rxConfig or not feature then return nil end
    if featureCodec.getBit(feature.enabledFeatures, FEATURE_SERIAL_RX) then return rxConfig.serialrx_provider end
    return nil
  end

  local function protocolName(id)
    for _, p in ipairs(protocolList()) do
      if p[1] == id then return p[2] end
    end
    return "-"
  end

  -- Writes the protocol and the serial receiver feature, as the EdgeTX suite
  -- does, and asks for the restart that makes them live. Registered for Discard.
  local function setProtocol(id)
    wiz.change("rx_config", rxConfig, function(o)
      bus.publish("msp.request", rxConfigCodec.buildWriteMessage(o))
    end)
    wiz.change("feature_config", feature, function(o)
      bus.publish("msp.request", featureCodec.buildWriteMessage(o))
    end)
    rxConfig.serialrx_provider = id
    bus.publish("msp.request", rxConfigCodec.buildWriteMessage(rxConfig))
    local value = feature.enabledFeatures
    for _, bit in ipairs(FEATURE_CLASH) do value = featureCodec.setBit(value, bit, false) end
    feature.enabledFeatures = featureCodec.setBit(value, FEATURE_SERIAL_RX, true)
    bus.publish("msp.request", featureCodec.buildWriteMessage(feature))
    wiz.requestReboot()
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
    -- No shell polling: the bars and the throttle measurement read the radio
    -- (readLocal); the FC is asked only for the status and the cross-check.
    self.liveRc, self.liveRcInterval = nil, nil
    checkAt = os.clock() - CHECK_POLL + CHECK_FIRST
  end

  local function go(name)
    screen, note, noteAccent, measuring = name, nil, nil, false
    if name == "sticks" then resetTravel() end
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
  -- The bar's name with its receiver channel, from the receiver map.
  local function channelLabel(slot)
    local ch = rxMap and rxMap[rxMapCodec.FIELDS[slot]]
    if ch == nil then return FUNCTION_NAMES[slot] end
    return string.format("%s (CH%d)", FUNCTION_NAMES[slot], ch + 1)
  end

  local function mappedRaw(slot)
    local ch = rxMap and rxMap[rxMapCodec.FIELDS[slot]]
    return ch and localRaw[ch + 1] or nil
  end

  -- Fills fracs[] for the screen; true when a bar moved enough to redraw.
  local function readBars()
    local changed = false
    for i = 1, barCount do
      local us
      if screen == "sticks" then
        us = localRc[i]
      elseif screen == "detect" then
        us = localRaw[i]
      else
        us = mappedRaw(i)
      end
      if screen == "sticks" then
        local p = percentOf(us)
        pcts[i] = p
        if p and i <= 4 then
          local t = travel[i]
          if p < t[1] then t[1] = math.max(p, -100) end
          if p > t[2] then t[2] = math.min(p, 100) end
        end
      end
      local f = fraction(us)
      fracs[i] = f
      local q = f and floor(f * 1000 / QUANT) or -1
      if q ~= lastShown[i] then
        lastShown[i] = q
        changed = true
      end
    end
    -- Next is decided when the screen is built: rebuild once the travel is complete.
    if screen == "sticks" then
      local ok = travelOk()
      if ok ~= travelWasOk then
        travelWasOk = ok
        wiz.rebuild()
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
    -- Beside the order's checks the bars are narrow: their names get more room.
    local longest = 0
    for i = 1, barCount do longest = math.max(longest, (lcd.getTextSize(labels[i] or ""))) end
    local labelW = math.min(floor(colW * 0.5), longest + 10)
    for i = 1, barCount do
      local c = floor((i - 1) / rows)
      local r = (i - 1) % rows
      local bx = x + c * (colW + gap)
      local by = y + r * rowH
      lcd.color(labelColor(kinds[i], colors))
      local name, nameMax = labels[i], labelW - 4
      if lcd.getTextSize(name) > nameMax then name = ui.fit(name, nameMax) end
      lcd.drawText(bx, by + floor((rowH - th) / 2), name, LEFT)
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

  -- The throttle in percent of its 1000 - 2000 us travel (0 % at 1000 us).
  local function thrPct(us)
    if not us then return "--" end
    return string.format("%d %%", floor((us - 1000) / 10 + 0.5))
  end
  local function fcRangeText()
    local zero, full = heli.throttleEnds(rcConfig)
    return thrPct(zero) .. " - " .. thrPct(full)
  end
  local function measuredText()
    if low and high then return thrPct(low) .. " - " .. thrPct(high) end
    return "--"
  end

  -- The gas: one wide bar, with the FC's end points (muted ticks), the measured
  -- travel (an accent band) and the live position; under it, in percent, the
  -- value now, the FC's range and the measured travel.
  local function drawThrottle(x, y, w, h, colors)
    lcd.font(FONT_S)
    local _, th = lcd.getTextSize("Ag")
    local textH = 3 * (th + 2)
    if h < textH + 16 then return end
    local barH = math.min(36, h - textH - 12)
    local by = y + 4
    local zero, full = heli.throttleEnds(rcConfig)
    if low and high then
      lcd.color(colors.surface)
      local lx = x + floor(w * thrFrac(low))
      local hx = x + floor(w * thrFrac(high))
      lcd.drawFilledRectangle(lx, by + floor(barH / 2) - 6, math.max(2, hx - lx), 12)
    end
    ui.gauge(x, by, w, barH, thrNow and thrFrac(thrNow) or nil, colors)
    lcd.color(colors.muted)
    lcd.drawFilledRectangle(x + floor(w * thrFrac(zero)) - 1, by - 4, 3, barH + 8)
    lcd.drawFilledRectangle(x + floor(w * thrFrac(full)) - 1, by - 4, 3, barH + 8)
    local ty = by + barH + 12
    lcd.color(colors.text)
    lcd.drawText(x, ty, T.throttleName .. ": " .. thrPct(thrNow), LEFT)
    lcd.drawText(x, ty + th + 2, T.fcRange .. ": " .. fcRangeText(), LEFT)
    lcd.drawText(x, ty + 2 * (th + 2), T.measured .. ": " .. measuredText(), LEFT)
  end

  -- Bar setups (build only) ----------------------------------------------------

  local function clearBars()
    barCount = 0
    hotRow = nil
    for k in pairs(lastShown) do lastShown[k] = nil end
    for k in pairs(fracs) do fracs[k] = nil end
  end

  -- Sticks: each control's bar on the left two thirds, and on the right third
  -- the way it has to move and its live position in percent.
  local function drawSticks(x, y, w, h, colors)
    if barCount == 0 or h < 10 then return end
    lcd.font(FONT_S)
    local _, th = lcd.getTextSize("Ag")
    local rowH = math.min(floor(h / barCount), th + 12)
    local leftW = floor(w * 2 / 3)
    local longestName, longestOpp = 0, 0
    for i = 1, barCount do
      longestName = math.max(longestName, (lcd.getTextSize(labels[i] or "")))
      longestOpp = math.max(longestOpp, (lcd.getTextSize(oppWords[i] or "")))
    end
    local nameW = math.min(floor(leftW * 0.5), longestName + 10)
    local oppW = math.min(floor(leftW * 0.35), longestOpp + 10)
    local barX = x + nameW + oppW
    local barW = leftW - nameW - oppW - 8
    local colX = x + leftW + 8
    local colW = w - leftW - 8
    for i = 1, barCount do
      local by = y + (i - 1) * rowH
      local ty = by + floor((rowH - th) / 2)
      lcd.color(labelColor(kinds[i], colors))
      local name, nameMax = labels[i], nameW - 4
      if lcd.getTextSize(name) > nameMax then name = ui.fit(name, nameMax) end
      lcd.drawText(x, ty, name, LEFT)
      lcd.color(colors.muted)
      local opp, oppMax = oppWords[i] or "", oppW - 6
      if lcd.getTextSize(opp) > oppMax then opp = ui.fit(opp, oppMax) end
      lcd.drawText(x + nameW, ty, opp, LEFT)
      ui.gauge(barX, by + 2, barW, rowH - 4, fracs[i] or nil, colors, 0.48, 0.52)
      local p = pcts[i]
      local valueText = "--"
      if p then valueText = (p == 0) and "0 %" or string.format("%+d %%", p) end
      lcd.font(FONT_S)
      local tw = lcd.getTextSize(valueText)
      local reached = i > 4 or (travel[i][1] <= -TRAVEL_OK and travel[i][2] >= TRAVEL_OK)
      lcd.color(reached and colors.text or colors.active)
      lcd.drawText(colX + colW - tw, ty, valueText, LEFT)
      lcd.color(colors.muted)
      local word, maxW = sideWords[i] or "", colW - tw - 6
      if lcd.getTextSize(word) > maxW then word = ui.fit(word, maxW) end
      lcd.drawText(colX, ty, word, LEFT)
    end
  end

  local function stickBars()
    clearBars()
    barCount = FUNCTION_ROWS
    for i = 1, FUNCTION_ROWS do
      labels[i] = channelLabel(i)
      kinds[i] = KIND_TEXT
      fracs[i] = false
    end
    scr:draw(drawSticks)
  end

  local function functionBars(activeSlot)
    clearBars()
    barCount = FUNCTION_ROWS
    for i = 1, FUNCTION_ROWS do
      labels[i] = channelLabel(i)
      kinds[i] = (i == activeSlot) and KIND_ACTIVE or KIND_TEXT
      fracs[i] = false
    end
    scr:draw(drawBars)
  end

  -- Detect: one bar per receiver channel. A channel already given a function
  -- says which, in grey; the others are plain.
  local function channelBars()
    clearBars()
    readLocal()
    local n = math.min(RAW_ROWS, math.max(#localRaw, FUNCTION_ROWS))
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
    local raw = localRaw
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

  -- The throttle from the radio, as the bar: the measured band follows at once.
  -- The cross-check confirms that the FC receives the same.
  local function throttleWakeup()
    local us = localRc[5]
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

  -- Cross-check: the FC's raw channels against the radio's, for the five
  -- functions. A stick that moved while the read was out is not judged, nor is
  -- a channel the FC reads as 0 (no signal: the signal line says so).
  local function onCheck()
    checkInFlight = false
    -- A warning stays until its own stick has been judged again.
    local compared, found, judgedMismatch = false, nil, false
    for slot = 1, FUNCTION_ROWS do
      local ch = rxMap and rxMap[rxMapCodec.FIELDS[slot]]
      local snap = checkSnap[slot]
      local now = ch and localRaw[ch + 1]
      local fc = ch and checkRaw[ch + 1]
      if snap and now and fc and fc > 0 and math.abs(snap - now) <= CHECK_STILL then
        compared = true
        if slot == mismatch then judgedMismatch = true end
        if not found and math.abs(fc - now) > CHECK_TOLERANCE then found = slot end
      end
    end
    if not compared or found == mismatch then return end
    if not found and mismatch and not judgedMismatch then return end
    mismatch = found
    wiz.rebuild()
  end
  local function onCheckError() checkInFlight = false end

  local function checkWakeup(now)
    -- The simulator's MSP replies are made up (a sweep): nothing to compare with.
    if rcChannels.SIMULATED or not rxMap or not wiz.canMove() then return end
    if checkInFlight and now - checkAt <= CHECK_GIVE_UP then return end
    if now - checkAt < CHECK_POLL then return end
    checkInFlight, checkAt = true, now
    for slot = 1, FUNCTION_ROWS do
      local ch = rxMap[rxMapCodec.FIELDS[slot]]
      checkSnap[slot] = ch and localRaw[ch + 1] or false
    end
    local m = rcChannels.buildReadMessage(rcChannels.RX_CHANNELS_COMMAND, checkRaw, onCheck, onCheckError)
    m.maxRetries = 0
    bus.publish("msp.request", m)
  end

  -- The mismatch, as a line: "The FC reads Roll (CH1) differently ...".
  local function mismatchLine()
    return mismatch and string.format(T.mismatchFmt, channelLabel(mismatch)) or nil
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

    if screen == "prepare" then
      scr:text(T.prepareTitle, T.prepareText)
      scr:picture(receiverPicture)
      scr:step(1, RECEIVER_SCREENS)
      local function answer(key, index)
        return function()
          answers[key], answered = not answers[key], index
          wiz.rebuild()
        end
      end
      local ready = answers.unplugged and answers.blades
      -- Focus: Next once both are Yes, else the answer just pressed, else the first No.
      local answerField = scr:checks({
        {label = T.unplugged, answer = answers.unplugged and T.yes or T.no, press = answer("unplugged", 1)},
        {label = T.blades, answer = answers.blades and T.yes or T.no, press = answer("blades", 2)},
      }, (not ready) and (answered or (not answers.unplugged and 1) or 2) or nil)
      answered = nil
      -- As the other steps: Start goes into the step, Next leaves it.
      local rowField = scr:row(nil, {{text = T.start, primary = ready, disabled = not ready,
        press = function() go("link") end}})
      return answerField or rowField

    elseif screen == "link" then
      -- The EdgeTX suite's receiver card, without its unlock: the protocol and the
      -- restart, which cut the link the radio talks over (the warning says so).
      scr:text(T.title, T.linkText, T.linkWarn)
      scr:picture(receiverPicture)
      scr:step(2, RECEIVER_SCREENS)
      local rows = {
        {label = T.protocol, answer = protocolName(currentProtocol()), press = function() go("protocol") end},
        {answer = T.saveRestart, press = function()
          wiz.setResume("link")
          wiz.saveAndReboot()
        end},
      }
      local field = scr:checks(rows)
      local rowField = scr:row(function() go("prepare") end, nil, {text = T.next, press = function() go("order") end})
      return field or rowField

    elseif screen == "protocol" then
      scr:text(T.protocolTitle)
      scr:step(2, RECEIVER_SCREENS)
      local current = currentProtocol()
      local specs = {}
      for _, p in ipairs(protocolList()) do
        specs[#specs + 1] = {text = p[2], primary = p[1] == current, press = function()
          setProtocol(p[1])
          go("link")
        end}
      end
      scr:row(function() go("link") end, nil, false)
      return scr:grid(specs, 4)

    elseif screen == "order" then
      -- The signal check is on this card too (it was the intro screen): the
      -- status line, and the live bars that show the sticks reaching the FC.
      local signalLine = (signal == true and T.signalOk) or (signal == false and T.signalNone) or nil
      scr:text(T.orderTitle, T.orderText, noteAccent)
      scr:step(3, RECEIVER_SCREENS)
      -- The bars on the left, as the other screens' pictures; the detection and
      -- the standard order on the right, as the EdgeTX card.
      functionBars(nil)
      -- The signal line and the result of a detection sit under the buttons: the
      -- bars keep their place.
      local rows = {
        {answer = T.detect, needsMotion = true, press = startDetect},
        {label = T.standardOrder, answer = presetName(mapArray(rxMap)), press = function() go("presets") end},
      }
      if signalLine then rows[#rows + 1] = {note = signalLine} end
      if mismatch then rows[#rows + 1] = {note = mismatchLine()} end
      if note then rows[#rows + 1] = {note = note} end
      local field = scr:checks(rows)
      -- The navigation row is always drawn; the focus is the checks' field, if any.
      local rowField = scr:row(function() go("link") end, nil, {text = T.next, press = function() go("sticks") end})
      return field or rowField

    elseif screen == "presets" then
      scr:text(T.orderTitle, T.presetsText)
      scr:step(3, RECEIVER_SCREENS)
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
      -- The detection is part of the channel order step, not a step of its own.
      scr:step(3, RECEIVER_SCREENS)
      channelBars()
      return scr:row(function() go("order") end, {
        {text = T.skip, press = function() nextStick(nil) end},
      }, false)

    elseif screen == "sticks" then
      scr:text(T.sticksTitle, T.sticksText, mismatchLine())
      scr:step(4, RECEIVER_SCREENS)
      stickBars()
      return scr:row(function() go("order") end, nil,
        {text = T.next, disabled = not travelOk(), press = function() go("throttle") end})

    elseif screen == "throttle" then
      local accent = noteAccent or mismatchLine() or T.bladesOff
      scr:text(T.throttleTitle, T.throttleText, accent)
      scr:step(5, RECEIVER_SCREENS)
      scr:draw(drawThrottle)
      local canUse = heli.throttleFromMeasured(low, high) ~= nil and not measuring and not applied
      local field = scr:checks({
        {answer = measuring and T.stop or T.measure, press = function()
          if measuring then
            measuring = false
            if not heli.throttleFromMeasured(low, high) then noteAccent = T.tooShort end
          else
            measuring, low, high, noteAccent, applied = true, nil, nil, nil, false
          end
          wiz.rebuild()
        end},
        {answer = T.use, disabled = not canUse, press = function()
          local minUs, maxUs = heli.throttleFromMeasured(low, high)
          if minUs then writeThrottle(minUs, maxUs) end
          applied = true
          wiz.rebuild()
        end},
        {answer = T.defaults, press = function()
          writeThrottle(0, 0)
          wiz.rebuild()
        end},
      }, canUse and 2 or 1)
      local rowField = scr:row(function() go("sticks") end, nil,
        {text = T.next, disabled = measuring, press = function() go("done") end})
      return field or rowField

    else -- done
      -- What is set now, beside the receiver; the text says what the way forward
      -- does: Next when nothing changed, Save and continue when the EEPROM is owed.
      scr:text(T.doneTitle, wiz.hasPending() and T.doneSave or T.doneKeep)
      scr:picture(receiverPicture)
      scr:step(6, RECEIVER_SCREENS)
      scr:checks({
        {label = T.protocol, value = protocolName(currentProtocol())},
        {label = T.orderTitle, value = presetName(mapArray(rxMap))},
        {label = T.throttleTitle, value = fcRangeText()},
      })
      return scr:row(function() go("throttle") end)
    end
  end

  function self.paint() scr:paint() end

  function self.wakeup(now)
    local fresh = false
    if (screen == "order" or screen == "detect" or screen == "sticks" or screen == "throttle")
        and now - localAt >= LOCAL_READ then
      localAt = now
      readLocal()
      fresh = true
    end
    if screen == "order" then
      if now >= statusAt then
        statusAt = now + STATUS_POLL
        -- Sent once, as the live reads: the next check is the retry.
        local m = status.buildReadMessage(function(data)
          local fs = rxFailsafe(data and data.arming_disable_flags)
          if fs == nil then return end
          local ok = not fs
          if ok ~= signal then
            signal = ok
            wiz.rebuild()
          end
        end)
        m.maxRetries = 0
        bus.publish("msp.request", m)
      end
    elseif screen == "detect" then
      if fresh then detectWakeup() end
    elseif screen == "throttle" then
      throttleWakeup()
    end
    if fresh and barCount > 0 and readBars() then wiz.invalidate() end
    -- The order screen asks the FC for its status already; the check waits there
    -- for the other half of the status interval.
    if screen == "sticks" or screen == "throttle" or screen == "order" then checkWakeup(now) end
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
