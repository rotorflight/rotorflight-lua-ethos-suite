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

local API_NAME = "VTX_CONFIG"
local MSP_API_CMD_READ = 88
local MSP_API_CMD_WRITE = 89

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"device_type", "U8"},
    {"band", "U8"},
    {"channel", "U8"},
    {"power", "U8"},
    {"pit_mode", "U8"},
    {"freq", "U16"},
    {"device_ready", "U8"},
    {"low_power_disarm", "U8"}
}

if rfsuite.utils.apiVersionCompare(">=", {12, 42}) then
    FIELD_SPEC[#FIELD_SPEC + 1] = {"pit_mode_freq", "U16"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"vtxtable_available", "U8"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"vtxtable_bands", "U8"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"vtxtable_channels", "U8"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"vtxtable_power_levels", "U8"}
end

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"freq_or_bandchan", "U16"},
    {"power", "U8"},
    {"pit_mode", "U8"},
    {"low_power_disarm", "U8"},
    {"pit_mode_freq", "U16"},
    {"band", "U8"},
    {"channel", "U8"},
    {"freq", "U16"},
    {"vtxtable_bands", "U8"},
    {"vtxtable_channels", "U8"},
    {"vtxtable_power_levels", "U8"},
    {"vtxtable_clear", "U8"}
}

local SIM_RESPONSE = core.simResponse({
    0,       -- device_type
    1,       -- band
    1,       -- channel
    1,       -- power
    0,       -- pit_mode
    108, 22, -- freq
    1,       -- device_ready
    0,       -- low_power_disarm
    0, 0,    -- pit_mode_freq
    1,       -- vtxtable_available
    5,       -- vtxtable_bands
    8,       -- vtxtable_channels
    5        -- vtxtable_power_levels
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
