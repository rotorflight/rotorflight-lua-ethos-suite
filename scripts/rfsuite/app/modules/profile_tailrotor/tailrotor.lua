local labels = {}
local fields = {}

local activateWakeup = false
local currentProfileChecked = false

-- tail rotor settings
labels[#labels + 1] = { t = "Yaw stop gain", label = "ysgain", inline_size = 13.6 }
fields[#fields + 1] = { t = "CW", help = "profilesYawStopGainCW", inline = 2, label = "ysgain", apikey = "yaw_cw_stop_gain" }
fields[#fields + 1] = { t = "CCW", help = "profilesYawStopGainCCW", inline = 1, label = "ysgain", apikey = "yaw_ccw_stop_gain" }

fields[#fields + 1] = { t = "Precomp Cutoff", help = "profilesYawPrecompCutoff", apikey = "yaw_precomp_cutoff" }
fields[#fields + 1] = { t = "Cyclic FF gain", help = "profilesYawFFCyclicGain", apikey = "yaw_cyclic_ff_gain" }
fields[#fields + 1] = { t = "Collective FF gain", help = "profilesYawFFCollectiveGain", apikey = "yaw_collective_ff_gain" }

if rfsuite.config.apiVersion >= 12.08 then
    labels[#labels + 1] = { t = "Inertia Precomp", label = "inertia", inline_size = 13.6 }
    fields[#fields + 1] = { t = "Gain", help = "profilesIntertiaGain", inline = 2, label = "inertia", apikey = "yaw_inertia_precomp_gain" }
    fields[#fields + 1] = { t = "Cutoff", help = "profilesInertiaCutoff", inline = 1, label = "inertia", apikey = "yaw_inertia_precomp_cutoff" }
else
    labels[#labels + 1] = { t = "Collective Impulse FF", label = "colimpff", inline_size = 13.6 }
    fields[#fields + 1] = { t = "Gain", help = "profilesYawFFImpulseGain", inline = 2, label = "colimpff", apikey = "yaw_collective_dynamic_gain" }
    fields[#fields + 1] = { t = "Decay", help = "profilesyawFFImpulseDecay", inline = 1, label = "colimpff", apikey = "yaw_collective_dynamic_decay" }
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
