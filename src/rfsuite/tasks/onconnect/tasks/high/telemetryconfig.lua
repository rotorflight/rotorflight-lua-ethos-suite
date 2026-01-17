--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local telemetryconfig = {}

local mspCallMade = false
local autoWriteInProgress = false

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

local function getDefaultSensorIds()
    local defaults = {}
    local i = 1
    local listSensors = rfsuite.tasks and rfsuite.tasks.telemetry and rfsuite.tasks.telemetry.listSensors
    local sensors = type(listSensors) == "function" and listSensors() or {}

    for _, sensor in pairs(sensors or {}) do
        if sensor and sensor.mandatory == true and sensor.set_telemetry_sensors ~= nil then
            defaults[i] = sensor.set_telemetry_sensors
            i = i + 1
        end
    end

    return defaults
end

local function slotsToSet(slots)
    local set = {}
    for _, v in ipairs(slots or {}) do
        v = tonumber(v) or 0
        if v ~= 0 then set[v] = true end
    end
    return set
end

local function allSlotsZero(slots)
    for i = 1, 40 do
        if (tonumber(slots[i]) or 0) ~= 0 then return false end
    end
    return true
end

local function mergeSlotsPreserveExisting(slots, defaults)
    local present = slotsToSet(slots)
    local merged = {}

    -- keep existing order (non-zero)
    for i = 1, 40 do
        local v = tonumber(slots[i]) or 0
        if v ~= 0 then merged[#merged + 1] = v end
    end

    -- append missing defaults
    for _, id in ipairs(defaults or {}) do
        id = tonumber(id) or 0
        if id ~= 0 and not present[id] then
            merged[#merged + 1] = id
            present[id] = true
        end
    end

    -- pad / clamp to 40
    local out = {}
    for i = 1, 40 do out[i] = merged[i] or 0 end
    return out, (#merged <= 40)
end

local function defaultsAppliedFlagKey()
    local mcu = rfsuite.session and rfsuite.session.mcu_id or "unknown"
    local ver = rfsuite.session and rfsuite.session.apiVersion or "unknown"
    ver = tostring(ver):gsub("%.", "_")
    return "telemetry_defaults_applied_" .. tostring(mcu) .. "_" .. tostring(ver)
end

local function getDefaultsAppliedFlag()
    local prefs = rfsuite.session and rfsuite.session.modelPreferences
    if not prefs or not rfsuite.ini or not rfsuite.ini.getvalue then return nil end
    return rfsuite.ini.getvalue(prefs, "general", defaultsAppliedFlagKey())
end

local function setDefaultsAppliedFlag()
    local prefs = rfsuite.session and rfsuite.session.modelPreferences
    if not prefs or not rfsuite.ini or not rfsuite.ini.setvalue then return end

    rfsuite.ini.setvalue(prefs, "general", defaultsAppliedFlagKey(), "1")

    if rfsuite.ini.save_ini_file and rfsuite.session and rfsuite.session.modelPreferencesFile then
        rfsuite.ini.save_ini_file(rfsuite.session.modelPreferencesFile, prefs)
    end
end

function telemetryconfig.wakeup()

    if rfsuite.session.apiVersion == nil then return end

    -- telemetry slots were added in 12.08
    if rfsuite.utils and rfsuite.utils.apiVersionCompare and rfsuite.utils.apiVersionCompare("<", "12.08") then
        return
    end

    if rfsuite.session.mspBusy then return end

    if (rfsuite.session.telemetryConfig == nil) and (mspCallMade == false) then
        mspCallMade = true
        local API = rfsuite.tasks.msp.api.load("TELEMETRY_CONFIG")
        API.setCompleteHandler(function(self, buf)
            local data = API.data().parsed

            local slots = {}
            for i = 1, 40 do
                local key = "telem_sensor_slot_" .. i
                slots[i] = tonumber(data[key]) or 0
            end

            rfsuite.session.telemetryConfig = slots

            -- Auto-apply defaults once (first-run / fresh config):
            --  - only if all slots are 0 (safe)
            --  - only if we have not already applied defaults for this FC+apiVersion
            if not autoWriteInProgress then
                local appliedFlag = getDefaultsAppliedFlag()
                if (appliedFlag == nil or tostring(appliedFlag) ~= "1") and allSlotsZero(slots) then
                    local defaults = getDefaultSensorIds()
                    local newSlots, fits = mergeSlotsPreserveExisting(slots, defaults)

                    if fits then
                        autoWriteInProgress = true

                        -- Use the raw buffer we just read (so we preserve other TELEMETRY_CONFIG fields)
                        local buffer = (API.data() and API.data().buffer) or buf

                        if type(buffer) == "table" and #buffer >= 52 then
                            -- slots live at indices 13..52 (40 bytes)
                            for i = 1, 40 do
                                buffer[12 + i] = tonumber(newSlots[i]) or 0
                            end

                            local WRITEAPI = rfsuite.tasks.msp.api.load("TELEMETRY_CONFIG")
                            WRITEAPI.setUUID("telemetryconfig-auto-defaults")
                            WRITEAPI.setCompleteHandler(function()
                                rfsuite.session.telemetryConfig = newSlots

                                if rfsuite.utils and rfsuite.utils.log then
                                    rfsuite.utils.log("Telemetry defaults applied (auto)", "info")
                                end

                                setDefaultsAppliedFlag()
                                saveToEeprom()
                                autoWriteInProgress = false
                            end)
                            WRITEAPI.setErrorHandler(function()
                                if rfsuite.utils and rfsuite.utils.log then
                                    rfsuite.utils.log("Telemetry defaults auto-apply failed", "info")
                                end
                                autoWriteInProgress = false
                            end)

                            WRITEAPI.write(buffer)

                            -- We don't log the slot list here; the write+eeprom logs are enough.
                            return
                        else
                            if rfsuite.utils and rfsuite.utils.log then
                                rfsuite.utils.log("Telemetry defaults not applied: invalid TELEMETRY_CONFIG buffer", "debug")
                            end
                        end
                    else
                        if rfsuite.utils and rfsuite.utils.log then
                            rfsuite.utils.log("Telemetry defaults not applied: not enough free slots", "info")
                        end
                    end
                end
            end

            local parts = {}
            for i, v in ipairs(slots) do 
                if v ~= 0 then 
                    parts[#parts + 1] = tostring(v) 
                end 
            end
            local slotsStr = table.concat(parts, ",")

            if rfsuite.utils and rfsuite.utils.log then 
                rfsuite.utils.log("Updated telemetry sensors: " .. slotsStr, "info") 
                rfsuite.utils.log("Updated telemetry sensors: " .. tostring(#parts) .. " of " .. tostring(#slots), "connect")
            end    
        end)
        API.setUUID("38163617-1496-4886-8b81-6a1dd6d7ed81")
        API.read()
    end

end

function telemetryconfig.reset()
    rfsuite.session.telemetryConfig = nil
    mspCallMade = false
    autoWriteInProgress = false
end

function telemetryconfig.isComplete() if rfsuite.session.telemetryConfig ~= nil then return true end end

return telemetryconfig
