
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

    
    local alertpanel = form.addExpansionPanel(rfsuite.i18n.get("app.modules.settings.txt_telemetry_announcements"))
    alertpanel:open(false)
    for i, v in ipairs(eventList) do
        rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
        rfsuite.app.formLines[rfsuite.session.formLineCnt] = alertpanel:addLine(eventNames[v.sensor] or "unknown")
        rfsuite.app.formFields[i] = form.addBooleanField(rfsuite.app.formLines[rfsuite.session.formLineCnt], 
                                                            nil, 
                                                            function() 
                                                                if rfsuite.userpref and rfsuite.userpref.announcements then
                                                                    return rfsuite.userpref.announcements[v.sensor] 
                                                                end
                                                            end, 
                                                            function(newValue) 
                                                                if rfsuite.userpref and rfsuite.userpref.announcements then
                                                                    rfsuite.userpref.announcements[v.sensor] = newValue 
                                                                    rfsuite.utils.save_ini_file(rfsuite.config.userPreferences, rfsuite.userpref)
                                                                end    
                                                            end)
    end

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
