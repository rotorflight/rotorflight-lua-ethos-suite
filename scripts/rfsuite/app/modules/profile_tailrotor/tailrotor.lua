local activateWakeup = false
local i18n = rfsuite.i18n.get

local apidata = {
    api = {
        [1] = "PID_PROFILE",
    },
    formdata = {
        labels = {
            { t = i18n("app.modules.profile_tailrotor.inertia_precomp"),        label = 2, inline_size = 13.6, apiversiongte = 12.08 },
            { t = i18n("app.modules.profile_tailrotor.collective_impulse_ff"),  label = 3, inline_size = 13.6, apiversionlte = 12.07 },
        },
        fields = {
            { t = i18n("app.modules.profile_tailrotor.precomp_cutoff"),        mspapi = 1, apikey = "yaw_precomp_cutoff" },

            -- Collective Impulse FF
            -- gt 12.08
            { t = i18n("app.modules.profile_tailrotor.gain"),                  inline = 2, label = 2, mspapi = 1, apikey = "yaw_inertia_precomp_gain", apiversiongte = 12.08 },
            { t = i18n("app.modules.profile_tailrotor.cutoff"),                inline = 1, label = 2, mspapi = 1, apikey = "yaw_inertia_precomp_cutoff", apiversiongte = 12.08 },
            -- lt 12.07
            { t = i18n("app.modules.profile_tailrotor.gain"),                  inline = 2, label = 3, mspapi = 1, apikey = "yaw_collective_dynamic_gain",  apiversionlte = 12.07 },
            { t = i18n("app.modules.profile_tailrotor.decay"),                 inline = 1, label = 3, mspapi = 1, apikey = "yaw_collective_dynamic_decay", apiversionlte = 12.07 },
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
            currentProfileChecked = true
        end
    end

end

return {
    apidata = apidata,
    title = i18n("app.modules.profile_tailrotor.name"),
    refreshOnProfileChange = true,
    reboot = false,
    eepromWrite = true,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
