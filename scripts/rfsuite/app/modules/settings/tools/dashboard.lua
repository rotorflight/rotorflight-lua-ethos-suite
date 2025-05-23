local settings = {}

local function openPage(pageIdx, title, script)
    enableWakeup = true
    rfsuite.app.triggers.closeProgressLoader = true
    form.clear()

    rfsuite.app.lastIdx    = pageIdx
    rfsuite.app.lastTitle  = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader(
        rfsuite.i18n.get("app.modules.settings.name") .. " / " .. rfsuite.i18n.get("app.modules.settings.dashboard")
    )
    rfsuite.session.formLineCnt = 0

    local formFieldCount = 0

    settings = rfsuite.preferences.dashboard

    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = form.addLine(rfsuite.i18n.get("app.modules.settings.dashboard_theme_preflight"))

    -- get theme list
    local themeList = rfsuite.widgets.dashboard.listThemes() 
    local formattedThemes = {}
    for i, theme in ipairs(themeList) do
        table.insert(formattedThemes, { theme.name, theme.idx })
    end
                                              
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.session.formLineCnt], nil, 
                                                        formattedThemes, 
                                                        function()
                                                            if rfsuite.preferences and rfsuite.preferences.dashboard then
                                                                local folderName = settings.theme_preflight
                                                                for _, theme in ipairs(themeList) do
                                                                    if (theme.source .. "/" .. theme.folder) == folderName then
                                                                        return theme.idx
                                                                    end
                                                                end
                                                            end
                                                            return nil
                                                        end, 
                                                        function(newValue) 
                                                            if rfsuite.preferences and rfsuite.preferences.dashboard then
                                                                local theme = themeList[newValue]
                                                                if theme then
                                                                    settings.theme_preflight = theme.source .. "/" .. theme.folder
                                                                end
                                                            end
                                                        end)     

    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = form.addLine(rfsuite.i18n.get("app.modules.settings.dashboard_theme_inflight"))

    -- get theme list
    local themeList = rfsuite.widgets.dashboard.listThemes() 
    local formattedThemes = {}
    for i, theme in ipairs(themeList) do
        table.insert(formattedThemes, { theme.name, theme.idx })
    end
                                              
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.session.formLineCnt], nil, 
                                                        formattedThemes, 
                                                        function()
                                                            if rfsuite.preferences and rfsuite.preferences.dashboard then
                                                                local folderName = settings.theme_inflight
                                                                for _, theme in ipairs(themeList) do
                                                                    if (theme.source .. "/" .. theme.folder) == folderName then
                                                                        return theme.idx
                                                                    end
                                                                end
                                                            end
                                                            return nil
                                                        end, 
                                                        function(newValue) 
                                                            if rfsuite.preferences and rfsuite.preferences.dashboard then
                                                                local theme = themeList[newValue]
                                                                if theme then
                                                                    settings.theme_inflight = theme.source .. "/" .. theme.folder
                                                                end
                                                            end
                                                        end)                                                             
    
    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = form.addLine(rfsuite.i18n.get("app.modules.settings.dashboard_theme_postflight"))

    -- get theme list
    local themeList = rfsuite.widgets.dashboard.listThemes() 
    local formattedThemes = {}
    for i, theme in ipairs(themeList) do
        table.insert(formattedThemes, { theme.name, theme.idx })
    end
                                              
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.session.formLineCnt], nil, 
                                                        formattedThemes, 
                                                        function()
                                                            if rfsuite.preferences and rfsuite.preferences.dashboard then
                                                                local folderName = settings.theme_postflight
                                                                for _, theme in ipairs(themeList) do
                                                                    if (theme.source .. "/" .. theme.folder) == folderName then
                                                                        return theme.idx
                                                                    end
                                                                end
                                                            end
                                                            return nil
                                                        end, 
                                                        function(newValue) 
                                                            if rfsuite.preferences and rfsuite.preferences.dashboard then
                                                                local theme = themeList[newValue]
                                                                if theme then
                                                                    settings.theme_postflight = theme.source .. "/" .. theme.folder
                                                                end
                                                            end
                                                        end)      

end

local function onNavMenu()
    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(
        pageIdx,
        rfsuite.i18n.get("app.modules.settings.name"),
        "settings/settings.lua"
    )
end

local function onSaveMenu()
    local buttons = {
        {
            label  = rfsuite.i18n.get("app.btn_ok_long"),
            action = function()
                local msg = rfsuite.i18n.get("app.modules.profile_select.save_prompt_local")
                rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))
                for key, value in pairs(settings) do
                    rfsuite.preferences.dashboard[key] = value
                end
                rfsuite.ini.save_ini_file(
                    "SCRIPTS:/" .. rfsuite.config.preferences .. "/preferences.ini",
                    rfsuite.preferences
                )
                -- update dashboard theme
                rfsuite.widgets.dashboard.reload_themes()
                -- close save progress
                rfsuite.app.triggers.closeSave = true
                return true
            end,
        },
        {
            label  = rfsuite.i18n.get("app.modules.profile_select.cancel"),
            action = function()
                return true
            end,
        },
    }

    form.openDialog({
        width   = nil,
        title   = rfsuite.i18n.get("app.modules.profile_select.save_settings"),
        message = rfsuite.i18n.get("app.modules.profile_select.save_prompt_local"),
        buttons = buttons,
        wakeup  = function() end,
        paint   = function() end,
        options = TEXT_LEFT,
    })
end

return {
    event      = event,
    openPage   = openPage,
    wakeup     = wakeup,
    onNavMenu  = onNavMenu,
    onSaveMenu = onSaveMenu,
    navButtons = {
        menu   = true,
        save   = true,
        reload = false,
        tool   = false,
        help   = false,
    },
    API = {},
}
