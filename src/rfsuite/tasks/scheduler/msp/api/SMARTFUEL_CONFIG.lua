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

local API_NAME = "SMARTFUEL_CONFIG"
local MSP_API_CMD_READ = 0x3006
local MSP_API_CMD_WRITE = 0x3007

local sourceTable = {
    "CURRENT",
    "VOLTAGE"
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"smartfuel_source", "U8", 0, 1, 0, nil, nil, nil, nil, nil, sourceTable, -1},
    {"stabilize_delay", "U16", 0, 10000, 1500, "s", 1, 1000, 1},
    {"stable_window", "U16", 0, 100, 15, "V", 2, 100, 1},
    {"voltage_fall_limit", "U16", 0, 100, 5, "V/s", 2, 100, 1},
    {"fuel_drop_rate", "U16", 0, 500, 10, "%/s", 1, 10, 1},
    {"sag_multiplier_percent", "U16", 0, 200, 70, "x", 2, 100, 1}
}
local WRITE_STRUCTURE = select(1, core.buildStructure(FIELD_SPEC))

local function getRemoteSmartFuelSource()
    local page = rfsuite.app and rfsuite.app.Page
    local fields = page and page.apidata and page.apidata.formdata and page.apidata.formdata.fields

    for _, field in ipairs(fields or {}) do
        if field.apikey == "smartfuel_remote_source" then
            return tonumber(field.value) or 0
        end
    end

    -- Fall back to the session value maintained by preferences.postSave and
    -- smartfuel.postLoad so that writes from the smartfuel tuning page still
    -- produce the correct smartfuel_source even without the field on screen.
    local batteryConfig = rfsuite and rfsuite.session and rfsuite.session.batteryConfig
    if batteryConfig and batteryConfig.smartfuelRemoteSource ~= nil then
        return tonumber(batteryConfig.smartfuelRemoteSource)
    end

    return nil
end

local SIM_RESPONSE = core.simResponse({
    0,       -- smartfuel_source
    220, 5,  -- stabilize_delay
    15, 0,   -- stable_window
    5, 0,    -- voltage_fall_limit
    10, 0,   -- fuel_drop_rate
    70, 0    -- sag_multiplier_percent
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    minApiVersion = {12, 0, 10},
    fields = FIELD_SPEC,
    buildWritePayload = function(payloadData)
        local remoteSource = getRemoteSmartFuelSource()
        if remoteSource ~= nil then
            payloadData.smartfuel_source = remoteSource == 2 and 1 or 0
        end

        return core.buildFullPayload(API_NAME, payloadData, WRITE_STRUCTURE)
    end,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
