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

local API_NAME = "MIXER_INPUT"

local directionTableEthos = {
    [1] = {"@i18n(api.MIXER_INPUT.tbl_normal)@", 250},
    [2] = {"@i18n(api.MIXER_INPUT.tbl_reversed)@", 65286}
}

-- Each entry is:
--   name, rate default, min default, max default, rate tableEthos
local INPUT_GROUPS = {
    {"none", 0, 0, 0},
    {"stabilized_roll", 250, 64350, 1250, directionTableEthos},
    {"stabilized_pitch", 250, 64350, 1250, directionTableEthos},
    {"stabilized_yaw", 250, 64350, 1250, directionTableEthos},
    {"stabilized_collective", 250, 64350, 1250, directionTableEthos},
    {"stabilized_throttle", 250, 64350, 1250},
    {"rc_command_roll", 250, 64350, 1250},
    {"rc_command_pitch", 250, 64350, 1250},
    {"rc_command_yaw", 250, 64350, 1250},
    {"rc_command_collective", 250, 64350, 1250},
    {"rc_command_throttle", 250, 64350, 1250},
    {"rc_channel_roll", 250, 64350, 1250},
    {"rc_channel_pitch", 250, 64350, 1250},
    {"rc_channel_yaw", 250, 64350, 1250},
    {"rc_channel_collective", 250, 64350, 1250},
    {"rc_channel_throttle", 250, 64350, 1250},
    {"rc_channel_aux1", 250, 64350, 1250},
    {"rc_channel_aux2", 250, 64350, 1250},
    {"rc_channel_aux3", 250, 64350, 1250},
    {"rc_channel_9", 250, 64350, 1250},
    {"rc_channel_10", 250, 64350, 1250},
    {"rc_channel_11", 250, 64350, 1250},
    {"rc_channel_12", 250, 64350, 1250},
    {"rc_channel_13", 250, 64350, 1250},
    {"rc_channel_14", 250, 64350, 1250},
    {"rc_channel_15", 250, 64350, 1250},
    {"rc_channel_16", 250, 64350, 1250},
    {"rc_channel_17", 250, 64350, 1250},
    {"rc_channel_18", 250, 64350, 1250}
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos, offset, xvals
local FIELD_SPEC = {}
for _, group in ipairs(INPUT_GROUPS) do
    FIELD_SPEC[#FIELD_SPEC + 1] = {"rate_" .. group[1], "U16", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, group[5]}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"min_" .. group[1], "U16"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"max_" .. group[1], "U16"}
end

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos, offset, xvals
local WRITE_FIELD_SPEC = {
    {"index", "U8"},
    {"rate", "U16"},
    {"min", "U16"},
    {"max", "U16"}
}

local function appendU16(bytes, value)
    bytes[#bytes + 1] = value & 0xFF
    bytes[#bytes + 1] = (value >> 8) & 0xFF
end

local function buildSimResponse()
    local bytes = {}
    for _, group in ipairs(INPUT_GROUPS) do
        appendU16(bytes, group[2]) -- rate_<group>
        appendU16(bytes, group[3]) -- min_<group>
        appendU16(bytes, group[4]) -- max_<group>
    end
    return bytes
end

local SIM_RESPONSE = core.simResponse(buildSimResponse())

return core.createConfigAPI({
    name = API_NAME,
    readCmd = 170,
    writeCmd = 171,
    fields = FIELD_SPEC,
    writeFields = WRITE_FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    initialRebuildOnWrite = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
