--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduled/msp/api_core.lua"))()

local API_NAME = "FEATURE_CONFIG"
local MSP_API_CMD_READ = 36
local MSP_API_CMD_WRITE = 37
local MSP_REBUILD_ON_WRITE = false


local pwmProtocol



local onoff = {"@i18n(api.MOTOR_CONFIG.tbl_off)@", "@i18n(api.MOTOR_CONFIG.tbl_on)@"}

-- IMPORTANT: keep entries ordered so index == bit number (bit0 first, bit1 second, etc)
local features_bitmap = {
  { field = "rx_ppm",          tableIdxInc = -1, table = onoff }, -- bit 0
  { field = "unused_1",        tableIdxInc = -1, table = onoff }, -- bit 1
  { field = "unused_2",        tableIdxInc = -1, table = onoff }, -- bit 2
  { field = "rx_serial",       tableIdxInc = -1, table = onoff }, -- bit 3
  { field = "unused_4",        tableIdxInc = -1, table = onoff }, -- bit 4
  { field = "unused_5",        tableIdxInc = -1, table = onoff }, -- bit 5
  { field = "softserial",      tableIdxInc = -1, table = onoff }, -- bit 6
  { field = "gps",             tableIdxInc = -1, table = onoff }, -- bit 7
  { field = "unused_8",        tableIdxInc = -1, table = onoff }, -- bit 8
  { field = "rangefinder",     tableIdxInc = -1, table = onoff }, -- bit 9
  { field = "telemetry",       tableIdxInc = -1, table = onoff }, -- bit 10
  { field = "unused_11",       tableIdxInc = -1, table = onoff }, -- bit 11
  { field = "unused_12",       tableIdxInc = -1, table = onoff }, -- bit 12
  { field = "rx_parallel_pwm", tableIdxInc = -1, table = onoff }, -- bit 13
  { field = "rx_msp",          tableIdxInc = -1, table = onoff }, -- bit 14
  { field = "rssi_adc",        tableIdxInc = -1, table = onoff }, -- bit 15
  { field = "led_strip",       tableIdxInc = -1, table = onoff }, -- bit 16
  { field = "dashboard",       tableIdxInc = -1, table = onoff }, -- bit 17
  { field = "osd",             tableIdxInc = -1, table = onoff }, -- bit 18
  { field = "cms",             tableIdxInc = -1, table = onoff }, -- bit 19
  { field = "unused_20",       tableIdxInc = -1, table = onoff }, -- bit 20
  { field = "unused_21",       tableIdxInc = -1, table = onoff }, -- bit 21
  { field = "unused_22",       tableIdxInc = -1, table = onoff }, -- bit 22
  { field = "unused_23",       tableIdxInc = -1, table = onoff }, -- bit 23
  { field = "unused_24",       tableIdxInc = -1, table = onoff }, -- bit 24
  { field = "rx_spi",          tableIdxInc = -1, table = onoff }, -- bit 25
  { field = "governor",        tableIdxInc = -1, table = onoff }, -- bit 26
  { field = "esc_sensor",      tableIdxInc = -1, table = onoff }, -- bit 27
  { field = "freq_sensor",     tableIdxInc = -1, table = onoff }, -- bit 28
  { field = "dyn_notch",       tableIdxInc = -1, table = onoff }, -- bit 29
  { field = "rpm_filter",      tableIdxInc = -1, table = onoff }, -- bit 30
}


-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
  { field = "enabledFeatures", type = "U32", apiVersion = 12.06, simResponse = {0,0,0,0}, bitmap = features_bitmap },
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
