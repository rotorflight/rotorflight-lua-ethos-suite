--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local common = {}

common.DEFAULT_LAYOUT = {
    preflight = {"governor", "armed", "flightmode", "off"},
    inflight = {"current", "voltage", "fuel", "timer"},
    postflight = {"current", "voltage", "fuel", "timer"}
}

common.SENSOR_KEYS = {
    "off",
    "flightmode",
    "timer",
    "governor",
    "armed",
    "temp_esc",
    "temp_mcu",
    "link",
    "fuel",
    "current",
    "voltage",
    "headspeed"
}

common.SENSOR_CHOICES = {
    {"Off", 1},
    {"Flight Mode", 2},
    {"Timer", 3},
    {"@i18n(sensors.governor)@", 4},
    {"Arm Status", 5},
    {"@i18n(sensors.esc_temp)@", 6},
    {"@i18n(sensors.mcu_temp)@", 7},
    {"@i18n(sensors.link)@", 8},
    {"@i18n(sensors.fuel)@", 9},
    {"@i18n(sensors.current)@", 10},
    {"@i18n(sensors.voltage)@", 11},
    {"@i18n(sensors.headspeed)@", 12}
}

common.LAYOUT_KEYS = {
    "two_top_one_bottom",
    "two_top_two_bottom",
    "one_centered",
    "one_top_two_bottom",
    "stacked_three"
}

common.LAYOUT_CHOICES = {
    {"Two Top + One Bottom", 1},
    {"Two Top + Two Bottom", 2},
    {"Single Centered", 3},
    {"One Top + Two Bottom", 4},
    {"Stacked Large + Large + Small", 5}
}

common.LAYOUT_ACTIVE = {
    two_top_one_bottom = {true, true, true, false},
    two_top_two_bottom = {true, true, true, true},
    one_centered = {true, false, false, false},
    one_top_two_bottom = {true, false, true, true},
    stacked_three = {true, true, true, false}
}

local function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

function common.keyToChoice(key)
    if type(key) == "number" then
        local idx = math.floor(key)
        if idx >= 1 and idx <= #common.SENSOR_KEYS then return idx end
    end
    for i = 1, #common.SENSOR_KEYS do
        if common.SENSOR_KEYS[i] == key then return i end
    end
    return 1
end

function common.choiceToKey(value)
    local idx = tonumber(value) or 1
    return common.SENSOR_KEYS[idx] or common.SENSOR_KEYS[1]
end

function common.layoutKeyToChoice(key)
    for i = 1, #common.LAYOUT_KEYS do
        if common.LAYOUT_KEYS[i] == key then return i end
    end
    return 1
end

function common.layoutChoiceToKey(value)
    local idx = tonumber(value) or 1
    return common.LAYOUT_KEYS[idx] or common.LAYOUT_KEYS[1]
end

function common.applyDefaults(target)
    local cfg = target or {}
    local legacyPrepost = {}
    for i = 1, 4 do
        local legacyKey = "prepost_" .. i
        legacyPrepost[i] = cfg[legacyKey]
    end
    for i = 1, 4 do
        local preKey = "preflight_" .. i
        local inKey = "inflight_" .. i
        local postKey = "postflight_" .. i

        local legacyValue = legacyPrepost[i]

        if cfg[preKey] == nil or cfg[preKey] == "" then
            cfg[preKey] = legacyValue or common.DEFAULT_LAYOUT.preflight[i]
        end
        if cfg[inKey] == nil or cfg[inKey] == "" then
            cfg[inKey] = common.DEFAULT_LAYOUT.inflight[i]
        end
        if cfg[postKey] == nil or cfg[postKey] == "" then
            cfg[postKey] = legacyValue or common.DEFAULT_LAYOUT.postflight[i]
        end
    end
    if cfg.layout_preflight == nil or cfg.layout_preflight == "" then cfg.layout_preflight = "stacked_three" end
    if cfg.layout_inflight == nil or cfg.layout_inflight == "" then cfg.layout_inflight = "one_top_two_bottom" end
    if cfg.layout_postflight == nil or cfg.layout_postflight == "" then cfg.layout_postflight = "two_top_two_bottom" end
    if cfg.offset_x == nil then cfg.offset_x = 0 end
    if cfg.offset_y == nil then cfg.offset_y = 0 end
    return cfg
end

function common.layoutPreview(layoutKey)
    if layoutKey == "two_top_one_bottom" then
        return "[1]     [2]", "      [3]"
    elseif layoutKey == "two_top_two_bottom" then
        return "[1]     [2]", "[3]     [4]"
    elseif layoutKey == "one_centered" then
        return "      [1]", ""
    elseif layoutKey == "one_top_two_bottom" then
        return "      [1]", "[3]     [4]"
    elseif layoutKey == "stacked_three" then
        return "     [1/2]", "        [3]"
    end
    return "[1]     [2]", "[3]     [4]"
end

function common.saveConfig(config)
    local msg = "@i18n(app.modules.profile_select.save_prompt_local)@"
    rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))

    rfsuite.preferences.activelook = rfsuite.preferences.activelook or {}
    local prefs = rfsuite.preferences.activelook
    local changed = false
    for key, value in pairs(config) do
        if prefs[key] ~= value then changed = true end
        prefs[key] = value
    end
    rfsuite.ini.save_ini_file("SCRIPTS:/" .. rfsuite.config.preferences .. "/preferences.ini", rfsuite.preferences)

    if changed then
        rfsuite.session = rfsuite.session or {}
        rfsuite.session.activelookReset = true
    end

    rfsuite.app.triggers.closeSave = true
    return true
end

function common.confirmedSave(config)
    local confirm = rfsuite.preferences.general and rfsuite.preferences.general.save_confirm
    if confirm == false or confirm == "false" then
        return common.saveConfig(config)
    end

    local buttons = {
        {
            label = "@i18n(app.btn_ok_long)@",
            action = function()
                common.saveConfig(config)
                return true
            end
        },
        {
            label = "@i18n(app.modules.profile_select.cancel)@",
            action = function() return true end
        }
    }

    form.openDialog({
        width = nil,
        title = "@i18n(app.modules.profile_select.save_settings)@",
        message = "@i18n(app.modules.profile_select.save_prompt_local)@",
        buttons = buttons,
        wakeup = function() end,
        paint = function() end,
        options = TEXT_LEFT
    })
    return true
end

function common.clampOffset(value)
    return clamp(tonumber(value) or 0, -20, 20)
end

return common
