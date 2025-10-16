
local rfsuite = require("rfsuite") 

local activateWakeup = false
local governorDisabledMsg = false


-- Fields from apidata->formdata->fields
-- If you change the order in apidata->formdata->fields you must change these too
local FIELD_TX_PRECOMP_CURVE      = 1
local FIELD_HS_ADJUSTMENT         = 2
local FIELD_FALLBACK_PRECOMP      = 3
local FIELD_PID_SPOOLUP           = 4
local FIELD_VOLTAGE_COMP          = 5
local FIELD_DYN_MIN_THROTTLE      = 6
local FIELD_AUTOROTATION          = 7
local FIELD_SUSPEND               = 8
local FIELD_BYPASS                = 9



local apidata = {
        api = {
            [1] = 'GOVERNOR_PROFILE',
        },
        formdata = {
            labels = {

            },
            fields = {
                {t = "@i18n(app.modules.profile_governor.tx_precomp_curve)@",       mspapi = 1, apikey = "governor_flags->tx_precomp_curve", type = 4},
                {t = "@i18n(app.modules.profile_governor.hs_adjustment)@",          mspapi = 1, apikey = "governor_flags->hs_adjustment", type = 4},
                {t = "@i18n(app.modules.profile_governor.fallback_precomp)@",       mspapi = 1, apikey = "governor_flags->fallback_precomp", type = 4},
                {t = "@i18n(app.modules.profile_governor.pid_spoolup)@",            mspapi = 1, apikey = "governor_flags->pid_spoolup", type = 4},
                {t = "@i18n(app.modules.profile_governor.voltage_comp)@",           mspapi = 1, apikey = "governor_flags->voltage_comp", type = 4},
                {t = "@i18n(app.modules.profile_governor.dyn_min_throttle)@",       mspapi = 1, apikey = "governor_flags->dyn_min_throttle", type = 4},
                {t = "@i18n(app.modules.profile_governor.autorotation)@",           mspapi = 1, apikey = "governor_flags->autorotation", type = 4},
                {t = "@i18n(app.modules.profile_governor.suspend)@",                mspapi = 1, apikey = "governor_flags->suspend", type = 4},
                {t = "@i18n(app.modules.profile_governor.bypass)@",                 mspapi = 1, apikey = "governor_flags->bypass", type = 4},

            }
        }
    }


local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function wakeup()
    if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then
        -- update active profile title
        if rfsuite.session.activeProfile ~= nil then
            rfsuite.app.formFields['title']:value(
                rfsuite.app.Page.title .." / ".. "@i18n(app.modules.governor.menu_flags)@" .. " #" .. rfsuite.session.activeProfile
            )
        end

        -- governor disabled message / buttons
        if rfsuite.session.governorMode == 0 then
            if governorDisabledMsg == false then
                governorDisabledMsg = true
                rfsuite.app.formNavigationFields['save']:enable(false)
                rfsuite.app.formNavigationFields['reload']:enable(false)
                rfsuite.app.formLines[#rfsuite.app.formLines + 1] =
                    form.addLine("@i18n(app.modules.profile_governor.disabled_message)@")
            end
        end

        -- read current values once
        local bypass       = (rfsuite.app.Page.fields[FIELD_BYPASS].value == 1)
        local txPrecomp    = (rfsuite.app.Page.fields[FIELD_TX_PRECOMP_CURVE].value == 1)
        local pidSpoolup   = (rfsuite.app.Page.fields[FIELD_PID_SPOOLUP].value == 1)
        local adcVoltage   = (rfsuite.session.batteryConfig.voltageMeterSource == 1)

        -- 1) Highest priority: BYPASS ON disables everything and exits early
        if bypass then
            rfsuite.app.formFields[FIELD_TX_PRECOMP_CURVE]:enable(false)
            rfsuite.app.formFields[FIELD_HS_ADJUSTMENT]:enable(false)
            rfsuite.app.formFields[FIELD_FALLBACK_PRECOMP]:enable(false)
            rfsuite.app.formFields[FIELD_PID_SPOOLUP]:enable(false)
            rfsuite.app.formFields[FIELD_VOLTAGE_COMP]:enable(false)
            rfsuite.app.formFields[FIELD_DYN_MIN_THROTTLE]:enable(false)
            rfsuite.app.formFields[FIELD_AUTOROTATION]:enable(false)
            rfsuite.app.formFields[FIELD_SUSPEND]:enable(false)
            return
        end

        -- 2) Baseline for non-bypass case: enable everything first
        rfsuite.app.formFields[FIELD_TX_PRECOMP_CURVE]:enable(true)
        rfsuite.app.formFields[FIELD_HS_ADJUSTMENT]:enable(true)
        rfsuite.app.formFields[FIELD_FALLBACK_PRECOMP]:enable(true)
        rfsuite.app.formFields[FIELD_PID_SPOOLUP]:enable(true)
        rfsuite.app.formFields[FIELD_VOLTAGE_COMP]:enable(true)  -- will refine just below
        rfsuite.app.formFields[FIELD_DYN_MIN_THROTTLE]:enable(true)
        rfsuite.app.formFields[FIELD_AUTOROTATION]:enable(true)
        rfsuite.app.formFields[FIELD_SUSPEND]:enable(true)

        -- 3) Voltage comp allowed only if voltage meter source == ADC
        rfsuite.app.formFields[FIELD_VOLTAGE_COMP]:enable(adcVoltage)

        -- 4) TX precomp ON excludes HS adj, fallback precomp, and PID spoolup
        if txPrecomp then
            rfsuite.app.formFields[FIELD_HS_ADJUSTMENT]:enable(false)
            rfsuite.app.formFields[FIELD_FALLBACK_PRECOMP]:enable(false)
            rfsuite.app.formFields[FIELD_PID_SPOOLUP]:enable(false)
        end

        -- 5) If TX precomp is OFF and PID spoolup is ON, then disable TX precomp
        if (not txPrecomp) and pidSpoolup then
            rfsuite.app.formFields[FIELD_TX_PRECOMP_CURVE]:enable(false)
        end
    end
end


local function event(widget, category, value, x, y)
    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage(pidx, title, "profile_governor/governor.lua")  
        return true
    end
end


local function onNavMenu()
    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(pidx, title, "profile_governor/governor.lua")  
    return true
end

return {
    apidata = apidata,
    title = "@i18n(app.modules.profile_governor.name)@",
    reboot = false,
    event = event,
    onNavMenu = onNavMenu,
    refreshOnProfileChange = true,
    eepromWrite = true,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
