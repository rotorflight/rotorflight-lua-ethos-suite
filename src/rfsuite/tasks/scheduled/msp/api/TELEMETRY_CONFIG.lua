--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduled/msp/api_core.lua"))()

local API_NAME = "TELEMETRY_CONFIG"
local MSP_API_CMD_READ = 73
local MSP_API_CMD_WRITE = 74
local MSP_REBUILD_ON_WRITE = false

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "telemetry_inverted", type = "U8", apiVersion = 12.06, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telemetry_inverted)@"},
    {field = "halfDuplex", type = "U8", apiVersion = 12.06, simResponse = {1}, help = "@i18n(api.TELEMETRY_CONFIG.halfDuplex)@"},
    {field = "enableSensors", type = "U32", apiVersion = 12.06, simResponse = {0, 0, 0, 0}, help = "@i18n(api.TELEMETRY_CONFIG.enableSensors)@"},
    {field = "pinSwap", type = "U8", apiVersion = 12.08, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.pinSwap)@"},
    {field = "crsf_telemetry_mode", type = "U8", apiVersion = 12.08, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.crsf_telemetry_mode)@"},
    {field = "crsf_telemetry_link_rate", type = "U16", apiVersion = 12.08, simResponse = {250, 0}, help = "@i18n(api.TELEMETRY_CONFIG.crsf_telemetry_link_rate)@"},
    {field = "crsf_telemetry_link_ratio", type = "U16", apiVersion = 12.08, simResponse = {8, 0}, help = "@i18n(api.TELEMETRY_CONFIG.crsf_telemetry_link_ratio)@"},
    {field = "telem_sensor_slot_1", type = "U8", apiVersion = 12.08, simResponse = {3}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_1)@"},
    {field = "telem_sensor_slot_2", type = "U8", apiVersion = 12.08, simResponse = {4}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_2)@"},
    {field = "telem_sensor_slot_3", type = "U8", apiVersion = 12.08, simResponse = {5}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_3)@"},
    {field = "telem_sensor_slot_4", type = "U8", apiVersion = 12.08, simResponse = {6}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_4)@"},
    {field = "telem_sensor_slot_5", type = "U8", apiVersion = 12.08, simResponse = {8}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_5)@"},
    {field = "telem_sensor_slot_6", type = "U8", apiVersion = 12.08, simResponse = {8}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_6)@"},
    {field = "telem_sensor_slot_7", type = "U8", apiVersion = 12.08, simResponse = {89}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_7)@"},
    {field = "telem_sensor_slot_8", type = "U8", apiVersion = 12.08, simResponse = {90}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_8)@"},
    {field = "telem_sensor_slot_9", type = "U8", apiVersion = 12.08, simResponse = {91}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_9)@"},
    {field = "telem_sensor_slot_10", type = "U8", apiVersion = 12.08, simResponse = {99}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_10)@"},
    {field = "telem_sensor_slot_11", type = "U8", apiVersion = 12.08, simResponse = {95}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_11)@"},
    {field = "telem_sensor_slot_12", type = "U8", apiVersion = 12.08, simResponse = {96}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_12)@"},
    {field = "telem_sensor_slot_13", type = "U8", apiVersion = 12.08, simResponse = {60}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_13)@"},
    {field = "telem_sensor_slot_14", type = "U8", apiVersion = 12.08, simResponse = {15}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_14)@"},
    {field = "telem_sensor_slot_15", type = "U8", apiVersion = 12.08, simResponse = {42}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_15)@"},
    {field = "telem_sensor_slot_16", type = "U8", apiVersion = 12.08, simResponse = {93}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_16)@"},
    {field = "telem_sensor_slot_17", type = "U8", apiVersion = 12.08, simResponse = {50}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_17)@"},
    {field = "telem_sensor_slot_18", type = "U8", apiVersion = 12.08, simResponse = {51}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_18)@"},
    {field = "telem_sensor_slot_19", type = "U8", apiVersion = 12.08, simResponse = {52}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_19)@"},
    {field = "telem_sensor_slot_20", type = "U8", apiVersion = 12.08, simResponse = {17}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_20)@"},
    {field = "telem_sensor_slot_21", type = "U8", apiVersion = 12.08, simResponse = {18}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_21)@"},
    {field = "telem_sensor_slot_22", type = "U8", apiVersion = 12.08, simResponse = {19}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_22)@"},
    {field = "telem_sensor_slot_23", type = "U8", apiVersion = 12.08, simResponse = {23}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_23)@"},
    {field = "telem_sensor_slot_24", type = "U8", apiVersion = 12.08, simResponse = {22}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_24)@"},
    {field = "telem_sensor_slot_25", type = "U8", apiVersion = 12.08, simResponse = {36}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_25)@"},
    {field = "telem_sensor_slot_26", type = "U8", apiVersion = 12.08, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_26)@"},
    {field = "telem_sensor_slot_27", type = "U8", apiVersion = 12.08, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_27)@"},
    {field = "telem_sensor_slot_28", type = "U8", apiVersion = 12.08, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_28)@"},
    {field = "telem_sensor_slot_29", type = "U8", apiVersion = 12.08, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_29)@"},
    {field = "telem_sensor_slot_30", type = "U8", apiVersion = 12.08, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_30)@"},
    {field = "telem_sensor_slot_31", type = "U8", apiVersion = 12.08, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_31)@"},
    {field = "telem_sensor_slot_32", type = "U8", apiVersion = 12.08, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_32)@"},
    {field = "telem_sensor_slot_33", type = "U8", apiVersion = 12.08, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_33)@"},
    {field = "telem_sensor_slot_34", type = "U8", apiVersion = 12.08, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_34)@"},
    {field = "telem_sensor_slot_35", type = "U8", apiVersion = 12.08, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_35)@"},
    {field = "telem_sensor_slot_36", type = "U8", apiVersion = 12.08, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_36)@"},
    {field = "telem_sensor_slot_37", type = "U8", apiVersion = 12.08, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_37)@"},
    {field = "telem_sensor_slot_38", type = "U8", apiVersion = 12.08, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_38)@"},
    {field = "telem_sensor_slot_39", type = "U8", apiVersion = 12.08, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_39)@"},
    {field = "telem_sensor_slot_40", type = "U8", apiVersion = 12.08, simResponse = {0}, help = "@i18n(api.TELEMETRY_CONFIG.telem_sensor_slot_40)@"}
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

local function setRebuildOnWrite(rebuild) MSP_REBUILD_ON_WRITE = rebuild end

return {read = read, write = write, setRebuildOnWrite = setRebuildOnWrite, readComplete = readComplete, writeComplete = writeComplete, readValue = readValue, setValue = setValue, resetWriteStatus = resetWriteStatus, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data, setUUID = setUUID, setTimeout = setTimeout}
