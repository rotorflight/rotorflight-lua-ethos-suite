-- Rotorflight dashboard widget.
--
-- Lite keeps the old dashboard's preflight/inflight/postflight theme shape,
-- while loading only the selected theme and current state page.

local bus = assert(loadfile("lib/bus.lua"))()
local buildInfo = assert(loadfile("lib/build_info.lua"))()
local modelPreferences = assert(loadfile("lib/model_preferences.lua"))()
local settingsStore = assert(loadfile("lib/settings_store.lua"))()
local flightmode = assert(loadfile("widgets/dashboard/flightmode.lua"))()
local dataflashErase = assert(loadfile("lib/msp_dataflash_erase.lua"))()
local dataflashSummary = assert(loadfile("lib/msp_dataflash_summary.lua"))()
local batteryProfileMsp = assert(loadfile("lib/msp_battery_profile.lua"))()
local ethosVersion = assert(loadfile("lib/ethos_version.lua"))()

local THEME_DIRS = {
  ["aerc-n"] = "widgets/dashboard/themes/aerc-n",
  aerc = "widgets/dashboard/themes/aerc",
  claude = "widgets/dashboard/themes/claude",
  danielrc = "widgets/dashboard/themes/danielrc",
  default = "widgets/dashboard/themes/default",
  gismo = "widgets/dashboard/themes/gismo",
  helihud = "widgets/dashboard/themes/helihud",
  kevd = "widgets/dashboard/themes/kevd",
  rfstatus = "widgets/dashboard/themes/rfstatus",
  ["rt-rc-n"] = "widgets/dashboard/themes/rt-rc-n",
  ["rt-rc"] = "widgets/dashboard/themes/rt-rc",
  ["srb-rc"] = "widgets/dashboard/themes/srb-rc",
  timer = "widgets/dashboard/themes/timer",
}

