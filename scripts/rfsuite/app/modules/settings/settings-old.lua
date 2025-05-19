
function sensorNameMap(sensorList)
    local nameMap = {}
    for _, sensor in ipairs(sensorList) do
        nameMap[sensor.key] = sensor.name
    end
    return nameMap
end


local function openPage(pidx, title, script)
    enableWakeup = true
    rfsuite.app.triggers.closeProgressLoader = true

    form.clear()

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader(rfsuite.i18n.get("app.modules.settings.name"))

    rfsuite.session.formLineCnt = 0

    local eventList = rfsuite.tasks.events.eventTable.telemetry
    local eventNames = sensorNameMap(rfsuite.tasks.telemetry.listSensors())

    local formFieldCount = 0


    -- general
    local generalpanel = form.addExpansionPanel(rfsuite.i18n.get("app.modules.settings.txt_general"))
    generalpanel:open(false)

    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = generalpanel:addLine(rfsuite.i18n.get("app.modules.settings.txt_iconsize"))
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.session.formLineCnt], nil, 
                                                        {{rfsuite.i18n.get("app.modules.settings.txt_text"), 0}, {rfsuite.i18n.get("app.modules.settings.txt_small"), 1}, {rfsuite.i18n.get("app.modules.settings.txt_large"), 2}},
                                                        function() 
                                                            if rfsuite.preferences and rfsuite.preferences.general then
                                                                    return rfsuite.preferences.general.iconsize or 1
                                                            end
                                                        end, 
                                                        function(newValue) 
                                                            if rfsuite.preferences and rfsuite.preferences.general then
                                                                rfsuite.preferences.general.iconsize = newValue
                                                                rfsuite.ini.save_ini_file(rfsuite.config.preferences, rfsuite.preferences)
                                                            end    
                                                        end) 

    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = generalpanel:addLine(rfsuite.i18n.get("app.modules.settings.txt_syncname"))
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.session.formLineCnt], 
                                                        nil, 
                                                        function() 
                                                            if rfsuite.preferences and rfsuite.preferences.general then
                                                                return rfsuite.preferences.general['syncname'] 
                                                            end
                                                        end, 
                                                        function(newValue) 
                                                            if rfsuite.preferences and rfsuite.preferences.general then
                                                                rfsuite.preferences.general.syncname = newValue
                                                                rfsuite.ini.save_ini_file(rfsuite.config.preferences, rfsuite.preferences)
                                                            end    
                                                        end)    


    -- dashboard
    local dashboardpanel = form.addExpansionPanel(rfsuite.i18n.get("app.modules.settings.dashboard"))
    dashboardpanel:open(false)

    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = dashboardpanel:addLine(rfsuite.i18n.get("app.modules.settings.dashboard_theme"))

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
                                                                local folderName = rfsuite.preferences.dashboard.theme
                                                                for _, theme in ipairs(themeList) do
                                                                    if theme.folder == folderName then
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
                                                                    rfsuite.preferences.dashboard.theme = theme.folder
                                                                    rfsuite.ini.save_ini_file(rfsuite.config.preferences, rfsuite.preferences)
                                                                    rfsuite.widgets.dashboard.reload_theme()
                                                                end
                                                            end
                                                        end) 


    -- telemetry announcements
    local alertpanel = form.addExpansionPanel(rfsuite.i18n.get("app.modules.settings.txt_telemetry_announcements"))
    alertpanel:open(false)

    for i, v in ipairs(eventList) do
        formFieldCount = formFieldCount + 1
        rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
        rfsuite.app.formLines[rfsuite.session.formLineCnt] = alertpanel:addLine(eventNames[v.sensor] or "unknown")
        rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.session.formLineCnt], 
                                                            nil, 
                                                            function() 
                                                                if rfsuite.preferences and rfsuite.preferences.announcements then
                                                                    return rfsuite.preferences.announcements[v.sensor] 
                                                                end
                                                            end, 
                                                            function(newValue) 
                                                                if rfsuite.preferences and rfsuite.preferences.announcements then
                                                                    rfsuite.preferences.announcements[v.sensor] = newValue 
                                                                    rfsuite.ini.save_ini_file(rfsuite.config.preferences, rfsuite.preferences)
                                                                end    
                                                            end)
    end

    -- development mode
    local devpanel = form.addExpansionPanel("Development")
    devpanel:open(false)

    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = devpanel:addLine(rfsuite.i18n.get("app.modules.settings.txt_devtools"))
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.session.formLineCnt], 
                                                        nil, 
                                                        function() 
                                                            if rfsuite.preferences and rfsuite.preferences.developer then
                                                                return rfsuite.preferences.developer['devtools'] 
                                                            end
                                                        end, 
                                                        function(newValue) 
                                                            if rfsuite.preferences and rfsuite.preferences.developer then
                                                                rfsuite.preferences.developer.devtools = newValue
                                                                rfsuite.ini.save_ini_file(rfsuite.config.preferences, rfsuite.preferences)
                                                            end    
                                                        end)    

    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = devpanel:addLine(rfsuite.i18n.get("app.modules.settings.txt_compilation"))
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.session.formLineCnt], 
                                                        nil, 
                                                        function() 
                                                            if rfsuite.preferences and rfsuite.preferences.developer then
                                                                return rfsuite.preferences.developer['compile'] 
                                                            end
                                                        end, 
                                                        function(newValue) 
                                                            if rfsuite.preferences and rfsuite.preferences.developer then
                                                                rfsuite.preferences.developer.compile = newValue
                                                                rfsuite.ini.save_ini_file(rfsuite.config.preferences, rfsuite.preferences)
                                                            end    
                                                        end)                                                        


    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = devpanel:addLine(rfsuite.i18n.get("app.modules.settings.txt_loglocation"))
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.session.formLineCnt], nil, 
                                                        {{rfsuite.i18n.get("app.modules.settings.txt_console"), 0}, {rfsuite.i18n.get("app.modules.settings.txt_consolefile"), 1}}, 
                                                        function() 
                                                            if rfsuite.preferences and rfsuite.preferences.developer then
                                                                if rfsuite.preferences.developer.logtofile  == false then
                                                                    return 0
                                                                else
                                                                    return 1
                                                                end   
                                                            end
                                                        end, 
                                                        function(newValue) 
                                                            if rfsuite.preferences and rfsuite.preferences.developer then
                                                                local value
                                                                if newValue == 0 then
                                                                    value = false
                                                                else    
                                                                    value = true
                                                                end    
                                                                rfsuite.preferences.developer.logtofile = value
                                                                rfsuite.ini.save_ini_file(rfsuite.config.preferences, rfsuite.preferences)
                                                            end    
                                                        end) 

    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = devpanel:addLine(rfsuite.i18n.get("app.modules.settings.txt_loglevel"))
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.session.formLineCnt], nil, 
                                                        {{rfsuite.i18n.get("app.modules.settings.txt_off"), 0}, {rfsuite.i18n.get("app.modules.settings.txt_info"), 1}, {rfsuite.i18n.get("app.modules.settings.txt_debug"), 2}}, 
                                                        function() 
                                                            if rfsuite.preferences and rfsuite.preferences.developer then
                                                                if rfsuite.preferences.developer['loglevel']  == "off" then
                                                                    return 0
                                                                elseif rfsuite.preferences.developer['loglevel']  == "info" then
                                                                    return 1
                                                                else
                                                                    return 2
                                                                end   
                                                            end
                                                        end, 
                                                        function(newValue) 
                                                            if rfsuite.preferences and rfsuite.preferences.developer then
                                                                local value
                                                                if newValue == 0 then
                                                                    value = "off"
                                                                elseif newValue == 1 then
                                                                    value = "info"
                                                                else
                                                                    value = "debug"
                                                                end    
                                                                rfsuite.preferences.developer['loglevel'] = value 
                                                                rfsuite.preferences.developer.loglevel = value
                                                                rfsuite.ini.save_ini_file(rfsuite.config.preferences, rfsuite.preferences)
                                                            end    
                                                        end) 
 
    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = devpanel:addLine(rfsuite.i18n.get("app.modules.settings.txt_mspdata"))
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.session.formLineCnt], 
                                                        nil, 
                                                        function() 
                                                            if rfsuite.preferences and rfsuite.preferences.developer then
                                                                return rfsuite.preferences.developer['logmsp'] 
                                                            end
                                                        end, 
                                                        function(newValue) 
                                                            if rfsuite.preferences and rfsuite.preferences.developer then
                                                                rfsuite.preferences.developer.logmsp = newValue
                                                                rfsuite.ini.save_ini_file(rfsuite.config.preferences, rfsuite.preferences)
                                                            end    
                                                        end)     

    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = devpanel:addLine(rfsuite.i18n.get("app.modules.settings.txt_queuesize"))
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.session.formLineCnt], 
                                                        nil, 
                                                        function() 
                                                            if rfsuite.preferences and rfsuite.preferences.developer then
                                                                return rfsuite.preferences.developer['logmspQueue'] 
                                                            end
                                                        end, 
                                                        function(newValue) 
                                                            if rfsuite.preferences and rfsuite.preferences.developer then
                                                                rfsuite.preferences.developer.logmspQueue = newValue
                                                                rfsuite.ini.save_ini_file(rfsuite.config.preferences, rfsuite.preferences)
                                                            end    
                                                        end)                                                             

    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = devpanel:addLine(rfsuite.i18n.get("app.modules.settings.txt_memusage"))
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.session.formLineCnt], 
                                                        nil, 
                                                        function() 
                                                            if rfsuite.preferences and rfsuite.preferences.developer then
                                                                return rfsuite.preferences.developer['memstats'] 
                                                            end
                                                        end, 
                                                        function(newValue) 
                                                            if rfsuite.preferences and rfsuite.preferences.developer then
                                                                rfsuite.preferences.developer.memstats = newValue
                                                                rfsuite.ini.save_ini_file(rfsuite.config.preferences, rfsuite.preferences)
                                                            end    
                                                        end)  

end


-- not changing to custom api at present due to complexity of read/write scenario in these modules
return {
    event = event,
    openPage = openPage,
    wakeup = wakeup,
    navButtons = {
        menu = true,
        save = false,
        reload = false,
        tool = false,
        help = false
    },  
    API = {},
}
