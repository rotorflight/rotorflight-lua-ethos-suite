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

local API_NAME = "RAW_GPS"
local MSP_API_CMD_READ = 106
local MSP_API_CMD_WRITE = 201

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"fix", "U8"},
    {"num_sat", "U8"},
    {"lat", "U32"},
    {"lon", "U32"},
    {"alt", "U16"},
    {"ground_speed", "U16"},
    {"ground_course", "U16"}
}

if rfsuite.utils.apiVersionCompare(">=", {12, 44}) then
    FIELD_SPEC[#FIELD_SPEC + 1] = {"hdop", "U16"}
end

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"fix", "U8"},
    {"num_sat", "U8"},
    {"lat", "U32"},
    {"lon", "U32"},
    {"alt", "U16"},
    {"ground_speed", "U16"}
}

local SIM_RESPONSE = core.simResponse({
    0,             -- fix
    0,             -- num_sat
    0, 0, 0, 0,    -- lat
    0, 0, 0, 0,    -- lon
    0, 0,          -- alt
    0, 0,          -- ground_speed
    0, 0,          -- ground_course
    0, 0           -- hdop
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    initialRebuildOnWrite = true,
    fields = FIELD_SPEC,
    writeFields = WRITE_FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
