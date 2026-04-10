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

local API_NAME = "GPS_RESCUE"
local MSP_API_CMD_READ = 135
local MSP_API_CMD_WRITE = 225

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"angle", "U16"},
    {"initial_altitude_m", "U16"},
    {"descent_distance_m", "U16"},
    {"rescue_groundspeed", "U16"},
    {"throttle_min", "U16"},
    {"throttle_max", "U16"},
    {"throttle_hover", "U16"},
    {"sanity_checks", "U8"},
    {"min_sats", "U8"}
}

if rfsuite.utils.apiVersionCompare(">=", {12, 43}) then
    FIELD_SPEC[#FIELD_SPEC + 1] = {"ascend_rate", "U16"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"descend_rate", "U16"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"allow_arming_without_fix", "U8"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"altitude_mode", "U8"}
end

if rfsuite.utils.apiVersionCompare(">=", {12, 44}) then
    FIELD_SPEC[#FIELD_SPEC + 1] = {"min_rescue_dth", "U16"}
end

local SIM_RESPONSE = core.simResponse({
    0, 0,    -- angle
    100, 0,  -- initial_altitude_m
    100, 0,  -- descent_distance_m
    200, 0,  -- rescue_groundspeed
    0, 0,    -- throttle_min
    0, 0,    -- throttle_max
    0, 0,    -- throttle_hover
    0,       -- sanity_checks
    6,       -- min_sats
    0, 0,    -- ascend_rate
    0, 0,    -- descend_rate
    0,       -- allow_arming_without_fix
    0,       -- altitude_mode
    0, 0     -- min_rescue_dth
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
