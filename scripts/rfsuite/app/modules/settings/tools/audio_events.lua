local settings = {}
local i18n = rfsuite.i18n.get

local function sensorNameMap(sensorList)
    local nameMap = {}
    for _, sensor in ipairs(sensorList) do
        nameMap[sensor.key] = sensor.name
    end
    return nameMap
end

local function openPage(pageIdx, title, script)
    enableWakeup = true
    rfsuite.app.triggers.closeProgressLoader = true
    form.clear()

    rfsuite.app.lastIdx    = pageIdx
    rfsuite.app.lastTitle  = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader(
        i18n("app.modules.settings.name") .. " / " .. i18n("app.modules.settings.audio") .. " / " .. i18n("app.modules.settings.txt_audio_events")
    )
    rfsuite.session.formLineCnt = 0

    local formFieldCount = 0

    local eventList = rfsuite.tasks.events.telemetry.eventTable
    local eventNames = sensorNameMap(rfsuite.tasks.telemetry.listSensors())

    settings = rfsuite.preferences.events

    for i, v in ipairs(eventList) do
    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = form.addLine(eventNames[v.sensor] or "unknown")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.session.formLineCnt], 
                                                        nil, 
                                                        function() 
                                                            if rfsuite.preferences and rfsuite.preferences.events then
                                                                return settings[v.sensor] 
                                                            end
                                                        end, 
                                                        function(newValue) 
                                                            if rfsuite.preferences and rfsuite.preferences.events then
                                                                settings[v.sensor] = newValue 
                                                            end    
                                                        end)
    end
  
end

local function onNavMenu()
    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(
        pageIdx,
        i18n("app.modules.settings.name"),
        "settings/tools/audio.lua"
    )
end

local function onSaveMenu()
    local buttons = {
        {
            label  = i18n("app.btn_ok_long"),
            action = function()
                local msg = i18n("app.modules.profile_select.save_prompt_local")
                rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))
                for key, value in pairs(settings) do
                    rfsuite.preferences.events[key] = value
                end
                rfsuite.ini.save_ini_file(
                    "SCRIPTS:/" .. rfsuite.config.preferences .. "/preferences.ini",
                    rfsuite.preferences
                )
                rfsuite.app.triggers.closeSave = true
                return true
            end,
        },
        {
            label  = i18n("app.modules.profile_select.cancel"),
            action = function()
                return true
            end,
        },
    }

    form.openDialog({
        width   = nil,
        title   = i18n("app.modules.profile_select.save_settings"),
        message = i18n("app.modules.profile_select.save_prompt_local"),
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
        i18n("app.modules.settings.name"),
        "settings/tools/audio.lua"
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
