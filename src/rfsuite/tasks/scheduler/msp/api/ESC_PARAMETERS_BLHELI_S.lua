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

local API_NAME = "ESC_PARAMETERS_BLHELI_S"
local MSP_SIGNATURE = 0xC1
local MSP_HEADER_BYTES = 2

local onOff = {"Off", "On"}
local startupPower = {"0.031", "0.047", "0.063", "0.094", "0.125", "0.188", "0.25", "0.38", "0.50", "0.75", "1.00", "1.25", "1.50"}
local motorDirection = {"Normal", "Reversed", "Forward/Reverse (3D)", "Forward/Reverse (3D) Rev"}
local commutationTiming = {"Low", "Medium Low", "Medium", "Medium High", "High"}
local demagCompensation = {"Off", "Low", "High"}
local beaconDelay = {"1 minute", "2 minutes", "5 minutes", "10 minutes", "Infinite"}
local temperatureProtection = {[0] = "Disabled", "80C", "90C", "100C", "110C", "120C", "130C", "140C"}

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_signature",             type = "U8",   apiVersion = {12, 0, 9}, simResponse = {193}},
    {field = "esc_command",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "main_revision",             type = "U8",   apiVersion = {12, 0, 9}, simResponse = {16}},
    {field = "sub_revision",              type = "U8",   apiVersion = {12, 0, 9}, simResponse = {7}},
    {field = "layout_revision",           type = "U8",   apiVersion = {12, 0, 9}, simResponse = {33}},
    {field = "p_gain",                    type = "U8",   apiVersion = {12, 0, 9}, simResponse = {7}},
    {field = "i_gain",                    type = "U8",   apiVersion = {12, 0, 9}, simResponse = {7}},
    {field = "governor_mode",             type = "U8",   apiVersion = {12, 0, 9}, simResponse = {4}},
    {field = "low_voltage_limit",         type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "motor_gain",                type = "U8",   apiVersion = {12, 0, 9}, simResponse = {3}},
    {field = "motor_idle",                type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "startup_power",             type = "U8",   apiVersion = {12, 0, 9}, simResponse = {9},  table = startupPower},
    {field = "pwm_frequency",             type = "U8",   apiVersion = {12, 0, 9}, simResponse = {24}},
    {field = "motor_direction",           type = "U8",   apiVersion = {12, 0, 9}, simResponse = {1},  tableIdxInc = -1, table = motorDirection},
    {field = "input_pwm_polarity",        type = "U8",   apiVersion = {12, 0, 9}, simResponse = {1}},
    {field = "mode_raw",                  type = "U16",  apiVersion = {12, 0, 9}, simResponse = {170, 85}},
    {field = "programming_by_tx",         type = "U8",   apiVersion = {12, 0, 9}, simResponse = {1},  tableIdxInc = -1, table = onOff},
    {field = "rearm_at_start",            type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "governor_setup_target",     type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "startup_rpm",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "startup_acceleration",      type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "volt_comp",                 type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "commutation_timing",        type = "U8",   apiVersion = {12, 0, 9}, simResponse = {3},  tableIdxInc = -1, table = commutationTiming},
    {field = "damping_force",             type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "governor_range",            type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "startup_method",            type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "ppm_min_throttle",          type = "U8",   apiVersion = {12, 0, 9}, simResponse = {37}, min = 1000, max = 1500, step = 4},
    {field = "ppm_max_throttle",          type = "U8",   apiVersion = {12, 0, 9}, simResponse = {208}, min = 1504, max = 2020, step = 4},
    {field = "beep_strength",             type = "U8",   apiVersion = {12, 0, 9}, simResponse = {40}, min = 1, max = 255, step = 1},
    {field = "beacon_strength",           type = "U8",   apiVersion = {12, 0, 9}, simResponse = {80}, min = 1, max = 255, step = 1},
    {field = "beacon_delay",              type = "U8",   apiVersion = {12, 0, 9}, simResponse = {4},  tableIdxInc = -1, table = beaconDelay},
    {field = "throttle_rate",             type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "demag_compensation",        type = "U8",   apiVersion = {12, 0, 9}, simResponse = {2},  tableIdxInc = -1, table = demagCompensation},
    {field = "bec_voltage",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "ppm_center_throttle",       type = "U8",   apiVersion = {12, 0, 9}, simResponse = {122}, min = 1000, max = 2020, step = 4},
    {field = "spoolup_time",              type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "temperature_protection",    type = "U8",   apiVersion = {12, 0, 9}, simResponse = {7},  table = temperatureProtection},
    {field = "low_rpm_power_protection",  type = "U8",   apiVersion = {12, 0, 9}, simResponse = {1},  tableIdxInc = -1,table = onOff},
    {field = "pwm_input",                 type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "pwm_dither",                type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "brake_on_stop",             type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0},  tableIdxInc = -1, table = onOff},
    {field = "led_control",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_29",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_2a",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_2b",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_2c",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_2d",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_2e",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_2f",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_30",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_31",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_32",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_33",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_34",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_35",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_36",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_37",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_38",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_39",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_3a",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_3b",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_3c",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_3d",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_3e",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_3f",               type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "layout_block",              type = "U128", apiVersion = {12, 0, 9}, simResponse = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}},
    {field = "mcu_block",                 type = "U128", apiVersion = {12, 0, 9}, simResponse = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}},
    {field = "name_block",                type = "U128", apiVersion = {12, 0, 9}, simResponse = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}}
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)
local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

