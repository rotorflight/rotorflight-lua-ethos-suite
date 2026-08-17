-- Dashboard-to-configurator theme bridge for the current app architecture.
--
-- File-backed settings, model overrides, and optional user-theme metadata are
-- resolved from the throttled wakeup path. paintBackground()/paintChrome()
-- only consume precompiled colors and flat geometry arrays; they perform no
-- file I/O and allocate no per-frame tables. Native ETHOS edit fields remain
-- native controls -- this module styles only the canvas, titles, rails, and
-- registered menu/navigation button chrome.

if package.loaded["rfsuite.app.theme_bridge"] then
  return package.loaded["rfsuite.app.theme_bridge"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local flightmode = requireModule("widgets/dashboard/flightmode.lua")
local modelPreferences = requireModule("lib/model_preferences.lua")
local paletteRegistry = requireModule("app/theme_palettes.lua")
local settingsStore = requireModule("lib/settings_store.lua")

local clock = os.clock
local floor = math.floor
local max = math.max
local min = math.min
local tonumber = tonumber
local type = type
local pcall = pcall

local lcdColor = lcd.color
local lcdDrawFilledRectangle = lcd.drawFilledRectangle
local lcdDrawRectangle = lcd.drawRectangle
local lcdGetWindowSize = lcd.getWindowSize
local lcdRGB = lcd.RGB

local bridge = {}
local tracker = flightmode.new()
local paletteCache = {}
local metadataCache = {}
local chromeRects = {}
local titleFields = {}
local railSegments = {}

local settings
local session
local modelDashboard
local loadedMcuId
local pendingSession
local pendingSettings
local modelLoadPending = false
local modelRetryAt = 0
local nextCheck = 0
local opened = false

local activeEnabled = true
local activePath
local activePhase = "preflight"
local activePalettePhase
local activeDark
local activeNativeSignature
local activePalette
local geometryDirty = true
local canvasWidth = 0
local canvasHeight = 0
local headerBottom = 0

local CHECK_INTERVAL = 0.50
local MODEL_RETRY_INTERVAL = 5.0
local NATIVE_SIGNATURE_INTERVAL = 1.0
local FADE_STEPS = 12
local GRADIENT_STEPS = 32

-- The separately maintained theme branches keep appTheme in their small
-- init.lua. Prefer that installed metadata so a theme author can edit their
-- own branch without also changing this bridge. Master's built-ins use the
-- registry directly: some of their init.lua files load the full dashboard
-- context and are too expensive to probe just for a palette.
local EDITABLE_THEME_METADATA = {
  aegis = true,
  america250 = true,
  libertyops250 = true,
  mwrc = true,
  singularity = true,
  zafira = true,
}

-- Keep selection behavior aligned with widgets/dashboard.lua. These themes
-- are always part of the current suite; separately maintained themes are
-- available only when their branch has installed a valid appTheme metadata
-- table. Unsupported and user paths must resolve to Default, just as the
-- dashboard does, so the configurator never claims to follow an absent theme.
local BUILTIN_DASHBOARD_THEMES = {
  ["aerc-n"] = true,
  aerc = true,
  claude = true,
  danielrc = true,
  default = true,
  gismo = true,
  helihud = true,
  kevd = true,
  rfstatus = true,
  ["rt-rc-n"] = true,
  ["rt-rc"] = true,
  ["srb-rc"] = true,
  timer = true,
}

local NATIVE_THEME_KEYS = {
  "THEME_PAGE_BGCOLOR",
  "THEME_PRIMARY_BGCOLOR",
  "THEME_SECONDARY_BGCOLOR",
  "THEME_DEFAULT_COLOR",
  "THEME_DISABLE_COLOR",
  "THEME_PRIMARY_COLOR",
  "THEME_FOCUS_COLOR",
  "THEME_WARNING_COLOR",
  "THEME_ERROR_COLOR",
  "THEME_BUTTON_BORDER_COLOR",
}
local nativeSignatureCache
local nativeSignatureDark
local nextNativeSignatureCheck = 0

local FALLBACK_DARK = {
  name = "ETHOS Dark",
  background = {20, 22, 26}, surface = {38, 41, 47}, surfaceAlt = {49, 53, 61},
  text = {238, 241, 245}, muted = {155, 162, 172}, accent = {61, 174, 255},
  focus = {83, 213, 133}, warning = {255, 181, 64}, error = {255, 86, 103}, border = {80, 88, 101},
}
local FALLBACK_LIGHT = {
  name = "ETHOS Light",
  background = {242, 244, 247}, surface = {255, 255, 255}, surfaceAlt = {229, 233, 239},
  text = {26, 31, 38}, muted = {92, 101, 113}, accent = {0, 112, 210},
  focus = {0, 145, 72}, warning = {190, 112, 0}, error = {205, 38, 58}, border = {158, 166, 177},
}

local function wipe(values)
  for key in pairs(values) do values[key] = nil end
end

local function darkMode()
  if type(lcd.darkMode) ~= "function" then return true end
  local ok, value = pcall(lcd.darkMode)
  return not ok or value == true
end

local function rgb(value, fallback)
  if type(value) == "number" then return value end
  if type(value) == "table" then
    local red = tonumber(value.r or value[1])
    local green = tonumber(value.g or value[2])
    local blue = tonumber(value.b or value[3])
    local alpha = tonumber(value.a or value[4]) or 1
    if red and green and blue then return lcdRGB(red, green, blue, alpha) end
  end
  return fallback
end

local function rgbComponents(value, fallback)
  if type(value) == "table" then
    local red = tonumber(value.r or value[1])
    local green = tonumber(value.g or value[2])
    local blue = tonumber(value.b or value[3])
    if red and green and blue then return {red, green, blue} end
  end
  if type(fallback) == "table" then
    return {tonumber(fallback[1]) or 0, tonumber(fallback[2]) or 0, tonumber(fallback[3]) or 0}
  end
  return {0, 0, 0}
end

local function nativeColor(constantName, fallback)
  local index = _G[constantName]
  if index ~= nil and type(lcd.themeColor) == "function" then
    local ok, value = pcall(lcd.themeColor, index)
    if ok and type(value) == "number" then return value end
  end
  return fallback
end

local function nativePalette(isDark)
  local source = isDark and FALLBACK_DARK or FALLBACK_LIGHT
  return {
    name = source.name,
    background = nativeColor("THEME_PAGE_BGCOLOR", rgb(source.background)),
    surface = nativeColor("THEME_PRIMARY_BGCOLOR", rgb(source.surface)),
    surfaceAlt = nativeColor("THEME_SECONDARY_BGCOLOR", rgb(source.surfaceAlt)),
    text = nativeColor("THEME_DEFAULT_COLOR", rgb(source.text)),
    muted = nativeColor("THEME_DISABLE_COLOR", rgb(source.muted)),
    accent = nativeColor("THEME_PRIMARY_COLOR", rgb(source.accent)),
    focus = nativeColor("THEME_FOCUS_COLOR", rgb(source.focus)),
    warning = nativeColor("THEME_WARNING_COLOR", rgb(source.warning)),
    error = nativeColor("THEME_ERROR_COLOR", rgb(source.error)),
    border = nativeColor("THEME_BUTTON_BORDER_COLOR", rgb(source.border)),
    _backgroundRGB = rgbComponents(source.background),
    _accentRGB = rgbComponents(source.accent),
    native = true,
  }
end

local function normalizeThemePath(value)
  if type(value) ~= "string" or value == "" or value == "nil" then return "system/default" end
  local source, folder = value:match("^([^/]+)/(.+)$")
  if source == "system" or source == "user" then
    if folder:sub(1, 1) == "@" then folder = folder:sub(2) end
    if folder ~= "" then return source .. "/" .. folder end
  end
  if value:sub(1, 1) == "@" then value = value:sub(2) end
  return "system/" .. value
end

local function phaseTheme(dashboard, phase)
  if type(dashboard) ~= "table" then return nil end
  local value
  if dashboard.use_same_theme == true or dashboard.use_same_theme == "true" then
    value = dashboard.theme_preflight or dashboard.theme
  else
    value = dashboard["theme_" .. phase] or dashboard.theme_preflight or dashboard.theme
  end
  if value == nil or value == "" or value == "nil" then return nil end
  return value
end

local function rawValue(raw, phaseRaw, key)
  if type(phaseRaw) == "table" and phaseRaw[key] ~= nil then return phaseRaw[key] end
  return type(raw) == "table" and raw[key] or nil
end

local function loadThemeMetadata(path, folder)
  local source = path:match("^([^/]+)/")
  local initPath
  if source == "user" then
    initPath = "SCRIPTS:/rfsuite.user/dashboard/" .. folder .. "/init.lua"
  else
    initPath = "widgets/dashboard/themes/" .. folder .. "/init.lua"
  end

  local okLoad, chunk = pcall(loadfile, initPath)
  if not okLoad or type(chunk) ~= "function" then return nil end
  local okRun, metadata = pcall(chunk)
  if not okRun or type(metadata) ~= "table" or type(metadata.appTheme) ~= "table" then return nil end
  local appTheme = metadata.appTheme
  if appTheme.name == nil and metadata.name ~= nil then appTheme.name = metadata.name end
  return appTheme
end

local function installedThemeMetadata(path, folder)
  local cached = metadataCache[path]
  if cached == nil then
    cached = loadThemeMetadata(path, folder) or false
    metadataCache[path] = cached
  end
  if cached ~= false then return cached end
  return nil
end

local function resolveThemeMetadata(path, folder)
  local registered = paletteRegistry.get(folder)
  if EDITABLE_THEME_METADATA[folder] == true then
    return installedThemeMetadata(path, folder) or registered
  end
  return registered
end

local function availableThemePath(path)
  local source, folder = path:match("^([^/]+)/(.+)$")
  if source ~= "system" or not folder then return "system/default" end
  if BUILTIN_DASHBOARD_THEMES[folder] then return path end
  if EDITABLE_THEME_METADATA[folder] and installedThemeMetadata(path, folder) then return path end
  return "system/default"
end

local function selectedThemePath(phase)
  local modelTheme = phaseTheme(modelDashboard, phase)
  if modelTheme then return availableThemePath(normalizeThemePath(modelTheme)) end
  local dashboard = settings and settings.dashboard
  return availableThemePath(normalizeThemePath(phaseTheme(dashboard, phase) or "system/default"))
end

local function nativeThemeSignature(now, isDark, force)
  if not force and nativeSignatureCache ~= nil and nativeSignatureDark == isDark and now < nextNativeSignatureCheck then
    return nativeSignatureCache
  end

  local signature = isDark and 5381 or 7919
  if type(lcd.themeColor) == "function" then
    for index = 1, #NATIVE_THEME_KEYS do
      local themeIndex = _G[NATIVE_THEME_KEYS[index]]
      if type(themeIndex) == "number" then
        local ok, color = pcall(lcd.themeColor, themeIndex)
        if ok and type(color) == "number" then
          signature = ((signature * 33) + (color % 2147483647)) % 2147483647
        end
      end
    end
  end
  nativeSignatureCache = signature
  nativeSignatureDark = isDark
  nextNativeSignatureCheck = now + NATIVE_SIGNATURE_INTERVAL
  return signature
end

local function compilePalette(path, phase, isDark, nativeSignature)
  local byPhase = paletteCache[path]
  if byPhase and byPhase[phase] and byPhase[phase][nativeSignature] then
    return byPhase[phase][nativeSignature]
  end

  local folder = path:match("^[^/]+/(.+)$") or "default"
  local raw = resolveThemeMetadata(path, folder)

  local native = nativePalette(isDark)
  local phaseRaw = type(raw) == "table" and raw[phase] or nil
  local palette
  if type(raw) == "table" and raw.native == true then
    palette = native
    palette.name = raw.name or native.name
  else
    local rail = rawValue(raw, phaseRaw, "rail")
    palette = {
      name = rawValue(raw, phaseRaw, "name") or native.name,
      background = rgb(rawValue(raw, phaseRaw, "background"), native.background),
      surface = rgb(rawValue(raw, phaseRaw, "surface"), native.surface),
      surfaceAlt = rgb(rawValue(raw, phaseRaw, "surfaceAlt"), native.surfaceAlt),
      text = rgb(rawValue(raw, phaseRaw, "text"), native.text),
      muted = rgb(rawValue(raw, phaseRaw, "muted"), native.muted),
      accent = rgb(rawValue(raw, phaseRaw, "accent"), native.accent),
      focus = rgb(rawValue(raw, phaseRaw, "focus"), native.focus),
      warning = rgb(rawValue(raw, phaseRaw, "warning"), native.warning),
      error = rgb(rawValue(raw, phaseRaw, "error"), native.error),
      border = rgb(rawValue(raw, phaseRaw, "border"), native.border),
      _backgroundRGB = rgbComponents(rawValue(raw, phaseRaw, "background"), native._backgroundRGB),
      _accentRGB = rgbComponents(rawValue(raw, phaseRaw, "accent"), native._accentRGB),
    }
    if type(rail) == "table" then
      local start = rail.start or rail[1]
      local middle = rail.middle or rail.mid or rail[2]
      local finish = rail.finish or rail[3]
      if start and middle and finish then
        palette._railStartRGB = rgbComponents(start, palette._accentRGB)
        palette._railMiddleRGB = rgbComponents(middle, palette._accentRGB)
        palette._railFinishRGB = rgbComponents(finish, palette._accentRGB)
      end
    end
  end

  palette.path = path
  palette.phase = phase
  byPhase = byPhase or {}
  paletteCache[path] = byPhase
  local byMode = byPhase[phase] or {}
  byPhase[phase] = byMode
  byMode[nativeSignature] = palette
  return palette
end

local function titleColor()
  if not activePalette then return nil end
  return activeEnabled and activePalette.accent or activePalette.text
end

local function applyTitles()
  local color = titleColor()
  if not color then return end
  for index = #titleFields, 1, -1 do
    local field = titleFields[index]
    if field and field.color then
      pcall(field.color, field, color)
    else
      table.remove(titleFields, index)
    end
  end
end

local function refreshPalette(force, now)
  now = now or clock()
  local phase = activePhase or "preflight"
  local path = selectedThemePath(phase)
  local isDark = darkMode()
  local nativeSignature = nativeThemeSignature(now, isDark, force)
  local enabled = settingsStore.followDashboardThemeEnabled(settings)
  if not force and path == activePath and phase == activePalettePhase and isDark == activeDark
      and nativeSignature == activeNativeSignature and enabled == activeEnabled and activePalette then
    return false
  end

  activeEnabled = enabled
  activePath = path
  activePalettePhase = phase
  activeDark = isDark
  activeNativeSignature = nativeSignature
  activePalette = enabled and compilePalette(path, phase, isDark, nativeSignature) or nativePalette(isDark)
  geometryDirty = true
  applyTitles()
  if lcd.invalidate then pcall(lcd.invalidate) end
  return true
end

local function blendColor(background, foreground, amount)
  amount = max(0, min(1, tonumber(amount) or 0))
  local inverse = 1 - amount
  return lcdRGB(
    floor((background[1] * inverse) + (foreground[1] * amount) + 0.5),
    floor((background[2] * inverse) + (foreground[2] * amount) + 0.5),
    floor((background[3] * inverse) + (foreground[3] * amount) + 0.5)
  )
end

local function appendSegment(x, y, width, height, color)
  local offset = #railSegments
  railSegments[offset + 1] = x
  railSegments[offset + 2] = y
  railSegments[offset + 3] = width
  railSegments[offset + 4] = height
  railSegments[offset + 5] = color
end

local function threeColor(startRGB, middleRGB, finishRGB, progress)
  if progress <= 0.5 then return blendColor(startRGB, middleRGB, progress * 2) end
  return blendColor(middleRGB, finishRGB, (progress - 0.5) * 2)
end

local function appendGradientRail(x, y, length, thickness, vertical, palette)
  if length <= 0 then return end
  local steps = min(GRADIENT_STEPS, max(12, length))
  for step = 1, steps do
    local startOffset = floor(((step - 1) * length) / steps)
    local endOffset = floor((step * length) / steps)
    local size = max(1, endOffset - startOffset)
    local progress = (step - 1) / max(1, steps - 1)
    local color = threeColor(palette._railStartRGB, palette._railMiddleRGB, palette._railFinishRGB, progress)
    if vertical then
      appendSegment(x, y + startOffset, thickness, size, color)
    else
      appendSegment(x + startOffset, y, size, thickness, color)
    end
  end
end

local function appendFadeRail(x, y, length, thickness, vertical, palette)
  if length <= 0 then return end
  local fadeLength = min(vertical and 84 or 96, max(24, floor(length / 5)))
  fadeLength = min(fadeLength, length)
  local segmentSize = max(1, floor(fadeLength / FADE_STEPS))
  local actualFade = min(length, segmentSize * FADE_STEPS)
  local body = max(0, length - actualFade)
  if body > 0 then
    if vertical then appendSegment(x, y, thickness, body, palette.accent)
    else appendSegment(x, y, body, thickness, palette.accent) end
  end
  for step = 1, FADE_STEPS do
    local progress = (step - 1) / max(1, FADE_STEPS - 1)
    local smooth = progress * progress * (3 - (2 * progress))
    local amount = 1 - smooth
    local offset = body + ((step - 1) * segmentSize)
    if offset < length and amount > 0.035 then
      local size = min(segmentSize, length - offset)
      local color = blendColor(palette._backgroundRGB, palette._accentRGB, amount)
      if vertical then appendSegment(x, y + offset, thickness, size, color)
      else appendSegment(x + offset, y, size, thickness, color) end
    end
  end
end

local function rebuildGeometry()
  wipe(railSegments)
  local width, height = lcdGetWindowSize()
  canvasWidth = floor(tonumber(width) or 0)
  canvasHeight = floor(tonumber(height) or 0)
  geometryDirty = false

  local palette = activePalette
  if not activeEnabled or not palette or canvasWidth <= 0 or canvasHeight <= 0 then return end
  local railY = min(canvasHeight - 2, max(0, floor(headerBottom + 2)))
  if palette._railStartRGB and palette._railMiddleRGB and palette._railFinishRGB then
    appendGradientRail(0, railY, canvasWidth, 2, false, palette)
    appendGradientRail(0, railY, max(0, canvasHeight - railY), 2, true, palette)
  else
    appendFadeRail(0, railY, canvasWidth, 2, false, palette)
    appendFadeRail(0, railY, max(0, canvasHeight - railY), 2, true, palette)
  end
end

local function updateFlightPhase(snapshot)
  if not snapshot then
    activePhase = "preflight"
    return
  end
  if snapshot.timerFlightCounted == true or (tonumber(snapshot.timerSession) or 0) > 0 then
    tracker.hasBeenInFlight = true
  end
  activePhase = tracker:update(snapshot)
end

local function applyPending(now)
  if pendingSettings then
    settings = pendingSettings
    pendingSettings = nil
    modelLoadPending = session and session.connected == true and session.mcuId ~= nil
  end

  if pendingSession then
    local nextSession = pendingSession
    pendingSession = nil
    local nextMcuId = nextSession.connected == true and nextSession.mcuId or nil
    if nextMcuId ~= loadedMcuId then
      if nextMcuId ~= nil then tracker:reset() end
      loadedMcuId = nextMcuId
      modelDashboard = nil
      modelLoadPending = nextMcuId ~= nil
      modelRetryAt = 0
    end
    session = nextSession
  end

  updateFlightPhase(session)

  if modelLoadPending and loadedMcuId and now >= modelRetryAt then
    modelLoadPending = false
    local ok, prefs = pcall(modelPreferences.load, loadedMcuId)
    if ok and type(prefs) == "table" then
      modelDashboard = prefs.dashboard
    else
      modelDashboard = nil
      modelLoadPending = true
      modelRetryAt = now + MODEL_RETRY_INTERVAL
    end
    -- Keep file-backed model loading and optional theme metadata loading on
    -- separate ticks to avoid exceeding ETHOS's instruction budget.
    nextCheck = now + CHECK_INTERVAL
    return true
  end
  return false
end

local function onSession(snapshot)
  if opened then pendingSession = snapshot or {} end
end

local function onSettings(snapshot)
  if not opened then return end
  pendingSettings = snapshot or {}
  nextCheck = 0
end

function bridge.open(initialSettings)
  if opened then bridge.clearCache() end
  opened = true
  tracker:reset()
  settings = initialSettings or settingsStore.load()
  activePhase = "preflight"
  activePath = nil
  activePalette = nil
  activeDark = nil
  loadedMcuId = nil
  modelDashboard = nil
  modelLoadPending = false
  pendingSession = nil
  pendingSettings = nil
  nextCheck = 0
  bus.subscribe("session.update", onSession)
  bus.subscribe("settings.update", onSettings)

  if pendingSession then
    session = pendingSession
    pendingSession = nil
    loadedMcuId = session.connected == true and session.mcuId or nil
    modelLoadPending = loadedMcuId ~= nil
    updateFlightPhase(session)
  end

  -- Use a cheap native palette while the root menu is being constructed.
  -- Optional custom-theme files are resolved later by the throttled wakeup,
  -- keeping file I/O out of both the create path and every paint frame.
  activeEnabled = settingsStore.followDashboardThemeEnabled(settings)
  activeDark = darkMode()
  activePalette = nativePalette(activeDark)
  rebuildGeometry()
end

function bridge.wakeup()
  if not opened then return end
  if geometryDirty then rebuildGeometry() end
  local now = clock()
  if now < nextCheck then return end
  nextCheck = now + CHECK_INTERVAL
  local loadedModel = applyPending(now)
  if not loadedModel then refreshPalette(false, now) end
  if geometryDirty then rebuildGeometry() end
end

function bridge.invalidate()
  activePath = nil
  nextCheck = 0
end

function bridge.clearPage()
  wipe(chromeRects)
  wipe(titleFields)
  headerBottom = 0
  geometryDirty = true
end

function bridge.registerHeaderRect(rect)
  if type(rect) ~= "table" then return end
  local bottom = floor((tonumber(rect.y) or 0) + (tonumber(rect.h) or 0))
  if bottom > headerBottom then headerBottom = bottom end
  geometryDirty = true
end

function bridge.registerChromeRect(rect, kind)
  if type(rect) ~= "table" then return end
  local offset = #chromeRects
  chromeRects[offset + 1] = floor(tonumber(rect.x) or 0)
  chromeRects[offset + 2] = floor(tonumber(rect.y) or 0)
  chromeRects[offset + 3] = floor(tonumber(rect.w) or 0)
  chromeRects[offset + 4] = floor(tonumber(rect.h) or 0)
  chromeRects[offset + 5] = kind == "tile" and 2 or 1
end

bridge.registerNavigationRect = bridge.registerChromeRect

function bridge.styleStaticText(field, role)
  if not field then return field end
  if role == "accent" then titleFields[#titleFields + 1] = field end
  local palette = activePalette
  local color = palette and (activeEnabled and palette[role or "text"] or palette.text) or nil
  if color and field.color then pcall(field.color, field, color) end
  return field
end

function bridge.paintBackground()
  if not activeEnabled or not activePalette or canvasWidth <= 0 or canvasHeight <= 0 then return end
  lcdColor(activePalette.background)
  lcdDrawFilledRectangle(0, 0, canvasWidth, canvasHeight)
end

function bridge.paintChrome()
  if not activeEnabled or not activePalette then return end
  for index = 1, #railSegments, 5 do
    lcdColor(railSegments[index + 4])
    lcdDrawFilledRectangle(railSegments[index], railSegments[index + 1], railSegments[index + 2], railSegments[index + 3])
  end

  local palette = activePalette
  for index = 1, #chromeRects, 5 do
    local x = chromeRects[index]
    local y = chromeRects[index + 1]
    local width = chromeRects[index + 2]
    local height = chromeRects[index + 3]
    local kind = chromeRects[index + 4]
    if width > 4 and height > 4 then
      lcdColor(palette.border)
      lcdDrawRectangle(x, y, width, height, 1)
      lcdColor(palette.accent)
      local inset = kind == 2 and 3 or 2
      lcdDrawFilledRectangle(x + inset, y + height - 3, max(1, width - (inset * 2)), 2)
    end
  end
end

function bridge.getPalette()
  return activePalette
end

function bridge.clearCache()
  if opened then
    bus.unsubscribe("session.update", onSession)
    bus.unsubscribe("settings.update", onSettings)
  end
  opened = false
  wipe(paletteCache)
  wipe(metadataCache)
  bridge.clearPage()
  wipe(railSegments)
  tracker:reset()
  settings = nil
  session = nil
  modelDashboard = nil
  loadedMcuId = nil
  pendingSession = nil
  pendingSettings = nil
  modelLoadPending = false
  modelRetryAt = 0
  nextCheck = 0
  activeEnabled = true
  activePath = nil
  activePhase = "preflight"
  activePalettePhase = nil
  activeDark = nil
  activeNativeSignature = nil
  activePalette = nil
  canvasWidth = 0
  canvasHeight = 0
  headerBottom = 0
  geometryDirty = true
  nativeSignatureCache = nil
  nativeSignatureDark = nil
  nextNativeSignatureCheck = 0
end

package.loaded["rfsuite.app.theme_bridge"] = bridge
return bridge
