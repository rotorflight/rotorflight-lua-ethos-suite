--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local settings = {}
local settings_model = {}

local themeList = rfsuite.widgets.dashboard.listThemes()
local formattedThemes = {}
local formattedThemesModel = {}
local themeIdByFolder = {}
local themeById = {}
local defaultThemeId = 0

local enableWakeup = false
local prevConnectedState = nil
local globalUseSameOverride = nil
local modelUseSameOverride = nil
local fieldIds = {}

local function clearTable(tbl)
    if type(tbl) ~= "table" then return end
    for k in pairs(tbl) do tbl[k] = nil end
end

local function normalizeThemeFolder(folderName)
    if type(folderName) ~= "string" then return folderName end
    local src, folder = folderName:match("([^/]+)/(.+)")
    if src == "system" and type(folder) == "string" and folder:sub(1, 1) == "@" then
        return src .. "/" .. folder:sub(2)
    end
    return folderName
end

local function sortThemesByName(a, b)
    local nameA = string.lower(a.name or "")
    local nameB = string.lower(b.name or "")
    if nameA ~= nameB then return nameA < nameB end

    local folderA = (a.source or "") .. "/" .. (a.folder or "")
    local folderB = (b.source or "") .. "/" .. (b.folder or "")
    return folderA < folderB
end

local function generateThemeList()

    themeList = rfsuite.widgets.dashboard.listThemes()
    table.sort(themeList, sortThemesByName)

    local screenW, screenH = lcd.getWindowSize()
    if screenW and screenH then
        for i = #themeList, 1, -1 do
            local minRes = themeList[i].minResolution
            if type(minRes) == "table" and (screenW < (minRes.x or 0) or screenH < (minRes.y or 0)) then
                table.remove(themeList, i)
            end
        end
    end

    settings = rfsuite.preferences.dashboard or {}

    if rfsuite.session.modelPreferences and type(rfsuite.session.modelPreferences.dashboard) == "table" then
        settings_model = rfsuite.session.modelPreferences.dashboard
    else
        settings_model = {}
    end

    clearTable(formattedThemes)
    clearTable(formattedThemesModel)
    clearTable(themeIdByFolder)
    clearTable(themeById)
    defaultThemeId = 0

    local fallbackThemeId = 0
    for i, theme in ipairs(themeList) do
        local themeId = tonumber(theme.idx) or i
        local themeName = theme.name or ("Theme " .. tostring(i))
        local folderKey = nil
        if type(theme.source) == "string" and type(theme.folder) == "string" then
            folderKey = theme.source .. "/" .. theme.folder
            themeIdByFolder[folderKey] = themeId
            if theme.source == "system" then
                themeIdByFolder[theme.source .. "/@" .. theme.folder] = themeId
            end
            if theme.source == "system" and theme.folder == "default" then defaultThemeId = themeId end
        end
        themeById[themeId] = theme
        if fallbackThemeId == 0 then fallbackThemeId = themeId end
        table.insert(formattedThemes, {themeName, themeId})
    end
    if defaultThemeId == 0 then defaultThemeId = fallbackThemeId end

    table.insert(formattedThemesModel, {"@i18n(app.modules.settings.dashboard_theme_panel_model_disabled)@", 0})
    for i, theme in ipairs(themeList) do
        local themeId = tonumber(theme.idx) or i
        local themeName = theme.name or ("Theme " .. tostring(i))
        table.insert(formattedThemesModel, {themeName, themeId})
    end
end

local function getThemeIdFromFolder(folderName, allowDisabled)
    if type(folderName) == "string" and folderName ~= "" and folderName ~= "nil" then
        local id = themeIdByFolder[normalizeThemeFolder(folderName)]
        if not id then id = themeIdByFolder[folderName] end
        if type(id) == "number" then return id end
    end
    if allowDisabled then return 0 end
    return defaultThemeId
end

local function getThemeByChoiceValue(choiceValue)
    local id = tonumber(choiceValue)
    if not id then return nil end
    return themeById[id]
end

local function getThemeFolderByChoiceValue(choiceValue, allowDisabled)
    local theme = getThemeByChoiceValue(choiceValue)
    if theme then return theme.source .. "/" .. theme.folder end
    if allowDisabled then return "nil" end

    theme = getThemeByChoiceValue(defaultThemeId)
    if theme then return theme.source .. "/" .. theme.folder end
    return nil
end

local function setThemeSetting(target, key, choiceValue, allowDisabled)
    if type(target) ~= "table" then return end
    local folder = getThemeFolderByChoiceValue(choiceValue, allowDisabled)
    if folder then target[key] = folder end
end

local function copyPreflightThemeToAllPhases(target, allowDisabled)
    if type(target) ~= "table" then return end
    local choiceValue = getThemeIdFromFolder(target.theme_preflight, allowDisabled)
    local folder = getThemeFolderByChoiceValue(choiceValue, allowDisabled)
    if folder then
        target.theme_preflight = folder
        target.theme_inflight = folder
        target.theme_postflight = folder
    end
