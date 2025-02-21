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

-- LuaFormatter off

-- Configuration settings for the Rotorflight Lua Ethos Suite
config.toolName = "Rotorflight"                                     -- name of the tool
config.icon = lcd.loadMask("app/gfx/icon.png")                      -- icon
config.icon_logtool = lcd.loadMask("app/gfx/icon_logtool.png")      -- icon
config.Version = "1.0.0"                                            -- version number of this software replace
config.ethosVersion = {1, 6, 2}                                     -- min version of ethos supported by this script                                                     
config.supportedMspApiVersion = {"12.06", "12.07","12.08"}          -- supported msp versions
config.simulatorApiVersionResponse = {0, 12, 8}                     -- version of api return by simulator
config.logLevel= "info"                                             -- off | info | debug [default = info]
config.logToFile = false                                            -- log to file [default = false] (log file is in /scripts/rfsuite/logs)
config.developerMode = false                                        -- show developer tools on main menu [default = false]

-- RotorFlight + ETHOS LUA preferences
local preferences = {}

-- Configuration options that adjust behavior of the script (will be moved to a settings menu in the future)
preferences.flightLog = true                                        -- will write a flight log into /scripts/rfsuite/logs/<modelname>/*.log
preferences.reloadOnSave = false                                    -- trigger a reload on save [default = false]
preferences.skipRssiSensorCheck = false                             -- skip checking for a valid rssi [ default = false]
preferences.internalElrsSensors = true                              -- disable the integrated elrs telemetry processing [default = true]
preferences.internalSportSensors = true                             -- disable the integrated smart port telemetry processing [default = true]
preferences.adjFunctionAlerts = false                               -- do not alert on adjfunction telemetry.  [default = false]
preferences.adjValueAlerts = true                                   -- play adjvalue alerts if sensor changes [default = true]  
preferences.saveWhenArmedWarning = true                             -- do not display the save when armed warning. [default = true]
preferences.audioAlerts = 1                                         -- 0 = all, 1 = alerts, 2 = disable [default = 1]
preferences.profileSwitching = true                                 -- enable auto profile switching [default = true]
preferences.iconSize = 1                                            -- 0 = text, 1 = small, 2 = large [default = 1]
preferences.soundPack = nil                                         -- use an custom sound pack. [default = nil]
preferences.syncCraftName = false                                   -- sync the craft name with the model name [default = false]
preferences.mspExpBytes = 8                                         -- number of bytes for msp_exp [default = 8] 
preferences.defaultRateProfile = 4 -- ACTUAL                        -- default rate table [default = 4]
preferences.watchdogParam = 10                                      -- watchdog timeout for progress boxes [default = 10]
preferences.simProfileSwiching  = true                              -- enable auto profile switching in simulator[default = true]

-- tasks
config.bgTaskName = config.toolName .. " [Background]"              -- background task name for msp services etc
config.bgTaskKey = "rf2bg"                                          -- key id used for msp services

-- LuaFormatter on

-- main
-- rfsuite: Main table for the rotorflight-lua-ethos-suite script.
-- rfsuite.config: Configuration table for the suite.
-- rfsuite.session: Session table for the suite.
-- rfsuite.app: Application module loaded from "app/app.lua" with the provided configuration.
rfsuite = {}
rfsuite.config = config
rfsuite.preferences = preferences
rfsuite.session = {}
rfsuite.app = assert(loadfile("app/app.lua"))(config)

-- 
-- This script initializes the logging configuration for the rfsuite module.
-- 
-- The logging configuration is loaded from the "lib/log.lua" file and is 
-- customized based on the provided configuration (`config`).
-- 
-- The log file is named using the current date and time in the format 
-- "logs/rfsuite_YYYY-MM-DD_HH-MM-SS.log".
-- 
-- The minimum print level for logging is set from `config.logLevel`.
-- 
-- The option to log to a file is set from `config.logToFile`.
-- 
-- If the system is running in simulation mode, the log print interval is 
-- set to 0.1 seconds.
-- logging
rfsuite.log = assert(loadfile("lib/log.lua"))(config)
rfsuite.log.config.log_file = "logs/rfsuite_" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".log"
rfsuite.log.config.min_print_level  = config.logLevel
rfsuite.log.config.log_to_file = config.logToFile


-- library with utility functions used throughou the suite
rfsuite.utils = assert(loadfile("lib/utils.lua"))(config)

-- 
-- This script initializes the `rfsuite` tasks and background task.
-- 
-- The `rfsuite.tasks` table is created to hold various tasks.
-- The `rfsuite.bg` is assigned the result of executing the "tasks/bg.lua" file with the `config` parameter.
-- The `loadfile` function is used to load the "tasks/bg.lua" file, and `assert` ensures that the file is loaded successfully.
-- The loaded file is then executed with the `config` parameter, and its return value is assigned to `rfsuite.bg`.
-- tasks
rfsuite.tasks = {}
rfsuite.bg = assert(loadfile("tasks/bg.lua"))(config)

-- LuaFormatter off

--[[
    Initializes the main script for the rotorflight-lua-ethos-suite.

    This function performs the following tasks:
    1. Checks if the Ethos version is supported using `rfsuite.utils.ethosVersionAtLeast()`.
       If the version is not supported, it raises an error and stops execution.
    2. Registers system tools using `system.registerSystemTool()` with configurations from `config`.
    3. Registers a background task using `system.registerTask()` with configurations from `config`.
    4. Dynamically loads and registers widgets:
       - Finds widget scripts using `rfsuite.utils.findWidgets()`.
       - Loads each widget script dynamically using `loadfile()`.
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
    - `loadfile()`
    - `system.registerWidget()`
]]
local function init()

    -- prevent this even getting close to running if version is not good
    if not rfsuite.utils.ethosVersionAtLeast() then
        error("Ethos version is not supported")
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
        wakeup = rfsuite.bg.wakeup,
        event = rfsuite.bg.event
    })

    -- widgets are loaded dynamically
    local widgetList = rfsuite.utils.findWidgets()

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
    for i, v in ipairs(widgetList) do
        if v.script then
            -- Dynamically assign the loaded script to a variable inside rfsuite table
            local scriptModule = assert(loadfile("widgets/" .. v.folder .. "/" .. v.script))(config)

            -- Use the script name as a key to store in rfsuite dynamically
            -- Assuming v.name is a valid Lua identifier-like string (without spaces or special characters)
            local varname = v.varname or v.script:gsub(".lua", "")
            rfsuite[varname] = scriptModule

            -- Now register the widget with dynamically assigned variable
            system.registerWidget({
                name = v.name,
                key = v.key,
                event = scriptModule.event,      -- Reference dynamically assigned module
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
