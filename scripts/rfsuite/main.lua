--[[

 * Copyright (C) Rotorflight Project
 *
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
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]] --
-- RotorFlight + ETHOS LUA configuration
local config = {}

-- Configuration settings for the Rotorflight Lua Ethos Suite
config.toolName = "Rotorflight"                                         -- name of the tool 
config.icon = lcd.loadMask("app/gfx/icon.png")                          -- icon
config.icon_logtool = lcd.loadMask("app/gfx/icon_logtool.png")          -- icon
config.icon_unsupported = lcd.loadMask("app/gfx/unsupported.png")       -- icon
config.version = {major = 2, minor = 2, revision = 0, suffix = "RC4"}   -- version of the script
config.ethosVersion = {1, 6, 2}                                         -- min version of ethos supported by this script                                                     
config.supportedMspApiVersion = {"12.06", "12.07","12.08"}              -- supported msp versions
config.simulatorApiVersionResponse = {0, 12, 8}                         -- version of api return by simulator
config.baseDir = "rfsuite"                                              -- base directory for the suite. This is only used by msp api to ensure correct path
config.logLevel= "info"                                                 -- off | info | debug [default = info]
config.logToFile = false                                                -- log to file [default = false] (log file is in /scripts/rfsuite/logs)
config.logMSP = false                                                   -- log msp messages [default =  false]
config.logMSPQueue = false                                              -- log msp queue size [default = false]
config.logMemoryUsage = false                                           -- log memory usage [default = false]
config.developerMode = false                                            -- show developer tools on main menu [default = false]
config.compile = true                                                   -- use the compiler [default = true]
config.compilerTiming = false                                           -- log compiler timings [default = false]

-- RotorFlight + ETHOS LUA preferences
local preferences = {}

