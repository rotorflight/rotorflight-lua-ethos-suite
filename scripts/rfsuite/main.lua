--[[
 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * Note. Some icons have been sourced from https://www.flaticon.com/
]]

-- Global namespace for the suite
rfsuite = {}
rfsuite.session = {}

-- Ensure legacy font (ethos 1.6 vs 1.7)
if not FONT_M then FONT_M = FONT_STD end

--======================
-- Configuration
--======================
local config = {
  toolName = "Rotorflight",
  icon = lcd.loadMask("app/gfx/icon.png"),
  icon_logtool = lcd.loadMask("app/gfx/icon_logtool.png"),
  icon_unsupported = lcd.loadMask("app/gfx/unsupported.png"),
  version = { major = 2, minor = 3, revision = 0, suffix = "20250731" },
  ethosVersion = { 1, 6, 2 }, -- min supported Ethos version
  supportedMspApiVersion = { "12.07", "12.08", "12.09" },
  baseDir = "rfsuite",
  preferences = "rfsuite.user", -- user preferences folder location
  defaultRateProfile = 4, -- ACTUAL
  watchdogParam = 10, -- progress box timeout
}

-- Pre-format minimum version string once
config.ethosVersionString = string.format("ETHOS < V%d.%d.%d", table.unpack(config.ethosVersion))

rfsuite.config = config

--======================
-- Preferences / INI
--======================
rfsuite.ini = assert(loadfile("lib/ini.lua"))(config) -- self-contained; never compiled

local userpref_defaults = {
  general = {
    iconsize = 2,
    syncname = false,
    gimbalsupression = 0.85,
    txbatt_type = 0,
  },
  localizations = {
    temperature_unit = 0, -- 0 = Celsius, 1 = Fahrenheit
    altitude_unit = 0, -- 0 = meters, 1 = feet
  },
  dashboard = {
    theme_preflight = "system/default",
    theme_inflight = "system/default",
    theme_postflight = "system/default",
  },
  events = {
    armflags = true,
    voltage = true,
    governor = true,
    pid_profile = true,
    rate_profile = true,
    esc_temp = false,
    escalertvalue = 90,
    smartfuel = true,
    smartfuelcallout = 0,
    smartfuelrepeats = 1,
    smartfuelhaptic = false,
    adj_v = false,
    adj_f = false,
  },
  switches = {},
  developer = {
    compile = true, -- compile the script
    devtools = false, -- show dev tools menu
    logtofile = false, -- log to file
    loglevel = "off", -- off, info, debug
    logmsp = false, -- print msp byte stream
    logobjprof = false, -- periodic print object references
    logmspQueue = false, -- periodic print the msp queue size
    memstats = false, -- periodic print memory usage
    taskprofiler = false, -- periodic print task profile
    mspexpbytes = 8,
    apiversion = 2, -- msp api version to use for simulator
    overlaystats = false, -- show cpu load in overlay
    overlaygrid = false, -- show overlay grid
  },
  timer = {
    timeraudioenable = false,
    elapsedalertmode = 0,
    prealerton = false,
    postalerton = false,
    prealertinterval = 10,
    prealertperiod = 30,
    postalertinterval = 10,
    postalertperiod = 30,
  },
  menulastselected = {},
}

-- Build paths once
local prefs_dir = "SCRIPTS:/" .. rfsuite.config.preferences
os.mkdir(prefs_dir)
local userpref_file = prefs_dir .. "/preferences.ini"

-- Load and merge
local master_ini = rfsuite.ini.load_ini_file(userpref_file) or {}
local updated_ini = rfsuite.ini.merge_ini_tables(master_ini, userpref_defaults)
rfsuite.preferences = updated_ini

-- Save only if the merged result differs from the on-disk data
if not rfsuite.ini.ini_tables_equal(master_ini, updated_ini) then
  rfsuite.ini.save_ini_file(userpref_file, updated_ini)
end

--======================
-- Core modules
--======================
rfsuite.config.bgTaskName = rfsuite.config.toolName .. " [Background]"
rfsuite.config.bgTaskKey = "rf2bg"

rfsuite.compiler = assert(loadfile("lib/compile.lua"))(rfsuite.config)

-- Shared lazy loader to defer module creation until first use,
-- but promote to eager-all on first touch.
local function rf_lazy_module(path, arg, compile_loadfile, post_init)
  local real  -- actual module table (created on first use)
  local function ensure()
    if not real then
      local chunk = assert(compile_loadfile(path), "failed to load: "..path)
      real = assert(chunk)(arg)
      if post_init then post_init(real) end
      -- First touch of any module => eagerly initialize the rest
      rfsuite._try_eager_init("lazy-touch:" .. tostring(path))
      collectgarbage()
    end
  end
  local proxy = {}
  proxy.__ensure = ensure
  proxy.__is_proxy = true
  return setmetatable(proxy, {
    __index    = function(_, k) ensure(); return real[k] end,
    __newindex = function(_, k, v) ensure(); real[k] = v end,
    __call     = function(_, ...) ensure(); return real(...) end,
    __pairs    = function() ensure(); return pairs(real) end,
  })
