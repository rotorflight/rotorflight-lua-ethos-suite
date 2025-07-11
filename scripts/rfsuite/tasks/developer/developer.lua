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

 * This task is a developer debug tool.  It simply provides a simple
 * point in which to inject api queries for debugging or creating new
 * api libraries.  Default behavious should always be to not run this 
 * loop.  Its up to the developer to ensure that after debug he flags
 * the task to not run.

 * This can be done by setting the ENABLE_TASK flag to true or false.

 * It can be usefull when using the task to enable the preferences.developer.logmsp 
 * flag in main.lua. This will print out the msp request and response.

]] --
local arg = {...}

local developer = {}



function developer.wakeup()

    --[[
    -- This is an example of how to use the api library to query the governor mode
        rfsuite.utils.log("API Debug Task: GOVERNOR_CONFIG", "info")
    local API = rfsuite.tasks.msp.api.load("GOVERNOR_CONFIG")
    API.setCompleteHandler(function(self, buf)
        local governorMode = API.readValue("gov_mode")
        rfsuite.utils.log("Governor mode: " .. governorMode, "info")
        rfsuite.session.governorMode = governorMode
    end)
    API.setUUID("123e4567-e89b-12d3-a456-426614174000")
    API.read()
    ]]--

    --[[
    rfsuite.utils.log("API Debug Task: TELEMETRY_CONFIG", "info")
    local API = rfsuite.tasks.msp.api.load("TELEMETRY_CONFIG")
    API.setCompleteHandler(function(self, buf)
    end)
    API.setUUID("123e4567-e89b-12d3-a456-426614174000")
    API.read()
    ]]

    -- Example of reading a value from an INI file using the API
    if rfsuite.session.mcu_id and rfsuite.config.preferences then
        local iniName = "SCRIPTS:/" .. rfsuite.config.preferences .. "/models/" .. rfsuite.session.mcu_id ..".ini"
        local api = rfsuite.tasks.ini.api.load("api_template")
        api.setIniFile(iniName)
        local pitch = api.readValue("pitch")

        print(pitch)
    end


    -- Example of reading a value from an INI file using the API
    if rfsuite.session.mcu_id and rfsuite.config.preferences then
        local iniName = "SCRIPTS:/" .. rfsuite.config.preferences .. "/models/" .. rfsuite.session.mcu_id ..".ini"
        local api = rfsuite.tasks.ini.api.load("api_template")
        api.setIniFile(iniName)

        -- stage value for later write
        api.setValue("pitch", math.random(-300, 300))

        local ok, err = api.write()
        if not ok then error("Failed to save INI: " .. err) end
    end


end

return developer
