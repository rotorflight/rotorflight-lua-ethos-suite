
local enableWakeup = false

-- Local config table for in-memory edits
local config = {}

local function openPage(pageIdx, title, script)
    enableWakeup = true
    if not rfsuite.app.navButtons then rfsuite.app.navButtons = {} end
    rfsuite.app.triggers.closeProgressLoader = true

    form.clear()

    rfsuite.app.lastIdx    = pageIdx
    rfsuite.app.lastTitle  = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader(
        "@i18n(app.modules.settings.name)@" .. " / " .. "@i18n(app.modules.settings.audio)@" .. " / " .. "@i18n(app.modules.settings.txt_audio_timer)@"
    )

    rfsuite.app.formLineCnt = 0
    local formFieldCount = 0

    -- Prepare working config as a shallow copy of timer preferences
    local saved = rfsuite.preferences.timer or {}
    for k, v in pairs(saved) do
        config[k] = v
    end

    local intervalChoices = {
        { "10s", 10 },
        { "15s", 15 },
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
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("@i18n(app.modules.settings.timer_alerting)@")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        rfsuite.app.formLines[rfsuite.app.formLineCnt], nil,
        function() return config.timeraudioenable or false end,
        function(newValue)
            config.timeraudioenable = newValue
            rfsuite.app.formFields[idxChoice]:enable(newValue)
            rfsuite.app.formFields[idxPre]:enable(newValue)
            rfsuite.app.formFields[idxPost]:enable(newValue)
            rfsuite.app.formFields[idxPrePeriod]:enable(newValue and (config.prealerton or false))
            rfsuite.app.formFields[idxPreInterval]:enable(newValue and (config.prealerton or false))
            rfsuite.app.formFields[idxPostPeriod]:enable(newValue and (config.postalerton or false))
            rfsuite.app.formFields[idxPostInterval]:enable(newValue and (config.postalerton or false))
        end
    )
    idxAudio = formFieldCount

    -- Timer Elapsed Alert Mode (Choice)
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("@i18n(app.modules.settings.timer_elapsed_alert_mode)@")
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(
        rfsuite.app.formLines[rfsuite.app.formLineCnt], nil,
        {
            { "Beep", 0 },
            { "Multi Beep", 1 },
            { "Timer Elapsed", 2 },
            { "Timer Seconds", 3 },
        },
        function() return config.elapsedalertmode or 0 end,
        function(newValue) config.elapsedalertmode = newValue end
    )
    idxChoice = formFieldCount

    -- Pre-timer Alert Options Panel
    local prePanel = form.addExpansionPanel("@i18n(app.modules.settings.timer_prealert_options)@")
    prePanel:open(config.prealerton or false)

    -- Pre-timer Alert On/Off
    formFieldCount = formFieldCount + 1
    idxPre = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        prePanel:addLine("@i18n(app.modules.settings.timer_prealert)@"), nil,
        function() return config.prealerton or false end,
        function(newValue)
            config.prealerton = newValue
            local audioEnabled = config.timeraudioenable or false
            rfsuite.app.formFields[idxPrePeriod]:enable(audioEnabled and newValue)
            rfsuite.app.formFields[idxPreInterval]:enable(audioEnabled and newValue)
        end
    )

    -- Pre-timer Alert Period (Choice)
    formFieldCount = formFieldCount + 1
    idxPrePeriod = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(
        prePanel:addLine("@i18n(app.modules.settings.timer_alert_period)@"), nil,
        periodChoices,
        function() return config.prealertperiod or 30 end,
        function(newValue) config.prealertperiod = newValue end
    )
    rfsuite.app.formFields[formFieldCount]:enable((config.timeraudioenable or false) and (config.prealerton or false))

    -- Pre-timer Alert Interval (Choice)
    formFieldCount = formFieldCount + 1
    idxPreInterval = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(
        prePanel:addLine("Alert Interval"), nil,
        intervalChoices,
        function() return config.prealertinterval or 10 end,
        function(newValue) config.prealertinterval = newValue end
    )
    rfsuite.app.formFields[formFieldCount]:enable((config.timeraudioenable or false) and (config.prealerton or false))

    -- Post-timer Alert Options Panel
    local postPanel = form.addExpansionPanel("@i18n(app.modules.settings.timer_postalert_options)@")
    postPanel:open(config.postalerton or false)

    -- Post-timer Alert On/Off
    formFieldCount = formFieldCount + 1
    idxPost = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        postPanel:addLine("@i18n(app.modules.settings.timer_postalert)@"), nil,
        function() return config.postalerton or false end,
        function(newValue)
            config.postalerton = newValue
            local audioEnabled = config.timeraudioenable or false
            rfsuite.app.formFields[idxPostPeriod]:enable(audioEnabled and newValue)
            rfsuite.app.formFields[idxPostInterval]:enable(audioEnabled and newValue)
        end
    )

    -- Post-timer Alert Period (Choice)
    formFieldCount = formFieldCount + 1
    idxPostPeriod = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(
        postPanel:addLine("@i18n(app.modules.settings.timer_alert_period)@"), nil,
        periodChoices,
        function() return config.postalertperiod or 60 end,
        function(newValue) config.postalertperiod = newValue end
    )
    rfsuite.app.formFields[formFieldCount]:enable((config.timeraudioenable or false) and (config.postalerton or false))

    -- Post-timer Alert Interval (Choice)
    formFieldCount = formFieldCount + 1
    idxPostInterval = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(
        postPanel:addLine("@i18n(app.modules.settings.timer_postalert_interval)@"), nil,
        intervalChoices,
        function() return config.postalertinterval or 10 end,
        function(newValue) config.postalertinterval = newValue end
    )
    rfsuite.app.formFields[formFieldCount]:enable((config.timeraudioenable or false) and (config.postalerton or false))

    -- Set initial enabled state based on current config
    rfsuite.app.formFields[idxChoice]:enable(config.timeraudioenable or false)
    rfsuite.app.formFields[idxPre]:enable(config.timeraudioenable or false)
    rfsuite.app.formFields[idxPrePeriod]:enable((config.timeraudioenable or false) and (config.prealerton or false))
    rfsuite.app.formFields[idxPreInterval]:enable((config.timeraudioenable or false) and (config.prealerton or false))
    rfsuite.app.formFields[idxPost]:enable(config.timeraudioenable or false)
    rfsuite.app.formFields[idxPostPeriod]:enable((config.timeraudioenable or false) and (config.postalerton or false))
    rfsuite.app.formFields[idxPostInterval]:enable((config.timeraudioenable or false) and (config.postalerton or false))
    rfsuite.app.navButtons.save = true
end

local function onSaveMenu()
    local buttons = {
        {
            label  = "@i18n(app.btn_ok_long)@",
            action = function()
                local msg = "@i18n(app.modules.profile_select.save_prompt_local)@"
                rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))
                for key, value in pairs(config) do
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

local function onNavMenu()
    rfsuite.app.ui.progressDisplay(nil,nil,true)
    rfsuite.app.ui.openPage(
        pageIdx,
        "@i18n(app.modules.settings.name)@",
        "settings/tools/audio.lua"
    )
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
