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

local API_NAME = "FLIGHT_STATS"
local MSP_API_CMD_READ = 14
local MSP_API_CMD_WRITE = 15

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"flightcount", "U32"},
    {"totalflighttime", "U32"},
    {"totaldistance", "U32"},
    {"minarmedtime", "S8"}
}

local SIM_RESPONSE = core.simResponse({
    123, 1, 0, 0, -- flightcount
    0, 1, 2, 0,   -- totalflighttime
    0, 0, 0, 0,   -- totaldistance
    15            -- minarmedtime
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE
})
