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

local API_NAME = "ESC_PARAMETERS_AM32"
local MSP_SIGNATURE = 0xC2
local MSP_HEADER_BYTES = 2

local motorDirection = {"Normal", "Reversed"}
local timingAdvance = {"0°", "7.5°", "15°", "22.5°"}
local onOff = {"Off", "On"}
local protocol = {"Auto", "Dshot 300-600", "Servo 1-2ms", "Serial", "BF Safe Arming"}
local brakeOnStop = {"@i18n(app.modules.esc_tools.mfg.am32.tbl_brake_off)@", "@i18n(app.modules.esc_tools.mfg.am32.tbl_brake_brake)@", "@i18n(app.modules.esc_tools.mfg.am32.tbl_brake_active)@"}
local variablePwm = {"@i18n(app.modules.esc_tools.mfg.am32.tbl_pwm_fixed)@", "@i18n(app.modules.esc_tools.mfg.am32.tbl_pwm_variable)@", "@i18n(app.modules.esc_tools.mfg.am32.tbl_pwm_rpm)@"}
local lowVoltageCutoff = {"@i18n(app.modules.esc_tools.mfg.am32.tbl_lvc_off)@", "@i18n(app.modules.esc_tools.mfg.am32.tbl_lvc_cell)@", "@i18n(app.modules.esc_tools.mfg.am32.tbl_lvc_abs)@"}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos, offset, xvals
local FIELD_SPEC = {
    {"esc_signature", "U8"},
    {"esc_command", "U8"},
    {"reserved_0", "U8"},
    {"eeprom_version", "U8"},
    {"reserved_1", "U8"},
    {"version_major", "U8"},
    {"version_minor", "U8"},
    {"max_ramp", "U8"},
    {"minimum_duty_cycle", "U8"},
    {"disable_stick_calibration", "U8"},
    {"absolute_voltage_cutoff", "U8"},
    {"current_p", "U8"},
    {"current_i", "U8"},
    {"current_d", "U8"},
    {"active_brake_power", "U8"},
    {"reserved_eeprom_3_0", "U8"},
    {"reserved_eeprom_3_1", "U8"},
    {"reserved_eeprom_3_2", "U8"},
    {"reserved_eeprom_3_3", "U8"},
    {"motor_direction", "U8", nil, nil, nil, nil, nil, nil, nil, nil, motorDirection, -1},
    {"bidirectional_mode", "U8", nil, nil, nil, nil, nil, nil, nil, nil, onOff, -1},
    {"sinusoidal_startup", "U8", nil, nil, nil, nil, nil, nil, nil, nil, onOff, -1},
    {"complementary_pwm", "U8", nil, nil, nil, nil, nil, nil, nil, nil, onOff, -1},
    {"variable_pwm_frequency", "U8", nil, nil, nil, nil, nil, nil, nil, nil, variablePwm, -1},
    {"stuck_rotor_protection", "U8", nil, nil, nil, nil, nil, nil, nil, nil, onOff, -1},
    {"timing_advance", "U8", nil, nil, nil, nil, nil, nil, nil, nil, timingAdvance, -1},
    {"pwm_frequency", "U8", 8, 144, nil, "kHz", nil, nil, 1},
    {"startup_power", "U8", 50, 150, 100, "%", nil, nil, 1},
    {"motor_kv", "U8", 20, 10220, nil, "KV", nil, nil, 40},
    {"motor_poles", "U8", 2, 36, 14, nil, nil, nil, 1},
    {"brake_on_stop", "U8", nil, nil, nil, nil, nil, nil, nil, nil, brakeOnStop, -1},
    {"stall_protection", "U8", nil, nil, nil, nil, nil, nil, nil, nil, onOff, -1},
    {"beep_volume", "U8", 0, 11, 10, nil, nil, nil, 1},
    {"interval_telemetry", "U8", nil, nil, nil, nil, nil, nil, nil, nil, onOff, -1},
    {"servo_low_threshold", "U8", 750, 1250, nil, "us", nil, nil, 2},
    {"servo_high_threshold", "U8", 1750, 2250, nil, "us", nil, nil, 2},
    {"servo_neutral", "U8", 1374, 1630, nil, "us", nil, nil, 1},
    {"servo_dead_band", "U8", 0, 100, nil, nil, nil, nil, 1},
    {"low_voltage_cutoff", "U8", nil, nil, nil, nil, nil, nil, nil, nil, lowVoltageCutoff, -1},
    {"low_voltage_threshold", "U8", 250, 350, nil, "cV", nil, nil, 1},
    {"rc_car_reversing", "U8", nil, nil, nil, nil, nil, nil, nil, nil, onOff, -1},
    {"use_hall_sensors", "U8", nil, nil, nil, nil, nil, nil, nil, nil, onOff, -1},
    {"sine_mode_range", "U8", 5, 25, nil, nil, nil, nil, 1},
    {"brake_strength", "U8", 0, 10, 0, nil, nil, nil, 1},
    {"running_brake_level", "U8", 0, 10, 0, nil, nil, nil, 1},
    {"temperature_limit", "U8", 70, 141, nil, "C", nil, nil, 1},
    {"current_limit", "U8", 0, 202, nil, nil, nil, nil, 2},
    {"sine_mode_power", "U8", 1, 10, nil, nil, nil, nil, 1},
    {"esc_protocol", "U8", nil, nil, nil, nil, nil, nil, nil, nil, protocol, -1},
    {"auto_advance", "U8", nil, nil, nil, nil, nil, nil, nil, nil, onOff, -1}
}

