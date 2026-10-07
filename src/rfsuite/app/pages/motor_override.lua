-- Setup -> ESC & Motors -> Motor Override.
--
-- Drives a motor directly from the radio via MSP_SET_MOTOR_OVERRIDE (195).
-- Three facts from the firmware shape this page, and each one is a place where
-- a page that got it wrong leaves a motor turning:
--
--   * MOTOR_OVERRIDE_TIMEOUT is 1.0 s (motors.h:27). motors.c:301-303 resets
--     every override once that deadline passes, so a single write holds a motor
--     for one second. The keep-alive below is what makes the page work at all --
--     without it the motor stops on its own a second after the pilot lets go.
--   * motors.c:116 drops the write entirely while ARMING_FLAG(ARMED) is set, so
--     an armed craft cannot be overridden from here at all. The page refuses
--     the switch in that state rather than showing a control that would
--     silently do nothing.
--   * The write names one motor (msp.c:2966-2972), so the release has to name
--     every motor the page may have touched, not only the selected one.
--
-- What this page cannot cover -- the script being killed, the link dropping, a
-- crash -- is covered by the firmware: the override lapses one second after the
-- last write that reached the board.
--
-- Servo override deliberately has no keep-alive here. It needs none: unlike the
-- motor path, servos.c:95-98 (setServoOverride) stores the value and nothing
-- else -- there is no servo counterpart to motorOverrideTimeout, so a servo
-- override holds until something writes SERVO_OVERRIDE_OFF.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local progressDialog = requireModule("app/progress_dialog.lua")
local motorOverride = requireModule("lib/msp_motor_override.lua")
local status = requireModule("lib/msp_status.lua")

-- A line of text across the whole screen.
--
-- form.addStaticText(line, nil, text) puts the text in that line's VALUE
-- column -- the narrow right-hand slot -- and clips whatever does not fit.
-- That is where this page's safety note was first written, which is why it
-- arrived cut off at the right edge with its second half missing. The suite's
-- idiom for a line that is ALL text is an empty form line plus a rect spanning
-- the window: app/esc_error.lua:43-61 and app/diagnostics_common.lua:59-73 both
-- do exactly this, and header.lua:56-70 records the same trap being hit before.
--
-- 480 px carries about 37 characters (bin/esc_summary/verify_esc_summary.lua),
-- which is why the note below is two short lines rather than one long one.
local function addTextLine(text)
  local line = form.addLine("")
  local slots = form.getFieldSlots(line, {0})
  local slot = (slots and slots[1]) or {}
  local width = nil
  if lcd and lcd.getWindowSize then width = lcd.getWindowSize() end
  local rect = {x = 0, y = slot.y or 0, w = width or slot.w or 0, h = slot.h or 0}
  return form.addStaticText(line, rect, text, LEFT)
end

local PAGE_TITLE = "@i18n(app.modules.esc_motors.motor_override)@"
local MSG_LOADING_TITLE = "@i18n(app.msg_loading)@"
local MSG_LOADING_BODY = "@i18n(app.msg_loading_from_fbl)@"
local MSG_LOAD_ERROR = "@i18n(app.modules.ports.load_error_prefix)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local MSG_ARMED_BLOCKED = "@i18n(app.modules.esc_motors.motor_override_armed)@"
local MSG_DISCONNECTED = "@i18n(app.modules.esc_motors.motor_override_disconnected)@"

-- How often the override is written again while the page holds a motor. Four
-- times inside the firmware's one-second window, which is also what the
-- Configurator sends.
local REFRESH_INTERVAL = 0.25

-- How long a write that has neither answered nor failed blocks the next one.
-- The same second and for the same reason: past it the override has lapsed at
-- the far end anyway, so there is nothing left to protect by waiting. Below it
-- the page keeps one write at a time, so the queue cannot outgrow the wire.
local WRITE_GIVE_UP = 1.0

