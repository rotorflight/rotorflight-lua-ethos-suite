local activateWakeup = false

local mspapi = {
    api = {
        [1] = "PID_PROFILE",
    },
    formdata = {
        labels = {
            {t = "PID Bandwidth", inline_size = 8.15, label = 1, type = 1},
            {t = "D-term cut-off", inline_size = 8.15, label = 2, type = 1},
            {t = "B-term cut-off", inline_size = 8.15, label = 3, type = 1}
        },
        fields = {
            {t = "R", inline = 3, label = 1, mspapi = 1, apikey = "gyro_cutoff_0"},
            {t = "P", inline = 2, label = 1, mspapi = 1, apikey = "gyro_cutoff_1"},
            {t = "Y", inline = 1, label = 1, mspapi = 1, apikey = "gyro_cutoff_2"},
            {t = "R", inline = 3, label = 2, mspapi = 1, apikey = "dterm_cutoff_0"},
            {t = "P", inline = 2, label = 2, mspapi = 1, apikey = "dterm_cutoff_1"},
            {t = "Y", inline = 1, label = 2, mspapi = 1, apikey = "dterm_cutoff_2"},
            {t = "R", inline = 3, label = 3, mspapi = 1, apikey = "bterm_cutoff_0"},
            {t = "P", inline = 2, label = 3, mspapi = 1, apikey = "bterm_cutoff_1"},
            {t = "Y", inline = 1, label = 3, mspapi = 1, apikey = "bterm_cutoff_2"}
        }
    }                 
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function wakeup()

    if activateWakeup and rfsuite.bg.msp.mspQueue:isProcessed() then       
        if rfsuite.session.activeProfile then
            rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " #" .. rfsuite.session.activeProfile)
            currentProfileChecked = true
        end
    end

end

return {
    mspapi = mspapi,
    title = "PID Bandwidth",
    refreshOnProfileChange = true,
    reboot = false,
    eepromWrite = true,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
