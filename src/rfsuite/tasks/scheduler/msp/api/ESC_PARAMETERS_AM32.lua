--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "ESC_PARAMETERS_AM32"
local MSP_API_CMD_READ = 217
local MSP_API_CMD_WRITE = 218
local MSP_REBUILD_ON_WRITE = false
local MSP_SIGNATURE = 0xC2 
local MSP_HEADER_BYTES = 2

-- tables used in structure below
local motorDirection = {"Normal", "Reversed"}
local timingAdvance = {"0°", "7.5°", "15°", "22.5°"}
local onOff = {"Off", "On"}
local protocol = {"Auto", "Dshot 300-600", "Servo 1-2ms", "Serial", "BF Safe Arming"}
local brakeOnStop = {"@i18n(app.modules.esc_tools.mfg.am32.tbl_brake_off)@", "@i18n(app.modules.esc_tools.mfg.am32.tbl_brake_brake)@", "@i18n(app.modules.esc_tools.mfg.am32.tbl_brake_active)@"}
local variablePwm = {"@i18n(app.modules.esc_tools.mfg.am32.tbl_pwm_fixed)@", "@i18n(app.modules.esc_tools.mfg.am32.tbl_pwm_variable)@", "@i18n(app.modules.esc_tools.mfg.am32.tbl_pwm_rpm)@"}
local lowVoltageCutoff = {"@i18n(app.modules.esc_tools.mfg.am32.tbl_lvc_off)@", "@i18n(app.modules.esc_tools.mfg.am32.tbl_lvc_cell)@", "@i18n(app.modules.esc_tools.mfg.am32.tbl_lvc_abs)@"}

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_signature",             type = "U8",  apiVersion = {12, 0, 9}, simResponse = {194}},
    {field = "esc_command",               type = "U8",  apiVersion = {12, 0, 9}, simResponse = {64}},
    {field = "reserved_0",                type = "U8",  apiVersion = {12, 0, 9}, simResponse = {1}},
    {field = "eeprom_version",            type = "U8",  apiVersion = {12, 0, 9}, simResponse = {3}},
    {field = "reserved_1",                type = "U8",  apiVersion = {12, 0, 9}, simResponse = {1}},
    {field = "version_major",             type = "U8",  apiVersion = {12, 0, 9}, simResponse = {2}},
    {field = "version_minor",             type = "U8",  apiVersion = {12, 0, 9}, simResponse = {19}},
    {field = "max_ramp",                  type = "U8",  apiVersion = {12, 0, 9}, simResponse = {50}},
    {field = "minimum_duty_cycle",        type = "U8",  apiVersion = {12, 0, 9}, simResponse = {1}},
    {field = "disable_stick_calibration", type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "absolute_voltage_cutoff",   type = "U8",  apiVersion = {12, 0, 9}, simResponse = {10}},
    {field = "current_p",                 type = "U8",  apiVersion = {12, 0, 9}, simResponse = {100}},
    {field = "current_i",                 type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "current_d",                 type = "U8",  apiVersion = {12, 0, 9}, simResponse = {100}},
    {field = "active_brake_power",        type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "reserved_eeprom_3_0",       type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "reserved_eeprom_3_1",       type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "reserved_eeprom_3_2",       type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "reserved_eeprom_3_3",       type = "U8",  apiVersion = {12, 0, 9}, simResponse = {255}},
    {field = "motor_direction",           type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}, tableIdxInc = -1, table = motorDirection},
    {field = "bidirectional_mode",        type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}, tableIdxInc = -1, table = onOff},
    {field = "sinusoidal_startup",        type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}, tableIdxInc = -1, table = onOff},
    {field = "complementary_pwm",         type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}, tableIdxInc = -1, table = onOff},
    {field = "variable_pwm_frequency",    type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}, tableIdxInc = -1, table = variablePwm},
    {field = "stuck_rotor_protection",    type = "U8",  apiVersion = {12, 0, 9}, simResponse = {1}, tableIdxInc = -1, table = onOff},
    {field = "timing_advance",            type = "U8",  apiVersion = {12, 0, 9}, simResponse = {26}, tableIdxInc = -1, table = timingAdvance}, -- *7.5
    {field = "pwm_frequency",             type = "U8",  apiVersion = {12, 0, 9}, unit = "kHz", simResponse = {16}, min = 8, max = 144, step = 1},
    {field = "startup_power",             type = "U8",  apiVersion = {12, 0, 9}, unit = "%", simResponse = {50}, default = 100, min = 50, max = 150, step = 1},
    {field = "motor_kv",                  type = "U8",  apiVersion = {12, 0, 9}, unit = "KV", simResponse = {12}, min = 20, max = 10220, step = 40}, -- stored as byte; decode as (byte*40)+20
    {field = "motor_poles",               type = "U8",  apiVersion = {12, 0, 9}, simResponse = {24}, default = 14, min = 2, max = 36, step = 1},
    {field = "brake_on_stop",             type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}, tableIdxInc = -1, table = brakeOnStop},
    {field = "stall_protection",          type = "U8",  apiVersion = {12, 0, 9}, simResponse = {1}, tableIdxInc = -1, table = onOff},
    {field = "beep_volume",               type = "U8",  apiVersion = {12, 0, 9}, simResponse = {5}, default = 10, min = 0, max = 11, step = 1},
    {field = "interval_telemetry",        type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}, tableIdxInc = -1, table = onOff},
    {field = "servo_low_threshold",       type = "U8",  apiVersion = {12, 0, 9}, unit = "us", simResponse = {128}, min = 750, max = 1250, step = 2},
    {field = "servo_high_threshold",      type = "U8",  apiVersion = {12, 0, 9}, unit = "us", simResponse = {128}, min = 1750, max = 2250, step = 2},
    {field = "servo_neutral",             type = "U8",  apiVersion = {12, 0, 9}, unit = "us", simResponse = {128}, min = 1374, max = 1630, step = 1},
    {field = "servo_dead_band",           type = "U8",  apiVersion = {12, 0, 9}, simResponse = {50}, min = 0, max = 100, step = 1},
    {field = "low_voltage_cutoff",        type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}, tableIdxInc = -1, table = lowVoltageCutoff},
    {field = "low_voltage_threshold",     type = "U8",  apiVersion = {12, 0, 9}, unit = "cV", simResponse = {50}, min = 250, max = 350, step = 1},
    {field = "rc_car_reversing",          type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}, tableIdxInc = -1, table = onOff},
    {field = "use_hall_sensors",          type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}, tableIdxInc = -1, table = onOff},
    {field = "sine_mode_range",           type = "U8",  apiVersion = {12, 0, 9}, simResponse = {10}, min = 5, max = 25, step = 1},
    {field = "brake_strength",            type = "U8",  apiVersion = {12, 0, 9}, simResponse = {10}, default = 0, min = 0, max = 10, step = 1},
    {field = "running_brake_level",       type = "U8",  apiVersion = {12, 0, 9}, simResponse = {5}, default = 0, min = 0, max = 10, step = 1},
    {field = "temperature_limit",         type = "U8",  apiVersion = {12, 0, 9}, unit = "C", simResponse = {145}, min = 70, max = 141, step = 1},
    {field = "current_limit",             type = "U8",  apiVersion = {12, 0, 9}, simResponse = {102}, min = 0, max = 202, step = 2},
    {field = "sine_mode_power",           type = "U8",  apiVersion = {12, 0, 9}, simResponse = {7}, min = 1, max = 10, step = 1},
    {field = "esc_protocol",              type = "U8",  apiVersion = {12, 0, 9}, simResponse = {1}, tableIdxInc = -1, table = protocol},
    {field = "auto_advance",              type = "U8",  apiVersion = {12, 0, 9}, simResponse = {0}, tableIdxInc = -1, table = onOff}
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