-- Only the forward half of the range is offered. MOTOR_OVERRIDE_MIN is -1000
-- and drives the motor backwards, which is not part of any setup procedure and
-- is not something to put one turn of a wheel away from zero.
local MAX_PERCENT = 100

-- How many motors to offer. A board that answers 0 has no motor outputs
-- configured; the page still shows the first one rather than a dead end, and
-- the flight controller ignores an override for a motor it does not have.
local function effectiveMotorCount(motorCount)
  local count = tonumber(motorCount) or 0
  if count < 1 then count = 1 end
  if count > motorOverride.MOTOR_SLOTS then count = motorOverride.MOTOR_SLOTS end
  return count
end

local function percentToValue(percent)
  local p = tonumber(percent) or 0
  if p < 0 then p = 0 end
  if p > MAX_PERCENT then p = MAX_PERCENT end
  return math.floor(p * motorOverride.OVERRIDE_MAX / 100)
end

local function open(opts)
  opts = opts or {}

  local disposed = false
  local loaded = false
  local activeDialog = false
  local inOverride = false
  local pendingConfirm = nil
  local motorCount = 1
  local selected = 0
  local percent = {}
  local writeInFlight = false
  local lastWriteAt = 0
  local connected = nil
  local isArmed = nil

  local pendingStatus = nil
  local pendingOverride = nil
  local pendingError = false

  local fields = {}
  local dialog = nil
  local confirmHandle = nil
  local headerHandle = nil
  local sessionHandler = nil

  local function count() return effectiveMotorCount(motorCount) end

  -- The in-flight flag is raised BEFORE the publish, not after it. A reply that
  -- comes back within the publish -- a stubbed queue, a cached answer -- would
  -- otherwise clear a flag that is set again on the next line, and the page
  -- would then hold the override on the give-up path only: one write a second,
  -- which is exactly the rate at which the firmware's one-second deadline
  -- lapses the override.
  local function writeOverride(index, valuePercent)
    writeInFlight = true
    lastWriteAt = os.clock()
    bus.publish("msp.request", motorOverride.buildWriteMessage(index, percentToValue(valuePercent), function()
      writeInFlight = false
    end, function()
      writeInFlight = false
    end))
  end

  --- Put every motor back to zero, whatever the page currently shows.
  ---
  --- Every motor and not only the selected one, because the pilot may have moved
  --- between them, and unconditionally, because this is the path that has to
  --- work when something has already gone wrong. If the link is gone the write
  --- cannot be made -- and then nothing can reach the board either, so the
  --- override lapses on its own within the second.
  local function releaseAllMotors()
    for i = 0, count() - 1 do
      percent[i] = 0
      writeOverride(i, 0)
    end
    writeInFlight = false
  end

  local function stopOverride()
    if not inOverride then return end
    inOverride = false
    releaseAllMotors()
  end

  -- The armed craft cannot be overridden at all (motors.c:116), so the switch is
  -- not merely refused there -- it is disabled, and an override that was already
  -- running when the craft armed is handed straight back.
  local function refreshEnabled()
    local blocked = isArmed == true
    if blocked and inOverride then
      inOverride = false
      releaseAllMotors()
    end
    if headerHandle and headerHandle.setTitle then
      headerHandle.setTitle(inOverride and (PAGE_TITLE .. " *") or PAGE_TITLE)
    end
    local idle = loaded and not activeDialog
    if fields.enable then fields.enable:enable(idle and not blocked) end
    -- The motor is chosen before the override is enabled. Changing it under an
    -- active override would leave the motor that is turning with nothing to
    -- refresh it: it would stop, but a second later and without the page ever
    -- having said so.
    if fields.motor then fields.motor:enable(idle and not inOverride) end
    if fields.throttle then fields.throttle:enable(idle and inOverride) end
    if fields.notice then
      fields.notice:value(blocked and MSG_ARMED_BLOCKED
        or (connected == false and MSG_DISCONNECTED or ""))
    end
  end

  local function setActiveDialog(value)
    if activeDialog == value then return end
    activeDialog = value
    refreshEnabled()
  end

  local function openConfirm(enabled)
    if enabled and isArmed == true then
      refreshEnabled()
      return
    end
    -- The handle is kept so dispose() can close it: a confirm dialog left open
    -- over a disposed page keeps its own wakeup running, which is the leak
    -- app/pages/ports.lua:269-276 records.
    confirmHandle = form.openDialog({
      title = enabled and "@i18n(app.modules.esc_motors.motor_override_enable)@"
        or "@i18n(app.modules.esc_motors.motor_override_disable)@",
      message = enabled and "@i18n(app.modules.esc_motors.motor_override_enable_msg)@"
        or "@i18n(app.modules.esc_motors.motor_override_disable_msg)@",
      buttons = {
        {label = BTN_OK, action = function()
          confirmHandle = nil
          setActiveDialog(false)
          if enabled then
            for i = 0, count() - 1 do
              percent[i] = 0
            end
            writeInFlight = false
            lastWriteAt = 0
            inOverride = true
          else
            stopOverride()
          end
          refreshEnabled()
          return true
        end},
        {label = BTN_CANCEL, action = function()
          confirmHandle = nil
          setActiveDialog(false)
          -- The switch draws itself in its new position the moment it is touched,
          -- so a cancel has to put the page back rather than only leave the state
          -- alone.
          refreshEnabled()
          return true
        end},
      },
      wakeup = function() end,
      paint = function() end,
      options = TEXT_LEFT,
    })
    if confirmHandle then
      setActiveDialog(true)
    else
      -- No dialog could be opened, so the switch has to be put back rather than
      -- left drawing itself as on.
      refreshEnabled()
    end
  end

  -- Forward declaration: the built page's Back button goes through goBack rather
  -- than an inline copy of its body, so the release and the wakeup-handler
  -- teardown cannot drift apart.
  local goBack

  local function buildFields()
    form.clear()
    headerHandle = header.build(inOverride and (PAGE_TITLE .. " *") or PAGE_TITLE, {
      onBack = function() goBack() end,
    })

    addTextLine("@i18n(app.modules.esc_motors.motor_override_note)@")
    addTextLine("@i18n(app.modules.esc_motors.motor_override_note_2)@")

    fields.notice = addTextLine("")

    if count() > 1 then
      local choices = {}
      for i = 1, count() do
        choices[i] = {"@i18n(app.modules.esc_motors.motor)@" .. " " .. i, i - 1}
      end
      fields.motor = form.addChoiceField(
        form.addLine("@i18n(app.modules.esc_motors.motor)@"), nil, choices,
        function() return selected end,
        function(value)
          if selected ~= value then
            selected = value
            if form.invalidate then form.invalidate() end
          end
        end)
    end

    fields.enable = form.addBooleanField(
      form.addLine("@i18n(app.modules.esc_motors.motor_override_enable)@"), nil,
      function() return inOverride end,
      function(value)
        -- Deferred to the wakeup tick: opening a dialog synchronously from inside
        -- a field callback is the failure app/page_runtime.lua:1252-1264 and
        -- :1318-1338 document twice, each caught live on hardware.
        pendingConfirm = value == true
      end)

    fields.throttle = form.addNumberField(
      form.addLine("@i18n(app.modules.esc_motors.motor_override_throttle)@"), nil, 0, MAX_PERCENT,
      function() return percent[selected] or 0 end,
      function(value)
        -- Recorded here and sent by the keep-alive that is running anyway. A write
        -- per wheel click would queue faster than the wire drains.
        percent[selected] = value
      end)
    if fields.throttle and fields.throttle.suffix then fields.throttle:suffix("%") end

    refreshEnabled()
    if headerHandle and headerHandle.focusMenu then headerHandle.focusMenu() end
  end

  local function closeProgress(force)
    if not dialog then return end
    local d = dialog
    dialog = nil
    pcall(function() d:value(100) end)
    pcall(function() d:close(force == true) end)
  end

  local function showLoadError()
    form.clear()
    header.build(PAGE_TITLE, {onBack = function()
      if opts.onBack then opts.onBack() end
    end})
    form.addLine(MSG_LOAD_ERROR .. " STATUS/MOTOR_OVERRIDE")
  end

  local function closeConfirm()
    if not confirmHandle then return end
    local h = confirmHandle
    confirmHandle = nil
    activeDialog = false
    pcall(function() h:close() end)
  end

  goBack = function()
    if disposed then return end
    disposed = true
    closeConfirm()
    closeProgress(true)
    if sessionHandler then
      bus.unsubscribe("session.update", sessionHandler)
      sessionHandler = nil
    end
    stopOverride()
    fields = {}
    headerHandle = nil
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.onBack then opts.onBack() end
  end

  form.clear()
  header.build(PAGE_TITLE, {onBack = goBack})
  form.addLine(MSG_LOADING_TITLE)
  dialog = progressDialog.open({
    title = MSG_LOADING_TITLE,
    message = MSG_LOADING_BODY,
  })

  if opts.setEventHandler then
    opts.setEventHandler(function(category, value)
      if not closeKey.shouldHandleClose(category, value) then return false end
      goBack()
      return true
    end)
  end

  if opts.setCleanupHandler then
    opts.setCleanupHandler(function()
      goBack()
    end)
  end

  if opts.setWakeupHandler then
    opts.setWakeupHandler(function()
      if disposed then return end

      if pendingError then
        pendingError = false
        closeProgress()
        showLoadError()
        return
      end

      if not loaded and pendingStatus and pendingOverride then
        motorCount = tonumber(pendingStatus.motor_count) or 1
        -- What the board already holds is shown rather than silently replaced: a
        -- non-zero value here means something else is driving that motor.
        for i = 0, count() - 1 do
          local value = tonumber(pendingOverride["motor_" .. (i + 1)]) or 0
          if value < 0 then value = 0 end
          percent[i] = math.floor(value * MAX_PERCENT / motorOverride.OVERRIDE_MAX)
        end
        if selected >= count() then selected = 0 end
        loaded = true
        closeProgress()
        buildFields()
        return
      end

      if pendingConfirm ~= nil then
        local enabled = pendingConfirm
        pendingConfirm = nil
        openConfirm(enabled == true)
        return
      end

      if not inOverride then return end

      local now = os.clock()
      if writeInFlight and (now - lastWriteAt) < WRITE_GIVE_UP then return end
      if (now - lastWriteAt) < REFRESH_INTERVAL then return end

      writeOverride(selected, percent[selected] or 0)
    end)
  end

  -- A craft that arms while the page is open cannot be overridden, and a link
  -- that is gone cannot be written to at all. Both hand the motor back -- with
  -- the zeros actually written, not merely by dropping the switch, because the
  -- page has no way to know whether the last write reached the board.
  sessionHandler = function(snapshot)
    local nextConnected = snapshot and snapshot.connected == true
    local nextArmed = snapshot and snapshot.isArmed == true
    if nextConnected == connected and nextArmed == isArmed then return end
    connected = nextConnected
    isArmed = nextArmed
    if not loaded then return end
    if connected == false or isArmed == true then stopOverride() end
    refreshEnabled()
  end
  bus.subscribe("session.update", sessionHandler)

  -- Two reads: MSP_STATUS answers how many motors this board has,
  -- MSP_MOTOR_OVERRIDE what it is already overriding.
  bus.publish("msp.request", status.buildReadMessage(function(data)
    if disposed then return end
    pendingStatus = data or {}
  end, function()
    if disposed then return end
    pendingError = true
  end))

  bus.publish("msp.request", motorOverride.buildReadMessage(function(data)
    if disposed then return end
    pendingOverride = data or {}
  end, function()
    if disposed then return end
    -- A board that will not answer the override read still has a motor count, so
    -- this is not fatal: the page opens with nothing shown as overridden.
    pendingOverride = {}
  end))
end

return {open = open}