--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then msp.apicore = core end
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local API_NAME = "PID_PROFILE"
local MSP_REBUILD_ON_WRITE = false

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "pid_mode", type = "U8", apiVersion = {12, 0, 6}, simResponse = {3}, help = "@i18n(api.PID_PROFILE.pid_mode)@"},
    {field = "error_decay_time_ground", type = "U8", apiVersion = {12, 0, 6}, simResponse = {25}, min = 0, max = 250, default = 2.5, unit = "s", decimals = 1, scale = 10, help = "@i18n(api.PID_PROFILE.error_decay_time_ground)@"},
    {field = "error_decay_time_cyclic", type = "U8", apiVersion = {12, 0, 6}, simResponse = {250}, min = 0, max = 250, default = 25, unit = "s", decimals = 1, scale = 10, help = "@i18n(api.PID_PROFILE.error_decay_time_cyclic)@"},
    {field = "error_decay_time_yaw", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, help = "@i18n(api.PID_PROFILE.error_decay_time_yaw)@"},
    {field = "error_decay_limit_cyclic", type = "U8", apiVersion = {12, 0, 6}, simResponse = {12}, min = 0, max = 25, default = 12, unit = "°", help = "@i18n(api.PID_PROFILE.error_decay_limit_cyclic)@"},
    {field = "error_decay_limit_yaw", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, help = "@i18n(api.PID_PROFILE.error_decay_limit_yaw)@"},
    {field = "error_rotation", type = "U8", apiVersion = {12, 0, 6}, simResponse = {1}, min = 0, max = 1, table = {[0] = "@i18n(api.PID_PROFILE.tbl_off)@", "@i18n(api.PID_PROFILE.tbl_on)@"}, help = "@i18n(api.PID_PROFILE.error_rotation)@"},
    {field = "error_limit_0", type = "U8", apiVersion = {12, 0, 6}, simResponse = {30}, min = 0, max = 180, default = 30, unit = "°", help = "@i18n(api.PID_PROFILE.error_limit_0)@"},
    {field = "error_limit_1", type = "U8", apiVersion = {12, 0, 6}, simResponse = {30}, min = 0, max = 180, default = 30, unit = "°", help = "@i18n(api.PID_PROFILE.error_limit_1)@"},
    {field = "error_limit_2", type = "U8", apiVersion = {12, 0, 6}, simResponse = {45}, min = 0, max = 180, default = 45, unit = "°", help = "@i18n(api.PID_PROFILE.error_limit_2)@"},
    {field = "gyro_cutoff_0", type = "U8", apiVersion = {12, 0, 6}, simResponse = {50}, min = 0, max = 250, default = 50, help = "@i18n(api.PID_PROFILE.gyro_cutoff_0)@"},
    {field = "gyro_cutoff_1", type = "U8", apiVersion = {12, 0, 6}, simResponse = {50}, min = 0, max = 250, default = 50, help = "@i18n(api.PID_PROFILE.gyro_cutoff_1)@"},
    {field = "gyro_cutoff_2", type = "U8", apiVersion = {12, 0, 6}, simResponse = {100}, min = 0, max = 250, default = 100, help = "@i18n(api.PID_PROFILE.gyro_cutoff_2)@"},
    {field = "dterm_cutoff_0", type = "U8", apiVersion = {12, 0, 6}, simResponse = {15}, min = 0, max = 250, default = 15, help = "@i18n(api.PID_PROFILE.dterm_cutoff_0)@"},
    {field = "dterm_cutoff_1", type = "U8", apiVersion = {12, 0, 6}, simResponse = {15}, min = 0, max = 250, default = 15, help = "@i18n(api.PID_PROFILE.dterm_cutoff_1)@"},
    {field = "dterm_cutoff_2", type = "U8", apiVersion = {12, 0, 6}, simResponse = {20}, min = 0, max = 250, default = 20, help = "@i18n(api.PID_PROFILE.dterm_cutoff_2)@"},
    {field = "iterm_relax_type", type = "U8", apiVersion = {12, 0, 6}, simResponse = {2}, min = 0, max = 2, table = {[0] = "@i18n(api.PID_PROFILE.tbl_off)@", "@i18n(api.PID_PROFILE.tbl_rp)@", "@i18n(api.PID_PROFILE.tbl_rpy)@"}, help = "@i18n(api.PID_PROFILE.iterm_relax_type)@"},
    {field = "iterm_relax_cutoff_0", type = "U8", apiVersion = {12, 0, 6}, simResponse = {10}, min = 1, max = 100, default = 10, help = "@i18n(api.PID_PROFILE.iterm_relax_cutoff_0)@"},
    {field = "iterm_relax_cutoff_1", type = "U8", apiVersion = {12, 0, 6}, simResponse = {10}, min = 1, max = 100, default = 10, help = "@i18n(api.PID_PROFILE.iterm_relax_cutoff_1)@"},
    {field = "iterm_relax_cutoff_2", type = "U8", apiVersion = {12, 0, 6}, simResponse = {15}, min = 1, max = 100, default = 10, help = "@i18n(api.PID_PROFILE.iterm_relax_cutoff_2)@"},
    {field = "yaw_cw_stop_gain", type = "U8", apiVersion = {12, 0, 6}, simResponse = {100}, min = 25, max = 250, default = 120, help = "@i18n(api.PID_PROFILE.yaw_cw_stop_gain)@"},
    {field = "yaw_ccw_stop_gain", type = "U8", apiVersion = {12, 0, 6}, simResponse = {100}, min = 25, max = 250, default = 80, help = "@i18n(api.PID_PROFILE.yaw_ccw_stop_gain)@"},
    {field = "yaw_precomp_cutoff", type = "U8", apiVersion = {12, 0, 6}, simResponse = {6}, min = 0, max = 250, default = 5, unit = "Hz", help = "@i18n(api.PID_PROFILE.yaw_precomp_cutoff)@"},
    {field = "yaw_cyclic_ff_gain", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, min = 0, max = 250, default = 0, help = "@i18n(api.PID_PROFILE.yaw_cyclic_ff_gain)@"},
    {field = "yaw_collective_ff_gain", type = "U8", apiVersion = {12, 0, 6}, simResponse = {30}, min = 0, max = 250, default = 30, help = "@i18n(api.PID_PROFILE.yaw_collective_ff_gain)@"},
    {field = "yaw_collective_dynamic_gain", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, min = 0, max = 125, default = 0, help = "@i18n(api.PID_PROFILE.yaw_collective_dynamic_gain)@"},
    {field = "yaw_collective_dynamic_decay", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, min = 0, max = 250, default = 25, unit = "s", help = "@i18n(api.PID_PROFILE.yaw_collective_dynamic_decay)@"},
    {field = "pitch_collective_ff_gain", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, min = 0, max = 250, default = 0, help = "@i18n(api.PID_PROFILE.pitch_collective_ff_gain)@"},
    {field = "angle_level_strength", type = "U8", apiVersion = {12, 0, 6}, simResponse = {40}, min = 0, max = 200, default = 40, help = "@i18n(api.PID_PROFILE.angle_level_strength)@"},
    {field = "angle_level_limit", type = "U8", apiVersion = {12, 0, 6}, simResponse = {55}, min = 10, max = 90, default = 55, unit = "°", help = "@i18n(api.PID_PROFILE.angle_level_limit)@"},
    {field = "horizon_level_strength", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, min = 0, max = 200, default = 40, help = "@i18n(api.PID_PROFILE.horizon_level_strength)@"},
    {field = "trainer_gain", type = "U8", apiVersion = {12, 0, 6}, simResponse = {75}, min = 25, max = 255, default = 75, help = "@i18n(api.PID_PROFILE.trainer_gain)@"},
    {field = "trainer_angle_limit", type = "U8", apiVersion = {12, 0, 6}, simResponse = {20}, min = 10, max = 80, default = 20, unit = "°", help = "@i18n(api.PID_PROFILE.trainer_angle_limit)@"},
    {field = "cyclic_cross_coupling_gain", type = "U8", apiVersion = {12, 0, 6}, simResponse = {25}, min = 0, max = 250, default = 50, help = "@i18n(api.PID_PROFILE.cyclic_cross_coupling_gain)@"},
    {field = "cyclic_cross_coupling_ratio", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, min = 0, max = 200, default = 0, unit = "%", help = "@i18n(api.PID_PROFILE.cyclic_cross_coupling_ratio)@"},
    {field = "cyclic_cross_coupling_cutoff", type = "U8", apiVersion = {12, 0, 6}, simResponse = {15}, min = 1, max = 250, default = 2.5, unit = "Hz", scale = 10, decimals = 1, help = "@i18n(api.PID_PROFILE.cyclic_cross_coupling_cutoff)@"},
    {field = "offset_limit_0", type = "U8", apiVersion = {12, 0, 6}, simResponse = {45}, min = 0, max = 180, default = 45, unit = "°", help = "@i18n(api.PID_PROFILE.offset_limit_0)@"},
    {field = "offset_limit_1", type = "U8", apiVersion = {12, 0, 6}, simResponse = {45}, min = 0, max = 180, default = 45, unit = "°", help = "@i18n(api.PID_PROFILE.offset_limit_1)@"},
    {field = "bterm_cutoff_0", type = "U8", apiVersion = {12, 0, 6}, simResponse = {15}, min = 0, max = 250, default = 15, help = "@i18n(api.PID_PROFILE.bterm_cutoff_0)@"},
    {field = "bterm_cutoff_1", type = "U8", apiVersion = {12, 0, 6}, simResponse = {15}, min = 0, max = 250, default = 15, help = "@i18n(api.PID_PROFILE.bterm_cutoff_1)@"},
    {field = "bterm_cutoff_2", type = "U8", apiVersion = {12, 0, 6}, simResponse = {20}, min = 0, max = 250, default = 20, help = "@i18n(api.PID_PROFILE.bterm_cutoff_2)@"},
    {field = "yaw_inertia_precomp_gain", type = "U8", apiVersion = {12, 0, 8}, simResponse = {10}, min = 0, max = 250, default = 0, help = "@i18n(api.PID_PROFILE.yaw_inertia_precomp_gain)@"},
    {field = "yaw_inertia_precomp_cutoff", type = "U8", apiVersion = {12, 0, 8}, simResponse = {20}, min = 0, max = 250, default = 2.5, scale = 10, decimals = 1, unit = "Hz", help = "@i18n(api.PID_PROFILE.yaw_inertia_precomp_cutoff)@"}
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)
local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

local function parseRead(buf)
    local result = nil
    core.parseMSPData(API_NAME, buf, MSP_API_STRUCTURE_READ, nil, nil, function(parsed)
        result = parsed
    end)
    if result == nil then
        return nil, "parse_failed"
    end
    return result
end

local function buildWritePayload(payloadData, _, _, state)
    return core.buildWritePayload(API_NAME, payloadData, MSP_API_STRUCTURE_WRITE, state.rebuildOnWrite == true)
end

return factory.create({
    name = API_NAME,
    readCmd = 94,
    writeCmd = 95,
    minBytes = MSP_MIN_BYTES,
    readStructure = MSP_API_STRUCTURE_READ,
    simulatorResponseRead = MSP_API_SIMULATOR_RESPONSE,
    parseRead = parseRead,
    buildWritePayload = buildWritePayload,
    writeUuidFallback = true,
    initialRebuildOnWrite = MSP_REBUILD_ON_WRITE,
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end
})
