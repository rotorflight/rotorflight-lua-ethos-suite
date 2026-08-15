-- Compatibility context for dashboard theme folders.
--
-- This intentionally exposes only the small surface old-style dashboard theme
-- files need. It is cached because copied theme files load it independently.

local cached = package.loaded["rfsuite.dashboard.context"]
if cached then return cached end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local buildInfo = requireModule("lib/build_info.lua")
local ethosVersion = requireModule("lib/ethos_version.lua")

local context = {
  config = {
    baseDir = "rfsuite",
    preferences = "rfsuite.user",
    version = buildInfo.version,
  },
  session = {
    modelPreferences = {},
    timer = {live = 0},
    isConnected = false,
    isArmed = false,
  },
  preferences = {
    general = {},
    dashboard = {},
    developer = {},
  },
  flightmode = {
    current = "preflight",
  },
  tasks = {
    telemetry = {},
  },
  ini = {},
  utils = {},
  widgets = {
    dashboard = {
      renders = {},
    },
  },
}

local currentWidget = nil

local function rgb(r, g, b)
  return lcd.RGB and lcd.RGB(r, g, b, 1) or nil
end

local utils = {}
local dashboardPrefs = {}
local tempThresholdCache = setmetatable({}, {__mode = "k"})
local fmtCache = {}
local paletteCache = {}
local themeStateCache = {}
local themePaletteCache = {}
local systemThemeSupport = nil
local imageCache = {}
local imagePathCache = {}
local imageBitmapCache = {}
local liveSourceCache = {}
local liveMissRetryAt = {}
local liveMissCount = {}
local liveRevalidateAt = {}
-- Same fix as lib/telemetry_sensors.lua's own MISS_RETRY_INITIAL/_MAX: a flat
-- 5s lockout from the first miss meant a box whose sensor simply hadn't
-- broadcast yet (common right after connect) stayed blank for up to 5s
-- rather than the fraction of a second it actually took to start
-- broadcasting. Exponential backoff keeps the same eventual 5s cap for a
-- sensor that's genuinely absent on this build, while resolving a merely-late
-- one much sooner.
local LIVE_MISS_RETRY_INITIAL = 0.5
local LIVE_MISS_RETRY_MAX = 5.0
local LIVE_MISS_RETRY_MULTIPLIER = 2
-- Same fix as lib/telemetry_sensors.lua's own REVALIDATE_INTERVAL, ported
-- here after noticing this cache never got it: liveSensorSource() picks the
-- *first* candidate that resolves and, unlike the miss path above, kept it
-- forever with no way back through the candidate list. If that first hit is
-- a stale/unwired duplicate sensor slot -- or one Ethos discovered before it
-- ever carried a real reading -- the box using it (e.g. the header's rssi
-- step-gauge) gets stuck showing that slot's value (often 0/nil) for the
-- rest of the session, exactly the "populates once, then stops updating"
-- symptom lib/telemetry_sensors.lua's own comment describes. Re-running the
-- scan every LIVE_REVALIDATE_INTERVAL seconds gives a better candidate that
-- shows up later a chance to take over, without rescanning every wakeup.
local LIVE_REVALIDATE_INTERVAL = 8.0
local DASHBOARD_RESOLUTION_TOLERANCE = 12
local DASHBOARD_SUPPORTED_RESOLUTIONS = {
  {784, 294}, {784, 316}, {800, 458}, {800, 480},
  {472, 191}, {472, 210}, {480, 301}, {480, 320},
  {630, 236}, {630, 258}, {640, 338}, {640, 360},
}
local DASHBOARD_THEME_WIDTHS = {800, 784, 640, 630, 480, 472}
local ETHOS_THEME_MIN_VERSION = {26, 1, 0}
local LOGO_DARK_FALLBACK = "widgets/dashboard/gfx/logo-dark.png"
local LOGO_LIGHT_FALLBACK = "widgets/dashboard/gfx/logo-light.png"
local FONT_LISTS_BY_RESOLUTION = {
  ["800x480"] = {value_default = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL, FONT_XXXXL}, value_reduced = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L}, value_title = {FONT_XXS, FONT_XS, FONT_S, FONT_STD}},
  ["480x320"] = {value_default = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL}, value_reduced = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L}, value_title = {FONT_XXS, FONT_XS, FONT_S}},
  ["480x272"] = {value_default = {FONT_XXS, FONT_XS, FONT_S, FONT_STD}, value_reduced = {FONT_XXS, FONT_XS, FONT_S}, value_title = {FONT_XXS, FONT_XS, FONT_S}},
  ["640x360"] = {value_default = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL}, value_reduced = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L}, value_title = {FONT_XXS, FONT_XS, FONT_S}},
}
local DEFAULT_FONT_LISTS = {value_default = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL, FONT_XXXXL}, value_reduced = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L}, value_title = {FONT_XXS, FONT_XS, FONT_S, FONT_STD}}
local THEME_STATE_KEYS = {
  {"defaultColor", "THEME_DEFAULT_COLOR"},
  {"defaultBgColor", "THEME_DEFAULT_BGCOLOR"},
  {"focusBgColor", "THEME_FOCUS_BGCOLOR"},
  {"focusColor", "THEME_FOCUS_COLOR"},
  {"primaryColor", "THEME_PRIMARY_COLOR"},
  {"primaryBgColor", "THEME_PRIMARY_BGCOLOR"},
  {"secondaryColor", "THEME_SECONDARY_COLOR"},
  {"secondaryBgColor", "THEME_SECONDARY_BGCOLOR"},
  {"highlightColor", "THEME_HIGHLIGHT_COLOR"},
  {"highlightInvertColor", "THEME_HIGHLIGHT_CONTRASTING_COLOR"},
  {"disableColor", "THEME_DISABLE_COLOR"},
  {"errorColor", "THEME_ERROR_COLOR"},
  {"warningColor", "THEME_WARNING_COLOR"},
  {"activeColor", "THEME_ACTIVE_COLOR"},
  {"inactiveColor", "THEME_INACTIVE_COLOR"},
  {"buttonBorderActiveColor", "THEME_BUTTON_BORDER_ACTIVE_COLOR"},
  {"buttonBorderColor", "THEME_BUTTON_BORDER_COLOR"},
  {"safeColor", "THEME_SAFE_COLOR"},
  {"safeContrastingColor", "THEME_SAFE_CONTRASTING_COLOR"},
  {"pageBgColor", "THEME_PAGE_BGCOLOR"},
}
local LIVE_SENSOR_CANDIDATES = {
  sport = {
    rssi = {
      {appId = 0xF010, subId = 0},
    },
    voltage = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0210},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0211},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0218},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x021A},
    },
    consumption = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5250},
    },
    current = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0200},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0208},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0201},
    },
    throttle_percent = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5440},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x51A4},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5269},
    },
    rpm = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0500},
    },
    tailspeed = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0501},
    },
    link = {
      {appId = 0xF101, subId = 0},
      "RSSI",
    },
    vfr = {
      {appId = 0xF010, subId = 0},
    },
    smartfuel = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0600},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE1},
    },
    temp_esc = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0401},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0418},
    },
    temp_mcu = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0400},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0401},
    },
    bec_voltage = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0901},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0219},
    },
    altitude = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0100},
    },
  },
  crsf = {
    -- subId=2 is the dedicated Link Quality field on firmware that broadcasts
    -- Rotorflight's newer CRSF telemetry frame (probed pre-rewrite via a
    -- 0xEE01 marker sensor -- see tasks/scheduler/telemetry/telemetry.lua's
    -- detectSourceMode() in the pre-rewrite tree). Older firmware without
    -- that marker never exposed subId=2 at all and instead used this
    -- subIdStart/subIdEnd range (see that same tree's
    -- sources/crsf_legacy.lua), which is what "link" below also uses as its
    -- structured candidate. Kept as a plain fallback here rather than fully
    -- reviving the old two-table firmware-format split: it stops rssi being
    -- permanently stuck on nil for old-firmware users, though the range's
    -- value is raw antenna RSSI rather than a true 0-100 LQ%, so it may not
    -- land on this box's step gauge as cleanly as subId=2 does.
    rssi = {
      {crsfId = 0x14, subId = 2},
      {crsfId = 0x14, subIdStart = 0, subIdEnd = 1},
    },
    voltage = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1011},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1041},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1051},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1080},
    },
    consumption = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1013},
    },
    current = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1012},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1042},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x104A},
    },
    throttle_percent = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1035},
    },
    rpm = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10C0},
    },
    tailspeed = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10C1},
    },
    link = {
      {crsfId = 0x14, subIdStart = 0, subIdEnd = 1},
      "Rx RSSI1",
    },
    -- Same rssi/subId=2 fallback reasoning as above -- vfr mirrors rssi
    -- one-for-one in this table (see sensorValue()'s `name == "rssi" or
    -- name == "vfr"` branch, which already treats them identically).
    vfr = {
      {crsfId = 0x14, subId = 2},
      {crsfId = 0x14, subIdStart = 0, subIdEnd = 1},
    },
    smartfuel = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1014},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE1},
    },
    temp_esc = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A0},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1047},
    },
    temp_mcu = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A3},
    },
    bec_voltage = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1081},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1049},
    },
    altitude = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10B2},
    },
  },
}

local NAMED_COLORS = {
  red = {255, 0, 0},
  green = {0, 188, 4},
  blue = {0, 122, 255},
  white = {255, 255, 255},
  black = {0, 0, 0},
  gray = {185, 185, 185},
  grey = {185, 185, 185},
  orange = {255, 165, 0},
  yellow = {255, 255, 0},
  cyan = {0, 255, 255},
  magenta = {255, 0, 255},
  pink = {255, 105, 180},
  purple = {128, 0, 128},
  violet = {143, 0, 255},
  brown = {139, 69, 19},
  lime = {0, 255, 0},
  olive = {128, 128, 0},
  gold = {255, 215, 0},
  silver = {192, 192, 192},
  teal = {0, 128, 128},
  navy = {0, 0, 128},
  maroon = {128, 0, 0},
  beige = {245, 245, 220},
  turquoise = {64, 224, 208},
  indigo = {75, 0, 130},
  coral = {255, 127, 80},
  salmon = {250, 128, 114},
  mint = {62, 180, 137},
  lightgreen = {144, 238, 144},
  darkgreen = {0, 100, 0},
  lightred = {255, 102, 102},
  darkred = {139, 0, 0},
  lightorange = {255, 200, 100},
  lightblue = {173, 216, 230},
  darkblue = {0, 0, 139},
  lightpurple = {216, 191, 216},
  darkpurple = {48, 25, 52},
  lightyellow = {255, 255, 224},
  darkyellow = {204, 204, 0},
  lightgrey = {211, 211, 211},
  lightgray = {211, 211, 211},
  darkgrey = {90, 90, 90},
  darkgray = {90, 90, 90},
  lmgrey = {80, 80, 80},
  darkwhite = {245, 245, 245},
  headergrey = {35, 35, 35},
  bggrey = {40, 40, 40},
  bgdarkgrey = {25, 25, 25},
  bglines = {65, 65, 65},
}

local function clampColorByte(value)
  value = math.floor((tonumber(value) or 0) + 0.5)
  if value < 0 then return 0 end
  if value > 255 then return 255 end
  return value
end

local function colorVariant(base, prefix)
  local factor = 0.3
  if prefix == "dark" then
    return rgb(clampColorByte(base[1] * (1 - factor)), clampColorByte(base[2] * (1 - factor)), clampColorByte(base[3] * (1 - factor)))
  end
  return rgb(clampColorByte(base[1] + (255 - base[1]) * factor), clampColorByte(base[2] + (255 - base[2]) * factor), clampColorByte(base[3] + (255 - base[3]) * factor))
end

local function legacyDark()
  return type(lcd.darkMode) == "function" and lcd.darkMode() == true
end

local function legacyPalette()
  local cacheKey = legacyDark() and "dark" or "light"
  if paletteCache[cacheKey] then return paletteCache[cacheKey] end
  local palette
  if legacyDark() then
    palette = {
      textcolor = rgb(255, 255, 255),
      titlecolor = rgb(255, 255, 255),
      bgcolor = rgb(0, 0, 0),
      fillcolor = rgb(0, 188, 4),
      fillwarncolor = rgb(255, 165, 0),
      fillcritcolor = rgb(255, 0, 0),
      fillbgcolor = rgb(185, 185, 185),
      accentcolor = rgb(255, 255, 255),
      rssifillcolor = rgb(0, 188, 4),
      rssifillbgcolor = rgb(90, 90, 90),
      txaccentcolor = rgb(185, 185, 185),
      txfillcolor = rgb(0, 188, 4),
      txbgfillcolor = rgb(90, 90, 90),
      tbbgcolor = rgb(35, 35, 35),
      cntextcolor = rgb(255, 255, 255),
      tbtextcolor = rgb(255, 255, 255),
      rssitextcolor = rgb(255, 255, 255),
      panelbg = rgb(40, 40, 40),
      paneldarkbg = rgb(25, 25, 25),
      panelbgline = rgb(65, 65, 65),
    }
    paletteCache[cacheKey] = palette
    return palette
  end

  palette = {
    textcolor = rgb(80, 80, 80),
    titlecolor = rgb(80, 80, 80),
    bgcolor = rgb(255, 255, 255),
    fillcolor = rgb(144, 238, 144),
    fillwarncolor = rgb(255, 200, 100),
    fillcritcolor = rgb(255, 102, 102),
    fillbgcolor = rgb(211, 211, 211),
    accentcolor = rgb(90, 90, 90),
    rssifillcolor = rgb(144, 238, 144),
    rssifillbgcolor = rgb(185, 185, 185),
    txaccentcolor = rgb(255, 255, 255),
    txfillcolor = rgb(144, 238, 144),
    txbgfillcolor = rgb(185, 185, 185),
    tbbgcolor = rgb(90, 90, 90),
    cntextcolor = rgb(255, 255, 255),
    tbtextcolor = rgb(255, 255, 255),
    rssitextcolor = rgb(255, 255, 255),
    panelbg = rgb(90, 90, 90),
    paneldarkbg = rgb(185, 185, 185),
    panelbgline = rgb(80, 80, 80),
  }
  paletteCache[cacheKey] = palette
  return palette
end

local function supportsSystemThemeColors()
  if systemThemeSupport ~= nil then return systemThemeSupport end
  systemThemeSupport = type(lcd.themeColor) == "function" and ethosVersion.atLeast(ETHOS_THEME_MIN_VERSION)
  return systemThemeSupport
end

local function resolveThemeConstant(name)
  if not supportsSystemThemeColors() then return nil end
  local key = _G and _G[name]
  if type(key) ~= "number" then return nil end
  return lcd.themeColor(key)
end

local THEME_COLOR_SIGNATURE_REFRESH_INTERVAL = 1.0
local themeColorSignatureCache = {value = nil, checkedAt = -math.huge}

local function buildThemeColorSignature()
  if not supportsSystemThemeColors() then return legacyDark() and "dark" or "light" end

  -- getThemeStateInternal() calls this on *every* call just to check
  -- whether its cache is still valid, not only when something changed --
  -- so hashing every theme constant here unconditionally (a `lcd.themeColor()`
  -- call per THEME_STATE_KEYS entry) turned a formerly-O(1) check into real,
  -- frequent-enough cost to trip Ethos's Lua instruction-count limit.
  -- Throttle the expensive part instead: reuse the last hash for up to
  -- THEME_COLOR_SIGNATURE_REFRESH_INTERVAL seconds. A live theme switch is
  -- still picked up within ~1s, which is effectively instant to a user, at
  -- a tiny fraction of the cost of hashing on every call.
  local now = os.clock()
  if themeColorSignatureCache.value and (now - themeColorSignatureCache.checkedAt) < THEME_COLOR_SIGNATURE_REFRESH_INTERVAL then
    return themeColorSignatureCache.value
  end

  local signature = 5381
  local hasAnyThemeColor = false
  for i = 1, #THEME_STATE_KEYS do
    local color = resolveThemeConstant(THEME_STATE_KEYS[i][2])
    if type(color) == "number" then
      signature = ((signature * 33) + (color % 2147483647)) % 2147483647
      hasAnyThemeColor = true
    end
  end

  local result = hasAnyThemeColor and ("ethos:" .. tostring(signature)) or (legacyDark() and "dark" or "light")
  themeColorSignatureCache.value = result
  themeColorSignatureCache.checkedAt = now
  return result
end

local function colorLuma(color)
  if type(color) ~= "number" then return nil end
  color = math.floor(color)
  if color < 0 then return nil end

  local r, g, b
  if color > 0xFFFFFF then
    local high = (color >> 24) & 0xFF
    local low = color & 0xFF
    if (low == 0 or low == 1 or low == 255) and high ~= 0 and high ~= 1 and high ~= 255 then
      r = high
      g = (color >> 16) & 0xFF
      b = (color >> 8) & 0xFF
    else
      r = (color >> 16) & 0xFF
      g = (color >> 8) & 0xFF
      b = low
    end
  elseif color > 0xFFFF then
    r = (color >> 16) & 0xFF
    g = (color >> 8) & 0xFF
    b = color & 0xFF
  else
    r = ((color >> 11) & 0x1F) * 255 / 31
    g = ((color >> 5) & 0x3F) * 255 / 63
    b = (color & 0x1F) * 255 / 31
  end

  return r * 0.299 + g * 0.587 + b * 0.114
end

local function buildLegacyThemeState(width, height)
  local palette = legacyPalette()
  return {
    width = width,
    height = height,
    flightmode = context.flightmode.current,
    usesThemeColors = false,
    defaultColor = legacyDark() and rgb(255, 255, 255) or rgb(90, 90, 90),
    defaultBgColor = legacyDark() and rgb(35, 35, 35) or rgb(230, 230, 230),
    primaryColor = palette.textcolor,
    primaryBgColor = palette.bgcolor,
    secondaryColor = palette.titlecolor,
    secondaryBgColor = palette.fillbgcolor,
    focusColor = legacyDark() and rgb(255, 255, 255) or rgb(0, 0, 0),
    focusBgColor = legacyDark() and rgb(40, 40, 40) or rgb(230, 230, 230),
    highlightColor = legacyDark() and palette.fillcolor or rgb(144, 238, 144),
    highlightInvertColor = legacyDark() and rgb(0, 0, 0) or rgb(255, 255, 255),
    disableColor = legacyDark() and rgb(112, 112, 112) or rgb(144, 144, 144),
    safeColor = palette.fillcolor,
    safeContrastingColor = legacyDark() and rgb(0, 0, 0) or rgb(255, 255, 255),
    warningColor = palette.fillwarncolor,
    errorColor = palette.fillcritcolor,
    activeColor = palette.fillcolor,
    inactiveColor = palette.fillcritcolor,
    buttonBorderActiveColor = palette.txaccentcolor,
    buttonBorderColor = palette.rssifillbgcolor,
    pageBgColor = legacyDark() and (rgb(16, 16, 16) or palette.bgcolor) or (rgb(209, 208, 208) or palette.bgcolor),
  }
end

local function getThemeStateInternal()
  local w, h = lcd.getWindowSize()
  local signature = tostring(w) .. "x" .. tostring(h) .. ":" .. tostring(context.flightmode.current or "") .. ":" .. buildThemeColorSignature()
  if themeStateCache.signature == signature and themeStateCache.state then return themeStateCache.state, signature end

  local state = buildLegacyThemeState(w, h)
  if supportsSystemThemeColors() then
    local hasAnyThemeColor = false
    for i = 1, #THEME_STATE_KEYS do
      local fieldName = THEME_STATE_KEYS[i][1]
      local color = resolveThemeConstant(THEME_STATE_KEYS[i][2])
      if type(color) == "number" then
        state[fieldName] = color
        hasAnyThemeColor = true
      end
    end
    state.usesThemeColors = hasAnyThemeColor
  end

  themeStateCache.signature = signature
  themeStateCache.state = state
  return state, signature
end

local function resolveDashboardSurfaceBg(state)
  return state and (state.primaryBgColor or state.pageBgColor or state.secondaryBgColor or state.defaultBgColor)
end

local function resolveDashboardHeaderBg(state, surfaceBg)
  if not state then return nil end
  local bg = state.pageBgColor or surfaceBg
  -- pageBgColor and the surface it sits on can resolve to the same color on
  -- some Ethos system themes, which would make the header/tile fill
  -- invisible against its own background. Same collision guard as
  -- resolveGaugeTrackBg below.
  if bg == surfaceBg then return state.secondaryBgColor or state.disableColor or bg end
  return bg
end

local function resolveDashboardHeaderTextColor(state)
  return state and (state.primaryColor or state.defaultColor)
end

local function resolveDashboardTitleColor(state)
  return state and (state.secondaryColor or state.primaryColor or state.defaultColor)
end

local function resolveDashboardPanelColors(state, surfaceBg)
  if not state then return nil, nil, nil end
  local panelBg = state.pageBgColor
  if panelBg == surfaceBg then panelBg = state.secondaryBgColor or state.disableColor or panelBg end
  return panelBg, state.secondaryBgColor, panelBg
end

local function resolveGaugeTrackBg(state, background)
  if not state then return background end
  if background == state.pageBgColor then return state.disableColor or state.secondaryBgColor end
  return state.secondaryBgColor or state.disableColor or background
end

local function resolveGaugeThresholdPalette(state)
  local fillcolor = state.safeColor or state.activeColor or state.highlightColor or rgb(0, 188, 4)
  local fillwarncolor = state.warningColor or rgb(255, 170, 0)
  local fillcritcolor = state.errorColor or state.inactiveColor or rgb(224, 64, 64)
  return fillcolor, fillwarncolor, fillcritcolor
end

local function logoFallbackForBackground(bgcolor)
  local luma = colorLuma(bgcolor)
  local useDarkLogo
  if luma then
    useDarkLogo = luma > 127
  else
    useDarkLogo = not legacyDark()
  end
  return useDarkLogo and LOGO_DARK_FALLBACK or LOGO_LIGHT_FALLBACK
end

local function closestDashboardResolution(width, height, supported)
  local bestRes, bestDistance
  local resolutions = supported or DASHBOARD_SUPPORTED_RESOLUTIONS
  for _, res in ipairs(resolutions) do
    local distance = math.abs(width - res[1]) + math.abs(height - res[2])
    if bestDistance == nil or distance < bestDistance then
      bestRes = res
      bestDistance = distance
    end
  end
  return bestRes, bestDistance
end

local function closestDashboardWidth(width)
  local bestWidth, bestDistance
  for i = 1, #DASHBOARD_THEME_WIDTHS do
    local candidate = DASHBOARD_THEME_WIDTHS[i]
    local distance = math.abs(width - candidate)
    if bestDistance == nil or distance < bestDistance then
      bestWidth = candidate
      bestDistance = distance
    end
  end
  return bestWidth
end

local GOVERNOR_LABELS = {
  [0] = "OFF",
  [1] = "IDLE",
  [2] = "SPOOLUP",
  [3] = "RECOVERY",
  [4] = "ACTIVE",
  [5] = "THR OFF",
  [6] = "LOST HS",
  [7] = "AUTOROT",
  [8] = "BAILOUT",
  [100] = "DISABLED",
  [101] = "DISARMED",
}

local function normalizeLiveSensorName(name)
  if name == "headspeed" then return "rpm" end
  return name
end

local function liveProtocol()
  local protocol = currentWidget and currentWidget.mspTransport
  if protocol == "sport" or protocol == "crsf" then return protocol end
  return nil
end

local function liveSensorSource(protocol, name)
  protocol = protocol or liveProtocol()
  name = normalizeLiveSensorName(name)
  if not protocol or not name then return nil end

  local byProtocol = liveSourceCache[protocol]
  if not byProtocol then
    byProtocol = {}
    liveSourceCache[protocol] = byProtocol
  end

  local now = os.clock()
  local source = byProtocol[name]
  if source then
    local revalidate = liveRevalidateAt[protocol]
    local dueAt = revalidate and revalidate[name]
    if not dueAt or now < dueAt then return source end
    -- Due for a recheck: fall through and re-scan candidates instead of
    -- trusting this cached source forever (see LIVE_REVALIDATE_INTERVAL's
    -- comment above).
    byProtocol[name] = nil
    source = nil
  end

  local misses = liveMissRetryAt[protocol]
  if misses and misses[name] and now < misses[name] then return nil end

  local candidates = LIVE_SENSOR_CANDIDATES[protocol] and LIVE_SENSOR_CANDIDATES[protocol][name]
  if not candidates then return nil end
  for i = 1, #candidates do
    source = system.getSource(candidates[i])
    if source then
      byProtocol[name] = source
      if misses then misses[name] = nil end
      local missCounts = liveMissCount[protocol]
      if missCounts then missCounts[name] = nil end
      local revalidate = liveRevalidateAt[protocol]
      if not revalidate then
        revalidate = {}
        liveRevalidateAt[protocol] = revalidate
      end
      revalidate[name] = now + LIVE_REVALIDATE_INTERVAL
      return source
    end
  end

  if not misses then
    misses = {}
    liveMissRetryAt[protocol] = misses
  end
  local missCounts = liveMissCount[protocol]
  if not missCounts then
    missCounts = {}
    liveMissCount[protocol] = missCounts
  end
  local count = (missCounts[name] or 0) + 1
  missCounts[name] = count
  local interval = math.min(LIVE_MISS_RETRY_INITIAL * (LIVE_MISS_RETRY_MULTIPLIER ^ (count - 1)), LIVE_MISS_RETRY_MAX)
  misses[name] = now + interval
  return nil
end

local function liveSensorValue(name)
  local source = liveSensorSource(nil, name)
  if not source then return nil end
  if source.state and source:state() == false then return nil end
  return source:value()
end

local function temperatureUnit()
  local general = context.preferences and context.preferences.general
  return tonumber(general and general.temperature_unit) == 1 and 1 or 0
end

local function temperatureUnitString(unit)
  if unit == nil then unit = temperatureUnit() end
  return unit == 1 and "°F" or "°C"
end

local function convertTemperature(value, unit)
  if value == nil then return nil end
  if unit == nil then unit = temperatureUnit() end
  if unit == 1 then return value * 1.8 + 32 end
  return value
end

local function convertTemperatureThresholds(thresholds, unit)
  if type(thresholds) ~= "table" then return thresholds end
  unit = unit or temperatureUnit()
  if unit ~= 1 then return thresholds end

  local cached = tempThresholdCache[thresholds]
  if cached then return cached end

  cached = {}
  for i = 1, #thresholds do
    local threshold = thresholds[i]
    if type(threshold) == "table" then
      local converted = {}
      for key, value in pairs(threshold) do
        converted[key] = key == "value" and convertTemperature(value, unit) or value
      end
      cached[i] = converted
    else
      cached[i] = threshold
    end
  end
  tempThresholdCache[thresholds] = cached
  return cached
end

local function temperaturePresentation(value, minValue, maxValue, thresholds)
  local unit = temperatureUnit()
  return convertTemperature(value, unit), temperatureUnitString(unit), convertTemperature(minValue, unit),
    convertTemperature(maxValue, unit), convertTemperatureThresholds(thresholds, unit)
end

local function localizeTemperature(value, minValue, maxValue, thresholds)
  local convertedValue, unit, convertedMin, convertedMax, convertedThresholds = temperaturePresentation(value, minValue, maxValue, thresholds)
  return convertedValue, nil, unit, convertedMin, convertedMax, convertedThresholds
end

local function roundSigned(value)
  if value >= 0 then return math.floor(value + 0.5) end
  return -math.floor(-value + 0.5)
end

local function updateMinMax(stats, minKey, maxKey, value)
  value = tonumber(value)
  if value == nil then return end
  if stats[minKey] == nil or value < stats[minKey] then stats[minKey] = value end
  if stats[maxKey] == nil or value > stats[maxKey] then stats[maxKey] = value end
end

local STAT_SUFFIXES = {
  rssi = "Rssi",
  link = "Link",
  vfr = "Vfr",
  voltage = "Voltage",
  cell_voltage = "CellVoltage",
  consumption = "Consumption",
  smartconsumption = "Consumption",
  current = "Current",
  throttle_percent = "ThrottlePercent",
  rpm = "Rpm",
  headspeed = "Rpm",
  tailspeed = "Tailspeed",
  smartfuel = "FuelPercent",
  fuel = "FuelPercent",
  temp_mcu = "TempMcu",
  temp_esc = "TempEsc",
  bec_voltage = "BecVoltage",
  altitude = "Altitude",
  watts = "Watts",
}

local STAT_ALIASES = {
  headspeed = "rpm",
  smartconsumption = "consumption",
  fuel = "smartfuel",
}

local PRESENTATION_STAT_SOURCES = {
  "voltage",
  "cell_voltage",
  "current",
  "consumption",
  "smartconsumption",
  "throttle_percent",
  "rpm",
  "headspeed",
  "tailspeed",
  "link",
  "rssi",
  "vfr",
  "smartfuel",
  "fuel",
  "temp_mcu",
  "temp_esc",
  "bec_voltage",
  "altitude",
  "watts",
}

local function statKey(name)
  return STAT_ALIASES[name or ""] or name
end

local function recordSensorStat(name, value)
  local widget = currentWidget
  if not widget or widget.flightmodeState ~= "inflight" or type(widget.dashboardStats) ~= "table" then return end
  value = tonumber(value)
  if value == nil then return end

  local key = statKey(name)
  local stats = widget.dashboardStats
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

  if key == "rpm" then
    if entry.avg and entry.avg > 0 then
      widget.headspeedVariancePct = roundSigned((math.abs(value - entry.avg) / entry.avg) * 100)
    else
      widget.headspeedVariancePct = nil
    end
  end

  local suffix = STAT_SUFFIXES[name or ""]
  if suffix then updateMinMax(stats, "min" .. suffix, "max" .. suffix, value) end
end

local function sensorValue(name)
  local widget = currentWidget
  if not widget then return nil end
  if widget.connected ~= true then return nil end
  if name == "voltage" then return widget.voltage or liveSensorValue(name), "V" end
  if name == "cell_voltage" then
    local cells = widget.batteryConfig and tonumber(widget.batteryConfig.cellCount)
    local voltage = tonumber(widget.voltage) or tonumber(liveSensorValue("voltage"))
    if cells and cells > 0 and voltage then return voltage / cells, "V" end
    return nil, "V"
  end
  if name == "consumption" or name == "smartconsumption" then return widget.consumption or liveSensorValue("consumption"), "mAh" end
  if name == "current" then return widget.current or liveSensorValue(name), "A" end
  if name == "throttle_percent" then return widget.throttlePercent or liveSensorValue(name), "%" end
  if name == "rpm" or name == "headspeed" then return widget.rpm or liveSensorValue(name), "rpm" end
  if name == "tailspeed" then return liveSensorValue(name), "rpm" end
  if name == "link" then return widget.linkQuality or liveSensorValue(name), "dB" end
  if name == "rssi" or name == "vfr" then return liveSensorValue(name), "%" end
  if name == "smartfuel" or name == "fuel" then return widget.fuelPercent or liveSensorValue("smartfuel"), "%" end
  if name == "watts" then
    local voltage = tonumber(widget.voltage) or tonumber(liveSensorValue("voltage"))
    local current = tonumber(widget.current) or tonumber(liveSensorValue("current"))
    if voltage and current then return voltage * current, "W" end
    return nil, "W"
  end
  if name == "governor" then return widget.governorState end
  if name == "pid_profile" then return widget.pidProfile end
  if name == "rate_profile" then return widget.rateProfile end
  if name == "battery_profile" then return widget.batteryProfile end
  if name == "temp_mcu" then return widget.tempMcu or liveSensorValue(name), "°C" end
  if name == "temp_esc" then return widget.tempEsc or liveSensorValue(name), "°C" end
  if name == "bec_voltage" then return widget.becVoltage or liveSensorValue(name), "V" end
  if name == "altitude" then return liveSensorValue(name), "m" end
  if name == "armflags" then
    if widget.isArmed == true then return 1 end
    if widget.isArmed == false then return 0 end
  end
  if name == "armdisableflags" then return widget.armDisableFlags end
  return nil
end

function context.tasks.telemetry.collectPresentationStats()
  if not currentWidget or currentWidget.flightmodeState ~= "inflight" then return end
  for i = 1, #PRESENTATION_STAT_SOURCES do
    local name = PRESENTATION_STAT_SOURCES[i]
    local value = sensorValue(name)
    recordSensorStat(name, value)
  end
end

context.tasks.telemetry.sensorTable = {
  rssi = {unit_string = "%"},
  link = {unit_string = "dB"},
  vfr = {unit_string = "%"},
  voltage = {unit_string = "V"},
  cell_voltage = {unit_string = "V"},
  consumption = {unit_string = "mAh"},
  smartconsumption = {unit_string = "mAh"},
  current = {unit_string = "A"},
  throttle_percent = {unit_string = "%"},
  rpm = {unit_string = "rpm"},
  headspeed = {unit_string = "rpm"},
  tailspeed = {unit_string = "rpm"},
  smartfuel = {unit_string = "%"},
  fuel = {unit_string = "%"},
  temp_mcu = {unit_string = "°C", localizations = localizeTemperature},
  temp_esc = {unit_string = "°C", localizations = localizeTemperature},
  bec_voltage = {unit_string = "V"},
  altitude = {unit_string = "m"},
  watts = {unit_string = "W"},
}

function context.tasks.telemetry.getSensor(name, minValue, maxValue, thresholds)
  local value, unit = sensorValue(name)
  recordSensorStat(name, value)
  local sensorDef = context.tasks.telemetry.sensorTable[name]
  local localize = sensorDef and sensorDef.localizations
  if type(localize) == "function" then
    return localize(value, minValue, maxValue, thresholds)
  end
  return value, nil, unit, minValue, maxValue, thresholds
end

function context.tasks.telemetry.getSensorStats(name)
  local widget = currentWidget
  local stats = widget and widget.dashboardStats
  if not stats then return nil end
  local entry = stats[statKey(name)]
  if entry and (name == "temp_mcu" or name == "temp_esc") then
    local unit = temperatureUnit()
    local cacheRoot = stats._temperaturePresentation
    if not cacheRoot then
      cacheRoot = {}
      stats._temperaturePresentation = cacheRoot
    end
    local cache = cacheRoot[name]
    if not cache then
      cache = {}
      cacheRoot[name] = cache
    end
    if cache.unit ~= unit or cache.minRaw ~= entry.min or cache.maxRaw ~= entry.max or cache.sumRaw ~= entry.sum or cache.countRaw ~= entry.count or cache.avgRaw ~= entry.avg then
      cache.unit = unit
      cache.minRaw = entry.min
      cache.maxRaw = entry.max
      cache.sumRaw = entry.sum
      cache.countRaw = entry.count
      cache.avgRaw = entry.avg
      cache.min = convertTemperature(entry.min, unit)
      cache.max = convertTemperature(entry.max, unit)
      cache.avg = convertTemperature(entry.avg, unit)
      cache.sum = entry.sum
      cache.count = entry.count
    end
    return cache
  end
  if entry then return entry end
  local names = {
    voltage = "Voltage",
    cell_voltage = "CellVoltage",
    consumption = "Consumption",
    smartconsumption = "Consumption",
    current = "Current",
    throttle_percent = "ThrottlePercent",
    rpm = "Rpm",
    headspeed = "Rpm",
    link = "Link",
    rssi = "Link",
    vfr = "Vfr",
    tailspeed = "Tailspeed",
    smartfuel = "FuelPercent",
    fuel = "FuelPercent",
    temp_mcu = "TempMcu",
    temp_esc = "TempEsc",
    bec_voltage = "BecVoltage",
    altitude = "Altitude",
    watts = "Watts",
  }
  local suffix = names[name or ""]
  if not suffix then return nil end
  local minValue = stats["min" .. suffix]
  local maxValue = stats["max" .. suffix]
  if name == "temp_mcu" or name == "temp_esc" then
    local unit = temperatureUnit()
    minValue = convertTemperature(minValue, unit)
    maxValue = convertTemperature(maxValue, unit)
  end
  return {min = minValue, max = maxValue, avg = nil, sum = nil, count = nil}
end

function context.tasks.telemetry.active()
  return currentWidget and currentWidget.connected == true
end

function context.ini.getvalue(tbl, section, key)
  local values = type(tbl) == "table" and tbl[section] or nil
  if type(values) ~= "table" then return nil end
  return values[key]
end

function utils.getHeaderOptions()
  local width = lcd.getWindowSize()
  local matchedW = closestDashboardWidth(width or 800)

  if matchedW == 800 or matchedW == 784 then
    return {
      height = 36,
      font = "FONT_L",
      txbattfont = "FONT_STD",
      txdbattfont = "FONT_S",
      batterysegmentpaddingtop = 4,
      batterysegmentpaddingbottom = 4,
      batterysegmentpaddingleft = 4,
      batterysegmentpaddingright = 4,
      gaugepaddingleft = 25,
      txdgaugepaddingleft = 20,
      gaugepaddingright = 26,
      txdgaugepaddingright = 20,
      gaugepaddingbottom = 2,
      gaugepaddingtop = 2,
      cappaddingright = 3,
      barpaddingleft = 25,
      barpaddingright = 28,
      barpaddingbottom = 2,
      barpaddingtop = 4,
      valuepaddingleft = 20,
      txdvaluepaddingleft = 10,
      valuepaddingbottom = 20,
      txdvaluepaddingtop = 8,
      roundradius = 15,
    }
  elseif matchedW == 640 or matchedW == 630 then
    return {
      height = 30,
      font = "FONT_L",
      txbattfont = "FONT_S",
      txdbattfont = "FONT_S",
      batterysegmentpaddingtop = 4,
      batterysegmentpaddingbottom = 4,
      batterysegmentpaddingleft = 4,
      batterysegmentpaddingright = 4,
      gaugepaddingleft = 21,
      txdgaugepaddingleft = 15,
      gaugepaddingright = 23,
      txdgaugepaddingright = 15,
      gaugepaddingbottom = 2,
      gaugepaddingtop = 2,
      cappaddingright = 4,
      barpaddingleft = 19,
      barpaddingright = 21,
      barpaddingbottom = 2,
      txdvaluepaddingleft = 8,
      barpaddingtop = 2,
      valuepaddingbottom = 20,
      txdvaluepaddingtop = 8,
      roundradius = 10,
    }
  end

  return {
    height = 30,
    font = "FONT_L",
    txbattfont = "FONT_STD",
    txdbattfont = "FONT_S",
    batterysegmentpaddingtop = 4,
    batterysegmentpaddingbottom = 4,
    batterysegmentpaddingleft = 4,
    batterysegmentpaddingright = 4,
    gaugepaddingleft = 8,
    txdgaugepaddingleft = 10,
    gaugepaddingright = 9,
    txdgaugepaddingright = 10,
    gaugepaddingbottom = 2,
    gaugepaddingtop = 2,
    cappaddingright = 4,
    barpaddingleft = 15,
    barpaddingright = 18,
    barpaddingbottom = 2,
    txdvaluepaddingleft = 8,
    barpaddingtop = 2,
    valuepaddingbottom = 20,
    txdvaluepaddingtop = 8,
    roundradius = 10,
  }
end

function utils.themeColors()
  local state, signature = getThemeStateInternal()
  if not state.usesThemeColors then return legacyPalette() end

  local cached = themePaletteCache.palette
  if cached and themePaletteCache.signature == signature then return cached end

  local surfaceBg = resolveDashboardSurfaceBg(state)
  local gaugeTrackBg = resolveGaugeTrackBg(state, surfaceBg)
  local headerBg = resolveDashboardHeaderBg(state, surfaceBg)
  local headerText = resolveDashboardHeaderTextColor(state) or state.primaryColor
  local headerGaugeTrackBg = resolveGaugeTrackBg(state, headerBg)
  local fillcolor, fillwarncolor, fillcritcolor = resolveGaugeThresholdPalette(state)
  local titleColor = resolveDashboardTitleColor(state)
  local panelBg, panelAltBg, panelLine = resolveDashboardPanelColors(state, surfaceBg)

  cached = {
    textcolor = state.primaryColor,
    titlecolor = titleColor,
    bgcolor = surfaceBg,
    fillcolor = fillcolor,
    fillwarncolor = fillwarncolor,
    fillcritcolor = fillcritcolor,
    fillbgcolor = gaugeTrackBg,
    accentcolor = state.secondaryColor,
    rssifillcolor = fillcolor,
    rssifillbgcolor = headerGaugeTrackBg,
    txaccentcolor = state.buttonBorderActiveColor,
    txfillcolor = fillcolor,
    txbgfillcolor = headerGaugeTrackBg,
    tbbgcolor = headerBg,
    cntextcolor = headerText,
    tbtextcolor = headerText,
    rssitextcolor = headerText,
    panelbg = panelBg,
    paneldarkbg = panelAltBg,
    panelbgline = panelLine,
  }
  themePaletteCache.signature = signature
  themePaletteCache.palette = cached
  return cached
end

function utils.resolveFont(value, default)
  if type(value) == "number" then return value end
  if type(value) == "string" and _G[value] then return _G[value] end
  return default
end

function utils.resolveColor(value)
  if type(value) == "number" then return value end
  if type(value) == "table" and #value >= 3 then return rgb(value[1], value[2], value[3]) end
  if type(value) ~= "string" then return nil end
  local lower = value:lower()
  local prefix, baseName = lower:match("^(bright|light|dark)(.+)$")
  if prefix and baseName and NAMED_COLORS[baseName] then return colorVariant(NAMED_COLORS[baseName], prefix) end
  local named = NAMED_COLORS[lower]
  if named then return rgb(named[1], named[2], named[3]) end
  return nil
end

function utils.resolveThemeColor(key, default)
  if type(default) == "number" then return default end
  if type(default) == "table" then
    local resolved = utils.resolveColor(default)
    if resolved ~= nil then return resolved end
    return default
  end
  if type(default) == "string" and default == "transparent" then return nil end
  local resolved = utils.resolveColor(default)
  if resolved ~= nil then return resolved end
  local value = utils.themeColors()[key]
  if value ~= nil then return value end
  return default
end

function utils.standardHeaderLayout(headeropts)
  headeropts = headeropts or utils.getHeaderOptions()
  return {height = headeropts.height, cols = 7, rows = 1}
end

function utils.getTxBatteryVoltageRange()
  if system and system.voltageRange then
    local vmin, vmax = system.voltageRange()
    if vmin and vmax and vmin < vmax then return vmin, vmax end
  end
  return 7.2, 8.4
end

function utils.getTxBox(colorMode, headeropts, txbattMin, txbattMax, txbattWarn)
  return {
    col = 6,
    row = 1,
    type = "gauge",
    subtype = "bar",
    source = "txbatt",
    battery = true,
    batteryframe = true,
    hidevalue = true,
    valuealign = "left",
    batterysegments = 4,
    batteryspacing = 1,
    batteryframethickness = 2,
    batterysegmentpaddingtop = headeropts.batterysegmentpaddingtop,
    batterysegmentpaddingbottom = headeropts.batterysegmentpaddingbottom,
    batterysegmentpaddingleft = headeropts.batterysegmentpaddingleft,
    batterysegmentpaddingright = headeropts.batterysegmentpaddingright,
    gaugepaddingright = headeropts.gaugepaddingright,
    gaugepaddingleft = headeropts.gaugepaddingleft,
    gaugepaddingbottom = headeropts.gaugepaddingbottom,
    gaugepaddingtop = headeropts.gaugepaddingtop,
    cappaddingright = headeropts.cappaddingright,
    fillbgcolor = colorMode.txbgfillcolor,
    bgcolor = colorMode.tbbgcolor,
    accentcolor = colorMode.txaccentcolor,
    min = txbattMin,
    max = txbattMax,
    thresholds = {
      {value = txbattWarn, fillcolor = colorMode.fillwarncolor},
      {value = txbattMax, fillcolor = colorMode.txfillcolor},
    },
  }
end

local function txTextBox(colorMode, headeropts)
  return {
    col = 6,
    row = 1,
    type = "text",
    subtype = "telemetry",
    source = "txbatt",
    title = "Tx Batt",
    titlepos = "bottom",
    titlefont = "FONT_XXS",
    valuealign = "center",
    unit = "v",
    valuepaddingtop = 8,
    valuepaddingleft = 8,
    font = headeropts.txbattfont,
    decimals = 1,
    bgcolor = colorMode.tbbgcolor,
    textcolor = colorMode.tbtextcolor,
  }
end

local function txDigitalBox(colorMode, headeropts, txbattMin, txbattMax, txbattWarn)
  return {
    col = 6,
    row = 1,
    type = "gauge",
    subtype = "bar",
    source = "txbatt",
    font = headeropts.txdbattfont,
    battery = false,
    roundradius = headeropts.roundradius,
    decimals = 1,
    unit = "v",
    gaugepaddingright = headeropts.txdgaugepaddingright,
    gaugepaddingleft = headeropts.txdgaugepaddingleft,
    gaugepaddingbottom = headeropts.gaugepaddingbottom,
    gaugepaddingtop = headeropts.gaugepaddingtop,
    valuepaddingleft = headeropts.txdvaluepaddingleft,
    valuepaddingtop = headeropts.txdvaluepaddingtop,
    fillbgcolor = colorMode.txbgfillcolor,
    bgcolor = colorMode.tbbgcolor,
    accentcolor = colorMode.txaccentcolor,
    textcolor = colorMode.tbtextcolor,
    min = txbattMin,
    max = txbattMax,
    thresholds = {
      {value = txbattWarn, fillcolor = colorMode.fillwarncolor},
      {value = txbattMax, fillcolor = colorMode.txfillcolor},
    },
  }
end

function utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbattType)
  colorMode = colorMode or utils.themeColors()
  headeropts = headeropts or utils.getHeaderOptions()
  local txbattMin, txbattMax = utils.getTxBatteryVoltageRange()
  local txbattWarn = txbattMin + 0.2
  txbattType = tonumber(txbattType) or 0

  local txBox
  if txbattType == 2 then
    txBox = txDigitalBox(colorMode, headeropts, txbattMin, txbattMax, txbattWarn)
  elseif txbattType == 1 then
    txBox = txTextBox(colorMode, headeropts)
  else
    txBox = utils.getTxBox(colorMode, headeropts, txbattMin, txbattMax, txbattWarn)
  end

  return {
    {col = 1, row = 1, colspan = 2, type = "text", subtype = "craftname", font = headeropts.font, valuealign = "left", valuepaddingleft = 5, bgcolor = colorMode.tbbgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.cntextcolor},
    {col = 3, row = 1, colspan = 3, type = "image", subtype = "image", bgcolor = colorMode.tbbgcolor},
    txBox,
    {
      col = 7,
      row = 1,
      type = "gauge",
      subtype = "step",
      source = "rssi",
      font = "FONT_XS",
      stepgap = 2,
      stepcount = 5,
      decimals = 0,
      valuealign = "left",
      barpaddingleft = headeropts.barpaddingleft,
      barpaddingright = headeropts.barpaddingright,
      barpaddingbottom = headeropts.barpaddingbottom,
      barpaddingtop = headeropts.barpaddingtop,
      valuepaddingleft = headeropts.valuepaddingleft,
      valuepaddingbottom = headeropts.valuepaddingbottom,
      bgcolor = colorMode.tbbgcolor,
      textcolor = colorMode.rssitextcolor,
      fillcolor = colorMode.rssifillcolor,
      fillbgcolor = colorMode.rssifillbgcolor,
    },
  }
end

function utils.getDashboardThemeOptionKey(width)
  local matchedW = closestDashboardWidth(tonumber(width) or 0)
  if matchedW == 800 then return "ls_full" end
  if matchedW == 784 then return "ls_std" end
  if matchedW == 640 then return "ss_full" end
  if matchedW == 630 then return "ss_std" end
  if matchedW == 480 then return "ms_full" end
  if matchedW == 472 then return "ms_std" end
  return "ls_full"
end

function utils.isFullScreen(width, height)
  local matchedW = utils.matchSupportedResolution(tonumber(width) or 0, tonumber(height) or 0)
  if matchedW == 800 or matchedW == 480 or matchedW == 640 then return true end
  if matchedW == 784 or matchedW == 472 or matchedW == 630 then return false end
  return nil
end

function utils.matchSupportedResolution(width, height, supportedResolutions, maxDistance)
  local bestRes, bestDistance = closestDashboardResolution(tonumber(width) or 0, tonumber(height) or 0, supportedResolutions)
  local tolerance = maxDistance or DASHBOARD_RESOLUTION_TOLERANCE
  if bestRes and bestDistance ~= nil and bestDistance <= tolerance then
    return bestRes[1], bestRes[2], bestDistance
  end
  return nil
end

function utils.supportedResolution(width, height, supportedResolutions)
  return utils.matchSupportedResolution(width, height, supportedResolutions) ~= nil
end

function utils.getThemeState()
  local state = getThemeStateInternal()
  return state
end

function utils.getThemeOutlineColor()
  local state = getThemeStateInternal()
  return state.primaryColor
end

function utils.getThemeSignature()
  local _, signature = getThemeStateInternal()
  return signature
end

function utils.getBatteryVoltageBounds(defaultCells, defaultMin, defaultMax)
  local config = currentWidget and currentWidget.batteryConfig
  local cells = tonumber(config and config.cellCount) or defaultCells or 6
  local minV = tonumber(config and config.vbatMinCell) or defaultMin or 3.0
  local maxV = tonumber(config and config.vbatMaxCell) or tonumber(config and config.vbatFullCell) or defaultMax or 4.2
  return cells, minV, maxV
end

function utils.maxVoltageToCellVoltage(value, decimals)
  value = tonumber(value)
  local cells = currentWidget and currentWidget.batteryConfig and tonumber(currentWidget.batteryConfig.cellCount)
  if value == nil or cells == nil or cells <= 0 then return value end
  local cell = value / cells
  decimals = decimals == nil and 2 or decimals
  local scale = 10 ^ decimals
  return math.floor(cell * scale + 0.5) / scale
end

function utils.getParam(box, key)
  local value = box and box[key]
  if type(value) == "function" and key ~= "transform" and key ~= "thresholds" and key ~= "value" then
    local ok, result = pcall(value, box)
    if ok then return result end
    return nil
  end
  return value
end

function utils.isModelPrefsReady()
  return true
end

function utils.resetBoxCache(box)
  if type(box) ~= "table" then return end
  box._cfg = nil
  box._cache = nil
  box._geom = nil
end

local function clearTable(t)
  if type(t) ~= "table" then return end
  for key in pairs(t) do t[key] = nil end
end

function context.widgets.dashboard.clearCaches(options)
  options = options or {}
  if options.renders then clearTable(context.widgets.dashboard.renders) end
  if options.theme then
    clearTable(paletteCache)
    clearTable(themeStateCache)
    clearTable(themePaletteCache)
    systemThemeSupport = nil
  end
  if options.images then
    clearTable(imageCache)
    clearTable(imagePathCache)
    clearTable(imageBitmapCache)
    if context.session then clearTable(context.session.dialImageCache) end
  end
  if options.liveSources then
    clearTable(liveSourceCache)
    clearTable(liveMissRetryAt)
    clearTable(liveMissCount)
  end
end

function utils.ensureCfg(box, builder)
  box._cfg = box._cfg or {}
  if not box._cfg._built then
    builder(box._cfg, box)
    box._cfg._built = true
  end
  return box._cfg
end

function utils.compileTransform(transform, decimals)
  return function(value)
    if value ~= nil and type(transform) == "function" then
      value = transform(value)
    elseif value ~= nil and transform == "floor" then
      value = math.floor(value)
    elseif value ~= nil and transform == "ceil" then
      value = math.ceil(value)
    elseif value ~= nil and transform == "round" then
      value = math.floor(value + 0.5)
    elseif value ~= nil and type(transform) == "number" then
      value = value * transform
    end
    if decimals ~= nil and value ~= nil then
      local fmt = fmtCache[decimals]
      if not fmt then
        fmt = "%." .. tostring(decimals) .. "f"
        fmtCache[decimals] = fmt
      end
      value = string.format(fmt, value)
    end
    return value
  end
end

function utils.transformValue(value, box)
  local transform = utils.getParam(box or {}, "transform")
  local decimals = utils.getParam(box or {}, "decimals")
  return utils.compileTransform(transform, decimals)(value)
end

function utils.resolveThresholdColor(value, box, colorKey, fallbackThemeKey, thresholdsOverride)
  local color = utils.resolveThemeColor(fallbackThemeKey, utils.getParam(box, colorKey))
  local thresholds = thresholdsOverride or utils.getParam(box, "thresholds")
  if thresholds and value ~= nil then
    for _, threshold in ipairs(thresholds) do
      local thresholdValue = threshold.value
      if type(thresholdValue) == "function" then thresholdValue = thresholdValue(box, value) end
      if type(value) == "string" and thresholdValue == value and threshold[colorKey] then
        return utils.resolveThemeColor(colorKey, threshold[colorKey])
      end
      if type(value) == "number" and type(thresholdValue) == "number" and value <= thresholdValue and threshold[colorKey] then
        return utils.resolveThemeColor(colorKey, threshold[colorKey])
      end
    end
  end
  return color
end

function utils.resolveThemeColorArray(colorKey, values, out)
  if values == nil and type(colorKey) == "table" then
    values = colorKey
    colorKey = nil
  end
  if type(values) ~= "table" then return values end
  out = out or {}
  for i = #out, 1, -1 do out[i] = nil end
  for i = 1, #values do out[i] = utils.resolveThemeColor(colorKey, values[i]) end
  return out
end

function utils.dirtyOnDisplayValueChange(box)
  if type(box) ~= "table" then return false end
  local value = box._currentDisplayValue
  if value ~= box._lastDisplayValue then
    box._lastDisplayValue = value
    return true
  end
  return false
end

function utils.getFontListsForResolution()
  local version = system and system.getVersion and system.getVersion() or {}
  local liveW, liveH
  if lcd.getWindowSize then liveW, liveH = lcd.getWindowSize() end
  local width = version.lcdWidth or liveW or 800
  local height = version.lcdHeight or liveH or 480
  local resolution = tostring(width) .. "x" .. tostring(height)
  return FONT_LISTS_BY_RESOLUTION[resolution] or DEFAULT_FONT_LISTS
end

-- Restored from this suite's own pre-rewrite widgets/dashboard/lib/utils.lua
-- (see the sibling wingflight-lua-ethos-suite repo's `stab-curve` branch,
-- which still has that file, for the source this was ported from) after
-- the rfsuite-full-rewrite collapsed this to a flat color-fill-only stub,
-- which silently broke every caller that passes a style table
-- (fillcolor/bordercolor/borderwidth/roundradius/inset*) as `bgcolor`
-- instead of a plain color -- a real, reproducible crash (`lcd.color`:
-- "number expected, got table"), not a hypothetical one: the kevd theme's
-- `rs_bgstyle`/`rs_govbgstyle`/`arcGroupTileBg` panels all rely on it, and
-- every gauge/dial object type (objects/gauge/{arc,bar,ring,step}.lua,
-- objects/dial/image.lua) already reassigns
-- `x, y, w, h = utils.drawBoxBackground(...)` expecting the
-- inset-adjusted content rect this returns.
local function drawRoundedFilledRectSafe(x, y, w, h, radius, color)
  if not color or w <= 0 or h <= 0 then return end

  radius = tonumber(radius) or 0
  if radius < 1 then
    lcd.color(color)
    lcd.drawFilledRectangle(x, y, w, h)
    return
  end

  local maxRadius = math.floor(math.min(w, h) / 2)
  if radius > maxRadius then radius = maxRadius end

  lcd.color(color)
  -- Center/edge fills create a rounded rectangle using primitives already
  -- used elsewhere in this dashboard renderer.
  lcd.drawFilledRectangle(x + radius, y, w - radius * 2, h)
  lcd.drawFilledRectangle(x, y + radius, w, h - radius * 2)
  lcd.drawFilledCircle(x + radius, y + radius, radius)
  lcd.drawFilledCircle(x + w - radius - 1, y + radius, radius)
  lcd.drawFilledCircle(x + radius, y + h - radius - 1, radius)
  lcd.drawFilledCircle(x + w - radius - 1, y + h - radius - 1, radius)
end

local function boxContentRect(x, y, w, h, bgcolor)
  if type(bgcolor) ~= "table" then
    return x, y, w, h
  end

  local inset = tonumber(bgcolor.inset or bgcolor.margin) or 0
  local insetleft = tonumber(bgcolor.insetleft or bgcolor.inset_left) or inset
  local insetright = tonumber(bgcolor.insetright or bgcolor.inset_right) or inset
  local insettop = tonumber(bgcolor.insettop or bgcolor.inset_top) or inset
  local insetbottom = tonumber(bgcolor.insetbottom or bgcolor.inset_bottom) or inset
  local borderwidth = tonumber(bgcolor.borderwidth) or 0

  local bw = w - insetleft - insetright
  local bh = h - insettop - insetbottom
  if bw <= 0 or bh <= 0 then return x, y, w, h end

  local contentPad = tonumber(bgcolor.contentpadding) or 0
  local innerLeft = insetleft + borderwidth + contentPad
  local innerRight = insetright + borderwidth + contentPad
  local innerTop = insettop + borderwidth + contentPad
  local innerBottom = insetbottom + borderwidth + contentPad
  return x + innerLeft, y + innerTop, w - innerLeft - innerRight, h - innerTop - innerBottom
end

local function drawBoxBackground(x, y, w, h, bgcolor)
  if type(bgcolor) ~= "table" then
    -- No `or legacyPalette().bgcolor` fallback here (unlike this
    -- function's own pre-restoration stub) -- matching the original
    -- `drawStyledBoxBackground` exactly: a nil/false bgcolor means
    -- "stay transparent", not "paint the legacy default". Making
    -- utils.box()'s call to this unconditional (below) is what exposed
    -- the difference -- a fallback fill was harmless while the call was
    -- gated on `bgcolor ~= nil`, but firing unconditionally it force-
    -- painted `legacyPalette().bgcolor` (black in dark mode) over every
    -- box that relies on transparency to show its parent panel's own
    -- background through, a real regression across every theme, not
    -- just kevd, caught live right after this fix shipped.
    if bgcolor then
      lcd.color(bgcolor)
      lcd.drawFilledRectangle(math.floor(x + 0.5), math.floor(y + 0.5), math.floor(w + 0.5), math.floor(h + 0.5))
    end
    return x, y, w, h
  end

  local backfillcolor = bgcolor.backfillcolor or bgcolor.cellbgcolor or bgcolor.outercolor
  if backfillcolor then
    lcd.color(backfillcolor)
    lcd.drawFilledRectangle(x, y, w, h)
  end

  local inset = tonumber(bgcolor.inset or bgcolor.margin) or 0
  local insetleft = tonumber(bgcolor.insetleft or bgcolor.inset_left) or inset
  local insetright = tonumber(bgcolor.insetright or bgcolor.inset_right) or inset
  local insettop = tonumber(bgcolor.insettop or bgcolor.inset_top) or inset
  local insetbottom = tonumber(bgcolor.insetbottom or bgcolor.inset_bottom) or inset
  local borderwidth = tonumber(bgcolor.borderwidth) or 0
  local radius = tonumber(bgcolor.roundradius or bgcolor.radius) or 0
  local fillcolor = bgcolor.bgcolor or bgcolor.fillcolor or bgcolor.fill or bgcolor.color
  local bordercolor = bgcolor.bordercolor

  local bx = x + insetleft
  local by = y + insettop
  local bw = w - insetleft - insetright
  local bh = h - insettop - insetbottom

  if bw <= 0 or bh <= 0 then return x, y, w, h end

  if borderwidth > 0 and bordercolor then
    drawRoundedFilledRectSafe(bx, by, bw, bh, radius, bordercolor)
    local ix = bx + borderwidth
    local iy = by + borderwidth
    local iw = bw - borderwidth * 2
    local ih = bh - borderwidth * 2
    if iw > 0 and ih > 0 then
      drawRoundedFilledRectSafe(ix, iy, iw, ih, math.max(0, radius - borderwidth), fillcolor)
    end
  else
    drawRoundedFilledRectSafe(bx, by, bw, bh, radius, fillcolor)
  end

  return boxContentRect(x, y, w, h, bgcolor)
end

function utils.drawBoxBackground(x, y, w, h, bgcolor)
  return drawBoxBackground(x, y, w, h, bgcolor)
end

function utils.boxContentRect(x, y, w, h, bgcolor)
  return boxContentRect(x, y, w, h, bgcolor)
end

-- Draws `image` (a path string, resolved+cached through imageCache like
-- utils.box() always has, or an already-loaded bitmap handle) fitted/aligned
-- inside the given rect. Extracted from utils.box()'s own image branch so
-- title-only callers (objects/image/{image,model}.lua) can draw their image
-- against utils.prepareTextLayout()'s cached content region without going
-- through utils.box()'s (uncached) title-measurement path a second time.
local function drawImageInRect(regionX, regionY, regionW, regionH, image, imagewidth, imageheight, imagealign, bgcolor)
  local bitmap = nil
  if type(image) == "string" then
    local fallbackLogo = utils.getLogoFallbackForBackground and utils.getLogoFallbackForBackground(bgcolor)
    local cacheKey = image .. "|" .. tostring(fallbackLogo or "")
    bitmap = imageCache[cacheKey]
    if bitmap == nil then
      bitmap = context.utils.loadImage(image, nil, fallbackLogo) or false
      imageCache[cacheKey] = bitmap
    end
    if bitmap == false then bitmap = nil end
  else
    bitmap = image
  end

  if bitmap and regionW > 0 and regionH > 0 and lcd.drawBitmap then
    local imgW = tonumber(imagewidth) or regionW
    local imgH = tonumber(imageheight) or regionH
    local align = imagealign or "center"
    local imgX = regionX
    local imgY = regionY
    if align == "right" then
      imgX = regionX + regionW - imgW
    elseif align ~= "left" then
      imgX = regionX + (regionW - imgW) / 2
    end
    if align == "bottom" then
      imgY = regionY + regionH - imgH
    elseif align ~= "top" then
      imgY = regionY + (regionH - imgH) / 2
    end
    lcd.drawBitmap(math.floor(imgX + 0.5), math.floor(imgY + 0.5), bitmap, math.floor(imgW + 0.5), math.floor(imgH + 0.5))
  end
end

function utils.drawImageInRect(x, y, w, h, image, imagewidth, imageheight, imagealign, bgcolor)
  return drawImageInRect(x, y, w, h, image, imagewidth, imageheight, imagealign, bgcolor)
end

function utils.box(x, y, w, h, title, titlepos, titlealign, titlefont, titlespacing, titlecolor, titlepadding, titlepaddingleft, titlepaddingright, titlepaddingtop, titlepaddingbottom, displayValue, unit, valuefont, valuealign, textcolor, valuepadding, valuepaddingleft, valuepaddingright, valuepaddingtop, valuepaddingbottom, bgcolor, image, imagewidth, imageheight, imagealign)
  -- Unconditional (not `if bgcolor ~= nil`): drawBoxBackground() itself
  -- handles a nil/plain bgcolor by returning x/y/w/h unchanged, and a
  -- style-table bgcolor needs its inset-adjusted return value so
  -- title/value/image below draw inside the border, not overlapping it.
  x, y, w, h = drawBoxBackground(x, y, w, h, bgcolor)

  title = (type(title) == "string" or type(title) == "number") and tostring(title) or nil
  local value = displayValue ~= nil and (tostring(displayValue) .. (unit or "")) or nil

  local tp = titlepadding or 0
  local vp = valuepadding or 6
  titlepaddingleft = titlepaddingleft or tp
  titlepaddingright = titlepaddingright or tp
  titlepaddingtop = titlepaddingtop or tp
  titlepaddingbottom = titlepaddingbottom or tp
  valuepaddingleft = valuepaddingleft or vp
  valuepaddingright = valuepaddingright or vp
  valuepaddingtop = valuepaddingtop or vp
  valuepaddingbottom = valuepaddingbottom or vp
  titlespacing = titlespacing or 6

  local titleH = 0
  local titleW = 0
  local titleTextH = 0
  local resolvedTitleFont = nil
  if title then
    local explicitTitleFont = utils.resolveFont(titlefont, nil)
    if explicitTitleFont then
      resolvedTitleFont = explicitTitleFont
      lcd.font(resolvedTitleFont)
      titleW, titleTextH = lcd.getTextSize(title)
    else
      local fontLists = utils.getFontListsForResolution()
      local titleFonts = fontLists.value_title or DEFAULT_FONT_LISTS.value_title
      local valueFonts = fontLists.value_default or DEFAULT_FONT_LISTS.value_default
      local minValueFontH = 9999

      for i = 1, #valueFonts do
        lcd.font(valueFonts[i])
        local _, vh = lcd.getTextSize("8")
        if vh and vh < minValueFontH then minValueFontH = vh end
      end

      local maxTitleW = w - titlepaddingleft - titlepaddingright
      for i = 1, #titleFonts do
        local candidate = titleFonts[i]
        lcd.font(candidate)
        local tw, th = lcd.getTextSize(title)
        local remH = h - titlepaddingtop - th - titlepaddingbottom - valuepaddingtop - valuepaddingbottom
        if tw <= maxTitleW and th > 0 and remH >= minValueFontH then
          resolvedTitleFont = candidate
          titleW = tw
          titleTextH = th
          break
        end
      end

      if not resolvedTitleFont then
        resolvedTitleFont = titleFonts[#titleFonts] or FONT_XS
        lcd.font(resolvedTitleFont)
        titleW, titleTextH = lcd.getTextSize(title)
      end
    end
    titleH = titleTextH + titlepaddingtop + titlepaddingbottom + titlespacing
  end

  local regionX = x + valuepaddingleft
  local regionY = y + valuepaddingtop
  local regionW = w - valuepaddingleft - valuepaddingright
  local regionH = h - valuepaddingtop - valuepaddingbottom
  if title and titlepos == "bottom" then
    regionH = regionH - titleH
  elseif title then
    regionY = regionY + titleH
    regionH = regionH - titleH
  end

  if image then
    drawImageInRect(regionX, regionY, regionW, regionH, image, imagewidth, imageheight, imagealign, bgcolor)
  elseif value then

    local resolvedValueFont = utils.resolveFont(valuefont, nil)
    if not resolvedValueFont then
      local fonts = utils.getFontListsForResolution().value_default
      resolvedValueFont = fonts[#fonts]
      local fitValue = value
      if string.find(fitValue, "%%", 1, true) then fitValue = fitValue:gsub("%%", "W") end
      for _, candidate in ipairs(fonts) do
        lcd.font(candidate)
        local tw, th = lcd.getTextSize(fitValue)
        if tw <= regionW and th <= regionH then
          resolvedValueFont = candidate
        end
      end
    end
    lcd.font(resolvedValueFont)
    local tw, th = lcd.getTextSize(value)
    local sx = regionX
    local align = valuealign or "center"
    if align == "right" then sx = regionX + regionW - tw elseif align ~= "left" then sx = regionX + (regionW - tw) / 2 end
    lcd.color(utils.resolveThemeColor("textcolor", textcolor))
    lcd.drawText(sx, regionY + (regionH - th) / 2, value)
  end

  if title then
    lcd.font(resolvedTitleFont)
    local regionW = w - titlepaddingleft - titlepaddingright
    local sx = x + titlepaddingleft + (regionW - titleW) / 2
    if titlealign == "left" then sx = x + titlepaddingleft end
    if titlealign == "right" then sx = x + titlepaddingleft + regionW - titleW end
    local sy = titlepos == "bottom" and (y + h - titlepaddingbottom - titleTextH) or (y + titlepaddingtop)
    lcd.color(utils.resolveThemeColor("titlecolor", titlecolor))
    lcd.drawText(sx, sy, title)
  end
end

-- Cached counterpart to utils.box()'s title/value text layout.
--
-- utils.box() re-runs its font-fit search (looping every candidate font in
-- the resolution's font list, calling lcd.font/lcd.getTextSize per
-- candidate) on *every* paint() call, not just every wakeup(). paint()
-- runs on every screen redraw regardless of an object's `render.scheduler`,
-- and Ethos grants paint() a much tighter instruction budget than wakeup()
-- -- so that loop is exactly the kind of work that should happen once in
-- wakeup() (looser budget) and be reused, unchanged, across paint() calls
-- (tight budget) until something affecting layout actually changes.
--
-- utils.prepareTextLayout() does the measuring/positioning only (no
-- drawing) and caches the result on box._textLayout, keyed on every input
-- that can change what it computes -- geometry, title/value text, fonts,
-- alignment, padding. Call it from both render.wakeup() (to pre-warm the
-- cache while the budget is loose) and render.paint() (which will get a
-- cache hit for free whenever wakeup() already ran with the same content
-- rect this frame -- see utils.boxContentRect()). utils.paintTextLayout()
-- then does the actual (cheap) drawing from that cached layout.
--
-- Extracted from objects/text/telemetry.lua's original private
-- implementation; see that object for the pattern this generalizes.
local function textOrNil(value)
  if type(value) == "string" or type(value) == "number" then return tostring(value) end
  return nil
end

local function valueText(displayValue, unit)
  if displayValue == nil then return nil end
  return tostring(displayValue) .. (unit or "")
end

local function prepareTextLayout(box, x, y, w, h, titleIn, titlepos, titlealign, titlefont, titlespacing, titlepadding, titlepaddingleft, titlepaddingright, titlepaddingtop, titlepaddingbottom, displayValue, unit, valuefont, valuealign, valuepadding, valuepaddingleft, valuepaddingright, valuepaddingtop, valuepaddingbottom, cacheField)
  -- cacheField lets a box keep more than one independently-cached layout
  -- (defaults to box._textLayout) -- needed by callers that draw several
  -- separate title/value blocks in one paint() (e.g. gauge/bar.lua's
  -- battadv overlay, which draws two extra text lines alongside its own
  -- main title/value label). Reusing a single slot across such calls would
  -- have each one evict the last, so every one of them would cache-miss on
  -- every paint() -- the exact problem this function exists to avoid.
  cacheField = cacheField or "_textLayout"
  local title = textOrNil(titleIn)
  local value = valueText(displayValue, unit)

  local tp = titlepadding or 0
  local vp = valuepadding or 6
  titlepaddingleft = titlepaddingleft or tp
  titlepaddingright = titlepaddingright or tp
  titlepaddingtop = titlepaddingtop or tp
  titlepaddingbottom = titlepaddingbottom or tp
  valuepaddingleft = valuepaddingleft or vp
  valuepaddingright = valuepaddingright or vp
  valuepaddingtop = valuepaddingtop or vp
  valuepaddingbottom = valuepaddingbottom or vp
  titlespacing = titlespacing or 6

  local layout = box[cacheField]
  if layout
      and layout.x == x and layout.y == y and layout.w == w and layout.h == h
      and layout.title == title and layout.value == value
      and layout.titlepos == titlepos and layout.titlealign == titlealign
      and layout.titlefont == titlefont and layout.valuefont == valuefont
      and layout.valuealign == valuealign
      and layout.titlepaddingleft == titlepaddingleft
      and layout.titlepaddingright == titlepaddingright
      and layout.titlepaddingtop == titlepaddingtop
      and layout.titlepaddingbottom == titlepaddingbottom
      and layout.valuepaddingleft == valuepaddingleft
      and layout.valuepaddingright == valuepaddingright
      and layout.valuepaddingtop == valuepaddingtop
      and layout.valuepaddingbottom == valuepaddingbottom
      and layout.titlespacing == titlespacing then
    return layout
  end

  layout = layout or {}
  layout.x, layout.y, layout.w, layout.h = x, y, w, h
  layout.title, layout.value = title, value
  layout.titlepos, layout.titlealign = titlepos, titlealign
  layout.titlefont, layout.valuefont = titlefont, valuefont
  layout.valuealign = valuealign
  layout.titlepaddingleft = titlepaddingleft
  layout.titlepaddingright = titlepaddingright
  layout.titlepaddingtop = titlepaddingtop
  layout.titlepaddingbottom = titlepaddingbottom
  layout.valuepaddingleft = valuepaddingleft
  layout.valuepaddingright = valuepaddingright
  layout.valuepaddingtop = valuepaddingtop
  layout.valuepaddingbottom = valuepaddingbottom
  layout.titlespacing = titlespacing

  local titleH = 0
  local titleW = 0
  local titleTextH = 0
  local resolvedTitleFont = nil
  if title then
    local explicitTitleFont = utils.resolveFont(titlefont, nil)
    if explicitTitleFont then
      resolvedTitleFont = explicitTitleFont
      lcd.font(resolvedTitleFont)
      titleW, titleTextH = lcd.getTextSize(title)
    else
      local fontLists = utils.getFontListsForResolution()
      local titleFonts = fontLists.value_title
      local valueFonts = fontLists.value_default
      local minValueFontH = 9999

      for i = 1, #valueFonts do
        lcd.font(valueFonts[i])
        local _, vh = lcd.getTextSize("8")
        if vh and vh < minValueFontH then minValueFontH = vh end
      end

      local maxTitleW = w - titlepaddingleft - titlepaddingright
      for i = 1, #titleFonts do
        local candidate = titleFonts[i]
        lcd.font(candidate)
        local tw, th = lcd.getTextSize(title)
        local remH = h - titlepaddingtop - th - titlepaddingbottom - valuepaddingtop - valuepaddingbottom
        if tw <= maxTitleW and th > 0 and remH >= minValueFontH then
          resolvedTitleFont = candidate
          titleW = tw
          titleTextH = th
          break
        end
      end

      if not resolvedTitleFont then
        resolvedTitleFont = titleFonts[#titleFonts] or FONT_XS
        lcd.font(resolvedTitleFont)
        titleW, titleTextH = lcd.getTextSize(title)
      end
    end
    titleH = titleTextH + titlepaddingtop + titlepaddingbottom + titlespacing
  end

  local regionX = x + valuepaddingleft
  local regionY = y + valuepaddingtop
  local regionW = w - valuepaddingleft - valuepaddingright
  local regionH = h - valuepaddingtop - valuepaddingbottom
  if title and titlepos == "bottom" then
    regionH = regionH - titleH
  elseif title then
    regionY = regionY + titleH
    regionH = regionH - titleH
  end

  -- Exposed for callers that draw something other than value text in the
  -- leftover (title-adjusted) content area -- e.g. objects/image/{image,
  -- model}.lua drawing an image there via utils.drawImageInRect().
  layout.regionX, layout.regionY, layout.regionW, layout.regionH = regionX, regionY, regionW, regionH

  layout.valueDraw = false
  if value then
    local resolvedValueFont = utils.resolveFont(valuefont, nil)
    if not resolvedValueFont then
      local fonts = utils.getFontListsForResolution().value_default
      resolvedValueFont = fonts[#fonts]
      local fitValue = value
      if string.find(fitValue, "%%", 1, true) then fitValue = fitValue:gsub("%%", "W") end
      for i = 1, #fonts do
        local candidate = fonts[i]
        lcd.font(candidate)
        local tw, th = lcd.getTextSize(fitValue)
        if tw <= regionW and th <= regionH then resolvedValueFont = candidate end
      end
    end
    lcd.font(resolvedValueFont)
    local valueW, valueH = lcd.getTextSize(value)
    local sx = regionX
    local align = valuealign or "center"
    if align == "right" then
      sx = regionX + regionW - valueW
    elseif align ~= "left" then
      sx = regionX + (regionW - valueW) / 2
    end
    layout.valueDraw = true
    layout.valueFont = resolvedValueFont
    layout.valueX = sx
    layout.valueY = regionY + (regionH - valueH) / 2
  end

  layout.titleDraw = false
  if title then
    local regionTitleW = w - titlepaddingleft - titlepaddingright
    local sx = x + titlepaddingleft + (regionTitleW - titleW) / 2
    if titlealign == "left" then sx = x + titlepaddingleft end
    if titlealign == "right" then sx = x + titlepaddingleft + regionTitleW - titleW end
    local sy = titlepos == "bottom" and (y + h - titlepaddingbottom - titleTextH) or (y + titlepaddingtop)
    layout.titleDraw = true
    layout.titleFont = resolvedTitleFont
    layout.titleX = sx
    layout.titleY = sy
  end

  box[cacheField] = layout
  return layout
end

function utils.prepareTextLayout(box, x, y, w, h, title, titlepos, titlealign, titlefont, titlespacing, titlepadding, titlepaddingleft, titlepaddingright, titlepaddingtop, titlepaddingbottom, displayValue, unit, valuefont, valuealign, valuepadding, valuepaddingleft, valuepaddingright, valuepaddingtop, valuepaddingbottom, cacheField)
  return prepareTextLayout(box, x, y, w, h, title, titlepos, titlealign, titlefont, titlespacing, titlepadding, titlepaddingleft, titlepaddingright, titlepaddingtop, titlepaddingbottom, displayValue, unit, valuefont, valuealign, valuepadding, valuepaddingleft, valuepaddingright, valuepaddingtop, valuepaddingbottom, cacheField)
end

function utils.paintTextLayout(layout, valuecolor, titlecolor)
  if not layout then return end
  if layout.valueDraw then
    lcd.font(layout.valueFont)
    lcd.color(utils.resolveThemeColor("textcolor", valuecolor))
    lcd.drawText(layout.valueX, layout.valueY, layout.value)
  end
  if layout.titleDraw then
    lcd.font(layout.titleFont)
    lcd.color(utils.resolveThemeColor("titlecolor", titlecolor))
    lcd.drawText(layout.titleX, layout.titleY, layout.title)
  end
end

function utils.drawArc(cx, cy, radius, thickness, startAngle, endAngle, arcColor)
  lcd.color(arcColor or legacyPalette().fillcolor)
  local outer = radius
  local inner = math.max(1, radius - (thickness or 6))
  if lcd.drawAnnulusSector then
    local sweep = endAngle - startAngle
    if sweep < 0 then sweep = sweep + 360 end
    if sweep <= 180 then
      lcd.drawAnnulusSector(cx, cy, inner, outer, startAngle, endAngle)
    else
      local mid = startAngle + sweep / 2
      lcd.drawAnnulusSector(cx, cy, inner, outer, startAngle, mid)
      lcd.drawAnnulusSector(cx, cy, inner, outer, mid, endAngle)
    end
  else
    lcd.drawCircle(cx, cy, outer)
  end
end

function utils.drawBarNeedle(cx, cy, length, thickness, angleDeg, needleColor)
  local radians = math.rad(angleDeg or 0)
  local x2 = cx + math.cos(radians) * (length or 0)
  local y2 = cy + math.sin(radians) * (length or 0)
  lcd.color(needleColor or legacyPalette().textcolor)
  if lcd.drawLine then
    local pen = lcd.pen and lcd.pen() or nil
    if lcd.pen then lcd.pen(thickness or 1) end
    lcd.drawLine(cx, cy, x2, y2)
    if pen and lcd.pen then lcd.pen(pen) end
  else
    lcd.drawFilledRectangle(cx, cy, x2 - cx, y2 - cy)
  end
end

function utils.getBatteryCellCount(default)
  local config = currentWidget and currentWidget.batteryConfig
  return tonumber(config and config.cellCount) or default or 0
end

function utils.setBackgroundColourBasedOnTheme()
  local w, h = lcd.getWindowSize()
  local colors = utils.themeColors()
  lcd.color(colors.panelbg or colors.bgcolor or utils.getThemeState().pageBgColor)
  lcd.drawFilledRectangle(0, 0, w, h)
end

function utils.drawScreenBorder()
end

function utils.getLogoFallbackForBackground(bgcolor)
  return logoFallbackForBackground(bgcolor or utils.themeColors().bgcolor)
end

function utils.loadImage(image1, image2, image3)
  return context.utils.loadImage(image1, image2, image3)
end

function utils.isImageTooLarge(path, maxBytes)
  return context.utils.isImageTooLarge(path, maxBytes)
end

function utils.isElectricEngine()
  return true
end

function utils.applyOffset(x, y, box)
  box = box or {}
  return x + (tonumber(box.xoffset) or 0), y + (tonumber(box.yoffset) or 0)
end

function utils.getPulsingDots()
  return "..."
end

function context.utils.getGovernorState(value)
  value = tonumber(value)

  local telemetry = context.tasks.telemetry
  local armflags = telemetry and telemetry.getSensor and telemetry.getSensor("armflags")
  local isArmed = context.utils.armFlagsToIsArmed(armflags)

  local returnvalue
  if value == nil and isArmed ~= nil then
    -- No governor telemetry sensor at all (feature disabled/unsupported on this
    -- craft) -- fall back to basic arm state instead of leaving this blank.
    returnvalue = isArmed and "ARMED" or "DISARMED"
  else
    if isArmed == false then value = 101 end
    returnvalue = GOVERNOR_LABELS[value] or "UNKNOWN"
  end

  local disableflags = telemetry and telemetry.getSensor and telemetry.getSensor("armdisableflags")
  if disableflags ~= nil then
    local armstring = context.utils.armingDisableFlagsToString(math.floor(disableflags))
    if armstring ~= "OK" then returnvalue = armstring end
  end

  return returnvalue
end

local function normalizeImagePath(path)
  if type(path) ~= "string" or path == "" then return nil end
  path = path:gsub("\\", "/")
  path = path:gsub("^/bitmaps", "BITMAPS:", 1)
  path = path:gsub("^/scripts", "SCRIPTS:", 1)
  path = path:gsub("^/system", "SYSTEM:", 1)
  path = path:gsub("^(%u+:)//+", "%1:/")
  return path
end

local function imageCandidates(path)
  path = normalizeImagePath(path)
  if not path then return {} end

  local candidates = {path}
  if not path:match("^[A-Z]+:") and not path:match("^/") then
    candidates[#candidates + 1] = "BITMAPS:" .. path
    candidates[#candidates + 1] = "SYSTEM:" .. path
  end

  local count = #candidates
  for i = 1, count do
    local candidate = candidates[i]
    if candidate:match("%.png$") then
      candidates[#candidates + 1] = candidate:gsub("%.png$", ".bmp")
    elseif candidate:match("%.bmp$") then
      candidates[#candidates + 1] = candidate:gsub("%.bmp$", ".png")
    end
  end

  return candidates
end

local function fileExists(path)
  path = normalizeImagePath(path)
  if not path or not os or not os.stat then return false end
  return os.stat(path) ~= nil
end

local function loadBitmap(path)
  path = normalizeImagePath(path)
  if not path then return nil end
  if lcd.loadBitmap then return lcd.loadBitmap(path) end
  if Bitmap and Bitmap.open then return Bitmap.open(path) end
  return nil
end

function context.utils.loadImage(image1, image2, image3)
  local images = {image1, image2, image3}
  for i = 1, 3 do
    local image = normalizeImagePath(images[i])
    if image then
      local cachedBitmap = imageBitmapCache[image]
      if cachedBitmap then return cachedBitmap end

      local path = imagePathCache[image]
      if path == nil then
        for _, candidate in ipairs(imageCandidates(image)) do
          if fileExists(candidate) then
            path = normalizeImagePath(candidate)
            break
          end
        end
        imagePathCache[image] = path or false
      elseif path == false then
        path = nil
      end

      if path then
        local bitmap = loadBitmap(path)
        if bitmap then
          imageBitmapCache[image] = bitmap
          return bitmap
        end
      end
    end
  end

  return nil
end

-- Model-photo images (widgets/dashboard/objects/image/model.lua) are the
-- only bitmaps this suite loads from a user-supplied, unconverted file
-- rather than its own bundled assets. Decoding an oversized one happens
-- synchronously inside that object's single wakeup() call -- which is only
-- ever one of a handful budgeted per tick during dashboard warm-up (see
-- dashboard.lua's STARTUP_PREP_OBJECTS_PER_TICK) -- so one big photo can by
-- itself burn through Ethos's whole per-tick Lua instruction budget and
-- trip its runaway-script guard, regardless of that per-tick object count
-- limit. This was previously a stub that always returned false: the
-- maxBytes plumbing already ran end to end (model.lua -> utils.isImageTooLarge
-- -> here) but nothing ever checked an actual size, so nothing was ever
-- rejected. No config surface currently supplies maxBytes (model.lua reads
-- it from rfsuite.config.maxModelImageBytes, which is never set), hence the
-- built-in default below.
local DEFAULT_MAX_IMAGE_BYTES = 250 * 1024

function context.utils.isImageTooLarge(path, maxBytes)
  path = normalizeImagePath(path)
  if not path or not os or not os.stat then return false end
  local info = os.stat(path)
  local size = info and tonumber(info.size)
  if not size then return false end
  return size > (tonumber(maxBytes) or DEFAULT_MAX_IMAGE_BYTES)
end

local ARMING_DISABLE_FLAG_TAG = {
  [0] = "@i18n(app.modules.fblstatus.arming_disable_flag_0)@",
  [1] = "@i18n(app.modules.fblstatus.arming_disable_flag_1)@",
  [2] = "@i18n(app.modules.fblstatus.arming_disable_flag_2)@",
  [3] = "@i18n(app.modules.fblstatus.arming_disable_flag_3)@",
  [4] = "@i18n(app.modules.fblstatus.arming_disable_flag_4)@",
  [5] = "@i18n(app.modules.fblstatus.arming_disable_flag_5)@",
  [6] = "@i18n(app.modules.fblstatus.arming_disable_flag_6)@",
  [7] = "@i18n(app.modules.fblstatus.arming_disable_flag_7)@",
  [8] = "@i18n(app.modules.fblstatus.arming_disable_flag_8)@",
  [9] = "@i18n(app.modules.fblstatus.arming_disable_flag_9)@",
  [10] = "@i18n(app.modules.fblstatus.arming_disable_flag_10)@",
  [11] = "@i18n(app.modules.fblstatus.arming_disable_flag_11)@",
  [12] = "@i18n(app.modules.fblstatus.arming_disable_flag_12)@",
  [13] = "@i18n(app.modules.fblstatus.arming_disable_flag_13)@",
  [14] = "@i18n(app.modules.fblstatus.arming_disable_flag_14)@",
  [15] = "@i18n(app.modules.fblstatus.arming_disable_flag_15)@",
  [16] = "@i18n(app.modules.fblstatus.arming_disable_flag_16)@",
  [17] = "@i18n(app.modules.fblstatus.arming_disable_flag_17)@",
  [18] = "@i18n(app.modules.fblstatus.arming_disable_flag_18)@",
  [19] = "@i18n(app.modules.fblstatus.arming_disable_flag_19)@",
  [20] = "@i18n(app.modules.fblstatus.arming_disable_flag_20)@",
  [21] = "@i18n(app.modules.fblstatus.arming_disable_flag_21)@",
  [22] = "@i18n(app.modules.fblstatus.arming_disable_flag_22)@",
  [23] = "@i18n(app.modules.fblstatus.arming_disable_flag_23)@",
  [24] = "@i18n(app.modules.fblstatus.arming_disable_flag_24)@",
  [25] = "@i18n(app.modules.fblstatus.arming_disable_flag_25)@",
}

-- Bit 0 (ARMED) is the only bit that reflects current arm state -- bits 1
-- (WAS_EVER_ARMED) and 2 (WAS_ARMED_WITH_PREARM, firmware
-- src/main/fc/runtime_config.h) are historical/informational and get set
-- alongside ARMED once a model has been armed at least once (and,
-- separately, once PREARM has ever been used), so a whole-byte whitelist
-- like {1, 3} stops matching as soon as either of those accumulates (e.g.
-- PREARM users see 5, then 7 -- both still armed, bit 0 still set).
function context.utils.armFlagsToIsArmed(value)
  value = tonumber(value)
  if value == nil then return nil end
  return (math.floor(value) & 1) == 1
end

function context.utils.armingDisableFlagsToString(flags)
  flags = tonumber(flags)
  if flags == nil or flags == 0 then return "OK" end

  local names = {}
  for i = 0, 25 do
    if (flags & (1 << i)) ~= 0 then
      local name = ARMING_DISABLE_FLAG_TAG[i]
      if name and name ~= "" then names[#names + 1] = name end
    end
  end

  if #names == 0 then return "OK" end

  return table.concat(names, ", ")
end

function context.widgets.dashboard.getPreference(key)
  return dashboardPrefs[key]
end

function context.widgets.dashboard.savePreference(key, value)
  dashboardPrefs[key] = value
end

function context.widgets.dashboard.setPreferences(values)
  dashboardPrefs = {}
  if type(values) == "table" then
    for key, value in pairs(values) do dashboardPrefs[key] = value end
  end
end

function context.widgets.dashboard.preferences()
  local values = {}
  for key, value in pairs(dashboardPrefs) do values[key] = value end
  return values
end

function context.setWidget(widget)
  currentWidget = widget
  local settings = widget and widget.settingsSnapshot
  context.preferences.general = settings and settings.general or context.preferences.general
  context.preferences.dashboard = settings and settings.dashboard or context.preferences.dashboard
  context.tasks.telemetry.sensorStats = widget and widget.dashboardStats or nil
  context.session.isConnected = widget and widget.connected == true
  context.session.connected = context.session.isConnected
  context.session.isArmed = widget and widget.isArmed == true
  context.session.telemetryState = context.session.isConnected
  context.session.mcu_id = widget and widget.mcuId
  context.session.craftName = widget and widget.craftName
  context.session.apiVersion = widget and widget.rfVersion
  context.session.timer.live = widget and widget.timerLive or 0
  context.session.bblFlags = widget and widget.bblFlags
  context.session.bblSize = widget and widget.bblSize
  context.session.bblUsed = widget and widget.bblUsed
  context.session.headspeedVariancePct = widget and widget.headspeedVariancePct
  context.session.modelPreferences = {
    general = {
      flightcount = widget and widget.modelStats and widget.modelStats.flightcount or 0,
      totalflighttime = widget and widget.modelStats and widget.modelStats.totalflighttime or 0,
      lastflighttime = widget and widget.modelStats and widget.modelStats.lastflighttime or 0,
    },
  }
  context.flightmode.current = widget and widget.flightmodeState or "preflight"
end

context.widgets.dashboard.utils = utils

package.loaded["rfsuite.dashboard.context"] = context
return context
