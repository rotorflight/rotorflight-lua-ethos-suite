--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local features = {}

local defaults = {
    dashboard = true,
    toolbox = false,
    activelook = false
}

local prefKeys = {
    dashboard = "feature_dashboard",
    toolbox = "feature_toolbox",
    activelook = "feature_activelook"
}

local function asBool(value, default)
    if value == nil then return default end
    if value == true or value == "true" or value == 1 or value == "1" then return true end
    if value == false or value == "false" or value == 0 or value == "0" then return false end
    return default
end

function features.isEnabled(name, prefs)
    local key = prefKeys[name]
    if not key then return true end

    local general = prefs and prefs.general
    return asBool(general and general[key], defaults[name] == true)
end

function features.prefKey(name)
    return prefKeys[name]
end

return features
