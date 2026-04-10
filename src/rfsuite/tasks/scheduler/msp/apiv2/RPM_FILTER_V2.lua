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

local API_NAME = "RPM_FILTER_V2"
local MSP_API_CMD_READ = 154
local MSP_API_CMD_WRITE = 155
local RPM_FILTER_NOTCH_COUNT = 16

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {}
for i = 1, RPM_FILTER_NOTCH_COUNT do
    FIELD_SPEC[#FIELD_SPEC + 1] = {"notch_source_" .. i, "U8"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"notch_center_" .. i, "U16"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"notch_q_" .. i, "U8"}
end

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"axis", "U8"}
}
for i = 1, RPM_FILTER_NOTCH_COUNT do
    WRITE_FIELD_SPEC[#WRITE_FIELD_SPEC + 1] = {"notch_source_" .. i, "U8"}
    WRITE_FIELD_SPEC[#WRITE_FIELD_SPEC + 1] = {"notch_center_" .. i, "U16"}
    WRITE_FIELD_SPEC[#WRITE_FIELD_SPEC + 1] = {"notch_q_" .. i, "U8"}
end

local function buildReadPayload(payloadData, _, _, _, axis)
    local readAxis = tonumber(axis)
    if readAxis == nil then readAxis = tonumber(payloadData.axis) end
    if readAxis == nil then readAxis = 0 end
    return {readAxis}
end

local SIM_RESPONSE = core.simResponse({
    0, 0, 0, -- notch 1
    0, 0, 0, -- notch 2
    0, 0, 0, -- notch 3
    0, 0, 0, -- notch 4
    0, 0, 0, -- notch 5
    0, 0, 0, -- notch 6
    0, 0, 0, -- notch 7
    0, 0, 0, -- notch 8
    0, 0, 0, -- notch 9
    0, 0, 0, -- notch 10
    0, 0, 0, -- notch 11
    0, 0, 0, -- notch 12
    0, 0, 0, -- notch 13
    0, 0, 0, -- notch 14
    0, 0, 0, -- notch 15
    0, 0, 0  -- notch 16
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    initialRebuildOnWrite = true,
    fields = FIELD_SPEC,
    writeFields = WRITE_FIELD_SPEC,
    buildReadPayload = buildReadPayload,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