local function processedData() rfsuite.utils.log("Processed data", "debug") end

local mspData = nil
local mspWriteComplete = false
local payloadData = {}
local defaultData = {}
local math_floor = math.floor
local log = rfsuite.utils.log

local handlers = core.createHandlers()

local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

local lastWriteUUID = nil

local writeDoneRegistry = setmetatable({}, {__mode = "kv"})

local function clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

local function normalizeTimingAdvance(raw)
    if raw == nil then return nil, "unknown", nil end
    if raw >= 10 and raw <= 42 then
        local norm = clamp(math_floor((raw - 10) / 8 + 0.5), 0, 3)
        return norm, "new", raw
    end
    if raw >= 0 and raw <= 3 then
        return raw, "legacy", raw
    end
    return clamp(math_floor(raw or 0), 0, 3), "unknown", raw
end

local function encodeTimingAdvance(normalized, encoding)
    local n = clamp(math_floor((normalized or 0) + 0.5), 0, 3)
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
    return clamp(math_floor(((kv - 20) / 40) + 0.5), 0, 255)
end

local function normalizeServoLow(raw)
    if raw == nil then return nil end
    return (raw * 2) + 750
end

local function encodeServoLow(value)
    if value == nil then return nil end
    return clamp(math_floor(((value - 750) / 2) + 0.5), 0, 255)
