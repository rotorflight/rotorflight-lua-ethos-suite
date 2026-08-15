-- Settings -> Dashboard -> Themes.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local modelPreferences = requireModule("lib/model_preferences.lua")
local settingsStore = requireModule("lib/settings_store.lua")
local tableClone = requireModule("lib/table_clone.lua")

local PAGE_TITLE = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.dashboard)@ / @i18n(app.modules.settings.dashboard_theme)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local MSG_SAVE_TITLE = "@i18n(app.msg_save_settings)@"
local MSG_SAVE_BODY = "@i18n(app.msg_save_current_page)@"

local MODEL_DISABLED = "@i18n(app.modules.settings.dashboard_theme_panel_model_disabled)@"
local DEFAULT_THEME = "system/default"

local THEME_DEFS = {
  {label = "@i18n(app.modules.settings.dashboard_theme_aerc)@", path = "system/aerc"},
  {label = "@i18n(app.modules.settings.dashboard_theme_aerc_n)@", path = "system/aerc-n"},
  {label = "@i18n(app.modules.settings.dashboard_theme_timer)@", path = "system/timer"},
  {label = "@i18n(app.modules.settings.dashboard_theme_claude)@", path = "system/claude"},
  {label = "@i18n(app.modules.settings.dashboard_theme_danielrc)@", path = "system/danielrc"},
  {label = "@i18n(app.modules.settings.dashboard_theme_default)@", path = "system/default"},
  {label = "@i18n(app.modules.settings.dashboard_theme_gismo)@", path = "system/gismo"},
  {label = "@i18n(app.modules.settings.dashboard_theme_helihud)@", path = "system/helihud"},
  {label = "@i18n(app.modules.settings.dashboard_theme_kevd)@", path = "system/kevd", minResolution = {x = 784, y = 294}},
  {label = "@i18n(app.modules.settings.dashboard_theme_rfstatus)@", path = "system/rfstatus"},
  {label = "@i18n(app.modules.settings.dashboard_theme_rt_rc)@", path = "system/rt-rc"},
  {label = "@i18n(app.modules.settings.dashboard_theme_rt_rc_n)@", path = "system/rt-rc-n"},
  {label = "@i18n(app.modules.settings.dashboard_theme_srb_rc)@", path = "system/srb-rc"},
}

local function coerceBool(value, default)
  if value == nil then return default end
  if value == true or value == "true" or value == 1 or value == "1" then return true end
  if value == false or value == "false" or value == 0 or value == "0" then return false end
  return default
end

local function themeKey(path)
  if type(path) ~= "string" then return nil end
  local folder = path:match("^system/(.+)$") or path
  if folder:sub(1, 1) == "@" then folder = folder:sub(2) end
  return folder
end

local function themeVisible(theme)
  local minRes = theme and theme.minResolution
  if type(minRes) ~= "table" then return true end
  local w, h = lcd.getWindowSize()
  return not (w and h and (w < (minRes.x or 0) or h < (minRes.y or 0)))
end

