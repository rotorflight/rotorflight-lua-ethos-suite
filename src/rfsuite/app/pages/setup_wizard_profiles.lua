-- Setup Wizard step: Profiles & gain. Opened by app/pages/setup_wizard.lua.
--
-- The radio's version of rotorflight-configurator's StepProfiles.svelte: one
-- switch picks the PID profile (and, if chosen, the rate profile), and master
-- gain in flight takes trim buttons or a knob on a spare channel. Each screen
-- of the step:
--
--   prepare   blades off and servos unplugged, both on before Start
--   profile   the profile switch: how it is used, Assign, then move it through
--             every position; Use writes the profile range
--   gain      master gain in flight: trim buttons, knob, or not used
--   channels  the channels in use (ARM, Rescue, Trainer, the profile switch,
--             the gain channel), and whether Next or Save and continue follows
--
-- The adjustment ranges are read slot by slot (as the Adjustments page does) and
-- each change is one MSP_SET_ADJUSTMENT_RANGE, registered with wiz.change() for
-- Discard. The switches and knobs are read from the radio's own channel outputs,
-- as the other steps (on S.Port, F.Port and FBUS an MSP reply blanks the FC's
-- sensor telemetry for 250 ms).

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")
-- Freed when the step closes.
local OWNED = ui.notLoaded({"rfsuite.lib.msp_adjustments", "rfsuite.lib.msp_modes", "rfsuite.lib.setup_wizard_adjust"})
local adjMsp = requireModule("lib/msp_adjustments.lua")
local modesMsp = requireModule("lib/msp_modes.lua")
local rxMapCodec = requireModule("lib/msp_rx_map.lua")
local A = requireModule("lib/setup_wizard_adjust.lua")

local floor = math.floor

local T = {
  title = "@i18n(app.modules.setup_wizard.step_profiles)@",
  prepareTitle = "@i18n(app.modules.setup_wizard.rcv_prepare_title)@",
  intro = "@i18n(app.modules.setup_wizard.prof_intro)@",
  unplugged = "@i18n(app.modules.setup_wizard.sen_servos_unplugged)@",
  blades = "@i18n(app.modules.setup_wizard.sen_blades_removed)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
  assign = "@i18n(app.modules.setup_wizard.mod_assign)@",
  reassign = "@i18n(app.modules.setup_wizard.mod_reassign)@",
  cancel = "@i18n(app.modules.setup_wizard.mod_cancel)@",
  noSwitch = "@i18n(app.modules.setup_wizard.mod_no_switch)@",
  notSet = "@i18n(app.modules.setup_wizard.mod_not_set)@",
  profileTitle = "@i18n(app.modules.setup_wizard.prof_switch_title)@",
  profileText = "@i18n(app.modules.setup_wizard.prof_switch_text)@",
  methodBoth = "@i18n(app.modules.setup_wizard.prof_both)@",
  methodPid = "@i18n(app.modules.setup_wizard.prof_pid)@",
  methodNone = "@i18n(app.modules.setup_wizard.prof_none)@",
  chosen = "@i18n(app.modules.setup_wizard.prof_chosen)@",
  countFmt = "@i18n(app.modules.setup_wizard.prof_count_fmt)@",
  nowProfile = "@i18n(app.modules.setup_wizard.prof_now_fmt)@",
  listenProfile = "@i18n(app.modules.setup_wizard.prof_listen)@",
  found = "@i18n(app.modules.setup_wizard.prof_found_fmt)@",
  use = "@i18n(app.modules.setup_wizard.prof_use)@",
  gainTitle = "@i18n(app.modules.setup_wizard.prof_gain_title)@",
  gainText = "@i18n(app.modules.setup_wizard.prof_gain_text)@",
  gainButtons = "@i18n(app.modules.setup_wizard.prof_gain_buttons)@",
  gainKnob = "@i18n(app.modules.setup_wizard.prof_gain_knob)@",
  gainNone = "@i18n(app.modules.setup_wizard.prof_gain_none)@",
  gainButtonsNote = "@i18n(app.modules.setup_wizard.prof_gain_buttons_note)@",
  gainKnobNote = "@i18n(app.modules.setup_wizard.prof_gain_knob_note)@",
  gainNow = "@i18n(app.modules.setup_wizard.prof_gain_now)@",
  listenButtons = "@i18n(app.modules.setup_wizard.prof_listen_buttons)@",
  listenKnob = "@i18n(app.modules.setup_wizard.prof_listen_knob)@",
  chTitle = "@i18n(app.modules.setup_wizard.prof_channels_title)@",
  on = "@i18n(app.modules.setup_wizard.mod_on)@",
  off = "@i18n(app.modules.setup_wizard.mod_off)@",
  chRow = "@i18n(app.modules.setup_wizard.prof_channel_fmt)@",
  useProfile = "@i18n(app.modules.setup_wizard.prof_use_profile)@",
  useGain = "@i18n(app.modules.setup_wizard.prof_use_gain)@",
  beyond8 = "@i18n(app.modules.setup_wizard.prof_beyond8)@",
  full = "@i18n(app.modules.setup_wizard.prof_full)@",
  doneKeep = "@i18n(app.modules.setup_wizard.prof_done_keep)@",
  doneSave = "@i18n(app.modules.setup_wizard.prof_done_save)@",
  loading = "@i18n(app.msg_loading)@",
  loadFailed = "@i18n(app.msg_load_failed_body)@",
}

