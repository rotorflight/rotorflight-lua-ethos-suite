local i18n = rfsuite.i18n.get

-- Local config table for in-memory edits
local config = {}

local function sensorNameMap(sensorList)
    local nameMap = {}
    for _, sensor in ipairs(sensorList) do
        nameMap[sensor.key] = sensor.name
    end
    return nameMap
end

local function openPage(pageIdx, title, script)
    enableWakeup = true
    if not rfsuite.app.navButtons then rfsuite.app.navButtons = {} end
    rfsuite.app.triggers.closeProgressLoader = true
    form.clear()

    rfsuite.app.lastIdx    = pageIdx
    rfsuite.app.lastTitle  = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader(
        i18n("app.modules.settings.name") .. " / " .. i18n("app.modules.settings.audio") .. " / " .. i18n("app.modules.settings.txt_audio_events")
    )
    rfsuite.app.formLineCnt = 0

    local formFieldCount = 0

    local eventList = rfsuite.tasks.events.telemetry.eventTable
    local eventNames = sensorNameMap(rfsuite.tasks.telemetry.listSensors())

    -- Prepare working config as a shallow copy of events preferences
    local saved = rfsuite.preferences.events or {}
    for k, v in pairs(saved) do
        config[k] = v
    end

    for i, v in ipairs(eventList) do
        formFieldCount = formFieldCount + 1
        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine(eventNames[v.sensor] or "unknown")
        rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
            rfsuite.app.formLines[rfsuite.app.formLineCnt],
            nil,
            function()
                return config[v.sensor]
            end,
            function(newValue)
                config[v.sensor] = newValue
            end
        )
    end

    -- Always enable all fields and Save
    for i, field in ipairs(rfsuite.app.formFields) do
        if field and field.enable then field:enable(true) end
    end
    rfsuite.app.navButtons.save = true
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
                for key, value in pairs(config) do
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
