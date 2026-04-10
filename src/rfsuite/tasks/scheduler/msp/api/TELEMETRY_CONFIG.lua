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

local API_NAME = "TELEMETRY_CONFIG"
local MSP_API_CMD_READ = 73
local MSP_API_CMD_WRITE = 74

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"telemetry_inverted", "U8"},
    {"halfDuplex", "U8"},
    {"enableSensors", "U32"}
}

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 8}) then
    FIELD_SPEC[#FIELD_SPEC + 1] = {"pinSwap", "U8"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"crsf_telemetry_mode", "U8"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"crsf_telemetry_link_rate", "U16"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"crsf_telemetry_link_ratio", "U16"}

    for i = 1, 40 do
        FIELD_SPEC[#FIELD_SPEC + 1] = {"telem_sensor_slot_" .. i, "U8"}
    end
end

local SIM_RESPONSE = core.simResponse({
    0,            -- telemetry_inverted
    1,            -- halfDuplex
    0, 0, 0, 0,   -- enableSensors
    0,            -- pinSwap
    0,            -- crsf_telemetry_mode
    250, 0,       -- crsf_telemetry_link_rate
    8, 0,         -- crsf_telemetry_link_ratio
    3,            -- telem_sensor_slot_1
    4,            -- telem_sensor_slot_2
    5,            -- telem_sensor_slot_3
    6,            -- telem_sensor_slot_4
    8,            -- telem_sensor_slot_5
    8,            -- telem_sensor_slot_6
    89,           -- telem_sensor_slot_7
    90,           -- telem_sensor_slot_8
    91,           -- telem_sensor_slot_9
    99,           -- telem_sensor_slot_10
    95,           -- telem_sensor_slot_11
    96,           -- telem_sensor_slot_12
    60,           -- telem_sensor_slot_13
    15,           -- telem_sensor_slot_14
    42,           -- telem_sensor_slot_15
    93,           -- telem_sensor_slot_16
    50,           -- telem_sensor_slot_17
    51,           -- telem_sensor_slot_18
    52,           -- telem_sensor_slot_19
    17,           -- telem_sensor_slot_20
    18,           -- telem_sensor_slot_21
    19,           -- telem_sensor_slot_22
    23,           -- telem_sensor_slot_23
    22,           -- telem_sensor_slot_24
    36,           -- telem_sensor_slot_25
    0,            -- telem_sensor_slot_26
    0,            -- telem_sensor_slot_27
    0,            -- telem_sensor_slot_28
    0,            -- telem_sensor_slot_29
    0,            -- telem_sensor_slot_30
    0,            -- telem_sensor_slot_31
    0,            -- telem_sensor_slot_32
    0,            -- telem_sensor_slot_33
    0,            -- telem_sensor_slot_34
    0,            -- telem_sensor_slot_35
    0,            -- telem_sensor_slot_36
    0,            -- telem_sensor_slot_37
    0,            -- telem_sensor_slot_38
    0,            -- telem_sensor_slot_39
    0             -- telem_sensor_slot_40
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
