local labels = {}
local fields = {}

local activateWakeup = false
local currentProfileChecked = false

-- tail rotor settings
labels[#labels + 1] = {t = "Yaw stop gain", label = "ysgain", inline_size = 13.6}
fields[#fields + 1] = {t = "CW", help = "profilesYawStopGainCW", inline = 2, label = "ysgain", min = 25, max = 250, default = 80, vals = {21}}
fields[#fields + 1] = {t = "CCW", help = "profilesYawStopGainCCW", inline = 1, label = "ysgain", min = 25, max = 250, default = 120, vals = {22}}

fields[#fields + 1] = {t = "Precomp Cutoff", help = "profilesYawPrecompCutoff", min = 0, max = 250, default = 5, unit = "Hz", vals = {23}}
fields[#fields + 1] = {t = "Cyclic FF gain", help = "profilesYawFFCyclicGain", min = 0, max = 250, default = 30, vals = {24}}
fields[#fields + 1] = {t = "Collective FF gain", help = "profilesYawFFCollectiveGain", min = 0, max = 250, default = 0, vals = {25}}

labels[#labels + 1] = {t = "Collective Impulse FF", label = "colimpff", inline_size = 13.6}
fields[#fields + 1] = {t = "Gain", help = "profilesYawFFImpulseGain", inline = 2, label = "colimpff", min = 0, max = 250, default = 0, vals = {26}}
fields[#fields + 1] = {t = "Decay", help = "profilesyawFFImpulseDecay", inline = 1, label = "colimpff", min = 0, max = 250, default = 25, unit = "s", vals = {27}}

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
    title = "Tail Rotor",
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
