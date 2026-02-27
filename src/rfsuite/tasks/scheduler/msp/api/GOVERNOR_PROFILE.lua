--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then msp.apicore = core end
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local API_NAME = "GOVERNOR_PROFILE"
local MSP_API_CMD_READ = 148
local MSP_API_CMD_WRITE = 149
local MSP_REBUILD_ON_WRITE = false

local MSP_API_STRUCTURE_READ_DATA

-- LuaFormatter off
if rfsuite.utils.apiVersionCompare(">=", {12, 0, 9}) then

    local offOn = {
        "@i18n(api.GOVERNOR_PROFILE.tbl_off)@",
        "@i18n(api.GOVERNOR_PROFILE.tbl_on)@"
    }

    local governor_flags_bitmap = {
        { field = "bit0_spare" }, -- bit 0
        { field = "bit1_spare" }, -- bit 1
        { field = "fallback_precomp",   table = offOn, tableIdxInc = -1, help = "@i18n(api.GOVERNOR_PROFILE.fallback_precomp)@" }, -- bit 2
        { field = "voltage_comp",       table = offOn, tableIdxInc = -1, help = "@i18n(api.GOVERNOR_PROFILE.voltage_comp)@" },     -- bit 3
        { field = "pid_spoolup",        table = offOn, tableIdxInc = -1, help = "@i18n(api.GOVERNOR_PROFILE.pid_spoolup)@" },      -- bit 4
        { field = "bit5_spare" }, -- bit 5
        { field = "dyn_min_throttle",   table = offOn, tableIdxInc = -1, help = "@i18n(api.GOVERNOR_PROFILE.dyn_min_throttle)@" }, -- bit 6
    }

    MSP_API_STRUCTURE_READ_DATA = {
        { field = "governor_headspeed",        type = "U16", apiVersion = {12, 0, 9}, simResponse = {208, 7},  min = 0,   max = 50000, default = 1000, unit = "rpm", step = 10, help = "@i18n(api.GOVERNOR_PROFILE.governor_headspeed)@" },
        { field = "governor_gain",             type = "U8",  apiVersion = {12, 0, 9}, simResponse = {100},      min = 0,   max = 250,   default = 40,  help = "@i18n(api.GOVERNOR_PROFILE.governor_gain)@" },
        { field = "governor_p_gain",           type = "U8",  apiVersion = {12, 0, 9}, simResponse = {10},       min = 0,   max = 250,   default = 40,  help = "@i18n(api.GOVERNOR_PROFILE.governor_p_gain)@" },
        { field = "governor_i_gain",           type = "U8",  apiVersion = {12, 0, 9}, simResponse = {125},      min = 0,   max = 250,   default = 50,  help = "@i18n(api.GOVERNOR_PROFILE.governor_i_gain)@" },
        { field = "governor_d_gain",           type = "U8",  apiVersion = {12, 0, 9}, simResponse = {5},        min = 0,   max = 250,   default = 0,   help = "@i18n(api.GOVERNOR_PROFILE.governor_d_gain)@" },
        { field = "governor_f_gain",           type = "U8",  apiVersion = {12, 0, 9}, simResponse = {20},       min = 0,   max = 250,   default = 10,  help = "@i18n(api.GOVERNOR_PROFILE.governor_f_gain)@" },
        { field = "governor_tta_gain",         type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0},        min = 0,   max = 250,   default = 0,   help = "@i18n(api.GOVERNOR_PROFILE.governor_tta_gain)@" },
        { field = "governor_tta_limit",        type = "U8",  apiVersion = {12, 0, 9}, simResponse = {20},       min = 0,   max = 250,   default = 20,  unit = "%", help = "@i18n(api.GOVERNOR_PROFILE.governor_tta_limit)@" },
        { field = "governor_yaw_weight",       type = "U8",  apiVersion = {12, 0, 9}, simResponse = {10},       min = 0,   max = 250,   default = 0,   help = "@i18n(api.GOVERNOR_PROFILE.governor_yaw_weight)@" },
        { field = "governor_cyclic_weight",    type = "U8",  apiVersion = {12, 0, 9}, simResponse = {40},       min = 0,   max = 250,   default = 10,  help = "@i18n(api.GOVERNOR_PROFILE.governor_cyclic_weight)@" },
        { field = "governor_collective_weight",type = "U8",  apiVersion = {12, 0, 9}, simResponse = {100},      min = 0,   max = 250,   default = 100, help = "@i18n(api.GOVERNOR_PROFILE.governor_collective_weight)@" },
        { field = "governor_max_throttle",     type = "U8",  apiVersion = {12, 0, 9}, simResponse = {100},      min = 0,   max = 100,   default = 100, unit = "%", help = "@i18n(api.GOVERNOR_PROFILE.governor_max_throttle)@" },
        { field = "governor_min_throttle",     type = "U8",  apiVersion = {12, 0, 9}, simResponse = {10},       min = 0,   max = 100,   default = 10,  unit = "%", help = "@i18n(api.GOVERNOR_PROFILE.governor_min_throttle)@" },
        { field = "governor_fallback_drop",    type = "U8",  apiVersion = {12, 0, 9}, simResponse = {10},       min = 0,   max = 50,    default = 10,  unit = "%", help = "@i18n(api.GOVERNOR_PROFILE.governor_fallback_drop)@" },
        { field = "governor_flags",            type = "U16", apiVersion = {12, 0, 9}, simResponse = {251, 3}, bitmap = governor_flags_bitmap, help = "@i18n(api.GOVERNOR_PROFILE.governor_flags)@" }
    }