end

local function settingsUseSameTheme(target, allowDisabled)
    if type(target) ~= "table" then return true end
    local preflight = getThemeIdFromFolder(target.theme_preflight, allowDisabled)
    return preflight == getThemeIdFromFolder(target.theme_inflight, allowDisabled) and preflight == getThemeIdFromFolder(target.theme_postflight, allowDisabled)
end

local function globalUseSameTheme()
    if globalUseSameOverride ~= nil then return globalUseSameOverride end
    return settingsUseSameTheme(settings, false)
end

local function modelUseSameTheme()
    if modelUseSameOverride ~= nil then return modelUseSameOverride end
    return settingsUseSameTheme(settings_model, true)
end

local function modelThemeFieldsEnabled()
    return (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false
end

local function enableField(fieldId, enabled)
    local field = fieldId and rfsuite.app.formFields[fieldId] or nil
    if field and field.enable then field:enable(enabled) end
end

local function updateGlobalPhaseFields()
    local useSame = globalUseSameTheme()
    enableField(fieldIds.global_inflight, not useSame)
    enableField(fieldIds.global_postflight, not useSame)
end

local function updateModelPhaseFields()
    local enabled = modelThemeFieldsEnabled()
    local useSame = modelUseSameTheme()
    enableField(fieldIds.model_use_same, enabled)
    enableField(fieldIds.model_preflight, enabled)
    enableField(fieldIds.model_inflight, enabled and not useSame)
    enableField(fieldIds.model_postflight, enabled and not useSame)
end

local function openPage(opts)

    local pageIdx = opts.idx
    local title = opts.title
    local script = opts.script
    enableWakeup = true
    rfsuite.app.triggers.closeProgressLoader = true
    form.clear()

    rfsuite.app.lastIdx = pageIdx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader("@i18n(app.modules.settings.name)@" .. " / " .. "@i18n(app.modules.settings.dashboard)@" .. " / " .. "@i18n(app.modules.settings.dashboard_theme)@")
    rfsuite.app.formLineCnt = 0

    local formFieldCount = 0

    generateThemeList()
    clearTable(fieldIds)
    if settings.use_same_theme ~= nil then
        globalUseSameOverride = settings.use_same_theme == true or settings.use_same_theme == "true"
    else
        globalUseSameOverride = nil
    end
    if type(settings_model) == "table" and settings_model.use_same_theme ~= nil then
        modelUseSameOverride = settings_model.use_same_theme == true or settings_model.use_same_theme == "true"
    else
        modelUseSameOverride = nil
    end

    local global_panel = form.addExpansionPanel("@i18n(app.modules.settings.dashboard_theme_panel_global)@")
    global_panel:open(true)

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = global_panel:addLine("@i18n(app.modules.settings.dashboard_theme_use_same)@")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, function()
        return globalUseSameTheme()
    end, function(newValue)
        globalUseSameOverride = newValue == true
        settings.use_same_theme = globalUseSameOverride
        if globalUseSameOverride then copyPreflightThemeToAllPhases(settings, false) end
        updateGlobalPhaseFields()
    end)
    fieldIds.global_use_same = formFieldCount

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = global_panel:addLine("@i18n(app.modules.settings.dashboard_theme_preflight)@")

    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, formattedThemes, function()
        if rfsuite.preferences and rfsuite.preferences.dashboard then
            local folderName = settings.theme_preflight
            return getThemeIdFromFolder(folderName, false)
        end
        return defaultThemeId
    end, function(newValue)
        if rfsuite.preferences and rfsuite.preferences.dashboard then
            local useSame = globalUseSameTheme()
            setThemeSetting(settings, "theme_preflight", newValue, false)
            if useSame then copyPreflightThemeToAllPhases(settings, false) end
        end
    end)
    fieldIds.global_preflight = formFieldCount

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = global_panel:addLine("@i18n(app.modules.settings.dashboard_theme_inflight)@")

    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, formattedThemes, function()
        if rfsuite.preferences and rfsuite.preferences.dashboard then
            local folderName = settings.theme_inflight
            return getThemeIdFromFolder(folderName, false)
        end
        return defaultThemeId
    end, function(newValue)
        if rfsuite.preferences and rfsuite.preferences.dashboard then
            setThemeSetting(settings, "theme_inflight", newValue, false)
        end
    end)
    fieldIds.global_inflight = formFieldCount

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = global_panel:addLine("@i18n(app.modules.settings.dashboard_theme_postflight)@")

    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, formattedThemes, function()
        if rfsuite.preferences and rfsuite.preferences.dashboard then
            local folderName = settings.theme_postflight
            return getThemeIdFromFolder(folderName, false)
        end
        return defaultThemeId
    end, function(newValue)
        if rfsuite.preferences and rfsuite.preferences.dashboard then
            setThemeSetting(settings, "theme_postflight", newValue, false)
        end
    end)
    fieldIds.global_postflight = formFieldCount
    updateGlobalPhaseFields()

    local model_panel = form.addExpansionPanel("@i18n(app.modules.settings.dashboard_theme_panel_model)@")
    model_panel:open(false)

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = model_panel:addLine("@i18n(app.modules.settings.dashboard_theme_use_same)@")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, function()
        return modelUseSameTheme()
    end, function(newValue)
        modelUseSameOverride = newValue == true
        if type(settings_model) == "table" then settings_model.use_same_theme = modelUseSameOverride end
        if modelUseSameOverride then copyPreflightThemeToAllPhases(settings_model, true) end
        updateModelPhaseFields()
    end)
    fieldIds.model_use_same = formFieldCount

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = model_panel:addLine("@i18n(app.modules.settings.dashboard_theme_preflight)@")

    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, formattedThemesModel, function()
        if type(settings_model) == "table" then
            local folderName = settings_model.theme_preflight
            return getThemeIdFromFolder(folderName, true)
        end
        return 0
    end, function(newValue)
        if type(settings_model) == "table" then
            local useSame = modelUseSameTheme()
            setThemeSetting(settings_model, "theme_preflight", newValue, true)
            if useSame then copyPreflightThemeToAllPhases(settings_model, true) end
        end
    end)
    fieldIds.model_preflight = formFieldCount

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = model_panel:addLine("@i18n(app.modules.settings.dashboard_theme_inflight)@")

    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, formattedThemesModel, function()
        if type(settings_model) == "table" then
            local folderName = settings_model.theme_inflight
            return getThemeIdFromFolder(folderName, true)
        end
        return 0
    end, function(newValue)
        if type(settings_model) == "table" then
            setThemeSetting(settings_model, "theme_inflight", newValue, true)
        end
    end)
    fieldIds.model_inflight = formFieldCount

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = model_panel:addLine("@i18n(app.modules.settings.dashboard_theme_postflight)@")

    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, formattedThemesModel, function()
        if type(settings_model) == "table" then
            local folderName = settings_model.theme_postflight
            return getThemeIdFromFolder(folderName, true)
        end
        return 0
    end, function(newValue)
        if type(settings_model) == "table" then
            setThemeSetting(settings_model, "theme_postflight", newValue, true)
        end
    end)
    fieldIds.model_postflight = formFieldCount
    updateModelPhaseFields()

