local settings = {}
local i18n = rfsuite.i18n.get
local enableWakeup = false
local prevConnectedState = nil

local function openPage(pageIdx, title, script)
    enableWakeup = true
    if not rfsuite.app.navButtons then rfsuite.app.navButtons = {} end

    -- Determine connection state FIRST
    local connected = rfsuite.session.isConnected and rfsuite.session.mcu_id and rfsuite.preferences
    rfsuite.app.navButtons.save = connected and true or false
    rfsuite.app.triggers.closeProgressLoader = true

    form.clear()

    rfsuite.app.lastIdx    = pageIdx
    rfsuite.app.lastTitle  = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader(
        i18n("app.modules.settings.name") .. " / " .. i18n("app.modules.settings.audio") .. " / " .. i18n("app.modules.settings.txt_audio_timer")
    )

    rfsuite.app.formLineCnt = 0
    local formFieldCount = 0

    if not rfsuite.preferences.timer then rfsuite.preferences.timer = {} end
    settings = rfsuite.preferences.timer

    local intervalChoices = {
        { "10s", 10 },
        { "20s", 20 },
        { "30s", 30 }
    }
    local periodChoices = {
        { "30s", 30 },
        { "60s", 60 },
        { "90s", 90 }
    }

    local idxAudio, idxChoice, idxPre, idxPrePeriod, idxPreInterval, idxPost, idxPostPeriod, idxPostInterval

    -- Audio Alerting On/Off
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Timer Alerting")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        rfsuite.app.formLines[rfsuite.app.formLineCnt], nil,
        function() return settings.timeraudioenable or false end,
        function(newValue)
            settings.timeraudioenable = newValue
            rfsuite.app.formFields[idxChoice]:enable(newValue)
            rfsuite.app.formFields[idxPre]:enable(newValue)
            rfsuite.app.formFields[idxPost]:enable(newValue)
            rfsuite.app.formFields[idxPrePeriod]:enable(newValue and (settings.prealerton or false))
            rfsuite.app.formFields[idxPreInterval]:enable(newValue and (settings.prealerton or false))
            rfsuite.app.formFields[idxPostPeriod]:enable(newValue and (settings.postalerton or false))
            rfsuite.app.formFields[idxPostInterval]:enable(newValue and (settings.postalerton or false))
        end
    )
    idxAudio = formFieldCount

    -- Timer Elapsed Alert Mode (Choice)
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Timer Elapsed Alert")
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(
        rfsuite.app.formLines[rfsuite.app.formLineCnt], nil,
        {
            { "Beep", 0 },
            { "Multi Beep", 1 },
            { "Timer Elapsed", 2 },
            { "Timer Seconds", 3 },
        },
        function() return settings.elapsedalertmode or 0 end,
        function(newValue) settings.elapsedalertmode = newValue end
    )
    idxChoice = formFieldCount

    -- Pre-timer Alert Options Panel
    local prePanel = form.addExpansionPanel("Pre-timer Alert Options")
    prePanel:open(settings.prealerton or false)

    -- Pre-timer Alert On/Off
    formFieldCount = formFieldCount + 1
    idxPre = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        prePanel:addLine("Pre-timer Alert"), nil,
        function() return settings.prealerton or false end,
        function(newValue)
            settings.prealerton = newValue
            local audioEnabled = settings.timeraudioenable or false
            rfsuite.app.formFields[idxPrePeriod]:enable(audioEnabled and newValue)
            rfsuite.app.formFields[idxPreInterval]:enable(audioEnabled and newValue)
        end
    )

    -- Pre-timer Alert Period (Choice)
    formFieldCount = formFieldCount + 1
    idxPrePeriod = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(
        prePanel:addLine("Alert Period"), nil,
        periodChoices,
        function() return settings.prealertperiod or 30 end,
        function(newValue) settings.prealertperiod = newValue end
    )
    rfsuite.app.formFields[formFieldCount]:enable((settings.timeraudioenable or false) and (settings.prealerton or false))

    -- Pre-timer Alert Interval (Choice)
    formFieldCount = formFieldCount + 1
    idxPreInterval = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(
        prePanel:addLine("Alert Interval"), nil,
        intervalChoices,
        function() return settings.prealertinterval or 10 end,
        function(newValue) settings.prealertinterval = newValue end
    )
    rfsuite.app.formFields[formFieldCount]:enable((settings.timeraudioenable or false) and (settings.prealerton or false))

    -- Post-timer Alert Options Panel
    local postPanel = form.addExpansionPanel("Post-timer Alert Options")
    postPanel:open(settings.postalerton or false)

    -- Post-timer Alert On/Off
    formFieldCount = formFieldCount + 1
    idxPost = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        postPanel:addLine("Post-timer Alert"), nil,
        function() return settings.postalerton or false end,
        function(newValue)
            settings.postalerton = newValue
            local audioEnabled = settings.timeraudioenable or false
            rfsuite.app.formFields[idxPostPeriod]:enable(audioEnabled and newValue)
            rfsuite.app.formFields[idxPostInterval]:enable(audioEnabled and newValue)
        end
    )

    -- Post-timer Alert Period (Choice)
    formFieldCount = formFieldCount + 1
    idxPostPeriod = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(
        postPanel:addLine("Alert Period"), nil,
        periodChoices,
        function() return settings.postalertperiod or 60 end,
        function(newValue) settings.postalertperiod = newValue end
    )
    rfsuite.app.formFields[formFieldCount]:enable((settings.timeraudioenable or false) and (settings.postalerton or false))

    -- Post-timer Alert Interval (Choice)
    formFieldCount = formFieldCount + 1
    idxPostInterval = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(
        postPanel:addLine("Alert Interval"), nil,
        intervalChoices,
        function() return settings.postalertinterval or 10 end,
        function(newValue) settings.postalertinterval = newValue end
    )
    rfsuite.app.formFields[formFieldCount]:enable((settings.timeraudioenable or false) and (settings.postalerton or false))

    -- Grey out everything if not connected, and reliably hide Save
    if not connected then
        for i, field in ipairs(rfsuite.app.formFields) do
            if field and field.enable then field:enable(false) end
        end
        rfsuite.app.navButtons.save = false
    else
        rfsuite.app.formFields[idxChoice]:enable(settings.timeraudioenable or false)
        rfsuite.app.formFields[idxPre]:enable(settings.timeraudioenable or false)
        rfsuite.app.formFields[idxPrePeriod]:enable((settings.timeraudioenable or false) and (settings.prealerton or false))
        rfsuite.app.formFields[idxPreInterval]:enable((settings.timeraudioenable or false) and (settings.prealerton or false))
        rfsuite.app.formFields[idxPost]:enable(settings.timeraudioenable or false)
        rfsuite.app.formFields[idxPostPeriod]:enable((settings.timeraudioenable or false) and (settings.postalerton or false))
        rfsuite.app.formFields[idxPostInterval]:enable((settings.timeraudioenable or false) and (settings.postalerton or false))
        rfsuite.app.navButtons.save = true
    end
end

local function onSaveMenu()
    local buttons = {
        {
            label  = i18n("app.btn_ok_long"),
            action = function()
                local msg = i18n("app.modules.profile_select.save_prompt_local")
                rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))
                for key, value in pairs(settings) do
                    rfsuite.preferences.timer[key] = value
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
    if category == EVT_CLOSE and (value == 0 or value == 35) then
        rfsuite.app.ui.openPage(
            pageIdx,
            i18n("app.modules.settings.name"),
            "settings/tools/audio.lua"
        )
        return true
    end
end

local function wakeup()
    if not enableWakeup then return end

    local connected = rfsuite.session.isConnected and rfsuite.session.mcu_id and rfsuite.preferences
    if connected ~= prevConnectedState then
        -- Set enable/disable for all fields
        for i, field in ipairs(rfsuite.app.formFields) do
            if field and field.enable then field:enable(connected) end
        end
        rfsuite.app.navButtons.save = connected and true or false
        prevConnectedState = connected
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
}
