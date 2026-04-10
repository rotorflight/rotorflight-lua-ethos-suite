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

local API_NAME = "GOVERNOR_CONFIG"
local MSP_API_CMD_READ = 142
local MSP_API_CMD_WRITE = 143

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC
local SIM_RESPONSE

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 9}) then
    local govModeTable = {
        [0] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_off)@",
        [1] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_limit)@",
        [2] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_direct)@",
        [3] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_electric)@",
        [4] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_nitro)@"
    }
    local throttleTypeTable = {
        [0] = "@i18n(api.GOVERNOR_CONFIG.tbl_throttle_type_normal)@",
        [1] = "@i18n(api.GOVERNOR_CONFIG.tbl_throttle_type_switch)@",
        [2] = "@i18n(api.GOVERNOR_CONFIG.tbl_throttle_type_function)@"
    }

    FIELD_SPEC = {
        {"gov_mode", "U8", 0, #govModeTable, nil, nil, nil, nil, nil, govModeTable},
        {"gov_startup_time", "U16", 0, 600, 200, "", 1, 10},
        {"gov_spoolup_time", "U16", 0, 600, 100, "%/s", 1, 10},
        {"gov_tracking_time", "U16", 0, 100, 10, "%/s", 1, 10},
        {"gov_recovery_time", "U16", 0, 100, 21, "%/s", 1, 10},
        {"gov_throttle_hold_timeout", "U16", 0, 250, 5, "s", 1, 10},
        {"spare_0", "U16"},
        {"gov_autorotation_timeout", "U16", 0, 250, nil, "s"},
        {"spare_1", "U16"},
        {"spare_2", "U16"},
        {"gov_handover_throttle", "U8", 0, 50, 20, "%"},
        {"gov_pwr_filter", "U8", 0, 250, 20, "Hz"},
        {"gov_rpm_filter", "U8", 0, 250, 20, "Hz"},
        {"gov_tta_filter", "U8", 0, 250, 20, "Hz"},
        {"gov_ff_filter", "U8", 0, 25, 10, "Hz"},
        {"spare_3", "U8"},
        {"gov_d_filter", "U8", 0, 250, 50, "Hz", 1, 10},
        {"gov_spooldown_time", "U16", 0, 600, 100, "%/s", 1, 10},
        {"gov_throttle_type", "U8", 0, #throttleTypeTable, nil, nil, nil, nil, nil, throttleTypeTable},
        {"spare_4", "S8"},
        {"spare_5", "S8"},
        {"governor_idle_throttle", "U8", 0, 250, 0, "%", 1, 10},
        {"governor_auto_throttle", "U8", 0, 250, 0, "%", 1, 10},
        {"gov_bypass_throttle_curve_1", "U8"},
        {"gov_bypass_throttle_curve_2", "U8"},
        {"gov_bypass_throttle_curve_3", "U8"},
        {"gov_bypass_throttle_curve_4", "U8"},
        {"gov_bypass_throttle_curve_5", "U8"},
        {"gov_bypass_throttle_curve_6", "U8"},
        {"gov_bypass_throttle_curve_7", "U8"},
        {"gov_bypass_throttle_curve_8", "U8"},
        {"gov_bypass_throttle_curve_9", "U8"}
    }

    SIM_RESPONSE = core.simResponse({
        2,       -- gov_mode
        200, 0,  -- gov_startup_time
        100, 0,  -- gov_spoolup_time
        20, 0,   -- gov_tracking_time
        20, 0,   -- gov_recovery_time
        50, 0,   -- gov_throttle_hold_timeout
        0, 0,    -- spare_0
        0, 0,    -- gov_autorotation_timeout
        0, 0,    -- spare_1
        0, 0,    -- spare_2
        20,      -- gov_handover_throttle
        20,      -- gov_pwr_filter
        20,      -- gov_rpm_filter
        0,       -- gov_tta_filter
        10,      -- gov_ff_filter
        0,       -- spare_3
        50,      -- gov_d_filter
        30, 0,   -- gov_spooldown_time
        0,       -- gov_throttle_type
        0,       -- spare_4
        0,       -- spare_5
        10,      -- governor_idle_throttle
        10,      -- governor_auto_throttle
        0,       -- gov_bypass_throttle_curve_1
        10,      -- gov_bypass_throttle_curve_2
        20,      -- gov_bypass_throttle_curve_3
        30,      -- gov_bypass_throttle_curve_4
        50,      -- gov_bypass_throttle_curve_5
        60,      -- gov_bypass_throttle_curve_6
        70,      -- gov_bypass_throttle_curve_7
        80,      -- gov_bypass_throttle_curve_8
        100      -- gov_bypass_throttle_curve_9
    })
else
    local govModeTable = {
        [0] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_off)@",
        [1] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_passthrough)@",
        [2] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_standard)@",
        [3] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_mode1)@",
        [4] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_mode2)@"
    }

    FIELD_SPEC = {
        {"gov_mode", "U8", 0, #govModeTable, nil, nil, nil, nil, nil, govModeTable},
        {"gov_startup_time", "U16", 0, 600, 200, "s", 1, 10},
        {"gov_spoolup_time", "U16", 0, 600, 100, "s", 1, 10},
        {"gov_tracking_time", "U16", 0, 100, 10, "s", 1, 10},
        {"gov_recovery_time", "U16", 0, 100, 21, "s", 1, 10},
        {"gov_zero_throttle_timeout", "U16"},
        {"gov_lost_headspeed_timeout", "U16"},
        {"gov_autorotation_timeout", "U16"},
        {"gov_autorotation_bailout_time", "U16"},
        {"gov_autorotation_min_entry_time", "U16"},
        {"gov_handover_throttle", "U8", 10, 50, 20, "%"},
        {"gov_pwr_filter", "U8"},
        {"gov_rpm_filter", "U8"},
        {"gov_tta_filter", "U8"},
        {"gov_ff_filter", "U8"}
    }

    if rfsuite.utils.apiVersionCompare(">=", {12, 0, 8}) then
        FIELD_SPEC[#FIELD_SPEC + 1] = {"gov_spoolup_min_throttle", "U8", 0, 50, 0, "%"}
    end

    SIM_RESPONSE = core.simResponse({
        3,       -- gov_mode
        100, 0,  -- gov_startup_time
        100, 0,  -- gov_spoolup_time
        20, 0,   -- gov_tracking_time
        20, 0,   -- gov_recovery_time
        30, 0,   -- gov_zero_throttle_timeout
        10, 0,   -- gov_lost_headspeed_timeout
        0, 0,    -- gov_autorotation_timeout
        0, 0,    -- gov_autorotation_bailout_time
        50, 0,   -- gov_autorotation_min_entry_time
        10,      -- gov_handover_throttle
        5,       -- gov_pwr_filter
        10,      -- gov_rpm_filter
        0,       -- gov_tta_filter
        10,      -- gov_ff_filter
        5        -- gov_spoolup_min_throttle
    })
end

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
