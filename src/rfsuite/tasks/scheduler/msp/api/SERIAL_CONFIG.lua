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

local API_NAME = "SERIAL_CONFIG"
local MAX_SERIAL_PORTS = 12

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos, offset, xvals
local READ_FIELD_SPEC = {}
for i = 1, MAX_SERIAL_PORTS do
    local mandatory = (i == 1)
    READ_FIELD_SPEC[#READ_FIELD_SPEC + 1] = {"port_" .. i .. "_identifier", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, mandatory}
    READ_FIELD_SPEC[#READ_FIELD_SPEC + 1] = {"port_" .. i .. "_function_mask", "U32", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, mandatory}
    READ_FIELD_SPEC[#READ_FIELD_SPEC + 1] = {"port_" .. i .. "_msp_baud_index", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, mandatory}
    READ_FIELD_SPEC[#READ_FIELD_SPEC + 1] = {"port_" .. i .. "_gps_baud_index", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, mandatory}
    READ_FIELD_SPEC[#READ_FIELD_SPEC + 1] = {"port_" .. i .. "_telem_baud_index", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, mandatory}
    READ_FIELD_SPEC[#READ_FIELD_SPEC + 1] = {"port_" .. i .. "_blackbox_baud_index", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, mandatory}
end

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos, offset, xvals
local WRITE_FIELD_SPEC = {
    {"identifier", "U8"},
    {"function_mask", "U32"},
    {"msp_baud_index", "U8"},
    {"gps_baud_index", "U8"},
    {"telem_baud_index", "U8"},
    {"blackbox_baud_index", "U8"}
}

local function buildSimResponse()
    local bytes = {}
    for i = 1, MAX_SERIAL_PORTS do
        bytes[#bytes + 1] = i - 1  -- identifier
        bytes[#bytes + 1] = 0      -- function_mask b0
        bytes[#bytes + 1] = 0      -- function_mask b1
        bytes[#bytes + 1] = 0      -- function_mask b2
        bytes[#bytes + 1] = 0      -- function_mask b3
        bytes[#bytes + 1] = 0      -- msp_baud_index
        bytes[#bytes + 1] = 0      -- gps_baud_index
        bytes[#bytes + 1] = 0      -- telem_baud_index
        bytes[#bytes + 1] = 0      -- blackbox_baud_index
    end
    return bytes
end

local SIM_RESPONSE = core.simResponse(buildSimResponse())

return core.createConfigAPI({
    name = API_NAME,
    readCmd = 54,
    writeCmd = 55,
    fields = READ_FIELD_SPEC,
    writeFields = WRITE_FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    initialRebuildOnWrite = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