else

    MSP_API_STRUCTURE_READ_DATA = {
        { field = "governor_headspeed",           type = "U16", apiVersion = {12, 0, 6}, simResponse = {208, 7},  min = 0,   max = 50000, default = 1000, unit = "rpm", step = 10, help = "@i18n(api.GOVERNOR_PROFILE.governor_headspeed)@" },
        { field = "governor_gain",                type = "U8",  apiVersion = {12, 0, 6}, simResponse = {100},      min = 0,   max = 250,   default = 40,  help = "@i18n(api.GOVERNOR_PROFILE.governor_gain)@" },
        { field = "governor_p_gain",              type = "U8",  apiVersion = {12, 0, 6}, simResponse = {10},       min = 0,   max = 250,   default = 40,  help = "@i18n(api.GOVERNOR_PROFILE.governor_p_gain)@" },
        { field = "governor_i_gain",              type = "U8",  apiVersion = {12, 0, 6}, simResponse = {125},      min = 0,   max = 250,   default = 50,  help = "@i18n(api.GOVERNOR_PROFILE.governor_i_gain)@" },
        { field = "governor_d_gain",              type = "U8",  apiVersion = {12, 0, 6}, simResponse = {5},        min = 0,   max = 250,   default = 0,   help = "@i18n(api.GOVERNOR_PROFILE.governor_d_gain)@" },
        { field = "governor_f_gain",              type = "U8",  apiVersion = {12, 0, 6}, simResponse = {20},       min = 0,   max = 250,   default = 10,  help = "@i18n(api.GOVERNOR_PROFILE.governor_f_gain)@" },
        { field = "governor_tta_gain",            type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0},        min = 0,   max = 250,   default = 0,   help = "@i18n(api.GOVERNOR_PROFILE.governor_tta_gain)@" },
        { field = "governor_tta_limit",           type = "U8",  apiVersion = {12, 0, 6}, simResponse = {20},       min = 0,   max = 250,   default = 20,  unit = "%", help = "@i18n(api.GOVERNOR_PROFILE.governor_tta_limit)@" },
        { field = "governor_yaw_ff_weight",       type = "U8",  apiVersion = {12, 0, 6}, simResponse = {10},       min = 0,   max = 250,   default = 0,   help = "@i18n(api.GOVERNOR_PROFILE.governor_yaw_ff_weight)@" },
        { field = "governor_cyclic_ff_weight",    type = "U8",  apiVersion = {12, 0, 6}, simResponse = {40},       min = 0,   max = 250,   default = 10,  help = "@i18n(api.GOVERNOR_PROFILE.governor_cyclic_ff_weight)@" },
        { field = "governor_collective_ff_weight",type = "U8",  apiVersion = {12, 0, 6}, simResponse = {100},      min = 0,   max = 250,   default = 100, help = "@i18n(api.GOVERNOR_PROFILE.governor_collective_ff_weight)@" },
        { field = "governor_max_throttle",        type = "U8",  apiVersion = {12, 0, 6}, simResponse = {100},      min = 0,   max = 100,   default = 100, unit = "%", help = "@i18n(api.GOVERNOR_PROFILE.governor_max_throttle)@" },
        { field = "governor_min_throttle",        type = "U8",  apiVersion = {12, 0, 6}, simResponse = {10},       min = 0,   max = 100,   default = 10,  unit = "%", help = "@i18n(api.GOVERNOR_PROFILE.governor_min_throttle)@" }
    }

end
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
    local writeStructure = MSP_API_STRUCTURE_WRITE
    if writeStructure == nil then return {} end
    return core.buildWritePayload(API_NAME, payloadData, writeStructure, state.rebuildOnWrite == true)
end

return factory.create({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    minBytes = MSP_MIN_BYTES or 0,
    readStructure = MSP_API_STRUCTURE_READ,
    writeStructure = MSP_API_STRUCTURE_WRITE,
    simulatorResponseRead = MSP_API_SIMULATOR_RESPONSE or {},
    parseRead = parseRead,
    buildWritePayload = buildWritePayload,
    writeUuidFallback = true,
    initialRebuildOnWrite = (MSP_REBUILD_ON_WRITE == true),
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end,
    exports = {
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
    }
})