end

local function onNavMenu()
    pageRuntime.openMenuContext()
    return true
end

local function onSaveMenu()

    local function doSave()
        local msg = "@i18n(app.modules.profile_select.save_prompt_local)@"
        rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))

        if globalUseSameTheme() then copyPreflightThemeToAllPhases(settings, false) end
        if modelThemeFieldsEnabled() and modelUseSameTheme() then copyPreflightThemeToAllPhases(settings_model, true) end

        for key, value in pairs(settings) do rfsuite.preferences.dashboard[key] = value end
        rfsuite.ini.save_ini_file("SCRIPTS:/" .. rfsuite.config.preferences .. "/preferences.ini", rfsuite.preferences)

        if rfsuite.session.isConnected and rfsuite.session.mcu_id and rfsuite.session.modelPreferencesFile then
            rfsuite.session.modelPreferences.dashboard = rfsuite.session.modelPreferences.dashboard or {}
            for key, value in pairs(settings_model) do rfsuite.session.modelPreferences.dashboard[key] = value end
            rfsuite.ini.save_ini_file(rfsuite.session.modelPreferencesFile, rfsuite.session.modelPreferences)
        end

        rfsuite.widgets.dashboard.reload_themes(true)

        rfsuite.app.triggers.closeSave = true
        return true
    end

    if rfsuite.preferences.general.save_confirm == false or rfsuite.preferences.general.save_confirm == "false" then
        doSave()
        return
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

local function wakeup()
    if not enableWakeup then return end

    local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false

    if currState ~= prevConnectedState then

        if currState then
            generateThemeList()
            local f = rfsuite.app.formFields[fieldIds.model_preflight]
            if f and f.values then f:values(formattedThemesModel) end
            f = rfsuite.app.formFields[fieldIds.model_inflight]
            if f and f.values then f:values(formattedThemesModel) end
            f = rfsuite.app.formFields[fieldIds.model_postflight]
            if f and f.values then f:values(formattedThemesModel) end
            if type(settings_model) == "table" and settings_model.use_same_theme ~= nil then
                modelUseSameOverride = settings_model.use_same_theme == true or settings_model.use_same_theme == "true"
            else
                modelUseSameOverride = nil
            end
        end

        updateModelPhaseFields()

        prevConnectedState = currState
    end
end

return {event = event, openPage = openPage, wakeup = wakeup, onNavMenu = onNavMenu, onSaveMenu = onSaveMenu, navButtons = {menu = true, save = true, reload = false, tool = false, help = false}, API = {}}
