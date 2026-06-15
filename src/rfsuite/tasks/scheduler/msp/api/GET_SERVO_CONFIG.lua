--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then
    msp.apicore = core
end

local SIM_RESPONSE = core.simResponse({
    220, 5,   -- mid
    232, 3,   -- min
    208, 7,   -- max
    232, 3,   -- rneg
    232, 3,   -- rpos
    100, 0,   -- rate
    0, 0,     -- speed
    0, 0      -- flags
})

local function buildReadPayload(_, _, _, _, servoIndex)
    servoIndex = tonumber(servoIndex) or 0
    if servoIndex < 0 then servoIndex = 0 end
    return {servoIndex}
end

return core.createReadOnlyAPI({
    name = "GET_SERVO_CONFIG",
    readCmd = 125,
    fields = {
        "mid", "U16",
        "min", "S16",
        "max", "S16",
        "rneg", "U16",
        "rpos", "U16",
        "rate", "U16",
        "speed", "U16",
        "flags", "U16"
    },
    buildReadPayload = buildReadPayload,
    simulatorResponseRead = SIM_RESPONSE,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
