--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "FLIGHT_STATS_INI"
local INI_FILE = "SCRIPTS:/" .. rfsuite.config.preferences .. "/models/" .. rfsuite.session.mcu_id .. ".ini"
local INI_SECTION = "general"

local ini = rfsuite.ini
local mspModule = rfsuite.tasks.msp.api

local handlers = core.createHandlers()

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "flightcount",     type = "U32", simResponse = {0}, min = 0, max = 1000000000,                          help = "@i18n(api.FLIGHT_STATS_INI.flightcount)@" },
    { field = "lastflighttime",  type = "U32", simResponse = {0}, min = 0, max = 1000000000, unit = "s",                 help = "@i18n(api.FLIGHT_STATS_INI.lastflighttime)@" },
    { field = "totalflighttime", type = "U32", simResponse = {0}, min = 0, max = 1000000000, unit = "s",                 help = "@i18n(api.FLIGHT_STATS_INI.totalflighttime)@" },
}
-- LuaFormatter on

local READ_STRUCT, MIN_BYTES, SIM_RESP = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local mspData = nil
local mspWriteDone = false
local payloadData = {}

local function loadParsedFromINI()
    local tbl = ini.load_ini_file(INI_FILE) or {}
    local parsed = {}
    for _, entry in ipairs(MSP_API_STRUCTURE_READ_DATA) do parsed[entry.field] = ini.getvalue(tbl, INI_SECTION, entry.field) or entry.simResponse[1] or 0 end
    return parsed
end

local function read()
    local parsed = loadParsedFromINI()
    mspData = {parsed = parsed, structure = READ_STRUCT, buffer = parsed, positionmap = {}, other = {}, receivedBytesCount = #MSP_API_STRUCTURE_READ_DATA}
    mspWriteDone = false

    local cb = handlers.getCompleteHandler()
    if cb then cb(nil, parsed) end
end

local function write()

    local msg = "@i18n(app.modules.profile_select.save_prompt_local)@"
    rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))

    local tbl = ini.load_ini_file(INI_FILE) or {}
    tbl.general = tbl.general or {}
    for k, v in pairs(payloadData) do
        v = math.floor(v)
        ini.setvalue(tbl, INI_SECTION, k, v)

        if rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[INI_SECTION] then rfsuite.session.modelPreferences[INI_SECTION][k] = v end
    end
    local ok, err = ini.save_ini_file(INI_FILE, tbl)
    if not ok then
        local cbErr = handlers.getErrorHandler()
        if cbErr then cbErr(err or "Failed to save INI: " .. INI_FILE) end
        return
    end
    mspWriteDone = true

    local parsed = loadParsedFromINI()
    mspData = {parsed = parsed, structure = READ_STRUCT, buffer = parsed, positionmap = {}, other = {}, receivedBytesCount = #MSP_API_STRUCTURE_READ_DATA}

    local cb = handlers.getCompleteHandler()
    if cb then cb(nil, parsed) end
    payloadData = {}
end

local function readComplete() return mspData ~= nil end
local function writeComplete() return mspWriteDone end
local function readValue(field) return mspData and mspData.parsed[field] end
local function setValue(field, v) payloadData[field] = v end
local function resetWriteStatus()
    mspWriteDone = false
    payloadData = {}
    mspData = nil
end
local function data() return mspData end

local function setRebuildOnWrite(rebuild) MSP_REBUILD_ON_WRITE = rebuild end

return {read = read, write = write, setRebuildOnWrite = setRebuildOnWrite, readComplete = readComplete, writeComplete = writeComplete, readValue = readValue, setValue = setValue, resetWriteStatus = resetWriteStatus, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data}
