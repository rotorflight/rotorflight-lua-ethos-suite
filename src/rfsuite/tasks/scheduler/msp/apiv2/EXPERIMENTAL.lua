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

local API_NAME = "EXPERIMENTAL"
local MSP_API_CMD_READ = 158
local MSP_API_CMD_WRITE = 159
local OPTIONAL = false

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"exp_uint1", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"exp_uint2", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"exp_uint3", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"exp_uint4", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"exp_uint5", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"exp_uint6", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"exp_uint7", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"exp_uint8", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"exp_uint9", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"exp_uint10", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"exp_uint11", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"exp_uint12", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"exp_uint13", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"exp_uint14", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"exp_uint15", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"exp_uint16", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL}
}

local SIM_RESPONSE = core.simResponse({
    255, -- exp_uint1
    10,  -- exp_uint2
    60,  -- exp_uint3
    200, -- exp_uint4
    20,  -- exp_uint5
    255, -- exp_uint6
    6,   -- exp_uint7
    10,  -- exp_uint8
    20,  -- exp_uint9
    40,  -- exp_uint10
    255, -- exp_uint11
    6,   -- exp_uint12
    10,  -- exp_uint13
    20,  -- exp_uint14
    20,  -- exp_uint15
    20   -- exp_uint16
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
