--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = {session = {}}
package.loaded.rfsuite = rfsuite

local _ENV = setmetatable({rfsuite = rfsuite}, {__index = _G, __newindex = function(_, k) print("attempt to create global '" .. tostring(k) .. "'", 2) end})

if not FONT_STD then FONT_STD = FONT_STD end

-- LuaFormatter off
local config = {
    toolName = "Rotorflight",
    icon = lcd.loadMask("app/gfx/icon.png"),
    icon_logtool = lcd.loadMask("app/gfx/icon_logtool.png"),
    icon_unsupported = lcd.loadMask("app/gfx/unsupported.png"),
    version = {major = 2, minor = 3, revision = 0, suffix = "20251111"},
    ethosVersion = {1, 6, 2},
    supportedMspApiVersion = {"12.07", "12.08", "12.09", "12.10"},
    baseDir = "rfsuite",
    preferences = "rfsuite.user",
    defaultRateProfile = 6,   -- default, may be overridden in onconnect/tasks/rateprofile.lua
    watchdogParam = 10,
    msp = {
        probeProtocol = 1,
        maxProtocol = 2,
        allowAutoUpgrade = true,
        v2MinApiVersion = {12, 0, 9},
    },
    mspProtocolVersion = 1,
    maxModelImageBytes = 350 * 1024 -- 350KB, to prevent OOM crashes on models with very large images
}
-- LuaFormatter on

config.ethosVersionString = string.format("ETHOS < V%d.%d.%d", table.unpack(config.ethosVersion))

rfsuite.config = config

local performance = {cpuload = 0, freeram = 0, mainStackKB = 0, ramKB = 0, luaRamKB = 0, luaBitmapsRamKB = 0}

rfsuite.performance = performance

rfsuite.ini = assert(loadfile("lib/ini.lua", "t", _ENV))(config)

local userpref_defaults = {
    general = {
        iconsize = 2,
        shortcuts_mixed_in = true,
        syncname = false,
        developer_tools = false,
        gimbalsupression = 0.85,
        txbatt_type = 0,
        hs_loader = 0,
        theme_loader = 1,  
        save_confirm = true,   
        save_dirty_only = true,
        reload_confirm = true,
        mspstatusdialog = true,
        save_armed_warning = true,
        toolbar_timeout = 10
    },
    localizations = {
        temperature_unit = 0,
        altitude_unit = 0
    },
    dashboard = {
        theme_preflight = "system/default",
        theme_inflight = "system/default",
        theme_postflight = "system/default"
    },
    activelook = {
        offset_x = 0,
        offset_y = 0,
        layout_preflight = "stacked_three",
        layout_inflight = "one_top_two_bottom",
        layout_postflight = "two_top_two_bottom",
        preflight_1 = "governor",
        preflight_2 = "armed",
        preflight_3 = "flightmode",
        preflight_4 = "off",
        inflight_1 = "current",
        inflight_2 = "voltage",
        inflight_3 = "fuel",
        inflight_4 = "timer",
        postflight_1 = "current",
        postflight_2 = "voltage",
        postflight_3 = "fuel",
        postflight_4 = "timer"
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
        otherSoundCfg = true,
        otherModelAnnounce = false
    },
    switches = {},
    developer = {
        loglevel = "off",
        logmsp = false,
        logobjprof = false,
        logmspQueue = false,
        logevents = false,
        memstats = false,
        logcachestats = false,
        taskprofiler = false,
        mspexpbytes = 8,
        apiversion = 2,
        tailmode_override = 0,
        overlaystats = false,
        overlaygrid = false,
        overlaystatsadmin = false
    },
    timer = {
        timeraudioenable = false,
        elapsedalertmode = 0,
        prealerton = false,
        postalerton = false,
        prealertinterval = 10,
        prealertperiod = 30,
        postalertinterval = 10,
        postalertperiod = 30
    },
    shortcuts = {},
    menulastselected = {}
}

local prefs_dir = "SCRIPTS:/" .. rfsuite.config.preferences
os.mkdir(prefs_dir)
local userpref_file = prefs_dir .. "/preferences.ini"

local master_ini = rfsuite.ini.load_ini_file(userpref_file) or {}
local updated_ini = rfsuite.ini.merge_ini_tables(master_ini, userpref_defaults)
rfsuite.preferences = updated_ini

-- Migrate legacy developer.mspstatusdialog to general.mspstatusdialog if present
if rfsuite.preferences then
    local gen = rfsuite.preferences.general
    local dev = rfsuite.preferences.developer
    if gen and gen.mspstatusdialog == nil and dev and dev.mspstatusdialog ~= nil then
        gen.mspstatusdialog = dev.mspstatusdialog
    end
end

if not rfsuite.ini.ini_tables_equal(master_ini, updated_ini) then rfsuite.ini.save_ini_file(userpref_file, updated_ini) end

rfsuite.config.bgTaskName = rfsuite.config.toolName .. " [Background]"
rfsuite.config.bgTaskKey = "rf2bg"

