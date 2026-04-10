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

local API_NAME = "PILOT_CONFIG"
local MSP_API_CMD_READ = 12
local MSP_API_CMD_WRITE = 13

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"model_id", "U8"},
    {"model_param1_type", "U8"},
    {"model_param1_value", "U16", 0, 3600, nil, "s"},
    {"model_param2_type", "U8"},
    {"model_param2_value", "U16"},
    {"model_param3_type", "U8"},
    {"model_param3_value", "U16"}
}

local SIM_RESPONSE = core.simResponse({
    3,       -- model_id
    0,       -- model_param1_type
    44, 1,   -- model_param1_value
    0,       -- model_param2_type
    20, 0,   -- model_param2_value
    20,      -- model_param3_type
    0, 30    -- model_param3_value
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    minApiVersion = {12, 0, 7},
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
