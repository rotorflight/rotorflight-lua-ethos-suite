--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local enableWakeup = false

local config = {}

local function openPage(opts)

    local pageIdx = opts.idx
    local title = opts.title
    local script = opts.script
    enableWakeup = true
    if not rfsuite.app.navButtons then rfsuite.app.navButtons = {} end
    rfsuite.app.triggers.closeProgressLoader = true
    form.clear()

    rfsuite.app.lastIdx = pageIdx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader("Settings" .. " / " .. "Dashboard" .. " / " .. "Localization")
    rfsuite.app.formLineCnt = 0
    local formFieldCount = 0

    local saved = rfsuite.preferences.localizations or {}
    for k, v in pairs(saved) do config[k] = v end

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Temperature Unit")
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, {{"Celsius", 0}, {"Fahrenheit", 1}}, function() return config.temperature_unit or 0 end, function(newValue) config.temperature_unit = newValue end)

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Altitude Unit")
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, {{"Meters", 0}, {"Feet", 1}}, function() return config.altitude_unit or 0 end, function(newValue) config.altitude_unit = newValue end)

    for i, field in ipairs(rfsuite.app.formFields) do if field and field.enable then field:enable(true) end end
    rfsuite.app.navButtons.save = true
end

local function onNavMenu()
    pageRuntime.openMenuContext()
    return true
end

local function onSaveMenu()
    local buttons = {
        {
            label = "                OK                ",
            action = function()
                local msg = "Save current page to radio?"
                rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))
                for key, value in pairs(config) do rfsuite.preferences.localizations[key] = value end
                rfsuite.ini.save_ini_file("SCRIPTS:/" .. rfsuite.config.preferences .. "/preferences.ini", rfsuite.preferences)

                rfsuite.bus.notify("dashboard.reload_themes", {})

                rfsuite.app.triggers.closeSave = true
                return true
            end
        }, {label = "CANCEL", action = function() return true end}
    }

    form.openDialog({width = nil, title = "Save settings", message = "Save current page to radio?", buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})
end

local function event(widget, category, value, x, y)
    return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
end

return {event = event, openPage = openPage, onNavMenu = onNavMenu, onSaveMenu = onSaveMenu, navButtons = {menu = true, save = true, reload = false, tool = false, help = false}, API = {}}
