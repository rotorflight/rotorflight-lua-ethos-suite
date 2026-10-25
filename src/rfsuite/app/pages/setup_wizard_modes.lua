-- Setup Wizard step: Mode switches. Opened by app/pages/setup_wizard.lua.
--
-- The radio's version of rotorflight-configurator's StepModes.svelte: ARM
-- (required), Rescue and Trainer put on switches. Press Assign, flick the
-- switch: the step sees which AUX channel moved and where it ended up, and
-- writes a mode range for that position (heli.rangeForSwitch(), the
-- Configurator's rangeForSwitch()). One screen per mode, as the radio has no
-- room for the Configurator's three cards side by side:
--
--   prepare   blades off and servos unplugged, both Yes before Start
--   arm       ARM; Next waits until it is on a switch
--   rescue    Rescue, if the FC offers it (it needs an accelerometer)
--   trainer   Trainer, likewise
--   done      a block per mode, as the Configurator's cards: where it is set
--             and, live, whether its switch has it on (a check of the
--             switches); and whether Next or Save and continue
--
-- The switches are read from the radio's own channel outputs, as the receiver
-- step's bars (no MSP polling: on S.Port, F.Port and FBUS each MSP reply blanks
-- the FC's sensor telemetry for 250 ms). MSP reads the box IDs and the mode
-- ranges once, and writes one MSP_SET_MODE_RANGE per assignment; each write is
-- registered with wiz.change() for Discard. Arming stays blocked by the wizard
-- while a switch is assigned.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")
-- Freed when the step closes. Not msp_rx_map: the background task's session
-- reads it on every connect.
local OWNED = ui.notLoaded({"rfsuite.lib.msp_modes"})
local modes = requireModule("lib/msp_modes.lua")
local rxMapCodec = requireModule("lib/msp_rx_map.lua")

local floor = math.floor

local T = {
  title = "@i18n(app.modules.setup_wizard.step_modes)@",
  prepareTitle = "@i18n(app.modules.setup_wizard.rcv_prepare_title)@",
  intro = "@i18n(app.modules.setup_wizard.mod_intro)@",
  unplugged = "@i18n(app.modules.setup_wizard.sen_servos_unplugged)@",
  blades = "@i18n(app.modules.setup_wizard.sen_blades_removed)@",
  yes = "@i18n(app.modules.setup_wizard.btn_yes)@",
  no = "@i18n(app.modules.setup_wizard.btn_no)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
  required = "@i18n(app.modules.setup_wizard.mod_required)@",
  assign = "@i18n(app.modules.setup_wizard.mod_assign)@",
  reassign = "@i18n(app.modules.setup_wizard.mod_reassign)@",
  remove = "@i18n(app.modules.setup_wizard.mod_remove)@",
  cancel = "@i18n(app.modules.setup_wizard.mod_cancel)@",
  listening = "@i18n(app.modules.setup_wizard.mod_listening)@",
  noSwitch = "@i18n(app.modules.setup_wizard.mod_no_switch)@",
  noSlot = "@i18n(app.modules.setup_wizard.mod_no_slot)@",
  notSet = "@i18n(app.modules.setup_wizard.mod_not_set)@",
  rangeFmt = "@i18n(app.modules.setup_wizard.mod_range_fmt)@",
  on = "@i18n(app.modules.setup_wizard.mod_on)@",
  off = "@i18n(app.modules.setup_wizard.mod_off)@",
  doneTitle = "@i18n(app.modules.setup_wizard.mod_done_title)@",
  doneKeep = "@i18n(app.modules.setup_wizard.mod_done_keep)@",
  doneSave = "@i18n(app.modules.setup_wizard.rcv_done_save)@",
}

-- Permanent box IDs (rotorflight-firmware msp/msp_box.c), as the Configurator.
local MODES = {
  {id = 0, key = "arm", icon = "arm", required = true,
    name = "@i18n(app.modules.setup_wizard.mod_arm)@",
    help = "@i18n(app.modules.setup_wizard.mod_help_arm)@"},
  {id = 53, key = "rescue", icon = "rescue",
    name = "@i18n(app.modules.setup_wizard.mod_rescue)@",
    help = "@i18n(app.modules.setup_wizard.mod_help_rescue)@"},
  {id = 47, key = "trainer", icon = "trainer",
    name = "@i18n(app.modules.setup_wizard.mod_trainer)@",
    help = "@i18n(app.modules.setup_wizard.mod_help_trainer)@"},
}

local CONTROL_CHANNELS = 5          -- roll, pitch, yaw, collective, throttle
local AUX_MAPPED = {"aux1", "aux2", "aux3"}  -- AUX1-3 go through the RX map
local LOCAL_CHANNELS = 16
-- Ethos -1024..1024 is -100..+100 %: 1500 +- 512 us on F.Port, FBUS and CRSF.
local US_PER_UNIT = 512 / 1024
local LOCAL_READ = 0.1
-- The Configurator's detection: a switch, not stick noise; where it ended up
-- once it has settled; given up after a while.
local MOVE_US = 300
local SETTLE = 0.4
local LISTEN = 15
local EMPTY_RANGE = {start = 1500, ["end"] = 1500}
local CHANNEL_MIN, CHANNEL_MAX = 900, 2100
-- SwitchFlick's animation: 1.4 s, the lever held at each end and flicked over.
local FLICK_PERIOD = 1.4
local FLICK_ANGLE = 28

-- The Configurator's rangeForSwitch(): centred on where the switch landed,
-- half-way back to where it started, out to the end stop at an end; 25 us steps.
local function rangeForSwitch(from, to)
  local half = math.abs(to - from) / 2
  local start = floor((to - half) / 25 + 0.5) * 25
  local stop = floor((to + half) / 25 + 0.5) * 25
  if to > 1900 then stop = CHANNEL_MAX end
  if to < 1100 then start = CHANNEL_MIN end
  return {start = math.max(CHANNEL_MIN, start), ["end"] = math.min(CHANNEL_MAX, stop)}
end

-- SwitchFlick's keyframes: -28 until 35 %, over to +28 by 50 %, held until
-- 85 %, back by 100 %; eased.
local function flickAngle(now)
  local p = (now % FLICK_PERIOD) / FLICK_PERIOD
  local f
  if p < 0.35 then f = 0
  elseif p < 0.5 then f = (p - 0.35) / 0.15
  elseif p < 0.85 then f = 1
  else f = 1 - (p - 0.85) / 0.15 end
  f = f * f * (3 - 2 * f)
  return floor(-FLICK_ANGLE + 2 * FLICK_ANGLE * f + 0.5)
end

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  self.liveRc = nil

  local screen = "prepare"
  local answers = {blades = false, unplugged = false}
  local answered = nil
  local note = nil
  local loadFailed = false
  local rxMap, ranges, extras, boxIds = nil, nil, nil, nil
  local offered = {}               -- the MODES this FC has, in order
  local screens = {}               -- "prepare", one per offered mode, "done"
  local current = nil              -- the mode of this screen

  -- The picture; its live fields follow the switch (wakeup).
  local picture = art.modeSwitch(nil)
  -- The summary's blocks, set on build; on follows the switch (wakeup).
  local blocks = {}

  -- The radio's channel outputs, in us, by receiver channel.
  local chanSources = {}
  local localRaw = {}
  local localAt = 0
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
  end

  -- The receiver channel (1-based) behind AUX channel aux (0 = AUX1): AUX1-3
  -- through the RX map (firmware rx/rx.c readRxChannels), the rest in order.
  local function auxChannel(aux)
    if aux < #AUX_MAPPED then
      local ch = rxMap and rxMap[AUX_MAPPED[aux + 1]]
      return ch and (ch + 1) or nil
    end
    return CONTROL_CHANNELS + aux + 1
  end
  local function auxValue(aux)
    local ch = auxChannel(aux)
    return ch and localRaw[ch] or nil
  end
  local function auxCount()
    return math.max(0, #localRaw - CONTROL_CHANNELS)
  end

  -- Mode ranges ------------------------------------------------------------

  local function slotOf(mode)
    if not ranges then return nil end
    for i, r in ipairs(ranges) do
      if r.id == mode.id and r.range.start < r.range["end"] then return i end
    end
    return nil
  end
  local function freeSlot()
    for i, r in ipairs(ranges or {}) do
      if not (r.range.start < r.range["end"]) then return i end
    end
    return nil
  end
  local function assignment(mode)
    local i = slotOf(mode)
    return i and ranges[i] or nil
  end
  local function isOn(r)
    local v = r and auxValue(r.auxChannelIndex)
    return v ~= nil and v >= r.range.start and v <= r.range["end"]
  end
  local function rangeText(r)
    return string.format(T.rangeFmt, auxChannel(r.auxChannelIndex) or (CONTROL_CHANNELS + r.auxChannelIndex + 1),
      r.range.start, r.range["end"])
  end

  -- Each slot written is put back on Discard, with its own logic and link.
  local touched = {}
  local function writeSlot(index, id, aux, range)
    wiz.change("mode_ranges", ranges, function(o)
      for i in pairs(touched) do
        if o[i] then
          local e = extras and extras[i] or {}
          bus.publish("msp.request", modes.buildSetModeRangeMessage(i, o[i],
            {modeLogic = e.modeLogic or 0, linkedTo = e.linkedTo or 0}))
        end
      end
    end)
    touched[index] = true
    ranges[index] = {id = id, auxChannelIndex = aux, range = {start = range.start, ["end"] = range["end"]}}
    bus.publish("msp.request", modes.buildSetModeRangeMessage(index, ranges[index], {modeLogic = 0, linkedTo = 0}))
  end

  local function save(mode, aux, from, to)
    local index = slotOf(mode) or freeSlot()
    if not index then
      note = T.noSlot
      return
    end
    writeSlot(index, mode.id, aux, rangeForSwitch(from, to))
  end

  local function remove(mode)
    local index = slotOf(mode)
    if index then writeSlot(index, 0, 0, EMPTY_RANGE) end
  end

  -- Listening: the AUX channel that moved furthest from where it was when
  -- Assign was pressed; once it has settled, where it ended up.
  local listening = nil              -- the mode being assigned
  local baseline = {}
  local listenUntil, settleAt, settleAux = 0, nil, nil

  local function stopListening()
    listening, settleAt, settleAux = nil, nil, nil
  end

  local function listen(mode)
    readLocal()
    for k in pairs(baseline) do baseline[k] = nil end
    for aux = 0, auxCount() - 1 do baseline[aux] = auxValue(aux) end
    listening, note = mode, nil
    listenUntil, settleAt, settleAux = os.clock() + LISTEN, nil, nil
  end

  local function listenWakeup(now)
    if settleAt then
      if now < settleAt then return end
      local aux = settleAux
      local from, to = baseline[aux], auxValue(aux)
      local mode = listening
      stopListening()
      if from and to and math.abs(to - from) > MOVE_US then save(mode, aux, from, to) end
      wiz.rebuild()
      return
    end
    if now > listenUntil then
      stopListening()
      note = T.noSwitch
      wiz.rebuild()
      return
    end
    local best, bestMove = nil, MOVE_US
    for aux = 0, auxCount() - 1 do
      local v, b = auxValue(aux), baseline[aux]
      if v and b and math.abs(v - b) > bestMove then best, bestMove = aux, math.abs(v - b) end
    end
    if best then settleAt, settleAux = now + SETTLE, best end
  end

  -- Screens ----------------------------------------------------------------

  local function screenIndex(name)
    for i, s in ipairs(screens) do if s == name then return i end end
    return 1
  end

  local function modeOf(name)
    for _, m in ipairs(offered) do if m.key == name then return m end end
    return nil
  end

  local function go(name)
    stopListening()
    screen, note, answered = name, nil, nil
    current = modeOf(name)
    wiz.rebuild()
  end

  local function neighbour(delta)
    return screens[screenIndex(screen) + delta]
  end

  wiz.fetch({
    map = function(ok, err) return rxMapCodec.buildReadMessage(ok, err) end,
    ranges = function(ok, err) return modes.buildModeRangesReadMessage(ok, err) end,
    extras = function(ok, err) return modes.buildModeRangesExtraReadMessage(ok, err) end,
    ids = function(ok, err) return modes.buildBoxIdsReadMessage(ok, err) end,
  }, function(results, failed)
    rxMap, ranges, extras, boxIds = results.map, results.ranges, results.extras, results.ids
    loadFailed = failed or not rxMap or not ranges or not boxIds
    -- The modes this FC offers. The simulator's box list has no Trainer: there
    -- all three are shown.
    local has = {}
    for _, id in ipairs(boxIds or {}) do has[id] = true end
    local sim = system.getVersion and system.getVersion().simulation == true
    for _, m in ipairs(MODES) do
      if has[m.id] or sim then offered[#offered + 1] = m end
    end
    screens[1] = "prepare"
    for _, m in ipairs(offered) do screens[#screens + 1] = m.key end
    screens[#screens + 1] = "done"
    wiz.rebuild()
  end)

  -- The live picture: the lever flicks while listening, and otherwise stands
  -- where the mode's switch is (low end left, high end right).
  local function pictureState(now)
    local r = current and assignment(current)
    if listening then return flickAngle(now), "listen" end
    if r then
      local v = auxValue(r.auxChannelIndex)
      local f = v and math.max(0, math.min(1, (v - 1000) / 1000)) or 0
      return floor(-FLICK_ANGLE + 2 * FLICK_ANGLE * f + 0.5), isOn(r) and "on" or "off"
    end
    return -FLICK_ANGLE, "off"
  end

  -- The summary: a block per mode side by side. Top: icon and name; then the
  -- channel and the range on lines of their own; at the foot On / Off in the
  -- colour of the state. The frame is green while the mode is on.
  local function drawSummary(x, y, w, h, colors)
    local n = #blocks
    if n == 0 or h < 40 then return end
    local gap = 12
    local bw = floor((w - gap * (n - 1)) / n)
    lcd.font(FONT_STD)
    local _, th = lcd.getTextSize("Ag")
    lcd.font(FONT_S)
    local _, lh = lcd.getTextSize("Ag")
    local pad = 8
    local bh = math.min(h, 2 * pad + th + 6 + 2 * lh + 8 + th)
    for i = 1, n do
      local b = blocks[i]
      local bx = x + (i - 1) * (bw + gap)
      lcd.color((b.assigned and b.on) and colors.good or colors.body)
      lcd.drawRectangle(bx, y, bw, bh, 2)
      local cy = y + pad
      local isz = th
      art.modeIcon(b.icon, bx + pad + floor(isz / 2), cy + floor(isz / 2), isz, colors.text)
      lcd.font(FONT_STD)
      lcd.color(colors.text)
      local nameX = bx + pad + isz + 6
      local name, maxW = b.name, bx + bw - pad - nameX
      if lcd.getTextSize(name) > maxW then name = ui.fit(name, maxW) end
      lcd.drawText(nameX, cy, name, LEFT)
      cy = cy + th + 6
      lcd.font(FONT_S)
      if b.assigned then
        lcd.color(colors.text)
        lcd.drawText(bx + pad, cy, b.line1, LEFT)
        lcd.color(colors.muted)
        local l2 = b.line2
        if lcd.getTextSize(l2) > bw - 2 * pad then l2 = ui.fit(l2, bw - 2 * pad) end
        lcd.drawText(bx + pad, cy + lh, l2, LEFT)
        lcd.font(FONT_STD)
        lcd.color(b.on and colors.good or colors.muted)
        lcd.drawText(bx + pad, y + bh - pad - th, b.on and T.on or T.off, LEFT)
      else
        lcd.color(colors.muted)
        lcd.drawText(bx + pad, cy, T.notSet, LEFT)
      end
    end
  end

  function self.build()
    scr:begin()
    if not ranges and not loadFailed then
      scr:text(T.title, "@i18n(app.msg_loading)@")
      return nil
    end
    if loadFailed then
      scr:text(T.title, "@i18n(app.msg_load_failed_body)@")
      return scr:row(nil)
    end
    local n = #screens

    if screen == "prepare" then
      -- As the other steps' safety cards, with the switch.
      scr:text(T.prepareTitle, T.intro)
      scr:picture(picture)
      scr:step(1, n)
      local function answer(key, index)
        return function()
          answers[key], answered = not answers[key], index
          wiz.rebuild()
        end
      end
      local ready = answers.unplugged and answers.blades
      local answerField = scr:checks({
        {label = T.unplugged, answer = answers.unplugged and T.yes or T.no, press = answer("unplugged", 1)},
        {label = T.blades, answer = answers.blades and T.yes or T.no, press = answer("blades", 2)},
      }, (not ready) and (answered or (not answers.unplugged and 1) or 2) or nil)
      answered = nil
      local rowField = scr:row(nil, {{text = T.start, primary = ready, disabled = not ready,
        press = function() go(screens[2]) end}})
      return answerField or rowField

    elseif screen == "done" then
      -- A block per mode; the range text "CH6 (1500 - 2100 us)" is split into the
      -- channel and the range in brackets, one line each.
      scr:text(T.doneTitle, wiz.hasPending() and T.doneSave or T.doneKeep)
      scr:step(n, n)
      for i = #blocks, 1, -1 do blocks[i] = nil end
      for i, m in ipairs(offered) do
        local r = assignment(m)
        local text = r and rangeText(r) or ""
        local line1, line2 = text:match("^(.-)%s*%((.*)%)%s*$")
        blocks[i] = {mode = m, icon = m.icon, name = m.name, assigned = r ~= nil,
          line1 = line1 or text, line2 = line2 or "", on = isOn(r)}
      end
      scr:draw(drawSummary)
      return scr:row(function() go(neighbour(-1)) end)

    else
      -- One mode: its icon over the switch, what it does, and where it is set.
      local mode = current
      local r = assignment(mode)
      scr:text(mode.name, mode.help)
      scr:titleExtras(mode.icon, mode.required and T.required or nil)
      picture.angle, picture.state = pictureState(os.clock())
      scr:picture(picture)
      scr:step(screenIndex(screen), n)
      -- "CH6 (1500 - 2100 us)" as two lines: the channel with On / Off beside it
      -- (row 1, live), the range under it.
      local rows = {}
      if r then
        local text = rangeText(r)
        local ch, range = text:match("^(.-)%s*%((.*)%)%s*$")
        rows[1] = {label = ch or text, value = isOn(r) and T.on or T.off}
        if range then rows[2] = {label = range} end
      else
        rows[1] = {label = T.notSet}
      end
      rows[#rows + 1] = {answer = listening and T.cancel or (r and T.reassign or T.assign), press = function()
        if listening then stopListening() else listen(mode) end
        wiz.rebuild()
      end}
      if r and not listening then
        rows[#rows + 1] = {answer = T.remove, press = function()
          remove(mode)
          wiz.rebuild()
        end}
      end
      if listening then
        rows[#rows + 1] = {note = T.listening}
      elseif note then
        rows[#rows + 1] = {note = note}
      end
      local field = scr:checks(rows, #rows > 0 and (r and 3 or 2) or nil)
      -- ARM is required: Next once it is on a switch.
      local rowField = scr:row(function() go(neighbour(-1)) end, nil,
        {text = T.next, disabled = (mode.required and not r) or listening ~= nil,
          press = function() go(neighbour(1)) end})
      if r and not listening and rowField then return rowField end
      return field or rowField
    end
  end

  function self.paint() scr:paint() end

  function self.wakeup(now)
    if not ranges or screen == "prepare" then return end
    if now - localAt >= LOCAL_READ then
      localAt = now
      readLocal()
      if listening then listenWakeup(now) end
      if current and not listening then
        local r = assignment(current)
        if r and scr:setCheckValue(1, isOn(r) and T.on or T.off) then wiz.invalidate() end
      end
      if screen == "done" then
        local changed = false
        for i = 1, #blocks do
          local on = isOn(assignment(blocks[i].mode))
          if on ~= blocks[i].on then
            blocks[i].on = on
            changed = true
          end
        end
        if changed then wiz.invalidate() end
      end
    end
    if current then
      local angle, state = pictureState(now)
      if math.abs(angle - (picture.angle or 0)) >= 2 or state ~= picture.state then
        picture.angle, picture.state = angle, state
        wiz.invalidate()
      end
    end
  end

  function self.released() scr:refresh() end
  function self.leave() stopListening() end

  return self
end

return {new = new, owned = OWNED}
