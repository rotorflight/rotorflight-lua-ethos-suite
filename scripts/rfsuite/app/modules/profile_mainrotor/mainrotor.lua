local activateWakeup = false


local apidata = {
    api = {
        [1] = 'PID_PROFILE',
    },
    formdata = {
        labels = {
            {t = "@i18n(app.modules.profile_mainrotor.collective_pitch_comp)@", t2 = "@i18n(app.modules.profile_mainrotor.collective_pitch_comp_short)@", label = 1,  inline_size = 40.15},
            {t = "@i18n(app.modules.profile_mainrotor.cyclic_cross_coupling)@",                                         label = 2,  inline_size = 40.15},
            {t = "",                                                              label = 3,  inline_size = 40.15},
            {t = "",                                                              label = 4,  inline_size = 40.15}

        },
        fields = {
            {t = "",      inline = 1, label = 1, mspapi = 1, apikey = "pitch_collective_ff_gain"},
            {t = "@i18n(app.modules.profile_mainrotor.gain)@",  inline = 1, label = 2, mspapi = 1, apikey = "cyclic_cross_coupling_gain"},
            {t = "@i18n(app.modules.profile_mainrotor.ratio)@", inline = 1, label = 3, mspapi = 1, apikey = "cyclic_cross_coupling_ratio"},
            {t = "@i18n(app.modules.profile_mainrotor.cutoff)@",inline = 1, label = 4, mspapi = 1, apikey = "cyclic_cross_coupling_cutoff"}
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
    title = "@i18n(app.modules.profile_mainrotor.name)@",
    refreshOnProfileChange = true,
    reboot = false,
    eepromWrite = true,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
