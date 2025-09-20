local activateWakeup = false

local apidata = {
    api = {
        [1] = "RESCUE_PROFILE",
    },
    formdata = {
        labels = {
            {t = "@i18n(app.modules.profile_rescue.pull_up)@", label = 1, inline_size = 13.6},
            {t = "@i18n(app.modules.profile_rescue.climb)@",   label = 2, inline_size = 13.6},
            {t = "@i18n(app.modules.profile_rescue.hover)@",   label = 3, inline_size = 13.6},
            {t = "@i18n(app.modules.profile_rescue.flip)@",    label = 4, inline_size = 13.6},
            {t = "@i18n(app.modules.profile_rescue.gains)@",   label = 5, inline_size = 13.6},
            {t = "",        label = 6, inline_size = 40.15},
            {t = "",        label = 7, inline_size = 40.15}
        },
        fields = {
            {t = "@i18n(app.modules.profile_rescue.mode_enable)@", inline = 1, type = 1,  mspapi = 1, apikey = "rescue_mode"},
            {t = "@i18n(app.modules.profile_rescue.flip_upright)@",    inline = 1, type = 1,  mspapi = 1, apikey = "rescue_flip_mode"},
            -- Pull-up
            {t = "@i18n(app.modules.profile_rescue.collective)@",         inline = 2, label = 1, mspapi = 1, apikey = "rescue_pull_up_collective"},
            {t = "@i18n(app.modules.profile_rescue.time)@",               inline = 1, label = 1, mspapi = 1, apikey = "rescue_pull_up_time"},
            -- Climb
            {t = "@i18n(app.modules.profile_rescue.collective)@",         inline = 2, label = 2, mspapi = 1, apikey = "rescue_climb_collective"},
            {t = "@i18n(app.modules.profile_rescue.time)@",               inline = 1, label = 2, mspapi = 1, apikey = "rescue_climb_time"},
            -- Hover
            {t = "@i18n(app.modules.profile_rescue.collective)@",         inline = 2, label = 3, mspapi = 1, apikey = "rescue_hover_collective"},
            -- Flip
            {t = "@i18n(app.modules.profile_rescue.fail_time)@",          inline = 2, label = 4, mspapi = 1, apikey = "rescue_flip_time"},
            {t = "@i18n(app.modules.profile_rescue.exit_time)@",          inline = 1, label = 4, mspapi = 1, apikey = "rescue_exit_time"},
            {t = "@i18n(app.modules.profile_rescue.level_gain)@",              inline = 2, label = 5, mspapi = 1, apikey = "rescue_level_gain"},
            {t = "@i18n(app.modules.profile_rescue.flip)@",               inline = 1, label = 5, mspapi = 1, apikey = "rescue_flip_gain"},
            -- Gains
            {t = "@i18n(app.modules.profile_rescue.rate)@",               inline = 1, label = 6, mspapi = 1, apikey = "rescue_max_setpoint_rate"},
            {t = "@i18n(app.modules.profile_rescue.accel)@",              inline = 1, label = 7, mspapi = 1, apikey = "rescue_max_setpoint_accel"}
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
    apidata = apidata,
    title = "@i18n(app.modules.profile_rescue.name)@",
    reboot = false,
    refreshOnProfileChange = true,
    eepromWrite = true,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
