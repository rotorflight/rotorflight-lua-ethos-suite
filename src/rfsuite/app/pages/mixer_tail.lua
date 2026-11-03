-- Mixer -> Tail page.
--
-- Ports the original API >= 12.0.9 Tail page. The visible field set is
-- chosen from the current tail rotor mode: fixed-pitch tails expose yaw
-- center trim in degrees, while motorized/bidirectional tails expose tail
-- idle and use raw percent-like yaw limits.
--
-- On a servo (variable pitch) tail, Tool toggles mixer override on the yaw
-- input, which holds the tail at center. While it is on, the other fields are locked and a settled trim
-- edit is sent live with MSP_SET_MIXER_CONFIG (the FC applies it at once,
-- without EEPROM). Save keeps it; leaving without saving puts the old trim
-- back.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local pageRuntime = requireModule("app/page_runtime.lua")
local mixerConfig = requireModule("lib/msp_mixer_config.lua")
local mixerInputFactory = requireModule("lib/msp_mixer_input.lua")
local tailOutput = requireModule("lib/msp_tail_motor_output.lua")
local mixerOverride = requireModule("lib/msp_mixer_override.lua")

local PAGE_TITLE = "@i18n(app.modules.mixer.tail)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"

-- MIXER_IN_STABILIZED_YAW in the firmware's mixer input list.
local OVERRIDE_YAW = 3
-- Seconds a trim value has to stay unchanged before it is sent live.
local LIVE_SETTLE = 0.5
-- Rows whose value and units follow the kind of tail: the formData key,
-- range, suffix and default for a servo (pitch) and a motor tail.
local SLOTS = {
  center = {
    pitch = {key = "yaw_center_trim", min = -250, max = 250, suffix = "°", default = 0},
    motor = {key = "tail_center_offset", min = -500, max = 500, suffix = "%", default = 0},
  },
  cw = {
    pitch = {key = "yaw_cw_limit_fixed", min = 0, max = 600, suffix = "°", default = 20},
    motor = {key = "yaw_cw_limit_motor", min = 0, max = 2000, suffix = "%", default = 125},
  },
  ccw = {
    pitch = {key = "yaw_ccw_limit_fixed", min = 0, max = 600, suffix = "°", default = 20},
    motor = {key = "yaw_ccw_limit_motor", min = 0, max = 2000, suffix = "%", default = 125},
  },
}
local TXT_CENTER_PITCH = "@i18n(app.modules.mixer.yaw_center_trim)@"
local TXT_CENTER_MOTOR = "@i18n(app.modules.mixer.tail_center_offset)@"
local HIDDEN_RECT = {x = 0, y = 0, w = 0, h = 0}

-- The Tail pin line: where the pin is now (OUTPUT), what Save will do, or
-- why the FC kept it where it was (RESULT). Short values: they share the
-- line with the label on a 480x320 radio.
local TXT_PIN_UNKNOWN = "-"
local TXT_PIN = {
  [tailOutput.OUTPUT.SERVO] = "@i18n(app.modules.mixer.tail_pin_servo)@",
  [tailOutput.OUTPUT.MOTOR] = "@i18n(app.modules.mixer.tail_pin_motor)@",
  [tailOutput.OUTPUT.BOTH] = "@i18n(app.modules.mixer.tail_pin_both)@",
  [tailOutput.OUTPUT.NONE] = "@i18n(app.modules.mixer.tail_pin_none)@",
}
local TXT_PIN_TO_MOTOR = "@i18n(app.modules.mixer.tail_pin_to_motor)@"
local TXT_PIN_TO_SERVO = "@i18n(app.modules.mixer.tail_pin_to_servo)@"
local TXT_PIN_REFUSED = {
  [tailOutput.RESULT.CUSTOM] = "@i18n(app.modules.mixer.tail_pin_refused_custom)@",
  [tailOutput.RESULT.NO_MAIN_MOTOR] = "@i18n(app.modules.mixer.tail_pin_refused_no_motor)@",
  [tailOutput.RESULT.NO_TIMER] = "@i18n(app.modules.mixer.tail_pin_refused_no_timer)@",
  [tailOutput.RESULT.TIMER_SHARED] = "@i18n(app.modules.mixer.tail_pin_refused_timer)@",
  [tailOutput.RESULT.NO_DMA] = "@i18n(app.modules.mixer.tail_pin_refused_no_dma)@",
}
local TXT_PIN_REFUSED_OTHER = "@i18n(app.modules.mixer.tail_pin_refused_custom)@"

