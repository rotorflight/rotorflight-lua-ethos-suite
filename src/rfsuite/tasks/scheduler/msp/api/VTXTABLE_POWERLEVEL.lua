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

local API_NAME = "VTXTABLE_POWERLEVEL"
local OPTIONAL = false

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"power_level", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"power_value", "U16", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"label_length", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"label_1", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"label_2", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"label_3", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL}
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"power_level", "U8"},
    {"power_value", "U16"},
    {"label_length", "U8"},
    {"label_1", "U8"},
    {"label_2", "U8"},
    {"label_3", "U8"}
}

local SIM_RESPONSE = core.simResponse({
    1, -- power_level
    25, 0, -- power_value
    3, -- label_length
    50, -- label_1
    53, -- label_2
    77  -- label_3
})

local function buildReadPayload(payloadData, _, _, _, powerLevel)
    local readPower = tonumber(powerLevel)
    if readPower == nil then
        readPower = tonumber(payloadData.power_level)
    end
    if readPower == nil then
        readPower = 1
    end

    return {readPower}
end

return core.createConfigAPI({
    name = API_NAME,
    readCmd = 138,
    writeCmd = 228,
    fields = FIELD_SPEC,
    writeFields = WRITE_FIELD_SPEC,
    buildReadPayload = buildReadPayload,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    initialRebuildOnWrite = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
