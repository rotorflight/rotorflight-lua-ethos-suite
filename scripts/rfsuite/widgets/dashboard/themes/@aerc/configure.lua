--[[
 * Copyright (C) Rotorflight Project
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
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
    rpm_min      = 0,
    rpm_max      = 3000,
    bec_min      = 3.0,
    bec_max      = 13.0,
    esctemp_warn = 90,
    esctemp_max  = 140,
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

local function configure()
    -- Defensive assignment for BEC fields (never <2 or >15)
    for k, v in pairs(THEME_DEFAULTS) do
        local val = tonumber(getPref(k))
        if k == "bec_min" or k == "bec_max" then
            if not val or val < 2 or val > 15 then
                config[k] = v
                setPref(k, v)
            else
                config[k] = val
            end
        else
            config[k] = val or v
        end
    end

    -- ==== RPM PANEL ====
    local rpm_panel = form.addExpansionPanel("Headspeed (RPM)")
    rpm_panel:open(false)
    local rpm_min_line = rpm_panel:addLine("Min")
    local rpm_min_field = form.addNumberField(rpm_min_line, nil, 0, 20000,
        function() return config.rpm_min end,
        function(val)
            config.rpm_min = clamp(tonumber(val) or THEME_DEFAULTS.rpm_min, 0, config.rpm_max-1)
            setPref("rpm_min", config.rpm_min)
        end,
        1)
    rpm_min_field:suffix("rpm")

    local rpm_max_line = rpm_panel:addLine("Max")
    local rpm_max_field = form.addNumberField(rpm_max_line, nil, 1, 20000,
        function() return config.rpm_max end,
        function(val)
            config.rpm_max = clamp(tonumber(val) or THEME_DEFAULTS.rpm_max, config.rpm_min+1, 20000)
            setPref("rpm_max", config.rpm_max)
        end,
        1)
    rpm_max_field:suffix("rpm")

    -- ==== BEC VOLTAGE PANEL (robust, integer workaround) ====
    local bec_panel = form.addExpansionPanel("BEC Voltage (V)")
    bec_panel:open(false)
    local bec_min_line = bec_panel:addLine("Min")
    local bec_min_field = form.addNumberField(bec_min_line, nil, 20, 150,
        function()
            local v = config.bec_min or THEME_DEFAULTS.bec_min
            return math.floor((v * 10) + 0.5)
        end,
        function(val)
            config.bec_min = val / 10
            setPref("bec_min", config.bec_min)
        end)
    bec_min_field:decimals(1)
    bec_min_field:suffix("V")

    local bec_max_line = bec_panel:addLine("Max")
    local bec_max_field = form.addNumberField(bec_max_line, nil, 20, 150,
        function()
            local v = config.bec_max or THEME_DEFAULTS.bec_max
            return math.floor((v * 10) + 0.5)
        end,
        function(val)
            config.bec_max = val / 10
            setPref("bec_max", config.bec_max)
        end)
    bec_max_field:decimals(1)
    bec_max_field:suffix("V")

    -- ==== ESC TEMP PANEL ====
    local esc_panel = form.addExpansionPanel("ESC Temp (°C)")
    esc_panel:open(false)
    local esc_warn_line = esc_panel:addLine("Warning")
    local esc_warn_field = form.addNumberField(esc_warn_line, nil, 0, 200,
        function()
            return config.esctemp_warn
        end,
        function(val)
            config.esctemp_warn = clamp(tonumber(val) or THEME_DEFAULTS.esctemp_warn, 0, 200)
            setPref("esctemp_warn", config.esctemp_warn)
        end,
        1)
    esc_warn_field:suffix("°C")

    local esc_max_line = esc_panel:addLine("Max")
    local esc_max_field = form.addNumberField(esc_max_line, nil, 1, 200,
        function() return config.esctemp_max end,
        function(val)
            config.esctemp_max = clamp(tonumber(val) or THEME_DEFAULTS.esctemp_max, config.esctemp_warn+1, 200)
            setPref("esctemp_max", config.esctemp_max)
        end,
        1)
    esc_max_field:suffix("°C")
end

local function write()
    for k, v in pairs(config) do
        setPref(k, v)
    end
end

return {
    configure = configure,
    write = write,
    wakeup = function() end
}
