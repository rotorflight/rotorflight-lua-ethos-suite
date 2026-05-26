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

local API_NAME = "ESC_PARAMETERS_BLUEJAY"
local MSP_SIGNATURE = 0xC1
local MSP_HEADER_BYTES = 2

local motorDirection = {"Normal", "Reversed", "Forward/Reverse (3D)", "Forward/Reverse (3D) Rev"}
local commutationTiming = {"0 deg (Low)", "7.5 deg (Medium Low)", "15 deg (Medium)", "22.5 deg (Medium High)", "30 deg (High)"}
local demagCompensation = {"Off", "Low", "High"}
local beaconDelay = {"1 minute", "2 minutes", "5 minutes", "10 minutes", "Infinite"}
local temperatureProtection = {[0] = "Disabled", "80C", "90C", "100C", "110C", "120C", "130C", "140C"}
local powerRating = {"1S", "2S+"}

local rampupStartPowerEthos = {
    [1] = {"0.5% (0.031)", 1},
    [2] = {"5% (0.25)", 7},
    [3] = {"7% (0.38)", 8},
    [4] = {"10% (0.50)", 9},
    [5] = {"15% (0.75)", 10},
    [6] = {"20% (1.00)", 11},
    [7] = {"24% (1.25)", 12},
    [8] = {"29% (1.50)", 13}
}

local rampupPowerEthos = {
    [1] = {"1x (More protection)", 1},
    [2] = {"2x", 2},
    [3] = {"3x", 3},
    [4] = {"4x", 4},
    [5] = {"5x", 5},
    [6] = {"6x", 6},
    [7] = {"7x", 7},
    [8] = {"8x", 8},
    [9] = {"9x", 9},
    [10] = {"10x", 10},
    [11] = {"11x", 11},
    [12] = {"12x", 12},
    [13] = {"13x (Less protection)", 13},
    [14] = {"Off", 0}
}

local startupBeepBoolEthos = {
    [1] = {"Off", 0},
    [2] = {"On", 1}
}

local startupBeepModeEthos = {
    [1] = {"Off", 0},
    [2] = {"Normal", 1},
    [3] = {"Custom", 2}
}

local brakingModeEthos = {
    [1] = {"Off", 0},
    [2] = {"Not during startup", 1},
    [3] = {"On", 2}
}

local pwmFrequencyEthos = {
    [1] = {"24kHz", 24},
    [2] = {"48kHz", 48},
    [3] = {"96kHz", 96}
}

local pwmFrequencyDynamicEthos = {
    [1] = {"24kHz", 24},
    [2] = {"48kHz", 48},
    [3] = {"96kHz", 96},
    [4] = {"Dynamic", 0}
}

