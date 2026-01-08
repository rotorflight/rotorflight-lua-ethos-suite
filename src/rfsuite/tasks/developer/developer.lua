--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}

local developer = {}

function developer.wakeup()

    --[[
    if rfsuite.session.mcu_id and rfsuite.config.preferences then
        local iniName = "SCRIPTS:/" .. rfsuite.config.preferences .. "/models/" .. rfsuite.session.mcu_id .. ".ini"
        local api = rfsuite.tasks.ini.api.load("api_template")
        api.setIniFile(iniName)
        local pitch = api.readValue("pitch")

        print(pitch)
    end

    if rfsuite.session.mcu_id and rfsuite.config.preferences then
        local iniName = "SCRIPTS:/" .. rfsuite.config.preferences .. "/models/" .. rfsuite.session.mcu_id .. ".ini"
        local api = rfsuite.tasks.ini.api.load("api_template")
        api.setIniFile(iniName)

        api.setValue("pitch", math.random(-300, 300))

        local ok, err = api.write()
        if not ok then error("Failed to save INI: " .. err) end
    end
    ]]--

    rfsuite.utils.log("Developer task wakeup","info")


    -- Example of reading governor setting via CLI_SETTING MSP API
    --[[
    local API = rfsuite.tasks.msp.api.load("CLI_SETTING")

    API.setCompleteHandler(function(self, buf)
        local s = API.readValue()   -- returns the parsed reply table
        if not s then return end

        -- s.type, s.value, s.min, s.max, s.scalePow10, s.flags
        local value = s.value

        -- process it
        rfsuite.utils.log("CLI setting value=" .. tostring(value),"info")
    end)

    API.setErrorHandler(function(self, buf)
    rfsuite.utils.log("CLI_SETTING read failed", "info")
    end)

    API.setUUID("550e8400-e29b-41d4-a716-446655440000")

    -- READ: pass the CLI key name
    API.read("gov_mode")   -- (example name)
    ]]

    -- Example of writing governor setting via CLI_SETTING MSP API
    --[[
    local API = rfsuite.tasks.msp.api.load("CLI_SETTING")

    API.setCompleteHandler(function(self, buf)
        if API.writeComplete() then
            rfsuite.utils.log("CLI setting written successfully", "info")
        else
            rfsuite.utils.log("CLI setting write failed", "info")
        end
    end)

    API.setErrorHandler(function(self, buf)
        rfsuite.utils.log("CLI_SETTING write failed", "info")
    end)

    API.setUUID("550e8400-e29b-41d4-a716-446655440000")

    -- WRITE: set gov_mode to 2
    API.write("gov_mode", 2)
    ]]


end

return developer
