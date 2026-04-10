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

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos, offset, xvals
local FIELD_SPEC = {
    {"esc_signature", "U8"},
    {"esc_command", "U8"},
    {"main_revision", "U8"},
    {"sub_revision", "U8"},
    {"layout_revision", "U8"},
    {"p_gain", "U8"},
    {"i_gain", "U8"},
    {"governor_mode", "U8"},
    {"low_voltage_limit", "U8"},
    {"motor_gain", "U8"},
    {"motor_idle", "U8"},
    {"startup_power", "U8", nil, nil, nil, nil, nil, nil, nil, nil, startupPower},
    {"pwm_frequency", "U8"},
    {"motor_direction", "U8", nil, nil, nil, nil, nil, nil, nil, nil, motorDirection},
    {"input_pwm_polarity", "U8"},
    {"mode_raw", "U16"},
    {"programming_by_tx", "U8", nil, nil, nil, nil, nil, nil, nil, nil, onOff},
    {"rearm_at_start", "U8"},
    {"governor_setup_target", "U8"},
    {"startup_rpm", "U8"},
    {"startup_acceleration", "U8"},
    {"volt_comp", "U8"},
    {"commutation_timing", "U8", nil, nil, nil, nil, nil, nil, nil, nil, commutationTiming},
    {"damping_force", "U8"},
    {"governor_range", "U8"},
    {"startup_method", "U8"},
    {"ppm_min_throttle", "U8", 1000, 1500, nil, nil, nil, nil, 4},
    {"ppm_max_throttle", "U8", 1504, 2020, nil, nil, nil, nil, 4},
    {"beep_strength", "U8", 1, 255, nil, nil, nil, nil, 1},
    {"beacon_strength", "U8", 1, 255, nil, nil, nil, nil, 1},
    {"beacon_delay", "U8", nil, nil, nil, nil, nil, nil, nil, nil, beaconDelay},
    {"throttle_rate", "U8"},
    {"demag_compensation", "U8", nil, nil, nil, nil, nil, nil, nil, nil, demagCompensation},
    {"bec_voltage", "U8"},
    {"ppm_center_throttle", "U8", 1000, 2020, nil, nil, nil, nil, 4},
    {"spoolup_time", "U8"},
    {"temperature_protection", "U8", nil, nil, nil, nil, nil, nil, nil, nil, temperatureProtection},
    {"low_rpm_power_protection", "U8", nil, nil, nil, nil, nil, nil, nil, nil, onOff},
    {"pwm_input", "U8"},
    {"pwm_dither", "U8"},
    {"brake_on_stop", "U8", nil, nil, nil, nil, nil, nil, nil, nil, onOff, -1},
    {"led_control", "U8"},
    {"reserved_29", "U8"},
    {"reserved_2a", "U8"},
    {"reserved_2b", "U8"},
    {"reserved_2c", "U8"},
    {"reserved_2d", "U8"},
    {"reserved_2e", "U8"},
    {"reserved_2f", "U8"},
    {"reserved_30", "U8"},
    {"reserved_31", "U8"},
    {"reserved_32", "U8"},
    {"reserved_33", "U8"},
    {"reserved_34", "U8"},
    {"reserved_35", "U8"},
    {"reserved_36", "U8"},
    {"reserved_37", "U8"},
    {"reserved_38", "U8"},
    {"reserved_39", "U8"},
    {"reserved_3a", "U8"},
    {"reserved_3b", "U8"},
    {"reserved_3c", "U8"},
    {"reserved_3d", "U8"},
    {"reserved_3e", "U8"},
    {"reserved_3f", "U8"}
}

local READ_STRUCT, MIN_BYTES = core.buildStructure(FIELD_SPEC)
local WRITE_STRUCT = READ_STRUCT

local SIM_RESPONSE = core.simResponse({
    193, -- esc_signature
    0,   -- esc_command
    16,  -- main_revision
    7,   -- sub_revision
    33,  -- layout_revision
    255, -- p_gain
    255, -- i_gain
    255, -- governor_mode
    255, -- low_voltage_limit
    255, -- motor_gain
    255, -- motor_idle
    9,   -- startup_power
    255, -- pwm_frequency
    1,   -- motor_direction
    255, -- input_pwm_polarity
    85, 170, -- mode_raw
    1,   -- programming_by_tx
    255, -- rearm_at_start
    255, -- governor_setup_target
    255, -- startup_rpm
    255, -- startup_acceleration
    255, -- volt_comp
    3,   -- commutation_timing
    255, -- damping_force
    255, -- governor_range
    255, -- startup_method
    37,  -- ppm_min_throttle
    208, -- ppm_max_throttle
    40,  -- beep_strength
    80,  -- beacon_strength
    4,   -- beacon_delay
    255, -- throttle_rate
    2,   -- demag_compensation
    255, -- bec_voltage
    122, -- ppm_center_throttle
    255, -- spoolup_time
    7,   -- temperature_protection
    1,   -- low_rpm_power_protection
    255, -- pwm_input
    255, -- pwm_dither
    0,   -- brake_on_stop
    0,   -- led_control
    255, -- reserved_29
    255, -- reserved_2a
    255, -- reserved_2b
    255, -- reserved_2c
    255, -- reserved_2d
    255, -- reserved_2e
    255, -- reserved_2f
    255, -- reserved_30
    255, -- reserved_31
    255, -- reserved_32
    255, -- reserved_33
    255, -- reserved_34
    255, -- reserved_35
    255, -- reserved_36
    255, -- reserved_37
    255, -- reserved_38
    255, -- reserved_39
    255, -- reserved_3a
    255, -- reserved_3b
    255, -- reserved_3c
    255, -- reserved_3d
    255, -- reserved_3e
    255  -- reserved_3f
})

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
    local result, err = core.parseStructure(API_NAME, buf, READ_STRUCT)
    if not result then
        return nil, err
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

local function buildWritePayload(payloadData, _, _, state)
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

    return core.buildPayload(API_NAME, effectivePayload, WRITE_STRUCT, state.rebuildOnWrite == true)
end

return core.createConfigAPI({
    name = API_NAME,
    minApiVersion = {12, 0, 9},
    readCmd = 217,
    writeCmd = 218,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    parseRead = parseRead,
    buildWritePayload = buildWritePayload,
    writeUuidFallback = true,
    initialRebuildOnWrite = false,
    readRetryOnErrorReply = true,
    readRetryBackoff = 0.35,
    resolveReadTimeout = function(state)
        return resolveTimeout(state, false)
    end,
    resolveWriteTimeout = function(state)
        return resolveTimeout(state, true)
    end,
    exports = {
        mspSignature = MSP_SIGNATURE,
        mspHeaderBytes = MSP_HEADER_BYTES,
        simulatorResponse = SIM_RESPONSE
    }
})
