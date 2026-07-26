-- Shared one-page ESC forward-programming editor.

if package.loaded["rfsuite.app.pages.esc_forward_vendor"] then
  return package.loaded["rfsuite.app.pages.esc_forward_vendor"]
end

local pageRuntime = assert(loadfile("app/page_runtime.lua"))()
local fieldLayout = assert(loadfile("app/field_layout.lua"))()
local fourWay = assert(loadfile("lib/msp_4wif_esc_fwd_prog.lua"))()
local bus = assert(loadfile("lib/bus.lua"))()
local closeKey = assert(loadfile("app/close_key.lua"))()
local header = assert(loadfile("app/header.lua"))()
local escError = assert(loadfile("app/esc_error.lua"))()
local progressDialog = assert(loadfile("app/progress_dialog.lua"))()

local esc_forward_vendor = {}

local MSG_LOADING_TITLE = "@i18n(app.msg_loading)@"
local MSG_LOADING_BODY = "@i18n(app.msg_loading_from_fbl)@"
local RESET_TARGET = 100

local function fieldSpec(mspModule, data, field)
  local key = field.key
  local meta = mspModule.FIELD_META and mspModule.FIELD_META[key] or {}
  return {
    key = key,
    bit = field.bit,
    choices = field.choices or (mspModule.choicesFor and mspModule.choicesFor(data, key)) or meta.choices,
    min = meta.min,
    max = meta.max,
    default = meta.default,
    suffix = meta.suffix,
    decimals = meta.decimals,
    scale = meta.scale,
    step = field.step or meta.step,
  }
end

local function fieldLabel(field, data)
  if type(field.label) == "function" then
    return field.label(data)
  end
  return field.label
end

local function fieldEnabled(field, data)
  if field.enabledWhen then
    return field.enabledWhen(data) == true
  end
  return true
end

