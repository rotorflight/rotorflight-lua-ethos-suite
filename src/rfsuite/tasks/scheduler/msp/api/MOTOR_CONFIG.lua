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

local API_NAME = "MOTOR_CONFIG"
local MSP_API_CMD_READ = 131
local MSP_API_CMD_WRITE = 222
local MSP_REBUILD_ON_WRITE = true

local pwmProtocol

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 7}) then
    pwmProtocol = {"PWM", "ONESHOT125", "ONESHOT42", "MULTISHOT", "BRUSHED", "DSHOT150", "DSHOT300", "DSHOT600", "PROSHOT", "CASTLE", "DISABLED"}
else
    pwmProtocol = {"PWM", "ONESHOT125", "ONESHOT42", "MULTISHOT", "BRUSHED", "DSHOT150", "DSHOT300", "DSHOT600", "PROSHOT","DISABLED"}
end

local onoff = {"@i18n(api.MOTOR_CONFIG.tbl_off)@", "@i18n(api.MOTOR_CONFIG.tbl_on)@"}

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "minthrottle",                 type = "U16", apiVersion = {12, 0, 6}, simResponse = {45, 4},  unit="us", min = 50,   max = 2250, default = 1070, help = "@i18n(api.MOTOR_CONFIG.minthrottle)@" },
    { field = "maxthrottle",                 type = "U16", apiVersion = {12, 0, 6}, simResponse = {208, 7},  unit="us",  min = 50,   max = 2250, default = 2000, help = "@i18n(api.MOTOR_CONFIG.maxthrottle)@" },
    { field = "mincommand",                  type = "U16", apiVersion = {12, 0, 6}, simResponse = {232, 3},  unit="us",  min = 50,   max = 2250, default = 1000, help = "@i18n(api.MOTOR_CONFIG.mincommand)@" },
    { field = "motor_count_blheli",          type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1},                              help = "@i18n(api.MOTOR_CONFIG.motor_count_blheli)@" },
    { field = "motor_pole_count_blheli",     type = "U8",  apiVersion = {12, 0, 6}, simResponse = {6},                              help = "@i18n(api.MOTOR_CONFIG.motor_pole_count_blheli)@" },

    { field = "use_dshot_telemetry",         type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0},  table = onoff, tableIdxInc = -1,  help = "@i18n(api.MOTOR_CONFIG.use_dshot_telemetry)@" },
    { field = "motor_pwm_protocol",          type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0}, table = pwmProtocol, tableIdxInc = -1, help = "@i18n(api.MOTOR_CONFIG.motor_pwm_protocol)@" },
    { field = "motor_pwm_rate",              type = "U16", apiVersion = {12, 0, 6}, simResponse = {250, 0}, min = 50,  max = 8000, default = 250, unit = "Hz", help = "@i18n(api.MOTOR_CONFIG.motor_pwm_rate)@" },
    { field = "use_unsynced_pwm",            type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1}, table = onoff, tableIdxInc = -1,                       help = "@i18n(api.MOTOR_CONFIG.use_unsynced_pwm)@" },

    { field = "motor_pole_count_0",          type = "U8",  apiVersion = {12, 0, 6}, simResponse = {6},  min = 2,   max = 256,  step = 2, default = 10, help = "@i18n(api.MOTOR_CONFIG.motor_pole_count_0)@" },
    { field = "motor_pole_count_1",          type = "U8",  apiVersion = {12, 0, 6}, simResponse = {4},                                                   help = "@i18n(api.MOTOR_CONFIG.motor_pole_count_1)@" },
    { field = "motor_pole_count_2",          type = "U8",  apiVersion = {12, 0, 6}, simResponse = {2},                                                   help = "@i18n(api.MOTOR_CONFIG.motor_pole_count_2)@" },
    { field = "motor_pole_count_3",          type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1},                                                   help = "@i18n(api.MOTOR_CONFIG.motor_pole_count_3)@" },

    { field = "motor_rpm_lpf_0",             type = "U8",  apiVersion = {12, 0, 6}, simResponse = {8},                                                   help = "@i18n(api.MOTOR_CONFIG.motor_rpm_lpf_0)@" },
    { field = "motor_rpm_lpf_1",             type = "U8",  apiVersion = {12, 0, 6}, simResponse = {7},                                                   help = "@i18n(api.MOTOR_CONFIG.motor_rpm_lpf_1)@" },
    { field = "motor_rpm_lpf_2",             type = "U8",  apiVersion = {12, 0, 6}, simResponse = {7},                                                   help = "@i18n(api.MOTOR_CONFIG.motor_rpm_lpf_2)@" },
    { field = "motor_rpm_lpf_3",             type = "U8",  apiVersion = {12, 0, 6}, simResponse = {8},                                                   help = "@i18n(api.MOTOR_CONFIG.motor_rpm_lpf_3)@" },

    { field = "main_rotor_gear_ratio_0",     type = "U16", apiVersion = {12, 0, 6}, simResponse = {20, 0}, min = 1,  max = 50000, default = 1, help = "@i18n(api.MOTOR_CONFIG.main_rotor_gear_ratio_0)@" },
    { field = "main_rotor_gear_ratio_1",     type = "U16", apiVersion = {12, 0, 6}, simResponse = {50, 0}, min = 1,  max = 50000, default = 1, help = "@i18n(api.MOTOR_CONFIG.main_rotor_gear_ratio_1)@" },
    { field = "tail_rotor_gear_ratio_0",     type = "U16", apiVersion = {12, 0, 6}, simResponse = {9, 0},  min = 1,  max = 50000, default = 1, help = "@i18n(api.MOTOR_CONFIG.tail_rotor_gear_ratio_0)@" },
    { field = "tail_rotor_gear_ratio_1",     type = "U16", apiVersion = {12, 0, 6}, simResponse = {30, 0}, min = 1,  max = 50000, default = 1, help = "@i18n(api.MOTOR_CONFIG.tail_rotor_gear_ratio_1)@" }
}