local READ_STRUCT, MIN_BYTES = core.buildStructure(FIELD_SPEC)
local WRITE_STRUCT = READ_STRUCT

local SIM_RESPONSE = core.simResponse({
    194, -- esc_signature
    64,  -- esc_command
    1,   -- reserved_0
    3,   -- eeprom_version
    1,   -- reserved_1
    2,   -- version_major
    19,  -- version_minor
    50,  -- max_ramp
    1,   -- minimum_duty_cycle
    0,   -- disable_stick_calibration
    10,  -- absolute_voltage_cutoff
    100, -- current_p
    0,   -- current_i
    100, -- current_d
    0,   -- active_brake_power
    255, -- reserved_eeprom_3_0
    255, -- reserved_eeprom_3_1
    255, -- reserved_eeprom_3_2
    255, -- reserved_eeprom_3_3
    0,   -- motor_direction
    0,   -- bidirectional_mode
    0,   -- sinusoidal_startup
    0,   -- complementary_pwm
    0,   -- variable_pwm_frequency
    1,   -- stuck_rotor_protection
    26,  -- timing_advance
    16,  -- pwm_frequency
    50,  -- startup_power
    12,  -- motor_kv
    24,  -- motor_poles
    0,   -- brake_on_stop
    1,   -- stall_protection
    5,   -- beep_volume
    0,   -- interval_telemetry
    128, -- servo_low_threshold
    128, -- servo_high_threshold
    128, -- servo_neutral
    50,  -- servo_dead_band
    0,   -- low_voltage_cutoff
    50,  -- low_voltage_threshold
    0,   -- rc_car_reversing
    0,   -- use_hall_sensors
    10,  -- sine_mode_range
    10,  -- brake_strength
    5,   -- running_brake_level
    145, -- temperature_limit
    102, -- current_limit
    7,   -- sine_mode_power
    1,   -- esc_protocol
    0    -- auto_advance
})

local function clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

local function normalizeTimingAdvance(raw)
    if raw == nil then return nil, "unknown", nil end
    if raw >= 10 and raw <= 42 then
        local norm = clamp(math.floor((raw - 10) / 8 + 0.5), 0, 3)
        return norm, "new", raw
    end
    if raw >= 0 and raw <= 3 then
        return raw, "legacy", raw
    end
    return clamp(math.floor(raw or 0), 0, 3), "unknown", raw
end

local function encodeTimingAdvance(normalized, encoding)
    local n = clamp(math.floor((normalized or 0) + 0.5), 0, 3)
    if encoding == "new" then
        return 10 + (n * 8)
    end
    return n
end

local function normalizeMotorKv(raw)
    if raw == nil then return nil end
    return (raw * 40) + 20
end

local function encodeMotorKv(kv)
    if kv == nil then return nil end
    return clamp(math.floor(((kv - 20) / 40) + 0.5), 0, 255)
end

local function normalizeServoLow(raw)
    if raw == nil then return nil end
    return (raw * 2) + 750
end

local function encodeServoLow(value)
    if value == nil then return nil end
    return clamp(math.floor(((value - 750) / 2) + 0.5), 0, 255)
end

local function normalizeServoHigh(raw)
    if raw == nil then return nil end
    return (raw * 2) + 1750
end

local function encodeServoHigh(value)
    if value == nil then return nil end
    return clamp(math.floor(((value - 1750) / 2) + 0.5), 0, 255)
end