local ledControlEthos = {
    [1] = {"Off", 0x00},
    [2] = {"Blue", 0x03},
    [3] = {"Green", 0x0C},
    [4] = {"Red", 0x30},
    [5] = {"Cyan", 0x0F},
    [6] = {"Magenta", 0x33},
    [7] = {"Yellow", 0x3C},
    [8] = {"White", 0x3F}
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos, offset, xvals
local FIELD_SPEC = {
    {"esc_signature", "U8"},
    {"esc_command", "U8"},
    {"main_revision", "U8"},
    {"sub_revision", "U8"},
    {"layout_revision", "U8"},
    {"reserved_03", "U8"},
    {"startup_power_min", "U8", 1000, 1125, nil, nil, nil, nil, 5},
    {"startup_beep", "U8"},
    {"dithering", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, startupBeepBoolEthos},
    {"startup_power_max", "U8", 1004, 1300, nil, nil, nil, nil, 4},
    {"reserved_08", "U8"},
    {"rpm_power_slope", "U8"},
    {"pwm_frequency", "U8"},
    {"motor_direction", "U8", nil, nil, nil, nil, nil, nil, nil, nil, motorDirection},
    {"reserved_0c", "U8"},
    {"mode_raw", "U16"},
    {"reserved_0f", "U8"},
    {"braking_strength", "U8", 0, 255, nil, nil, nil, nil, 1},
    {"reserved_11", "U8"},
    {"reserved_12", "U8"},
    {"reserved_13", "U8"},
    {"reserved_14", "U8"},
    {"commutation_timing", "U8", nil, nil, nil, nil, nil, nil, nil, nil, commutationTiming},
    {"reserved_16", "U8"},
    {"reserved_17", "U8"},
    {"reserved_18", "U8"},
    {"reserved_19", "U8"},
    {"reserved_1a", "U8"},
    {"beep_strength", "U8", 0, 255, nil, nil, nil, nil, 1},
    {"beacon_strength", "U8", 0, 255, nil, nil, nil, nil, 1},
    {"beacon_delay", "U8", nil, nil, nil, nil, nil, nil, nil, nil, beaconDelay},
    {"reserved_1e", "U8"},
    {"demag_compensation", "U8", nil, nil, nil, nil, nil, nil, nil, nil, demagCompensation},
    {"reserved_20", "U8"},
    {"reserved_21", "U8"},
    {"reserved_22", "U8"},
    {"temperature_protection", "U8", nil, nil, nil, nil, nil, nil, nil, nil, temperatureProtection},
    {"low_rpm_power_protection", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, startupBeepBoolEthos},
    {"reserved_25", "U8"},
    {"reserved_26", "U8"},
    {"brake_on_stop", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, startupBeepBoolEthos},
    {"led_control", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, ledControlEthos},
    {"power_rating", "U8", nil, nil, nil, nil, nil, nil, nil, nil, powerRating},
    {"force_edt_arm", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, startupBeepBoolEthos},
    {"threshold_48to24", "U8", 0, 100, nil, "%", nil, nil, 1},
    {"threshold_96to48", "U8", 0, 100, nil, "%", nil, nil, 1},
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
    0,   -- main_revision
    22,  -- sub_revision
    209, -- layout_revision
    255, -- reserved_03
    51,  -- startup_power_min
    0,   -- startup_beep
    0,   -- dithering
    5,   -- startup_power_max
    255, -- reserved_08
    9,   -- rpm_power_slope
    24,  -- pwm_frequency
    1,   -- motor_direction
    255, -- reserved_0c
    85, 170, -- mode_raw
    255, -- reserved_0f
    255, -- braking_strength
    255, -- reserved_11
    255, -- reserved_12
    255, -- reserved_13
    255, -- reserved_14
    4,   -- commutation_timing
    255, -- reserved_16
    255, -- reserved_17
    255, -- reserved_18
    255, -- reserved_19
    255, -- reserved_1a
    40,  -- beep_strength
    80,  -- beacon_strength
    4,   -- beacon_delay
    255, -- reserved_1e
    2,   -- demag_compensation
    255, -- reserved_20
    255, -- reserved_21
    255, -- reserved_22
    0,   -- temperature_protection
    1,   -- low_rpm_power_protection
    255, -- reserved_25
    255, -- reserved_26
    0,   -- brake_on_stop
    0,   -- led_control
    2,   -- power_rating
    0,   -- force_edt_arm
    170, -- threshold_48to24
    85,  -- threshold_96to48
    0,   -- reserved_2d
    0,   -- reserved_2e
    0,   -- reserved_2f
    0,   -- reserved_30
    0,   -- reserved_31
    0,   -- reserved_32
    0,   -- reserved_33
    0,   -- reserved_34
    0,   -- reserved_35
    0,   -- reserved_36
    0,   -- reserved_37
    0,   -- reserved_38
    0,   -- reserved_39
    0,   -- reserved_3a
    0,   -- reserved_3b
    0,   -- reserved_3c
    0,   -- reserved_3d
    0,   -- reserved_3e
    0    -- reserved_3f
})

local function clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

local function round(value)
    return math.floor(value + 0.5)
end

local function normalizeStartupPowerMin(raw)
    if raw == nil then return nil end
    return round((raw * 1000 / 2047) + 1000)
end

local function encodeStartupPowerMin(value)
    if value == nil then return nil end
    return clamp(round(((value - 1000) * 2047) / 1000), 0, 255)
end

local function normalizeStartupPowerMax(raw)
    if raw == nil then return nil end
    return round((raw * 1000 / 250) + 1000)
end

local function encodeStartupPowerMax(value)
    if value == nil then return nil end
    return clamp(round(((value - 1000) * 250) / 1000), 0, 255)
end

