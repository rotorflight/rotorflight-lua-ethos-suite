-- Shared 4-way ESC target selector for forward-programming pages.

if package.loaded["rfsuite.app.pages.esc_forward_4way"] then
  return package.loaded["rfsuite.app.pages.esc_forward_4way"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local fourWay = requireModule("lib/msp_4wif_esc_fwd_prog.lua")
local motorConfig = requireModule("lib/msp_motor_config.lua")
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local escError = requireModule("app/esc_error.lua")
local progressDialog = requireModule("app/progress_dialog.lua")

local SELECT_ESC = "@i18n(app.modules.esc_tools.select_esc)@"
local OPEN_LABEL = "@i18n(app.modules.esc_tools.open)@"
local MSG_LOADING_TITLE = "@i18n(app.msg_loading)@"
local MSG_LOADING_BODY = "@i18n(app.msg_loading_from_fbl)@"

local DEFAULT_PRE_SWITCH_TARGET = 100
local DEFAULT_PRE_SWITCH_DELAY = 0.8
local DEFAULT_SWITCH_READ_DELAY = 5.0
local DEFAULT_PRE_SWITCH_WRITE_COUNT = 1
local DEFAULT_SWITCH_WRITE_COUNT = 1
local DEFAULT_SWITCH_MAX_ATTEMPTS = 10
local DEFAULT_SWITCH_RETRY_DELAY = 0.8
local DEFAULT_WRITE_MAX_RETRIES = 2
local RESET_TARGET = 100

local TARGETS = {
  {label = "ESC 1", target = 0},
  {label = "ESC 2", target = 1},
  {label = "ESC 3", target = 2},
  {label = "ESC 4", target = 3},
}

local function simDelay(seconds)
  if system.getVersion().simulation == true then return 0.1 end
  return seconds
end

local function clampTargetCount(count)
  count = tonumber(count) or 1
  count = math.floor(count)
  if count < 1 then return 1 end
  if count > #TARGETS then return #TARGETS end
  return count
end

local function positiveInt(value, fallback, minValue)
  value = tonumber(value)
  if value == nil then value = fallback end
  value = math.floor(value)
  minValue = minValue or 0
  if value < minValue then return minValue end
  return value
end

local function open(opts, config)
  local pageTitle = assert(config.pageTitle)
  local openEditor = assert(config.openEditor)
  local preSwitchTarget = config.preSwitchTarget or DEFAULT_PRE_SWITCH_TARGET
  local preSwitchDelay = config.preSwitchDelay or DEFAULT_PRE_SWITCH_DELAY
  local switchReadDelay = config.switchReadDelay or DEFAULT_SWITCH_READ_DELAY
  local preSwitchWriteCount = positiveInt(config.preSwitchWriteCount, DEFAULT_PRE_SWITCH_WRITE_COUNT, 0)
  local switchWriteCount = positiveInt(config.switchWriteCount, DEFAULT_SWITCH_WRITE_COUNT, 1)
  local switchMaxAttempts = positiveInt(config.switchMaxAttempts, DEFAULT_SWITCH_MAX_ATTEMPTS, 1)
  local switchRetryDelay = config.switchRetryDelay or DEFAULT_SWITCH_RETRY_DELAY
  local writeMaxRetries = positiveInt(config.writeMaxRetries, DEFAULT_WRITE_MAX_RETRIES, 0)
  local disposed = false
  local state = "loading_count"
  local selected = nil
  local nextAt = 0
  local errorText = nil
  local switchPhase = nil
  local targetCount = nil
  local buildSelectorPending = false
  local dialog = nil
  local selectTarget
  local processSwitchPhase

  local function closeDialog(force)
    if not dialog then return end
    local d = dialog
    dialog = nil
    pcall(function() d:value(100) end)
    pcall(function() d:close() end)
  end

  local function showProgress(title, message)
    closeDialog(true)
    dialog = progressDialog.open({
      title = title,
      message = message,
      close = function() closeDialog(true) end,
      speed = progressDialog.SPEED.VSLOW,
    })
  end

  local function releaseFblControl()
    local message = fourWay.buildWriteMessage(RESET_TARGET)
    message.clearQueue = true
    bus.publish("msp.request", message)
  end

  local function dispose(returnControl)
    disposed = true
    switchPhase = nil
    closeDialog(true)
    if opts.setEventHandler then opts.setEventHandler(nil) end
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setPaintHandler then opts.setPaintHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    if returnControl then releaseFblControl() end
    collectgarbage()
  end

  local function goBack()
    dispose(true)
    if opts.onBack then opts.onBack() end
  end

  local function setStatus(text)
    form.clear()
    header.build(pageTitle, {onBack = goBack})
    form.addLine(text)
  end

  local function setErrorStatus(reason)
    form.clear()
    header.build(pageTitle, {onBack = goBack})
    escError.addLines(reason)
  end

  local function fail(reason)
    state = "error"
    errorText = reason or true
  end

  local function writeTarget(target, onWritten, onError)
    bus.publish("msp.request", fourWay.buildWriteMessage(target, onWritten, onError or fail, {
      maxRetries = writeMaxRetries,
    }))
  end

  local function switchFailed(reason)
    local label = selected and selected.label or "ESC"
    if reason == "max_retries" or reason == "timeout" then
      fail("Timed out selecting " .. label .. ". Check ESC power and try again.")
    else
      fail(reason or ("Unable to select " .. label .. "."))
    end
  end

  processSwitchPhase = function()
    if disposed or not switchPhase then return end
    if switchPhase.done >= switchPhase.count then
      local onComplete = switchPhase.onComplete
      switchPhase = nil
      if onComplete then onComplete() end
      return
    end

    if switchPhase.attempts >= switchMaxAttempts then
      switchFailed("timeout")
      return
    end

    switchPhase.attempts = switchPhase.attempts + 1
    state = "switch_write"
    writeTarget(switchPhase.target, function()
      if disposed or not switchPhase then return end
      switchPhase.done = switchPhase.done + 1
      switchPhase.attempts = 0
      if switchPhase.done >= switchPhase.count then
        local onComplete = switchPhase.onComplete
        switchPhase = nil
        if onComplete then onComplete() end
      else
        nextAt = os.clock() + simDelay(switchRetryDelay)
        state = "wait_switch_retry"
      end
    end, function(reason)
      if disposed or not switchPhase then return end
      if switchPhase.attempts >= switchMaxAttempts then
        switchFailed(reason)
      else
        nextAt = os.clock() + simDelay(switchRetryDelay)
        state = "wait_switch_retry"
      end
    end)
  end

  local function startSwitchPhase(target, count, onComplete)
    switchPhase = {
      target = target,
      count = count,
      done = 0,
      attempts = 0,
      onComplete = onComplete,
    }
    processSwitchPhase()
  end

  local function buildSelector()
    if disposed then return end
    closeDialog(false)
    state = "idle"
    form.clear()
    header.build(pageTitle, {onBack = goBack})
    form.addLine(SELECT_ESC)
    for i = 1, #TARGETS do
      local item = TARGETS[i]
      local line = form.addLine(item.label)
      local slots = form.getFieldSlots(line, {0, " Open "})
      local button = form.addButton(line, slots[2], {
        text = OPEN_LABEL,
        options = FONT_S + CENTERED,
        press = function() selectTarget(item) end,
      })
      if button and button.enable then
        button:enable(i <= targetCount)
      end
    end
  end

  selectTarget = function(item)
    if state ~= "idle" then return end
    selected = item
    state = "pre_switch"
    setStatus("Selecting " .. item.label .. "...")
    showProgress(MSG_LOADING_TITLE, "Selecting " .. item.label .. "...")
    startSwitchPhase(preSwitchTarget, preSwitchWriteCount, function()
      nextAt = os.clock() + simDelay(preSwitchDelay)
      state = "wait_pre"
    end)
  end

  form.clear()
  header.build(pageTitle, {onBack = goBack})
  form.addLine("@i18n(app.msg_loading_from_fbl)@")
  showProgress(MSG_LOADING_TITLE, MSG_LOADING_BODY)

  if opts.setEventHandler then
    opts.setEventHandler(function(category, value)
      if not closeKey.shouldHandleClose(category, value) then return false end
      goBack()
      return true
    end)
  end

  bus.publish("msp.request", motorConfig.buildReadMessage(function(data)
    if disposed then return end
    targetCount = clampTargetCount(data and data.motor_count_blheli)
    buildSelectorPending = true
  end, function()
    if disposed then return end
    targetCount = 1
    buildSelectorPending = true
  end))

  if opts.setCleanupHandler then opts.setCleanupHandler(function() dispose(true) end) end
  if opts.setWakeupHandler then
    opts.setWakeupHandler(function()
      if disposed then return end
      if buildSelectorPending then
        buildSelectorPending = false
        buildSelector()
      elseif state == "wait_pre" and os.clock() >= nextAt then
        state = "switch"
        startSwitchPhase(selected.target, switchWriteCount, function()
          nextAt = os.clock() + simDelay(switchReadDelay)
          state = "wait_read"
        end)
      elseif state == "wait_switch_retry" and os.clock() >= nextAt then
        processSwitchPhase()
      elseif state == "wait_read" and os.clock() >= nextAt then
        dispose(false)
        openEditor(opts, selected)
      elseif state == "error" and errorText then
        local reason = errorText
        errorText = nil
        closeDialog(false)
        setErrorStatus(reason)
      end
    end)
  end
end

local esc_forward_4way = {open = open}
package.loaded["rfsuite.app.pages.esc_forward_4way"] = esc_forward_4way
return esc_forward_4way
