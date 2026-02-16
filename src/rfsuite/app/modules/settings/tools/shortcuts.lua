--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local shortcuts = assert(loadfile("app/lib/shortcuts.lua"))()

local enableWakeup = false
local config = {}
local GROUP_PREF_KEY = "settings_shortcuts_group"

local function prefBool(value)
    return value == true or value == "true" or value == 1 or value == "1"
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

    rfsuite.app.ui.fieldHeader("@i18n(app.modules.settings.name)@" .. " / " .. "@i18n(app.modules.settings.shortcuts)@")
    rfsuite.app.formLineCnt = 0
    local formFieldCount = 0

    config = {}
    local registry = shortcuts.buildRegistry()
    local saved = rfsuite.preferences.shortcuts or {}
    for _, item in ipairs(registry.items or {}) do
        config[item.id] = prefBool(saved[item.id])
    end

    local prefs = rfsuite.preferences
    prefs.menulastselected = prefs.menulastselected or {}
    local selectedGroup = tonumber(prefs.menulastselected[GROUP_PREF_KEY]) or 1
    if selectedGroup < 1 then selectedGroup = 1 end
    if selectedGroup > #registry.groups then selectedGroup = #registry.groups end
    if selectedGroup < 1 then selectedGroup = 1 end

    local function addFieldLine(container, label)
        formFieldCount = formFieldCount + 1
        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        local line
        if container == form then
            line = form.addLine(label)
        elseif container and container.addLine then
            line = container:addLine(label)
        else
            line = form.addLine(label)
        end
        rfsuite.app.formLines[rfsuite.app.formLineCnt] = line
        return line
    end

    if #registry.groups == 0 then
        rfsuite.app.formLines[#rfsuite.app.formLines + 1] = form.addLine("@i18n(app.modules.settings.shortcuts_none)@")
    else
        local groupChoices = {}
        for i, group in ipairs(registry.groups) do
            groupChoices[#groupChoices + 1] = {group.title or "@i18n(app.menu_section_tools)@", i}
        end

        local groupLine = addFieldLine(form, "@i18n(app.modules.settings.shortcuts_group)@")
        rfsuite.app.formFields[formFieldCount] = form.addChoiceField(groupLine, nil, groupChoices,
            function() return selectedGroup end,
            function(newValue)
                prefs.menulastselected[GROUP_PREF_KEY] = newValue
                rfsuite.app.triggers.reloadFull = true
            end)

        local group = registry.groups[selectedGroup]
        if group then
            local panel = form.addExpansionPanel(group.title or "@i18n(app.menu_section_tools)@")
            panel:open(true)
            for _, item in ipairs(group.items) do
                local line = addFieldLine(panel, item.name)
                rfsuite.app.formFields[formFieldCount] = form.addBooleanField(line, nil,
                    function() return config[item.id] == true end,
                    function(newValue) config[item.id] = newValue end)
            end
        end
    end

    for i, field in ipairs(rfsuite.app.formFields) do if field and field.enable then field:enable(true) end end
    rfsuite.app.navButtons.save = true
end

local function onNavMenu()
    pageRuntime.openMenuContext()
    return true
end

local function onSaveMenu()

    local function doSave()
        local prefs = rfsuite.preferences
        prefs.shortcuts = prefs.shortcuts or {}
        for key in pairs(prefs.shortcuts) do prefs.shortcuts[key] = nil end
        for id, selected in pairs(config) do
            if selected == true then prefs.shortcuts[id] = true end
        end
        rfsuite.ini.save_ini_file("SCRIPTS:/" .. rfsuite.config.preferences .. "/preferences.ini", prefs)
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
    return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
end

return {event = event, openPage = openPage, onNavMenu = onNavMenu, onSaveMenu = onSaveMenu, navButtons = {menu = true, save = true, reload = false, tool = false, help = false}, API = {}}
