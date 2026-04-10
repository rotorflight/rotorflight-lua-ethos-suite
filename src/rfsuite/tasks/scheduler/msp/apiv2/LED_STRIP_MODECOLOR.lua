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

local API_NAME = "LED_STRIP_MODECOLOR"
local MSP_API_CMD_READ = 127
local MSP_API_CMD_WRITE = 221
local MODE_COUNT = 4
local DIRECTION_COUNT = 6
local SPECIAL_COLOR_COUNT = 11

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {}
for mode = 0, MODE_COUNT - 1 do
    for direction = 0, DIRECTION_COUNT - 1 do
        local idx = (mode * DIRECTION_COUNT) + direction + 1
        FIELD_SPEC[#FIELD_SPEC + 1] = {"mode_" .. idx, "U8"}
        FIELD_SPEC[#FIELD_SPEC + 1] = {"fun_" .. idx, "U8"}
        FIELD_SPEC[#FIELD_SPEC + 1] = {"color_" .. idx, "U8"}
    end
end
for special = 0, SPECIAL_COLOR_COUNT - 1 do
    local idx = (MODE_COUNT * DIRECTION_COUNT) + special + 1
    FIELD_SPEC[#FIELD_SPEC + 1] = {"mode_" .. idx, "U8"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"fun_" .. idx, "U8"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"color_" .. idx, "U8"}
end
FIELD_SPEC[#FIELD_SPEC + 1] = {"aux_mode", "U8"}
FIELD_SPEC[#FIELD_SPEC + 1] = {"aux_fun", "U8"}
FIELD_SPEC[#FIELD_SPEC + 1] = {"aux_color", "U8"}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"mode", "U8"},
    {"fun", "U8"},
    {"color", "U8"}
}

local SIM_RESPONSE = core.simResponse({
    -- mode slots 1..24: mode, function, color
    0, 0, 0, 0, 1, 0, 0, 2, 0, 0, 3, 0, 0, 4, 0, 0, 5, 0,
    1, 0, 0, 1, 1, 0, 1, 2, 0, 1, 3, 0, 1, 4, 0, 1, 5, 0,
    2, 0, 0, 2, 1, 0, 2, 2, 0, 2, 3, 0, 2, 4, 0, 2, 5, 0,
    3, 0, 0, 3, 1, 0, 3, 2, 0, 3, 3, 0, 3, 4, 0, 3, 5, 0,
    -- special color slots 25..35: mode=4, function, color
    4, 0, 0, 4, 1, 0, 4, 2, 0, 4, 3, 0, 4, 4, 0, 4, 5, 0,
    4, 6, 0, 4, 7, 0, 4, 8, 0, 4, 9, 0, 4, 10, 0,
    255, -- aux_mode
    0, -- aux_fun
    0  -- aux_color
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
