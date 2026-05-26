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

local API_NAME = "BUS_SERVO_CONFIG"
local MSP_API_CMD_READ = 152
local MSP_API_CMD_WRITE = 153
local BUS_SERVO_CHANNELS = 18

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {}
for i = 1, BUS_SERVO_CHANNELS do
    FIELD_SPEC[#FIELD_SPEC + 1] = {"source_type_" .. i, "U8"}
end

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"index", "U8"},
    {"source_type", "U8"}
}

local SIM_RESPONSE = core.simResponse({
    0, -- source_type_1
    0, -- source_type_2
    0, -- source_type_3
    0, -- source_type_4
    0, -- source_type_5
    0, -- source_type_6
    0, -- source_type_7
    0, -- source_type_8
    0, -- source_type_9
    0, -- source_type_10
    0, -- source_type_11
    0, -- source_type_12
    0, -- source_type_13
    0, -- source_type_14
    0, -- source_type_15
    0, -- source_type_16
    0, -- source_type_17
    0  -- source_type_18
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