local DEFAULT_DASHBOARD_SETTINGS = {
  theme = "default",
  use_same_theme = true,
  theme_preflight = "system/default",
  theme_inflight = "system/default",
  theme_postflight = "system/default",
}
local themeDef = nil
local stateDef = nil
local themeDefs = {}
local stateDefs = {}
local dashboardContext = nil
local dashboardEngine = nil
local loadedTheme = nil
local loadedState = nil
local systemToolHandle = nil
local clock = os.clock
-- Set true while app/tool.lua's full-screen tool owns the display (see its
-- create()/close()) -- matches master's rfsuite.tasks.appRunning gate on
-- dashboard.lua's own wakeup(): a background-screen widget doing full
-- object-wakeup/paint-prep work while a *different* screen is the one
-- actually on the display is pure wasted CPU, every tick, for as long as
-- the tool stays open.
local appRunning = false
bus.subscribe("app.state", function(state) appRunning = state and state.running == true end)
local GESTURE_MIN_DY = 20
local GESTURE_MAX_DX = 40
local GESTURE_CONSUME_TIMEOUT = 0.75
local TOOLBAR_TIMEOUT = 10
-- Paces the cold-start object warm-up (each box's object-type/subtype
-- module load, first sensor-source resolution, any images) across many
-- wakeup ticks instead of paying for it all in a single burst the moment
-- the startup overlay drops -- af92913d dropped this pacing, which turned
-- first-load into one uncontrolled burst that Ethos's own per-tick
-- instruction budget then had to throttle anyway (see the runaway-script
-- guard comment on context.lua's isImageTooLarge), making the whole radio
-- feel laggy for as long as that burst took to grind through.
local STARTUP_PREP_OBJECTS_PER_TICK = 2
-- Master keeps inactive dashboard-state preloading disabled by default:
-- it saves RAM and avoids loading a non-visible theme during startup.
local PREWARM_STATES = {}
-- Live OS theme switches (no restart) are only picked up by polling
-- utils.getThemeSignature() and forcing a reload on change -- master does
-- this every 0.25s in its wakeup(); this rewrite never did it at all, so
-- every theme (not just one) needed a full restart to pick up a live
-- theme switch. 5s (vs master's 0.25s) trades a little detection latency
-- for meaningfully less CPU load -- a live theme switch is a rare, human-
-- paced action, not something that needs sub-second response.
local THEME_STATE_CHECK_INTERVAL = 5.0
local themeStateSignature = nil
local nextThemeStateCheck = 0

local TOOLBAR_ITEMS = {
  {name = "Reset", icon = "widgets/dashboard/gfx/toolbar_reset.png", action = "reset_flight"},
  {name = "Erase", icon = "widgets/dashboard/gfx/toolbar_erase.png", action = "erase_blackbox", isConnected = true},
  {name = "Battery", icon = "widgets/dashboard/gfx/toolbar_battery.png", action = "battery_profile", isConnected = true, requiresBatteryProfiles = true},
  {name = "Setup", icon = "widgets/dashboard/gfx/toolbar_app.png", action = "launch_app", requiresOpenPage = true},
}

local function trimDashboardCaches(options)
  local dashboard = dashboardContext and dashboardContext.widgets and dashboardContext.widgets.dashboard
  if dashboard and dashboard.clearCaches then dashboard.clearCaches(options) end
end

local function clearThemeCache()
  trimDashboardCaches({theme = true, renders = true, images = true})
  if dashboardEngine and dashboardEngine.reset then dashboardEngine.reset() end
  themeDef = nil
  stateDef = nil
  for key in pairs(themeDefs) do themeDefs[key] = nil end
  for key in pairs(stateDefs) do stateDefs[key] = nil end
  loadedTheme = nil
  loadedState = nil
end

local function ensureDashboardContext()
  if not dashboardContext then
    dashboardContext = assert(loadfile("widgets/dashboard/context.lua"))()
  end
  return dashboardContext
end

local function dashboardUtils(load)
  local context = load and ensureDashboardContext() or dashboardContext
  return context
    and context.widgets
    and context.widgets.dashboard
    and context.widgets.dashboard.utils
    or nil
end

local function ensureDashboardEngine()
  if not dashboardEngine then
    dashboardEngine = assert(loadfile("widgets/dashboard/engine.lua"))()
  end
  return dashboardEngine
end

local function themeKey(value)
  if type(value) ~= "string" then return "default" end
  local folder = value:match("^system/(.+)$") or value
  if folder:sub(1, 1) == "@" then folder = folder:sub(2) end
  if THEME_DIRS[folder] then return folder end
  return "default"
end

local function phaseTheme(dashboard, state)
  if type(dashboard) ~= "table" then return nil end
  if dashboard.use_same_theme == true or dashboard.use_same_theme == "true" then
    return dashboard.theme_preflight or dashboard.theme
  end
  if state == "inflight" then return dashboard.theme_inflight or dashboard.theme_preflight or dashboard.theme end
  if state == "postflight" then return dashboard.theme_postflight or dashboard.theme_preflight or dashboard.theme end
  return dashboard.theme_preflight or dashboard.theme
end

local function ensureDashboardSettings(widget)
  if not widget then return DEFAULT_DASHBOARD_SETTINGS end
  if not widget.settingsSnapshot then
    widget.settingsSnapshot = settingsStore.load()
  end
  if not widget.dashboardSettings then
    widget.dashboardSettings = settingsStore.dashboard(widget.settingsSnapshot)
  end
  return widget.dashboardSettings or DEFAULT_DASHBOARD_SETTINGS
end

local function selectedThemeForState(widget, state)
  local modelTheme = phaseTheme(widget and widget.modelDashboard, state)
  if modelTheme and modelTheme ~= "nil" then return themeKey(modelTheme) end
  return themeKey(phaseTheme(ensureDashboardSettings(widget), state))
end

local function loadThemeDef(theme)
  theme = themeKey(theme)
  if themeDefs[theme] then
    themeDef = themeDefs[theme]
    loadedTheme = theme
    return themeDef
  end
  local dir = THEME_DIRS[theme] or THEME_DIRS.default
  themeDef = assert(loadfile(dir .. "/init.lua"))()
  themeDef.dir = dir
  themeDefs[theme] = themeDef
  loadedTheme = theme
  return themeDef
end

local function loadStateDef(theme, state)
  local def = loadThemeDef(theme)
  local key = themeKey(theme) .. ":" .. tostring(state)
  if stateDefs[key] then
    stateDef = stateDefs[key]
    loadedState = state
    return stateDef
  end
  local file = def[state] or (state .. ".lua")
  stateDef = assert(loadfile(def.dir .. "/" .. file))()
  stateDefs[key] = stateDef
  loadedState = state
  return stateDef
end

local function normalizeModelDashboard(dashboard)
  if type(dashboard) ~= "table" then return nil end
  return {
    theme = dashboard.theme,
    use_same_theme = dashboard.use_same_theme,
    theme_preflight = dashboard.theme_preflight,
    theme_inflight = dashboard.theme_inflight,
    theme_postflight = dashboard.theme_postflight,
  }
end

local function sameModelDashboard(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  return a.theme == b.theme
    and a.use_same_theme == b.use_same_theme
    and a.theme_preflight == b.theme_preflight
    and a.theme_inflight == b.theme_inflight
    and a.theme_postflight == b.theme_postflight
end

local function loadModelDashboard(widget)
  if not widget or widget.connected ~= true or not widget.mcuId or widget.mcuId == "" then
    widget.modelDashboard = nil
    return
  end

  local prefs = modelPreferences.load(widget.mcuId)
  widget.modelDashboard = normalizeModelDashboard(prefs and prefs.dashboard)
end

local function requestPaint(widget)
  if widget then widget.needsPaint = true end
end

local function resetDashboardPrewarm(widget)
  if not widget then return end
  widget.dashboardPrewarmIndex = 1
  if widget.dashboardPrewarmed then
    for key in pairs(widget.dashboardPrewarmed) do widget.dashboardPrewarmed[key] = nil end
  end
end

local function markStartupUnderlayDirty(widget)
  if not widget then return end
  widget.startupComplete = false
end

local function invalidateWidget(widget)
  if not lcd or not lcd.invalidate then return end
  local ok = pcall(lcd.invalidate, widget)
  if not ok then lcd.invalidate() end
end

local function clearToolbarMasks(widget)
  local masks = widget and widget.toolbarMasks
  if not masks then return end
  for key in pairs(masks) do masks[key] = nil end
end

local function setToolbarVisible(widget, visible)
  if not widget then return end
  visible = visible == true
  if widget.toolbarVisible == visible then return end
  widget.toolbarVisible = visible
  widget.toolbarOpenedAt = visible and clock() or 0
  widget.toolbarLastActive = widget.toolbarOpenedAt
  widget.toolbarCloseAt = 0
  if visible and not widget.selectedToolbarIndex then widget.selectedToolbarIndex = 1 end
  if not visible then
    widget.selectedToolbarIndex = nil
    clearToolbarMasks(widget)
  end
  requestPaint(widget)
end

local function resolveToolbarThemeColor(themeColorKey, fallback)
  if type(themeColorKey) == "number" and type(lcd.themeColor) == "function" and ethosVersion.atLeast({26, 1, 0}) then
    return lcd.themeColor(themeColorKey)
  end
  return fallback
end

local function toolbarColors()
  local utils = dashboardUtils(false)
  local themeState = utils and utils.getThemeState and utils.getThemeState() or {}
  local defaultColor = resolveToolbarThemeColor(THEME_DEFAULT_COLOR, themeState.primaryColor or lcd.RGB(90, 90, 90, 1))
  local focusColor = resolveToolbarThemeColor(THEME_FOCUS_COLOR, themeState.focusColor or lcd.RGB(0, 0, 0, 1))
  local defaultBg = resolveToolbarThemeColor(THEME_DEFAULT_BGCOLOR, themeState.primaryBgColor or lcd.RGB(255, 255, 255, 1))
  local focusBg = resolveToolbarThemeColor(THEME_FOCUS_BGCOLOR, themeState.focusBgColor or lcd.RGB(230, 230, 230, 1))
  local pageBg = resolveToolbarThemeColor(THEME_PAGE_BGCOLOR, themeState.pageBgColor or defaultBg)
  local surfaceBg = (type(lcd.themeColor) == "function" and ethosVersion.atLeast({26, 1, 0})) and pageBg or defaultBg
  local lineColor = resolveToolbarThemeColor(THEME_BUTTON_BORDER_COLOR, themeState.buttonBorderColor or defaultColor)
  if lineColor == surfaceBg then
    lineColor = resolveToolbarThemeColor(THEME_SECONDARY_COLOR, themeState.secondaryColor or defaultColor)
  end
  if lineColor == surfaceBg then
    lineColor = resolveToolbarThemeColor(THEME_PRIMARY_COLOR, themeState.primaryColor or defaultColor)
  end

  return {
    surfaceBg = surfaceBg,
    line = lineColor,
    tileFill = focusBg,
    selectedFill = focusColor,
    text = defaultColor,
    selectedText = defaultBg,
  }
end

local function toolbarBounds(widget, w, h)
  local barH = math.floor(math.max(h * 0.24, math.min(h * 0.40, w * 0.16)))
  return 0, h - barH, w, barH
end

local function loadToolbarMask(widget, path)
  if not lcd.loadMask then return nil end
  widget.toolbarMasks = widget.toolbarMasks or {}
  local mask = widget.toolbarMasks[path]
  if mask == nil then
    mask = lcd.loadMask(path, true) or false
    widget.toolbarMasks[path] = mask
  end
  if mask == false then return nil end
  return mask
end

local function canOpenSystemTool()
  return systemToolHandle ~= nil
    and system
    and type(system.openPage) == "function"
    and ethosVersion.atLeast({26, 1, 0})
end

local function normalizeBatteryProfile(value)
  local profile = tonumber(value)
  if profile == nil then return nil end
  profile = math.floor(profile)
  if profile >= 1 and profile <= 6 then return profile - 1 end
  if profile >= 0 and profile <= 5 then return profile end
  return nil
end

local function capacityValue(value)
  if type(value) == "number" then return value end
  if type(value) == "string" then return tonumber(value:match("(%d+)")) end
  if type(value) == "table" then
    if type(value.capacity) == "number" then return value.capacity end
    if type(value.capacity) == "string" then return tonumber(value.capacity:match("(%d+)")) end
    if type(value.name) == "string" then return tonumber(value.name:match("(%d+)")) end
  end
  return nil
end

local function buildBatteryProfileList(widget)
  local profilesRaw = widget and widget.batteryConfig and widget.batteryConfig.profiles
  local profileList = {}
  if type(profilesRaw) ~= "table" then return profileList end

  for i = 0, 5 do
    local capacity = capacityValue(profilesRaw[i])
    if capacity and capacity > 0 then
      profileList[#profileList + 1] = {name = tostring(math.floor(capacity + 0.5)) .. "mAh", idx = i}
    end
  end

  if #profileList == 0 then
    for i, profile in ipairs(profilesRaw) do
      if type(profile) == "table" and profile.name then
        local idx = normalizeBatteryProfile(profile.idx or profile.index or profile.profile or i) or (i - 1)
        profileList[#profileList + 1] = {name = profile.name, idx = idx}
      end
    end
  end

  return profileList
end

local function hasSelectableBatteryProfiles(widget)
  return #buildBatteryProfileList(widget) > 1
end

local function isToolbarItemEnabled(widget, item)
  if not item then return false end
  -- apiVersionSupported ~= false (not a strict == true) so a not-yet-read
  -- version doesn't wrongly block a toolbar item before the handshake has
  -- even had a chance to answer -- only a *confirmed* unsupported FC does.
  if item.isConnected == true and not (widget and widget.connected == true and widget.apiVersionSupported ~= false) then return false end
  if item.requiresOpenPage == true and not canOpenSystemTool() then return false end
  if item.requiresBatteryProfiles == true and not hasSelectableBatteryProfiles(widget) then return false end
  return true
end

local function drawToolbar(widget, w, h)
  if not widget.toolbarVisible then
    clearToolbarMasks(widget)
    return
  end

  local x, y, barW, barH = toolbarBounds(widget, w, h)
  local colors = toolbarColors()
  local slots = 6
  local itemW = barW / slots
  local slotPad = 12
  local iconSize = math.min(55, math.floor(barH * 0.42))

  lcd.color(colors.surfaceBg)
  lcd.drawFilledRectangle(x, y, barW, barH)
  lcd.color(colors.line)
  lcd.drawFilledRectangle(x, y, barW, 4)
  lcd.font(FONT_XS)

  widget.toolbarRects = widget.toolbarRects or {}
  for key in pairs(widget.toolbarRects) do widget.toolbarRects[key] = nil end

  for i, item in ipairs(TOOLBAR_ITEMS) do
    local ix = x + (i - 1) * itemW
    local bx = ix + slotPad
    local by = y + slotPad + 6
    local bw = itemW - (slotPad * 2)
    local bh = barH - (slotPad * 2) - 6
    local enabled = isToolbarItemEnabled(widget, item)
    widget.toolbarRects[i] = {x = ix, y = y, w = itemW, h = barH, item = item, enabled = enabled}

    local selected = widget.selectedToolbarIndex == i
    lcd.color((selected and enabled) and colors.selectedFill or colors.tileFill)
    lcd.drawFilledRectangle(bx, by, bw, bh)
    lcd.color((selected and enabled) and colors.selectedText or colors.text)
    lcd.drawText(bx + (bw * 0.5), by + 6, item.name, CENTERED)

    local mask = loadToolbarMask(widget, item.icon)
    if mask and lcd.drawMask then
      lcd.color((selected and enabled) and colors.selectedText or colors.text)
      lcd.drawMask(math.floor(bx + (bw - iconSize) / 2 + 0.5), math.floor(by + bh - iconSize - 8 + 0.5), mask)
    end
    if not enabled then
      lcd.color(lcd.RGB(0, 0, 0, 0.65))
      lcd.drawFilledRectangle(bx + 2, by + 2, bw - 4, bh - 4)
    end
  end
end

local function clearDashboardStats(stats)
  if not stats then return end
  for key in pairs(stats) do stats[key] = nil end
end

local function applyResetFlight(widget)
  if not widget then return end
  if widget.flightmode and type(widget.flightmode.reset) == "function" then
    widget.flightmode:reset()
  end
  widget.flightmodeState = "preflight"
  widget.headspeedVariancePct = nil
  clearDashboardStats(widget.dashboardStats)
  widget.timerLive = 0
  widget.timerSession = 0

  if model and type(model.resetFlight) == "function" then
    pcall(model.resetFlight)
  end

  setToolbarVisible(widget, false)
  resetDashboardPrewarm(widget)
  markStartupUnderlayDirty(widget)
  requestPaint(widget)
  invalidateWidget(widget)
end

local function askResetFlight(widget)
  if not form or type(form.openDialog) ~= "function" then
    applyResetFlight(widget)
    return
  end

  form.openDialog({
    width = nil,
    title = "@i18n(widgets.dashboard.reset_flight_ask_title)@",
    message = "@i18n(widgets.dashboard.reset_flight_ask_text)@",
    buttons = {
      {
        label = "@i18n(app.btn_ok)@",
        action = function()
          -- Close the dialog immediately and do the actual reset (which
          -- includes a native model.resetFlight() call) on the next
          -- wakeup tick -- applyResetFlight() used to run synchronously
          -- right here, so the dialog visibly hung on "OK" for however
          -- long that native call took.
          widget.pendingResetFlight = true
          return true
        end,
      },
      {
        label = "@i18n(app.btn_cancel)@",
        action = function()
          return true
        end,
      },
    },
    wakeup = function() end,
    paint = function() end,
    options = TEXT_LEFT,
  })
end

local function closeEraseDialog(widget)
  local dialog = widget and widget.eraseDialog
  if dialog then
    if dialog.value then dialog:value(100) end
    if dialog.close then dialog:close() end
  end
  if widget then widget.eraseDialog = nil end
end

local function finishErase(widget, failed)
  if not widget then return end
  widget.eraseActive = false
  widget.eraseReadPending = false
  widget.eraseDone = false
  widget.eraseError = false
  widget.eraseStartedAt = 0
  widget.eraseProgressValue = 0
  closeEraseDialog(widget)
  setToolbarVisible(widget, false)
  requestPaint(widget)
  invalidateWidget(widget)

  if failed and form and type(form.openDialog) == "function" then
    form.openDialog({
      title = "@i18n(app.modules.blackbox.name)@",
      message = "@i18n(app.modules.blackbox.erase_failed)@",
      buttons = {
        {
          label = "@i18n(app.btn_ok)@",
          action = function()
            return true
          end,
        },
      },
      wakeup = function() end,
      paint = function() end,
      options = TEXT_LEFT,
    })
  end
end

local function readBlackboxSummaryAfterErase(widget)
  if not widget or widget.eraseReadPending ~= true then return end
  widget.eraseReadPending = false
  bus.publish("msp.request", dataflashSummary.buildReadMessage(function(data)
    widget.bblFlags = data and data.flags or widget.bblFlags
    widget.bblSize = data and data.total or widget.bblSize
    widget.bblUsed = data and data.used or widget.bblUsed
    widget.eraseDone = true
  end, function()
    widget.eraseDone = true
  end))
end

local function doEraseBlackbox(widget)
  if not widget or widget.connected ~= true or widget.eraseActive == true then return end

  widget.eraseActive = true
  widget.eraseStartedAt = clock()
  widget.eraseProgressValue = 0
  widget.eraseReadPending = false
  widget.eraseDone = false
  widget.eraseError = false

  if form and type(form.openProgressDialog) == "function" then
    widget.eraseDialog = form.openProgressDialog({
      title = "@i18n(app.modules.blackbox.name)@",
      message = "@i18n(app.modules.blackbox.erasing_dataflash)@",
      close = function() end,
      wakeup = function() end,
    })
    if widget.eraseDialog then
      widget.eraseDialog:value(0)
      widget.eraseDialog:closeAllowed(false)
    end
  end

  bus.publish("msp.request", dataflashErase.buildWriteMessage(function()
    widget.eraseReadPending = true
  end, function()
    widget.eraseError = true
  end))
end

local function askEraseBlackbox(widget)
  if not widget or widget.connected ~= true then return end
  if not form or type(form.openDialog) ~= "function" then
    doEraseBlackbox(widget)
    return
  end

  form.openDialog({
    title = "@i18n(app.modules.blackbox.name)@",
    message = "@i18n(app.modules.blackbox.erase_prompt)@",
    buttons = {
      {
        label = "@i18n(app.btn_ok)@",
        action = function()
          doEraseBlackbox(widget)
          return true
        end,
      },
      {
        label = "@i18n(app.btn_cancel)@",
        action = function()
          return true
        end,
      },
    },
    wakeup = function() end,
    paint = function() end,
    options = TEXT_LEFT,
  })
end

local function closeBatteryDialog(widget)
  local dialog = widget and widget.batteryDialog
  if dialog then
    if dialog.value then dialog:value(100) end
    if dialog.close then dialog:close() end
  end
  if widget then widget.batteryDialog = nil end
end

local function finishBatteryProfileWrite(widget, failed)
  if not widget then return end
  widget.batteryActive = false
  widget.batteryDone = false
  widget.batteryError = false
  widget.batteryStartedAt = 0
  widget.batteryProgressValue = 0
  closeBatteryDialog(widget)
  setToolbarVisible(widget, false)
  requestPaint(widget)
  invalidateWidget(widget)

  if failed and form and type(form.openDialog) == "function" then
    form.openDialog({
      title = "@i18n(widgets.battery.title)@",
      message = "@i18n(widgets.battery.write_failed)@",
      buttons = {
        {
          label = "@i18n(app.btn_ok)@",
          action = function()
            return true
          end,
        },
      },
      wakeup = function() end,
      paint = function() end,
      options = TEXT_LEFT,
    })
  end
end

local function showBatteryInfo(message)
  if not form or type(form.openDialog) ~= "function" then return end
  form.openDialog({
    title = "@i18n(widgets.battery.title)@",
    message = message,
    buttons = {
      {
        label = "@i18n(app.btn_ok)@",
        action = function()
          return true
        end,
      },
    },
    wakeup = function() end,
    paint = function() end,
    options = TEXT_LEFT,
  })
end

local function writeBatteryProfile(widget, profileIndex, profileName)
  if not widget or widget.connected ~= true or widget.batteryActive == true then return end
  profileIndex = normalizeBatteryProfile(profileIndex)
  if profileIndex == nil then return end

  if normalizeBatteryProfile(widget.batteryProfile) == profileIndex then
    showBatteryInfo("@i18n(widgets.battery.msg_battery_selected)@ " .. tostring(profileName))
    return
  end

  widget.batteryActive = true
  widget.batteryStartedAt = clock()
  widget.batteryProgressValue = 0
  widget.batteryDone = false
  widget.batteryError = false

  if form and type(form.openProgressDialog) == "function" then
    widget.batteryDialog = form.openProgressDialog({
      title = "@i18n(widgets.battery.title)@",
      message = "@i18n(app.msg_saving_settings)@",
      close = function() end,
      wakeup = function() end,
    })
    if widget.batteryDialog then
      widget.batteryDialog:value(0)
      widget.batteryDialog:closeAllowed(false)
    end
  end

  local message = batteryProfileMsp.buildWriteMessage({batteryProfile = profileIndex}, function()
    widget.batteryProfile = profileIndex
    widget.batteryDone = true
  end, function()
    widget.batteryError = true
  end)
  message.sessionBatteryProfile = profileIndex
  bus.publish("msp.request", message)
end

local function chooseBatteryProfile(widget)
  if not widget or widget.connected ~= true then return end
  local profileList = buildBatteryProfileList(widget)
  if #profileList == 0 then
    showBatteryInfo("@i18n(widgets.battery.no_profiles)@")
    return
  end

  if not form or type(form.openDialog) ~= "function" then
    local profile = profileList[1]
    writeBatteryProfile(widget, profile.idx, profile.name)
    return
  end

  local buttons = {}
  local message = "@i18n(widgets.battery.msg_select_battery)@\n\n"
  for _, profile in ipairs(profileList) do
    local label = tostring((profile.idx or 0) + 1)
    message = message .. label .. " - " .. tostring(profile.name) .. "\n"
  end

  for i = #profileList, 1, -1 do
    local profile = profileList[i]
    table.insert(buttons, {
      label = "  " .. tostring((profile.idx or 0) + 1) .. "  ",
      action = function()
        writeBatteryProfile(widget, profile.idx, profile.name)
        return true
      end,
    })
  end

  local screenW = lcd.getWindowSize()
  form.openDialog({
    title = "@i18n(widgets.battery.select_title)@",
    message = message,
    width = screenW and math.floor((screenW * 9) / 10) or nil,
    buttons = buttons,
    wakeup = function() end,
    paint = function() end,
    options = TEXT_LEFT,
  })
end

local function launchSystemTool(widget)
  if not canOpenSystemTool() then return end
  setToolbarVisible(widget, false)
  requestPaint(widget)
  invalidateWidget(widget)
  system.openPage({system = systemToolHandle})
end

local function activateToolbarItem(widget, item)
  if not item then return false end
  if not isToolbarItemEnabled(widget, item) then return false end
  if item.action == "reset_flight" then
    askResetFlight(widget)
    return true
  elseif item.action == "erase_blackbox" then
    askEraseBlackbox(widget)
    return true
  elseif item.action == "battery_profile" then
    chooseBatteryProfile(widget)
    return true
  elseif item.action == "launch_app" then
    launchSystemTool(widget)
    return true
  end
  return false
end

local function updateMinMax(stats, minKey, maxKey, value)
  value = tonumber(value)
  if value == nil then return end
  if stats[minKey] == nil or value < stats[minKey] then stats[minKey] = value end
  if stats[maxKey] == nil or value > stats[maxKey] then stats[maxKey] = value end
end

local function recordStat(stats, key, value)
  value = tonumber(value)
  if not key or value == nil then return end
  local entry = stats[key]
  if not entry then
    entry = {min = value, max = value, sum = 0, count = 0, avg = value}
    stats[key] = entry
  end
  if value < entry.min then entry.min = value end
  if value > entry.max then entry.max = value end
  entry.sum = (entry.sum or 0) + value
  entry.count = (entry.count or 0) + 1
  entry.avg = entry.sum / entry.count
end

local function roundSigned(value)
  if value >= 0 then return math.floor(value + 0.5) end
  return -math.floor(-value + 0.5)
end

local function create()
  return {
    connected = false,
    isArmed = nil,
    craftName = nil,
    mcuId = nil,
    lastConnectedMcuId = nil,
    fcVersion = nil,
    rfVersion = nil,
    voltage = nil,
    batteryConfig = nil,
    consumption = nil,
    current = nil,
    throttlePercent = nil,
    rpm = nil,
    linkQuality = nil,
    tempEsc = nil,
    tempMcu = nil,
    becVoltage = nil,
    fuelPercent = nil,
    governorMode = nil,
    governorState = nil,
    mspTransport = nil,
    pidProfile = nil,
    rateProfile = nil,
    batteryProfile = nil,
    timerLive = 0,
    timerSession = 0,
    timerTarget = 300,
    modelStats = nil,
    bblFlags = nil,
    bblSize = nil,
    bblUsed = nil,
    headspeedVariancePct = nil,
    dashboardStats = {},
    dashboardSettings = nil,
    modelDashboard = nil,
    flightmode = flightmode.new(),
    flightmodeState = "preflight",
    handler = nil,
    settingsHandler = nil,
    taskHandler = nil,
    taskRunning = false,
    taskProtocol = nil,
    needsPaint = true,
    startupComplete = false,
    dashboardPrewarmIndex = 1,
    dashboardPrewarmed = {},
    toolbarVisible = false,
    toolbarOpenedAt = 0,
    toolbarLastActive = 0,
    toolbarCloseAt = 0,
    selectedToolbarIndex = nil,
    toolbarRects = {},
    toolbarMasks = nil,
    pendingResetFlight = false,
    eraseDialog = nil,
    eraseActive = false,
    eraseStartedAt = 0,
    eraseProgressValue = 0,
    eraseReadPending = false,
    eraseDone = false,
    eraseError = false,
    batteryDialog = nil,
    batteryActive = false,
    batteryStartedAt = 0,
    batteryProgressValue = 0,
    batteryDone = false,
    batteryError = false,
    gestureActive = false,
    gestureStartX = 0,
    gestureStartY = 0,
    gestureTriggered = false,
    gestureConsumeUntilTouchEnd = false,
    gestureConsumeStartedAt = 0,
    isSliding = false,
    isSlidingStart = 0,
  }
end

local function recordDashboardStats(widget, state)
  if state ~= "inflight" then return end
  local stats = widget.dashboardStats
  updateMinMax(stats, "minVoltage", "maxVoltage", widget.voltage)
  recordStat(stats, "voltage", widget.voltage)
  updateMinMax(stats, "minConsumption", "maxConsumption", widget.consumption)
  recordStat(stats, "consumption", widget.consumption)
  updateMinMax(stats, "minCurrent", "maxCurrent", widget.current)
  recordStat(stats, "current", widget.current)
  updateMinMax(stats, "minThrottlePercent", "maxThrottlePercent", widget.throttlePercent)
  recordStat(stats, "throttle_percent", widget.throttlePercent)
  updateMinMax(stats, "minRpm", "maxRpm", widget.rpm)
  recordStat(stats, "rpm", widget.rpm)
  local rpmStats = stats.rpm
  if rpmStats and rpmStats.avg and rpmStats.avg > 0 and tonumber(widget.rpm) then
    widget.headspeedVariancePct = roundSigned((math.abs(tonumber(widget.rpm) - rpmStats.avg) / rpmStats.avg) * 100)
  end
  updateMinMax(stats, "minLink", "maxLink", widget.linkQuality)
  recordStat(stats, "link", widget.linkQuality)
  updateMinMax(stats, "minTempEsc", "maxTempEsc", widget.tempEsc)
  recordStat(stats, "temp_esc", widget.tempEsc)
  updateMinMax(stats, "minTempMcu", "maxTempMcu", widget.tempMcu)
  recordStat(stats, "temp_mcu", widget.tempMcu)
  updateMinMax(stats, "minBecVoltage", "maxBecVoltage", widget.becVoltage)
  recordStat(stats, "bec_voltage", widget.becVoltage)
  updateMinMax(stats, "minFuelPercent", "maxFuelPercent", widget.fuelPercent)
  recordStat(stats, "smartfuel", widget.fuelPercent)
  if tonumber(widget.voltage) and tonumber(widget.current) then
    local watts = tonumber(widget.voltage) * tonumber(widget.current)
    updateMinMax(stats, "minWatts", "maxWatts", watts)
    recordStat(stats, "watts", watts)
  end
end

local function update(widget, snapshot)
  snapshot = snapshot or {}
  local previousState = widget.flightmodeState
  local previousConnected = widget.connected
  local previousMcuId = widget.mcuId
  widget.connected = snapshot.connected == true
  widget.isArmed = snapshot.isArmed
  widget.armDisableFlags = snapshot.armDisableFlags

  widget.craftName = snapshot.craftName
  widget.mcuId = snapshot.mcuId
  widget.fcVersion = snapshot.fcVersion
  widget.rfVersion = snapshot.rfVersion
  widget.apiVersionMajor = snapshot.apiVersionMajor
  widget.apiVersionMinor = snapshot.apiVersionMinor
  widget.apiVersionSupported = snapshot.apiVersionSupported
  widget.voltage = snapshot.voltage
  widget.batteryConfig = snapshot.batteryConfig
  widget.consumption = snapshot.consumption
  widget.current = snapshot.current
  widget.throttlePercent = snapshot.throttlePercent
  widget.rpm = snapshot.rpm
  widget.linkQuality = snapshot.linkQuality
  widget.tempEsc = snapshot.tempEsc
  widget.tempMcu = snapshot.tempMcu
  widget.becVoltage = snapshot.becVoltage
  widget.fuelPercent = snapshot.fuelPercent
  widget.governorMode = snapshot.governorMode
  widget.governorState = snapshot.governorState
  widget.mspTransport = snapshot.mspTransport
  widget.pidProfile = snapshot.pidProfile
  widget.rateProfile = snapshot.rateProfile
  widget.batteryProfile = snapshot.batteryProfile
  widget.timerLive = snapshot.timerLive or 0
  widget.timerSession = snapshot.timerSession or 0
  widget.timerTarget = snapshot.timerTarget or 300
  widget.modelStats = snapshot.modelStats
  widget.bblFlags = snapshot.bblFlags
  widget.bblSize = snapshot.bblSize
  widget.bblUsed = snapshot.bblUsed

  if widget.mcuId ~= previousMcuId and widget.connected == true and widget.mcuId and widget.mcuId ~= "" then
    if widget.lastConnectedMcuId and widget.lastConnectedMcuId ~= widget.mcuId then
      -- A genuinely different aircraft just connected. session.lua nils
      -- out mcuId on every disconnect, so previousMcuId (this tick's prior
      -- value) is always nil right here and can't distinguish "same model
      -- reconnecting" from "different model connected" -- lastConnectedMcuId
      -- persists across that gap for the real comparison. Postflight/
      -- inflight state, min/max stats, and timers from the previous model
      -- must not bleed into the new one.
      if widget.flightmode and type(widget.flightmode.reset) == "function" then
        widget.flightmode:reset()
      end
      widget.headspeedVariancePct = nil
      clearDashboardStats(widget.dashboardStats)
      widget.timerLive = 0
      widget.timerSession = 0
    end
    widget.lastConnectedMcuId = widget.mcuId

    local previousModelDashboard = widget.modelDashboard
    loadModelDashboard(widget)
    if not sameModelDashboard(previousModelDashboard, widget.modelDashboard) then
      clearThemeCache()
      resetDashboardPrewarm(widget)
      markStartupUnderlayDirty(widget)
    end
  end

  if previousConnected == false and widget.connected == true then
    if previousState == "postflight" and widget.flightmode and type(widget.flightmode.reset) == "function" then
      widget.flightmode:reset()
    end
    clearDashboardStats(widget.dashboardStats)
    widget.headspeedVariancePct = nil
  elseif previousConnected == true and widget.connected ~= true then
    markStartupUnderlayDirty(widget)
  end

  widget.flightmodeState = widget.flightmode:update(widget)
  if widget.flightmodeState == "inflight" and previousState ~= "inflight" and previousState ~= "postflight" then
    clearDashboardStats(widget.dashboardStats)
    widget.headspeedVariancePct = nil
  end
  recordDashboardStats(widget, widget.flightmodeState)
end

local function dashboardState(widget)
  return widget.flightmodeState or "preflight"
end

local function hasTelemetryValues(widget)
  return widget
    and (widget.voltage ~= nil
      or widget.current ~= nil
      or widget.consumption ~= nil
      or widget.throttlePercent ~= nil
      or widget.rpm ~= nil
      or widget.linkQuality ~= nil
      or widget.tempEsc ~= nil
      or widget.tempMcu ~= nil
      or widget.becVoltage ~= nil
      or widget.fuelPercent ~= nil)
end

local function shouldShowStartupOverlay(widget)
  if not widget then return true end
  -- Checked ahead of startupComplete's latch so an unsupported FC still
  -- surfaces if a previous connection in this widget session completed.
  if widget.connected == true and widget.apiVersionSupported == false then return true end
  if widget.startupComplete == true then return false end
  if dashboardState(widget) == "postflight" then return false end
  if widget.taskRunning ~= true then return true end
  if widget.connected ~= true then return true end
  -- Wait for real sensor data, not just a live task/link, before switching
  -- to the full dashboard -- otherwise the very first wakeOne() per box
  -- resolves its sensor source before anything is actually broadcasting,
  -- which caches a miss and (lib/telemetry_sensors.lua's MISS_RETRY_INTERVAL
  -- / context.lua's LIVE_MISS_RETRY_INTERVAL) blocks retrying for 5s --
  -- exactly the "values take forever to appear" symptom this avoids.
  if not hasTelemetryValues(widget) then return true end
  return false
end

local function startupOverlayMessage(widget)
  if not widget or widget.taskRunning ~= true then
    return "@i18n(widgets.dashboard.startup_waiting_task)@",
      "@i18n(widgets.dashboard.startup_waiting_task_detail)@"
  end
  if widget.connected == true and widget.apiVersionSupported == false then
    local detected = "?"
    if widget.apiVersionMajor and widget.apiVersionMinor then
      detected = string.format("%d.%02d", widget.apiVersionMajor, widget.apiVersionMinor)
    end
    return "@i18n(widgets.dashboard.startup_unsupported_version)@",
      "@i18n(widgets.dashboard.startup_unsupported_version_detail)@ " .. detected
  end
  if widget.connected ~= true then
    return "@i18n(widgets.dashboard.startup_no_link)@",
      "@i18n(widgets.dashboard.startup_no_link_detail)@"
  end
  return "@i18n(widgets.dashboard.startup_preparing_dashboard)@",
    "@i18n(widgets.dashboard.startup_preparing_dashboard_detail)@"
end

local function drawCenteredText(text, y, font, color, screenW)
  if not text or text == "" then return 0 end
  lcd.font(font)
  lcd.color(color)
  local tw, th = lcd.getTextSize(text)
  lcd.drawText(math.floor((screenW - (tw or 0)) / 2 + 0.5), y, text)
  return th or 0
end

local function drawFilledRoundRect(x, y, w, h, radius)
  x = math.floor((x or 0) + 0.5)
  y = math.floor((y or 0) + 0.5)
  w = math.floor((w or 0) + 0.5)
  h = math.floor((h or 0) + 0.5)
  if w <= 0 or h <= 0 then return end

  radius = math.floor((radius or 0) + 0.5)
  radius = math.max(0, math.min(radius, math.floor(math.min(w, h) / 2)))
  if radius <= 0 or not lcd.drawFilledCircle then
    lcd.drawFilledRectangle(x, y, w, h)
    return
  end

  lcd.drawFilledRectangle(x + radius, y, w - (2 * radius), h)
  lcd.drawFilledRectangle(x, y + radius, radius, h - (2 * radius))
  lcd.drawFilledRectangle(x + w - radius, y + radius, radius, h - (2 * radius))
  lcd.drawFilledCircle(x + radius, y + radius, radius)
  lcd.drawFilledCircle(x + w - radius - 1, y + radius, radius)
  lcd.drawFilledCircle(x + radius, y + h - radius - 1, radius)
  lcd.drawFilledCircle(x + w - radius - 1, y + h - radius - 1, radius)
end

local function drawRoundedPanel(x, y, w, h, border, radius, borderColor, fillColor)
  lcd.color(borderColor)
  drawFilledRoundRect(x, y, w, h, radius)
  local innerW = w - (2 * border)
  local innerH = h - (2 * border)
  if innerW <= 0 or innerH <= 0 then return end
  lcd.color(fillColor)
  drawFilledRoundRect(x + border, y + border, innerW, innerH, math.max(0, radius - border))
end

local function drawStartupOverlay(widget, w, h, hasBackground)
  local utils = dashboardUtils(false)
  local theme = utils and utils.getThemeState and utils.getThemeState() or {}
  local bg = theme.pageBgColor or theme.primaryBgColor or lcd.RGB(16, 16, 16, 1)
  local panel = theme.primaryBgColor or lcd.RGB(0, 0, 0, 1)
  local border = theme.buttonBorderActiveColor or theme.secondaryColor or lcd.RGB(255, 255, 255, 1)
  local text = theme.primaryColor or lcd.RGB(255, 255, 255, 1)
  local subtext = theme.secondaryColor or text

  lcd.color(hasBackground and lcd.RGB(0, 0, 0, 0.35) or bg)
  lcd.drawFilledRectangle(0, 0, w, h)

  local panelW = math.floor(math.min(w * 0.78, 520) + 0.5)
  local panelH = math.floor(math.min(h * 0.62, 300) + 0.5)
  local panelX = math.floor((w - panelW) / 2 + 0.5)
  local panelY = math.floor((h - panelH) / 2 + 0.5)
  local borderW = math.max(4, math.floor(math.min(panelW, panelH) * 0.055 + 0.5))
  local radius = math.floor(math.min(panelW, panelH) * 0.14 + 0.5)

  drawRoundedPanel(panelX, panelY, panelW, panelH, borderW, radius, border, panel)

  local logo = utils and utils.loadImage and utils.loadImage(utils.getLogoFallbackForBackground and utils.getLogoFallbackForBackground(panel) or "widgets/dashboard/gfx/logo-light.png")
  local cursorY = panelY + math.floor(panelH * 0.18)
  if logo and lcd.drawBitmap then
    local logoW = math.floor(math.min(panelW * 0.55, 230) + 0.5)
    local logoH = math.floor(logoW * 0.23 + 0.5)
    lcd.drawBitmap(math.floor(panelX + (panelW - logoW) / 2 + 0.5), cursorY, logo, logoW, logoH)
    cursorY = cursorY + logoH + math.floor(panelH * 0.12)
  else
    cursorY = cursorY + drawCenteredText("@i18n(widgets.dashboard.startup_title)@", cursorY, FONT_L, text, w) + math.floor(panelH * 0.10)
  end

  local message, detail = startupOverlayMessage(widget)
  cursorY = cursorY + drawCenteredText(message, cursorY, FONT_S, text, w) + 8
  cursorY = cursorY + drawCenteredText(detail, cursorY, FONT_XS, subtext, w) + 6
  drawCenteredText(buildInfo.displayName(), cursorY, FONT_XXS, subtext, w)
end

local function setDashboardPreferences(widget, theme)
  ensureDashboardSettings(widget)
  ensureDashboardContext().widgets.dashboard.setPreferences(settingsStore.dashboardTheme(widget.settingsSnapshot, theme))
end

local function prepareDashboard(widget, allowStartupOverlay, maxObjects)
  if shouldShowStartupOverlay(widget) and not allowStartupOverlay then return end
  local w, h = lcd.getWindowSize()
  local state = dashboardState(widget)
  local theme = selectedThemeForState(widget, state)
  setDashboardPreferences(widget, theme)
  local engine = ensureDashboardEngine()
  if engine.wakeup then
    return engine.wakeup(widget, loadStateDef(theme, state), w, h, maxObjects and {maxObjects = maxObjects} or nil)
  end
  return true
end

local function paintDashboardShell(widget, w, h)
  local state = dashboardState(widget)
  local theme = selectedThemeForState(widget, state)
  setDashboardPreferences(widget, theme)
  local engine = ensureDashboardEngine()
  if engine.paintShell then engine.paintShell(widget, loadStateDef(theme, state), w, h) end
end

local function paintDashboard(widget, w, h)
  local state = dashboardState(widget)
  local theme = selectedThemeForState(widget, state)
  setDashboardPreferences(widget, theme)
  ensureDashboardEngine().paint(widget, loadThemeDef(theme), loadStateDef(theme, state), state, w, h)
end

local function prewarmDashboardState(widget)
  if not widget then return end
  local index = widget.dashboardPrewarmIndex or 1
  if index > #PREWARM_STATES then return end

  local state = PREWARM_STATES[index]
  local theme = selectedThemeForState(widget, state)
  local key = theme .. ":" .. state
  widget.dashboardPrewarmed = widget.dashboardPrewarmed or {}

  widget.dashboardPrewarmIndex = index + 1
  if widget.dashboardPrewarmed[key] then return end

  setDashboardPreferences(widget, theme)
  local engine = ensureDashboardEngine()
  if engine.preload then engine.preload(widget, loadStateDef(theme, state)) end
  widget.dashboardPrewarmed[key] = true
end

local function paint(widget)
  local w, h = lcd.getWindowSize()
  if shouldShowStartupOverlay(widget) then
    -- Keep blocking startup states cheap: draw only the themed shell behind
    -- the overlay, not the live object/value pipeline.
    paintDashboardShell(widget, w, h)
    drawStartupOverlay(widget, w, h, true)
    drawToolbar(widget, w, h)
    return
  end
  paintDashboard(widget, w, h)
  drawToolbar(widget, w, h)
end

local function consumeTouchEvents()
  if not system or not system.killEvents then return end
  if TOUCH_START then system.killEvents(TOUCH_START) end
  if TOUCH_MOVE then system.killEvents(TOUCH_MOVE) end
  if TOUCH_END then system.killEvents(TOUCH_END) end
end

local function event(widget, category, value, x, y)
  if widget.gestureConsumeUntilTouchEnd and category == EVT_TOUCH then
    local now = clock()
    local staleConsume = widget.gestureConsumeStartedAt > 0 and (now - widget.gestureConsumeStartedAt) >= GESTURE_CONSUME_TIMEOUT
    if value == TOUCH_START or staleConsume then
      widget.gestureConsumeUntilTouchEnd = false
      widget.gestureActive = false
      widget.gestureTriggered = false
      widget.gestureConsumeStartedAt = 0
    else
      consumeTouchEvents()
      if value == TOUCH_END then
        widget.gestureConsumeUntilTouchEnd = false
        widget.gestureActive = false
        widget.gestureTriggered = false
        widget.gestureConsumeStartedAt = 0
      end
      return true
    end
  end

  if category == EVT_KEY and value == KEY_PAGE_LONG and lcd.hasFocus() then
    setToolbarVisible(widget, true)
    invalidateWidget(widget)
    if system and system.killEvents then system.killEvents(value) end
    return true
  end

  if widget.toolbarVisible and category == EVT_KEY and lcd.hasFocus() then
    local count = #TOOLBAR_ITEMS
    local idx = widget.selectedToolbarIndex or 1
    if value == ROTARY_LEFT then
      idx = idx - 1
      if idx < 1 then idx = count end
      widget.selectedToolbarIndex = idx
      widget.toolbarLastActive = clock()
      requestPaint(widget)
      invalidateWidget(widget)
      return true
    elseif value == KEY_ROTARY_RIGHT then
      idx = idx + 1
      if idx > count then idx = 1 end
      widget.selectedToolbarIndex = idx
      widget.toolbarLastActive = clock()
      requestPaint(widget)
      invalidateWidget(widget)
      return true
    elseif value == KEY_ENTER_BREAK then
      local item = TOOLBAR_ITEMS[idx]
      widget.toolbarLastActive = clock()
      if activateToolbarItem(widget, item) then return true end
      requestPaint(widget)
      invalidateWidget(widget)
      return true
    elseif value == KEY_DOWN_BREAK then
      setToolbarVisible(widget, false)
      invalidateWidget(widget)
      return true
    end
  end

  if widget.toolbarVisible and category == EVT_TOUCH and (value == TOUCH_START or value == TOUCH_END) and x and y then
    for idx, rect in ipairs(widget.toolbarRects or {}) do
      if x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h then
        widget.selectedToolbarIndex = idx
        widget.toolbarLastActive = clock()
        requestPaint(widget)
        invalidateWidget(widget)
        if value == TOUCH_END and activateToolbarItem(widget, rect.item) then return true end
        return true
      end
    end
  end

  if category == EVT_TOUCH and value == TOUCH_START and x and y then
    widget.gestureActive = true
    widget.gestureStartX = x
    widget.gestureStartY = y
    widget.gestureTriggered = false
    widget.gestureConsumeStartedAt = 0
  elseif category == EVT_TOUCH and value == TOUCH_END then
    widget.gestureActive = false
    widget.gestureTriggered = false
    widget.gestureConsumeStartedAt = 0
  elseif category == EVT_TOUCH and value == TOUCH_MOVE and x and y then
    widget.isSliding = true
    widget.isSlidingStart = clock()
    if not widget.gestureActive then
      widget.gestureActive = true
      widget.gestureStartX = x
      widget.gestureStartY = y
      widget.gestureTriggered = false
    end
    if not widget.gestureTriggered then
      local dx = x - (widget.gestureStartX or x)
      local dy = y - (widget.gestureStartY or y)
      if math.abs(dx) <= GESTURE_MAX_DX then
        if dy <= -GESTURE_MIN_DY then
          widget.gestureTriggered = true
          widget.gestureConsumeUntilTouchEnd = true
          widget.gestureConsumeStartedAt = clock()
          setToolbarVisible(widget, true)
          consumeTouchEvents()
          invalidateWidget(widget)
          return true
        elseif dy >= GESTURE_MIN_DY then
          widget.gestureTriggered = true
          widget.gestureConsumeUntilTouchEnd = true
          widget.gestureConsumeStartedAt = clock()
          setToolbarVisible(widget, false)
          consumeTouchEvents()
          invalidateWidget(widget)
          return true
        end
      end
    end
  end

  return false
end

local function wakeup(widget)
  -- Skip all work while a different screen is actually on the display --
  -- either this tool's own full-screen app/menu (appRunning) or simply
  -- some other Ethos screen (lcd.isVisible() false). Matches master's
  -- dashboard.wakeup() early return; see appRunning's own comment above.
  if appRunning or not lcd.isVisible() then return end

  if widget.pendingResetFlight then
    widget.pendingResetFlight = false
    applyResetFlight(widget)
  end

  if not widget.dashboardSettings then
    widget.settingsSnapshot = settingsStore.load()
    widget.dashboardSettings = settingsStore.dashboard(widget.settingsSnapshot)
    requestPaint(widget)
  end

  if not widget.handler then
    widget.handler = function(snapshot)
      update(widget, snapshot)
      requestPaint(widget)
    end
    bus.subscribe("session.update", widget.handler)
  end

  if not widget.taskHandler then
    widget.taskHandler = function(status)
      status = status or {}
      local running = status.running == true
      local protocol = status.protocol
      if running ~= widget.taskRunning or protocol ~= widget.taskProtocol then
        widget.taskRunning = running
        widget.taskProtocol = protocol
        requestPaint(widget)
      end
    end
    bus.subscribe("task.status", widget.taskHandler)
  end

  if not widget.settingsHandler then
    widget.settingsHandler = function(snapshot)
      widget.settingsSnapshot = settingsStore.clone(snapshot)
      widget.dashboardSettings = settingsStore.dashboard(snapshot)
      loadModelDashboard(widget)
      clearThemeCache()
      resetDashboardPrewarm(widget)
      markStartupUnderlayDirty(widget)
      requestPaint(widget)
    end
    bus.subscribe("settings.update", widget.settingsHandler)
  end

  -- Poll for a live Ethos OS theme change (switching light/dark, or to a
  -- different installed theme package) -- nothing else notifies us of this,
  -- since it doesn't go through rfsuite's own "settings.update" bus event.
  -- Matches master's dashboard.lua wakeup(), which does the same 0.25s poll.
  local now = clock()
  if now >= nextThemeStateCheck then
    nextThemeStateCheck = now + THEME_STATE_CHECK_INTERVAL
    local utils = dashboardUtils(true)
    local currentThemeSignature = utils and utils.getThemeSignature and utils.getThemeSignature() or nil
    if currentThemeSignature ~= themeStateSignature then
      themeStateSignature = currentThemeSignature
      clearThemeCache()
      resetDashboardPrewarm(widget)
      markStartupUnderlayDirty(widget)
      requestPaint(widget)
    end
  end

  if widget.needsPaint then
    widget.needsPaint = false
    prepareDashboard(widget)
    invalidateWidget(widget)
  end

  if widget.toolbarVisible then
    local now = clock()
    if widget.toolbarLastActive == 0 then widget.toolbarLastActive = now end
    if TOOLBAR_TIMEOUT > 0 and (now - widget.toolbarLastActive) >= TOOLBAR_TIMEOUT then
      setToolbarVisible(widget, false)
      invalidateWidget(widget)
    end
  end

  if shouldShowStartupOverlay(widget) then
    -- paint() only ever shows the lightweight shell while the overlay is up
    -- (see its own comment), so this can't paint anything premature -- but
    -- it's still worth incrementally warming the *full-content* box cache
    -- here, a few objects per tick, so that by the time real telemetry
    -- arrives and the overlay drops, every box's object-type module and
    -- sensor source are already resolved instead of all needing it at once.
    if widget.connected == true then
      prepareDashboard(widget, true, STARTUP_PREP_OBJECTS_PER_TICK)
      requestPaint(widget)
      invalidateWidget(widget)
    end
  else
    widget.startupComplete = true
  end

  if widget.startupComplete == true then
    prewarmDashboardState(widget)
  end

  if widget.eraseActive then
    local now = clock()
    readBlackboxSummaryAfterErase(widget)
    local elapsed = now - (widget.eraseStartedAt or now)
    local progress = math.min(95, math.floor((elapsed / 5.0) * 100))
    if progress > (widget.eraseProgressValue or 0) then
      widget.eraseProgressValue = progress
      if widget.eraseDialog and widget.eraseDialog.value then
        widget.eraseDialog:value(progress)
      end
    end
    if widget.eraseDone or widget.eraseError then
      finishErase(widget, widget.eraseError == true)
    end
  end

  if widget.batteryActive then
    local now = clock()
    local elapsed = now - (widget.batteryStartedAt or now)
    local progress = math.min(95, math.floor((elapsed / 2.0) * 100))
    if progress > (widget.batteryProgressValue or 0) then
      widget.batteryProgressValue = progress
      if widget.batteryDialog and widget.batteryDialog.value then
        widget.batteryDialog:value(progress)
      end
    end
    if widget.batteryDone or widget.batteryError then
      finishBatteryProfileWrite(widget, widget.batteryError == true)
    end
  end

  if widget.gestureConsumeUntilTouchEnd and widget.gestureConsumeStartedAt > 0 and (clock() - widget.gestureConsumeStartedAt) >= GESTURE_CONSUME_TIMEOUT then
    widget.gestureConsumeUntilTouchEnd = false
    widget.gestureActive = false
    widget.gestureTriggered = false
    widget.gestureConsumeStartedAt = 0
  end

  if widget.isSliding and (clock() - (widget.isSlidingStart or 0)) > 1 then
    widget.isSliding = false
  end
end

local function configure(widget)
end

local function read(widget)
end

local function write(widget)
end

local function close(widget)
  if widget.handler then
    bus.unsubscribe("session.update", widget.handler)
    widget.handler = nil
  end
  if widget.settingsHandler then
    bus.unsubscribe("settings.update", widget.settingsHandler)
    widget.settingsHandler = nil
  end
  if widget.taskHandler then
    bus.unsubscribe("task.status", widget.taskHandler)
    widget.taskHandler = nil
  end
  widget.eraseActive = false
  widget.eraseReadPending = false
  widget.eraseDone = false
  widget.eraseError = false
  closeEraseDialog(widget)
  widget.batteryActive = false
  widget.batteryDone = false
  widget.batteryError = false
  closeBatteryDialog(widget)
  clearToolbarMasks(widget)
  clearThemeCache()
end

local widget = {
  key = "rf2sdh",
  name = "Rotorflight Dashboard",
  create = create,
  paint = paint,
  wakeup = wakeup,
  event = event,
  configure = configure,
  read = read,
  write = write,
  close = close,
  title = false,
}

local function init(opts)
  opts = opts or {}
  systemToolHandle = opts.systemToolHandle
  system.registerWidget(widget)
end

return {init = init}
