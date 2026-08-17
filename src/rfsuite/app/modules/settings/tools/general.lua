--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local enableWakeup = false

local config = {}

local function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

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

    rfsuite.app.ui.fieldHeader("Settings" .. " / " .. "General")
    rfsuite.app.formLineCnt = 0
    local formFieldCount = 0

    config = {}
    local saved = rfsuite.preferences.general or {}
    for k, v in pairs(saved) do config[k] = v end

    local function addFieldLine(container, label)
        formFieldCount = formFieldCount + 1
        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        local line = container:addLine(label)
        rfsuite.app.formLines[rfsuite.app.formLineCnt] = line
        return line
    end

    local displayPanel = form.addExpansionPanel("Display")
    local safetyPanel = form.addExpansionPanel("Safety & Prompts")
    local integrationPanel = form.addExpansionPanel("Integration")
    local developerPanel = form.addExpansionPanel("Development")

    local line = addFieldLine(displayPanel, "Icon Size")
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(line, nil, {{"TEXT", 0}, {"SMALL", 1}, {"LARGE", 2}}, function() return config.iconsize ~= nil and config.iconsize or 1 end, function(newValue) config.iconsize = newValue end)

    line = addFieldLine(displayPanel, "Follow dashboard theme")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(line, nil, function()
        return prefBool(config.follow_dashboard_theme, true)
    end, function(newValue) config.follow_dashboard_theme = newValue end)

    line = addFieldLine(displayPanel, "Tx Battery Options")
    local txbattChoices = {{"Default", 0}, {"Text", 1}, {"Digital", 2}}
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(line, nil, txbattChoices, function() return config.txbatt_type ~= nil and config.txbatt_type or 0 end, function(newValue) config.txbatt_type = newValue end)

    line = addFieldLine(displayPanel, "Theme loader style")
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(line, nil, {{"SMALL", 0}, {"MEDIUM", 1}, {"LARGE", 2}}, function() return config.theme_loader ~= nil and config.theme_loader or 1 end, function(newValue) config.theme_loader = newValue end)

    line = addFieldLine(displayPanel, "Progress Loader")
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(line, nil, {{"CLOSE ASAP", 0}, {"CLOSE AT 100%", 1}}, function() return config.hs_loader ~= nil and config.hs_loader or 1 end, function(newValue) config.hs_loader = newValue end)

    line = addFieldLine(displayPanel, "Dashboard startup log")
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(line, nil, {{"CONNECTION", 0}, {"READY", 1}}, function() return tonumber(config.dashboard_startup_log_close) or 0 end, function(newValue) config.dashboard_startup_log_close = newValue end)

    line = addFieldLine(displayPanel, "Dash-bar auto-close")
    rfsuite.app.formFields[formFieldCount] = form.addNumberField(line, nil, 5, 30, function()
        if config.toolbar_timeout == nil then return 10 end
        return config.toolbar_timeout
    end, function(newValue) config.toolbar_timeout = newValue end)
    rfsuite.app.formFields[formFieldCount]:suffix("s")
    rfsuite.app.formFields[formFieldCount]:minimum(5)
    rfsuite.app.formFields[formFieldCount]:maximum(30)

    line = addFieldLine(displayPanel, "Collapse Navigation")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(line, nil, function()
        return prefBool(config.collapse_unused_menu_entries, false)
    end, function(newValue) config.collapse_unused_menu_entries = newValue end)

    line = addFieldLine(safetyPanel, "Confirm on save")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(line, nil, function() return config.save_confirm or false end, function(newValue) config.save_confirm = newValue end)

    line = addFieldLine(safetyPanel, "Save requires changes")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(line, nil, function()
        if config.save_dirty_only == nil then return true end
        return config.save_dirty_only
    end, function(newValue) config.save_dirty_only = newValue end)

    line = addFieldLine(safetyPanel, "Show disarm-to-save warning")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(line, nil, function()
        if config.save_armed_warning == nil then return true end
        return config.save_armed_warning
    end, function(newValue) config.save_armed_warning = newValue end)

    line = addFieldLine(safetyPanel, "Confirm on reload")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(line, nil, function() return config.reload_confirm or false end, function(newValue) config.reload_confirm = newValue end)

    line = addFieldLine(safetyPanel, "Battery Type on connect")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(line, nil, function()
        return prefBool(config.show_battery_profile_startup, true)
    end, function(newValue) config.show_battery_profile_startup = newValue end)

    line = addFieldLine(safetyPanel, "Battery Type confirmation")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(line, nil, function()
        return prefBool(config.show_confirmation_dialog, true)
    end, function(newValue) config.show_confirmation_dialog = newValue end)

    line = addFieldLine(safetyPanel, "ESC tools safety prompt")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(line, nil, function()
        return prefBool(config.show_esc_tools_warning, true)
    end, function(newValue) config.show_esc_tools_warning = newValue end)

    line = addFieldLine(integrationPanel, "Sync model name")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(line, nil, function() return config.syncname or false end, function(newValue) config.syncname = newValue end)

    line = addFieldLine(integrationPanel, "MSP Activity Display")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(line, nil, function()
        if config.mspstatusdialog == nil then return true end
        return config.mspstatusdialog
    end, function(newValue) config.mspstatusdialog = newValue end)

    line = addFieldLine(developerPanel, "Developer Tools")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(line, nil, function() return config.developer_tools or false end, function(newValue) config.developer_tools = newValue end)


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
        for key, value in pairs(config) do rfsuite.preferences.general[key] = value end
        rfsuite.ini.save_ini_file("SCRIPTS:/" .. rfsuite.config.preferences .. "/preferences.ini", rfsuite.preferences)
        -- Invalidate rather than rebuild inline: reparsing the manifest here would stack
        -- on top of this same tick's file I/O and can exceed Ethos's per-tick instruction
        -- budget. The next screen that needs app.MainMenu rebuilds it lazily instead.
        rfsuite.app.MainMenu = nil
        if rfsuite.app.themeBridge and rfsuite.app.themeBridge.invalidate then rfsuite.app.themeBridge.invalidate() end
        rfsuite.app.triggers.closeSave = true
        return true
    end

    if config.save_confirm == false or config.save_confirm == "false" then
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
