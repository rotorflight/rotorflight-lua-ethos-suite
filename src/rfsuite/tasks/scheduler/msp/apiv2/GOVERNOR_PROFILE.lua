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

local API_NAME = "GOVERNOR_PROFILE"
local MSP_API_CMD_READ = 148
local MSP_API_CMD_WRITE = 149

local FIELD_SPEC
local SIM_RESPONSE
local GOVERNOR_FLAGS_BITMAP = nil

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 9}) then
    local tblOffOn = {
        "@i18n(api.GOVERNOR_PROFILE.tbl_off)@",
        "@i18n(api.GOVERNOR_PROFILE.tbl_on)@"
    }

    GOVERNOR_FLAGS_BITMAP = {
        {field = "bit0_spare"},
        {field = "bit1_spare"},
        {field = "fallback_precomp", table = tblOffOn, tableIdxInc = -1},
        {field = "voltage_comp", table = tblOffOn, tableIdxInc = -1},
        {field = "pid_spoolup", table = tblOffOn, tableIdxInc = -1},
        {field = "bit5_spare"},
        {field = "dyn_min_throttle", table = tblOffOn, tableIdxInc = -1},
    }

    -- Tuple layout:
    --   field, type, min, max, default, unit,
    --   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
    FIELD_SPEC = {
        {"governor_headspeed", "U16", 0, 50000, 1000, "rpm", nil, nil, 10},
        {"governor_gain", "U8", 0, 250, 40},
        {"governor_p_gain", "U8", 0, 250, 40},
        {"governor_i_gain", "U8", 0, 250, 50},
        {"governor_d_gain", "U8", 0, 250, 0},
        {"governor_f_gain", "U8", 0, 250, 10},
        {"governor_tta_gain", "U8", 0, 250, 0},
        {"governor_tta_limit", "U8", 0, 250, 20, "%"},
        {"governor_yaw_weight", "U8", 0, 250, 0},
        {"governor_cyclic_weight", "U8", 0, 250, 10},
        {"governor_collective_weight", "U8", 0, 250, 100},
        {"governor_max_throttle", "U8", 0, 100, 100, "%"},
        {"governor_min_throttle", "U8", 0, 100, 10, "%"},
        {"governor_fallback_drop", "U8", 0, 50, 10, "%"},
        {"governor_flags", "U16"}
    }

    SIM_RESPONSE = core.simResponse({
        208, 7, -- governor_headspeed
        100,    -- governor_gain
        10,     -- governor_p_gain
        125,    -- governor_i_gain
        5,      -- governor_d_gain
        20,     -- governor_f_gain
        0,      -- governor_tta_gain
        20,     -- governor_tta_limit
        10,     -- governor_yaw_weight
        40,     -- governor_cyclic_weight
        100,    -- governor_collective_weight
        100,    -- governor_max_throttle
        10,     -- governor_min_throttle
        10,     -- governor_fallback_drop
        251, 3  -- governor_flags
    })
else
    -- Tuple layout:
    --   field, type, min, max, default, unit,
    --   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
    FIELD_SPEC = {
        {"governor_headspeed", "U16", 0, 50000, 1000, "rpm", nil, nil, 10},
        {"governor_gain", "U8", 0, 250, 40},
        {"governor_p_gain", "U8", 0, 250, 40},
        {"governor_i_gain", "U8", 0, 250, 50},
        {"governor_d_gain", "U8", 0, 250, 0},
        {"governor_f_gain", "U8", 0, 250, 10},
        {"governor_tta_gain", "U8", 0, 250, 0},
        {"governor_tta_limit", "U8", 0, 250, 20, "%"},
        {"governor_yaw_ff_weight", "U8", 0, 250, 0},
        {"governor_cyclic_ff_weight", "U8", 0, 250, 10},
        {"governor_collective_ff_weight", "U8", 0, 250, 100},
        {"governor_max_throttle", "U8", 0, 100, 100, "%"},
        {"governor_min_throttle", "U8", 0, 100, 10, "%"}
    }

    SIM_RESPONSE = core.simResponse({
        208, 7, -- governor_headspeed
        100,    -- governor_gain
        10,     -- governor_p_gain
        125,    -- governor_i_gain
        5,      -- governor_d_gain
        20,     -- governor_f_gain
        0,      -- governor_tta_gain
        20,     -- governor_tta_limit
        10,     -- governor_yaw_ff_weight
        40,     -- governor_cyclic_ff_weight
        100,    -- governor_collective_ff_weight
        100,    -- governor_max_throttle
        10      -- governor_min_throttle
    })
end

local api = core.createConfigAPI({
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

local function attachGovernorFlagsBitmap(structure)
    if type(structure) ~= "table" then return end

    for _, entry in ipairs(structure) do
        if type(entry) == "table" and entry.field == "governor_flags" then
            entry.bitmap = GOVERNOR_FLAGS_BITMAP
            return
        end
    end
end

if GOVERNOR_FLAGS_BITMAP then
    attachGovernorFlagsBitmap(api.__rfReadStructure)
    if api.__rfWriteStructure ~= api.__rfReadStructure then
        attachGovernorFlagsBitmap(api.__rfWriteStructure)
    end
end

return api
