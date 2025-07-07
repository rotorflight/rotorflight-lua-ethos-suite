local i18n = rfsuite.i18n.get

local config = {}

local function sensorNameMap(sensorList)
    local nameMap = {}
    for _, sensor in ipairs(sensorList) do
        nameMap[sensor.key] = sensor.name
    end
    return nameMap
end

local function setFieldEnabled(field, enabled)
    if field and field.enable then field:enable(enabled) end
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
    rfsuite.app.formFields = {}

    -- Build event name map
    local eventList = rfsuite.tasks.events.telemetry.eventTable
    local eventNames = sensorNameMap(rfsuite.tasks.telemetry.listSensors())

    -- Prepare working config as a shallow copy of events preferences
    local savedEvents = rfsuite.preferences.events or {}
    for k, v in pairs(savedEvents) do config[k] = v end

    local escFields, becFields, fuelFields = {}, {}, {}

    -- Arming Flags Panel
    local armEnabled = config.armflags == true
    local armPanel = form.addExpansionPanel(i18n("Arming Flags"))
    armPanel:open(armEnabled)
    local armLine = armPanel:addLine(i18n("Arming Flags"))
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        armLine, nil,
        function() return config.armflags end,
        function(val) config.armflags = val end
    )

    -- Governor Panel
    local govEnabled = config.governor == true
    local govPanel = form.addExpansionPanel(i18n("Governor State"))
    govPanel:open(govEnabled)
    local govLine = govPanel:addLine(i18n("Governor State"))
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        govLine, nil,
        function() return config.governor end,
        function(val) config.governor = val end
    )

    -- Voltage Low Alert Panel
    local voltEnabled = config.voltage == true
    local voltPanel = form.addExpansionPanel(i18n("Voltage"))
    voltPanel:open(voltEnabled)
    local voltLine = voltPanel:addLine(i18n("Voltage"))
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        voltLine, nil,
        function() return config.voltage end,
        function(val) config.voltage = val end
    )

    -- Rates/PID Profile Panel
    local ratesEnabled = (config.pid_profile == true) or (config.rate_profile == true)
    local ratesPanel = form.addExpansionPanel(i18n("PID/Rates Profile"))
    ratesPanel:open(ratesEnabled)
    local pidLine = ratesPanel:addLine(i18n("PID Profile"))
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        pidLine, nil,
        function() return config.pid_profile end,
        function(val) config.pid_profile = val end
    )
    local rateLine = ratesPanel:addLine(i18n("Rates Profile"))
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        rateLine, nil,
        function() return config.rate_profile end,
        function(val) config.rate_profile = val end
    )

    -- ESC Temp Alert Panel
    local escEnabled = config.temp_esc == true
    local escPanel = form.addExpansionPanel(i18n("ESC Temperature"))
    escPanel:open(escEnabled)
    local escEnable = escPanel:addLine(i18n("ESC Temperature"))
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    escFields.enable = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        escEnable, nil,
        function() return config.temp_esc end,
        function(val)
            config.temp_esc = val
            setFieldEnabled(rfsuite.app.formFields[escFields.thresh], val)
        end
    )
    local escThresh = escPanel:addLine(i18n("Threshold (°)"))
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    escFields.thresh = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addNumberField(
        escThresh, nil, 60, 300,
        function() return config.escalertvalue or 90 end,
        function(val) config.escalertvalue = val end,
        1
    )
    rfsuite.app.formFields[formFieldCount]:suffix("°")
    setFieldEnabled(rfsuite.app.formFields[escFields.thresh], escEnabled)

    -- BEC Voltage Alert Panel
    local becEnabled = config.bec_voltage == true
    local becPanel = form.addExpansionPanel(i18n("BEC Voltage"))
    becPanel:open(becEnabled)
    local becEnable = becPanel:addLine(i18n("BEC Voltage"))
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    becFields.enable = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        becEnable, nil,
        function() return config.bec_voltage end,
        function(val)
            config.bec_voltage = val
            setFieldEnabled(rfsuite.app.formFields[becFields.thresh], val)
        end
    )
    local becThresh = becPanel:addLine(i18n("Threshold (V)"))
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    becFields.thresh = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addNumberField(
        becThresh, nil, 30, 130,
        function()
            local v = config.becalertvalue or 6.5
            return math.floor((v * 10) + 0.5)
        end,
        function(val)
            local new_val = val / 10
            config.becalertvalue = math.max(3.0, math.min(new_val, 13.0))
        end,
        1
    )
    rfsuite.app.formFields[formFieldCount]:decimals(1)
    rfsuite.app.formFields[formFieldCount]:suffix("V")
    setFieldEnabled(rfsuite.app.formFields[becFields.thresh], becEnabled)

    -- Smart Fuel Alert Panel
    local fuelEnabled = config.smartfuel == true
    local fuelPanel = form.addExpansionPanel(i18n("Fuel"))
    fuelPanel:open(fuelEnabled)
    local fuelEnable = fuelPanel:addLine(i18n("Fuel"))
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    fuelFields.enable = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        fuelEnable, nil,
        function() return config.smartfuel end,
        function(val)
            config.smartfuel = val
            setFieldEnabled(rfsuite.app.formFields[fuelFields.callout], val)
            setFieldEnabled(rfsuite.app.formFields[fuelFields.repeats], val)
            setFieldEnabled(rfsuite.app.formFields[fuelFields.haptic], val)
        end
    )
    local calloutChoices = {
        {"Default (Only at 10%)", 0},
        {"Every 10%", 10},
        {"Every 20%", 20},
        {"Every 25%", 25},
        {"Every 50%", 50},
    }
    local fuelThresh = fuelPanel:addLine(i18n("Callout %"))
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    fuelFields.callout = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(
        fuelThresh, nil,
        calloutChoices,
        function()
            local v = config.smartfuelcallout
            if v == nil or v == false then return 10 end
            return v
        end,
        function(val) config.smartfuelcallout = val end
    )
    setFieldEnabled(rfsuite.app.formFields[fuelFields.callout], fuelEnabled)

    local fuelRepeats = fuelPanel:addLine(i18n("Repeats below 0%"))
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    fuelFields.repeats = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addNumberField(
        fuelRepeats, nil, 1, 10,
        function() return config.smartfuelrepeats or 1 end,
        function(val) config.smartfuelrepeats = val end,
        1
    )
    rfsuite.app.formFields[formFieldCount]:suffix("x")
    setFieldEnabled(rfsuite.app.formFields[fuelFields.repeats], fuelEnabled)

    local fuelHaptic = fuelPanel:addLine(i18n("Haptic below 0%"))
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    fuelFields.haptic = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        fuelHaptic, nil,
        function() return config.smartfuelhaptic == true end,
        function(val) config.smartfuelhaptic = val end
    )
    setFieldEnabled(rfsuite.app.formFields[fuelFields.haptic], fuelEnabled)

    setFieldEnabled(rfsuite.app.formFields[escFields.enable], true)
    setFieldEnabled(rfsuite.app.formFields[becFields.enable], true)
    setFieldEnabled(rfsuite.app.formFields[fuelFields.enable], true)

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