local function normalizeServoNeutral(raw)
    if raw == nil then return nil end
    return raw + 1374
end

local function encodeServoNeutral(value)
    if value == nil then return nil end
    return clamp(math.floor((value - 1374) + 0.5), 0, 255)
end

local function normalizeLowVoltageThreshold(raw)
    if raw == nil then return nil end
    return raw + 250
end

local function encodeLowVoltageThreshold(value)
    if value == nil then return nil end
    return clamp(math.floor((value - 250) + 0.5), 0, 255)
end

local function normalizeCurrentLimit(raw)
    if raw == nil then return nil end
    return raw * 2
end

local function encodeCurrentLimit(value)
    if value == nil then return nil end
    return clamp(math.floor((value / 2) + 0.5), 0, 255)
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
    local norm, encoding, raw = normalizeTimingAdvance(parsed.timing_advance)
    parsed.timing_advance = norm

    result.other = result.other or {}
    result.other.timing_advance_encoding = encoding
    result.other.timing_advance_raw = raw

    if encoding == "unknown" and raw ~= nil and rfsuite.utils and rfsuite.utils.log then
        rfsuite.utils.log("AM32 timing_advance raw value out of range: " .. tostring(raw), "info")
    end

    local rawKv = parsed.motor_kv
    if rawKv ~= nil then
        parsed.motor_kv = normalizeMotorKv(rawKv)
        result.other.motor_kv_raw = rawKv
    end

    local rawServoLow = parsed.servo_low_threshold
    if rawServoLow ~= nil then
        parsed.servo_low_threshold = normalizeServoLow(rawServoLow)
        result.other.servo_low_threshold_raw = rawServoLow
    end

    local rawServoHigh = parsed.servo_high_threshold
    if rawServoHigh ~= nil then
        parsed.servo_high_threshold = normalizeServoHigh(rawServoHigh)
        result.other.servo_high_threshold_raw = rawServoHigh
    end

    local rawServoNeutral = parsed.servo_neutral
    if rawServoNeutral ~= nil then
        parsed.servo_neutral = normalizeServoNeutral(rawServoNeutral)
        result.other.servo_neutral_raw = rawServoNeutral
    end

    local rawLowVoltage = parsed.low_voltage_threshold
    if rawLowVoltage ~= nil then
        parsed.low_voltage_threshold = normalizeLowVoltageThreshold(rawLowVoltage)
        result.other.low_voltage_threshold_raw = rawLowVoltage
    end

    local rawCurrentLimit = parsed.current_limit
    if rawCurrentLimit ~= nil then
        parsed.current_limit = normalizeCurrentLimit(rawCurrentLimit)
        result.other.current_limit_raw = rawCurrentLimit
    end

    return result
end

local function buildWritePayload(payloadData, mspData, _, state)
    local effectivePayload = payloadData
    local encoding = mspData and mspData.other and mspData.other.timing_advance_encoding or "legacy"

    if effectivePayload and (
        effectivePayload.timing_advance ~= nil or
        effectivePayload.motor_kv ~= nil or
        effectivePayload.servo_low_threshold ~= nil or
        effectivePayload.servo_high_threshold ~= nil or
        effectivePayload.servo_neutral ~= nil or
        effectivePayload.low_voltage_threshold ~= nil or
        effectivePayload.current_limit ~= nil
    ) then
        local cloned = {}
        for k, v in pairs(effectivePayload) do
            cloned[k] = v
        end

        if cloned.timing_advance ~= nil then
            cloned.timing_advance = encodeTimingAdvance(cloned.timing_advance, encoding)
        end
        if cloned.motor_kv ~= nil then
            cloned.motor_kv = encodeMotorKv(cloned.motor_kv)
        end
        if cloned.servo_low_threshold ~= nil then
            cloned.servo_low_threshold = encodeServoLow(cloned.servo_low_threshold)
        end
        if cloned.servo_high_threshold ~= nil then
            cloned.servo_high_threshold = encodeServoHigh(cloned.servo_high_threshold)
        end
        if cloned.servo_neutral ~= nil then
            cloned.servo_neutral = encodeServoNeutral(cloned.servo_neutral)
        end
        if cloned.low_voltage_threshold ~= nil then
            cloned.low_voltage_threshold = encodeLowVoltageThreshold(cloned.low_voltage_threshold)
        end
        if cloned.current_limit ~= nil then
            cloned.current_limit = encodeCurrentLimit(cloned.current_limit)
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
    readCompleteOnErrorReplyAttempt = 2,
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
