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
local motorDirection = {"normal", "reversed"}
local timingAdvance = {"0°", "7.5°", "15°", "22.5°"}
local onOff = {"off", "on"}
local protocol = {"Auto", "Dshot 300-600", "Servo 1-2ms", "Serial", "BF Safe Arming"}


-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    -- MSP header
    {field = "esc_signature",             type = "U8",  apiVersion = {12, 0, 7}, simResponse = {194}},
    {field = "esc_command",               type = "U8",  apiVersion = {12, 0, 7}, simResponse = {0}},

    -- EEPROM bytes 0..47 (AM32 EEPROM layout)
    {field = "reserved_0",                type = "U8",  apiVersion = {12, 0, 7}},
    {field = "eeprom_version",            type = "U8",  apiVersion = {12, 0, 7}, simResponse = {3}},
    {field = "reserved_1",                type = "U8",  apiVersion = {12, 0, 7}},
    {field = "fw_major",                  type = "U8",  apiVersion = {12, 0, 7}, simResponse = {2}},
    {field = "fw_minor",                  type = "U8",  apiVersion = {12, 0, 7}, simResponse = {17}},
    {field = "max_ramp",                  type = "U8",  apiVersion = {12, 0, 7}},
    {field = "minimum_duty_cycle",        type = "U8",  apiVersion = {12, 0, 7}},
    {field = "disable_stick_calibration", type = "U8",  apiVersion = {12, 0, 7}},
    {field = "absolute_voltage_cutoff",   type = "U8",  apiVersion = {12, 0, 7}},
    {field = "current_P",                 type = "U8",  apiVersion = {12, 0, 7}},
    {field = "current_I",                 type = "U8",  apiVersion = {12, 0, 7}},
    {field = "current_D",                 type = "U8",  apiVersion = {12, 0, 7}},
    {field = "active_brake_power",        type = "U8",  apiVersion = {12, 0, 7}},
    {field = "reserved_eeprom_3_0",       type = "U8",  apiVersion = {12, 0, 7}},
    {field = "reserved_eeprom_3_1",       type = "U8",  apiVersion = {12, 0, 7}},
    {field = "reserved_eeprom_3_2",       type = "U8",  apiVersion = {12, 0, 7}},
    {field = "reserved_eeprom_3_3",       type = "U8",  apiVersion = {12, 0, 7}},
    {field = "motor_direction",           type = "U8",  apiVersion = {12, 0, 7}, tableIdxInc = -1, table = motorDirection},
    {field = "bidirectional_mode",        type = "U8",  apiVersion = {12, 0, 7}, tableIdxInc = -1, table = onOff},
    {field = "sinusoidal_startup",        type = "U8",  apiVersion = {12, 0, 7}, tableIdxInc = -1, table = onOff},
    {field = "complementary_pwm",         type = "U8",  apiVersion = {12, 0, 7}, tableIdxInc = -1, table = onOff},
    {field = "variable_pwm_frequency",    type = "U8",  apiVersion = {12, 0, 7}, tableIdxInc = -1, table = onOff},
    {field = "stuck_rotor_protection",    type = "U8",  apiVersion = {12, 0, 7}, tableIdxInc = -1, table = onOff},
    {field = "timing_advance",            type = "U8",  apiVersion = {12, 0, 7}, tableIdxInc = -1, table = timingAdvance},
    {field = "pwm_frequency",             type = "U8",  apiVersion = {12, 0, 7}, tableIdxInc = -1, table = onOff},
    {field = "startup_power",             type = "U8",  apiVersion = {12, 0, 7}, default = 100, min = 50, max = 150},
    {field = "motor_kv",                  type = "U8",  apiVersion = {12, 0, 7}, min = 20, max = 10220, step = 40}, -- stored as byte; decode as (byte*40)+20
    {field = "motor_poles",               type = "U8",  apiVersion = {12, 0, 7}, default = 14, min = 2, max = 36},
    {field = "brake_on_stop",             type = "U8",  apiVersion = {12, 0, 7}, tableIdxInc = -1, table = onOff},
    {field = "stall_protection",          type = "U8",  apiVersion = {12, 0, 7}, tableIdxInc = -1, table = onOff},
    {field = "beep_volume",               type = "U8",  apiVersion = {12, 0, 7}, default = 10, min = 0, max = 11},
    {field = "interval_telemetry",        type = "U8",  apiVersion = {12, 0, 7}, tableIdxInc = -1, table = onOff},
    {field = "servo_low_threshold",       type = "U8",  apiVersion = {12, 0, 7}},
    {field = "servo_high_threshold",      type = "U8",  apiVersion = {12, 0, 7}},
    {field = "servo_neutral",             type = "U8",  apiVersion = {12, 0, 7}},
    {field = "servo_dead_band",           type = "U8",  apiVersion = {12, 0, 7}},
    {field = "low_voltage_cutoff",        type = "U8",  apiVersion = {12, 0, 7}},
    {field = "low_voltage_threshold",     type = "U8",  apiVersion = {12, 0, 7}},
    {field = "rc_car_reversing",          type = "U8",  apiVersion = {12, 0, 7}},
    {field = "use_hall_sensors",          type = "U8",  apiVersion = {12, 0, 7}},
    {field = "sine_mode_range",           type = "U8",  apiVersion = {12, 0, 7}},
    {field = "brake_strength",            type = "U8",  apiVersion = {12, 0, 7}, default = 0, min = 0, max = 10},
    {field = "running_brake_level",       type = "U8",  apiVersion = {12, 0, 7}, default = 0, min = 0, max = 10},
    {field = "temperature_limit",         type = "U8",  apiVersion = {12, 0, 7}},
    {field = "current_limit",             type = "U8",  apiVersion = {12, 0, 7}},
    {field = "sine_mode_power",           type = "U8",  apiVersion = {12, 0, 7}},
    {field = "esc_protocol",              type = "U8",  apiVersion = {12, 0, 7}, tableIdxInc = -1, table = protocol},
    {field = "auto_advance",              type = "U8",  apiVersion = {12, 0, 7}, tableIdxInc = -1, table = onOff}
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)
MSP_API_SIMULATOR_RESPONSE = {194, 64, 1, 3, 1, 2, 19, 200, 2, 0, 10, 100, 0, 100, 5, 255, 255, 255, 255, 0, 0, 0, 1, 2, 0, 24, 24, 100, 52, 12, 0, 0, 5, 0, 128, 128, 128, 50, 0, 50, 0, 0, 5, 10, 10, 145, 102, 6, 1, 0}
local MSP_PARSER_OPTIONS = {chunked = true, fieldsPerTick = 4}

