local settings = {}

local function openPage(pageIdx, title, script)
    enableWakeup = true
    rfsuite.app.triggers.closeProgressLoader = true
    form.clear()

    rfsuite.app.lastIdx    = pageIdx
    rfsuite.app.lastTitle  = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader(
        rfsuite.i18n.get("app.modules.settings.name") .. " / " .. rfsuite.i18n.get("app.modules.settings.dashboard") .. " / " .. rfsuite.i18n.get("app.modules.settings.localizations")
    )
    rfsuite.session.formLineCnt = 0

    local formFieldCount = 0

    settings = rfsuite.preferences.localizations

    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = form.addLine(rfsuite.i18n.get("app.modules.settings.temperature_unit"))
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.session.formLineCnt], nil, 
                                                        {{rfsuite.i18n.get("app.modules.settings.celcius"), 0}, {rfsuite.i18n.get("app.modules.settings.fahrenheit"), 1}}, 
                                                        function() 
                                                            if rfsuite.preferences and rfsuite.preferences.localizations then
                                                                return settings.temperature_unit or 0
                                                            end
                                                        end, 
                                                        function(newValue) 
                                                            if rfsuite.preferences and rfsuite.preferences.localizations then
                                                                settings.temperature_unit = newValue
                                                            end    
                                                        end) 
            
    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = form.addLine(rfsuite.i18n.get("app.modules.settings.altitude_unit"))
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.session.formLineCnt], nil, 
                                                        {{rfsuite.i18n.get("app.modules.settings.meters"), 0}, {rfsuite.i18n.get("app.modules.settings.feet"), 1}}, 
                                                        function() 
                                                            if rfsuite.preferences and rfsuite.preferences.localizations then
                                                                return settings.altitude_unit or 0
                                                            end
                                                        end, 
                                                        function(newValue) 
                                                            if rfsuite.preferences and rfsuite.preferences.localizations then
                                                                settings.altitude_unit = newValue
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
        return true
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

local function event(widget, category, value, x, y)
    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage(
            pageIdx,
            rfsuite.i18n.get("app.modules.settings.name"),
            "settings/settings.lua"
        )
        return true
    end
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
