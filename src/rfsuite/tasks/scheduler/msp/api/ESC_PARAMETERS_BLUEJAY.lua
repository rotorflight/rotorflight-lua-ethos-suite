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

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_signature",                type = "U8",  apiVersion = {12, 0, 9}, simResponse = {193}},
    {field = "esc_command",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "main_revision",                type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "sub_revision",                 type = "U8",  apiVersion = {12, 0, 9}, simResponse = {22}},
    {field = "layout_revision",              type = "U8",  apiVersion = {12, 0, 9}, simResponse = {209}},
    {field = "reserved_03",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "startup_power_min",            type = "U8",  apiVersion = {12, 0, 9}, simResponse = {51},  min = 1000, max = 1125, step = 5},
    {field = "startup_beep",                 type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "dithering",                    type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0},   tableEthos = startupBeepBoolEthos},
    {field = "startup_power_max",            type = "U8",  apiVersion = {12, 0, 9}, simResponse = {5},   min = 1004, max = 1300, step = 4},
    {field = "reserved_08",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "rpm_power_slope",              type = "U8",  apiVersion = {12, 0, 9}, simResponse = {9}},
    {field = "pwm_frequency",                type = "U8",  apiVersion = {12, 0, 9}, simResponse = {24}},
    {field = "motor_direction",              type = "U8",  apiVersion = {12, 0, 9}, simResponse = {1},   table = motorDirection},
    {field = "reserved_0c",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "mode_raw",                     type = "U16", apiVersion = {12, 0, 9}, simResponse = {85, 170}},
    {field = "reserved_0f",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "braking_strength",             type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}, min = 0, max = 255, step = 1},
    {field = "reserved_11",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "reserved_12",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "reserved_13",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "reserved_14",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "commutation_timing",           type = "U8",  apiVersion = {12, 0, 9}, simResponse = {4},   table = commutationTiming},
    {field = "reserved_16",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "reserved_17",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "reserved_18",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "reserved_19",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "reserved_1a",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "beep_strength",                type = "U8",  apiVersion = {12, 0, 9}, simResponse = {40},  min = 0, max = 255, step = 1},
    {field = "beacon_strength",              type = "U8",  apiVersion = {12, 0, 9}, simResponse = {80},  min = 0, max = 255, step = 1},
    {field = "beacon_delay",                 type = "U8",  apiVersion = {12, 0, 9}, simResponse = {4},   table = beaconDelay},
    {field = "reserved_1e",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "demag_compensation",           type = "U8",  apiVersion = {12, 0, 9}, simResponse = {2},   table = demagCompensation},
    {field = "reserved_20",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "reserved_21",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "reserved_22",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "temperature_protection",       type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0},   table = temperatureProtection},
    {field = "low_rpm_power_protection",     type = "U8",  apiVersion = {12, 0, 9}, simResponse = {1},   tableEthos = startupBeepBoolEthos},
    {field = "reserved_25",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "reserved_26",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "brake_on_stop",                type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0},   tableEthos = startupBeepBoolEthos},
    {field = "led_control",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0},   tableEthos = ledControlEthos},
    {field = "power_rating",                 type = "U8",  apiVersion = {12, 0, 9}, simResponse = {2},   table = powerRating},
    {field = "force_edt_arm",                type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0},   tableEthos = startupBeepBoolEthos},
    {field = "threshold_48to24",             type = "U8",  apiVersion = {12, 0, 9}, simResponse = {170}, min = 0, max = 100, step = 1, unit = "%"},
    {field = "threshold_96to48",             type = "U8",  apiVersion = {12, 0, 9}, simResponse = {85},  min = 0, max = 100, step = 1, unit = "%"},
    {field = "reserved_2d",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_2e",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_2f",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_30",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_31",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_32",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_33",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_34",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_35",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_36",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_37",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_38",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_39",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_3a",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_3b",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_3c",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_3d",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_3e",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_3f",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}}
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)
local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

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
    local result = nil

    core.parseMSPData(API_NAME, buf, MSP_API_STRUCTURE_READ, nil, nil, function(parsed)
        result = parsed
    end)

    if not (result and result.parsed) then
        return nil, "parse_failed"
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
    if layoutRevision == 200 then
        local meta = result.structure
        if meta then
            for _, field in ipairs(meta) do
                if field.field == "rpm_power_slope" then
                    field.tableEthos = rampupStartPowerEthos
                    field.table = nil
                elseif field.field == "startup_beep" then
                    field.tableEthos = startupBeepBoolEthos
                    field.table = nil
                elseif field.field == "braking_strength" then
                    field.tableEthos = nil
                    field.table = nil
                    field.min = 0
                    field.max = 255
                    field.step = 1
                end
            end
        end
    elseif layoutRevision == 202 then
        local meta = result.structure
        if meta then
            for _, field in ipairs(meta) do
                if field.field == "rpm_power_slope" then
                    field.tableEthos = rampupPowerEthos
                    field.table = nil
                elseif field.field == "startup_beep" then
                    field.tableEthos = startupBeepBoolEthos
                    field.table = nil
                elseif field.field == "braking_strength" then
                    field.tableEthos = brakingModeEthos
                    field.table = nil
                    field.min = nil
                    field.max = nil
                    field.step = nil
                end
            end
        end
    else
        local meta = result.structure
        if meta then
            for _, field in ipairs(meta) do
                if field.field == "rpm_power_slope" then
                    field.tableEthos = rampupPowerEthos
                    field.table = nil
                elseif field.field == "startup_beep" then
                    if layoutRevision == 205 then
                        field.tableEthos = startupBeepModeEthos
                    else
                        field.tableEthos = startupBeepBoolEthos
                    end
                    field.table = nil
                elseif field.field == "braking_strength" then
                    field.tableEthos = nil
                    field.table = nil
                    field.min = 0
                    field.max = 255
                    field.step = 1
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
    end

    return result
end

local function buildWritePayload(payloadData, mspData, _, state)
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
