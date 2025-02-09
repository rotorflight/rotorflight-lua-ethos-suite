local labels = {}
local fields = {}

local activateWakeup = false
local currentProfileChecked = false

-- tail rotor settings
labels[#labels + 1] = {t = "Yaw stop gain", label = "ysgain", inline_size = 13.6}
fields[#fields + 1] = {t = "CW", help = "profilesYawStopGainCW", inline = 2, label = "ysgain", min = 25, max = 250, default = 80, apikey = "yaw_cw_stop_gain"}
fields[#fields + 1] = {t = "CCW", help = "profilesYawStopGainCCW", inline = 1, label = "ysgain", min = 25, max = 250, default = 120, apikey = "yaw_ccw_stop_gain"}

fields[#fields + 1] = {t = "Precomp Cutoff", help = "profilesYawPrecompCutoff", min = 0, max = 250, default = 5, unit = "Hz", apikey = "yaw_precomp_cutoff"}
fields[#fields + 1] = {t = "Cyclic FF gain", help = "profilesYawFFCyclicGain", min = 0, max = 250, default = 30, apikey = "yaw_cyclic_ff_gain"}
fields[#fields + 1] = {t = "Collective FF gain", help = "profilesYawFFCollectiveGain", min = 0, max = 250, default = 0, apikey = "yaw_collective_ff_gain"}

if rfsuite.config.apiVersion >= 12.08 then
    labels[#labels + 1] = {t = "Inertia Precomp", label = "inertia", inline_size = 13.6}
    fields[#fields + 1] = {t = "Gain", help = "profilesIntertiaGain", inline = 2, label = "inertia", min = 0, max = 250, default = 0, apikey = "yaw_inertia_precomp_gain"}
    fields[#fields + 1] = {t = "Cutoff", help = "profilesInertiaCutoff", inline = 1, label = "inertia", min = 0, max = 250, default = 25, unit = "Hz", apikey = "yaw_inertia_precomp_cutoff"}
else
    labels[#labels + 1] = {t = "Collective Impulse FF", label = "colimpff", inline_size = 13.6}
    fields[#fields + 1] = {t = "Gain", help = "profilesYawFFImpulseGain", inline = 2, label = "colimpff", min = 0, max = 250, default = 0, apikey = "yaw_collective_dynamic_gain"}
    fields[#fields + 1] = {t = "Decay", help = "profilesyawFFImpulseDecay", inline = 1, label = "colimpff", min = 0, max = 250, default = 25, unit = "s", apikey = "yaw_collective_dynamic_decay"}
end

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
    title = "Tail Rotor",
    refreshOnProfileChange = true,
    reboot = false,
    eepromWrite = true,
    labels = labels,
    fields = fields,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
