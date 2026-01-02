--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html

  MIXER_INPUT_INDEXED
  - Uses MSP_MIXER_INPUTS (170) with optional 1-byte argument {idx}
    to fetch a single mixer input row (rate/min/max) at a time.
  - Aggregates multiple indexed reads into a single API completion
    so ui.requestPage() remains compatible.
]]--

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api_core.lua"))()

local API_NAME = "MIXER_INPUT_INDEXED"
local MSP_API_CMD_READ = 170
local MSP_API_CMD_WRITE = 171
local MSP_REBUILD_ON_WRITE = true

-- --------------------------------------------------------------------
-- IMPORTANT:
-- We keep the FULL structure metadata so ui.lua can inject attributes
-- (tableEthos, defaults, min/max, help, etc) exactly like MIXER_INPUT.lua.
-- --------------------------------------------------------------------

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {

    -- 0: MIXER_IN_NONE
    { field = "rate_none", type = "U16", apiVersion = 12.06, simResponse = { 0, 0 } },
    { field = "min_none",  type = "U16", apiVersion = 12.06, simResponse = { 0, 0 } },
    { field = "max_none",  type = "U16", apiVersion = 12.06, simResponse = { 0, 0 } },

    -- 1: MIXER_IN_STABILIZED_ROLL
    { field = "rate_stabilized_roll", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 }, tableEthos = {[1] = { "@i18n(api.MIXER_INPUT.tbl_normal)@",   250 },[2] = { "@i18n(api.MIXER_INPUT.tbl_reversed)@", 65286 }}} ,
    { field = "min_stabilized_roll",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_stabilized_roll",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    -- 2: MIXER_IN_STABILIZED_PITCH
    { field = "rate_stabilized_pitch", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_stabilized_pitch",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_stabilized_pitch",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    -- 3: MIXER_IN_STABILIZED_YAW
    { field = "rate_stabilized_yaw", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
    { field = "min_stabilized_yaw",  type = "U16", apiVersion = 12.06, simResponse = { 30, 251 } },
    { field = "max_stabilized_yaw",  type = "U16", apiVersion = 12.06, simResponse = { 226, 4 } },

    -- 4: MIXER_IN_STABILIZED_COLLECTIVE
    { field = "rate_stabilized_collective", type = "U16", apiVersion = 12.06, simResponse = { 250, 0 } },
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

local MSP_API_STRUCTURE_META, _, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

-- Indexed reply structure: one row only
local MSP_API_STRUCTURE_READ_IDX = {
    { field = "rate", type = "U16" },
    { field = "min",  type = "U16" },
    { field = "max",  type = "U16" },
}
local MSP_MIN_BYTES_IDX = 6

-- Write structure (same as MIXER_INPUT.lua)
local MSP_API_STRUCTURE_WRITE = {
    { field = "index", type = "U8" },
    { field = "rate",  type = "U16" },
    { field = "min",   type = "U16" },
    { field = "max",   type = "U16" },
}

-- Build index->fieldname maps from the metadata structure (3 fields per index)
local rateFieldByIdx, minFieldByIdx, maxFieldByIdx = {}, {}, {}
do
    local idx = 0
    for i = 1, #MSP_API_STRUCTURE_META, 3 do
        local a = MSP_API_STRUCTURE_META[i]
        local b = MSP_API_STRUCTURE_META[i + 1]
        local c = MSP_API_STRUCTURE_META[i + 2]
        if a and b and c then
            rateFieldByIdx[idx] = a.field
            minFieldByIdx[idx]  = b.field
            maxFieldByIdx[idx]  = c.field
            idx = idx + 1
        end
    end
end

local mspData = nil
local mspWriteComplete = false
local payloadData = {}
local handlers = core.createHandlers()

local MSP_API_UUID
local MSP_API_MSG_TIMEOUT
local lastWriteUUID = nil
local writeDoneRegistry = setmetatable({}, { __mode = "kv" })

-- Indexed read state
local pending = nil           -- array of idx
local pendingPos = 1
local pendingTotal = 0

local function ensureMspData()
    if not mspData then
        mspData = {
            parsed = {},
            buffer = {},            -- we keep the last buffer only (good enough for diagnostics)
            structure = MSP_API_STRUCTURE_META,
            positionmap = {},       -- not meaningful for aggregated data; keep empty
            processed = {},
            other = {},
            receivedBytesCount = 0
        }
    end
end

local function callCompleteOnce(self, buf)
    local getComplete = self.getCompleteHandler
    if getComplete then
        local complete = getComplete()
        if complete then complete(self, buf) end
    end
end

local function callError(self, buf)
    local getError = self.getErrorHandler
    if getError then
        local err = getError()
        if err then err(self, buf) end
    end
end

-- Determine which mixer indices are referenced on the current page for this API module
local function collectNeededIndicesFromPage()
    local app = rfsuite.app
    local out = {}
    local seen = {}

    if not (app and app.Page and app.Page.apidata and app.Page.apidata.formdata and app.Page.apidata.formdata.fields) then
        return out
    end

    for _, f in ipairs(app.Page.apidata.formdata.fields) do
        if f and type(f.api) == "string" then
            local apiName, fieldName = f.api:match("^([^:]+):(.+)$")
            if apiName == API_NAME and fieldName then
                -- Find idx by scanning our prebuilt maps (small table; fast enough)
                -- (Alternative: build reverse map once; but this keeps it simple.)
                for idx, rf in pairs(rateFieldByIdx) do
                    if rf == fieldName or minFieldByIdx[idx] == fieldName or maxFieldByIdx[idx] == fieldName then
                        if not seen[idx] then
                            seen[idx] = true
                            out[#out + 1] = idx
                        end
                        break
                    end
                end
            end
        end
    end

    table.sort(out)
    return out
end

local function queueNextIndexRead()
    if not pending or pendingPos > pendingTotal then
        -- done
        ensureMspData()
        callCompleteOnce({ getCompleteHandler = handlers.getCompleteHandler }, mspData.buffer or {})
        return
    end

    local idx = pending[pendingPos]
    pendingPos = pendingPos + 1

    local message = {
        command = MSP_API_CMD_READ,
        payload = { idx }, -- 1-byte arg
        structure = MSP_API_STRUCTURE_READ_IDX,
        minBytes = MSP_MIN_BYTES_IDX,
        simulatorResponse = { 0, 0, 0, 0, 0, 0 },
        uuid = MSP_API_UUID,
        timeout = MSP_API_MSG_TIMEOUT,
        getCompleteHandler = handlers.getCompleteHandler,
        getErrorHandler = handlers.getErrorHandler,
    }

    message.processReply = function(self, buf)
        -- Parse a single row
        core.parseMSPData(API_NAME, buf, MSP_API_STRUCTURE_READ_IDX, nil, nil, { chunked = false, completionCallback = function(result)
            ensureMspData()

            local rateKey = rateFieldByIdx[idx]
            local minKey  = minFieldByIdx[idx]
            local maxKey  = maxFieldByIdx[idx]

            if rateKey then mspData.parsed[rateKey] = result.parsed.rate end
            if minKey  then mspData.parsed[minKey]  = result.parsed.min  end
            if maxKey  then mspData.parsed[maxKey]  = result.parsed.max  end

            mspData.buffer = buf
            mspData.receivedBytesCount = (mspData.receivedBytesCount or 0) + (result.receivedBytesCount or 0)

            queueNextIndexRead()
        end })
    end

    message.errorHandler = function(self, buf)
        -- Bubble error up (ui.requestPage will retry/timeout as usual)
        callError(self, buf)
    end

    rfsuite.tasks.msp.mspQueue:add(message)
end

local function read()
    if MSP_API_CMD_READ == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_READ", "debug")
        return
    end

    ensureMspData()

    pending = collectNeededIndicesFromPage()
    pendingPos = 1
    pendingTotal = #pending

    -- If nothing on the page references us, complete immediately (keeps requestPage moving)
    if pendingTotal == 0 then
        callCompleteOnce({ getCompleteHandler = handlers.getCompleteHandler }, {})
        return
    end

    queueNextIndexRead()
end

local function write(suppliedPayload)
    if MSP_API_CMD_WRITE == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_WRITE", "debug")
        return
    end

    local payload = suppliedPayload or core.buildWritePayload(API_NAME, payloadData, MSP_API_STRUCTURE_WRITE, MSP_REBUILD_ON_WRITE)

    local uuid = MSP_API_UUID or (rfsuite.utils and rfsuite.utils.uuid and rfsuite.utils.uuid()) or tostring(os.clock())
    lastWriteUUID = uuid

    local message = {
        command = MSP_API_CMD_WRITE,
        payload = payload,
        processReply = function(self, buf)
            mspWriteComplete = true
            if self.uuid then writeDoneRegistry[self.uuid] = true end
            callCompleteOnce(self, buf)
        end,
        errorHandler = function(self, buf) callError(self, buf) end,
        simulatorResponse = {},
        uuid = uuid,
        timeout = MSP_API_MSG_TIMEOUT,
        getCompleteHandler = handlers.getCompleteHandler,
        getErrorHandler = handlers.getErrorHandler
    }

    rfsuite.tasks.msp.mspQueue:add(message)
end

local function readValue(fieldName)
    if mspData and mspData.parsed and mspData.parsed[fieldName] ~= nil then
        return mspData.parsed[fieldName]
    end
    return nil
end

local function setValue(fieldName, value) payloadData[fieldName] = value end

local function readComplete()
    -- For indexed module, completion means we’ve at least created mspData.
    return mspData ~= nil
end

local function writeComplete() return mspWriteComplete end
local function resetWriteStatus() mspWriteComplete = false end
local function data() return mspData end
local function setUUID(uuid) MSP_API_UUID = uuid end
local function setTimeout(timeout) MSP_API_MSG_TIMEOUT = timeout end

return {
    read = read,
    write = write,
    readComplete = readComplete,
    writeComplete = writeComplete,
    readValue = readValue,
    setValue = setValue,
    resetWriteStatus = resetWriteStatus,
    setCompleteHandler = handlers.setCompleteHandler,
    setErrorHandler = handlers.setErrorHandler,
    data = data,
    setUUID = setUUID,
    setTimeout = setTimeout
}