local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

local function processedData() rfsuite.utils.log("Processed data", "debug") end

local mspData = nil
local mspWriteComplete = false
local payloadData = {}
local defaultData = {}

local handlers = core.createHandlers()

local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

local lastWriteUUID = nil

local writeDoneRegistry = setmetatable({}, {__mode = "kv"})

local function normalizeTimingAdvance(parsed)
    if not parsed or parsed.timing_advance == nil then return end

    local raw = tonumber(parsed.timing_advance) or 0
    parsed.timing_advance_raw = raw

    if raw >= 10 then
        if raw < 10 then raw = 10 end
        if raw > 42 then raw = 42 end
        parsed.timing_advance_is_new = true
        parsed.timing_advance = raw
        return
    end

    parsed.timing_advance_is_new = false
    if raw < 0 then raw = 0 end
    if raw > 3 then raw = 3 end

    parsed.timing_advance = raw
end

local function normalizeMotorKv(parsed)
    if not parsed or parsed.motor_kv == nil then return end
    local raw = tonumber(parsed.motor_kv) or 0
    parsed.motor_kv = (raw * 40) + 20
end

local function normalizeAutoPWMSwitch(parsed)
    if not parsed or parsed.pwm_frequency == nil then return end
    local raw = tonumber(parsed.pwm_frequency) or 0
    parsed.pwm_frequency_raw = raw
    parsed.pwm_frequency = (raw == 2) and 1 or 0
