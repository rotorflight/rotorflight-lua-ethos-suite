-- Rotorflight dashboard widget.
--
-- Lite keeps the old dashboard's preflight/inflight/postflight theme shape,
-- while loading only the selected theme and current state page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local modelPreferences = requireModule("lib/model_preferences.lua")
local settingsStore = requireModule("lib/settings_store.lua")
local flightmode = requireModule("widgets/dashboard/flightmode.lua")
local dataflashErase = requireModule("lib/msp_dataflash_erase.lua")
local dataflashSummary = requireModule("lib/msp_dataflash_summary.lua")
local batteryProfileMsp = requireModule("lib/msp_battery_profile.lua")
local ethosVersion = requireModule("lib/ethos_version.lua")
local mspApiVersion = requireModule("lib/msp_api_version.lua")

local THEME_DIRS = {
  aegis = "widgets/dashboard/themes/aegis",
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
local INSTRUCTION_BUDGET_ERROR = "Max instructions count reached"

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
  trimDashboardCaches({theme = true})
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
    dashboardContext = requireModule("widgets/dashboard/context.lua")
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
    dashboardEngine = requireModule("widgets/dashboard/engine.lua")
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

local function resetDashboardPaintRetry(widget)
  if not widget then return end
  widget.dashboardPaintRetryPending = false
  widget.dashboardPaintRetryIndex = nil
  widget.dashboardInstructionBudgetRetryLogged = false
end

local function isInstructionBudgetError(err)
  return type(err) == "string" and string.find(err, INSTRUCTION_BUDGET_ERROR, 1, true) ~= nil
end

local function resetDashboardPrewarm(widget)
  if not widget then return end
  widget.dashboardPrewarmIndex = 1
  if widget.dashboardPrewarmed then
    for key in pairs(widget.dashboardPrewarmed) do widget.dashboardPrewarmed[key] = nil end
  end
end

local function requestThemeReload(widget, restoreAfterReload)
  local wasComplete = widget and widget.dashboardEverPainted == true
  clearThemeCache()
  resetDashboardPrewarm(widget)
  resetDashboardPaintRetry(widget)
  if widget then
    widget.themeReloadPending = true
    widget.themeReloadWasComplete = wasComplete or restoreAfterReload == true
  end
  requestPaint(widget)
end

local function finishThemeReload(widget)
  if not widget then return end
  widget.themeReloadPending = false
  widget.themeReloadWasComplete = false
end

local function invalidateWidget(widget)
  if not lcd or not lcd.invalidate then return end
  local ok = pcall(lcd.invalidate, widget)
  if not ok then pcall(lcd.invalidate) end
end

local function invalidateWidgetGlobal(widget)
  invalidateWidget(widget)
  if lcd and lcd.invalidate then pcall(lcd.invalidate) end
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
  local lowRes = w <= 640
  local widthRatio = lowRes and 0.22 or 0.16
  local minRatio = lowRes and 0.28 or 0.24
  local maxRatio = lowRes and 0.42 or 0.40
  local minIconBarH = lowRes and math.min(96, h * 0.48) or 0
  local barH = math.floor(math.max(h * minRatio, minIconBarH, math.min(h * maxRatio, w * widthRatio)))
  return 0, h - barH, w, barH
end

local function fitToolbarLabel(widget, item, maxW, font)
  local label = item and item.name
  if type(label) ~= "string" or label == "" then return label end
  widget.toolbarLabelCache = widget.toolbarLabelCache or {}
  local cached = widget.toolbarLabelCache[item]
  if cached and cached.label == label and cached.maxW == maxW and cached.font == font then
    return cached.text, cached.h
  end

  local tw, th = lcd.getTextSize(label)
  local fitted = label
  local ellipsis = "..."
  if tw > maxW then
    local ellW = lcd.getTextSize(ellipsis)
    if ellW >= maxW then
      fitted = ellipsis
    else
      local trimmed = label
      while #trimmed > 1 do
        trimmed = trimmed:sub(1, #trimmed - 1)
        tw = lcd.getTextSize(trimmed)
        if tw + ellW <= maxW then
          fitted = trimmed .. ellipsis
          break
        end
      end
      if fitted == label then fitted = ellipsis end
    end
  end

  if fitted ~= label then _, th = lcd.getTextSize(fitted) end
  if not cached then
    cached = {}
    widget.toolbarLabelCache[item] = cached
  end
  cached.label = label
  cached.maxW = maxW
  cached.font = font
  cached.text = fitted
  cached.h = th or 0
  return fitted, cached.h
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
  local lowRes = barW <= 640
  local slotPad = lowRes and 6 or 12
  local groupPadTop = lowRes and 4 or 6
  local textPadTop = lowRes and 3 or 6
  local iconBottomPad = lowRes and 5 or 8
  local iconGap = lowRes and 3 or 6
  local iconSize = 55
  local labelFont = (lowRes and FONT_XXS) or FONT_XS

  lcd.color(colors.surfaceBg)
  lcd.drawFilledRectangle(x, y, barW, barH)
  lcd.color(colors.line)
  lcd.drawFilledRectangle(x, y, barW, lowRes and 3 or 4)
  lcd.font(labelFont)

  widget.toolbarRects = widget.toolbarRects or {}
  for key in pairs(widget.toolbarRects) do widget.toolbarRects[key] = nil end

  for i, item in ipairs(TOOLBAR_ITEMS) do
    local ix = x + (i - 1) * itemW
    local bx = ix + slotPad
    local by = y + slotPad + groupPadTop
    local bw = itemW - (slotPad * 2)
    local bh = barH - (slotPad * 2) - groupPadTop
    local enabled = isToolbarItemEnabled(widget, item)
    widget.toolbarRects[i] = {x = ix, y = y, w = itemW, h = barH, item = item, enabled = enabled}

    local selected = widget.selectedToolbarIndex == i
    lcd.color((selected and enabled) and colors.selectedFill or colors.tileFill)
    lcd.drawFilledRectangle(bx, by, bw, bh)
    lcd.color((selected and enabled) and colors.selectedText or colors.text)
    local label, labelH = fitToolbarLabel(widget, item, math.floor(bw - 4), labelFont)
    local labelY = by + textPadTop
    lcd.drawText(bx + (bw * 0.5), labelY, label, CENTERED)

    local mask = loadToolbarMask(widget, item.icon)
    if mask and lcd.drawMask then
      lcd.color((selected and enabled) and colors.selectedText or colors.text)
      local minIconY = labelY + (labelH or 0) + iconGap
      local iconY = by + bh - iconSize - iconBottomPad
      if iconY < minIconY then iconY = minIconY end
      lcd.drawMask(math.floor(bx + (bw - iconSize) / 2 + 0.5), math.floor(iconY + 0.5), mask)
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
    -- Per-instance (not module-level, unlike app/tool.lua's own equivalent
    -- singleton fields) since this widget can have more than one
    -- simultaneous instance -- see drawBackgroundTaskWarning() below.
    createdAt = os.clock(),
    taskStatusAt = nil,
    needsPaint = true,
    dashboardEverPainted = false,
    dashboardPaintRetryPending = false,
    dashboardPaintRetryIndex = nil,
    dashboardInstructionBudgetRetryLogged = false,
    themeReloadPending = false,
    themeReloadWasComplete = false,
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
    batteryDialogShown = false,
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
      requestThemeReload(widget)
    end
  end

  if previousConnected == false and widget.connected == true then
    if previousState == "postflight" and widget.flightmode and type(widget.flightmode.reset) == "function" then
      widget.flightmode:reset()
    end
    clearDashboardStats(widget.dashboardStats)
    widget.headspeedVariancePct = nil
  elseif previousConnected == true and widget.connected ~= true then
    -- Re-arm the startup battery-profile prompt for the next connection
    -- (matches master's own reset of session.batteryDialogShown on
    -- disconnect) -- otherwise reconnecting the same craft would never
    -- prompt again for the rest of this widget's lifetime.
    widget.batteryDialogShown = false
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

local function setDashboardPreferences(widget, theme)
  ensureDashboardSettings(widget)
  ensureDashboardContext().widgets.dashboard.setPreferences(settingsStore.dashboardTheme(widget.settingsSnapshot, theme), "system/" .. theme)
end

local function prepareDashboard(widget)
  local w, h = lcd.getWindowSize()
  local state = dashboardState(widget)
  local theme = selectedThemeForState(widget, state)
  setDashboardPreferences(widget, theme)
  local engine = ensureDashboardEngine()
  if engine.wakeup then
    return engine.wakeup(widget, loadStateDef(theme, state), w, h)
  end
  return true
end

local function handleDashboardResize(widget)
  if not widget or not lcd or not lcd.getWindowSize then return end
  local w, h = lcd.getWindowSize()
  local previousW = widget.dashboardWindowW
  local previousH = widget.dashboardWindowH
  if previousW == w and previousH == h then return end

  widget.dashboardWindowW = w
  widget.dashboardWindowH = h
  if previousW == nil or previousH == nil then return end

  if widget.dashboardEverPainted ~= true or widget.themeReloadPending == true then
    resetDashboardPrewarm(widget)
    resetDashboardPaintRetry(widget)
    requestPaint(widget)
  end
end

local function paintDashboard(widget, w, h)
  local state = dashboardState(widget)
  local theme = selectedThemeForState(widget, state)
  setDashboardPreferences(widget, theme)
  local ok, result = pcall(ensureDashboardEngine().paint, widget, loadThemeDef(theme), loadStateDef(theme, state), state, w, h)
  if not ok then
    if isInstructionBudgetError(result) then
      if widget and widget.dashboardInstructionBudgetRetryLogged ~= true then
        print("[dashboard] paint budget exhausted; retrying next tick: " .. tostring(result))
        widget.dashboardInstructionBudgetRetryLogged = true
      end
      if widget then widget.dashboardPaintRetryPending = true end
      return false
    end
    print("[dashboard] paint failed: " .. tostring(result))
    if widget then widget.dashboardPaintRetryPending = false end
    return true
  end
  ok = result
  if ok == false then
    if widget then widget.dashboardPaintRetryPending = true end
    return false
  end
  if widget then
    widget.dashboardPaintRetryPending = false
    widget.dashboardEverPainted = true
  end
  return true
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

-- Lightweight dashboard error overlays -- currently two: "connected to
-- invalid/unsupported firmware" and "background task not running". Both
-- share this same single-line strip across the footer (bottom edge) of
-- the screen, drawn on top of whatever the theme/toolbar already painted
-- there, not a modal dialog or a restructuring of the normal paint
-- layout. Footer rather than header: keeps the top of the screen (craft
-- name/link status, in most themes) clear. Each stays up for as long as
-- its own condition holds, not a timed toast -- the underlying problem
-- doesn't clear itself. Can visually stack with the toolbar (also
-- footer-anchored, see toolbarBounds()) if the pilot manually swipes it
-- open while one of these is showing -- an intentionally unhandled rare
-- overlap, not worth the complexity for how lightweight this is meant to
-- stay. At most one shows at a time -- see drawFooterAlert()'s own
-- priority ordering.
local FOOTER_ALERT_BG = lcd.RGB(180, 20, 20, 1)
local FOOTER_ALERT_TEXT = lcd.RGB(255, 255, 255, 1)

local function drawFooterBanner(w, h, text)
  lcd.font(w <= 640 and FONT_XS or FONT_S)
  local _, textH = lcd.getTextSize(text)
  local bannerH = textH + (w <= 640 and 8 or 12)
  local bannerY = h - bannerH

  lcd.color(FOOTER_ALERT_BG)
  lcd.drawFilledRectangle(0, bannerY, w, bannerH)
  lcd.color(FOOTER_ALERT_TEXT)
  lcd.drawText(w * 0.5, bannerY + (bannerH - textH) * 0.5, text, CENTERED)
end

-- See lib/msp_api_version.lua's classifyUnsupported() for the two states
-- this distinguishes ("invalid": a different firmware family entirely,
-- wrong product, not just an old version of this one; "unsupported":
-- right family, minor below this rebuild's own floor, needs a firmware
-- update).
local function apiVersionWarningText(widget)
  local reason, familyName = mspApiVersion.classifyUnsupported(widget.apiVersionMajor, widget.apiVersionMinor)
  if not reason then return nil end
  local version = tostring(widget.apiVersionMajor) .. "." .. tostring(widget.apiVersionMinor)
  if reason == "invalid" then
    if familyName then
      return "@i18n(widgets.dashboard.startup_invalid_device)@: " .. familyName .. " (MSP " .. version .. ")"
    end
    return "@i18n(widgets.dashboard.startup_invalid_device)@ (MSP " .. version .. ")"
  end
  return "@i18n(widgets.dashboard.startup_unsupported_version)@ (MSP " .. version .. ")"
end

-- Mirrors app/tool.lua's own isBackgroundTaskRunning()/TASK_ALERT_GRACE
-- watchdog (kept independent, per-widget-instance state rather than
-- shared -- see this file's header comment on why the three subsystems
-- never touch each other's internals directly), tracking "task.status"
-- staleness the same way. Needed here too, not just in app/tool.lua's own
-- popup: a pilot watching the dashboard (not the full-screen tool) gets
-- no other indication the background task -- which owns the MSP link/
-- session/telemetry this whole widget depends on -- has stopped running.
local BG_TASK_STATUS_TIMEOUT = 3.0
-- See app/tool.lua's own TASK_ALERT_GRACE for the full reasoning; kept in
-- sync with that same value.
local BG_TASK_ALERT_GRACE = 10.0

local function isBackgroundTaskRunning(widget)
  return widget.taskStatusAt ~= nil and (os.clock() - widget.taskStatusAt) <= BG_TASK_STATUS_TIMEOUT
end

local function backgroundTaskGraceExpired(widget)
  return widget.createdAt ~= nil and (os.clock() - widget.createdAt) >= BG_TASK_ALERT_GRACE
end

-- Priority order: background-task-down first (the more fundamental
-- problem -- without it, session/MSP state can never resolve either way,
-- so widget.connected can never even become true), then invalid/
-- unsupported firmware. In practice these are close to mutually
-- exclusive already (widget.connected requires the background task to be
-- alive), but keeping an explicit order costs nothing and avoids ever
-- drawing both at once.
local function drawFooterAlert(widget, w, h)
  if not widget then return end
  if not isBackgroundTaskRunning(widget) then
    if not backgroundTaskGraceExpired(widget) then return end
    drawFooterBanner(w, h, "@i18n(app.msg_background_task_missing_title)@")
    return
  end

  if widget.connected == true and widget.apiVersionSupported == false then
    local text = apiVersionWarningText(widget)
    if text then drawFooterBanner(w, h, text) end
  end
end

local function paint(widget)
  local w, h = lcd.getWindowSize()
  if widget and widget.themeReloadPending == true then
    if prepareDashboard(widget) then finishThemeReload(widget) end
  end
  if paintDashboard(widget, w, h) == false then
    requestPaint(widget)
    invalidateWidgetGlobal(widget)
    return
  end
  drawToolbar(widget, w, h)
  drawFooterAlert(widget, w, h)
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
  -- Keep retained session/task/settings subscriptions above the visibility
  -- guard so state tracking is never gated behind a check that only exists
  -- to skip expensive per-tick dashboard prep work.
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
      -- Tracks staleness, not just "has this ever fired" -- see
      -- drawBackgroundTaskWarning() below, same reasoning as app/tool.lua's
      -- own isBackgroundTaskRunning(). "task.status" is retained (see
      -- lib/bus.lua's header), so a late subscriber's very first callback
      -- here is a replay of whatever was last published, not necessarily
      -- fresh -- but background.lua only ever publishes running=true, so
      -- there's nothing to distinguish "replay of an old true" from "fresh
      -- true" other than this timestamp, updated every time either way.
      if running then widget.taskStatusAt = os.clock() end
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
      requestThemeReload(widget, true)
    end
    bus.subscribe("settings.update", widget.settingsHandler)
  end

  -- Skip the rest -- expensive per-tick prep/paint-adjacent work -- while
  -- a different screen is actually on the display: either this tool's own
  -- full-screen app/menu (appRunning) or simply some other Ethos screen
  -- (lcd.isVisible() false). Matches master's dashboard.wakeup() early
  -- return; see appRunning's own comment above.
  if appRunning or not lcd.isVisible() then return end
  handleDashboardResize(widget)

  if widget.pendingResetFlight then
    widget.pendingResetFlight = false
    applyResetFlight(widget)
  end

  -- Auto-prompt the battery-profile chooser once per connection, matching
  -- master's own showBatteryTypeStartup behavior -- gated on the Settings
  -- > General > Integration toggle, and only actually opened when more
  -- than one profile is configured (a single-profile craft has nothing to
  -- choose, same as the toolbar's own battery icon staying disabled --
  -- see isToolbarItemEnabled()'s requiresBatteryProfiles check). Waits for
  -- widget.batteryConfig to have actually arrived (async, via
  -- session.update) rather than firing the instant `connected` flips true,
  -- and latches batteryDialogShown so it only ever fires once per
  -- connection -- reset on disconnect above.
  if widget.connected == true
      and not widget.batteryDialogShown
      and widget.batteryConfig
      and settingsStore.batteryProfileStartupEnabled(widget.settingsSnapshot) then
    widget.batteryDialogShown = true
    if hasSelectableBatteryProfiles(widget) then
      chooseBatteryProfile(widget)
    end
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
      requestThemeReload(widget)
    end
  end

  local forcePaintRetry = widget.dashboardPaintRetryPending == true
  if forcePaintRetry then
    widget.needsPaint = true
  end

  if widget.needsPaint then
    widget.needsPaint = false
    local prepared = prepareDashboard(widget)
    if widget.themeReloadPending == true and prepared then finishThemeReload(widget) end
    if prepared == false then widget.needsPaint = true end
    if forcePaintRetry then
      invalidateWidgetGlobal(widget)
    else
      invalidateWidget(widget)
    end
  end

  if widget.toolbarVisible then
    local now = clock()
    if widget.toolbarLastActive == 0 then widget.toolbarLastActive = now end
    if TOOLBAR_TIMEOUT > 0 and (now - widget.toolbarLastActive) >= TOOLBAR_TIMEOUT then
      setToolbarVisible(widget, false)
      invalidateWidget(widget)
    end
  end

  if widget.dashboardEverPainted == true then
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