local MSP_API_STRUCTURE_WRITE = {
    { field = "minthrottle",                 type = "U16", apiVersion = {12, 0, 6}, simResponse = {45, 4},  min = 50,   max = 2250, default = 1070 },
    { field = "maxthrottle",                 type = "U16", apiVersion = {12, 0, 6}, simResponse = {208, 7}, min = 50,   max = 2250, default = 2000 },
    { field = "mincommand",                  type = "U16", apiVersion = {12, 0, 6}, simResponse = {232, 3}, min = 50,   max = 2250, default = 1000 },
    { field = "motor_pole_count_blheli",     type = "U8",  apiVersion = {12, 0, 6}, simResponse = {6} },

    { field = "use_dshot_telemetry",         type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0} },
    { field = "motor_pwm_protocol",          type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0}, table = pwmProtocol, tableIdxInc = -1 },
    { field = "motor_pwm_rate",              type = "U16", apiVersion = {12, 0, 6}, simResponse = {250, 0}, min = 50, max = 8000, default = 250, unit = "Hz" },
    { field = "use_unsynced_pwm",            type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },

    { field = "motor_pole_count_0",          type = "U8",  apiVersion = {12, 0, 6}, simResponse = {6}, min = 2,  max = 256, default = 8 },
    { field = "motor_pole_count_1",          type = "U8",  apiVersion = {12, 0, 6}, simResponse = {4} },
    { field = "motor_pole_count_2",          type = "U8",  apiVersion = {12, 0, 6}, simResponse = {2} },
    { field = "motor_pole_count_3",          type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },

    { field = "motor_rpm_lpf_0",             type = "U8",  apiVersion = {12, 0, 6}, simResponse = {8} },
    { field = "motor_rpm_lpf_1",             type = "U8",  apiVersion = {12, 0, 6}, simResponse = {7} },
    { field = "motor_rpm_lpf_2",             type = "U8",  apiVersion = {12, 0, 6}, simResponse = {7} },
    { field = "motor_rpm_lpf_3",             type = "U8",  apiVersion = {12, 0, 6}, simResponse = {8} },

    { field = "main_rotor_gear_ratio_0",     type = "U16", apiVersion = {12, 0, 6}, simResponse = {20, 0}, min = 1,  max = 50000, default = 1 },
    { field = "main_rotor_gear_ratio_1",     type = "U16", apiVersion = {12, 0, 6}, simResponse = {50, 0}, min = 1,  max = 50000, default = 1 },
    { field = "tail_rotor_gear_ratio_0",     type = "U16", apiVersion = {12, 0, 6}, simResponse = {9, 0},  min = 1,  max = 50000, default = 1 },
    { field = "tail_rotor_gear_ratio_1",     type = "U16", apiVersion = {12, 0, 6}, simResponse = {30, 0}, min = 1,  max = 50000, default = 1 }
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

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
