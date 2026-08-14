-- Shared page builder for Controls -> Beepers subpages.
--
-- Pure factory only: each caller owns its page state, and the only shared
-- module state is package.loaded caching for this stateless builder.

if package.loaded["rfsuite.app.pages.beepers_page"] then
  return package.loaded["rfsuite.app.pages.beepers_page"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local progressDialog = requireModule("app/progress_dialog.lua")
local eeprom = requireModule("lib/msp_eeprom.lua")
local beeperConfig = requireModule("lib/msp_beeper_config.lua")

local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local MSG_LOADING_TITLE = "@i18n(app.msg_loading)@"
local MSG_LOADING_BODY = "@i18n(app.msg_loading_from_fbl)@"
local MSG_SAVING_TITLE = "@i18n(app.msg_saving)@"
local MSG_SAVING_BODY = "@i18n(app.msg_saving_settings)@"
local MSG_SAVE_TITLE = "@i18n(app.msg_save_settings)@"
local MSG_SAVE_BODY = "@i18n(app.msg_save_current_page)@"
local MSG_RELOAD_TITLE = "@i18n(reload)@"
local MSG_RELOAD_BODY = "@i18n(app.msg_reload_settings)@"

local function maskForBit(bit)
  return 2 ^ bit
end

local function isBitSet(mask, bit)
  local flag = maskForBit(bit)
  return math.floor((tonumber(mask or 0) or 0) / flag) % 2 >= 1
end

local function setBit(mask, bit, enabled)
  mask = tonumber(mask or 0) or 0
  local flag = maskForBit(bit)
  local wasEnabled = isBitSet(mask, bit)
  if enabled == true and not wasEnabled then return mask + flag end
  if enabled ~= true and wasEnabled then return mask - flag end
  return mask
end

local function sameConfig(a, b)
  return (a.beeper_off_flags or 0) == (b.beeper_off_flags or 0)
    and (a.dshotBeaconTone or 1) == (b.dshotBeaconTone or 1)
    and (a.dshotBeaconOffFlags or 0) == (b.dshotBeaconOffFlags or 0)
end

local beepers_page = {}

function beepers_page.new(config)
  local page = {}

  function page.open(opts)
    opts = opts or {}
    local disposed = false
    local headerHandle = nil
    local dialog = nil
    local loaded = false
    local busy = false
    local current = beeperConfig.defaultConfig()
    local original = beeperConfig.defaultConfig()
    local fields = {}
    local pageTitle = config.title

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

    local function showProgress(title, message)
      dialog = progressDialog.open({
        title = title,
        message = message,
      })
    end

    local function applyBusy(value)
      busy = value == true
      if headerHandle then
        local enabled = loaded and not busy and not sameConfig(current, original)
        headerHandle.setSaveEnabled(enabled)
        headerHandle.setReloadEnabled(not busy)
      end
      for _, field in ipairs(fields) do
        field:enable(loaded and not busy)
      end
    end

    local function markDirty()
      if headerHandle then
        headerHandle.setSaveEnabled(loaded and not busy and not sameConfig(current, original))
      end
    end

    local function goBack()
      disposed = true
      if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
      if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
      closeDialog()
      if opts.onBack then opts.onBack() end
    end

    local function loadData(focusFn)
      if disposed then return end
      loaded = false
      applyBusy(true)
      showProgress(MSG_LOADING_TITLE, MSG_LOADING_BODY)
      bus.publish("msp.request", beeperConfig.buildReadMessage(function(data)
        if disposed then return end
        current = beeperConfig.clone(data)
        original = beeperConfig.clone(data)
        loaded = true
        applyBusy(false)
        closeDialog(focusFn)
        if form.invalidate then form.invalidate() end
      end, function()
        if disposed then return end
        applyBusy(false)
        closeDialog(focusFn)
      end))
    end

    local function saveData(focusFn)
      if disposed or not loaded then return end
      applyBusy(true)
      showProgress(MSG_SAVING_TITLE, MSG_SAVING_BODY)
      bus.publish("msp.request", beeperConfig.buildWriteMessage(current, function()
        if disposed then return end
        bus.publish("msp.request", eeprom.buildWriteMessage(function()
          if disposed then return end
          original = beeperConfig.clone(current)
          applyBusy(false)
          closeDialog(focusFn)
        end, function()
          if disposed then return end
          applyBusy(false)
          closeDialog(focusFn)
        end))
      end, function()
        if disposed then return end
        applyBusy(false)
        closeDialog(focusFn)
      end))
    end

    local function confirmSave(focusFn)
      form.openDialog({
        title = MSG_SAVE_TITLE,
        message = MSG_SAVE_BODY,
        buttons = {
          {label = BTN_OK, action = function() saveData(focusFn); return true end},
          {label = BTN_CANCEL, action = function() return true end},
        },
        wakeup = function() end,
        paint = function() end,
      })
    end

    local function confirmReload(focusFn)
      form.openDialog({
        title = MSG_RELOAD_TITLE,
        message = MSG_RELOAD_BODY,
        buttons = {
          {label = BTN_OK, action = function() loadData(focusFn); return true end},
          {label = BTN_CANCEL, action = function() return true end},
        },
        wakeup = function() end,
        paint = function() end,
      })
    end

    form.clear()
    headerHandle = header.build(pageTitle, {
      onBack = goBack,
      onSave = function() confirmSave(headerHandle and headerHandle.focusSave) end,
      onReload = function() confirmReload(headerHandle and headerHandle.focusReload) end,
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
      opts.setWakeupHandler(nil)
    end

    if config.tone == true then
      local toneLine = form.addLine("@i18n(app.modules.beepers.dshot_tone)@")
      local tone = form.addChoiceField(toneLine, nil, {
        {"1", 1},
        {"2", 2},
        {"3", 3},
        {"4", 4},
        {"5", 5},
      }, function()
        return current.dshotBeaconTone or 1
      end, function(value)
        current.dshotBeaconTone = value
        markDirty()
      end)
      tone:enable(false)
      fields[#fields + 1] = tone
    end

    for _, def in ipairs(config.fields or {}) do
      local line = form.addLine(def.label)
      local field = form.addBooleanField(line, nil, function()
        return not isBitSet(current[def.maskField], def.bit)
      end, function(value)
        current[def.maskField] = setBit(current[def.maskField], def.bit, value ~= true)
        markDirty()
      end)
      field:enable(false)
      fields[#fields + 1] = field
    end

    loadData()
  end

  return page
end

package.loaded["rfsuite.app.pages.beepers_page"] = beepers_page
return beepers_page
