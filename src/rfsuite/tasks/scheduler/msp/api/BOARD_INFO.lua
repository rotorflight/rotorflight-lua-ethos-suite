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

local API_NAME = "BOARD_INFO"
local MSP_API_CMD_READ = 4
local MSP_API_CMD_WRITE = 248
local TARGET_NAME_MAX = 32
local BOARD_NAME_MAX = 20
local BOARD_DESIGN_MAX = 12
local MANUFACTURER_ID_MAX = 4
local OPTIONAL = false

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"board_identifier_1", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"board_identifier_2", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"board_identifier_3", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"board_identifier_4", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"hardware_revision", "U16", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"fc_type", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"target_capabilities", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"target_name_length", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
}

for i = 1, TARGET_NAME_MAX do
    FIELD_SPEC[#FIELD_SPEC + 1] = {"target_name_" .. i, "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL}
end
FIELD_SPEC[#FIELD_SPEC + 1] = {"board_name_length", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL}
for i = 1, BOARD_NAME_MAX do
    FIELD_SPEC[#FIELD_SPEC + 1] = {"board_name_" .. i, "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL}
end
FIELD_SPEC[#FIELD_SPEC + 1] = {"board_design_length", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL}
for i = 1, BOARD_DESIGN_MAX do
    FIELD_SPEC[#FIELD_SPEC + 1] = {"board_design_" .. i, "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL}
end
FIELD_SPEC[#FIELD_SPEC + 1] = {"manufacturer_id_length", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL}
for i = 1, MANUFACTURER_ID_MAX do
    FIELD_SPEC[#FIELD_SPEC + 1] = {"manufacturer_id_" .. i, "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL}
end
for i = 1, 32 do
    FIELD_SPEC[#FIELD_SPEC + 1] = {"signature_" .. i, "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL}
end
FIELD_SPEC[#FIELD_SPEC + 1] = {"mcu_type_id", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL}
if rfsuite.utils.apiVersionCompare(">=", {12, 42}) then
    FIELD_SPEC[#FIELD_SPEC + 1] = {"configuration_state", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL}
end
if rfsuite.utils.apiVersionCompare(">=", {12, 43}) then
    FIELD_SPEC[#FIELD_SPEC + 1] = {"gyro_sample_rate_hz", "U16", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"configuration_problems", "U32", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL}
end
if rfsuite.utils.apiVersionCompare(">=", {12, 44}) then
    FIELD_SPEC[#FIELD_SPEC + 1] = {"spi_device_count", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"i2c_device_count", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL}
end

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"board_name_length", "U8"},
}
for i = 1, BOARD_NAME_MAX do
    WRITE_FIELD_SPEC[#WRITE_FIELD_SPEC + 1] = {"board_name_" .. i, "U8"}
end
WRITE_FIELD_SPEC[#WRITE_FIELD_SPEC + 1] = {"board_design_length", "U8"}
for i = 1, BOARD_DESIGN_MAX do
    WRITE_FIELD_SPEC[#WRITE_FIELD_SPEC + 1] = {"board_design_" .. i, "U8"}
end
WRITE_FIELD_SPEC[#WRITE_FIELD_SPEC + 1] = {"manufacturer_id_length", "U8"}
for i = 1, MANUFACTURER_ID_MAX do
    WRITE_FIELD_SPEC[#WRITE_FIELD_SPEC + 1] = {"manufacturer_id_" .. i, "U8"}
end

local SIM_RESPONSE = core.simResponse({
    82, -- board_identifier_1
    70, -- board_identifier_2
    76, -- board_identifier_3
    84, -- board_identifier_4
    0, 0, -- hardware_revision
    0, -- fc_type
    0, -- target_capabilities
    0, -- target_name_length
    -- target_name_1..32
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, -- board_name_length
    -- board_name_1..20
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, -- board_design_length
    -- board_design_1..12
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, -- manufacturer_id_length
    -- manufacturer_id_1..4
    0, 0, 0, 0,
    -- signature_1..32
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, -- mcu_type_id
    0, -- configuration_state
    0, 0, -- gyro_sample_rate_hz
    0, 0, 0, 0, -- configuration_problems
    0, -- spi_device_count
    0  -- i2c_device_count
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
