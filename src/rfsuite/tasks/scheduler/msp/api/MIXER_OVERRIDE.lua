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

local API_NAME = "MIXER_OVERRIDE"
local MSP_API_CMD_READ = 190
local MSP_API_CMD_WRITE = 191
local MIXER_OVERRIDE_COUNT = 29

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {}
for i = 1, MIXER_OVERRIDE_COUNT do
    FIELD_SPEC[#FIELD_SPEC + 1] = {"override_" .. i, "U16"}
end

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"index", "U8"},
    {"value", "U16"}
}

local SIM_RESPONSE = core.simResponse({
    0, 0, -- override_1
    0, 0, -- override_2
    0, 0, -- override_3
    0, 0, -- override_4
    0, 0, -- override_5
    0, 0, -- override_6
    0, 0, -- override_7
    0, 0, -- override_8
    0, 0, -- override_9
    0, 0, -- override_10
    0, 0, -- override_11
    0, 0, -- override_12
    0, 0, -- override_13
    0, 0, -- override_14
    0, 0, -- override_15
    0, 0, -- override_16
    0, 0, -- override_17
    0, 0, -- override_18
    0, 0, -- override_19
    0, 0, -- override_20
    0, 0, -- override_21
    0, 0, -- override_22
    0, 0, -- override_23
    0, 0, -- override_24
    0, 0, -- override_25
    0, 0, -- override_26
    0, 0, -- override_27
    0, 0, -- override_28
    0, 0  -- override_29
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    fields = FIELD_SPEC,
    writeFields = WRITE_FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    initialRebuildOnWrite = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
