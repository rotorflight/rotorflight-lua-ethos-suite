--[[
 * Copyright (C) Rotorflight Project
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0/en.html
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * Note: Some icons have been sourced from https://www.flaticon.com/
]]--

local config = {}
local THEME_DEFAULTS = {
    v_min        = 7.0,      -- 2S x 3.5V, safe default for nitro receiver packs
    v_max        = 8.4,      -- 2S x 4.2V, max charge for 2S Li-Ion/LiPo RX
}

local function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

local function getPref(key)
    return rfsuite.widgets.dashboard.getPreference(key)
end

local function setPref(key, value)
    rfsuite.widgets.dashboard.savePreference(key, value)
end

local formFields = {}
local prevConnectedState = nil

local function isTelemetryConnected()
    return rfsuite and rfsuite.session and rfsuite.session.isConnected and rfsuite.session.mcu_id and rfsuite.preferences
end

local function configure()
    for k, v in pairs(THEME_DEFAULTS) do
        local val = tonumber(getPref(k))
        config[k] = val or v
    end

    -- VOLTAGE PANEL (Receiver battery for Nitro)
    local voltage_panel = form.addExpansionPanel("Voltage")
    voltage_panel:open(false)
    local voltage_min_line = voltage_panel:addLine("Min")
    formFields[#formFields + 1] = form.addNumberField(voltage_min_line, nil, 50, 140,
        function()
            local v = config.v_min or THEME_DEFAULTS.v_min
            return math.floor((v * 10) + 0.5)
        end,
        function(val)
            local min_val = val / 10
            config.v_min = clamp(min_val, 5, config.v_max - 0.1)
            setPref("v_min", config.v_min)
        end)
    formFields[#formFields]:decimals(1)
    formFields[#formFields]:suffix("V")

    local voltage_max_line = voltage_panel:addLine("Max")
    formFields[#formFields + 1] = form.addNumberField(voltage_max_line, nil, 50, 140,
        function()
            local v = config.v_max or THEME_DEFAULTS.v_max
            return math.floor((v * 10) + 0.5)
        end,
        function(val)
            local max_val = val / 10
            config.v_max = clamp(max_val, config.v_min + 0.1, 14)
            setPref("v_max", config.v_max)
        end)
    formFields[#formFields]:decimals(1)
    formFields[#formFields]:suffix("V")

    -- FLIGHTS PANEL
    local flights_panel = form.addExpansionPanel("Flights")
    flights_panel:open(false)

    local ini = rfsuite and rfsuite.session and rfsuite.session.modelPreferences

    local function getFlightCount()
        if ini and rfsuite.ini then
            local v = rfsuite.ini.getvalue(ini, "general", "flightcount")
            return tonumber(v) or 0
        end
        return 0
    end
    local function setFlightCount(val)
        if ini and rfsuite.ini then
            rfsuite.ini.setvalue(ini, "general", "flightcount", tonumber(val) or 0)
            if rfsuite.session.modelPreferencesFile then
                rfsuite.ini.save_ini_file(rfsuite.session.modelPreferencesFile, ini)
            end
        end
    end

    local flights_line = flights_panel:addLine("Flight Count")
    formFields[#formFields + 1] = form.addNumberField(
        flights_line, nil, 0, 100000,
        getFlightCount,
        function(val) setFlightCount(val) end,
        1
    )

    -- Grey out everything if telemetry not connected
    local connected = isTelemetryConnected()
    for i, field in ipairs(formFields) do
        if field and field.enable then field:enable(connected) end
    end
    prevConnectedState = connected
end

local function write()
    for k, v in pairs(config) do
        setPref(k, v)
    end
end

-- Dynamic grey-out support: runs when telemetry connects/disconnects
local function wakeup()
    local connected = isTelemetryConnected()
    if connected ~= prevConnectedState then
        for i, field in ipairs(formFields) do
            if field and field.enable then field:enable(connected) end
        end
        prevConnectedState = connected
    end
end

return {
    configure = configure,
    write = write,
    wakeup = wakeup
}
