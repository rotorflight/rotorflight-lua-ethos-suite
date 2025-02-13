local labels = {}
local fields = {}

local activateWakeup = false
local currentProfileChecked = false

-- pid controller settings =
fields[#fields + 1] = {t = "Ground Error Decay", help = "profilesErrorDecayGround", apikey = "error_decay_time_ground"}

labels[#labels + 1] = {t = "Inflight Error Decay", label = 2, inline_size = 13.6}
fields[#fields + 1] = {t = "Time", help = "profilesErrorDecayGroundCyclicTime", inline = 2, label = 2, apikey = "error_decay_time_cyclic"}
fields[#fields + 1] = {t = "Limit", help = "profilesErrorDecayGroundCyclicLimit", inline = 1, label = 2, apikey = "error_decay_limit_cyclic"}

labels[#labels + 1] = {t = "Error limit", label = 4, inline_size = 8.15}
fields[#fields + 1] = {t = "R", help = "profilesErrorLimit", inline = 3, label = 4, apikey = "error_limit_0"}
fields[#fields + 1] = {t = "P", help = "profilesErrorLimit", inline = 2, label = 4, apikey = "error_limit_1"}
fields[#fields + 1] = {t = "Y", help = "profilesErrorLimit", inline = 1, label = 4, apikey = "error_limit_2"}

labels[#labels + 1] = {t = "HSI Offset limit", label = 5, inline_size = 8.15}
fields[#fields + 1] = {t = "R", help = "profilesErrorHSIOffsetLimit", inline = 3, label = 5, apikey = "offset_limit_0"}
fields[#fields + 1] = {t = "P", help = "profilesErrorHSIOffsetLimit", inline = 2, label = 5, apikey = "offset_limit_1"}

fields[#fields + 1] = {t = "Error rotation", help = "profilesErrorRotation", apikey = "error_rotation",type=1}

labels[#labels + 1] = {t = "I-term relax", label = 6, inline_size = 40.15}
fields[#fields + 1] = {t = "", help = "profilesItermRelaxType", inline = 1, label = 6, apikey = "iterm_relax_type", type=1}

labels[#labels + 1] = {t = "        Cut-off point", label = 15, inline_size = 8.15}
fields[#fields + 1] = {t = "R", help = "profilesItermRelax", inline = 3, label = 15, apikey = "iterm_relax_cutoff_0"}
fields[#fields + 1] = {t = "P", help = "profilesItermRelax", inline = 2, label = 15, apikey = "iterm_relax_cutoff_1"}
fields[#fields + 1] = {t = "Y", help = "profilesItermRelax", inline = 1, label = 15, apikey = "iterm_relax_cutoff_2"}

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
    title = "PID Controller",
    refreshOnProfileChange = true,
    reboot = false,
    eepromWrite = true,
    labels = labels,
    fields = fields,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
