local activateWakeup = false


local mspapi = {
    api = {
        [1] = "PID_PROFILE",
    },
    formdata = {
        labels = {
            { t = "Yaw stop gain",          label = 1, inline_size = 13.6 },
            { t = "Inertia Precomp",        label = 2, inline_size = 13.6, apiversiongte = 12.08 },
            { t = "Collective Impulse FF",  label = 3, inline_size = 13.6, apiversionlte = 12.07 },
        },
        fields = {
            { t = "CW",                    inline = 2, label = 1, mspapi = 1, apikey = "yaw_cw_stop_gain" },
            { t = "CCW",                   inline = 1, label = 1, mspapi = 1, apikey = "yaw_ccw_stop_gain" },
            { t = "Precomp Cutoff",        mspapi = 1, apikey = "yaw_precomp_cutoff" },
            { t = "Cyclic FF gain",        mspapi = 1, apikey = "yaw_cyclic_ff_gain" },
            { t = "Collective FF gain",    mspapi = 1, apikey = "yaw_collective_ff_gain" },
            -- gt 12.08
            { t = "Gain",                  inline = 2, label = 2, mspapi = 1, apikey = "yaw_inertia_precomp_gain", apiversiongte = 12.08 },
            { t = "Cutoff",                inline = 1, label = 2, mspapi = 1, apikey = "yaw_inertia_precomp_cutoff", apiversiongte = 12.08 },
            -- lt 12.07
            { t = "Gain",                  inline = 2, label = 3, mspapi = 1, apikey = "yaw_collective_dynamic_gain",  apiversionlte = 12.07 },
            { t = "Decay",                 inline = 1, label = 3, mspapi = 1, apikey = "yaw_collective_dynamic_decay", apiversionlte = 12.07 }
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
    mspapi = mspapi,
    title = "Tail Rotor",
    refreshOnProfileChange = true,
    reboot = false,
    eepromWrite = true,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