-- Added to the save confirmation when the kind of tail changes.
local MSG_TTA_ON = "@i18n(app.modules.mixer.tail_tta_on)@"
local MSG_TTA_OFF = "@i18n(app.modules.mixer.tail_tta_off)@"

local CHOICES_TAIL_MODE = {
  {"@i18n(api.MIXER_CONFIG.tbl_tail_variable_pitch)@", 0},
  {"@i18n(api.MIXER_CONFIG.tbl_tail_motororized_tail)@", 1},
  {"@i18n(api.MIXER_CONFIG.tbl_tail_bidirectional)@", 2},
}

local CHOICES_DIRECTION = {
  {"@i18n(api.MIXER_INPUT.tbl_reversed)@", 0},
  {"@i18n(api.MIXER_INPUT.tbl_normal)@", 1},
}

local function u16ToS16(value)
  if not value then return 0 end
  if value >= 0x8000 then return value - 0x10000 end
  return value
end

local function s16ToU16(value)
  if value < 0 then return value + 0x10000 end
  return value
end

local function round(value)
  if value >= 0 then return math.floor(value + 0.5) end
  return math.ceil(value - 0.5)
end

local function isMotorizedMode(mode)
  return (tonumber(mode) or -1) >= 1
end

local function rateToDirection(value)
  return u16ToS16(value) < 0 and 0 or 1
end

local function dirSign(direction)
  return direction == 0 and -1 or 1
end