end

-- Reentrancy-safe eager init trigger (runs at most once)
rfsuite._eager_started = false
function rfsuite._try_eager_init(reason)
  if rfsuite._eager_started then return end
  rfsuite._eager_started = true
  if rfsuite.eager_init then
    rfsuite.eager_init(reason or "first-touch")
  else
    -- If init() hasn't defined eager_init yet, defer until it exists.
    -- We keep the flag true so subsequent calls don't double-trigger.
    rfsuite._pending_eager_reason = reason or "first-touch"
  end
end

rfsuite.i18n = assert(rfsuite.compiler.loadfile("lib/i18n.lua"))(rfsuite.config)
rfsuite.i18n.load()

rfsuite.utils = assert(rfsuite.compiler.loadfile("lib/utils.lua"))(rfsuite.config)

rfsuite.app   = rf_lazy_module("app/app.lua",    rfsuite.config, rfsuite.compiler.loadfile)

rfsuite.tasks = rf_lazy_module("tasks/tasks.lua", rfsuite.config, rfsuite.compiler.loadfile)

-- Flight mode & session
rfsuite.flightmode = { current = "preflight" }
rfsuite.utils.session() -- reset session state

-- Simulator hooks
rfsuite.simevent = { telemetry_state = true }

--======================
-- Public: version API
--======================
function rfsuite.version()
  local v = rfsuite.config.version
  return {
    version = string.format("%d.%d.%d-%s", v.major, v.minor, v.revision, v.suffix),
    major = v.major,
    minor = v.minor,
    revision = v.revision,
    suffix = v.suffix,
  }
end

--======================
-- Init / Registration
--======================
local function unsupported_tool()
  return {
    name = rfsuite.config.toolName,
    icon = rfsuite.config.icon_unsupported,
    create = function() end,
    wakeup = function()
      lcd.invalidate()
    end,
    paint = function()
      local w, h = lcd.getWindowSize()
      lcd.color(lcd.RGB(255, 255, 255, 1))
      lcd.font(FONT_M)
      local msg = rfsuite.config.ethosVersionString
      local tw, th = lcd.getTextSize(msg)
      lcd.drawText((w - tw) / 2, (h - th) / 2, msg)
    end,
    close = function() end,
  }
end

local function register_main_tool()
  system.registerSystemTool({
    event = rfsuite.app.event,
    name = rfsuite.config.toolName,
    icon = rfsuite.config.icon,
    create = rfsuite.app.create,
    wakeup = rfsuite.app.wakeup,
    paint = rfsuite.app.paint,
    close = rfsuite.app.close,
  })
end

local function register_bg_task()
  -- wrap task init so we can eagerly warm app + widgets when bg task starts
  local function bg_init_wrapper(...)
    if rfsuite.eager_init then rfsuite.eager_init("bgtask") end
    return rfsuite.tasks.init(...)
  end
  system.registerTask({
    name = rfsuite.config.bgTaskName,
    key = rfsuite.config.bgTaskKey,
    wakeup = rfsuite.tasks.wakeup,
    event = rfsuite.tasks.event,
    init = bg_init_wrapper,
    read = rfsuite.tasks.read,
    write = rfsuite.tasks.write,
  })
end

local function load_widget_cache(cachePath)
  local loadf, loadErr = rfsuite.compiler.loadfile(cachePath)
  if not loadf then
    rfsuite.utils.log("[cache] loadfile failed: " .. tostring(loadErr), "info")
    return nil
  end
  local ok, cached = pcall(loadf)
  if not ok then
    rfsuite.utils.log("[cache] execution failed: " .. tostring(cached), "info")
    return nil
  end
  if type(cached) ~= "table" then
    rfsuite.utils.log("[cache] unexpected content; rebuilding", "info")
    return nil
  end
  rfsuite.utils.log("[cache] Loaded widget list from cache", "info")
  return cached
end

local function build_widget_cache(widgetList, cacheFile)
  rfsuite.utils.createCacheFile(widgetList, cacheFile, true)
  rfsuite.utils.log("[cache] Created new widgets cache file", "info")
end

