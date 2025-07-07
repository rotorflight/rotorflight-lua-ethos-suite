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
    v_min          = 18.0,      -- default: 6s x 3.0V
    v_max          = 25.2,      -- default: 6s x 4.2V
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

    -- VOLTAGE PANEL (override min/max V)
    local voltage_panel = form.addExpansionPanel(rfsuite.i18n.get("widgets.dashboard.voltage"))
    voltage_panel:open(true)

    local voltage_min_line = voltage_panel:addLine(rfsuite.i18n.get("widgets.dashboard.min"))
    formFields[#formFields + 1] = form.addNumberField(voltage_min_line, nil, 50, 650,
        function()
            local v = config.v_min or THEME_DEFAULTS.v_min
            return math.floor((v * 10) + 0.5)
        end,
        function(val)
            local min_val = val / 10
            config.v_min = clamp(min_val, 5, config.v_max - 0.1)
        end)
    formFields[#formFields]:decimals(1)
    formFields[#formFields]:suffix("V")

    local voltage_max_line = voltage_panel:addLine(rfsuite.i18n.get("widgets.dashboard.max"))
    formFields[#formFields + 1] = form.addNumberField(voltage_max_line, nil, 50, 650,
        function()
            local v = config.v_max or THEME_DEFAULTS.v_max
            return math.floor((v * 10) + 0.5)
        end,
        function(val)
            local max_val = val / 10
            config.v_max = clamp(max_val, config.v_min + 0.1, 65)
        end)
    formFields[#formFields]:decimals(1)
    formFields[#formFields]:suffix("V")

end

local function write()
    for k, v in pairs(config) do
        setPref(k, v)
    end
end


return {
    configure = configure,
    write = write,
}
