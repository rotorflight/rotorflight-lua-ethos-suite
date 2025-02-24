local activateWakeup = false

local mspapi = {
    api = {
        [1] = "RESCUE_PROFILE",
    },
    formdata = {
        labels = {
            {t = "Pull-up", label = 1, inline_size = 13.6},
            {t = "Climb",   label = 2, inline_size = 13.6},
            {t = "Hover",   label = 3, inline_size = 13.6},
            {t = "Flip",    label = 4, inline_size = 13.6},
            {t = "Gains",   label = 5, inline_size = 13.6},
            {t = "",        label = 6, inline_size = 40.15},
            {t = "",        label = 7, inline_size = 40.15}
        },
        fields = {
            {t = "Rescue mode enable", inline = 1, type = 1,  mspapi = 1, apikey = "rescue_mode"},
            {t = "Flip to upright",    inline = 1, type = 1,  mspapi = 1, apikey = "rescue_flip_mode"},
            -- Pull-up
            {t = "Collective",         inline = 2, label = 1, mspapi = 1, apikey = "rescue_pull_up_collective"},
            {t = "Time",               inline = 1, label = 1, mspapi = 1, apikey = "rescue_pull_up_time"},
            -- Climb
            {t = "Collective",         inline = 2, label = 2, mspapi = 1, apikey = "rescue_climb_collective"},
            {t = "Time",               inline = 1, label = 2, mspapi = 1, apikey = "rescue_climb_time"},
            -- Hover
            {t = "Collective",         inline = 2, label = 3, mspapi = 1, apikey = "rescue_hover_collective"},
            -- Flip
            {t = "Fail time",          inline = 2, label = 4, mspapi = 1, apikey = "rescue_flip_time"},
            {t = "Exit time",          inline = 1, label = 4, mspapi = 1, apikey = "rescue_exit_time"},
            {t = "Level",              inline = 2, label = 5, mspapi = 1, apikey = "rescue_level_gain"},
            {t = "Flip",               inline = 1, label = 5, mspapi = 1, apikey = "rescue_flip_gain"},
            -- Gains
            {t = "Rate",               inline = 1, label = 6, mspapi = 1, apikey = "rescue_max_setpoint_rate"},
            {t = "Accel",              inline = 1, label = 7, mspapi = 1, apikey = "rescue_max_setpoint_accel"}
        }
    }                 
}


local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function wakeup()

    if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then      
        if rfsuite.session.activeProfile ~= nil then
            rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " #" .. rfsuite.session.activeProfile)
        end
    end

end

return {
    mspapi = mspapi,
    title = "Rescue",
    reboot = false,
    refreshOnProfileChange = true,
    eepromWrite = true,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