local function register_widgets(widgetList)
  rfsuite.widgets = {}
  local dupCount = {}

  for _, v in ipairs(widgetList) do
    if v.script then
      local path = "widgets/" .. v.folder .. "/" .. v.script
      local scriptModule = assert(rfsuite.compiler.loadfile(path))(config)

      local base = v.varname or v.script:gsub("%.lua$", "")
      if rfsuite.widgets[base] then
        dupCount[base] = (dupCount[base] or 0) + 1
        base = string.format("%s_dup%02d", base, dupCount[base])
      end
      rfsuite.widgets[base] = scriptModule

      system.registerWidget({
        name = v.name,
        key = v.key,
        event = scriptModule.event,
        create = scriptModule.create,
        paint = scriptModule.paint,
        wakeup = scriptModule.wakeup,
        build = scriptModule.build,
        close = scriptModule.close,
        configure = scriptModule.configure,
        read = scriptModule.read,
        write = scriptModule.write,
        persistent = scriptModule.persistent or false,
        menu = scriptModule.menu,
        title = scriptModule.title,
      })
    end
  end
end

local function init()
  
  local cfg = rfsuite.config

  -- Bail early if Ethos is too old
  if not rfsuite.utils.ethosVersionAtLeast() then
    system.registerSystemTool(unsupported_tool())
    return
  end

  register_main_tool()
  register_bg_task()

  -- Widgets: try cache, else rebuild
  local cacheFile = "widgets.lua"
  local cachePath = "cache/" .. cacheFile
  local widgetList = load_widget_cache(cachePath)

  if not widgetList then
    widgetList = rfsuite.utils.findWidgets()
    build_widget_cache(widgetList, cacheFile)
  end

  rfsuite._widget_proxies = {}

-- Override register_widgets with a lazy-loading version
register_widgets = function(widgetList)
  rfsuite.widgets = {}
  local dupCount = {}

  local function make_widget_proxy(path)
  local mod
  local function ensure()
    if not mod then
      mod = assert(rfsuite.compiler.loadfile(path))(config)
      -- First touch of any widget => eagerly initialize the rest
      rfsuite._try_eager_init("widget-touch:" .. tostring(path))
    end
  end
  local function opt(name)
    return function(...)
      ensure()
      local f = mod[name]
      if f then return f(...) end
    end
  end
  local proxy = {
    event     = opt("event"),
    create    = opt("create"),
    paint     = opt("paint"),
    wakeup    = opt("wakeup"),
    build     = opt("build"),
    close     = opt("close"),
    configure = opt("configure"),
    read      = opt("read"),
    write     = opt("write"),
    get_title = function() ensure(); return mod.title end,
    get_menu  = function() ensure(); return mod.menu end,
    get_persistent = function() ensure(); return mod.persistent end,
  }
  proxy.__ensure = ensure
  proxy.__is_proxy = true
  table.insert(rfsuite._widget_proxies, proxy)
  return proxy
end

  for _, v in ipairs(widgetList) do
    if v.script then
      local path = "widgets/" .. v.folder .. "/" .. v.script
      local proxy = make_widget_proxy(path)

      local base = v.varname or v.script:gsub("%.lua$", "")
      if rfsuite.widgets[base] then
        dupCount[base] = (dupCount[base] or 0) + 1
        base = string.format("%s_dup%02d", base, dupCount[base])
      end
      rfsuite.widgets[base] = proxy

      system.registerWidget({
        name       = v.name,
        key        = v.key,
        event      = proxy.event,
        create     = proxy.create,
        paint      = proxy.paint,
        wakeup     = proxy.wakeup,
        build      = proxy.build,
        close      = proxy.close,
        configure  = proxy.configure,
        read       = proxy.read,
        write      = proxy.write,
        -- persistent must be a boolean at registration time; default to false
        -- (if a widget truly needs persistence, we can force an early ensure here and
        -- read mod.persistent, but most widgets are fine with false)
        persistent = false,

        -- Defer menu/title to the real module once loaded:
        menu = function(...)
          local m = proxy.get_menu and proxy.get_menu()
          if type(m) == "function" then
            return m(...)
          end
          -- if menu is not a function, Ethos expects nil or a function; return nothing
        end,

        title = v.title,
      })

    end
  end
end

register_widgets(widgetList)

  ------------------------------------------------------------------
  -- Eager init: fully load the app + all widgets on bg task start --
  ------------------------------------------------------------------
  function rfsuite.eager_init(reason)
    -- 1) App module
    if rfsuite.app and rfsuite.app.__ensure then
      rfsuite.app.__ensure()
    end
    -- 2) All widget modules
    if rfsuite._widget_proxies then
      for _, p in ipairs(rfsuite._widget_proxies) do
        if p and p.__ensure then p.__ensure() end
      end
    end
    if rfsuite.utils and rfsuite.utils.log then
      rfsuite.utils.log(string.format("[init] eager_init (%s): app+widgets ready", tostring(reason)), "info")
    end
  end

  -- If a first-touch happened before eager_init existed, honor it now
  if rfsuite._eager_started and rfsuite._pending_eager_reason then
    local why = rfsuite._pending_eager_reason
    rfsuite._pending_eager_reason = nil
    rfsuite.eager_init(why .. " (deferred)")
  end  

end



return { init = init }
