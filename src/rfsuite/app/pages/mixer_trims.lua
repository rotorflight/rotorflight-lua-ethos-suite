-- Mixer -> Trims page.
--
-- Edits MIXER_CONFIG swash trims and the tail trim/idle field. Tool
-- toggles mixer override; while enabled, settled edits are live-written
-- without EEPROM so the pilot can trim servos interactively. Save still
-- commits through the normal page_runtime EEPROM path.

local bus = assert(loadfile("lib/bus.lua"))()
local pageRuntime = assert(loadfile("app/page_runtime.lua"))()
local header = assert(loadfile("app/header.lua"))()
local closeKey = assert(loadfile("app/close_key.lua"))()
local mixerConfig = assert(loadfile("lib/msp_mixer_config.lua"))()
local mixerOverride = assert(loadfile("lib/msp_mixer_override.lua"))()

local PAGE_TITLE = "@i18n(app.modules.mixer.trims)@"
local MSG_LOADING = "@i18n(app.msg_loading)@"
local MSG_LOAD_ERROR = "@i18n(app.modules.ports.load_error_prefix)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local LIVE_SETTLE = 0.85

local function isMotorizedMode(mode)
  return (tonumber(mode) or -1) >= 1
end

local function digest(formData)
  return table.concat({
    tostring(formData.swash_trim_0 or ""),
    tostring(formData.swash_trim_1 or ""),
    tostring(formData.swash_trim_2 or ""),
    tostring(formData.tail_center_trim or ""),
    tostring(formData.tail_motor_idle or ""),
  }, "|")
end

local function queueOverride(value)
  for i = 1, 4 do
    bus.publish("msp.request", mixerOverride.buildWriteMessage(i, value))
  end
end

local function openEditor(opts, initialMode)
  local formData = {}
  local inOverride = false
  local lastLiveDigest = nil
  local lastChangeAt = 0
  local motorized = isMotorizedMode(initialMode)

  local runtime
  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "mixer_trims",
    mspModule = mixerConfig,
    opts = opts,
    profileField = "none",
    unloadPackageKeys = {
      "rfsuite.lib.msp_mixer_config",
      "rfsuite.lib.msp_mixer_override",
    },
    onLoaded = function()
      local data = runtime.data or {}
      formData.swash_trim_0 = data.swash_trim_0 or 0
      formData.swash_trim_1 = data.swash_trim_1 or 0
      formData.swash_trim_2 = data.swash_trim_2 or 0
      formData.tail_rotor_mode = data.tail_rotor_mode or 0
      formData.tail_center_trim = data.tail_center_trim or 0
      formData.tail_motor_idle = data.tail_motor_idle or 0
      lastLiveDigest = digest(formData)
      if form.invalidate then form.invalidate() end
    end,
    beforeSave = function(rt)
      local data = rt.data
      if not data then return end
      data.swash_trim_0 = formData.swash_trim_0 or 0
      data.swash_trim_1 = formData.swash_trim_1 or 0
      data.swash_trim_2 = formData.swash_trim_2 or 0
      if isMotorizedMode(formData.tail_rotor_mode) then
        data.tail_motor_idle = formData.tail_motor_idle or 0
      else
        data.tail_center_trim = formData.tail_center_trim or 0
      end
    end,
    onTool = function(focusFn)
      form.openDialog({
        title = inOverride and "@i18n(app.modules.trim.disable_mixer_override)@"
          or "@i18n(app.modules.trim.enable_mixer_override)@",
        message = inOverride and "@i18n(app.modules.trim.disable_mixer_message)@"
          or "@i18n(app.modules.trim.enable_mixer_message)@",
        buttons = {
          {label = BTN_OK, action = function()
            if inOverride then
              queueOverride(mixerOverride.OVERRIDE_OFF)
              inOverride = false
            else
              queueOverride(0)
              inOverride = true
              lastLiveDigest = digest(formData)
              lastChangeAt = os.clock()
            end
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
      if not inOverride or not rt.loaded or rt.activeDialog then return end
      local now = os.clock()
      local current = digest(formData)
      if current ~= lastLiveDigest and (now - lastChangeAt) >= LIVE_SETTLE then
        rt.beforeSave(rt)
        bus.publish("msp.request", mixerConfig.buildWriteMessage(rt.data))
        lastLiveDigest = current
        lastChangeAt = now
      end
    end,
    onDispose = function()
      if inOverride then
        queueOverride(mixerOverride.OVERRIDE_OFF)
        inOverride = false
      end
    end,
  })

  -- Captured instead of closing over `runtime` directly in the field
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

  local function addNumber(label, key, min, max, suffix, decimals)
    local line = form.addLine(label)
    local field = form.addNumberField(line, nil, min, max,
      function() return formData[key] or 0 end,
      function(value)
        markDirty()
        formData[key] = value
        lastChangeAt = os.clock()
      end)
    if suffix then field:suffix(suffix) end
    if decimals then field:decimals(decimals) end
    field:default(0)
    if field.enableInstantChange then field:enableInstantChange(true) end
    runtime:registerField(key, field)
  end

  form.clear()
  runtime:buildChrome()
  addNumber("@i18n(app.modules.trim.roll_trim)@", "swash_trim_0", -1000, 1000, "%", 1)
  addNumber("@i18n(app.modules.trim.pitch_trim)@", "swash_trim_1", -1000, 1000, "%", 1)
  addNumber("@i18n(app.modules.trim.collective_trim)@", "swash_trim_2", -1000, 1000, "%", 1)
  if motorized then
    addNumber("@i18n(app.modules.trim.tail_motor_idle)@", "tail_motor_idle", 0, 250, "%", 1)
  else
    addNumber("@i18n(app.modules.trim.yaw_trim)@", "tail_center_trim", -500, 500, "%", 1)
  end
  runtime:loadInitial()
end

local function open(opts)
  local disposed = false
  local pendingMode = nil
  local pendingError = nil

  form.clear()
  local function goBack()
    disposed = true
    if opts.onBack then opts.onBack() end
  end
  header.build(PAGE_TITLE, {onBack = goBack})
  form.addLine(MSG_LOADING)

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
    end)
  end
  if opts.setWakeupHandler then
    opts.setWakeupHandler(function()
      if disposed then return end
      if pendingMode ~= nil then
        local mode = pendingMode
        pendingMode = nil
        openEditor(opts, mode)
        return
      end
      if pendingError then
        pendingError = nil
        form.clear()
        header.build(PAGE_TITLE, {onBack = goBack})
        form.addLine(MSG_LOAD_ERROR .. " MIXER_CONFIG")
      end
    end)
  end

  bus.publish("msp.request", mixerConfig.buildReadMessage(function(data)
    if disposed then return end
    pendingMode = data and data.tail_rotor_mode or 0
  end, function()
    if disposed then return end
    pendingError = true
  end))
end

return {open = open}
