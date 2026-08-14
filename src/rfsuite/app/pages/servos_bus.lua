-- Servos -> BUS Output.
--
-- BUS servos look almost identical to PWM in the UI, but the firmware
-- indexes them differently. The original suite uses:
--   read/center/override index = UI index + 8
--   config write index         = UI index + (servo_count - 18)
-- Keep those translations local and explicit here.

local requireModule = assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local header = requireModule("app/header.lua")
local pageRuntime = requireModule("app/page_runtime.lua")
local tileGrid = requireModule("app/tile_grid.lua")
local progressDialog = requireModule("app/progress_dialog.lua")
local eeprom = requireModule("lib/msp_eeprom.lua")
local mixerConfig = requireModule("lib/msp_mixer_config.lua")
local servoCenter = requireModule("lib/msp_servo_center.lua")
local servoConfig = requireModule("lib/msp_servo_config.lua")
local servoOverride = requireModule("lib/msp_servo_override.lua")
local status = requireModule("lib/msp_status.lua")

local PAGE_TITLE = "@i18n(app.modules.servos.bus)@"
local MSG_LOADING_TITLE = "@i18n(app.msg_loading)@"
local MSG_LOADING_BODY = "@i18n(app.msg_loading_from_fbl)@"
local MSG_LOAD_ERROR = "@i18n(app.modules.ports.load_error_prefix)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local BUS_OUTPUT_COUNT = 16
local BUS_CONFIG_OFFSET = 18
local BUS_READ_BASE_INDEX = 8
local LIVE_SETTLE = 0.05

local YES_NO = {
  {"@i18n(app.modules.servos.tbl_no)@", 0},
  {"@i18n(app.modules.servos.tbl_yes)@", 1},
}

local BUS_FIELD_META = {
  mid = {min = 1000, max = 2000, default = 1500},
  min = {min = -500, max = -1, default = -500},
  max = {min = 1, max = 500, default = 500},
  rneg = {min = 100, max = 1000, default = 500},
  rpos = {min = 100, max = 1000, default = 500},
  speed = {min = 0, max = 60000, default = 0, suffix = "ms"},
}

local function servoTitle(index)
  return "@i18n(app.modules.servos.servo_prefix)@" .. index
end

local function readIndex(uiIndex)
  return (uiIndex or 0) + BUS_READ_BASE_INDEX
end

local function configWriteIndex(uiIndex, servoCount)
  local offset = (tonumber(servoCount) or BUS_CONFIG_OFFSET) - BUS_CONFIG_OFFSET
  local value = (uiIndex or 0) + offset
  if value < 0 then return 0 end
  return value
end

local function applyMixerNames(rows, swashMode, tailMode)
  if swashMode == 2 or swashMode == 3 or swashMode == 4 then
    if rows[1] then rows[1].title = "@i18n(app.modules.servos.cyc_pitch)@"; rows[1].icon = "servos_cpitch.png" end
    if rows[2] then rows[2].title = "@i18n(app.modules.servos.cyc_left)@"; rows[2].icon = "servos_cleft.png" end
    if rows[3] then rows[3].title = "@i18n(app.modules.servos.cyc_right)@"; rows[3].icon = "servos_cright.png" end
  end
  if tailMode == 0 and rows[4] then
    rows[4].title = "@i18n(app.modules.servos.tail)@"
    rows[4].icon = "servos_tail.png"
  end
end

local function buildRows(mixer)
  local rows = {}
  for i = 1, BUS_OUTPUT_COUNT do
    rows[i] = {uiIndex = i - 1, title = servoTitle(i), icon = "servo" .. i .. ".png"}
  end
  applyMixerNames(rows, mixer and mixer.swash_type or 0, mixer and mixer.tail_rotor_mode or 0)
  return rows
end

local function flagsFor(reverse, geometry)
  if reverse == 1 and geometry == 1 then return 3 end
  if geometry == 1 then return 2 end
  if reverse == 1 then return 1 end
  return 0
end

local function unpackFlags(data)
  local flags = data.flags or 0
  data.reverse = (flags == 1 or flags == 3) and 1 or 0
  data.geometry = (flags == 2 or flags == 3) and 1 or 0
end

