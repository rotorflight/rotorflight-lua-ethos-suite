--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then
    msp.apicore = core
end

local API_NAME = "FLIGHT_STATS_INI"
local INI_FILE = "SCRIPTS:/" .. rfsuite.config.preferences .. "/models/" .. rfsuite.session.mcu_id .. ".ini"
local INI_SECTION = "general"

local ini = rfsuite.ini
local tonumber = tonumber
local pairs = pairs

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos, offset, xvals
local FIELD_SPEC = {
    {"flightcount", "U32", 0, 1000000000, 0},
    {"lastflighttime", "U32", 0, 1000000000, 0, "s"},
    {"totalflighttime", "U32", 0, 1000000000, 0, "s"}
}

local READ_STRUCT = select(1, core.buildStructure(FIELD_SPEC))

local function loadParsedFromINI()
    local tbl = ini.load_ini_file(INI_FILE) or {}
    local parsed = {}

    for _, entry in ipairs(READ_STRUCT) do
        parsed[entry.field] = tonumber(ini.getvalue(tbl, INI_SECTION, entry.field)) or entry.default or 0
    end

    return parsed
end

local function updateStateData(state, parsed)
    state.mspData = {
        parsed = parsed,
        structure = READ_STRUCT,
        buffer = parsed,
        positionmap = {},
        other = {},
        receivedBytesCount = #READ_STRUCT
    }
end

return core.createCustomAPI({
    name = API_NAME,
    readStructure = READ_STRUCT,
    writeStructure = READ_STRUCT,
    customRead = function(state, emitComplete)
        updateStateData(state, loadParsedFromINI())
        state.mspWriteComplete = false
        emitComplete(nil, state.mspData.parsed)
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
        updateStateData(state, loadParsedFromINI())
        emitComplete(nil, state.mspData.parsed)
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
