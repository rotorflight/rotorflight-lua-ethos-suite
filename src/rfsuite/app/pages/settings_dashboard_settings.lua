-- Settings -> Dashboard -> Settings.
--
-- Mirrors the original suite's dashboard-settings page shape: a tile grid
-- of dashboard themes that expose a configure.lua, with each tile opening
-- that theme's own configuration form.

local requireModule = assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local tileGrid = requireModule("app/tile_grid.lua")
local settingsStore = requireModule("lib/settings_store.lua")
local dashboardContext = requireModule("widgets/dashboard/context.lua")

local PAGE_TITLE = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.dashboard)@ / @i18n(app.modules.settings.dashboard_settings)@"
local NO_THEMES = "@i18n(app.modules.settings.no_themes_available_to_configure)@"

local THEME_DEFS = {
  {label = "@i18n(app.modules.settings.dashboard_theme_aerc)@", folder = "aerc"},
  {label = "@i18n(app.modules.settings.dashboard_theme_aerc_n)@", folder = "aerc-n"},
  {label = "@i18n(app.modules.settings.dashboard_theme_claude)@", folder = "claude"},
  {label = "@i18n(app.modules.settings.dashboard_theme_default)@", folder = "default"},
  {label = "@i18n(app.modules.settings.dashboard_theme_gismo)@", folder = "gismo"},
  {label = "@i18n(app.modules.settings.dashboard_theme_kevd)@", folder = "kevd", minResolution = {x = 784, y = 294}},
  {label = "@i18n(app.modules.settings.dashboard_theme_rfstatus)@", folder = "rfstatus"},
  {label = "@i18n(app.modules.settings.dashboard_theme_rt_rc)@", folder = "rt-rc"},
  {label = "@i18n(app.modules.settings.dashboard_theme_rt_rc_n)@", folder = "rt-rc-n"},
  {label = "@i18n(app.modules.settings.dashboard_theme_srb_rc)@", folder = "srb-rc"},
}

local lastSelected

local function themeDir(folder)
  return "widgets/dashboard/themes/" .. folder
end

local function themeVisible(theme)
  local minRes = theme and theme.minResolution
  if type(minRes) ~= "table" then return true end
  local w, h = lcd.getWindowSize()
  return not (w and h and (w < (minRes.x or 0) or h < (minRes.y or 0)))
end

-- Session-cached (mirrors objects/dial/image.lua's rfsuite.session.dialImageCache):
-- this page module is loadfile()'d fresh on every visit (no require()-style
-- caching -- see docs/memory-and-module-lifecycle.md), so a plain local
-- wouldn't survive a second open(). Which themes ship a configure.lua and
-- which are hidden by minResolution can't change while the script is
-- running, so probing that via loadfile() (a full compile of each theme's
-- configure.lua, thrown away immediately after) on every single page visit
-- was pure repeat waste -- a real, previously observed contributor to
-- Ethos's "Max instructions count reached" on dashboard-theme navigation.
local function configuredThemes()
  local cached = dashboardContext.session.dashboardConfiguredThemes
  if cached then return cached end

  local themes = {}
  for _, theme in ipairs(THEME_DEFS) do
    if themeVisible(theme) then
      local dir = themeDir(theme.folder)
      local ok = pcall(function() return assert(loadfile(dir .. "/configure.lua")) end)
      if ok then
        themes[#themes + 1] = {
          label = theme.label,
          folder = theme.folder,
          configure = dir .. "/configure.lua",
          icon = dir .. "/icon.png",
        }
      end
    end
  end
  dashboardContext.session.dashboardConfiguredThemes = themes
  return themes
end

local function saveThemePrefs(settings, themeModule, folder)
  if themeModule and themeModule.write then themeModule.write() end
  settingsStore.setDashboardTheme(settings, folder, dashboardContext.widgets.dashboard.preferences())
  settingsStore.save(settings)
  bus.publish("settings.update", settingsStore.clone(settings))
end

local function open(opts)
  opts = opts or {}
  local disposed = false
  local settings = settingsStore.load()
  local headerHandle

  local function clearHandlers()
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setPaintHandler then opts.setPaintHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
  end

  local function goBack()
    if disposed then return end
    disposed = true
    clearHandlers()
    dashboardContext.widgets.dashboard.setPreferences(nil)
    if opts.onBack then opts.onBack() end
  end

  local function openTheme(theme)
    local themeModule = assert(loadfile(theme.configure))()

    form.clear()
    dashboardContext.widgets.dashboard.setPreferences(settingsStore.dashboardTheme(settings, theme.folder))

    headerHandle = header.build(theme.label, {
      onBack = function()
        open(opts)
      end,
      onSave = function()
        saveThemePrefs(settings, themeModule, theme.folder)
        if headerHandle then headerHandle.focusSave() end
      end,
      onReload = function()
        openTheme(theme)
        if headerHandle then headerHandle.focusReload() end
      end,
    })

    if opts.setEventHandler then
      opts.setEventHandler(function(category, value)
        if not closeKey.shouldHandleClose(category, value) then return false end
        open(opts)
        return true
      end)
    end
    clearHandlers()
    if opts.setCleanupHandler then
      opts.setCleanupHandler(function()
        dashboardContext.widgets.dashboard.setPreferences(nil)
      end)
    end

    if themeModule.configure then themeModule.configure() end
    if headerHandle then
      headerHandle.setSaveEnabled(true)
      headerHandle.setReloadEnabled(true)
      headerHandle.focusMenu()
    end
  end

  local function openThemeGrid()
    form.clear()
    clearHandlers()
    dashboardContext.widgets.dashboard.setPreferences(nil)

    if opts.setEventHandler then
      opts.setEventHandler(function(category, value)
        if not closeKey.shouldHandleClose(category, value) then return false end
        goBack()
        return true
      end)
    end
    if opts.setCleanupHandler then opts.setCleanupHandler(goBack) end

    local gridHeader = header.build(PAGE_TITLE, {onBack = goBack})
    local themes = configuredThemes()
    local windowWidth, windowHeight = lcd.getWindowSize()
    local numPerRow, tileW, tileH, tilePadding, tileFont = tileGrid.metrics(windowWidth, windowHeight)
    local x, y = 0, form.height() + tilePadding
    local col = 0
    local buttons = {}

    local iconCache = dashboardContext.session.dashboardThemeIconCache
    if not iconCache then
      iconCache = {}
      dashboardContext.session.dashboardThemeIconCache = iconCache
    end

    for i, theme in ipairs(themes) do
      local icon = iconCache[theme.icon]
      if icon == nil then
        icon = lcd.loadMask(theme.icon) or false
        iconCache[theme.icon] = icon
      end
      buttons[i] = form.addButton(nil, {x = x, y = y, w = tileW, h = tileH}, {
        text = theme.label,
        icon = icon or nil,
        options = tileFont,
        press = function()
          lastSelected = i
          openTheme(theme)
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

    if #themes == 0 then
      form.addStaticText(nil, {x = tilePadding, y = form.height() + tilePadding, w = windowWidth - (2 * tilePadding), h = 32}, NO_THEMES, CENTERED)
      gridHeader.focusMenu()
      return
    end

    local selected = lastSelected and buttons[lastSelected]
    if selected then selected:focus() else gridHeader.focusMenu() end
  end

  openThemeGrid()
end

return {open = open}