end

local function normalizeVariablePWMSwitch(parsed)
    if not parsed or parsed.variable_pwm_frequency == nil then return end
    local raw = tonumber(parsed.variable_pwm_frequency) or 0
    parsed.variable_pwm_frequency_raw = raw
    parsed.variable_pwm_frequency = (raw == 1) and 1 or 0
end

local function encodeMotorKv(value)
    local kv = tonumber(value) or 0
    kv = math.floor(kv + 0.5)
    local raw = math.floor((kv - 20) / 40 + 0.5)
    if raw < 0 then raw = 0 end
    if raw > 255 then raw = 255 end
    return raw
end

local function encodeTimingAdvance(value)
    local v = tonumber(value) or 0
    if v >= 10 then return v end
    if v < 0 then v = 0 end
    if v > 3 then v = 3 end
    return (v * 8) + 10
end

local function encodeAutoPWMSwitch(value)
    local v = tonumber(value) or 0
    if v <= 0 then return 0 end
    return 2
end

local function encodeVariablePWMSwitch(value)
    local v = tonumber(value) or 0
    if v == 1 then return 1 end
    return 0
end


local function processReplyStaticRead(self, buf)
    core.parseMSPData(API_NAME, buf, self.structure, nil, nil, {
        chunked = MSP_PARSER_OPTIONS.chunked,
        fieldsPerTick = MSP_PARSER_OPTIONS.fieldsPerTick,
        completionCallback = function(result)
            mspData = result
            normalizeTimingAdvance(mspData and mspData.parsed)
            normalizeMotorKv(mspData and mspData.parsed)
            normalizeAutoPWMSwitch(mspData and mspData.parsed)
            normalizeVariablePWMSwitch(mspData and mspData.parsed)
            if #buf >= (self.minBytes or 0) then
                local getComplete = self.getCompleteHandler
                if getComplete then
                    local complete = getComplete()
                    if complete then complete(self, buf) end
                end
            end
        end
    })
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

    local message = {command = MSP_API_CMD_READ, apiname=API_NAME, structure = MSP_API_STRUCTURE_READ, minBytes = MSP_MIN_BYTES, processReply = processReplyStaticRead, errorHandler = errorHandlerStatic, simulatorResponse = MSP_API_SIMULATOR_RESPONSE, uuid = MSP_API_UUID, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler, mspData = nil}
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function buildEncodedPayloadData()
    local encoded = {}
    for key, value in pairs(payloadData) do
        encoded[key] = value
    end
    if encoded.motor_kv ~= nil then encoded.motor_kv = encodeMotorKv(encoded.motor_kv) end
    if encoded.timing_advance ~= nil then encoded.timing_advance = encodeTimingAdvance(encoded.timing_advance) end
    if encoded.pwm_frequency ~= nil then encoded.pwm_frequency = encodeAutoPWMSwitch(encoded.pwm_frequency) end
    if encoded.variable_pwm_frequency ~= nil then encoded.variable_pwm_frequency = encodeVariablePWMSwitch(encoded.variable_pwm_frequency) end
    return encoded
end

local function write(suppliedPayload)
    if MSP_API_CMD_WRITE == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_WRITE", "debug")
        return
    end

    local payload = suppliedPayload or core.buildWritePayload(API_NAME, buildEncodedPayloadData(), MSP_API_STRUCTURE_WRITE, MSP_REBUILD_ON_WRITE)

    local uuid = MSP_API_UUID or rfsuite.utils and rfsuite.utils.uuid and rfsuite.utils.uuid() or tostring(os.clock())
    lastWriteUUID = uuid

    local message = {command = MSP_API_CMD_WRITE, apiname = API_NAME, payload = payload, processReply = processReplyStaticWrite, errorHandler = errorHandlerStatic, simulatorResponse = {}, uuid = uuid, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler}

    rfsuite.tasks.msp.mspQueue:add(message)
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