end

local function normalizeServoHigh(raw)
    if raw == nil then return nil end
    return (raw * 2) + 1750
end

local function encodeServoHigh(value)
    if value == nil then return nil end
    return clamp(math_floor(((value - 1750) / 2) + 0.5), 0, 255)
end

local function normalizeServoNeutral(raw)
    if raw == nil then return nil end
    return raw + 1374
end

local function encodeServoNeutral(value)
    if value == nil then return nil end
    return clamp(math_floor((value - 1374) + 0.5), 0, 255)
end

local function normalizeLowVoltageThreshold(raw)
    if raw == nil then return nil end
    return raw + 250
end

local function encodeLowVoltageThreshold(value)
    if value == nil then return nil end
    return clamp(math_floor((value - 250) + 0.5), 0, 255)
end

local function normalizeCurrentLimit(raw)
    if raw == nil then return nil end
    return raw * 2
end

local function encodeCurrentLimit(value)
    if value == nil then return nil end
    return clamp(math_floor((value / 2) + 0.5), 0, 255)
end

local function resolveTimeout(isWrite)
    if MSP_API_MSG_TIMEOUT ~= nil then return MSP_API_MSG_TIMEOUT end
    local protocol = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.protocol
    if not protocol then return nil end
    if isWrite then return protocol.saveTimeout end
    return protocol.pageReqTimeout
end

local function processReplyStaticRead(self, buf)
    core.parseMSPData(API_NAME, buf, self.structure, nil, nil, function(result)
        mspData = result
        if mspData and mspData.parsed then
            local norm, encoding, raw = normalizeTimingAdvance(mspData.parsed.timing_advance)
            mspData.parsed.timing_advance = norm
            mspData.other = mspData.other or {}
            mspData.other.timing_advance_encoding = encoding
            mspData.other.timing_advance_raw = raw
            if encoding == "unknown" and raw ~= nil then
                log("AM32 timing_advance raw value out of range: " .. tostring(raw), "info")
            end
            local rawKv = mspData.parsed.motor_kv
            if rawKv ~= nil then
                mspData.parsed.motor_kv = normalizeMotorKv(rawKv)
                mspData.other.motor_kv_raw = rawKv
            end
            local rawServoLow = mspData.parsed.servo_low_threshold
            if rawServoLow ~= nil then
                mspData.parsed.servo_low_threshold = normalizeServoLow(rawServoLow)
                mspData.other.servo_low_threshold_raw = rawServoLow
            end
            local rawServoHigh = mspData.parsed.servo_high_threshold
            if rawServoHigh ~= nil then
                mspData.parsed.servo_high_threshold = normalizeServoHigh(rawServoHigh)
                mspData.other.servo_high_threshold_raw = rawServoHigh
            end
            local rawServoNeutral = mspData.parsed.servo_neutral
            if rawServoNeutral ~= nil then
                mspData.parsed.servo_neutral = normalizeServoNeutral(rawServoNeutral)
                mspData.other.servo_neutral_raw = rawServoNeutral
            end
            local rawLowVoltage = mspData.parsed.low_voltage_threshold
            if rawLowVoltage ~= nil then
                mspData.parsed.low_voltage_threshold = normalizeLowVoltageThreshold(rawLowVoltage)
                mspData.other.low_voltage_threshold_raw = rawLowVoltage
            end
            local rawCurrentLimit = mspData.parsed.current_limit
            if rawCurrentLimit ~= nil then
                mspData.parsed.current_limit = normalizeCurrentLimit(rawCurrentLimit)
                mspData.other.current_limit_raw = rawCurrentLimit
            end
        end
        if #buf >= (self.minBytes or 0) then
            local getComplete = self.getCompleteHandler
            if getComplete then
                local complete = getComplete()
                if complete then complete(self, buf) end
            end
        end
    end)