local function open(opts)
  local formData = {}
  local originalMode = nil
  local fields = {}
  -- Set further down, once the fields exist.
  local refresh, applyMode, onTailModeChange
  -- Last loaded/override/mode state the fields were enabled for.
  local enableState = nil
  -- RESULT of the last move the FC refused. Kept across the re-read after
  -- the save's reboot, which replaces runtime.data.tail.
  local lastRefused = nil
  local tailPinText = nil
  local inOverride = false
  -- Raw tail_center_trim that EEPROM holds, the one the FC last confirmed,
  -- and the one sent live but not yet confirmed.
  local savedTrim = nil
  local liveTrim = nil
  local pendingTrim = nil
  -- Only a trim edit is sent live: the degrees field rounds the raw value,
  -- so an unedited field can differ from what the FC holds.
  local trimEdited = false
  local lastChangeAt = 0
  -- Reused for every live write: the loaded mixer config with the trim swapped in.
  local liveMixer = {}

  -- Whether the kind of tail (servo or motor) differs from what was loaded:
  -- the pin and Tail Torque Assist follow it on save.
  local function kindChanged()
    return originalMode ~= nil
      and isMotorizedMode(formData.tail_rotor_mode) ~= isMotorizedMode(originalMode)
  end

  -- Raw tail_center_trim from the trim field of the current tail mode.
  local function trimFromForm()
    if isMotorizedMode(formData.tail_rotor_mode) then
      return formData.tail_center_offset or 0
    end
    return round((formData.yaw_center_trim or 0) * 100 / 24)
  end

  local function onTrimWritten()
    if pendingTrim ~= nil then liveTrim = pendingTrim end
    pendingTrim = nil
  end

  -- Keep the confirmed trim; retry after the settle time.
  local function onTrimError()
    pendingTrim = nil
    lastChangeAt = os.clock()
  end

  local function sendTrim(rt, trim)
    local mixer = rt.data and rt.data.mixer
    if not mixer then return end
    for key, value in pairs(mixer) do liveMixer[key] = value end
    liveMixer.tail_center_trim = trim
    pendingTrim = trim
    bus.publish("msp.request", mixerConfig.buildWriteMessage(liveMixer, onTrimWritten, onTrimError))
  end

  local function setOverride(on)
    bus.publish("msp.request", mixerOverride.buildWriteMessage(OVERRIDE_YAW,
      on and 0 or mixerOverride.OVERRIDE_OFF))
    inOverride = on
  end

  local runtime
  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "mixer_tail",
    sources = {
      {key = "mixer", mspModule = mixerConfig},
      {key = "yaw", mspModule = mixerInputFactory.yaw()},
      -- Last, so the pin and TTA writes land before the EEPROM write.
      {key = "tail", mspModule = tailOutput},
    },
    opts = opts,
    profileField = "none",
    rebootAfterSave = function(rt)
      local tail = rt.data.tail
      return (originalMode ~= nil and formData.tail_rotor_mode ~= originalMode)
        or (tail ~= nil and tail.moved == true)
    end,
    onSaved = function(rt)
      local tail = rt.data.tail
      lastRefused = tail and tail.refused or nil
      savedTrim = trimFromForm()
      liveTrim = savedTrim
      pendingTrim = nil
      -- Moving the pin restarts the FC, which drops the override.
      if tail and tail.moved then inOverride = false end
    end,
    unloadPackageKeys = {
      "rfsuite.lib.msp_mixer_config",
      "rfsuite.lib.msp_mixer_input",
      "rfsuite.lib.msp_tail_motor_output",
      "rfsuite.lib.msp_mixer_override",
    },
    onLoaded = function()
      local mixer = runtime.data.mixer or {}
      local yaw = runtime.data.yaw or {}
      local mode = mixer.tail_rotor_mode or 0
      formData.tail_rotor_mode = mode
      formData.yaw_direction = rateToDirection(yaw.rate_stabilized_yaw)
      formData.yaw_calibration = math.abs(u16ToS16(yaw.rate_stabilized_yaw))
      formData.tail_motor_idle = mixer.tail_motor_idle or 0
      formData.tail_center_offset = mixer.tail_center_trim or 0
      formData.yaw_center_trim = round(u16ToS16(mixer.tail_center_trim) * 24 / 100)
      formData.yaw_cw_limit_motor = math.abs(u16ToS16(yaw.min_stabilized_yaw))
      formData.yaw_ccw_limit_motor = math.abs(u16ToS16(yaw.max_stabilized_yaw))
      formData.yaw_cw_limit_fixed = round(math.abs(u16ToS16(yaw.min_stabilized_yaw)) * 24 / 100)
      formData.yaw_ccw_limit_fixed = round(math.abs(u16ToS16(yaw.max_stabilized_yaw)) * 24 / 100)
      -- Only the first read is what EEPROM holds: a later re-read returns
      -- whatever was last sent live. onSaved moves it on.
      liveTrim = u16ToS16(mixer.tail_center_trim)
      pendingTrim = nil
      trimEdited = false
      if savedTrim == nil then savedTrim = liveTrim end

      originalMode = mode
      runtime.extraSaveMessage = nil
      -- A motor tail whose pin is still on SERVO 4 (or the reverse): Save
      -- fixes it, so offer Save even with nothing edited. Not after the FC
      -- refused that move: saving again would only be refused again.
      if not lastRefused and tailOutput.movable(runtime.data.tail, isMotorizedMode(mode)) then
        runtime:markDirty()
      end
      applyMode()
      runtime:updateToolEnabled()
      refresh()
      if form.invalidate then form.invalidate() end
    end,
    beforeSave = function(rt)
      local tail = rt.data.tail
      if tail then
        tail.motorised = isMotorizedMode(formData.tail_rotor_mode)
        if kindChanged() then
          tail.setTta = tail.motorised
        else
          tail.setTta = nil
        end
      end

      local mixer = rt.data.mixer
      if mixer then
        mixer.tail_rotor_mode = formData.tail_rotor_mode or 0
        if isMotorizedMode(formData.tail_rotor_mode) then
          mixer.tail_motor_idle = formData.tail_motor_idle or 0
          mixer.tail_center_trim = formData.tail_center_offset or 0
        else
          mixer.tail_center_trim = s16ToU16(round((formData.yaw_center_trim or 0) * 100 / 24))
        end
      end

      local yaw = rt.data.yaw
      if yaw then
        local yawRate = round(formData.yaw_calibration or 0)
        yaw.rate_stabilized_yaw = s16ToU16(yawRate * dirSign(formData.yaw_direction))

        local cw
        local ccw
        if isMotorizedMode(formData.tail_rotor_mode) then
          cw = round(formData.yaw_cw_limit_motor or 0)
          ccw = round(formData.yaw_ccw_limit_motor or 0)
        else
          cw = round(formData.yaw_cw_limit_fixed or 0)
          ccw = round(formData.yaw_ccw_limit_fixed or 0)
          cw = round(cw * 100 / 24)
          ccw = round(ccw * 100 / 24)
        end
        yaw.min_stabilized_yaw = s16ToU16(-math.abs(cw))
        yaw.max_stabilized_yaw = s16ToU16(math.abs(ccw))
      end
    end,
    toolIcon = "app/gfx/nav/override.png",
    -- Servo tails only: a disarmed FC drives the motors from motor override
    -- alone (motors.c motorUpdate()), so a tail motor never shows the trim.
    toolAvailable = function()
      return not isMotorizedMode(formData.tail_rotor_mode)
    end,
    onTool = function(focusFn)
      form.openDialog({
        title = inOverride and "@i18n(app.modules.trim.disable_mixer_override)@"
          or "@i18n(app.modules.trim.enable_mixer_override)@",
        message = inOverride and "@i18n(app.modules.trim.disable_mixer_message)@"
          or "@i18n(app.modules.mixer.tail_override_msg)@",
        buttons = {
          {label = BTN_OK, action = function()
            -- focusFn() on every outcome: the form loses its focus when a
            -- dialog closes (app/page_runtime.lua's note on closeDialog).
            if inOverride then
              setOverride(false)
            elseif runtime.loaded and not isMotorizedMode(formData.tail_rotor_mode) then
              setOverride(true)
            end
            if refresh then refresh() end
            if focusFn then focusFn() end
            return true
          end},
          {label = BTN_CANCEL, action = function()
            if focusFn then focusFn() end
            return true
          end},
        },
        wakeup = function() end,
        paint = function() end,
        options = TEXT_LEFT,
      })
    end,
    onWakeup = function(rt)
      refresh()
      -- Not while armed (or not known to be disarmed): the FC ignores the
      -- override then, but would take the trim.
      if not inOverride or not trimEdited or pendingTrim ~= nil or not rt.loaded
        or rt.busy or rt.activeDialog or rt:armedOrUnconfirmed() then return end
      local trim = trimFromForm()
      if trim ~= liveTrim and (os.clock() - lastChangeAt) >= LIVE_SETTLE then
        sendTrim(rt, trim)
      end
    end,
    onDispose = function(rt)
      -- Left without saving: put back the trim EEPROM holds. Not while
      -- armed (the FC keeps the live trim until it restarts) or mid-save
      -- (the save writes the trim itself).
      local changed = liveTrim ~= savedTrim or (pendingTrim ~= nil and pendingTrim ~= savedTrim)
      if savedTrim ~= nil and changed and not rt.busy and not rt:armedOrUnconfirmed() then
        sendTrim(rt, savedTrim)
      end
      if inOverride then setOverride(false) end
    end,
  })

  -- Captured instead of closing over `runtime` directly in each field
  -- setter below -- matching app/pages/pids.lua's own dataRef convention
  -- (see its comment): Ethos retains some form callback closures past
  -- this page's own lifetime, and controlRef.runtime gets nilled on
  -- dispose (app/page_runtime.lua's own PageRuntime:dispose()), so
  -- whatever gets retained here stays small instead of pinning the whole
  -- disposed PageRuntime.
  local controlRef = runtime.controlRef
  local function markDirty()
    local rt = controlRef.runtime
    if rt then rt:markDirty() end
  end

  -- formData key each slot row edits now (see SLOTS); set by applyMode().
  local slotKey = {}

  local function addChoice(label, key, choices, onChange)
    local field = form.addChoiceField(form.addLine(label), nil, choices,
      function() return formData[key] or 0 end,
      function(value)
        markDirty()
        formData[key] = value
        if onChange then onChange(value) end
      end)
    runtime:registerField(key, field)
    fields[key] = field
  end

  local function addNumber(line, key, min, max, suffix, default)
    local field = form.addNumberField(line, nil, min, max,
      function() return formData[key] or 0 end,
      function(value)
        markDirty()
        formData[key] = value
      end)
    field:suffix(suffix)
    field:decimals(1)
    field:default(default)
    runtime:registerField(key, field)
    fields[key] = field
    return field
  end

  -- A row whose key and units follow the kind of tail. Built for a servo
  -- tail; applyMode() switches it.
  local function addSlot(line, slot)
    local spec = SLOTS[slot].pitch
    slotKey[slot] = spec.key
    local field = form.addNumberField(line, nil, spec.min, spec.max,
      function() return formData[slotKey[slot]] or 0 end,
      function(value)
        markDirty()
        formData[slotKey[slot]] = value
        if slot == "center" then
          trimEdited = true
          lastChangeAt = os.clock()
        end
      end)
    field:suffix(spec.suffix)
    field:decimals(1)
    field:default(spec.default)
    runtime:registerField(slot, field)
    fields[slot] = field
    return field
  end

  form.clear()
  runtime:buildChrome()

  local function currentTailPinText()
    local tail = runtime.loaded and runtime.data.tail
    if not tail or not tail.supported then return TXT_PIN_UNKNOWN end
    if lastRefused then return TXT_PIN_REFUSED[lastRefused] or TXT_PIN_REFUSED_OTHER end
    local motorized = isMotorizedMode(formData.tail_rotor_mode)
    if tailOutput.movable(tail, motorized) then
      return motorized and TXT_PIN_TO_MOTOR or TXT_PIN_TO_SERVO
    end
    return TXT_PIN[tail.output] or TXT_PIN_UNKNOWN
  end

  -- Rows: the same field serves both kinds of tail where only the units
  -- differ. Tail Idle is motor only: its own text label and field are
  -- hidden (zero rect) on a servo tail, and it is the last row, with no
  -- separator, so the empty row leaves no gap.
  addChoice("@i18n(app.modules.mixer.tail_rotor_mode)@", "tail_rotor_mode", CHOICES_TAIL_MODE,
    function() onTailModeChange() end)
  fields.tail_pin = form.addStaticText(form.addLine("@i18n(app.modules.mixer.tail_pin)@"), nil, TXT_PIN_UNKNOWN)
  tailPinText = TXT_PIN_UNKNOWN
  addChoice("@i18n(app.modules.mixer.yaw_direction)@", "yaw_direction", CHOICES_DIRECTION)

  local centerLine = form.addLine("")
  local centerField = addSlot(centerLine, "center")
  if centerField.enableInstantChange then centerField:enableInstantChange(true) end
  -- rect() can return nil (the bin/ harness stubs do).
  local fieldRect = centerField:rect() or HIDDEN_RECT
  local labelRect = {x = 0, y = fieldRect.y or 0, w = math.max(0, (fieldRect.x or 0) - 8), h = fieldRect.h or 0}
  local centerLabel = form.addStaticText(centerLine, labelRect, TXT_CENTER_PITCH)

  addNumber(form.addLine("@i18n(app.modules.mixer.yaw_calibration)@"), "yaw_calibration", 200, 2000, "%", 400)
  addSlot(form.addLine("@i18n(app.modules.mixer.yaw_cw_limit)@"), "cw")
  addSlot(form.addLine("@i18n(app.modules.mixer.yaw_ccw_limit)@"), "ccw")

  local idleLine = form.addLine("", nil, false)
  local idleField = addNumber(idleLine, "tail_motor_idle", 0, 250, "%", 0)
  local idleRect = idleField:rect() or HIDDEN_RECT
  local idleLabel = form.addStaticText(idleLine, labelRect, "@i18n(app.modules.mixer.tail_motor_idle)@")
  idleField:rect(HIDDEN_RECT)
  idleLabel:rect(HIDDEN_RECT)

  local appliedMotorized = false

  -- Switches the slot rows and the Tail Idle row to the current kind of
  -- tail. Does nothing unless that kind changed.
  applyMode = function()
    local motorized = isMotorizedMode(formData.tail_rotor_mode)
    if motorized == appliedMotorized then return end
    appliedMotorized = motorized
    local variant = motorized and "motor" or "pitch"
    for slot, specs in pairs(SLOTS) do
      local spec = specs[variant]
      local field = fields[slot]
      slotKey[slot] = spec.key
      field:minimum(spec.min)
      field:maximum(spec.max)
      field:suffix(spec.suffix)
      field:default(spec.default)
    end
    centerLabel:value(motorized and TXT_CENTER_MOTOR or TXT_CENTER_PITCH)
    idleField:rect(motorized and idleRect or HIDDEN_RECT)
    idleLabel:rect(motorized and labelRect or HIDDEN_RECT)
    enableState = nil
    if lcd.invalidate then lcd.invalidate() end
  end

  refresh = function()
    -- Wakeup path: only touch the fields when what they show changes.
    local text = currentTailPinText()
    if fields.tail_pin and text ~= tailPinText then
      tailPinText = text
      fields.tail_pin:value(text)
    end

    -- Override on: only the trim (center) row stays editable. Tail Idle
    -- only on a motor tail, where it is shown.
    local loaded = runtime.loaded == true
    local state = (loaded and 1 or 0) + (inOverride and 2 or 0) + (appliedMotorized and 4 or 0)
    if state == enableState then return end
    enableState = state
    local free = loaded and not inOverride
    for key, field in pairs(fields) do
      if key == "center" then
        field:enable(loaded)
      elseif key == "tail_motor_idle" then
        field:enable(free and appliedMotorized)
      elseif key ~= "tail_pin" then
        field:enable(free)
      end
    end
  end

  onTailModeChange = function()
    lastRefused = nil
    if kindChanged() then
      runtime.extraSaveMessage = isMotorizedMode(formData.tail_rotor_mode) and MSG_TTA_ON or MSG_TTA_OFF
    else
      runtime.extraSaveMessage = nil
    end
    applyMode()
    runtime:updateToolEnabled()
    refresh()
  end

  refresh()
  runtime:loadInitial()
end

return {open = open}
