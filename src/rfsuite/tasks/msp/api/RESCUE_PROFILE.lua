--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api_core.lua"))()

local API_NAME = "RESCUE_PROFILE"
local MSP_API_CMD_READ = 146
local MSP_API_CMD_WRITE = 147
local MSP_REBUILD_ON_WRITE = false

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "rescue_mode", type = "U8", apiVersion = 12.06, simResponse = {1}, min = 0, max = 1, default = 0, table = {[0] = "@i18n(api.RESCUE_PROFILE.tbl_off)@", "@i18n(api.RESCUE_PROFILE.tbl_on)@"}, help = "@i18n(api.RESCUE_PROFILE.help_rescue_mode)@"},
    {field = "rescue_flip_mode", type = "U8", apiVersion = 12.06, simResponse = {0}, min = 0, max = 1, default = 0, table = {[0] = "@i18n(api.RESCUE_PROFILE.tbl_noflip)@", "@i18n(api.RESCUE_PROFILE.tbl_flip)@"}, help = "@i18n(api.RESCUE_PROFILE.help_rescue_flip_mode)@"},
    {field = "rescue_flip_gain", type = "U8", apiVersion = 12.06, simResponse = {200}, min = 5, max = 250, default = 200, help = "@i18n(api.RESCUE_PROFILE.help_rescue_flip_gain)@"},
    {field = "rescue_level_gain", type = "U8", apiVersion = 12.06, simResponse = {100}, min = 5, max = 250, default = 100, help = "@i18n(api.RESCUE_PROFILE.help_rescue_level_gain)@"},
    {field = "rescue_pull_up_time", type = "U8", apiVersion = 12.06, simResponse = {5}, min = 0, max = 250, default = 0.3, unit = "s", decimals = 1, scale = 10, help = "@i18n(api.RESCUE_PROFILE.help_rescue_pull_up_time)@"},
    {field = "rescue_climb_time", type = "U8", apiVersion = 12.06, simResponse = {3}, min = 0, max = 250, default = 1, unit = "s", decimals = 1, scale = 10, help = "@i18n(api.RESCUE_PROFILE.help_rescue_climb_time)@"},
    {field = "rescue_flip_time", type = "U8", apiVersion = 12.06, simResponse = {10}, min = 0, max = 250, default = 2, unit = "s", decimals = 1, scale = 10, help = "@i18n(api.RESCUE_PROFILE.help_rescue_flip_time)@"},
    {field = "rescue_exit_time", type = "U8", apiVersion = 12.06, simResponse = {5}, min = 0, max = 250, default = 0.5, unit = "s", decimals = 1, scale = 10, help = "@i18n(api.RESCUE_PROFILE.help_rescue_exit_time)@"},
    {field = "rescue_pull_up_collective", type = "U16", apiVersion = 12.06, simResponse = {182, 3}, min = 0, max = 100, default = 65, unit = "%", scale = 10, help = "@i18n(api.RESCUE_PROFILE.help_rescue_pull_up_collective)@"},
    {field = "rescue_climb_collective", type = "U16", apiVersion = 12.06, simResponse = {188, 2}, min = 0, max = 100, default = 45, unit = "%", scale = 10, help = "@i18n(api.RESCUE_PROFILE.help_rescue_climb_collective)@"},
    {field = "rescue_hover_collective", type = "U16", apiVersion = 12.06, simResponse = {194, 1}, min = 0, max = 100, default = 35, unit = "%", scale = 10, help = "@i18n(api.RESCUE_PROFILE.help_rescue_hover_collective)@"},
    {field = "rescue_hover_altitude", type = "U16", apiVersion = 12.06, simResponse = {244, 1}, help = "@i18n(api.RESCUE_PROFILE.help_rescue_hover_altitude)@", min = 0, max = 500, default = 20, unit = "m"},
    {field = "rescue_alt_p_gain", type = "U16", apiVersion = 12.06, simResponse = {20, 0}, help = "@i18n(api.RESCUE_PROFILE.help_rescue_alt_p_gain)@", min = 0, max = 1000, default = 20},
    {field = "rescue_alt_i_gain", type = "U16", apiVersion = 12.06, simResponse = {20, 0}, help = "@i18n(api.RESCUE_PROFILE.help_rescue_alt_i_gain)@", min = 0, max = 1000, default = 20},
    {field = "rescue_alt_d_gain", type = "U16", apiVersion = 12.06, simResponse = {10, 0}, help = "@i18n(api.RESCUE_PROFILE.help_rescue_alt_d_gain)@", min = 0, max = 1000, default = 10},
    {field = "rescue_max_collective", type = "U16", apiVersion = 12.06, simResponse = {232, 3}, help = "@i18n(api.RESCUE_PROFILE.help_rescue_max_collective)@", min = 0, max = 100, default = 90, unit = "%", scale = 10},
    {field = "rescue_max_setpoint_rate", type = "U16", apiVersion = 12.06, simResponse = {44, 1}, min = 5, max = 1000, default = 300, unit = "°/s", help = "@i18n(api.RESCUE_PROFILE.help_rescue_max_setpoint_rate)@"},
    {field = "rescue_max_setpoint_accel", type = "U16", apiVersion = 12.06, simResponse = {184, 11}, min = 0, max = 10000, default = 3000, unit = "°/s^2", help = "@i18n(api.RESCUE_PROFILE.help_rescue_max_setpoint_accel)@"}
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

    local message = {command = MSP_API_CMD_READ, structure = MSP_API_STRUCTURE_READ, minBytes = MSP_MIN_BYTES, processReply = processReplyStaticRead, errorHandler = errorHandlerStatic, simulatorResponse = MSP_API_SIMULATOR_RESPONSE, uuid = MSP_API_UUID, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler, mspData = nil}
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

    local message = {command = MSP_API_CMD_WRITE, payload = payload, processReply = processReplyStaticWrite, errorHandler = errorHandlerStatic, simulatorResponse = {}, uuid = uuid, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler}

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

return {read = read, write = write, readComplete = readComplete, writeComplete = writeComplete, readValue = readValue, setValue = setValue, resetWriteStatus = resetWriteStatus, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data, setUUID = setUUID, setTimeout = setTimeout}
