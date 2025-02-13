local labels = {}
local fields = {}

local activateWakeup = false
local currentProfileChecked = false

-- auto leveling settings
labels[#labels + 1] = {t = "Acro trainer", inline_size = 13.6, label = 11}
fields[#fields + 1] = {t = "Gain", inline = 2, label = 11, apikey = "trainer_gain"}
fields[#fields + 1] = {t = "Max", inline = 1, label = 11, apikey = "trainer_angle_limit"}

labels[#labels + 1] = {t = "Angle mode", inline_size = 13.6, label = 12}
fields[#fields + 1] = {t = "Gain", inline = 2, label = 12, apikey = "angle_level_strength"}
fields[#fields + 1] = {t = "Max", inline = 1, label = 12, apikey = "angle_level_limit"}

labels[#labels + 1] = {t = "Horizon mode", inline_size = 13.6, label = 13}
fields[#fields + 1] = {t = "Gain", inline = 2, label = 13, apikey = "horizon_level_strength"}

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
    mspapi = "PID_PROFILE",
    title = "Auto Level",
    refreshOnProfileChange = true,
    reboot = false,
    eepromWrite = true,
    labels = labels,
    fields = fields,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
