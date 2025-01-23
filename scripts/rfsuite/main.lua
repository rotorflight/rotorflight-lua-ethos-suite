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
config.toolName = "Rotorflight"                                     -- name of the tool
config.suiteDir = "/scripts/rfsuite/"                               -- base path the script is installed into
config.icon = lcd.loadMask("app/gfx/icon.png")                      -- icon
config.icon_logtool = lcd.loadMask("app/gfx/icon_logtool.png")      -- icon
config.Version = "1.0.0"                                            -- version number of this software release
config.ethosVersion = 1560                                          -- min version of ethos supported by this script
config.ethosVersionString = "ETHOS < V1.6.0"                        -- string to print if ethos version error occurs
config.defaultRateProfile = 4 -- ACTUAL                             -- default rate table [default = 4]
config.supportedMspApiVersion = {"12.06", "12.07","12.08"}          -- supported msp versions
config.simulatorApiVersionResponse = {0, 12, 07}                    -- version of api return by simulator
config.watchdogParam = 10                                           -- watchdog timeout for progress boxes [default = 10]


-- features
config.logEnable = false                                           -- will write debug log to: /scripts/rfsuite/logs/rfsuite.log [default = false]
config.logEnableScreen = false                                      -- if config.logEnable is true then also print to screen [default = false]
config.mspTxRxDebug = false                                         -- simple print of full msp payload that is sent and received [default = false]
config.flightLog = true                                             -- will write a flight log into /scripts/rfsuite/logs/<modelname>/*.log
config.reloadOnSave = false                                         -- trigger a reload on save [default = false]
config.skipRssiSensorCheck = false                                  -- skip checking for a valid rssi [ default = false]
config.enternalElrsSensors = true                                   -- disable the integrated elrs telemetry processing [default = true]
config.internalSportSensors = true                                  -- disable the integrated smart port telemetry processing [default = true]
config.adjFunctionAlerts = false                                    -- do not alert on adjfunction telemetry.  [default = false]
config.adjValueAlerts = true                                        -- play adjvalue alerts if sensor changes [default = true]  
config.saveWhenArmedWarning = true                                  -- do not display the save when armed warning. [default = true]
config.audioAlerts = 1                                              -- 0 = all, 1 = alerts, 2 = disable [default = 1]
config.profileSwitching = true                                      -- enable auto profile switching [default = true]
config.iconSize = 1                                                 -- 0 = text, 1 = small, 2 = large [default = 1]
config.developerMode = false                                        -- show developer tools on main menu [default = false]
config.soundPack = nil                                              -- use an custom sound pack. [default = nil]
config.syncCraftName = false                                         -- sync the craft name with the model name [default = false]

-- tasks
config.bgTaskName = config.toolName .. " [Background]"              -- background task name for msp services etc
config.bgTaskKey = "rf2bg"                                          -- key id used for msp services


-- LuaFormatter on

-- main
rfsuite = {}
rfsuite.config = config
rfsuite.app = assert(loadfile("app/app.lua"))(config)
rfsuite.utils = assert(loadfile("lib/utils.lua"))(config)

-- tasks
rfsuite.tasks = {}
rfsuite.bg = assert(loadfile("tasks/bg.lua"))(config)


-- LuaFormatter off

local function init()

    -- function that most always been there and are not handled dynamically on init
    system.registerSystemTool({event = rfsuite.app.event, name = config.toolName, icon = config.icon, create = rfsuite.app.create, wakeup = rfsuite.app.wakeup, paint = rfsuite.app.paint, close = rfsuite.app.close})
    system.registerSystemTool({event = rfsuite.app.event, name = config.toolName, icon = config.icon_logtool, create = rfsuite.app.create_logtool, wakeup = rfsuite.app.wakeup, paint = rfsuite.app.paint, close = rfsuite.app.close})
    system.registerTask({name = config.bgTaskName, key = config.bgTaskKey, wakeup = rfsuite.bg.wakeup, event = rfsuite.bg.event})


    -- widgets are loaded dynamically
    local widgetList = rfsuite.utils.findWidgets()

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
                persistent = false
            })
        end
    end
end

-- LuaFormatter on

return {init = init}
