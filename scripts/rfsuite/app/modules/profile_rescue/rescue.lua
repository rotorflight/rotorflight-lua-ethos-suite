local labels = {}
local fields = {}

local activateWakeup = false
local currentProfileChecked = false

fields[#fields + 1] = {t = "Rescue mode enable", type = 1, apikey = "rescue_mode"}
fields[#fields + 1] = {t = "Flip to upright", help = "profilesRescueFlipMode", type = 1, apikey = "rescue_flip_mode"}

labels[#labels + 1] = {t = "Pull-up", label = "pullup", inline_size = 13.6}
fields[#fields + 1] = {t = "Collective", help = "profilesRescuePullupCollective", inline = 2, label = "pullup", apikey = "rescue_pull_up_collective"}
fields[#fields + 1] = {t = "Time", help = "profilesRescuePullupTime", inline = 1, label = "pullup", apikey = "rescue_pull_up_time"}

labels[#labels + 1] = {t = "Climb", label = "climb", inline_size = 13.6}
fields[#fields + 1] = {t = "Collective", help = "profilesRescueClimbCollective", inline = 2, label = "climb", apikey = "rescue_climb_collective"}
fields[#fields + 1] = {t = "Time", help = "profilesRescueClimbTime", inline = 1, label = "climb", apikey = "rescue_climb_time"}

labels[#labels + 1] = {t = "Hover", label = "hover", inline_size = 13.6}
fields[#fields + 1] = {t = "Collective", help = "profilesRescueHoverCollective", inline = 2, label = "hover", apikey = "rescue_hover_collective"}

labels[#labels + 1] = {t = "Flip", label = "flip", inline_size = 13.6}
fields[#fields + 1] = {t = "Fail time", help = "profilesRescueFlipTime", inline = 2, label = "flip", apikey = "rescue_flip_time"}
fields[#fields + 1] = {t = "Exit time", help = "profilesRescueExitTime", inline = 1, label = "flip", apikey = "rescue_exit_time"}

labels[#labels + 1] = {t = "Gains", label = "rescue", inline_size = 13.6}
fields[#fields + 1] = {t = "Level", help = "profilesRescueLevelGain", label = "rescue", inline = 2, apikey = "rescue_level_gain"}
fields[#fields + 1] = {t = "Flip", help = "profilesRescueFlipGain", label = "rescue", inline = 1, apikey = "rescue_flip_gain"}

labels[#labels + 1] = {t = "", label = "rescue2", inline_size = 40.15}
fields[#fields + 1] = {t = "Rate", help = "profilesRescueMaxRate", label = "rescue2", inline = 1, apikey = "rescue_max_setpoint_rate"}

labels[#labels + 1] = {t = "", label = "rescue3", inline_size = 40.15}
fields[#fields + 1] = {t = "Accel", help = "profilesRescueMaxAccel", label = "rescue3", inline = 1, apikey = "rescue_max_setpoint_accel"}

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
    mspapi = "RESCUE_PROFILE",
    title = "Rescue",
    reboot = false,
    refreshOnProfileChange = true,
    eepromWrite = true,
    labels = labels,
    fields = fields,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
