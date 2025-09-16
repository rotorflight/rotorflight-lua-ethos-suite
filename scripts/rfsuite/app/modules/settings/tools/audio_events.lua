

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
        "@i18n(app.modules.settings.name)@" .. " / " .. "@i18n(app.modules.settings.audio)@" .. " / " .. "@i18n(app.modules.settings.txt_audio_events)@"
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
    local armPanel = form.addExpansionPanel("@i18n(app.modules.settings.arming_flags)@")
    armPanel:open(armEnabled)
    local armLine = armPanel:addLine("@i18n(app.modules.settings.arming_flags)@")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        armLine, nil,
        function() return config.armflags end,
        function(val) config.armflags = val end
    )

    -- Governor Panel
    local govEnabled = config.governor == true
    local govPanel = form.addExpansionPanel("@i18n(app.modules.settings.governor_state)@")
    govPanel:open(govEnabled)
    local govLine = govPanel:addLine("@i18n(app.modules.settings.governor_state)@")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        govLine, nil,
        function() return config.governor end,
        function(val) config.governor = val end
    )

    -- Voltage Low Alert Panel
    local voltEnabled = config.voltage == true
    local voltPanel = form.addExpansionPanel("@i18n(app.modules.settings.voltage)@")
    voltPanel:open(voltEnabled)
    local voltLine = voltPanel:addLine("@i18n(app.modules.settings.voltage)@")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        voltLine, nil,
        function() return config.voltage end,
        function(val) config.voltage = val end
    )

    -- Rates/PID Profile Panel
    local ratesEnabled = (config.pid_profile == true) or (config.rate_profile == true)
    local ratesPanel = form.addExpansionPanel("@i18n(app.modules.settings.pid_rates_profile)@")
    ratesPanel:open(ratesEnabled)
    local pidLine = ratesPanel:addLine("@i18n(app.modules.settings.pid_profile)@")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        pidLine, nil,
        function() return config.pid_profile end,
        function(val) config.pid_profile = val end
    )
    local rateLine = ratesPanel:addLine("@i18n(app.modules.settings.rate_profile)@")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        rateLine, nil,
        function() return config.rate_profile end,
        function(val) config.rate_profile = val end
    )

    -- ESC Temp Alert Panel
    local escEnabled = config.temp_esc == true
    local escPanel = form.addExpansionPanel("@i18n(app.modules.settings.esc_temperature)@")
    escPanel:open(escEnabled)
    local escEnable = escPanel:addLine("@i18n(app.modules.settings.esc_temperature)@")
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
    local escThresh = escPanel:addLine("@i18n(app.modules.settings.esc_threshold)@")
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

    -- Adjustments Panel
    local adjEnabled = (config.adj_f == true) or (config.adj_v == true)
    local adjPanel = form.addExpansionPanel("@i18n(app.modules.settings.adj_callouts)@")
    adjPanel:open(adjEnabled)

    -- Speak the adjust *function name* (e.g., "pitch", "rate", etc.)
    local adjFuncLine = adjPanel:addLine("@i18n(app.modules.settings.adj_function)@")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
    adjFuncLine, nil,
    function() return config.adj_f == true end,   -- default OFF
    function(val) config.adj_f = val end
    )

    -- Speak the adjust *value* (e.g., the number after you change it)
    local adjValueLine = adjPanel:addLine("@i18n(app.modules.settings.adj_value)@")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
    adjValueLine, nil,
    function() return config.adj_v == true end,   -- default OFF
    function(val) config.adj_v = val end
    )

    -- Smart Fuel Alert Panel
    local fuelEnabled = config.smartfuel == true
    local fuelPanel = form.addExpansionPanel("@i18n(app.modules.settings.fuel)@")
    fuelPanel:open(fuelEnabled)
    local fuelEnable = fuelPanel:addLine("@i18n(app.modules.settings.fuel)@")
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
        {"@i18n(app.modules.settings.fuel_callout_default)@", 0},
        {"@i18n(app.modules.settings.fuel_callout_5)@", 5},
        {"@i18n(app.modules.settings.fuel_callout_10)@", 10},
        {"@i18n(app.modules.settings.fuel_callout_20)@", 20},
        {"@i18n(app.modules.settings.fuel_callout_25)@", 25},
        {"@i18n(app.modules.settings.fuel_callout_50)@", 50},
    }
    local fuelThresh = fuelPanel:addLine("@i18n(app.modules.settings.fuel_callout_percent)@")
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

    local fuelRepeats = fuelPanel:addLine("@i18n(app.modules.settings.fuel_repeats_below)@")
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

    local fuelHaptic = fuelPanel:addLine("@i18n(app.modules.settings.fuel_haptic_below)@")
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
    rfsuite.app.ui.progressDisplay(nil,nil,true)
    rfsuite.app.ui.openPage(
        pageIdx,
        "@i18n(app.modules.settings.name)@",
        "settings/tools/audio.lua"
    )
end

local function onSaveMenu()
    local buttons = {
        {
            label  = "@i18n(app.btn_ok_long)@",
            action = function()
                local msg = "@i18n(app.modules.profile_select.save_prompt_local)@"
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
            label  = "@i18n(app.modules.profile_select.cancel)@",
            action = function()
                return true
            end,
        },
    }

    form.openDialog({
        width   = nil,
        title   = "@i18n(app.modules.profile_select.save_settings)@",
        message = "@i18n(app.modules.profile_select.save_prompt_local)@",
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
            "@i18n(app.modules.settings.name)@",
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
