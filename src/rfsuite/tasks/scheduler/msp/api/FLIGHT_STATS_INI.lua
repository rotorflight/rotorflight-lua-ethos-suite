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

local API_NAME = "FLIGHT_STATS_INI"
local INI_FILE = "SCRIPTS:/" .. rfsuite.config.preferences .. "/models/" .. rfsuite.session.mcu_id .. ".ini"
local INI_SECTION = "general"

local ini = rfsuite.ini
local tonumber = tonumber
local ipairs = ipairs
local pairs = pairs

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "flightcount",     type = "U32", simResponse = {0}, min = 0, max = 1000000000},
    { field = "lastflighttime",  type = "U32", simResponse = {0}, min = 0, max = 1000000000, unit = "s"},
    { field = "totalflighttime", type = "U32", simResponse = {0}, min = 0, max = 1000000000, unit = "s"},
}
-- LuaFormatter on

local READ_STRUCT = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local function loadParsedFromINI()
    local tbl = ini.load_ini_file(INI_FILE) or {}
    local parsed = {}
    for _, entry in ipairs(MSP_API_STRUCTURE_READ_DATA) do
        parsed[entry.field] = tonumber(ini.getvalue(tbl, INI_SECTION, entry.field)) or entry.simResponse[1] or 0
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
        tbl.general = tbl.general or {}

        for k, v in pairs(state.payloadData) do
            v = math.floor(v)
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
