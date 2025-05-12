local function sortSensorList(rawSensorList)
    local sensorList = {}
    for i, v in ipairs(rawSensorList) do
        if type(v.onchange) == "table" then
            sensorList[#sensorList + 1] = {key = i, name = v.name}
        end
    end

    table.sort(sensorList, function(a, b)
        return a.name:lower() < b.name:lower()
    end)
    return sensorList
end

local sensorList = sortSensorList(rfsuite.tasks.telemetry.listSensors())

local function openPage(pidx, title, script)
    enableWakeup = true
    rfsuite.app.triggers.closeProgressLoader = true

    form.clear()

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader(rfsuite.i18n.get("app.modules.settings.name"))

    rfsuite.session.formLineCnt = 0


    local alertpanel = form.addExpansionPanel(rfsuite.i18n.get("app.modules.settings.txt_telemetry_announcements"))
    alertpanel:open(false)
    for i, v in ipairs(sensorList) do

        rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
        rfsuite.app.formLines[rfsuite.session.formLineCnt] = alertpanel:addLine(v.name)
        rfsuite.app.formFields[v.key] = form.addBooleanField(rfsuite.app.formLines[rfsuite.session.formLineCnt], 
                                                            nil, 
                                                            function() 
                                                                    return value 
                                                            end, 
                                                            function(newValue) 
                                                                value = newValue 
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
