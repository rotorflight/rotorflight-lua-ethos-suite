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

local API_NAME = "ACC_TRIM"
local MSP_API_CMD_READ = 240
local MSP_API_CMD_WRITE = 239

-- Tuple layout:
--   field, type, min, max, default, unit
local FIELD_SPEC = {
    {"pitch", "S16", -300, 300, 0, "°"},
    {"roll", "S16", -300, 300, 0, "°"}
}

local SIM_RESPONSE = core.simResponse({
    0, 0, -- pitch
    0, 0  -- roll
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
