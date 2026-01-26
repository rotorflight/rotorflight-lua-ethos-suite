--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "ESC_PARAMETERS_FLYROTOR"
local MSP_API_CMD_READ = 217
local MSP_API_CMD_WRITE = 218
local MSP_REBUILD_ON_WRITE = false
local MSP_SIGNATURE = 0x73
local MSP_HEADER_BYTES = 2

local tblLed = {"CUSTOM", "OFF", "RED", "GREEN", "BLUE", "YELLOW", "MAGENTA", "CYAN", "WHITE", "ORANGE", "GRAY", "MAROON", "DARK_GREEN", "NAVY", "PURPLE", "TEAL", "SILVER", "PINK", "GOLD", "BROWN", "LIGHT_BLUE", "FL_PINK", "FL_ORANGE", "FL_LIME", "FL_MINT", "FL_CYAN", "FL_PURPLE", "FL_HOT_PINK", "FL_LIGHT_YELLOW", "FL_AQUAMARINE", "FL_GOLD", "FL_DEEP_PINK", "FL_NEON_GREEN", "FL_ORANGE_RED"}

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_signature", type = "U8", apiVersion = 12.07, simResponse = {115}, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.esc_signature)@"},
    {field = "esc_command", type = "U8", apiVersion = 12.07, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.esc_command)@"},
    {field = "esc_type", type = "U8", apiVersion = 12.07, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.esc_type)@"},
    {field = "esc_model", type = "U16", apiVersion = 12.07, simResponse = {1, 24}, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.esc_model)@", byteorder = "big"},
    {field = "esc_sn", type = "U64", apiVersion = 12.07, simResponse = {231, 79, 190, 216, 78, 29, 169, 244}, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.esc_sn)@"},
    {field = "esc_iap", type = "U24", apiVersion = 12.07, simResponse = {1, 0, 0}, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.esc_iap)@"},
    {field = "esc_fw", type = "U24", apiVersion = 12.07, simResponse = {1, 0, 1}, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.esc_fw)@"},
    {field = "esc_hardware", type = "U8", apiVersion = 12.07, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.esc_hardware)@"},
    {field = "throttle_min", type = "U16", apiVersion = 12.07, simResponse = {4, 76}, byteorder = "big", help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.throttle_min)@"},
    {field = "throttle_max", type = "U16", apiVersion = 12.07, simResponse = {7, 148}, byteorder = "big", help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.throttle_max)@"},
    {field = "esc_mode", type = "U8", apiVersion = 12.07, simResponse = {0}, table = {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_escgov)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_linear_thr)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_rf_gov)@"}, tableIdxInc = -1, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.governor)@"},
    {field = "cell_count", type = "U8", apiVersion = 12.07, simResponse = {6}, min = 4, max = 14, default = 6, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.cell_count)@"},
    {field = "low_voltage_protection", type = "U8", apiVersion = 12.07, simResponse = {30}, min = 28, max = 38, scale = 10, default = 30, decimals = 1, unit = "V", help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.low_voltage_protection)@"},
    {field = "temperature_protection", type = "U8", apiVersion = 12.07, simResponse = {125}, min = 50, max = 135, default = 125, unit = "°", help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.temperature_protection)@"},
    {field = "bec_voltage", type = "U8", apiVersion = 12.07, simResponse = {1}, table = {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_disabled)@", "7.5V", "8.0V", "8.5V", "12.0V"}, tableIdxInc = -1, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.bec_voltage)@"},
    {field = "electrical_angle", type = "U8", apiVersion = 12.07, simResponse = {0}, table = {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_auto)@", "1°", "2°", "3°", "4°", "5°", "6°", "7°", "8°", "9°", "10°"}, tableIdxInc = -1, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.electrical_angle)@"},
    {field = "motor_direction", type = "U8", apiVersion = 12.07, simResponse = {0}, table = {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_cw)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_ccw)@"}, tableIdxInc = -1, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.motor_direction)@"},
    {field = "starting_torque", type = "U8", apiVersion = 12.07, simResponse = {3}, min = 1, max = 15, default = 3, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.starting_torque)@"},
    {field = "response_speed", type = "U8", apiVersion = 12.07, simResponse = {5}, min = 1, max = 15, default = 5, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.response_speed)@"},
    {field = "buzzer_volume", type = "U8", apiVersion = 12.07, simResponse = {1}, min = 1, max = 5, default = 2, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.buzzer_volume)@"},
    {field = "current_gain", type = "S8", apiVersion = 12.07, simResponse = {20}, min = 0, max = 40, default = 20, offset = -20, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.current_gain)@"},
    {field = "fan_control", type = "U8", apiVersion = 12.07, simResponse = {0}, table = {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_automatic)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_alwayson)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_alwaysoff)@"}, tableIdxInc = -1, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.fan_control)@"},
    {field = "soft_start", type = "U8", apiVersion = 12.07, simResponse = {15}, min = 5, max = 55, default = 15, unit = "s", help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.soft_start)@"},
    {field = "auto_restart_time", type = "U8", apiVersion = 12.07, simResponse = {15}, min = 0, max = 100, default = 30, unit = "s", help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.auto_restart_time)@"},
    {field = "restart_acc", type = "U8", apiVersion = 12.07, simResponse = {15}, min = 1, max = 10, default = 5, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.restart_acc)@"},
    {field = "gov_p", type = "U8", apiVersion = 12.07, simResponse = {45}, min = 0, max = 100, default = 45, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.gov_p)@"},
    {field = "gov_i", type = "U8", apiVersion = 12.07, simResponse = {35}, min = 0, max = 100, default = 35, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.gov_i)@"},
    {field = "active_freewheel", type = "U8", apiVersion = 12.08, simResponse = {0}, min = 0, max = 1, table = {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_disabled)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_enabled)@"}, tableIdxInc = -1, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.active_freewheel)@"},
    {field = "drive_freq", type = "U8", apiVersion = 12.07, simResponse = {16}, min = 10, max = 24, default = 16, unit = "KHz", help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.drive_freq)@"},
    {field = "motor_erpm_max", type = "U24", apiVersion = 12.07, simResponse = {2, 23, 40}, min = 0, max = 1000000, step = 100, byteorder = "big", help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.motor_erpm_max)@"},
    {field = "throttle_protocol", type = "U8", apiVersion = 12.08, simResponse = {0}, min = 0, max = 0, table = {"PWM"}, tableIdxInc = -1, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.throttle_protocol)@"},
    {field = "telemetry_protocol", type = "U8", apiVersion = 12.08, simResponse = {0}, min = 0, max = 0, table = {"FLYROTOR"}, tableIdxInc = -1, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.telemetry_protocol)@"},
    {field = "led_color_index", type = "U8", apiVersion = 12.08, simResponse = {3}, min = 0, max = #tblLed - 1, table = tblLed, tableIdxInc = -1, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.led_color_index)@"},
    {field = "led_color_rgb", type = "U24", apiVersion = 12.08, simResponse = {0, 0, 0}, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.led_color_rgb)@"},
    {field = "motor_temp_sensor", type = "U8", apiVersion = 12.08, simResponse = {0}, min = 0, max = 1, table = {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_disabled)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_enabled)@"}, tableIdxInc = -1, help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.motor_temp_sensor)@"},
    {field = "motor_temp", type = "U8", apiVersion = 12.08, simResponse = {100}, min = 50, max = 150, unit = "°", help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.motor_temp)@"},
    {field = "battery_capacity", type = "U16", apiVersion = 12.08, simResponse = {0, 0}, min = 0, max = 50000, step = 100, unit = "mAh", byteorder = "big", help = "@i18n(api.ESC_PARAMETERS_FLYROTOR.battery_capacity)@"}
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

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

local function processReplyStaticRead(self, buf)
    core.parseMSPData(API_NAME, buf, self.structure, nil, nil, function(result)
        mspData = result
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

    local message = {command = MSP_API_CMD_READ, apiname=API_NAME, structure = MSP_API_STRUCTURE_READ, minBytes = MSP_MIN_BYTES, processReply = processReplyStaticRead, errorHandler = errorHandlerStatic, simulatorResponse = MSP_API_SIMULATOR_RESPONSE, uuid = MSP_API_UUID, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler, mspData = nil}
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function write(suppliedPayload)
    if MSP_API_CMD_WRITE == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_WRITE", "debug")
        return
    end

    local payload = suppliedPayload or core.buildWritePayload(API_NAME, payloadData, MSP_API_STRUCTURE_WRITE, MSP_REBUILD_ON_WRITE)

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
