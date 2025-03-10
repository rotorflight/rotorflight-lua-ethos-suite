
local activateWakeup = false
local governorDisabledMsg = false


local mspapi = {
    api = {
        [1] = 'GOVERNOR_PROFILE',
    },
    formdata = {
        labels = {
            {t = "Gains",                label = 1, inline_size = 8.15},
            {t = "Precomp",              label = 2, inline_size = 8.15},
            {t = "Tail Torque Assist",   label = 3}
        },
        fields = {
            {t = "Full headspeed",          mspapi = 1, apikey = "governor_headspeed", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},   
            {t = "Min throttle",            mspapi = 1, apikey = "governor_min_throttle", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
            {t = "Max throttle",            mspapi = 1, apikey = "governor_max_throttle", enablefunction = function() return (rfsuite.session.governorMode >=1 ) end},                    
            {t = "PID master gain",         mspapi = 1, apikey = "governor_gain", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
            {t = "P",                       inline = 4, label = 1, mspapi = 1, apikey = "governor_p_gain", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
            {t = "I",                       inline = 3, label = 1, mspapi = 1, apikey = "governor_i_gain", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
            {t = "D",                       inline = 2, label = 1, mspapi = 1, apikey = "governor_d_gain", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
            {t = "F",                       inline = 1, label = 1, mspapi = 1, apikey = "governor_f_gain", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
            {t = "Yaw",                     inline = 3, label = 2, mspapi = 1, apikey = "governor_yaw_ff_weight", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
            {t = "Cyc",                     inline = 2, label = 2, mspapi = 1, apikey = "governor_cyclic_ff_weight", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
            {t = "Col",                     inline = 1, label = 2, mspapi = 1, apikey = "governor_collective_ff_weight", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
            {t = "Gain",                    inline = 2, label = 3, mspapi = 1, apikey = "governor_tta_gain", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
            {t = "Limit",                   inline = 1, label = 3, mspapi = 1, apikey = "governor_tta_limit", enablefunction = function() return (rfsuite.session.governorMode >=2 ) end},
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
                rfsuite.app.formLines[#rfsuite.app.formLines + 1] = form.addLine("Rotorflight governor is not enabled")

            end
        end

    end

end

return {
    mspapi = mspapi,
    title = "Governor",
    reboot = false,
    refreshOnProfileChange = true,
    eepromWrite = true,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