-- Mode names for the channel list (ids as on the FC, rotorflight-firmware msp_box.c).
local MODE_NAMES = {
  [0] = "@i18n(app.modules.setup_wizard.mod_arm)@",
  [53] = "@i18n(app.modules.setup_wizard.mod_rescue)@",
  [47] = "@i18n(app.modules.setup_wizard.mod_trainer)@",
}

local BUTTON_NAMES = {
  cyclicDown = "@i18n(app.modules.setup_wizard.prof_btn_cyclic_down)@",
  cyclicUp = "@i18n(app.modules.setup_wizard.prof_btn_cyclic_up)@",
  yawDown = "@i18n(app.modules.setup_wizard.prof_btn_yaw_down)@",
  yawUp = "@i18n(app.modules.setup_wizard.prof_btn_yaw_up)@",
}

local PROFILE_HELP = {
  both = "@i18n(app.modules.setup_wizard.prof_help_both)@",
  pid = "@i18n(app.modules.setup_wizard.prof_help_pid)@",
  none = "@i18n(app.modules.setup_wizard.prof_help_none)@",
}
local GAIN_HELP = {
  buttons = "@i18n(app.modules.setup_wizard.prof_gain_help_buttons)@",
  knob = "@i18n(app.modules.setup_wizard.prof_gain_help_knob)@",
  none = "@i18n(app.modules.setup_wizard.prof_gain_help_none)@",
}

local METHODS = {
  {key = "both", text = T.methodBoth},
  {key = "pid", text = T.methodPid},
  {key = "none", text = T.methodNone},
}
local GAINS = {
  {key = "buttons", text = T.gainButtons},
  {key = "knob", text = T.gainKnob},
  {key = "none", text = T.gainNone},
}

