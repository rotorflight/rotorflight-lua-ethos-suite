--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local floor = math.floor
local pairs = pairs
local tonumber = tonumber

local config = {}
local THEME_DEFAULTS = {v_min = 18.0, v_max = 25.2}

local function clamp(val, min, max)
    if val < min then
        return min
    end
    if val > max then
        return max
    end
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
end

local function write()
    for k, v in pairs(config) do
        setPref(k, v)
    end
end

return {configure = configure, write = write}