local function visibleFields(fields, data)
  local visible = {}
  local pendingGroup = nil
  for i = 1, #fields do
    local field = fields[i]
    if field.group then
      pendingGroup = field
    elseif field.key and fieldEnabled(field, data) then
      if pendingGroup then
        visible[#visible + 1] = pendingGroup
        pendingGroup = nil
      end
      visible[#visible + 1] = field
    end
  end
  return visible
end

function esc_forward_vendor.open(opts, config)
  local mspModule = assert(config.mspModule)
  local fields = assert(config.fields)
  local pageTitle = assert(config.pageTitle)
  local unloadPackageKeys = config.unloadPackageKeys
  local runtime = nil
  local disposed = false
  local wrapperDisposed = false
  local pendingData = nil
  local pendingError = nil
  local dialog = nil
  local goBack

  local function releaseFblControl()
    if not (config and config.release4WayOnExit == true) then return end
    local message = fourWay.buildWriteMessage(RESET_TARGET)
    message.clearQueue = true
    bus.publish("msp.request", message)
  end

  local function closeDialog(force)
    if not dialog then return end
    local d = dialog
    dialog = nil
    pcall(function() d:value(100) end)
    pcall(function() d:close() end)
  end

  local function showProgress()
    closeDialog(true)
    dialog = progressDialog.open({
      title = MSG_LOADING_TITLE,
      message = MSG_LOADING_BODY,
      close = function() closeDialog(true) end,
      speed = config.release4WayOnExit and progressDialog.SPEED.SLOW or progressDialog.SPEED.DEFAULT,
    })
  end

  local function disposePreload()
    if wrapperDisposed then return end
    wrapperDisposed = true
    disposed = true
    releaseFblControl()
    closeDialog(true)
    pendingData = nil
    pendingError = nil
    local runtimeToDispose = runtime
    runtime = nil
    if runtimeToDispose then
      runtimeToDispose:dispose()
    end
    if opts then
      if opts.setEventHandler then opts.setEventHandler(nil) end
      if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
      if opts.setPaintHandler then opts.setPaintHandler(nil) end
      if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    end
    if unloadPackageKeys then
      for _, key in ipairs(unloadPackageKeys) do
        package.loaded[key] = nil
      end
      unloadPackageKeys = nil
    end
    mspModule = nil
    fields = nil
    config = nil
    opts = nil
    pageTitle = nil
    goBack = nil
    collectgarbage()
  end

  local function releaseWrapperRefs()
    if wrapperDisposed then return end
    wrapperDisposed = true
    disposed = true
    releaseFblControl()
    closeDialog(true)
    pendingData = nil
    pendingError = nil
    runtime = nil
    if opts then
      if opts.setEventHandler then opts.setEventHandler(nil) end
      if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
      if opts.setPaintHandler then opts.setPaintHandler(nil) end
      if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    end
    if unloadPackageKeys then
      for _, key in ipairs(unloadPackageKeys) do
        package.loaded[key] = nil
      end
      unloadPackageKeys = nil
    end
    mspModule = nil
    fields = nil
    config = nil
    opts = nil
    pageTitle = nil
    goBack = nil
    collectgarbage()
  end

  goBack = function()
    if runtime then
      runtime:goBack()
      return
    end
    local onBack = opts and opts.onBack
    disposePreload()
    if onBack then onBack() end
  end

  local function buildEditor(data)
    if disposed then return end
    closeDialog(false)
    local pageFields = visibleFields(fields, data)

    runtime = pageRuntime.new({
      pageTitle = pageTitle,
      logTag = config.logTag or pageTitle,
      mspModule = mspModule,
      opts = opts,
      profileField = "none",
      beforeSave = config.beforeSave,
      extraSaveMessage = config.extraSaveMessage,
      eepromWrite = config.eepromWrite,
      rebootAfterSave = config.rebootAfterSave or false,
      unloadPackageKeys = config.unloadPackageKeys,
      initialData = data,
      onLoaded = function()
        if config.onLoaded then config.onLoaded(runtime) end
      end,
      onWakeup = config.onWakeup,
      onDispose = releaseWrapperRefs,
    })

    form.clear()
    runtime:buildChrome()
    if mspModule.summaryFor then
      form.addLine(mspModule.summaryFor(data, pageTitle))
    end

    local panel = nil
    for i = 1, #pageFields do
      local field = pageFields[i]
      if field.group then
        panel = form.addExpansionPanel(field.group)
        panel:open(false)
      else
        fieldLayout.buildSingle(runtime, fieldLabel(field, data), fieldSpec(mspModule, data, field), panel)
      end
    end

    runtime:loadInitial()
  end

  local function isCompatibleEsc(data)
    if mspModule.isCompatible and not mspModule.isCompatible(data) then
      return false
    end

    local expected = mspModule.EXPECTED_SIGNATURE
    if expected == nil then return true end
    return tonumber(data and data.esc_signature) == tonumber(expected)
  end

  form.clear()
  header.build(pageTitle, {onBack = goBack})
  form.addLine("@i18n(app.msg_loading_from_fbl)@")
  showProgress()

  if opts.setEventHandler then
    opts.setEventHandler(function(category, value)
      if not closeKey.shouldHandleClose(category, value) then return false end
      goBack()
      return true
    end)
  end

  if opts.setWakeupHandler then
    opts.setWakeupHandler(function()
      if disposed then return end
      if pendingData then
        local data = pendingData
        pendingData = nil
        buildEditor(data)
      elseif pendingError then
        local err = pendingError
        pendingError = nil
        closeDialog(false)
        form.clear()
        header.build(pageTitle, {onBack = goBack})
        escError.addLines(err)
      end
    end)
  end

  if opts.setCleanupHandler then
    opts.setCleanupHandler(function()
      if runtime then
        local runtimeToDispose = runtime
        runtime = nil
        runtimeToDispose:dispose()
      else
        disposePreload()
      end
    end)
  end

  bus.publish("msp.request", mspModule.buildReadMessage(function(data)
    if disposed then return end
    if not isCompatibleEsc(data) then
      pendingError = {
        kind = "signature",
        expected = mspModule.EXPECTED_SIGNATURE,
        actual = data and data.esc_signature,
      }
      return
    end
    pendingData = data
  end, function(reason)
    if disposed then return end
    pendingError = reason or true
  end))
end

package.loaded["rfsuite.app.pages.esc_forward_vendor"] = esc_forward_vendor
return esc_forward_vendor
