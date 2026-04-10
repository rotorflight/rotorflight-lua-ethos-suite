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

local API_NAME = "MIXER_CONFIG"
local MSP_API_CMD_READ = 42
local MSP_API_CMD_WRITE = 43

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"main_rotor_dir", "U8", nil, nil, nil, nil, nil, nil, nil, {"@i18n(api.MIXER_CONFIG.tbl_cw)@", "@i18n(api.MIXER_CONFIG.tbl_ccw)@"}, -1},
    {"tail_rotor_mode", "U8", nil, nil, nil, nil, nil, nil, nil, {"@i18n(api.MIXER_CONFIG.tbl_tail_variable_pitch)@", "@i18n(api.MIXER_CONFIG.tbl_tail_motororized_tail)@", "@i18n(api.MIXER_CONFIG.tbl_tail_bidirectional)@"}, -1},
    {"tail_motor_idle", "U8", 0, 250, 0, "%", 1, 10},
    {"tail_center_trim", "S16", -500, 500, 0, "%", 1, 10, nil, 0.239923224568138},
    {"swash_type", "U8", nil, nil, nil, nil, nil, nil, nil, {"None", "Direct", "CPPM 120", "CPPM 135", "CPPM 140", "FPM 90 L", "FPM 90 V"}, -1},
    {"swash_ring", "U8"},
    {"swash_phase", "S16", -1800, 1800, 0, "°", 1, 10},
    {"swash_pitch_limit", "U16", 0, 360, 0, "°", nil, nil, 1, 0.01200192},
    {"swash_trim_0", "S16", -1000, 1000, 0, "%", 1, 10},
    {"swash_trim_1", "S16", -1000, 1000, 0, "%", 1, 10},
    {"swash_trim_2", "S16", -1000, 1000, 0, "%", 1, 10},
    {"swash_tta_precomp", "U8", 0, 250, 0}
}

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 7}) then
    FIELD_SPEC[#FIELD_SPEC + 1] = {"swash_geo_correction", "S8", -250, 250, 0, "%", 1, 5, 2}
end

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 8}) then
    FIELD_SPEC[#FIELD_SPEC + 1] = {"collective_tilt_correction_pos", "S8", -100, 100, 0, "°"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"collective_tilt_correction_neg", "S8", -100, 100, 10, "°"}
end

local SIM_RESPONSE = core.simResponse({
    0,        -- main_rotor_dir
    0,        -- tail_rotor_mode
    0,        -- tail_motor_idle
    165, 1,   -- tail_center_trim
    0,        -- swash_type
    2,        -- swash_ring
    100, 0,   -- swash_phase
    131, 6,   -- swash_pitch_limit
    0, 0,     -- swash_trim_0
    0, 0,     -- swash_trim_1
    0, 0,     -- swash_trim_2
    0,        -- swash_tta_precomp
    10,       -- swash_geo_correction
    3,        -- collective_tilt_correction_pos
    11        -- collective_tilt_correction_neg
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