rfsuite.utils = assert(loadfile("lib/utils.lua"))(rfsuite.config)
rfsuite.ethos_events = assert(loadfile("lib/ethos_events.lua", "t", _ENV))()

rfsuite.app = assert(loadfile("app/app.lua"))(rfsuite.config)

rfsuite.tasks = assert(loadfile("tasks/tasks.lua"))(rfsuite.config)

rfsuite.flightmode = {current = "preflight"}
rfsuite.utils.session()

rfsuite.simevent = {telemetry_state = true}

rfsuite.sysIndex = {}

function rfsuite.version()
    local v = rfsuite.config.version
    return {version = string.format("%d.%d.%d-%s", v.major, v.minor, v.revision, v.suffix), major = v.major, minor = v.minor, revision = v.revision, suffix = v.suffix}
end

local function unsupported_tool()
    return {
        name = rfsuite.config.toolName,
        icon = rfsuite.config.icon_unsupported,
        create = function() end,
        wakeup = function() lcd.invalidate() end,
        paint = function()
            local w, h = lcd.getWindowSize()
            lcd.color(lcd.RGB(255, 255, 255, 1))
            lcd.font(FONT_STD)
            local msg = rfsuite.config.ethosVersionString
            local tw, th = lcd.getTextSize(msg)
            lcd.drawText((w - tw) / 2, (h - th) / 2, msg)
        end,
        close = function() end
    }
end

local function unsupported_i18n()
    return {
        name = rfsuite.config.toolName,
        icon = rfsuite.config.icon_unsupported,
        create = function() end,
        wakeup = function() lcd.invalidate() end,
        paint = function()
            local w, h = lcd.getWindowSize()
            lcd.color(lcd.RGB(255, 255, 255, 1))
            lcd.font(FONT_STD)
            local msg = "i18n not compiled - download a release version"
            local tw, th = lcd.getTextSize(msg)
            lcd.drawText((w - tw) / 2, (h - th) / 2, msg)
        end,
        close = function() end
    }
end

local function register_main_tool()
    rfsuite.sysIndex['app'] = system.registerSystemTool({
        event  = rfsuite.app.event,
        name   = rfsuite.config.toolName,
        icon   = rfsuite.config.icon,
        create = rfsuite.app.create,
        wakeup = rfsuite.app.wakeup,
        paint  = rfsuite.app.paint,
        close  = rfsuite.app.close
    })
end

local function register_bg_task()
    rfsuite.sysIndex['task'] = system.registerTask({
        name  = rfsuite.config.bgTaskName,
        key   = rfsuite.config.bgTaskKey,
        wakeup = rfsuite.tasks.wakeup,
        event = rfsuite.tasks.event,
        init  = rfsuite.tasks.init,
        read  = rfsuite.tasks.read,
        write = rfsuite.tasks.write
    })
end

local function register_widgets()
    local manifestPath = "widgets/manifest.lua"
    local widgetList = {}

    local chunk = loadfile(manifestPath)
    if chunk then
        local res = chunk()
        if type(res) == "table" then
            widgetList = res
        else
            rfsuite.utils.log("[widgets] manifest did not return a table", "info")
        end
    else
        rfsuite.utils.log("[widgets] manifest not found or load failed", "info")
    end

    rfsuite.widgets = {}
    local dupCount = {}

    for _, v in ipairs(widgetList) do
        if v.script then
            local path = "widgets/" .. v.folder .. "/" .. v.script

            local wchunk = loadfile(path)
            local scriptModule = wchunk and wchunk(config) or nil

            if type(scriptModule) == "table" then
                local base = v.varname or v.script:gsub("%.lua$", "")
                if rfsuite.widgets[base] then
                    dupCount[base] = (dupCount[base] or 0) + 1
                    base = string.format("%s_dup%02d", base, dupCount[base])
                end
                rfsuite.widgets[base] = scriptModule

                if v.type == "glasses" then
                    -- we only register glasses widgets if the system supports them
                    if system.registerGlassesWidget then
                        rfsuite.sysIndex['widget_' .. v.folder] = system.registerGlassesWidget({
                            key = v.key,
                            name = v.name,
                            create = scriptModule.create,
                            build = scriptModule.build,
                            wakeup = scriptModule.wakeup
                        })
                    end
                else
                    rfsuite.sysIndex['widget_' .. v.folder] = system.registerWidget({
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
                        title = scriptModule.title
                    })
                end    
            else
                rfsuite.utils.log("[widgets] widget did not return a module table: " .. path, "info")
            end
        end
    end
end

local function init()
    local cfg = rfsuite.config

    if not rfsuite.utils.ethosVersionAtLeast() then
        system.registerSystemTool(unsupported_tool())
        return
    end

    local isCompiledCheck = "@i18n(iscompiledcheck)@"
    if isCompiledCheck ~= "true" and isCompiledCheck ~= "eurt" then
        system.registerSystemTool(unsupported_i18n())
    else
        register_main_tool()
    end

    -- register background task
    register_bg_task()

    -- register widgets
    register_widgets()
end

return {init = init}
