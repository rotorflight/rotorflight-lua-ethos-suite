--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local enableWakeup = false
local config = {}

local function prefBool(value, default)
    if value == nil then return default end
    if value == true or value == "true" or value == 1 or value == "1" then return true end
    if value == false or value == "false" or value == 0 or value == "0" then return false end
    return default
end

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

    rfsuite.app.ui.fieldHeader("Settings" .. " / " .. "Features")
    rfsuite.app.formLineCnt = 0
    local formFieldCount = 0

    config = {}
    local saved = rfsuite.preferences.general or {}
    config.feature_dashboard = saved.feature_dashboard
    config.feature_toolbox = saved.feature_toolbox
    config.feature_activelook = saved.feature_activelook

    local function addFieldLine(label)
        formFieldCount = formFieldCount + 1
        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        local line = form.addLine(label)
        rfsuite.app.formLines[rfsuite.app.formLineCnt] = line
        return line
    end

    local line = addFieldLine("Rotorflight Dashboard")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(line, nil, function()
        return prefBool(config.feature_dashboard, true)
    end, function(newValue) config.feature_dashboard = newValue end)

    line = addFieldLine("Rotorflight Toolbox")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(line, nil, function()
        return prefBool(config.feature_toolbox, false)
    end, function(newValue) config.feature_toolbox = newValue end)

    line = addFieldLine("Rotorflight ActiveLook")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(line, nil, function()
        return prefBool(config.feature_activelook, false)
    end, function(newValue) config.feature_activelook = newValue end)

    for i, field in ipairs(rfsuite.app.formFields) do if field and field.enable then field:enable(true) end end
    rfsuite.app.navButtons.save = true
end

local function onNavMenu()
    pageRuntime.openMenuContext()
    return true
end

local function onSaveMenu()
    local function doSave()
        local msg = "Save current page to radio?"
        rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))
        rfsuite.preferences.general = rfsuite.preferences.general or {}
        for key, value in pairs(config) do rfsuite.preferences.general[key] = value end
        rfsuite.ini.save_ini_file("SCRIPTS:/" .. rfsuite.config.preferences .. "/preferences.ini", rfsuite.preferences)
        rfsuite.app.MainMenu = assert(loadfile("app/modules/init.lua"))()
        rfsuite.app.triggers.closeSave = true
        return true
    end

    local confirm = rfsuite.preferences.general and rfsuite.preferences.general.save_confirm
    if confirm == false or confirm == "false" then
        doSave()
        return true
    end

    local buttons = {
        {
            label = "                OK                ",
            action = function()
                doSave()
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
