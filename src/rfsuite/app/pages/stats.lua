-- Controls -> Stats page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local modelPreferences = requireModule("lib/model_preferences.lua")

local PAGE_TITLE = "@i18n(app.modules.stats.name)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local MSG_SAVE_TITLE = "@i18n(app.msg_save_settings)@"
local MSG_SAVE_BODY = "@i18n(app.modules.stats.save_prompt)@"
local MSG_RELOAD_TITLE = "@i18n(reload)@"
local MSG_RELOAD_BODY = "@i18n(app.modules.stats.reload_prompt)@"

local function copyStats(stats)
  stats = stats or {}
  return {
    flightcount = tonumber(stats.flightcount) or 0,
    lastflighttime = tonumber(stats.lastflighttime) or 0,
    totalflighttime = tonumber(stats.totalflighttime) or 0,
  }
end

local function sameStats(a, b)
  a = copyStats(a)
  b = copyStats(b)
  return a.flightcount == b.flightcount
    and a.lastflighttime == b.lastflighttime
    and a.totalflighttime == b.totalflighttime
end

local function addStatsTimeField(line, getValue, setValue)
  if form.addTimeField then
    local ok, field = pcall(form.addTimeField, line, nil, getValue, setValue)
    if ok and field then return field end
  end

  local field = form.addNumberField(line, nil, 0, 1000000000, getValue, setValue)
  if field and field.suffix then field:suffix("s") end
  return field
end

local function open(opts)
  opts = opts or {}
  local disposed = false
  local headerHandle = nil
  local sessionHandler = nil
  local loaded = false
  local mcuId = nil
  local prefs = nil
  local prefsFile = nil
  local current = copyStats()
  local original = copyStats()
  local fields = {}

  local function isDirty()
    return not sameStats(current, original)
  end

  local function updateEnabled()
    local enabled = loaded and mcuId ~= nil
    for _, field in ipairs(fields) do
      if field and field.enable then field:enable(enabled) end
    end
    if headerHandle then
      headerHandle.setReloadEnabled(mcuId ~= nil)
      headerHandle.setSaveEnabled(enabled and isDirty())
    end
  end

  local function loadLocal()
    if not mcuId then
      loaded = false
      prefs = nil
      prefsFile = nil
      current = copyStats()
      original = copyStats()
      updateEnabled()
      return
    end
    prefs, prefsFile = modelPreferences.load(mcuId)
    current = modelPreferences.stats(prefs)
    original = copyStats(current)
    loaded = true
    updateEnabled()
    if form.invalidate then form.invalidate() end
  end

  local function goBack()
    if disposed then return end
    disposed = true
    if sessionHandler then bus.unsubscribe("session.update", sessionHandler) end
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    prefs = nil
    prefsFile = nil
    if opts.onBack then opts.onBack() end
  end

  local function save(focusFn)
    if disposed or not loaded or not mcuId then return end
    prefs = modelPreferences.setStats(prefs, current)
    modelPreferences.save(prefsFile, prefs)
    original = copyStats(current)
    bus.publish("model.stats.update", {
      mcuId = mcuId,
      stats = copyStats(current),
    })
    updateEnabled()
    if focusFn then focusFn() end
  end

  local function confirmSave(focusFn)
    if not isDirty() then
      if focusFn then focusFn() end
      return
    end
    form.openDialog({
      title = MSG_SAVE_TITLE,
      message = MSG_SAVE_BODY,
      buttons = {
        {label = BTN_OK, action = function() save(focusFn); return true end},
        {label = BTN_CANCEL, action = function() if focusFn then focusFn() end; return true end},
      },
      wakeup = function() end,
      paint = function() end,
      options = TEXT_LEFT,
    })
  end

  local function confirmReload(focusFn)
    form.openDialog({
      title = MSG_RELOAD_TITLE,
      message = MSG_RELOAD_BODY,
      buttons = {
        {label = BTN_OK, action = function() loadLocal(); if focusFn then focusFn() end; return true end},
        {label = BTN_CANCEL, action = function() if focusFn then focusFn() end; return true end},
      },
      wakeup = function() end,
      paint = function() end,
      options = TEXT_LEFT,
    })
  end

  local function onSessionUpdate(snapshot)
    if disposed then return end
    local nextMcuId = snapshot and snapshot.mcuId or nil
    if nextMcuId ~= mcuId then
      mcuId = nextMcuId
      loadLocal()
      return
    end
    if not isDirty() and snapshot and snapshot.modelStats then
      current = copyStats(snapshot.modelStats)
      original = copyStats(current)
      loaded = true
      updateEnabled()
      if form.invalidate then form.invalidate() end
    end
  end

  form.clear()
  headerHandle = header.build(PAGE_TITLE, {
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
      if sessionHandler then bus.unsubscribe("session.update", sessionHandler) end
      prefs = nil
      prefsFile = nil
    end)
  end
  if opts.setWakeupHandler then opts.setWakeupHandler(updateEnabled) end

  local line = form.addLine("@i18n(app.modules.stats.flightcount)@")
  local flightCount = form.addNumberField(line, nil, 0, 1000000000, function()
    return current.flightcount
  end, function(value)
    current.flightcount = value or 0
    updateEnabled()
  end)
  fields[#fields + 1] = flightCount

  line = form.addLine("@i18n(app.modules.stats.lastflighttime)@")
  local lastFlightTime = addStatsTimeField(line, function()
    return current.lastflighttime
  end, function(value)
    current.lastflighttime = value or 0
    updateEnabled()
  end)
  fields[#fields + 1] = lastFlightTime

  line = form.addLine("@i18n(app.modules.stats.totalflighttime)@")
  local totalFlightTime = addStatsTimeField(line, function()
    return current.totalflighttime
  end, function(value)
    current.totalflighttime = value or 0
    updateEnabled()
  end)
  fields[#fields + 1] = totalFlightTime

  sessionHandler = bus.subscribe("session.update", onSessionUpdate)
  updateEnabled()
end

return {open = open}
