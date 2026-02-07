--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local enableWakeup = false

local config = {}

local function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

local function openPage(pageIdx, title, script)
    enableWakeup = true
    if not rfsuite.app.navButtons then rfsuite.app.navButtons = {} end
    rfsuite.app.triggers.closeProgressLoader = true
    form.clear()

    rfsuite.app.lastIdx = pageIdx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader("@i18n(app.modules.settings.name)@" .. " / " .. "@i18n(app.modules.settings.txt_general)@")
    rfsuite.app.formLineCnt = 0
    local formFieldCount = 0

    local saved = rfsuite.preferences.general or {}
    for k, v in pairs(saved) do config[k] = v end

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("@i18n(app.modules.settings.txt_iconsize)@")
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, {{"@i18n(app.modules.settings.txt_text)@", 0}, {"@i18n(app.modules.settings.txt_small)@", 1}, {"@i18n(app.modules.settings.txt_large)@", 2}}, function() return config.iconsize ~= nil and config.iconsize or 1 end, function(newValue) config.iconsize = newValue end)

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("@i18n(app.modules.settings.txt_hs_loader)@")
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, {{"@i18n(app.modules.settings.txt_hs_loader_fastclose)@", 0}, {"@i18n(app.modules.settings.txt_hs_loader_wait)@", 1}}, function() return config.hs_loader ~= nil and config.hs_loader or 1 end, function(newValue) config.hs_loader = newValue end)

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("@i18n(app.modules.settings.dashboard_loader_loader_style_select)@")
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, {{"@i18n(app.modules.settings.loader_style_small)@", 0}, {"@i18n(app.modules.settings.loader_style_medium)@", 1}, {"@i18n(app.modules.settings.loader_style_large)@", 2}}, function() return config.theme_loader ~= nil and config.theme_loader or 1 end, function(newValue) config.theme_loader = newValue end)

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("@i18n(app.modules.settings.txt_batttype)@")
    local txbattChoices = {{"@i18n(app.modules.settings.txt_battdef)@", 0}, {"@i18n(app.modules.settings.txt_batttext)@", 1}, {"@i18n(app.modules.settings.txt_battdig)@", 2}}
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, txbattChoices, function() return config.txbatt_type ~= nil and config.txbatt_type or 0 end, function(newValue)
        config.txbatt_type = newValue
        if rfsuite.preferences and rfsuite.preferences.general then rfsuite.preferences.general.txbatt_type = newValue end
    end)

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("@i18n(app.modules.settings.txt_save_confirm)@")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, function() return config.save_confirm or false end, function(newValue) config.save_confirm = newValue end)

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("@i18n(app.modules.settings.txt_save_armed_warning)@")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, function()
        if config.save_armed_warning == nil then return true end
        return config.save_armed_warning
    end, function(newValue) config.save_armed_warning = newValue end)

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("@i18n(app.modules.settings.txt_reload_confirm)@")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, function() return config.reload_confirm or false end, function(newValue) config.reload_confirm = newValue end)

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("@i18n(app.modules.settings.txt_mspstatusdialog)@")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, function()
        if config.mspstatusdialog == nil then return true end
        return config.mspstatusdialog
    end, function(newValue) config.mspstatusdialog = newValue end)


    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("@i18n(app.modules.settings.txt_syncname)@")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, function() return config.syncname or false end, function(newValue) config.syncname = newValue end)


    for i, field in ipairs(rfsuite.app.formFields) do if field and field.enable then field:enable(true) end end
    rfsuite.app.navButtons.save = true
end

local function onNavMenu()
    rfsuite.app.ui.progressDisplay(nil, nil, true)
    rfsuite.app.ui.openPage(pageIdx, "@i18n(app.modules.settings.name)@", "settings/settings.lua")
end

local function onSaveMenu()

    local function doSave()
        local msg = "@i18n(app.modules.profile_select.save_prompt_local)@"
        rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))
        for key, value in pairs(config) do rfsuite.preferences.general[key] = value end
        rfsuite.ini.save_ini_file("SCRIPTS:/" .. rfsuite.config.preferences .. "/preferences.ini", rfsuite.preferences)
        rfsuite.app.triggers.closeSave = true
        return true
    end

    if rfsuite.preferences.general.save_confirm == false or rfsuite.preferences.general.save_confirm == "false" then
        doSave()
        return true
    end    

    local buttons = {
        {
            label = "@i18n(app.btn_ok_long)@",
            action = function()
                doSave()
                return true
            end
        }, {label = "@i18n(app.modules.profile_select.cancel)@", action = function() return true end}
    }

    form.openDialog({width = nil, title = "@i18n(app.modules.profile_select.save_settings)@", message = "@i18n(app.modules.profile_select.save_prompt_local)@", buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})
end

local function event(widget, category, value, x, y)

    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage(pageIdx, "@i18n(app.modules.settings.name)@", "settings/settings.lua")
        return true
    end
end

return {event = event, openPage = openPage, onNavMenu = onNavMenu, onSaveMenu = onSaveMenu, navButtons = {menu = true, save = true, reload = false, tool = false, help = false}, API = {}}
