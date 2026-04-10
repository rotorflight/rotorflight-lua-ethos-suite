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

local API_NAME = "LED_COLORS"
local MSP_API_CMD_READ = 46
local MSP_API_CMD_WRITE = 47
local LED_CONFIGURABLE_COLOR_COUNT = 16

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {}
for i = 1, LED_CONFIGURABLE_COLOR_COUNT do
    FIELD_SPEC[#FIELD_SPEC + 1] = {"color_" .. i .. "_h", "U16"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"color_" .. i .. "_s", "U8"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"color_" .. i .. "_v", "U8"}
end

local SIM_RESPONSE = core.simResponse({
    0, 0, 0, 0, -- color_1_h, color_1_s, color_1_v
    0, 0, 0, 0, -- color_2_h, color_2_s, color_2_v
    0, 0, 0, 0, -- color_3_h, color_3_s, color_3_v
    0, 0, 0, 0, -- color_4_h, color_4_s, color_4_v
    0, 0, 0, 0, -- color_5_h, color_5_s, color_5_v
    0, 0, 0, 0, -- color_6_h, color_6_s, color_6_v
    0, 0, 0, 0, -- color_7_h, color_7_s, color_7_v
    0, 0, 0, 0, -- color_8_h, color_8_s, color_8_v
    0, 0, 0, 0, -- color_9_h, color_9_s, color_9_v
    0, 0, 0, 0, -- color_10_h, color_10_s, color_10_v
    0, 0, 0, 0, -- color_11_h, color_11_s, color_11_v
    0, 0, 0, 0, -- color_12_h, color_12_s, color_12_v
    0, 0, 0, 0, -- color_13_h, color_13_s, color_13_v
    0, 0, 0, 0, -- color_14_h, color_14_s, color_14_v
    0, 0, 0, 0, -- color_15_h, color_15_s, color_15_v
    0, 0, 0, 0  -- color_16_h, color_16_s, color_16_v
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    initialRebuildOnWrite = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
