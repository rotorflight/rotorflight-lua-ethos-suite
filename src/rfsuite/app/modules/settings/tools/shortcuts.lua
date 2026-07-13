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
local MAX_SHORTCUTS = (shortcuts.getMaxSelected and shortcuts.getMaxSelected()) or 5
local shortcutMixedIn = false
local registryItems = {}

local function prefBool(value)
    if value == nil then return nil end
    if type(value) == "boolean" then return value end
    if type(value) == "number" then return value > 0 end
    if type(value) == "string" then
        local lowered = value:lower():match("^%s*(.-)%s*$")
        if lowered == "true" or lowered == "1" or lowered == "yes" or lowered == "on" then return true end
        if lowered == "false" or lowered == "0" or lowered == "no" or lowered == "off" then return false end
        if lowered:find("mix", 1, true) then return true end
        if lowered:find("dock", 1, true) then return false end
        local num = tonumber(lowered)
        if num ~= nil then return num > 0 end
    end
    return nil
end

local function countSelected(configMap)
    local count = 0
    for _, selected in pairs(configMap or {}) do
        if selected == true then count = count + 1 end
    end
    return count
end

local function buildLimitedSelection(configMap, orderedItems, limit)
    local selected = {}
    local selectedCount = 0
    for _, item in ipairs(orderedItems or {}) do
        if configMap[item.id] == true then
            selectedCount = selectedCount + 1
            if selectedCount <= limit then
                selected[item.id] = true
            end
        end
    end
    return selected
end

local function showShortcutLimitDialog()
    local message = string.format("No more than %d shortcuts can be selected.", MAX_SHORTCUTS)
    local buttons = {{label = "@i18n(app.btn_ok)@", action = function() return true end}}
    form.openDialog({width = nil, title = "@i18n(app.modules.settings.shortcuts)@", message = message, buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})
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
    registryItems = registry.items or {}
    local saved = rfsuite.preferences.shortcuts or {}
    for _, item in ipairs(registryItems) do
        config[item.id] = (prefBool(saved[item.id]) == true)
    end

    local prefs = rfsuite.preferences
    prefs.menulastselected = prefs.menulastselected or {}
    prefs.general = prefs.general or {}
    local mixedInPref = prefBool(prefs.general.shortcuts_mixed_in)
    shortcutMixedIn = (mixedInPref == true)
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

    local modeLine = addFieldLine(form, "Mixed In Mode")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(modeLine, nil,
        function() return shortcutMixedIn == true end,
        function(newValue)
            local parsed = prefBool(newValue)
            if parsed ~= nil then shortcutMixedIn = (parsed == true) end
        end)

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
                local itemId = item.id
                local line = addFieldLine(panel, item.name)
                rfsuite.app.formFields[formFieldCount] = form.addBooleanField(line, nil,
                    function() return config[itemId] == true end,
                    function(newValue)
                        local parsed = prefBool(newValue)
                        local selected = (parsed == true)
                        if selected and config[itemId] ~= true and countSelected(config) >= MAX_SHORTCUTS then
                            showShortcutLimitDialog()
                            rfsuite.app.triggers.reloadFull = true
                            return
                        end
                        config[itemId] = selected
                    end)
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
        prefs.general = prefs.general or {}
        prefs.shortcuts = prefs.shortcuts or {}
        prefs.general.shortcuts_mixed_in = (shortcutMixedIn == true)
        prefs.general.shortcuts_display_mode = nil

        local selectedMap = buildLimitedSelection(config, registryItems, MAX_SHORTCUTS)
        for key in pairs(prefs.shortcuts) do prefs.shortcuts[key] = nil end
        for _, item in ipairs(registryItems) do
            if selectedMap[item.id] == true then
                prefs.shortcuts[item.id] = true
            end
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
