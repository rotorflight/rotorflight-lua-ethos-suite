local activateWakeup = false
local currentProfileChecked = false


local apidata = {
    api = {
        [1] = "PID_PROFILE",
    },
    formdata = {
        labels = {
            { t = "@i18n(app.modules.profile_tailrotor.collective_impulse_ff)@",  label = 3, inline_size = 13.6, apiversionlte = 12.07 },
            { t = "@i18n(app.modules.profile_tailrotor.yaw_stop_gain)@",          label = 1, inline_size = 13.6 },           
        },
        fields = {
            { t = "@i18n(app.modules.profile_tailrotor.cyclic_ff_gain)@",        mspapi = 1, apikey = "yaw_cyclic_ff_gain" },
            { t = "@i18n(app.modules.profile_tailrotor.collective_ff_gain)@",    mspapi = 1, apikey = "yaw_collective_ff_gain" },
            -- Yaw stop gain
            { t = "@i18n(app.modules.profile_tailrotor.cw)@",                    inline = 2, label = 1, mspapi = 1, apikey = "yaw_cw_stop_gain" },
            { t = "@i18n(app.modules.profile_tailrotor.ccw)@",                   inline = 1, label = 1, mspapi = 1, apikey = "yaw_ccw_stop_gain" },           
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
    title = "@i18n(app.modules.profile_tailrotor.name)@",
    refreshOnProfileChange = true,
    reboot = false,
    eepromWrite = true,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
