--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api_core.lua"))()

local API_NAME = "MIXER_INPUT"
local MSP_API_CMD_READ = 170
local MSP_API_CMD_WRITE = 171
local MSP_REBUILD_ON_WRITE = true

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {

    -- 0: MIXER_IN_NONE
    { field = "rate_none", type = "U16", apiVersion = 12.06, simResponse = { 0, 0 } },
    { field = "min_none",  type = "U16", apiVersion = 12.06, simResponse = { 0, 0 } },
    { field = "max_none",  type = "U16", apiVersion = 12.06, simResponse = { 0, 0 } },

    -- 1: MIXER_IN_STABILIZED_ROLL
    { field = "rate_stabilized_roll", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 }, tableEthos = {[1] = { "@i18n(api.MIXER_INPUT.tbl_normal)@",   250 },[2] = { "@i18n(api.MIXER_INPUT.tbl_reversed)@", 65286 }}},
    { field = "min_stabilized_roll",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_stabilized_roll",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    -- 2: MIXER_IN_STABILIZED_PITCH
    { field = "rate_stabilized_pitch", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } , tableEthos = {[1] = { "@i18n(api.MIXER_INPUT.tbl_normal)@",   250 },[2] = { "@i18n(api.MIXER_INPUT.tbl_reversed)@", 65286 }}},
    { field = "min_stabilized_pitch",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_stabilized_pitch",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    -- 3: MIXER_IN_STABILIZED_YAW
    { field = "rate_stabilized_yaw", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } , tableEthos = {[1] = { "@i18n(api.MIXER_INPUT.tbl_normal)@",   250 },[2] = { "@i18n(api.MIXER_INPUT.tbl_reversed)@", 65286 }}},
    { field = "min_stabilized_yaw",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_stabilized_yaw",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    -- 4: MIXER_IN_STABILIZED_COLLECTIVE
    { field = "rate_stabilized_collective", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } , tableEthos = {[1] = { "@i18n(api.MIXER_INPUT.tbl_normal)@",   250 },[2] = { "@i18n(api.MIXER_INPUT.tbl_reversed)@", 65286 }}},
    { field = "min_stabilized_collective",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_stabilized_collective",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    -- 5: MIXER_IN_STABILIZED_THROTTLE
    { field = "rate_stabilized_throttle", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_stabilized_throttle",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_stabilized_throttle",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    -- 6: MIXER_IN_RC_COMMAND_ROLL
    { field = "rate_rc_command_roll", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_command_roll",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_command_roll",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    -- 7: MIXER_IN_RC_COMMAND_PITCH
    { field = "rate_rc_command_pitch", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_command_pitch",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_command_pitch",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    -- 8: MIXER_IN_RC_COMMAND_YAW
    { field = "rate_rc_command_yaw", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_command_yaw",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_command_yaw",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    -- 9: MIXER_IN_RC_COMMAND_COLLECTIVE
    { field = "rate_rc_command_collective", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_command_collective",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_command_collective",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    -- 10: MIXER_IN_RC_COMMAND_THROTTLE
    { field = "rate_rc_command_throttle", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_command_throttle",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_command_throttle",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    -- 11: MIXER_IN_RC_CHANNEL_ROLL
    { field = "rate_rc_channel_roll", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_channel_roll",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_channel_roll",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    -- 12: MIXER_IN_RC_CHANNEL_PITCH
    { field = "rate_rc_channel_pitch", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_channel_pitch",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_channel_pitch",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    -- 13: MIXER_IN_RC_CHANNEL_YAW
    { field = "rate_rc_channel_yaw", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_channel_yaw",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_channel_yaw",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    -- 14: MIXER_IN_RC_CHANNEL_COLLECTIVE
    { field = "rate_rc_channel_collective", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_channel_collective",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_channel_collective",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    -- 15: MIXER_IN_RC_CHANNEL_THROTTLE
    { field = "rate_rc_channel_throttle", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_channel_throttle",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_channel_throttle",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    -- 16–18: AUX
    { field = "rate_rc_channel_aux1", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_channel_aux1",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_channel_aux1",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_aux2", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_channel_aux2",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_channel_aux2",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_aux3", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_channel_aux3",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_channel_aux3",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    -- 19–28: RC channels 9–18
    { field = "rate_rc_channel_9",  type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_channel_9",   type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_channel_9",   type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_10", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_channel_10",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_channel_10",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_11", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_channel_11",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_channel_11",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_12", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_channel_12",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_channel_12",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_13", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_channel_13",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_channel_13",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_14", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_channel_14",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_channel_14",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_15", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_channel_15",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_channel_15",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_16", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_channel_16",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_channel_16",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_17", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_channel_17",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_channel_17",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    { field = "rate_rc_channel_18", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_rc_channel_18",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_rc_channel_18",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },
}

-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

-- LuaFormatter off
local MSP_API_STRUCTURE_WRITE = {
    -- mixer input index
    { field = "index", type = "U8" },

    -- mixer input values
    { field = "rate",  type = "U16" },
    { field = "min",   type = "U16" },
    { field = "max",   type = "U16" },
}
-- LuaFormatter on

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
