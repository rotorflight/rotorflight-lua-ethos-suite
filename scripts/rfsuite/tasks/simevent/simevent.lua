--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local simevent = {}

local source = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/sim/sensors/"

local handlers = {simevent_telemetry_state = function(value) rfsuite.simevent.telemetry_state = (value == 0) end}

local lastValues = {}

function simevent.wakeup()

    if not system.getVersion().simulation then return end

    for name, handler in pairs(handlers) do
        local path = source .. name .. ".lua"

        local chunk, loadErr = loadfile(path)
        if not chunk then
            print(("sim: could not load %s.lua: %s"):format(name, loadErr))
        else

            local ok, result = pcall(chunk)
            if not ok then
                print(("sim: error running %s.lua: %s"):format(name, result))
            elseif result ~= lastValues[name] then

                lastValues[name] = result
                handler(result)
            end
        end
    end
end

return simevent