-- Configuration options that adjust behavior of the script (will be moved to a settings menu in the future)
preferences.flightLog = true                                        -- will write a flight log into /scripts/rfsuite/logs/<modelname>/*.log
preferences.reloadOnSave = false                                    -- trigger a reload on save [default = false]
preferences.internalElrsSensors = true                              -- disable the integrated elrs telemetry processing [default = true]
preferences.internalSportSensors = true                             -- disable the integrated smart port telemetry processing [default = true]
preferences.internalSimSensors = true                               -- disable the integrated simulator telemetry processing [default = true]
preferences.adjFunctionAlerts = false                               -- do not alert on adjfunction telemetry.  [default = false]
preferences.adjValueAlerts = true                                   -- play adjvalue alerts if sensor changes [default = true]  
preferences.saveWhenArmedWarning = true                             -- do not display the save when armed warning. [default = true]
preferences.audioAlerts = 1                                         -- 0 = all, 1 = alerts, 2 = disable [default = 1]
preferences.profileSwitching = true                                 -- enable auto profile switching [default = true]
preferences.iconSize = 1                                            -- 0 = text, 1 = small, 2 = large [default = 1]
preferences.syncCraftName = false                                   -- sync the craft name with the model name [default = false]
preferences.mspExpBytes = 8                                         -- number of bytes for msp_exp [default = 8] 
preferences.defaultRateProfile = 4 -- ACTUAL                        -- default rate table [default = 4]
preferences.watchdogParam = 10                                      -- watchdog timeout for progress boxes [default = 10]
preferences.spreadScheduling = true                                 -- false = all tasks run on all cycles.  true = tasks are spread over multiple cycles. [default = true]

-- tasks
config.bgTaskName = config.toolName .. " [Background]"              -- background task name for msp services etc
config.bgTaskKey = "rf2bg"                                          -- key id used for msp services


--- Checks if the `developerMode` is disabled in the `config` table.
--- If disabled, attempts to enable it by checking for the existence of a 
--- file named `../developermode`. If the file exists, it sets 
--- `config.developerMode` to `true`.
---
--- Note:
--- - The file path `../developermode` is relative to the script's execution directory.
--- - This functionality is likely used to toggle developer-specific features 
---   during runtime.
if not config.developerMode then
    local f = io.open("../developermode", "r")
    if f then
        io.close(f)
        config.developerMode = true
    end
end


-- main
-- rfsuite: Main table for the rotorflight-lua-ethos-suite script.
-- rfsuite.config: Configuration table for the suite.
-- rfsuite.session: Session table for the suite.
-- rfsuite.app: Application module loaded from "app/app.lua" with the provided configuration.
rfsuite = {}
rfsuite.config = config
rfsuite.preferences = preferences
rfsuite.session = {}
rfsuite.compiler = assert(loadfile("lib/compile.lua"))(config) 
rfsuite.app = assert(rfsuite.compiler.loadfile("app/app.lua"))(config)



-- library with utility functions used throughou the suite
rfsuite.utils = assert(rfsuite.compiler.loadfile("lib/utils.lua"))(config)


-- Load the i18n system
rfsuite.i18n  = assert(rfsuite.compiler.loadfile("lib/i18n.lua"))(config)
rfsuite.i18n.load()     

-- 
-- This script initializes the `rfsuite` tasks and background task.
-- 
-- The `rfsuite.tasks` table is created to hold various tasks.
-- The `rfsuite.tasks` is assigned the result of executing the "tasks/tasks.lua" file with the `config` parameter.
-- The `rfsuite.compiler.loadfile` function is used to load the "tasks/tasks.lua" file, and `assert` ensures that the file is loaded successfully.
-- The loaded file is then executed with the `config` parameter, and its return value is assigned to `rfsuite.tasks`.
-- tasks
rfsuite.tasks = assert(rfsuite.compiler.loadfile("tasks/tasks.lua"))(config)

-- LuaFormatter off


--[[
This script initializes various session parameters for the rfsuite application to nil.
The parameters include:
- tailMode: Mode for the tail rotor.
- swashMode: Mode for the swashplate.
- activeProfile: Currently active profile.
- activeRateProfile: Currently active rate profile.
- activeProfileLast: Last active profile.
- activeRateLast: Last active rate profile.
- servoCount: Number of servos.
- servoOverride: Override setting for servos.
- clockSet: Clock setting.
- apiVersion: Version of the API.
- lastLabel: Last label used.
- rssiSensor: RSSI sensor value.
- formLineCnt: Form line count.
- rateProfile: Rate profile.
- governorMode: Mode for the governor.
- ethosRunningVersion: Version of the Ethos running.
- lcdWidth: Width of the LCD.
- lcdHeight: Height of the LCD.
- mspSignature - uses for mostly in sim to save esc type
- telemetryType = sport or crsf
- repairSensors: makes the background task repair sensors
- lastMemoryUsage.  Used to track memory usage for debugging
- 

-- Every attempt should be made if using session vars to record them here with a nil
-- to prevent conflicts with other scripts that may use the same session vars.
]]
rfsuite.session.tailMode = nil
rfsuite.session.swashMode = nil
rfsuite.session.activeProfile = nil
rfsuite.session.activeRateProfile = nil
rfsuite.session.activeProfileLast = nil
rfsuite.session.activeRateLast = nil
rfsuite.session.servoCount = nil
rfsuite.session.servoOverride = nil
rfsuite.session.clockSet = nil
rfsuite.session.apiVersion = nil
rfsuite.session.activeProfile = nil
rfsuite.session.activeRateProfile = nil
rfsuite.session.activeProfileLast = nil
rfsuite.session.activeRateLast = nil
rfsuite.session.servoCount = nil
rfsuite.session.servoOverride = nil
rfsuite.session.clockSet = nil
rfsuite.session.lastLabel = nil
rfsuite.session.tailMode = nil
rfsuite.session.swashMode = nil
rfsuite.session.formLineCnt = nil
rfsuite.session.rateProfile = nil
rfsuite.session.governorMode = nil
rfsuite.session.servoOverride = nil
rfsuite.session.ethosRunningVersion = nil
rfsuite.session.lcdWidth = nil
rfsuite.session.lcdHeight = nil
rfsuite.session.mspSignature = nil
rfsuite.session.telemetryState = nil
rfsuite.session.telemetryType = nil
rfsuite.session.telemetryTypeChanged = nil
rfsuite.session.telemetrySensor = nil
rfsuite.session.repairSensors = false
rfsuite.session.locale = system.getLocale()
rfsuite.session.lastMemoryUsage = nil
rfsuite.session.mcu_id = nil


--- Retrieves the version information of the rfsuite module.
--- 
--- This function constructs a version string and returns a table containing
--- detailed version information, including the major, minor, revision, and suffix
--- components.
---
--- @return table A table containing the following fields:
---   - `version` (string): The full version string in the format "X.Y.Z-SUFFIX".
---   - `major` (number): The major version number.
---   - `minor` (number): The minor version number.
---   - `revision` (number): The revision version number.
---   - `suffix` (string): The version suffix (e.g., "alpha", "beta").
function rfsuite.version()
    local version = config.version.major .. "." .. config.version.minor .. "." .. config.version.revision .. "-" .. config.version.suffix
    return {
        version = version,
        major = config.version.major,
        minor = config.version.minor,
        revision = config.version.revision,
        suffix = config.version.suffix
    }
end


--[[
    Initializes the main script for the rotorflight-lua-ethos-suite.

    This function performs the following tasks:
    1. Checks if the Ethos version is supported using `rfsuite.utils.ethosVersionAtLeast()`.
       If the version is not supported, it raises an error and stops execution.
    2. Registers system tools using `system.registerSystemTool()` with configurations from `config`.
    3. Registers a background task using `system.registerTask()` with configurations from `config`.
    4. Dynamically loads and registers widgets:
       - Finds widget scripts using `rfsuite.utils.findWidgets()`.
       - Loads each widget script dynamically using `rfsuite.compiler.loadfile()`.
       - Assigns the loaded script to a variable inside the `rfsuite` table.
       - Registers each widget with `system.registerWidget()` using the dynamically assigned module.

    Note:
    - Assumes `v.name` is a valid Lua identifier-like string (without spaces or special characters).
    - Each widget script is expected to have functions like `event`, `create`, `paint`, `wakeup`, `close`, `configure`, `read`, `write`, and optionally `persistent` and `menu`.

    Throws:
    - Error if the Ethos version is not supported.

    Dependencies:
    - `rfsuite.utils.ethosVersionAtLeast()`
    - `system.registerSystemTool()`
    - `system.registerTask()`
    - `rfsuite.utils.findWidgets()`
    - `rfsuite.compiler.loadfile()`
    - `system.registerWidget()`
]]
local function init()

    -- prevent this even getting close to running if version is not good
    if not rfsuite.utils.ethosVersionAtLeast() then

        system.registerSystemTool({
            name = config.toolName,
            icon = config.icon_unsupported ,
            create = function () end,
            wakeup = function () 
                        lcd.invalidate()
                        return
                     end,
            paint = function () 
                        local w, h = lcd.getWindowSize()
                        local textColor = lcd.RGB(255, 255, 255, 1) 
                        lcd.color(textColor)
                        lcd.font(FONT_STD)
                        local badVersionMsg = string.format("ETHOS < V%d.%d.%d", table.unpack(config.ethosVersion))
                        local textWidth, textHeight = lcd.getTextSize(badVersionMsg)
                        local x = (w - textWidth) / 2
                        local y = (h - textHeight) / 2
                        lcd.drawText(x, y, badVersionMsg)
                        return 
                    end,
            close = function () end,
        })
        return
    end

    -- Registers the main system tool with the specified configuration.
    -- This tool handles events, creation, wakeup, painting, and closing.
    system.registerSystemTool({
        event = rfsuite.app.event,
        name = config.toolName,
        icon = config.icon,
        create = rfsuite.app.create,
        wakeup = rfsuite.app.wakeup,
        paint = rfsuite.app.paint,
        close = rfsuite.app.close
    })

    -- Registers the log tool with the specified configuration.
    -- This tool handles events, creation, wakeup, painting, and closing.
    system.registerSystemTool({
        event = rfsuite.app.event,
        name = config.toolName,
        icon = config.icon_logtool,
        create = rfsuite.app.create_logtool,
        wakeup = rfsuite.app.wakeup,
        paint = rfsuite.app.paint,
        close = rfsuite.app.close
    })

    -- Registers a background task with the specified configuration.
    -- This task handles wakeup and event processing.
    system.registerTask({
        name = config.bgTaskName,
        key = config.bgTaskKey,
        wakeup = rfsuite.tasks.wakeup,
        event = rfsuite.tasks.event
    })

    -- widgets are loaded dynamically
    local cacheFile = "widgets.lua"
    local cachePath = "cache/" .. cacheFile
    local widgetList
    
    -- Try to load from cache if it exists
    if io.open(cachePath, "r") then
        local ok, cached = pcall(dofile, cachePath)
        if ok and type(cached) == "table" then
            widgetList = cached
            rfsuite.utils.log("[cache] Loaded widget list from cache","info")
        else
            rfsuite.utils.log("[cache] Failed to load cache, rebuilding...","info")
        end
    end
    
    -- If no valid cache, build and write new one
    if not widgetList then
        widgetList = rfsuite.utils.findWidgets()
        rfsuite.utils.createCacheFile(widgetList, cacheFile, true)
        rfsuite.utils.log("[cache] Created new widgets cache file","info")
    end

    -- Iterates over the widgetList table and dynamically loads and registers widget scripts.
    -- For each widget in the list:
    -- 1. Checks if the widget has a script defined.
    -- 2. Loads the script file from the specified folder and assigns it to a variable inside the rfsuite table.
    -- 3. Uses the script name (or a provided variable name) as a key to store the loaded script module in the rfsuite table.
    -- 4. Registers the widget with the system using the dynamically assigned module's functions and properties.
    -- 
    -- Parameters:
    -- widgetList - A table containing widget definitions. Each widget should have the following fields:
    --   - script: The filename of the widget script to load.
    --   - folder: The folder where the widget script is located.
    --   - name: The name of the widget.
    --   - key: A unique key for the widget.
    --   - varname (optional): A custom variable name to use for storing the script module in the rfsuite table.
    -- 
    -- The loaded script module should define the following functions and properties (if applicable):
    --   - event: Function to handle events.
    --   - create: Function to create the widget.
    --   - paint: Function to paint the widget.
    --   - wakeup: Function to handle wakeup events.
    --   - close: Function to handle widget closure.
    --   - configure: Function to configure the widget.
    --   - read: Function to read data.
    --   - write: Function to write data.
    --   - persistent: Boolean indicating if the widget is persistent (default is false).
    --   - menu: Menu definition for the widget.
    --   - title: Title of the widget.
    rfsuite.widgets = {}

        for i, v in ipairs(widgetList) do
            if v.script then
                -- Load the script dynamically
                local scriptModule = assert(rfsuite.compiler.loadfile("widgets/" .. v.folder .. "/" .. v.script))(config)
        
                -- Use the script filename (without .lua) as the key, or v.varname if provided
                local varname = v.varname or v.script:gsub("%.lua$", "")
        
                -- Store the module inside rfsuite.widgets
                if rfsuite.widgets[varname] then
                    math.randomseed(os.time())
                    local rand = math.random()
                    rfsuite.widgets[varname .. rand] = scriptModule
                else
                    rfsuite.widgets[varname] = scriptModule
                end    
        
                -- Register the widget with the system
                system.registerWidget({
                    name = v.name,
                    key = v.key,
                    event = scriptModule.event,
                    create = scriptModule.create,
                    paint = scriptModule.paint,
                    wakeup = scriptModule.wakeup,
                    close = scriptModule.close,
                    configure = scriptModule.configure,
                    read = scriptModule.read,
                    write = scriptModule.write,
                    persistent = scriptModule.persistent or false,
                    menu = scriptModule.menu,
                    title = scriptModule.title
                })
            end
        end
    
end    

-- LuaFormatter on

return {init = init}
