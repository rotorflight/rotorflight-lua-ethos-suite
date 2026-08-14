-- Developer -> MSP Experimental.

local requireModule = assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local settingsStore = requireModule("lib/settings_store.lua")
local mspExp = requireModule("lib/msp_experimental.lua")
local eeprom = requireModule("lib/msp_eeprom.lua")

local PAGE_TITLE = "@i18n(app.modules.settings.txt_developer)@ / @i18n(app.modules.msp_exp.name)@"
local MSG_LOADING = "@i18n(app.msg_loading)@"
local MSG_SAVING = "@i18n(app.msg_saving)@"
local DEFAULT_BYTES = 8

local function clamp(value, min, max)
  value = math.floor((tonumber(value) or min) + 0.5)
  if value < min then return min end
  if value > max then return max end
  return value
end

local function uintToInt(value)
  value = clamp(value, 0, 255)
  if value > 127 then return value - 256 end
  return value
end

local function intToUint(value)
  value = clamp(value, -128, 127)
  if value < 0 then return value + 256 end
  return value
end

local function byteCount(settings)
  local developer = settings and settings.developer
  return clamp(developer and developer.mspexpbytes or DEFAULT_BYTES, 1, 16)
end

local function open(opts)
  opts = opts or {}
  local disposed = false
  local headerHandle
  local settings = settingsStore.load()
  settings.developer = settings.developer or {}
  local totalBytes = byteCount(settings)
  local values = {}
  local fields = {}
  local pendingRead
  local pendingError
  local pendingSaved
  local dialog

  for i = 1, 16 do values[i] = 0 end

  local function updateSaveEnabled()
    if headerHandle then
      headerHandle.setSaveEnabled(pendingRead == nil)
      headerHandle.setReloadEnabled(pendingRead == nil)
    end
  end

  local function closeDialog(focusFn)
    if dialog then
      dialog:value(100)
      dialog:close()
      dialog = nil
    end
    if focusFn then focusFn() end
  end

  local function showDialog(title)
    closeDialog()
    dialog = form.openProgressDialog({
      title = title,
      message = title,
      close = function() end,
      wakeup = function()
        if dialog then dialog:value(60) end
      end,
    })
    if dialog then
      dialog:value(0)
      dialog:closeAllowed(false)
    end
  end

  local function setFieldValue(field, value)
    if field and type(field.value) == "function" then
      field:value(value)
    end
  end

  local function applyValues()
    for i = 1, totalBytes do
      setFieldValue(fields.uint[i], values[i] or 0)
      setFieldValue(fields.int[i], uintToInt(values[i] or 0))
    end
  end

  local function requestRead(focusFn)
    if disposed then return end
    showDialog(MSG_LOADING)
    pendingRead = true
    pendingError = nil
    updateSaveEnabled()
    bus.publish("msp.request", mspExp.buildReadMessage(function(bytes)
      pendingRead = bytes
    end, function(reason)
      pendingError = reason or "error"
      pendingRead = nil
    end))
    if focusFn then focusFn() end
  end

  local function save(focusFn)
    if disposed then return end
    showDialog(MSG_SAVING)
    bus.publish("msp.request", mspExp.buildWriteMessage(values, function()
      bus.publish("msp.request", eeprom.buildWriteMessage(function()
        pendingSaved = true
      end, function(reason)
        pendingError = reason or "save_error"
      end))
    end, function(reason)
      pendingError = reason or "write_error"
    end))
    if focusFn then focusFn() end
  end

  local function goBack()
    if disposed then return end
    disposed = true
    closeDialog()
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    settings = nil
    fields = nil
    if opts.onBack then opts.onBack() end
  end

  form.clear()
  headerHandle = header.build(PAGE_TITLE, {
    onBack = goBack,
    onSave = function() save(headerHandle and headerHandle.focusSave) end,
    onReload = function() requestRead(headerHandle and headerHandle.focusReload) end,
  })

  local headerLine = form.addLine("")
  local headerSlots = form.getFieldSlots(headerLine, {0, 0})
  form.addStaticText(headerLine, headerSlots[1], "UINT8", CENTERED)
  form.addStaticText(headerLine, headerSlots[2], "INT8", CENTERED)

  fields = {uint = {}, int = {}}
  for i = 1, totalBytes do
    local line = form.addLine(tostring(i))
    local slots = form.getFieldSlots(line, {0, 0})
    fields.uint[i] = form.addNumberField(line, slots[1], 0, 255, function()
      return values[i] or 0
    end, function(value)
      values[i] = clamp(value, 0, 255)
      if fields.int then setFieldValue(fields.int[i], uintToInt(values[i])) end
    end)
    fields.int[i] = form.addNumberField(line, slots[2], -128, 127, function()
      return uintToInt(values[i] or 0)
    end, function(value)
      values[i] = intToUint(value)
      if fields.uint then setFieldValue(fields.uint[i], values[i]) end
    end)
  end

  local function wakeup()
    if disposed then return end
    if type(pendingRead) == "table" then
      local bytes = pendingRead
      pendingRead = nil
      for i = 1, 16 do values[i] = bytes[i] or 0 end
      if #bytes > 0 and #bytes ~= totalBytes then
        settings.developer.mspexpbytes = #bytes
        settingsStore.save(settings)
        closeDialog()
        open(opts)
        return
      end
      closeDialog(headerHandle and headerHandle.focusReload)
      updateSaveEnabled()
      applyValues()
    elseif pendingError then
      pendingError = nil
      pendingRead = nil
      closeDialog(headerHandle and headerHandle.focusMenu)
      updateSaveEnabled()
    elseif pendingSaved then
      pendingSaved = nil
      closeDialog(headerHandle and headerHandle.focusSave)
    end
  end

  if opts.setEventHandler then
    opts.setEventHandler(function(category, value)
      if not closeKey.shouldHandleClose(category, value) then return false end
      goBack()
      return true
    end)
  end
  if opts.setWakeupHandler then opts.setWakeupHandler(wakeup) end
  if opts.setCleanupHandler then opts.setCleanupHandler(goBack) end

  requestRead()
end

return {open = open}
