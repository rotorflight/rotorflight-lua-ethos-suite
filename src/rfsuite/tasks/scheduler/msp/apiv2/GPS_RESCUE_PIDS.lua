--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicorev2) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/apiv2/core.lua"))()
if msp and not msp.apicorev2 then
    msp.apicorev2 = core
end

local API_NAME = "GPS_RESCUE_PIDS"
local MSP_API_CMD_READ = 136
local MSP_API_CMD_WRITE = 226

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"throttle_p", "U16"},
    {"throttle_i", "U16"},
    {"throttle_d", "U16"},
    {"vel_p", "U16"},
    {"vel_i", "U16"},
    {"vel_d", "U16"},
    {"yaw_p", "U16"}
}

local SIM_RESPONSE = core.simResponse({
    0, 0, -- throttle_p
    0, 0, -- throttle_i
    0, 0, -- throttle_d
    0, 0, -- vel_p
    0, 0, -- vel_i
    0, 0, -- vel_d
    0, 0  -- yaw_p
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    initialRebuildOnWrite = true,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
