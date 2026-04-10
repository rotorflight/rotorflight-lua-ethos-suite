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

local API_NAME = "GPS_CONFIG"
local MSP_API_CMD_READ = 132
local MSP_API_CMD_WRITE = 223

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"provider", "U8"},
    {"sbas_mode", "U8"},
    {"auto_config", "U8"},
    {"auto_baud", "U8"}
}

if rfsuite.utils.apiVersionCompare(">=", {12, 43}) then
    FIELD_SPEC[#FIELD_SPEC + 1] = {"set_home_point_once", "U8"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"ublox_use_galileo", "U8"}
end

local SIM_RESPONSE = core.simResponse({
    0,  -- provider
    0,  -- sbas_mode
    1,  -- auto_config
    1,  -- auto_baud
    0,  -- set_home_point_once
    0   -- ublox_use_galileo
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    initialRebuildOnWrite = true,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