end

local function processReplyStaticWrite(self, buf)
    mspWriteComplete = true

    if self.uuid then writeDoneRegistry[self.uuid] = true end

    local getComplete = self.getCompleteHandler
    if getComplete then
        local complete = getComplete()
        if complete then complete(self, buf) end
    end
end

local function errorHandlerStatic(self, buf)
    local getError = self.getErrorHandler
    if getError then
        local err = getError()
        if err then err(self, buf) end
    end
end

local function read()
    if MSP_API_CMD_READ == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_READ", "debug")
        return
    end

    local message = {command = MSP_API_CMD_READ, apiname=API_NAME, structure = MSP_API_STRUCTURE_READ, minBytes = MSP_MIN_BYTES, processReply = processReplyStaticRead, errorHandler = errorHandlerStatic, simulatorResponse = MSP_API_SIMULATOR_RESPONSE, uuid = MSP_API_UUID, timeout = resolveTimeout(false), getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler, mspData = nil}
    return rfsuite.tasks.msp.mspQueue:add(message)
end

local function write(suppliedPayload)
    if MSP_API_CMD_WRITE == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_WRITE", "debug")
        return
    end

    local effectivePayload = payloadData
    if suppliedPayload == nil then
        local encoding = mspData and mspData.other and mspData.other.timing_advance_encoding or "legacy"
        if effectivePayload and (effectivePayload.timing_advance ~= nil or effectivePayload.motor_kv ~= nil or effectivePayload.servo_low_threshold ~= nil or effectivePayload.servo_high_threshold ~= nil or effectivePayload.servo_neutral ~= nil or effectivePayload.low_voltage_threshold ~= nil or effectivePayload.current_limit ~= nil) then
            local cloned = {}
            for k, v in pairs(effectivePayload) do cloned[k] = v end
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
    else
        effectivePayload = suppliedPayload
    end

    local payload = suppliedPayload or core.buildWritePayload(API_NAME, effectivePayload, MSP_API_STRUCTURE_WRITE, MSP_REBUILD_ON_WRITE)

    local uuid = MSP_API_UUID or rfsuite.utils and rfsuite.utils.uuid and rfsuite.utils.uuid() or tostring(os.clock())
    lastWriteUUID = uuid

    local message = {command = MSP_API_CMD_WRITE, apiname = API_NAME, payload = payload, processReply = processReplyStaticWrite, errorHandler = errorHandlerStatic, simulatorResponse = {}, uuid = uuid, timeout = resolveTimeout(true), getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler}

    return rfsuite.tasks.msp.mspQueue:add(message)
end

local function readValue(fieldName)
    if mspData and mspData['parsed'][fieldName] ~= nil then return mspData['parsed'][fieldName] end
    return nil
end

local function setValue(fieldName, value) payloadData[fieldName] = value end

local function readComplete() return mspData ~= nil and #mspData['buffer'] >= MSP_MIN_BYTES end

local function writeComplete() return mspWriteComplete end

local function resetWriteStatus() mspWriteComplete = false end

local function data() return mspData end

local function setUUID(uuid) MSP_API_UUID = uuid end

local function setTimeout(timeout) MSP_API_MSG_TIMEOUT = timeout end

local function setRebuildOnWrite(rebuild) MSP_REBUILD_ON_WRITE = rebuild end

return {read = read, write = write, setRebuildOnWrite = setRebuildOnWrite, readComplete = readComplete, writeComplete = writeComplete, readValue = readValue, setValue = setValue, resetWriteStatus = resetWriteStatus, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data, setUUID = setUUID, setTimeout = setTimeout, mspSignature = MSP_SIGNATURE, mspHeaderBytes = MSP_HEADER_BYTES, simulatorResponse = MSP_API_SIMULATOR_RESPONSE}