local function buildThemeChoices()
  local choices = {}
  local modelChoices = {{MODEL_DISABLED, 0}}
  local pathById = {}
  local idByPath = {}
  local fallbackId = 1

  for _, theme in ipairs(THEME_DEFS) do
    if themeVisible(theme) then
      local id = #choices + 1
      choices[id] = {theme.label, id}
      modelChoices[#modelChoices + 1] = {theme.label, id}
      pathById[id] = theme.path
      idByPath[theme.path] = id
      idByPath[themeKey(theme.path)] = id
      if theme.path == DEFAULT_THEME then fallbackId = id end
    end
  end

  return choices, modelChoices, pathById, idByPath, fallbackId
end

local function normalizeThemePath(path, allowDisabled, defaultPath)
  if allowDisabled and (path == nil or path == "" or path == "nil" or path == 0 or path == "0") then
    return "nil"
  end

  local key = themeKey(path or defaultPath)
  for _, theme in ipairs(THEME_DEFS) do
    if key == themeKey(theme.path) then return theme.path end
  end

  return defaultPath or DEFAULT_THEME
end

local function normalizeDashboard(dashboard, allowDisabled)
  dashboard = tableClone.shallow(dashboard)
  local defaultPath = allowDisabled and "nil" or DEFAULT_THEME
  dashboard.use_same_theme = coerceBool(dashboard.use_same_theme, true)
  dashboard.theme_preflight = normalizeThemePath(dashboard.theme_preflight or dashboard.theme, allowDisabled, defaultPath)
  dashboard.theme_inflight = normalizeThemePath(dashboard.theme_inflight or dashboard.theme_preflight or dashboard.theme, allowDisabled, dashboard.theme_preflight)
  dashboard.theme_postflight = normalizeThemePath(dashboard.theme_postflight or dashboard.theme_preflight or dashboard.theme, allowDisabled, dashboard.theme_preflight)

  if dashboard.use_same_theme then
    dashboard.theme_inflight = dashboard.theme_preflight
    dashboard.theme_postflight = dashboard.theme_preflight
  end

  dashboard.theme = themeKey(dashboard.theme_preflight) or themeKey(DEFAULT_THEME)
  return dashboard
end

local function sameSection(a, b)
  a = a or {}
  b = b or {}
  for key, value in pairs(a) do
    if b[key] ~= value then return false end
  end
  for key in pairs(b) do
    if a[key] == nil then return false end
  end
  return true
end

local function choiceForPath(path, idByPath, fallbackId, allowDisabled)
  if allowDisabled and (path == nil or path == "nil" or path == "") then return 0 end
  local id = idByPath[normalizeThemePath(path, allowDisabled, allowDisabled and "nil" or DEFAULT_THEME)]
  return id or fallbackId
end

local function pathForChoice(value, pathById, allowDisabled)
  value = tonumber(value) or 0
  if allowDisabled and value == 0 then return "nil" end
  return pathById[value] or DEFAULT_THEME
end

local function copyPreflightToAll(dashboard, allowDisabled, pathById, idByPath, fallbackId)
  if type(dashboard) ~= "table" then return end
  local id = choiceForPath(dashboard.theme_preflight, idByPath, fallbackId, allowDisabled)
  local path = pathForChoice(id, pathById, allowDisabled)
  dashboard.theme_preflight = path
  dashboard.theme_inflight = path
  dashboard.theme_postflight = path
end

local function hasModelDashboardOverride(dashboard)
  dashboard = normalizeDashboard(dashboard, true)
  return dashboard.theme_preflight ~= "nil"
    or dashboard.theme_inflight ~= "nil"
    or dashboard.theme_postflight ~= "nil"
end

local function open(opts)
  opts = opts or {}
  local disposed = false
  local headerHandle
  local settings = settingsStore.load()
  local originalDashboard
  local modelPrefs
  local modelPath
  local modelDashboard = normalizeDashboard(nil, true)
  local originalModelDashboard = normalizeDashboard(nil, true)
  local session = {}
  local pendingSession
  local sessionHandler
  local fields = {}

  local choices, modelChoices, pathById, idByPath, fallbackId = buildThemeChoices()
  settings.dashboard = normalizeDashboard(settings.dashboard, false)
  originalDashboard = tableClone.shallow(settings.dashboard)

  local function modelEnabled()
    return session.connected == true and session.mcuId ~= nil and session.mcuId ~= ""
  end

  local function isDirty()
    local globalDirty = not sameSection(normalizeDashboard(settings and settings.dashboard, false), originalDashboard)
    local modelDirty = modelEnabled() and not sameSection(normalizeDashboard(modelDashboard, true), normalizeDashboard(originalModelDashboard, true))
    return globalDirty or modelDirty
  end

  local function updateSaveEnabled()
    if headerHandle then headerHandle.setSaveEnabled(isDirty()) end
  end

  local function setEnabled(field, enabled)
    if field and field.enable then field:enable(enabled == true) end
  end

  local function globalUseSame()
    return settings and settings.dashboard and settings.dashboard.use_same_theme == true
  end

  local function modelUseSame()
    return modelDashboard and modelDashboard.use_same_theme == true
  end

  local function updateGlobalFields()
    setEnabled(fields.global_inflight, not globalUseSame())
    setEnabled(fields.global_postflight, not globalUseSame())
    updateSaveEnabled()
  end

  local function updateModelFields()
    local enabled = modelEnabled()
    local useSame = modelUseSame()
    setEnabled(fields.model_use_same, enabled)
    setEnabled(fields.model_preflight, enabled)
    setEnabled(fields.model_inflight, enabled and not useSame)
    setEnabled(fields.model_postflight, enabled and not useSame)
    updateSaveEnabled()
  end

  local function loadModelDashboard()
    if not modelEnabled() then
      modelPrefs = nil
      modelPath = nil
      modelDashboard = normalizeDashboard(nil, true)
      originalModelDashboard = normalizeDashboard(nil, true)
      return
    end

    modelPrefs, modelPath = modelPreferences.load(session.mcuId)
    modelPrefs.dashboard = normalizeDashboard(modelPrefs.dashboard, true)
    modelDashboard = modelPrefs.dashboard
    originalModelDashboard = tableClone.shallow(modelDashboard)
  end

  local function applySession(snapshot)
    snapshot = snapshot or {}
    local previousMcuId = session.mcuId
    local previousConnected = session.connected
    session.connected = snapshot.connected == true
    session.mcuId = snapshot.mcuId

    if session.connected ~= previousConnected or session.mcuId ~= previousMcuId then
      loadModelDashboard()
      updateModelFields()
      lcd.invalidate()
    end
  end

  local function appWakeup()
    if pendingSession then
      local snapshot = pendingSession
      pendingSession = nil
      applySession(snapshot)
    end
  end

  local function goBack()
    if disposed then return end
    disposed = true
    if sessionHandler then bus.unsubscribe("session.update", sessionHandler); sessionHandler = nil end
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    settings = nil
    originalDashboard = nil
    modelPrefs = nil
    modelDashboard = nil
    originalModelDashboard = nil
    fields = nil
    if opts.onBack then opts.onBack() end
  end

  local function save(focusFn)
    if disposed then return end
    settings.dashboard = normalizeDashboard(settings.dashboard, false)
    if settings.dashboard.use_same_theme then copyPreflightToAll(settings.dashboard, false, pathById, idByPath, fallbackId) end
    settingsStore.save(settings)
    originalDashboard = tableClone.shallow(settings.dashboard)

    if modelEnabled() and modelPrefs and modelPath then
      modelDashboard = normalizeDashboard(modelDashboard, true)
      if modelDashboard.use_same_theme then copyPreflightToAll(modelDashboard, true, pathById, idByPath, fallbackId) end
      if hasModelDashboardOverride(modelDashboard) then
        modelPrefs.dashboard = modelDashboard
      else
        modelDashboard = normalizeDashboard(nil, true)
        modelPrefs.dashboard = nil
      end
      modelPreferences.save(modelPath, modelPrefs)
      originalModelDashboard = tableClone.shallow(modelDashboard)
    end

    bus.publish("settings.update", settingsStore.clone(settings))
    updateSaveEnabled()
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

  local function setTheme(target, key, value, allowDisabled)
    target[key] = pathForChoice(value, pathById, allowDisabled)
  end

  form.clear()
  headerHandle = header.build(PAGE_TITLE, {
    onBack = goBack,
    onSave = function() confirmSave(headerHandle and headerHandle.focusSave) end,
  })

  local globalPanel = form.addExpansionPanel("@i18n(app.modules.settings.dashboard_theme_panel_global)@")
  globalPanel:open(false)

  fields.global_use_same = form.addBooleanField(globalPanel:addLine("@i18n(app.modules.settings.dashboard_theme_use_same)@"), nil,
    function()
      return globalUseSame()
    end,
    function(value)
      settings.dashboard.use_same_theme = value == true
      if settings.dashboard.use_same_theme then copyPreflightToAll(settings.dashboard, false, pathById, idByPath, fallbackId) end
      updateGlobalFields()
    end)

  fields.global_preflight = form.addChoiceField(globalPanel:addLine("@i18n(app.modules.settings.dashboard_theme_preflight)@"), nil, choices,
    function()
      return choiceForPath(settings and settings.dashboard and settings.dashboard.theme_preflight, idByPath, fallbackId, false)
    end,
    function(value)
      if not settings then return end
      setTheme(settings.dashboard, "theme_preflight", value, false)
      if globalUseSame() then copyPreflightToAll(settings.dashboard, false, pathById, idByPath, fallbackId) end
      updateSaveEnabled()
    end)

  fields.global_inflight = form.addChoiceField(globalPanel:addLine("@i18n(app.modules.settings.dashboard_theme_inflight)@"), nil, choices,
    function()
      return choiceForPath(settings and settings.dashboard and settings.dashboard.theme_inflight, idByPath, fallbackId, false)
    end,
    function(value)
      if not settings then return end
      setTheme(settings.dashboard, "theme_inflight", value, false)
      updateSaveEnabled()
    end)

  fields.global_postflight = form.addChoiceField(globalPanel:addLine("@i18n(app.modules.settings.dashboard_theme_postflight)@"), nil, choices,
    function()
      return choiceForPath(settings and settings.dashboard and settings.dashboard.theme_postflight, idByPath, fallbackId, false)
    end,
    function(value)
      if not settings then return end
      setTheme(settings.dashboard, "theme_postflight", value, false)
      updateSaveEnabled()
    end)

  local modelPanel = form.addExpansionPanel("@i18n(app.modules.settings.dashboard_theme_panel_model)@")
  modelPanel:open(false)

  fields.model_use_same = form.addBooleanField(modelPanel:addLine("@i18n(app.modules.settings.dashboard_theme_use_same)@"), nil,
    function()
      return modelUseSame()
    end,
    function(value)
      modelDashboard.use_same_theme = value == true
      if modelDashboard.use_same_theme then copyPreflightToAll(modelDashboard, true, pathById, idByPath, fallbackId) end
      updateModelFields()
    end)

  fields.model_preflight = form.addChoiceField(modelPanel:addLine("@i18n(app.modules.settings.dashboard_theme_preflight)@"), nil, modelChoices,
    function()
      return choiceForPath(modelDashboard and modelDashboard.theme_preflight, idByPath, fallbackId, true)
    end,
    function(value)
      if not modelDashboard then return end
      setTheme(modelDashboard, "theme_preflight", value, true)
      if modelUseSame() then copyPreflightToAll(modelDashboard, true, pathById, idByPath, fallbackId) end
      updateSaveEnabled()
    end)

  fields.model_inflight = form.addChoiceField(modelPanel:addLine("@i18n(app.modules.settings.dashboard_theme_inflight)@"), nil, modelChoices,
    function()
      return choiceForPath(modelDashboard and modelDashboard.theme_inflight, idByPath, fallbackId, true)
    end,
    function(value)
      if not modelDashboard then return end
      setTheme(modelDashboard, "theme_inflight", value, true)
      updateSaveEnabled()
    end)

  fields.model_postflight = form.addChoiceField(modelPanel:addLine("@i18n(app.modules.settings.dashboard_theme_postflight)@"), nil, modelChoices,
    function()
      return choiceForPath(modelDashboard and modelDashboard.theme_postflight, idByPath, fallbackId, true)
    end,
    function(value)
      if not modelDashboard then return end
      setTheme(modelDashboard, "theme_postflight", value, true)
      updateSaveEnabled()
    end)

  updateGlobalFields()
  updateModelFields()

  if opts.setEventHandler then
    opts.setEventHandler(function(category, value)
      if closeKey.shouldHandleClose(category, value) then
        goBack()
        return true
      end
      return false
    end)
  end

  sessionHandler = function(snapshot)
    pendingSession = snapshot or {}
  end
  bus.subscribe("session.update", sessionHandler)
  appWakeup()

  if opts.setWakeupHandler then opts.setWakeupHandler(appWakeup) end
  if opts.setCleanupHandler then
    opts.setCleanupHandler(function()
      disposed = true
      if sessionHandler then bus.unsubscribe("session.update", sessionHandler); sessionHandler = nil end
      settings = nil
      originalDashboard = nil
      modelPrefs = nil
      modelDashboard = nil
      originalModelDashboard = nil
      fields = nil
    end)
  end
end

return {open = open}
