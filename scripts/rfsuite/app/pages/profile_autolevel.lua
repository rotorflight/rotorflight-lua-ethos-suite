local labels = {}
local fields = {}

local activateWakeup = false
local currentProfileChecked = false

-- auto leveling settings
labels[#labels + 1] = {t = "Acro trainer", inline_size = 13.6, label = 11}
fields[#fields + 1] = {t = "Gain", help = "profilesAcroTrainerGain", inline = 2, label = 11, min = 25, max = 255, default = 75, vals = {32}}
fields[#fields + 1] = {t = "Max", help = "profilesAcroTrainerLimit", inline = 1, label = 11, min = 10, max = 80, default = 20, unit = "°", vals = {33}}

labels[#labels + 1] = {t = "Angle mode", inline_size = 13.6, label = 12}
fields[#fields + 1] = {t = "Gain", help = "profilesAngleModeGain", inline = 2, label = 12, min = 0, max = 200, default = 40, vals = {29}}
fields[#fields + 1] = {t = "Max", help = "profilesAngleModeLimit", inline = 1, label = 12, min = 10, max = 90, default = 55, unit = "°", vals = {30}}

labels[#labels + 1] = {t = "Horizon mode", inline_size = 13.6, label = 13}
fields[#fields + 1] = {t = "Gain", help = "profilesHorizonModeGain", inline = 2, label = 13, min = 0, max = 200, default = 40, vals = {31}}

local function postLoad(self)
    rfsuite.app.triggers.isReady = true
    activateWakeup = true
end

local function wakeup()

    if activateWakeup == true and currentProfileChecked == false and rfsuite.bg.msp.mspQueue:isProcessed() then

        -- update active profile
        -- the check happens in postLoad          
        if rfsuite.config.activeProfile ~= nil then
            rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " #" .. rfsuite.config.activeProfile)
            currentProfileChecked = true
        end

    end

end

return {
    read = 94, -- msp_PID_PROFILE
    write = 95, -- msp_SET_PID_PROFILE
    title = "Auto Level",
    refreshOnProfileChange = true,
    reboot = false,
    eepromWrite = true,
    minBytes = 41,
    labels = labels,
    simulatorResponse = {3, 25, 250, 0, 12, 0, 1, 30, 30, 45, 50, 50, 100, 15, 15, 20, 2, 10, 10, 15, 100, 100, 5, 0, 30, 0, 25, 0, 40, 55, 40, 75, 20, 25, 0, 15, 45, 45, 15, 15, 20},
    fields = fields,
    postLoad = postLoad,
    wakeup = wakeup
}
