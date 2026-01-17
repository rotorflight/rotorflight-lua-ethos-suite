--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local sync = {}

local fetchData = false
local saveData  = false
local isComplete = false

local FBL_FEATURES = {}

local function copyTable(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do dst[k] = v end
    return dst
end

local function saveToEeprom()
    local mspEepromWrite = {
        command = 250,
        simulatorResponse = {},
        processReply = function()
            if rfsuite.utils and rfsuite.utils.log then
                rfsuite.utils.log("EEPROM write command sent", "info")
            end
        end
    }
    rfsuite.tasks.msp.mspQueue:add(mspEepromWrite)
end

local function bitmask(bit)
    -- Ethos Lua in RF suite generally supports bitwise ops; keep it simple.
    return (1 << bit)
end

function sync.wakeup()

    -- no api version info yet
    if rfsuite.session.apiVersion == nil then return end

    -- avoid clashing with other MSP work
    if rfsuite.session.mspBusy then return end

    -- fetch data from FC
    if fetchData == false then
        local API = rfsuite.tasks.msp.api.load("FEATURE_CONFIG")
        API.setUUID("featureconfig-telemetry-enable")
        API.setCompleteHandler(function(self, buf)
            FBL_FEATURES = copyTable(API.data().parsed) or {}

            -- proceed to save/decide phase
            saveData = true
        end)
        API.read()

        fetchData = true
    end

    if saveData == true then
        local API = rfsuite.tasks.msp.api.load("FEATURE_CONFIG")
        API.setRebuildOnWrite(true)

        -- seed ALL remote values first (prevents clobbering anything we don't care about)
        for k, v in pairs(FBL_FEATURES or {}) do
            API.setValue(k, v)
        end

        local enabled = tonumber(FBL_FEATURES.enabledFeatures) or 0
        local TELEMETRY_BIT = 10
        local mask = bitmask(TELEMETRY_BIT)

        if (enabled & mask) ~= 0 then
            if rfsuite.utils and rfsuite.utils.log then
                rfsuite.utils.log("Telemetry feature already enabled", "info")
            end
            isComplete = true
        else
            local newEnabled = (enabled | mask)
            API.setValue("enabledFeatures", newEnabled)

            API.setCompleteHandler(function()
                if rfsuite.utils and rfsuite.utils.log then
                    rfsuite.utils.log("Telemetry feature enabled (FEATURE_CONFIG)", "info")
                    rfsuite.utils.log("Telemetry feature enabled (FEATURE_CONFIG)", "connect")
                end
                saveToEeprom()
                isComplete = true
            end)

            API.setErrorHandler(function()
                if rfsuite.utils and rfsuite.utils.log then
                    rfsuite.utils.log("Failed to enable telemetry feature (FEATURE_CONFIG)", "info")
                end
                -- don't loop forever; mark complete to avoid hammering
                isComplete = true
            end)

            API.write()
        end

        saveData = false
    end
end

function sync.reset()
    fetchData = false
    saveData = false
    isComplete = false
    FBL_FEATURES = {}
end

function sync.isComplete()
    return isComplete
end

return sync
