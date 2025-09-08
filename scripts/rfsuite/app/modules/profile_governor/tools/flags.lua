
local activateWakeup = false
local governorDisabledMsg = false
local i18n = rfsuite.i18n.get


local apidata = {
        api = {
            [1] = 'GOVERNOR_PROFILE',
        },
        formdata = {
            labels = {

            },
            fields = {
                {t = i18n("app.modules.profile_governor.fc_throttle_curve"),       mspapi = 1, apikey = "governor_flags->fc_throttle_curve", type = 1},
                {t = i18n("app.modules.profile_governor.tx_precomp_curve"),       mspapi = 1, apikey = "governor_flags->tx_precomp_curve", type = 1},
                {t = i18n("app.modules.profile_governor.fallback_precomp"),       mspapi = 1, apikey = "governor_flags->fallback_precomp", type = 1},
                {t = i18n("app.modules.profile_governor.voltage_comp"),           mspapi = 1, apikey = "governor_flags->voltage_comp", type = 1},
                {t = i18n("app.modules.profile_governor.pid_spoolup"),            mspapi = 1, apikey = "governor_flags->pid_spoolup", type = 1},
                {t = i18n("app.modules.profile_governor.hs_adjustment"),          mspapi = 1, apikey = "governor_flags->hs_adjustment", type = 1},
                {t = i18n("app.modules.profile_governor.dyn_min_throttle"),       mspapi = 1, apikey = "governor_flags->dyn_min_throttle", type = 1},
                {t = i18n("app.modules.profile_governor.autorotation"),           mspapi = 1, apikey = "governor_flags->autorotation", type = 1},
                {t = i18n("app.modules.profile_governor.suspend"),                mspapi = 1, apikey = "governor_flags->suspend", type = 1},
                {t = i18n("app.modules.profile_governor.bypass"),                 mspapi = 1, apikey = "governor_flags->bypass", type = 1},
            }
        }
    }


local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function wakeup()

    if activateWakeup == true  and rfsuite.tasks.msp.mspQueue:isProcessed() then

        -- update active profile
        -- the check happens in postLoad          
        if rfsuite.session.activeProfile ~= nil then
            rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .." / " .. i18n("app.modules.governor.menu_flags") .. " #" .. rfsuite.session.activeProfile)
        end

        if rfsuite.session.governorMode == 0 then
            if governorDisabledMsg == false then
                governorDisabledMsg = true

                -- disable save button
                rfsuite.app.formNavigationFields['save']:enable(false)
                -- disable reload button
                rfsuite.app.formNavigationFields['reload']:enable(false)
                -- add field to formFields
                rfsuite.app.formLines[#rfsuite.app.formLines + 1] = form.addLine(i18n("app.modules.profile_governor.disabled_message"))

            end
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
    title = i18n("app.modules.profile_governor.name"),
    reboot = false,
    event = event,
    onNavMenu = onNavMenu,
    refreshOnProfileChange = true,
    eepromWrite = true,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