local function normalizePwmFrequency(raw)
    if raw == nil then return nil end
    if raw == 192 then return 0 end
    return raw
end

local function encodePwmFrequency(value)
    if value == nil then return nil end
    if value == 0 then return 192 end
    return value
end

local function normalizeThreshold(raw)
    if raw == nil then return nil end
    return clamp(round((raw * 100) / 255), 0, 100)
end

local function encodeThreshold(value)
    if value == nil then return nil end
    return clamp(round((value * 255) / 100), 0, 255)
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

    if parsed.startup_power_min ~= nil then
        result.other.startup_power_min_raw = parsed.startup_power_min
        parsed.startup_power_min = normalizeStartupPowerMin(parsed.startup_power_min)
    end

    if parsed.startup_power_max ~= nil then
        result.other.startup_power_max_raw = parsed.startup_power_max
        parsed.startup_power_max = normalizeStartupPowerMax(parsed.startup_power_max)
    end

    if parsed.pwm_frequency ~= nil then
        result.other.pwm_frequency_raw = parsed.pwm_frequency
        parsed.pwm_frequency = normalizePwmFrequency(parsed.pwm_frequency)
    end

    if parsed.threshold_48to24 ~= nil then
        result.other.threshold_48to24_raw = parsed.threshold_48to24
        parsed.threshold_48to24 = normalizeThreshold(parsed.threshold_48to24)
    end

    if parsed.threshold_96to48 ~= nil then
        result.other.threshold_96to48_raw = parsed.threshold_96to48
        parsed.threshold_96to48 = normalizeThreshold(parsed.threshold_96to48)
    end

    local layoutRevision = parsed.layout_revision or 0
    local meta = result.structure
    if meta then
        for _, field in ipairs(meta) do
            if field.field == "rpm_power_slope" then
                if layoutRevision == 200 then
                    field.tableEthos = rampupStartPowerEthos
                else
                    field.tableEthos = rampupPowerEthos
                end
                field.table = nil
            elseif field.field == "startup_beep" then
                if layoutRevision == 205 then
                    field.tableEthos = startupBeepModeEthos
                else
                    field.tableEthos = startupBeepBoolEthos
                end
                field.table = nil
            elseif field.field == "braking_strength" then
                if layoutRevision == 202 then
                    field.tableEthos = brakingModeEthos
                    field.min = nil
                    field.max = nil
                    field.step = nil
                else
                    field.tableEthos = nil
                    field.min = 0
                    field.max = 255
                    field.step = 1
                end
                field.table = nil
            elseif field.field == "pwm_frequency" then
                if layoutRevision >= 209 then
                    field.tableEthos = pwmFrequencyDynamicEthos
                else
                    field.tableEthos = pwmFrequencyEthos
                end
                field.table = nil
            end
        end
    end

    return result
end

local function buildWritePayload(payloadData, _, _, state)
    local effectivePayload = payloadData

    if effectivePayload and (
        effectivePayload.startup_power_min ~= nil or
        effectivePayload.startup_power_max ~= nil or
        effectivePayload.pwm_frequency ~= nil or
        effectivePayload.threshold_48to24 ~= nil or
        effectivePayload.threshold_96to48 ~= nil
    ) then
        local cloned = {}
        for k, v in pairs(effectivePayload) do
            cloned[k] = v
        end

        if cloned.startup_power_min ~= nil then
            cloned.startup_power_min = encodeStartupPowerMin(cloned.startup_power_min)
        end
        if cloned.startup_power_max ~= nil then
            cloned.startup_power_max = encodeStartupPowerMax(cloned.startup_power_max)
        end
        if cloned.pwm_frequency ~= nil then
            cloned.pwm_frequency = encodePwmFrequency(cloned.pwm_frequency)
        end
        if cloned.threshold_48to24 ~= nil then
            cloned.threshold_48to24 = encodeThreshold(cloned.threshold_48to24)
        end
        if cloned.threshold_96to48 ~= nil then
            cloned.threshold_96to48 = encodeThreshold(cloned.threshold_96to48)
        end
        if cloned.threshold_96to48 ~= nil and cloned.threshold_48to24 ~= nil and cloned.threshold_96to48 > cloned.threshold_48to24 then
            cloned.threshold_96to48 = cloned.threshold_48to24
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
