--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api_core.lua"))()

local API_NAME = "ESC_PARAMETERS_ZTW"
local MSP_API_CMD_READ = 217
local MSP_API_CMD_WRITE = 218
local MSP_REBUILD_ON_WRITE = false
local MSP_SIGNATURE = 0xDD
local MSP_HEADER_BYTES = 2

local flightMode = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_fmheli)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_fmfw)@"}
local motorDirection = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_cw)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_ccw)@"}
local becLvVoltage = {"6.0V", "7.4V", "8.4V"}
local startupPower = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_low)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_medium)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_high)@"}
local fanControl = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_on)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_off)@"}
local ledColor = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_red)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_yellow)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_orange)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_green)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_jadegreen)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_blue)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_cyan)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_purple)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_pink)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_white)@"}
local becHvVoltage = {"6.0V", "6.2V", "6.4V", "6.6V", "6.8V", "7.0V", "7.2V", "7.4V", "7.6V", "7.8V", "8.0V", "8.2V", "8.4V", "8.6V", "8.8V", "9.0V", "9.2V", "9.4V", "9.6V", "9.8V", "10.0V", "10.2V", "10.4V", "10.6V", "10.8V", "11.0V", "11.2V", "11.4V", "11.6V", "11.8V", "12.0V"}
local lowVoltage = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_off)@", "2.7V", "3.0V", "3.2V", "3.4V", "3.6V", "3.8V"}
local timing = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_auto)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_low)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_medium)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_high)@"}
local accel = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_fast)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_normal)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_slow)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_vslow)@"}
local brakeType = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_normal)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_reverse)@"}
local autoRestart = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_off)@", "90s"}
local srFunc = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_on)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_off)@"}
local govMode = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_escgov)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_extgov)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_fwgov)@"}

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_signature", type = "U8", apiVersion = 12.07, simResponse = {221}, help = "@i18n(api.ESC_PARAMETERS_ZTW.esc_signature)@"},
    {field = "esc_command", type = "U8", apiVersion = 12.07, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_ZTW.esc_command)@"},
    {field = "esc_model", type = "U8", apiVersion = 12.07, simResponse = {23}, help = "@i18n(api.ESC_PARAMETERS_ZTW.esc_model)@"},
    {field = "esc_version", type = "U8", apiVersion = 12.07, simResponse = {3}, help = "@i18n(api.ESC_PARAMETERS_ZTW.esc_version)@"},
    {field = "governor", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = govMode, help = "@i18n(api.ESC_PARAMETERS_ZTW.governor)@"},
    {field = "cell_cutoff", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = lowVoltage, help = "@i18n(api.ESC_PARAMETERS_ZTW.cell_cutoff)@"},
    {field = "timing", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = timing, help = "@i18n(api.ESC_PARAMETERS_ZTW.timing)@"},
    {field = "lv_bec_voltage", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = becLvVoltage, help = "@i18n(api.ESC_PARAMETERS_ZTW.lv_bec_voltage)@"},
    {field = "motor_direction", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = motorDirection, help = "@i18n(api.ESC_PARAMETERS_ZTW.motor_direction)@"},
    {field = "gov_p", type = "U16", apiVersion = 12.07, simResponse = {4, 0}, min = 1, max = 10, default = 5, offset = 1, help = "@i18n(api.ESC_PARAMETERS_ZTW.gov_p)@"},
    {field = "gov_i", type = "U16", apiVersion = 12.07, simResponse = {3, 0}, min = 1, max = 10, default = 5, offset = 1, help = "@i18n(api.ESC_PARAMETERS_ZTW.gov_i)@"},
    {field = "acceleration", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = accel, help = "@i18n(api.ESC_PARAMETERS_ZTW.acceleration)@"},
    {field = "auto_restart_time", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = autoRestart, help = "@i18n(api.ESC_PARAMETERS_ZTW.auto_restart_time)@"},
    {field = "hv_bec_voltage", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = becHvVoltage, help = "@i18n(api.ESC_PARAMETERS_ZTW.hv_bec_voltage)@"},
    {field = "startup_power", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, table = startupPower, tableIdxInc = -1, help = "@i18n(api.ESC_PARAMETERS_ZTW.startup_power)@"},
    {field = "brake_type", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = brakeType, help = "@i18n(api.ESC_PARAMETERS_ZTW.brake_type)@"},
    {field = "brake_force", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = 100, default = 0, unit = "%", help = "@i18n(api.ESC_PARAMETERS_ZTW.brake_force)@"},
    {field = "sr_function", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, table = srFunc, tableIdxInc = -1, help = "@i18n(api.ESC_PARAMETERS_ZTW.sr_function)@"},
    {field = "capacity_correction", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = 20, default = 10, offset = -10, unit = "%", help = "@i18n(api.ESC_PARAMETERS_ZTW.capacity_correction)@"},
    {field = "motor_poles", type = "U16", apiVersion = 12.07, simResponse = {9, 0}, min = 1, max = 55, default = 10, step = 1, offset = 1, help = "@i18n(api.ESC_PARAMETERS_ZTW.motor_poles)@"},
    {field = "led_color", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = ledColor, help = "@i18n(api.ESC_PARAMETERS_ZTW.led_color)@"},
    {field = "smart_fan", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = fanControl, help = "@i18n(api.ESC_PARAMETERS_ZTW.smart_fan)@"},
    {field = "activefields", type = "U32", apiVersion = 12.07, simResponse = {238, 255, 1, 0}, help = "@i18n(api.ESC_PARAMETERS_ZTW.activefields)@"}
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

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

return {read = read, write = write, readComplete = readComplete, writeComplete = writeComplete, readValue = readValue, setValue = setValue, resetWriteStatus = resetWriteStatus, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data, setUUID = setUUID, setTimeout = setTimeout, mspSignature = MSP_SIGNATURE, mspHeaderBytes = MSP_HEADER_BYTES, simulatorResponse = MSP_API_SIMULATOR_RESPONSE}
