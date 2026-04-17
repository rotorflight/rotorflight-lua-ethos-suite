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

local API_NAME = "BATTERY_INI"
local INI_FILE = "SCRIPTS:/" .. rfsuite.config.preferences .. "/models/" .. rfsuite.session.mcu_id .. ".ini"
local INI_SECTION = "battery"

local ini = rfsuite.ini
local tonumber = tonumber
local pairs = pairs
local math_floor = math.floor

local offOn = {"@i18n(api.BATTERY_INI.tbl_off)@", "@i18n(api.BATTERY_INI.tbl_on)@"}
local alertTypes = {"@i18n(api.BATTERY_INI.alert_off)@", "@i18n(api.BATTERY_INI.alert_bec)@", "@i18n(api.BATTERY_INI.alert_rxbatt)@"}
local modelTypes = {"@i18n(api.BATTERY_INI.tbl_auto)@", "@i18n(api.BATTERY_INI.tbl_electric)@", "@i18n(api.BATTERY_INI.tbl_nitro)@"}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos, offset, xvals
local FIELD_SPEC = {
    {"smartfuel_model_type", "U8", 0, 2, 0, nil, nil, nil, nil, nil, modelTypes, -1},
    {"smartfuel_source", "U8", 0, 1, 0, nil, nil, nil, nil, nil, offOn, -1},
    {"stabilize_delay", "U16", 0, 10000, 1500, "s", 1, 1000, 1},
    {"stable_window", "U16", 0, 100, 15, "V", 2, 100, 1},
    {"voltage_fall_limit", "U16", 0, 100, 5, "V/s", 2, 100, 1},
    {"fuel_drop_rate", "U16", 0, 500, 10, "%/s", 1, 10, 1},
    {"sag_multiplier_percent", "U16", 0, 200, 70, "x", 2, 100, 1},
    {"alert_type", "U8", 0, 2, 0, nil, nil, nil, nil, nil, alertTypes, -1},
    {"becalertvalue", "U8", 30, 140, 6.5, "V", 1, 10, 1},
    {"rxalertvalue", "U8", 30, 140, 7.5, "V", 1, 10, 1},
    {"flighttime", "U8", 0, 3600, 300, "s", nil, nil, 1}
}

local READ_STRUCT = select(1, core.buildStructure(FIELD_SPEC))
local FIELD_METADATA = {}

for _, entry in ipairs(READ_STRUCT) do
    FIELD_METADATA[entry.field] = entry
end

local function normalizeScaledINIValue(entry, value)
    local numeric = tonumber(value)
    if numeric == nil then
        return nil
    end

    local max = entry and entry.max or nil
    local scale = entry and entry.scale or nil

    -- Recover gracefully if a scaled field was accidentally persisted with its
    -- transport scaling applied one or more extra times.
    if scale and scale > 1 and max ~= nil and numeric > max then
        local guard = 0
        while numeric > max and guard < 4 do
            numeric = numeric / scale
            guard = guard + 1
        end
    end

    return numeric
end

local function loadParsedFromINI()
    local tbl = ini.load_ini_file(INI_FILE) or {}
    local parsed = {}

    for _, entry in ipairs(READ_STRUCT) do
        local raw = ini.getvalue(tbl, INI_SECTION, entry.field)
        if raw == nil and entry.field == "smartfuel_source" then
            raw = ini.getvalue(tbl, INI_SECTION, "calc_local")
        elseif raw == nil and entry.field == "sag_multiplier_percent" then
            local legacyRaw = ini.getvalue(tbl, INI_SECTION, "sag_multiplier")
            if legacyRaw ~= nil then
                raw = tonumber(legacyRaw) * 100
            end
        end

        if raw ~= nil then
            local normalized = normalizeScaledINIValue(entry, raw)
            if entry.field == "becalertvalue" or entry.field == "rxalertvalue" then
                parsed[entry.field] = (normalized or tonumber(raw)) * 10
            else
                parsed[entry.field] = normalized
            end
        elseif entry.default ~= nil then
            if entry.field == "becalertvalue" or entry.field == "rxalertvalue" then
                parsed[entry.field] = entry.default * 10
            else
                parsed[entry.field] = entry.default
            end
        else
            parsed[entry.field] = 0
        end
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
        local parsed = loadParsedFromINI()
        updateStateData(state, parsed)
        state.mspWriteComplete = false
        emitComplete(nil, parsed)
        return true
    end,
    customWrite = function(_, state, emitComplete, emitError)
        local msg = "@i18n(app.modules.profile_select.save_prompt_local)@"
        rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))

        local tbl = ini.load_ini_file(INI_FILE) or {}

        for k, v in pairs(state.payloadData) do
            local entry = FIELD_METADATA[k]
            if entry and entry.scale then
                v = math_floor(v * entry.scale + 0.5)
            end
            if k == "smartfuel_source" or k == "smartfuel_model_type" or k == "alert_type" then
                v = math_floor(v)
            end

            ini.setvalue(tbl, INI_SECTION, k, v)
            if k == "smartfuel_source" then
                ini.setvalue(tbl, INI_SECTION, "calc_local", v)
            elseif k == "sag_multiplier_percent" then
                ini.setvalue(tbl, INI_SECTION, "sag_multiplier", v / 100)
            end

            if rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[INI_SECTION] then
                rfsuite.session.modelPreferences[INI_SECTION][k] = v
                if k == "smartfuel_source" then
                    rfsuite.session.modelPreferences[INI_SECTION].calc_local = v
                elseif k == "sag_multiplier_percent" then
                    rfsuite.session.modelPreferences[INI_SECTION].sag_multiplier = v / 100
                end
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