local function publishOverrideAll(value)
  bus.publish("msp.request", servoOverride.buildWriteAllMessage(value))
end

local function publishOverride(index, value)
  bus.publish("msp.request", servoOverride.buildWriteMessage(index, value))
end

local openList

local function openEditor(opts, listState, row)
  local inheritedOverride = listState.inOverride == true
  local inOverride = inheritedOverride
  local lastCenter = nil
  local lastChangeAt = 0
  local uiIndex = row.uiIndex
  local rwIndex = readIndex(uiIndex)
  local writeIndex = configWriteIndex(uiIndex, listState.servoCount)

  local pageMsp = {
    FIELD_META = BUS_FIELD_META,
    buildReadMessage = function(onData, onError)
      return servoConfig.buildReadMessage(rwIndex, onData, onError)
    end,
    buildWriteMessage = function(data, onWritten, onError)
      return servoConfig.buildWriteMessage(writeIndex, data, onWritten, onError)
    end,
  }

  local function disableOverride()
    if listState.inOverride then
      publishOverrideAll(servoOverride.OVERRIDE_OFF)
      listState.inOverride = false
    else
      publishOverride(rwIndex, servoOverride.OVERRIDE_OFF)
    end
    inOverride = false
  end

  local runtime
  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE .. " / " .. row.title,
    logTag = "servos_bus_editor",
    mspModule = pageMsp,
    opts = {
      onBack = function()
        if inOverride and not inheritedOverride then disableOverride() end
        openList(opts, listState)
      end,
      setEventHandler = opts.setEventHandler,
      setWakeupHandler = opts.setWakeupHandler,
      setPaintHandler = opts.setPaintHandler,
      setCleanupHandler = opts.setCleanupHandler,
    },
    profileField = "none",
    unloadPackageKeys = {
      "rfsuite.lib.msp_servo_center",
      "rfsuite.lib.msp_servo_config",
      "rfsuite.lib.msp_servo_override",
    },
    onLoaded = function()
      unpackFlags(runtime.data)
      lastCenter = runtime.data.mid
      if inOverride then
        for key, field in pairs(runtime.fields) do
          if key ~= "mid" then field:enable(false) end
        end
      end
      if form.invalidate then form.invalidate() end
    end,
    beforeSave = function(rt)
      rt.data.flags = flagsFor(rt.data.reverse, rt.data.geometry)
    end,
    onTool = function(focusFn)
      form.openDialog({
        title = inOverride and "@i18n(app.modules.servos.disable_servo_override)@"
          or "@i18n(app.modules.servos.enable_servo_override)@",
        message = inOverride and "@i18n(app.modules.servos.disable_servo_override_msg)@"
          or "@i18n(app.modules.servos.enable_servo_override_msg)@",
        buttons = {
          {label = BTN_OK, action = function()
            if inOverride then
              disableOverride()
              inheritedOverride = false
              for key, field in pairs(runtime.fields) do
                if key ~= "mid" then field:enable(runtime.loaded) end
              end
            else
              publishOverride(rwIndex, servoOverride.OVERRIDE_CENTER)
              inOverride = true
              inheritedOverride = false
              lastCenter = runtime.data.mid
              lastChangeAt = os.clock()
              for key, field in pairs(runtime.fields) do
                if key ~= "mid" then field:enable(false) end
              end
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
      local current = rt.data.mid
      if current ~= lastCenter and (now - lastChangeAt) >= LIVE_SETTLE then
        bus.publish("msp.request", servoCenter.buildWriteMessage(rwIndex, current))
        lastCenter = current
        lastChangeAt = now
      end
    end,
    onDispose = function()
      if inOverride and not inheritedOverride then disableOverride() end
    end,
  })

  form.clear()
  runtime:buildChrome()
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.servos.center)@", {key = "mid"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.servos.minimum)@", {key = "min"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.servos.maximum)@", {key = "max"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.servos.scale_negative)@", {key = "rneg"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.servos.scale_positive)@", {key = "rpos"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.servos.speed)@", {key = "speed"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.servos.reverse)@", {key = "reverse", choices = YES_NO})
  if uiIndex <= 7 then
    fieldLayout.buildSingle(runtime, "@i18n(app.modules.servos.geometry)@", {key = "geometry", choices = YES_NO})
  end
  runtime:loadInitial()
end

openList = function(opts, listState)
  local rows = listState.rows or {}
  local selected = listState.selected or 1

  local function leaveList()
    if listState.inOverride then
      publishOverrideAll(servoOverride.OVERRIDE_OFF)
      listState.inOverride = false
      bus.publish("msp.request", eeprom.buildWriteMessage())
    end
    if opts.onBack then opts.onBack() end
  end

  form.clear()
  local headerHandle = header.build(PAGE_TITLE, {
    onBack = leaveList,
    onTool = function(focusFn)
      form.openDialog({
        title = listState.inOverride and "@i18n(app.modules.servos.disable_servo_override)@"
          or "@i18n(app.modules.servos.enable_servo_override)@",
        message = listState.inOverride and "@i18n(app.modules.servos.disable_servo_override_msg)@"
          or "@i18n(app.modules.servos.enable_servo_override_msg)@",
        buttons = {
          {label = BTN_OK, action = function()
            if listState.inOverride then
              publishOverrideAll(servoOverride.OVERRIDE_OFF)
              listState.inOverride = false
              bus.publish("msp.request", eeprom.buildWriteMessage())
            else
              publishOverrideAll(servoOverride.OVERRIDE_CENTER)
              listState.inOverride = true
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
  })

  if opts.setEventHandler then
    opts.setEventHandler(function(category, value)
      if closeKey.shouldHandleClose(category, value) then
        leaveList()
        return true
      end
      return false
    end)
  end
  if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
  if opts.setPaintHandler then opts.setPaintHandler(nil) end
  if opts.setCleanupHandler then
    opts.setCleanupHandler(function()
      if listState.inOverride then
        publishOverrideAll(servoOverride.OVERRIDE_OFF)
        listState.inOverride = false
      end
    end)
  end

  local windowWidth, windowHeight = lcd.getWindowSize()
  local numPerRow, tileW, tileH, tilePadding, tileFont = tileGrid.metrics(windowWidth, windowHeight)
  local x, y = 0, form.height() + tilePadding
  local col = 0
  local buttons = {}

  for i, row in ipairs(rows) do
    buttons[i] = form.addButton(nil, {x = x, y = y, w = tileW, h = tileH}, {
      text = row.title,
      icon = lcd.loadMask("app/gfx/" .. row.icon),
      options = tileFont,
      press = function()
        listState.selected = i
        openEditor(opts, listState, row)
      end,
    })
    col = col + 1
    if col >= numPerRow then
      col = 0
      x = 0
      y = y + tileH + tilePadding
    else
      x = x + tileW + tilePadding
    end
  end

  if buttons[selected] then
    buttons[selected]:focus()
  else
    headerHandle.focusMenu()
  end
end

local function open(opts)
  local disposed = false
  local pendingStatus = nil
  local pendingMixer = nil
  local pendingError = nil
  local dialog = nil
  local listState = {inOverride = false}

  local function closeDialog(force)
    if not dialog then return end
    local d = dialog
    dialog = nil
    pcall(function() d:value(100) end)
    pcall(function() d:close(force == true) end)
  end

  local function goBack()
    disposed = true
    closeDialog(true)
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
      closeDialog(true)
    end)
  end
  if opts.setWakeupHandler then
    opts.setWakeupHandler(function()
      if disposed then return end
      if pendingError then
        pendingError = nil
        closeDialog()
        form.clear()
        header.build(PAGE_TITLE, {onBack = goBack})
        form.addLine(MSG_LOAD_ERROR .. " STATUS/MIXER_CONFIG")
        return
      end
      if pendingStatus and pendingMixer then
        listState.servoCount = pendingStatus.servo_count
        listState.rows = buildRows(pendingMixer)
        closeDialog()
        opts.setWakeupHandler(nil)
        openList(opts, listState)
      end
    end)
  end

  bus.publish("msp.request", status.buildReadMessage(function(data)
    if disposed then return end
    pendingStatus = data
  end, function()
    if disposed then return end
    pendingError = true
  end))
  bus.publish("msp.request", mixerConfig.buildReadMessage(function(data)
    if disposed then return end
    pendingMixer = data
  end, function()
    if disposed then return end
    pendingError = true
  end))
end

return {open = open}
