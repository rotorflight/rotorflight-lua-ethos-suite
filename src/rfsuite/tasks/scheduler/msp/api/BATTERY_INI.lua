--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "BATTERY_INI"
local INI_FILE = "SCRIPTS:/" .. rfsuite.config.preferences .. "/models/" .. rfsuite.session.mcu_id .. ".ini"
local INI_SECTION = "battery"

local ini = rfsuite.ini
local mspModule = rfsuite.tasks.msp.api

local math_floor = math.floor
local tonumber = tonumber
local ipairs = ipairs

local handlers = core.createHandlers()

local offOn = {"@i18n(api.BATTERY_INI.tbl_off)@", "@i18n(api.BATTERY_INI.tbl_on)@"}
local alertTypes = {"@i18n(api.BATTERY_INI.alert_off)@", "@i18n(api.BATTERY_INI.alert_bec)@", "@i18n(api.BATTERY_INI.alert_rxbatt)@"}

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "calc_local",     type = "U8", simResponse = {0}, tableIdxInc = -1, table = offOn,      help = "@i18n(api.BATTERY_INI.calcfuel_local)@" },
    { field = "sag_multiplier", type = "U8", simResponse = {0}, decimals = 1, default = 0.5, min = 0, max = 10, help = "@i18n(api.BATTERY_INI.sag_multiplier)@" },
    { field = "alert_type",     type = "U8", simResponse = {0}, tableIdxInc = -1, table = alertTypes, default = 0, min = 0, max = 2, help = "@i18n(api.BATTERY_INI.alert_type)@" },
    { field = "becalertvalue",  type = "U8", simResponse = {0}, min = 30, decimals = 1, scale = 10, max = 140, unit = "V", default = 6.5, help = "@i18n(api.BATTERY_INI.becalertvalue)@" },
    { field = "rxalertvalue",   type = "U8", simResponse = {0}, min = 30, decimals = 1, scale = 10, max = 140, unit = "V", default = 7.5, help = "@i18n(api.BATTERY_INI.rxalertvalue)@" },
    { field = "flighttime",     type = "U8", simResponse = {0}, min = 0, max = 3600, unit = "s", default = 300, help = "@i18n(api.BATTERY_INI.flighttime)@" },
}
-- LuaFormatter on

local READ_STRUCT, MIN_BYTES, SIM_RESP = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local mspData = nil
local mspWriteDone = false
local payloadData = {}

local function loadParsedFromINI()
    local tbl = ini.load_ini_file(INI_FILE) or {}
    local parsed = {}
    for _, entry in ipairs(MSP_API_STRUCTURE_READ_DATA) do
        local raw = ini.getvalue(tbl, INI_SECTION, entry.field)
        if raw ~= nil then
            if entry.field == "becalertvalue" or entry.field == "rxalertvalue" then
                parsed[entry.field] = tonumber(raw) * 10
            else
                parsed[entry.field] = tonumber(raw)
            end
        else
            parsed[entry.field] = entry.default and ((entry.field == "becalertvalue" or entry.field == "rxalertvalue") and (entry.default * 10) or entry.default)
        end
    end
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

    for k, v in pairs(payloadData) do
        if k == "calc_local" then v = math_floor(v) end

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