local function clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

local function normalizePpm(raw)
    if raw == nil then return nil end
    return (raw * 4) + 1000
end

local function encodePpm(value)
    if value == nil then return nil end
    return clamp(math.floor(((value - 1000) / 4) + 0.5), 0, 255)
end

local function resolveTimeout(state, isWrite)
    if state.timeout ~= nil then return state.timeout end
    local protocolRef = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.protocol
    if not protocolRef then return nil end
    if isWrite then return protocolRef.saveTimeout end
    return protocolRef.pageReqTimeout
end

local function parseRead(buf)
    local result = nil

    core.parseMSPData(API_NAME, buf, MSP_API_STRUCTURE_READ, nil, nil, function(parsed)
        result = parsed
    end)

    if not (result and result.parsed) then
        return nil, "parse_failed"
    end

    local parsed = result.parsed
    result.other = result.other or {}

    local rawMin = parsed.ppm_min_throttle
    if rawMin ~= nil then
        parsed.ppm_min_throttle = normalizePpm(rawMin)
        result.other.ppm_min_throttle_raw = rawMin
    end

    local rawMax = parsed.ppm_max_throttle
    if rawMax ~= nil then
        parsed.ppm_max_throttle = normalizePpm(rawMax)
        result.other.ppm_max_throttle_raw = rawMax
    end

    local rawCenter = parsed.ppm_center_throttle
    if rawCenter ~= nil then
        parsed.ppm_center_throttle = normalizePpm(rawCenter)
        result.other.ppm_center_throttle_raw = rawCenter
    end

    return result
end

local function buildWritePayload(payloadData, mspData, _, state)
    local effectivePayload = payloadData

    if effectivePayload and (
        effectivePayload.ppm_min_throttle ~= nil or
        effectivePayload.ppm_max_throttle ~= nil or
        effectivePayload.ppm_center_throttle ~= nil
    ) then
        local cloned = {}
        for k, v in pairs(effectivePayload) do
            cloned[k] = v
        end

        if cloned.ppm_min_throttle ~= nil then
            cloned.ppm_min_throttle = encodePpm(cloned.ppm_min_throttle)
        end
        if cloned.ppm_max_throttle ~= nil then
            cloned.ppm_max_throttle = encodePpm(cloned.ppm_max_throttle)
        end
        if cloned.ppm_center_throttle ~= nil then
            cloned.ppm_center_throttle = encodePpm(cloned.ppm_center_throttle)
        end

        effectivePayload = cloned
    end

    return core.buildWritePayload(API_NAME, effectivePayload, MSP_API_STRUCTURE_WRITE, state.rebuildOnWrite == true)
end

return factory.create({
    name = API_NAME,
    readCmd = 217,
    writeCmd = 218,
    minBytes = MSP_MIN_BYTES,
    readStructure = MSP_API_STRUCTURE_READ,
    writeStructure = MSP_API_STRUCTURE_WRITE,
    simulatorResponseRead = MSP_API_SIMULATOR_RESPONSE,
    parseRead = parseRead,
    buildWritePayload = buildWritePayload,
    writeUuidFallback = true,
    initialRebuildOnWrite = false,
    resolveReadTimeout = function(state)
        return resolveTimeout(state, false)
    end,
    resolveWriteTimeout = function(state)
        return resolveTimeout(state, true)
    end,
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end,
    exports = {
        mspSignature = MSP_SIGNATURE,
        mspHeaderBytes = MSP_HEADER_BYTES,
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE
    }
})