local CONTROL_CHANNELS = A.CONTROL_CHANNELS
local AUX_MAPPED = {"aux1", "aux2", "aux3"}  -- AUX1-3 go through the RX map
local LOCAL_CHANNELS = 16
-- Ethos -1024..1024 is -100..+100 %: 1500 +- 512 us on F.Port, FBUS and CRSF.
local US_PER_UNIT = 512 / 1024
local LOCAL_READ = 0.1
-- How far a channel must move to be the switch (profile), a trim button (buttons)
-- or the knob, and how long to listen.
local MOVE_US = {profile = 300, buttons = 100, knob = 250}
local LISTEN = 20
local SETTLE = 0.4
local RECORD_STEP_US = 20
local RECORD_MAX = 300
-- SwitchFlick's animation, as on the mode switch screens.
local FLICK_PERIOD = 1.4
local FLICK_ANGLE = 28

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  self.liveRc = nil

  local screen = "prepare"
  local answers = {blades = false, unplugged = false}
  local answered = nil
  local note = nil
  local rxMap = nil
  local modeRanges = nil
  local loadFailed = false
  local full = false

  -- The adjustment ranges, read slot by slot.
  local ranges = {}
  local adjIndex = 0
  local adjLoaded, adjFailed = false, false
  local touched = {}
  local chosen = nil            -- the profile method picked here (nil: as on the FC)
  local chosenGain = nil        -- the gain method picked here (nil: as on the FC)

  local picture = art.modeSwitch(nil)
  picture.helpSlots = 4
  -- The first screen shows the PIDs icon, inverted for the dark screen.
  local pidsPicture = art.image("pids-inv", 140, 140, true)
  local screens = {"prepare", "profile", "gain", "channels"}
  local SCREEN_COUNT = #screens

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
  -- through the RX map, the rest in order.
  local function auxChannel(aux)
    if aux < #AUX_MAPPED then
      local ch = rxMap and rxMap[AUX_MAPPED[aux + 1]]
      return ch and (ch + 1) or nil
    end
    return CONTROL_CHANNELS + aux + 1
  end
  local function auxValue(aux)
    if aux == nil then return nil end
    local ch = auxChannel(aux)
    return ch and localRaw[ch] or nil
  end
  local function auxCount()
    return math.max(0, #localRaw - CONTROL_CHANNELS)
  end

  -- Writes ------------------------------------------------------------------

  -- Restores the slots written since the last save, on Discard.
  local function writeRange(range)
    local index = A.slotFor(ranges, range.adjFunction)
    if not index then
      full = true
      wiz.rebuild()
      return false
    end
    -- Registered before the change, so the copy holds the old values.
    wiz.change("adjustment_ranges", ranges, function(o)
      for i in pairs(touched) do
        if o[i] then bus.publish("msp.request", adjMsp.buildWriteMessage(i, o[i])) end
      end
    end)
    touched[index] = true
    ranges[index] = range
    bus.publish("msp.request", adjMsp.buildWriteMessage(index, range))
    return true
  end

  local function removeFunction(adjFunction)
    for i = 1, #ranges do
      if ranges[i] and ranges[i].adjFunction == adjFunction then
        wiz.change("adjustment_ranges", ranges, function(o)
          for j in pairs(touched) do
            if o[j] then bus.publish("msp.request", adjMsp.buildWriteMessage(j, o[j])) end
          end
        end)
        touched[i] = true
        ranges[i] = adjMsp.defaultRange()
        bus.publish("msp.request", adjMsp.buildWriteMessage(i, ranges[i]))
        return
      end
    end
  end

  -- Profile switch ------------------------------------------------------------

  local listening = nil         -- nil, "profile", "buttons" or "knob"
  local listenUntil = 0
  local baseline = {}
  local settleAt, settleAux = nil, nil
  local profAux = nil           -- the profile switch's AUX channel, once found
  local profSamples = {}

  local function stopListening()
    listening, settleAt, settleAux = nil, nil, nil
  end

  local function cancelProfile()
    stopListening()
    profAux = nil
    profSamples = {}
  end

  local function startListen(kind)
    readLocal()
    for k in pairs(baseline) do baseline[k] = nil end
    for aux = 0, auxCount() - 1 do baseline[aux] = auxValue(aux) end
    listening, note = kind, nil
    listenUntil = os.clock() + LISTEN
    settleAt, settleAux = nil, nil
    if kind == "profile" then
      profAux = nil
      profSamples = {}
    end
  end

  local function writeGain(build)
    writeRange(build(A.ADJ.CYCLIC_MASTER_GAIN))
    writeRange(build(A.ADJ.YAW_MASTER_GAIN))
  end

  local function setProfileMethod(value)
    if chosen == value then return end
    cancelProfile()
    chosen = value
    if value == "none" then
      removeFunction(A.ADJ.PID_PROFILE)
      removeFunction(A.ADJ.RATE_PROFILE)
    elseif value == "pid" then
      removeFunction(A.ADJ.RATE_PROFILE)
    else
      -- The rates follow the PID profile switch.
      local pid = A.rangeOf(ranges, A.ADJ.PID_PROFILE)
      if pid then
        local rate = {}
        for k, v in pairs(pid) do rate[k] = v end
        rate.adjFunction = A.ADJ.RATE_PROFILE
        writeRange(rate)
      end
    end
    wiz.rebuild()
  end

  local function useProfileSwitch()
    local positions = A.switchPositions(profSamples)
    if #positions < 2 or not profAux then return end
    local aux = profAux
    cancelProfile()
    writeRange(A.profileRange(A.ADJ.PID_PROFILE, aux, positions))
    if (chosen or A.profileMode(ranges)) == "both" then
      writeRange(A.profileRange(A.ADJ.RATE_PROFILE, aux, positions))
    end
    wiz.rebuild()
  end

  local function setGainMethod(value)
    if (chosenGain or A.gainMode(ranges)) == value then return end
    stopListening()
    chosenGain = value
    removeFunction(A.ADJ.CYCLIC_MASTER_GAIN)
    removeFunction(A.ADJ.YAW_MASTER_GAIN)
    wiz.rebuild()
  end

  -- The channels in use, one row each: the name, the channel, and what it is
  -- set to. Live: the profile the switch is on, the mode switches on or off.
  local summary = {}

  local function summaryRows()
    local rows = {}
    for _, r in ipairs(modeRanges or {}) do
      if r.range.start < r.range["end"] and MODE_NAMES[r.id] then
        local v = auxValue(r.auxChannelIndex)
        local on = v ~= nil and v >= r.range.start and v <= r.range["end"]
        rows[#rows + 1] = {name = MODE_NAMES[r.id], aux = r.auxChannelIndex,
          detail = on and T.on or T.off, on = on}
      end
    end
    local pid = A.rangeOf(ranges, A.ADJ.PID_PROFILE)
    if pid then
      local v = auxValue(pid.adjChannel)
      rows[#rows + 1] = {name = T.useProfile, aux = pid.adjChannel,
        detail = v and string.format(T.nowProfile, A.mappedValue(pid, v)) or T.notSet, on = false}
    end
    local gainCh = A.channelOf(ranges, A.ADJ.CYCLIC_MASTER_GAIN)
    if gainCh ~= nil then
      local method = chosenGain or A.gainMode(ranges)
      local detail, pressed = method == "buttons" and T.gainButtons or T.gainKnob, false
      if method == "buttons" then
        local b = A.buttonAt(auxValue(gainCh))
        if b then detail, pressed = BUTTON_NAMES[b.key], true end
      else
        local r = A.rangeOf(ranges, A.ADJ.CYCLIC_MASTER_GAIN)
        local v = r and auxValue(r.adjChannel)
        if v then detail = string.format("%d %%", A.mappedValue(r, v)) end
      end
      rows[#rows + 1] = {name = T.useGain, aux = gainCh, detail = detail, on = pressed}
    end
    table.sort(rows, function(x, y) return x.aux < y.aux end)
    return rows
  end

  -- Keeps the rows live; returns true when one of them changed.
  local function refreshSummary()
    local fresh = summaryRows()
    local changed = #fresh ~= #summary
    for i = 1, #fresh do
      if changed then break end
      local a, b = fresh[i], summary[i]
      if a.name ~= b.name or a.aux ~= b.aux or a.detail ~= b.detail or a.on ~= b.on then changed = true end
    end
    if changed then summary = fresh end
    return changed
  end

  -- One bordered row per channel in use, drawn in the area under the text. More
  -- than two rows go into two columns (name above, channel and state below); a
  -- row too low for the large font takes the small one, and long text is cut short.
  local function drawSummary(x, y, w, h, colors)
    local n = #summary
    if n == 0 then return end
    local cols = n > 2 and 2 or 1
    local rowsN = math.ceil(n / cols)
    local gapX, gapY = 6, 6
    local cellW = floor((w - gapX * (cols - 1)) / cols)
    local rowH = math.min(56, floor((h - gapY * (rowsN - 1)) / rowsN))
    lcd.font(FONT_STD)
    local _, th = lcd.getTextSize("Ag")
    lcd.font(FONT_S)
    local _, sh = lcd.getTextSize("Ag")
    for i, r in ipairs(summary) do
      local cx = x + ((i - 1) % cols) * (cellW + gapX)
      local ry = y + floor((i - 1) / cols) * (rowH + gapY)
      lcd.color(colors.body)
      lcd.drawRectangle(cx, ry, cellW, rowH, 2)
      lcd.color(colors.active)
      lcd.drawFilledRectangle(cx, ry, 6, rowH)
      local chText = string.format(T.chRow, r.aux + CONTROL_CHANNELS + 1)
      if cols == 1 then
        -- One column: name, channel and state on one line.
        local big = rowH >= th + 12
        lcd.font(big and FONT_STD or FONT_S)
        local _, nh = lcd.getTextSize("Ag")
        local ty = ry + floor((rowH - nh) / 2)
        lcd.color(colors.text)
        lcd.drawText(cx + 18, ty, r.name, LEFT)
        lcd.font(FONT_S)
        lcd.color(colors.muted)
        lcd.drawText(cx + floor(cellW * 0.5), ty + floor((nh - sh) / 2), chText, LEFT)
        lcd.color(r.on and colors.good or colors.text)
        lcd.drawText(cx + cellW - 12, ty + floor((nh - sh) / 2), r.detail, RIGHT)
      else
        -- Two columns: the name and the channel on top, the state below, each
        -- on its own line so the state is never cut.
        local maxW = cellW - 24
        local name = r.name
        lcd.font(rowH >= 2 * sh + th and FONT_STD or FONT_S)
        local _, nh = lcd.getTextSize("Ag")
        local chW = lcd.getTextSize(chText)
        if lcd.getTextSize(name) > maxW - chW - 8 then name = ui.fit(name, maxW - chW - 8) end
        lcd.color(colors.text)
        lcd.drawText(cx + 16, ry + 4, name, LEFT)
        lcd.font(FONT_S)
        lcd.color(colors.muted)
        lcd.drawText(cx + cellW - 12 - chW, ry + 4 + floor((nh - sh) / 2), chText, RIGHT)
        local state = r.detail
        if lcd.getTextSize(state) > maxW then state = ui.fit(state, maxW) end
        lcd.color(r.on and colors.good or colors.text)
        lcd.drawText(cx + 16, ry + rowH - sh - 4, state, LEFT)
      end
    end
  end

  -- Reads ---------------------------------------------------------------------

  local function readNextSlot()
    adjIndex = adjIndex + 1
    if adjIndex > adjMsp.RANGE_COUNT then
      adjLoaded = true
      wiz.rebuild()
      return
    end
    local slot = adjIndex
    bus.publish("msp.request", adjMsp.buildReadSlotMessage(slot, function(range)
      ranges[slot] = range
      readNextSlot()
    end, function()
      adjFailed = true
      wiz.rebuild()
    end))
  end
  readNextSlot()

  wiz.fetch({
    map = function(ok, err) return rxMapCodec.buildReadMessage(ok, err) end,
    modes = function(ok, err) return modesMsp.buildModeRangesReadMessage(ok, err) end,
  }, function(results, failed)
    rxMap, modeRanges = results.map, results.modes
    loadFailed = failed or not rxMap or not modeRanges
    wiz.rebuild()
  end)

  -- Screens -------------------------------------------------------------------

  local function screenIndex(name)
    for i, s in ipairs(screens) do if s == name then return i end end
    return 1
  end

  local function go(name)
    cancelProfile()
    screen, note, answered = name, nil, nil
    wiz.rebuild()
  end

  local function neighbour(delta)
    return screens[screenIndex(screen) + delta]
  end

  -- The switch's live picture: lever along the channel, the listening flick.
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

  local function pictureState(now, aux)
    if listening == "profile" then return flickAngle(now), "listen" end
    local v = auxValue(aux)
    if v then
      local f = math.max(0, math.min(1, (v - 1000) / 1000))
      return floor(-FLICK_ANGLE + 2 * FLICK_ANGLE * f + 0.5), "on"
    end
    return -FLICK_ANGLE, "off"
  end

  local function currentPid() return A.rangeOf(ranges, A.ADJ.PID_PROFILE) end
  local function currentGainChannel() return A.channelOf(ranges, A.ADJ.CYCLIC_MASTER_GAIN) end

  -- The help of the chosen option, wrapped for the left half under the switch.
  local function helpLines(text)
    local width = lcd.getWindowSize()
    return wiz.wrapLines(text, floor(width / 2) - 16, FONT_S)
  end

  -- The live lines under the switch: the profile's channel and the profile
  -- the switch is on; while listening or recording, what the step waits for.
  local function profileStatus(method, pid)
    if listening == "profile" then return helpLines(T.listenProfile) end
    if profAux ~= nil then
      return helpLines(string.format(T.found, #A.switchPositions(profSamples)))
    end
    local lines = {}
    if method == "none" or not pid then return lines end
    for _, t in ipairs(helpLines(string.format(T.countFmt, pid.adjChannel + CONTROL_CHANNELS + 1, pid.adjMax))) do
      lines[#lines + 1] = t
    end
    local v = auxValue(pid.adjChannel)
    if v then
      for _, t in ipairs(helpLines(string.format(T.nowProfile, A.mappedValue(pid, v)))) do lines[#lines + 1] = t end
    end
    return lines
  end

  local function gainStatus(method, gainCh)
    if listening == "buttons" then return helpLines(T.listenButtons) end
    if listening == "knob" then return helpLines(T.listenKnob) end
    if method == "buttons" and gainCh then
      local pressed = A.buttonAt(auxValue(gainCh))
      if pressed then return helpLines(string.format("%s: %s", T.gainNow, BUTTON_NAMES[pressed.key])) end
    elseif method == "knob" then
      local r = A.rangeOf(ranges, A.ADJ.CYCLIC_MASTER_GAIN)
      if r and auxValue(r.adjChannel) then
        return helpLines(string.format("%s: %d %%", T.gainNow, A.mappedValue(r, auxValue(r.adjChannel))))
      end
    end
    return {}
  end

  local function profileScreen()
    local method = chosen or A.profileMode(ranges)
    local pid = A.rangeOf(ranges, A.ADJ.PID_PROFILE)
    local recording = profAux ~= nil
    scr:text(T.profileTitle, T.profileText)
    picture.angle, picture.state = pictureState(os.clock(), pid and pid.adjChannel or nil)
    picture.help = helpLines(PROFILE_HELP[method] or PROFILE_HELP.none)
    picture.status = profileStatus(method, pid)
    scr:picture(picture)
    scr:step(2, SCREEN_COUNT)
    local rows = {}
    for _, m in ipairs(METHODS) do
      rows[#rows + 1] = {answer = m.text, marked = (method == m.key),
        press = function() setProfileMethod(m.key) end,
        disabled = not adjLoaded or listening ~= nil or recording}
    end
    local bottom = nil
    if recording then
      local count = #A.switchPositions(profSamples)
      bottom = {
        {text = T.cancel, press = function() cancelProfile(); wiz.rebuild() end},
        {text = T.use, primary = true, disabled = count < 2, press = useProfileSwitch},
      }
    elseif listening ~= "profile" and method ~= "none" then
      rows[#rows + 1] = {answer = pid and T.reassign or T.assign, marked = false,
        disabled = not adjLoaded, press = function() startListen("profile"); wiz.rebuild() end}
    end
    local field = scr:checks(rows)
    local rowField = scr:row(function() go(neighbour(-1)) end, bottom,
      {text = T.next, disabled = listening ~= nil or recording,
        press = function() go(neighbour(1)) end})
    return field or rowField
  end

  local function gainScreen()
    local method = chosenGain or A.gainMode(ranges)
    local gainCh = A.channelOf(ranges, A.ADJ.CYCLIC_MASTER_GAIN)
    scr:text(T.gainTitle, T.gainText)
    picture.angle, picture.state = pictureState(os.clock(), gainCh)
    picture.help = helpLines(GAIN_HELP[method] or GAIN_HELP.none)
    if method == "buttons" then
      for _, t in ipairs(helpLines(T.gainButtonsNote)) do picture.help[#picture.help + 1] = t end
    end
    picture.status = gainStatus(method, gainCh)
    scr:picture(picture)
    scr:step(3, SCREEN_COUNT)
    local rows = {}
    for _, m in ipairs(GAINS) do
      rows[#rows + 1] = {answer = m.text, marked = (method == m.key),
        press = function() setGainMethod(m.key) end, disabled = not adjLoaded or listening ~= nil}
    end
    if listening == nil and method ~= "none" then
      rows[#rows + 1] = {answer = gainCh and T.reassign or T.assign, marked = false,
        disabled = not adjLoaded, press = function() startListen(method); wiz.rebuild() end}
    end
    local field = scr:checks(rows)
    local rowField = scr:row(function() go(neighbour(-1)) end, nil,
      {text = T.next, disabled = listening ~= nil, press = function() go(neighbour(1)) end})
    return field or rowField
  end

  local function channelsScreen()
    summary = summaryRows()
    local notes = {}
    if full then notes[#notes + 1] = T.full end
    if #summary == 0 then notes[#notes + 1] = T.notSet end
    local beyond = false
    for _, r in ipairs(summary) do if r.aux >= A.AUX_IN_8_CHANNELS then beyond = true end end
    scr:text(T.chTitle, wiz.hasPending() and T.doneSave or T.doneKeep, #notes > 0 and table.concat(notes, " ") or nil,
      beyond and {text = "(" .. T.beyond8 .. ")", accent = true} or nil)
    scr:step(4, SCREEN_COUNT)
    scr:draw(drawSummary)
    return scr:row(function() go(neighbour(-1)) end)
  end

  function self.build()
    scr:begin()
    if loadFailed or adjFailed then
      scr:text(T.title, T.loadFailed)
      return scr:row(nil)
    end
    if not (adjLoaded and rxMap and modeRanges) then
      scr:text(T.title, T.loading)
      return nil
    end
    if screen == "prepare" then
      scr:text(T.prepareTitle, T.intro)
      scr:picture(pidsPicture)
      scr:step(1, SCREEN_COUNT)
      -- Safety confirmation toggles: 1-click toggle buttons (No/Yes). Start follows once both are Yes.
      local function toggle(key, index)
        return {function() return answers[key] == true end, function(v)
          answers[key], answered = v and true or false, index
          wiz.rebuild()
        end}
      end
      local ready = answers.unplugged and answers.blades
      local answerField = scr:checks({
        {label = T.unplugged, toggle = toggle("unplugged", 1)},
        {label = T.blades, toggle = toggle("blades", 2)},
      }, (not ready) and (answered or (not answers.unplugged and 1) or 2) or nil)
      answered = nil
      local rowField = scr:row(nil, {{text = T.start, primary = ready, disabled = not ready,
        press = function() go(screens[2]) end}})
      return answerField or rowField
    elseif screen == "profile" then
      return profileScreen()
    elseif screen == "gain" then
      return gainScreen()
    else
      return channelsScreen()
    end
  end

  function self.paint() scr:paint() end

  function self.wakeup(now)
    if not adjLoaded then return end
    if screen == "prepare" then return end
    if now - localAt >= LOCAL_READ then
      localAt = now
      readLocal()
      if listening == "profile" or listening == "buttons" or listening == "knob" then
        if settleAt then
          -- The profile switch's move settled: take where it ended up.
          if listening == "profile" and now >= settleAt then
            local aux = settleAux
            profAux = aux
            profSamples = {baseline[aux] or 0, auxValue(aux) or 0}
            stopListening()
            wiz.rebuild()
          end
        else
          local best, bestMove = nil, MOVE_US[listening]
          for aux = 0, auxCount() - 1 do
            local v, b = auxValue(aux), baseline[aux]
            if v and b and math.abs(v - b) > bestMove then best, bestMove = aux, math.abs(v - b) end
          end
          if best then
            if listening == "profile" then
              settleAt, settleAux = now + SETTLE, best
            elseif listening == "knob" then
              writeGain(function(fn) return A.knobRange(fn, best) end)
              stopListening()
              wiz.rebuild()
            else
              writeGain(function(fn) return A.steppedGainRange(fn, best) end)
              stopListening()
              wiz.rebuild()
            end
          elseif now > listenUntil then
            stopListening()
            note = T.noSwitch
            wiz.rebuild()
          end
        end
      end
      if profAux ~= nil then
        local v = auxValue(profAux)
        local last = profSamples[#profSamples]
        if v and v > 0 and #profSamples < RECORD_MAX and (last == nil or math.abs(v - last) > RECORD_STEP_US) then
          profSamples[#profSamples + 1] = v
        end
      end
      if screen == "profile" then
        picture.status = profileStatus(chosen or A.profileMode(ranges), A.rangeOf(ranges, A.ADJ.PID_PROFILE))
      elseif screen == "gain" then
        picture.status = gainStatus(chosenGain or A.gainMode(ranges), A.channelOf(ranges, A.ADJ.CYCLIC_MASTER_GAIN))
      end
      if screen == "profile" or screen == "gain" then wiz.invalidate() end
      if screen == "channels" and refreshSummary() then wiz.invalidate() end
    end
  end

  function self.released() scr:refresh() end
  function self.leave() stopListening() end

  return self
end

return {new = new, owned = OWNED}
