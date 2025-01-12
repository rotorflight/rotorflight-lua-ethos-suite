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
config.ethosVersion = 1518                                          -- min version of ethos supported by this script
config.ethosVersionString = "ETHOS < V1.5.18"                       -- string to print if ethos version error occurs
config.defaultRateProfile = 4 -- ACTUAL                             -- default rate table [default = 4]
config.supportedMspApiVersion = {"12.06", "12.07","12.08"}          -- supported msp versions
config.simulatorApiVersionResponse = {0, 12, 8}                     -- version of api return by simulator
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

-- tasks
config.bgTaskName = config.toolName .. " [Background]"              -- background task name for msp services etc
config.bgTaskKey = "rf2bg"                                          -- key id used for msp services

-- widgets
config.rf2govName = "Rotorflight Governor"                          -- RF2Gov Name
config.rf2govKey = "rf2gov"                                         -- RF2Gov Key
config.rf2statusName = "Rotorflight Status"                         -- RF2Status name
config.rf2statusKey = "bkshss"                                      -- RF2Status key
config.rf2craftnameName = "Rotorflight Craft Name"                  -- rf2craftname Name
config.rf2craftnameKey = "bkzhfs"                                   -- rf2craftname key


-- LuaFormatter on

-- main
rfsuite = {}
rfsuite.config = config
rfsuite.app = assert(loadfile("app/app.lua"))(config)
rfsuite.utils = assert(loadfile("lib/utils.lua"))(config)

-- tasks
rfsuite.tasks = {}
rfsuite.bg = assert(loadfile("tasks/bg.lua"))(config)

-- widgets
rfsuite.rf2gov = assert(loadfile("widgets/governor/governor.lua"))(config)
rfsuite.rf2status = assert(loadfile("widgets/status/status.lua"))(config)
rfsuite.rf2craftname = assert(loadfile("widgets/craftname/craftname.lua"))(config)

-- LuaFormatter off

local function init()
        system.registerSystemTool({event = rfsuite.app.event, name = config.toolName, icon = config.icon, create = rfsuite.app.create, wakeup = rfsuite.app.wakeup, paint = rfsuite.app.paint, close = rfsuite.app.close})
        system.registerSystemTool({event = rfsuite.app.event, name = config.toolName, icon = config.icon_logtool, create = rfsuite.app.create_logtool, wakeup = rfsuite.app.wakeup, paint = rfsuite.app.paint, close = rfsuite.app.close})
        system.registerTask({name = config.bgTaskName, key = config.bgTaskKey, wakeup = rfsuite.bg.wakeup, event = rfsuite.bg.event})
        system.registerWidget({name = config.rf2govName,key = config.rf2govKey, create = rfsuite.rf2gov.create, paint = rfsuite.rf2gov.paint, wakeup = rfsuite.rf2gov.wakeup, persistent = false})        
        system.registerWidget({name = config.rf2statusName,key = config.rf2statusKey, event = rfsuite.rf2status.event, write = rfsuite.rf2status.write, read = rfsuite.rf2status.read, configure = rfsuite.rf2status.configure, create = rfsuite.rf2status.create, paint = rfsuite.rf2status.paint, wakeup = rfsuite.rf2status.wakeup, persistent = false})        
		system.registerWidget({name = config.rf2craftnameName,key = config.rf2craftnameKey, event = rfsuite.rf2craftname.event, create = rfsuite.rf2craftname.create, paint = rfsuite.rf2craftname.paint, wakeup = rfsuite.rf2craftname.wakeup, write = rfsuite.rf2craftname.write, read = rfsuite.rf2craftname.read, configure = rfsuite.rf2craftname.configure, persistent = false})        
end

-- LuaFormatter on

return {init = init}
