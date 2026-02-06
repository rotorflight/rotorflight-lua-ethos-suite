--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}

local developer = {}

-- Localize globals
local print = print
local math_random = math.random
local tostring = tostring

function developer.wakeup()
    local session = rfsuite.session
    local config = rfsuite.config

    if not session or not session.mcu_id or not config or not config.preferences then return end

    local tasks = rfsuite.tasks
    if not tasks or not tasks.ini or not tasks.ini.api then return end

    local iniName = "SCRIPTS:/" .. config.preferences .. "/models/" .. session.mcu_id .. ".ini"
    local api = tasks.ini.api.load("api_template")

    if api then
        api.setIniFile(iniName)
        local pitch = api.readValue("pitch")
        print(pitch)
        api.setValue("pitch", math_random(-300, 300))
        local ok, err = api.write()
        if not ok then print("Failed to save INI: " .. tostring(err)) end
    end
end

return developer
