
local activateWakeup = false
local governorDisabledMsg = false



local apidata = {
        api = {
            [1] = 'GOVERNOR_PROFILE',
        },
        formdata = {
            labels = {
                {t = "@i18n(app.modules.profile_governor.gains)@",                label = 1, inline_size = 8.15},
                {t = "@i18n(app.modules.profile_governor.precomp)@",              label = 2, inline_size = 8.15},
                {t = "@i18n(app.modules.profile_governor.tail_torque_assist)@",   label = 3}
            },
            fields = {
                {t = "@i18n(app.modules.profile_governor.full_headspeed)@",          mspapi = 1, apikey = "governor_headspeed", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},   
                {t = "@i18n(app.modules.profile_governor.min_throttle)@",            mspapi = 1, apikey = "governor_min_throttle", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.max_throttle)@",            mspapi = 1, apikey = "governor_max_throttle", enablefunction = function() return (rfsuite.session.governorMode >=1 ) end},                    
                {t = "@i18n(app.modules.profile_governor.gain)@",                    mspapi = 1, apikey = "governor_gain", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.p)@",                       inline = 4, label = 1, mspapi = 1, apikey = "governor_p_gain", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.i)@",                       inline = 3, label = 1, mspapi = 1, apikey = "governor_i_gain", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.d)@",                       inline = 2, label = 1, mspapi = 1, apikey = "governor_d_gain", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.f)@",                       inline = 1, label = 1, mspapi = 1, apikey = "governor_f_gain", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.yaw)@",                     inline = 3, label = 2, mspapi = 1, apikey = "governor_yaw_ff_weight", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.cyc)@",                     inline = 2, label = 2, mspapi = 1, apikey = "governor_cyclic_ff_weight", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.col)@",                     inline = 1, label = 2, mspapi = 1, apikey = "governor_collective_ff_weight", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.tta_gain)@",                inline = 2, label = 3, mspapi = 1, apikey = "governor_tta_gain", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
                {t = "@i18n(app.modules.profile_governor.tta_limit)@",               inline = 1, label = 3, mspapi = 1, apikey = "governor_tta_limit", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
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
            rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " #" .. rfsuite.session.activeProfile)
        end

        if rfsuite.session.governorMode == 0 then
            if governorDisabledMsg == false then
                governorDisabledMsg = true

                -- disable save button
                rfsuite.app.formNavigationFields['save']:enable(false)
                -- disable reload button
                rfsuite.app.formNavigationFields['reload']:enable(false)
                -- add field to formFields
                rfsuite.app.formLines[#rfsuite.app.formLines + 1] = form.addLine("@i18n(app.modules.profile_governor.disabled_message)@")

            end
        end

    end

end

return {
    apidata = apidata,
    title = "@i18n(app.modules.profile_governor.name)@",
    reboot = false,
    refreshOnProfileChange = true,
    eepromWrite = true,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
