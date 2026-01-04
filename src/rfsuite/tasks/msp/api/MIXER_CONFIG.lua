--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api_core.lua"))()

local API_NAME = "MIXER_CONFIG"
local MSP_API_CMD_READ = 42
local MSP_API_CMD_WRITE = 43
local MSP_REBUILD_ON_WRITE = false

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "main_rotor_dir", type = "U8",  apiVersion = 12.06, simResponse = {0}, table = {"@i18n(api.MIXER_CONFIG.tbl_cw)@", "@i18n(api.MIXER_CONFIG.tbl_ccw)@"}, tableIdxInc = -1, help = "@i18n(api.MIXER_CONFIG.main_rotor_dir)@" },
    { field = "tail_rotor_mode", type = "U8", apiVersion = 12.06, simResponse = {0}, help = "@i18n(api.MIXER_CONFIG.tail_rotor_mode)@" , table = {"@i18n(api.MIXER_CONFIG.tbl_tail_variable_pitch)@", "@i18n(api.MIXER_CONFIG.tbl_tail_motororized_tail)@", "@i18n(api.MIXER_CONFIG.tbl_tail_bidirectional)@"}, tableIdxInc = -1},
    { field = "tail_motor_idle", type = "U8", apiVersion = 12.06, simResponse = {0}, default = 0, unit = "%", min = 0, max = 250, decimals = 1, scale = 10, help = "@i18n(api.MIXER_CONFIG.tail_motor_idle)@" },
    { field = "tail_center_trim", type = "S16", apiVersion = 12.06, simResponse = {165, 1}, default = 0, min = -500, max = 500, decimals = 1, scale = 10, mult = 0.239923224568138, help = "@i18n(api.MIXER_CONFIG.tail_center_trim)@" },
    { field = "swash_type", type = "U8", apiVersion = 12.06, simResponse = {0}, table = {"None", "Direct", "CPPM 120", "CPPM 135", "CPPM 140", "FPM 90 L", "FPM 90 V"}, tableIdxInc = -1, help = "@i18n(api.MIXER_CONFIG.swash_type)@" },
    { field = "swash_ring", type = "U8", apiVersion = 12.06, simResponse = {2}, help = "@i18n(api.MIXER_CONFIG.swash_ring)@" },
    { field = "swash_phase", type = "S16", apiVersion = 12.06, simResponse = {100, 0}, default = 0, min = -1800, max = 1800, decimals = 1, scale = 10, help = "@i18n(api.MIXER_CONFIG.swash_phase)@" },
    { field = "swash_pitch_limit", type = "U16", apiVersion = 12.06, simResponse = {131, 6}, default = 0, min = 0, max = 360, decimals = 1, step = 1, mult = 0.01200192, help = "@i18n(api.MIXER_CONFIG.swash_pitch_limit)@" },
    { field = "swash_trim_0", type = "S16", apiVersion = 12.06, simResponse = {0, 0}, default = 0, min = -1000, max = 1000, decimals = 1, scale = 10, help = "@i18n(api.MIXER_CONFIG.swash_trim_0)@" },
    { field = "swash_trim_1", type = "S16", apiVersion = 12.06, simResponse = {0, 0}, default = 0, min = -1000, max = 1000, decimals = 1, scale = 10, help = "@i18n(api.MIXER_CONFIG.swash_trim_1)@" },
    { field = "swash_trim_2", type = "S16", apiVersion = 12.06, simResponse = {0, 0}, default = 0, min = -1000, max = 1000, decimals = 1, scale = 10, help = "@i18n(api.MIXER_CONFIG.swash_trim_2)@" },
    { field = "swash_tta_precomp", type = "U8", apiVersion = 12.06, simResponse = {0}, default = 0, min = 0, max = 250, help = "@i18n(api.MIXER_CONFIG.swash_tta_precomp)@" },
    { field = "swash_geo_correction", type = "S8", apiVersion = 12.07, simResponse = {0}, default = 0, min = -250, max = 250, decimals = 1, scale = 5, step = 2, help = "@i18n(api.MIXER_CONFIG.swash_geo_correction)@" },
    { field = "collective_tilt_correction_pos", type = "S8", apiVersion = 12.08, simResponse = {0}, default = 0, min = -100, max = 100, help = "@i18n(api.MIXER_CONFIG.collective_tilt_correction_pos)@" },
    { field = "collective_tilt_correction_neg", type = "S8", apiVersion = 12.08, simResponse = {10}, default = 10, min = -100, max = 100, help = "@i18n(api.MIXER_CONFIG.collective_tilt_correction_neg)@" },
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

return {read = read, write = write, readComplete = readComplete, writeComplete = writeComplete, readValue = readValue, setValue = setValue, resetWriteStatus = resetWriteStatus, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data, setUUID = setUUID, setTimeout = setTimeout}
