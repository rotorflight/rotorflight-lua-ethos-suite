local activateWakeup = false
local currentProfileChecked = false


local mspapi = {
    api = {
        [1] = 'PID_PROFILE',
    },
    formdata = {
        labels = {
            {t = "Acro trainer", inline_size = 13.6, label = 1},
            {t = "Angle mode",   inline_size = 13.6, label = 2},
            {t = "Horizon mode", inline_size = 13.6, label = 3}
        },
        fields = {
            {t = "Gain", inline = 2, label = 1, mspapi = 1, apikey = "trainer_gain"},
            {t = "Max",  inline = 1, label = 1, mspapi = 1, apikey = "trainer_angle_limit"},
            {t = "Gain", inline = 2, label = 2, mspapi = 1, apikey = "angle_level_strength"},
            {t = "Max",  inline = 1, label = 2, mspapi = 1, apikey = "angle_level_limit"},
            {t = "Gain", inline = 2, label = 3, mspapi = 1, apikey = "horizon_level_strength"}
        }
    }
}


local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function wakeup()
    if activateWakeup and rfsuite.tasks.msp.mspQueue:isProcessed() then
        if rfsuite.session.activeProfile then
            rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " #" .. rfsuite.session.activeProfile)
            currentProfileChecked = true
        end
    end
end

return {
    mspapi = mspapi,
    title = "Auto Level",
    refreshOnProfileChange = true,
    reboot = false,
    eepromWrite = true,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
