--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api_core.lua"))()

local API_NAME = "GOVERNOR_PROFILE"
local MSP_API_CMD_READ = 148
local MSP_API_CMD_WRITE = 149
local MSP_REBUILD_ON_WRITE = false

local MSP_API_STRUCTURE_READ_DATA

-- LuaFormatter off
if rfsuite.utils.apiVersionCompare(">=", "12.09") then

    local offOn = {
        "@i18n(api.GOVERNOR_PROFILE.tbl_off)@",
        "@i18n(api.GOVERNOR_PROFILE.tbl_on)@"
    }

    local governor_flags_bitmap = {
        { field = "fc_throttle_curve",       table = offOn, tableIdxInc = -1, help = "@i18n(api.GOVERNOR_PROFILE.fc_throttle_curve)@" },
        { field = "tx_precomp_curve",        table = offOn, tableIdxInc = -1, help = "@i18n(api.GOVERNOR_PROFILE.tx_precomp_curve)@" },
        { field = "fallback_precomp",        table = offOn, tableIdxInc = -1, help = "@i18n(api.GOVERNOR_PROFILE.fallback_precomp)@" },
        { field = "voltage_comp",            table = offOn, tableIdxInc = -1, help = "@i18n(api.GOVERNOR_PROFILE.voltage_comp)@" },
        { field = "pid_spoolup",             table = offOn, tableIdxInc = -1, help = "@i18n(api.GOVERNOR_PROFILE.pid_spoolup)@" },
        { field = "hs_adjustment",           table = offOn, tableIdxInc = -1, help = "@i18n(api.GOVERNOR_PROFILE.hs_adjustment)@" },
        { field = "dyn_min_throttle",        table = offOn, tableIdxInc = -1, help = "@i18n(api.GOVERNOR_PROFILE.dyn_min_throttle)@" },
        { field = "autorotation",            table = offOn, tableIdxInc = -1, help = "@i18n(api.GOVERNOR_PROFILE.autorotation)@" },
        { field = "suspend",                 table = offOn, tableIdxInc = -1, help = "@i18n(api.GOVERNOR_PROFILE.suspend)@" },
        { field = "bypass",                  table = offOn, tableIdxInc = -1, help = "@i18n(api.GOVERNOR_PROFILE.bypass)@" }
    }

    MSP_API_STRUCTURE_READ_DATA = {
        { field = "governor_headspeed",        type = "U16", apiVersion = 12.09, simResponse = {208, 7},  min = 0,   max = 50000, default = 1000, unit = "rpm", step = 10, help = "@i18n(api.GOVERNOR_PROFILE.governor_headspeed)@" },
        { field = "governor_gain",             type = "U8",  apiVersion = 12.09, simResponse = {100},      min = 0,   max = 250,   default = 40,  help = "@i18n(api.GOVERNOR_PROFILE.governor_gain)@" },
        { field = "governor_p_gain",           type = "U8",  apiVersion = 12.09, simResponse = {10},       min = 0,   max = 250,   default = 40,  help = "@i18n(api.GOVERNOR_PROFILE.governor_p_gain)@" },
        { field = "governor_i_gain",           type = "U8",  apiVersion = 12.09, simResponse = {125},      min = 0,   max = 250,   default = 50,  help = "@i18n(api.GOVERNOR_PROFILE.governor_i_gain)@" },
        { field = "governor_d_gain",           type = "U8",  apiVersion = 12.09, simResponse = {5},        min = 0,   max = 250,   default = 0,   help = "@i18n(api.GOVERNOR_PROFILE.governor_d_gain)@" },
        { field = "governor_f_gain",           type = "U8",  apiVersion = 12.09, simResponse = {20},       min = 0,   max = 250,   default = 10,  help = "@i18n(api.GOVERNOR_PROFILE.governor_f_gain)@" },
        { field = "governor_tta_gain",         type = "U8",  apiVersion = 12.09, simResponse = {0},        min = 0,   max = 250,   default = 0,   help = "@i18n(api.GOVERNOR_PROFILE.governor_tta_gain)@" },
        { field = "governor_tta_limit",        type = "U8",  apiVersion = 12.09, simResponse = {20},       min = 0,   max = 250,   default = 20,  unit = "%", help = "@i18n(api.GOVERNOR_PROFILE.governor_tta_limit)@" },
        { field = "governor_yaw_weight",       type = "U8",  apiVersion = 12.09, simResponse = {10},       min = 0,   max = 250,   default = 0,   help = "@i18n(api.GOVERNOR_PROFILE.governor_yaw_weight)@" },
        { field = "governor_cyclic_weight",    type = "U8",  apiVersion = 12.09, simResponse = {40},       min = 0,   max = 250,   default = 10,  help = "@i18n(api.GOVERNOR_PROFILE.governor_cyclic_weight)@" },
        { field = "governor_collective_weight",type = "U8",  apiVersion = 12.09, simResponse = {100},      min = 0,   max = 250,   default = 100, help = "@i18n(api.GOVERNOR_PROFILE.governor_collective_weight)@" },
        { field = "governor_max_throttle",     type = "U8",  apiVersion = 12.09, simResponse = {100},      min = 0,   max = 100,   default = 100, unit = "%", help = "@i18n(api.GOVERNOR_PROFILE.governor_max_throttle)@" },
        { field = "governor_min_throttle",     type = "U8",  apiVersion = 12.09, simResponse = {10},       min = 0,   max = 100,   default = 10,  unit = "%", help = "@i18n(api.GOVERNOR_PROFILE.governor_min_throttle)@" },
        { field = "governor_fallback_drop",    type = "U8",  apiVersion = 12.09, simResponse = {10},       min = 0,   max = 50,    default = 10,  unit = "%", help = "@i18n(api.GOVERNOR_PROFILE.governor_fallback_drop)@" },
        { field = "governor_flags",            type = "U16", apiVersion = 12.09, simResponse = {251, 3}, bitmap = governor_flags_bitmap, help = "@i18n(api.GOVERNOR_PROFILE.governor_flags)@" }
    }

