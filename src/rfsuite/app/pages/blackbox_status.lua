-- Controls -> Blackbox -> Status page.

local requireModule = assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local progressDialog = requireModule("app/progress_dialog.lua")
local dataflashSummary = requireModule("lib/msp_dataflash_summary.lua")
local sdcardSummary = requireModule("lib/msp_sdcard_summary.lua")
local dataflashErase = requireModule("lib/msp_dataflash_erase.lua")

local PAGE_TITLE = "@i18n(app.modules.blackbox.name)@ / @i18n(app.modules.blackbox.menu_status)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local SDCARD_NOT_PRESENT = 0
local SDCARD_FATAL = 1
local SDCARD_CARD_INIT = 2
local SDCARD_FS_INIT = 3
local SDCARD_READY = 4

local function hasBit(mask, bit)
  return math.floor((tonumber(mask or 0) or 0) / (2 ^ bit)) % 2 >= 1
end

local function formatSize(bytes)
  bytes = tonumber(bytes or 0) or 0
  if bytes <= 0 then return "0 B" end
  if bytes < 1024 then return string.format("%d B", bytes) end
  local kb = bytes / 1024
  if kb < 1024 then return string.format("%.1f kB", kb) end
  local mb = kb / 1024
  if mb < 1024 then return string.format("%.1f MB", mb) end
  return string.format("%.2f GB", mb / 1024)
end

local function open(opts)
  opts = opts or {}
  local disposed = false
  local headerHandle = nil
  local dataflashField = nil
  local sdcardField = nil
  local dialog = nil
  local pending = 0
  local lastPoll = 0
  local eraseInProgress = false
  local dataflash = {ready = false, supported = false, total = 0, used = 0}
  local sdcard = {supported = false, state = 0, filesystemLastError = 0, freeSizeKB = 0, totalSizeKB = 0}

  local function dataflashText()
    if not dataflash.supported then return "@i18n(app.modules.blackbox.not_supported)@" end
    if eraseInProgress or not dataflash.ready then return "@i18n(app.modules.blackbox.erasing_busy)@" end
    return string.format("@i18n(app.modules.blackbox.used_fmt)@", formatSize(dataflash.used), formatSize(dataflash.total))
  end

  local function sdcardText()
    if not sdcard.supported then return "@i18n(app.modules.blackbox.not_supported)@" end
    if sdcard.state == SDCARD_NOT_PRESENT then return "@i18n(app.modules.blackbox.no_card)@" end
    if sdcard.state == SDCARD_FATAL then
      return string.format("@i18n(app.modules.blackbox.error_code_fmt)@", sdcard.filesystemLastError or 0)
    end
    if sdcard.state == SDCARD_CARD_INIT then return "@i18n(app.modules.blackbox.initializing_card)@" end
    if sdcard.state == SDCARD_FS_INIT then return "@i18n(app.modules.blackbox.initializing_filesystem)@" end
    if sdcard.state == SDCARD_READY then
      local totalKB = sdcard.totalSizeKB or 0
      local usedKB = math.max(totalKB - (sdcard.freeSizeKB or 0), 0)
      return string.format("@i18n(app.modules.blackbox.used_fmt)@", formatSize(usedKB * 1024), formatSize(totalKB * 1024))
    end
    return string.format("@i18n(app.modules.blackbox.unknown_state_fmt)@", sdcard.state or 0)
  end

  local function updateFields()
    if disposed then return end
    if dataflashField and dataflashField.value then dataflashField:value(dataflashText()) end
    if sdcardField and sdcardField.value then sdcardField:value(sdcardText()) end
    if headerHandle then headerHandle.setReloadEnabled(pending == 0) end
  end

  local function closeDialog(focusFn)
    if not dialog then return end
    dialog:value(100)
    dialog:close()
    dialog = nil
    if focusFn then
      focusFn()
    elseif headerHandle then
      headerHandle.focusMenu()
    end
  end

  local function showProgress(message)
    dialog = progressDialog.open({
      title = "@i18n(app.modules.blackbox.name)@",
      message = message,
    })
  end

  local function finishRead()
    if disposed then return end
    pending = pending - 1
    if pending < 0 then pending = 0 end
    if eraseInProgress and dataflash.ready then
      eraseInProgress = false
      closeDialog(headerHandle and headerHandle.focusTool)
    end
    updateFields()
  end

  local function poll()
    if disposed or pending > 0 then return end
    pending = 2
    updateFields()
    bus.publish("msp.request", dataflashSummary.buildReadMessage(function(data)
      if disposed then return end
      dataflash.ready = hasBit(data.flags, 0)
      dataflash.supported = hasBit(data.flags, 1)
      dataflash.total = data.total or 0
      dataflash.used = data.used or 0
      finishRead()
    end, finishRead))
    bus.publish("msp.request", sdcardSummary.buildReadMessage(function(data)
      if disposed then return end
      sdcard.supported = hasBit(data.flags, 0)
      sdcard.state = data.state or 0
      sdcard.filesystemLastError = data.filesystemLastError or 0
      sdcard.freeSizeKB = data.freeSizeKB or 0
      sdcard.totalSizeKB = data.totalSizeKB or 0
      finishRead()
    end, finishRead))
  end

  local function goBack()
    disposed = true
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    closeDialog()
    if opts.onBack then opts.onBack() end
  end

  local function erase(focusFn)
    if disposed then return end
    eraseInProgress = true
    showProgress("@i18n(app.modules.blackbox.erasing_dataflash)@")
    bus.publish("msp.request", dataflashErase.buildWriteMessage(function()
      if disposed then return end
      poll()
      if not dataflash.supported then
        eraseInProgress = false
        closeDialog(focusFn)
      end
    end, function()
      if disposed then return end
      eraseInProgress = false
      closeDialog(focusFn)
    end))
    updateFields()
  end

  local function confirmErase(focusFn)
    form.openDialog({
      title = "@i18n(app.modules.blackbox.name)@",
      message = "@i18n(app.modules.blackbox.erase_prompt)@",
      buttons = {
        {label = BTN_OK, action = function() erase(focusFn); return true end},
        {label = BTN_CANCEL, action = function() return true end},
      },
      wakeup = function() end,
      paint = function() end,
    })
  end

  form.clear()
  headerHandle = header.build(PAGE_TITLE, {
    onBack = goBack,
    onReload = function()
      poll()
      if headerHandle then headerHandle.focusReload() end
    end,
    onTool = function() confirmErase(headerHandle and headerHandle.focusTool) end,
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
      closeDialog()
    end)
  end
  if opts.setWakeupHandler then
    opts.setWakeupHandler(function()
      local now = os.clock()
      if pending == 0 and now - lastPoll >= 2 then
        lastPoll = now
        poll()
      end
    end)
  end

  local line = form.addLine("@i18n(app.modules.blackbox.dataflash)@")
  dataflashField = form.addStaticText(line, nil, "-")
  line = form.addLine("@i18n(app.modules.blackbox.sdcard)@")
  sdcardField = form.addStaticText(line, nil, "-")
  updateFields()
  poll()
end

return {open = open}
