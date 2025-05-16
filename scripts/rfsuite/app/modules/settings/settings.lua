
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
                                                                if rfsuite.userpref and rfsuite.userpref.announcements then
                                                                    return rfsuite.userpref.announcements[v.sensor] 
                                                                end
                                                            end, 
                                                            function(newValue) 
                                                                if rfsuite.userpref and rfsuite.userpref.announcements then
                                                                    rfsuite.userpref.announcements[v.sensor] = newValue 
                                                                    rfsuite.ini.save_ini_file(rfsuite.config.userPreferences, rfsuite.userpref)
                                                                end    
                                                            end)
    end

    -- development mode
    local devpanel = form.addExpansionPanel("Development")
    devpanel:open(false)

    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = devpanel:addLine("Developer Tools")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.session.formLineCnt], 
                                                        nil, 
                                                        function() 
                                                            if rfsuite.userpref and rfsuite.userpref.developer then
                                                                return rfsuite.userpref.developer['devtools'] 
                                                            end
                                                        end, 
                                                        function(newValue) 
                                                            if rfsuite.userpref and rfsuite.userpref.developer then
                                                                rfsuite.userpref.developer['devtools'] = newValue 
                                                                rfsuite.config.developerMode = newValue
                                                                rfsuite.ini.save_ini_file(rfsuite.config.userPreferences, rfsuite.userpref)
                                                            end    
                                                        end)    

    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = devpanel:addLine("Compilation")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.session.formLineCnt], 
                                                        nil, 
                                                        function() 
                                                            if rfsuite.userpref and rfsuite.userpref.developer then
                                                                return rfsuite.userpref.developer['compile'] 
                                                            end
                                                        end, 
                                                        function(newValue) 
                                                            if rfsuite.userpref and rfsuite.userpref.developer then
                                                                rfsuite.userpref.developer['compile'] = newValue 
                                                                rfsuite.config.compile = newValue
                                                                rfsuite.ini.save_ini_file(rfsuite.config.userPreferences, rfsuite.userpref)
                                                            end    
                                                        end)                                                        


    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = devpanel:addLine("Debug log")
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.session.formLineCnt], nil, 
                                                        {{"OFF", 0}, {"INFO", 1}, {"DEBUG", 2}}, 
                                                        function() 
                                                            if rfsuite.userpref and rfsuite.userpref.developer then
                                                                if rfsuite.userpref.developer['loglevel']  == "off" then
                                                                    return 0
                                                                elseif rfsuite.userpref.developer['loglevel']  == "info" then
                                                                    return 1
                                                                else
                                                                    return 2
                                                                end   
                                                            end
                                                        end, 
                                                        function(newValue) 
                                                            if rfsuite.userpref and rfsuite.userpref.developer then
                                                                local value
                                                                if newValue == 0 then
                                                                    value = "off"
                                                                elseif newValue == 1 then
                                                                    value = "info"
                                                                else
                                                                    value = "debug"
                                                                end    
                                                                rfsuite.userpref.developer['loglevel'] = value 
                                                                rfsuite.config.logLevel = value
                                                                rfsuite.ini.save_ini_file(rfsuite.config.userPreferences, rfsuite.userpref)
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
