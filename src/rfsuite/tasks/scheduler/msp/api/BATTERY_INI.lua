--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then msp.apicore = core end
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local API_NAME = "BATTERY_INI"
local INI_FILE = "SCRIPTS:/" .. rfsuite.config.preferences .. "/models/" .. rfsuite.session.mcu_id .. ".ini"
local INI_SECTION = "battery"

local ini = rfsuite.ini
local tonumber = tonumber
local ipairs = ipairs

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

local READ_STRUCT = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

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

return factory.create({
    name = API_NAME,
    customRead = function(state, emitComplete)
        local parsed = loadParsedFromINI()
        state.mspData = {
            parsed = parsed,
            structure = READ_STRUCT,
            buffer = parsed,
            positionmap = {},
            other = {},
            receivedBytesCount = #MSP_API_STRUCTURE_READ_DATA
        }
        state.mspWriteComplete = false
        emitComplete(nil, parsed)
        return true
    end,
    customWrite = function(_, state, emitComplete, emitError)
        local msg = "@i18n(app.modules.profile_select.save_prompt_local)@"
        rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))

        local tbl = ini.load_ini_file(INI_FILE) or {}

        for k, v in pairs(state.payloadData) do
            if k == "calc_local" then v = math.floor(v) end
            ini.setvalue(tbl, INI_SECTION, k, v)
            if rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[INI_SECTION] then
                rfsuite.session.modelPreferences[INI_SECTION][k] = v
            end
        end

        local ok, err = ini.save_ini_file(INI_FILE, tbl)
        if not ok then
            emitError(nil, err or ("Failed to save INI: " .. INI_FILE))
            return false, err
        end

        state.mspWriteComplete = true
        local parsed = loadParsedFromINI()
        state.mspData = {
            parsed = parsed,
            structure = READ_STRUCT,
            buffer = parsed,
            positionmap = {},
            other = {},
            receivedBytesCount = #MSP_API_STRUCTURE_READ_DATA
        }

        emitComplete(nil, parsed)
        state.payloadData = {}
        return true
    end,
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end,
    methods = {
        resetWriteStatus = function(state)
            state.mspWriteComplete = false
            state.payloadData = {}
            state.mspData = nil
        end
    }
})