else

    MSP_API_STRUCTURE_READ_DATA = {
        { field = "governor_headspeed",           type = "U16", apiVersion = 12.06, simResponse = {208, 7},  min = 0,   max = 50000, default = 1000, unit = "rpm", step = 10, help = "@i18n(api.GOVERNOR_PROFILE.governor_headspeed)@" },
        { field = "governor_gain",                type = "U8",  apiVersion = 12.06, simResponse = {100},      min = 0,   max = 250,   default = 40,  help = "@i18n(api.GOVERNOR_PROFILE.governor_gain)@" },
        { field = "governor_p_gain",              type = "U8",  apiVersion = 12.06, simResponse = {10},       min = 0,   max = 250,   default = 40,  help = "@i18n(api.GOVERNOR_PROFILE.governor_p_gain)@" },
        { field = "governor_i_gain",              type = "U8",  apiVersion = 12.06, simResponse = {125},      min = 0,   max = 250,   default = 50,  help = "@i18n(api.GOVERNOR_PROFILE.governor_i_gain)@" },
        { field = "governor_d_gain",              type = "U8",  apiVersion = 12.06, simResponse = {5},        min = 0,   max = 250,   default = 0,   help = "@i18n(api.GOVERNOR_PROFILE.governor_d_gain)@" },
        { field = "governor_f_gain",              type = "U8",  apiVersion = 12.06, simResponse = {20},       min = 0,   max = 250,   default = 10,  help = "@i18n(api.GOVERNOR_PROFILE.governor_f_gain)@" },
        { field = "governor_tta_gain",            type = "U8",  apiVersion = 12.06, simResponse = {0},        min = 0,   max = 250,   default = 0,   help = "@i18n(api.GOVERNOR_PROFILE.governor_tta_gain)@" },
        { field = "governor_tta_limit",           type = "U8",  apiVersion = 12.06, simResponse = {20},       min = 0,   max = 250,   default = 20,  unit = "%", help = "@i18n(api.GOVERNOR_PROFILE.governor_tta_limit)@" },
        { field = "governor_yaw_ff_weight",       type = "U8",  apiVersion = 12.06, simResponse = {10},       min = 0,   max = 250,   default = 0,   help = "@i18n(api.GOVERNOR_PROFILE.governor_yaw_ff_weight)@" },
        { field = "governor_cyclic_ff_weight",    type = "U8",  apiVersion = 12.06, simResponse = {40},       min = 0,   max = 250,   default = 10,  help = "@i18n(api.GOVERNOR_PROFILE.governor_cyclic_ff_weight)@" },
        { field = "governor_collective_ff_weight",type = "U8",  apiVersion = 12.06, simResponse = {100},      min = 0,   max = 250,   default = 100, help = "@i18n(api.GOVERNOR_PROFILE.governor_collective_ff_weight)@" },
        { field = "governor_max_throttle",        type = "U8",  apiVersion = 12.06, simResponse = {100},      min = 0,   max = 100,   default = 100, unit = "%", help = "@i18n(api.GOVERNOR_PROFILE.governor_max_throttle)@" },
        { field = "governor_min_throttle",        type = "U8",  apiVersion = 12.06, simResponse = {10},       min = 0,   max = 100,   default = 10,  unit = "%", help = "@i18n(api.GOVERNOR_PROFILE.governor_min_throttle)@" }
    }

end
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
