local labels = {}
local fields = {}

local activateWakeup = false
local currentProfileChecked = false

labels[#labels + 1] = {t = "Collective Pitch Compensation", t2 = "Col. Pitch Compensation", label = "cpcomp", inline_size = 40.15}
fields[#fields + 1] = {t = "", help = "profilesPitchFFCollective", inline = 1, label = "cpcomp", min = 0, max = 250, default = 0, apikey = "pitch_collective_ff_gain"}

-- main rotor settings
labels[#labels + 1] = {t = "Cyclic Cross coupling", label = "cycliccc1", inline_size = 40.15}
if tonumber(rfsuite.config.apiVersion) >= 12.07 then
    fields[#fields + 1] = {t = "Gain", help = "profilesCyclicCrossCouplingGain", inline = 1, label = "cycliccc1", line = false, min = 0, max = 250, default = 50, apikey = "cyclic_cross_coupling_gain"}
else
    fields[#fields + 1] = {t = "Gain", help = "profilesCyclicCrossCouplingGain", inline = 1, label = "cycliccc1", line = false, min = 0, max = 250, default = 25, apikey = "cyclic_cross_coupling_gain"}
end

labels[#labels + 1] = {t = "", label = "cycliccc2", inline_size = 40.15}
fields[#fields + 1] = {t = "Ratio", help = "profilesCyclicCrossCouplingRatio", inline = 1, label = "cycliccc2", line = false, min = 0, max = 200, default = 0, unit = "%", apikey = "cyclic_cross_coupling_ratio"}

labels[#labels + 1] = {t = "", label = "cycliccc3", inline_size = 40.15}
if tonumber(rfsuite.config.apiVersion) >= 12.07 then
    fields[#fields + 1] = {t = "Cutoff", help = "profilesCyclicCrossCouplingCutoff", scale = 10, decimals = 1, inline = 1, label = "cycliccc3", line = true, min = 1, max = 250, default = 2.5, unit = "Hz", apikey = "cyclic_cross_coupling_cutoff"}
else
    fields[#fields + 1] = {t = "Cutoff", help = "profilesCyclicCrossCouplingCutoff", inline = 1, label = "cycliccc3", line = true, min = 1, max = 250, default = 15, unit = "Hz", apikey = "cyclic_cross_coupling_cutoff"}
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
    title = "Main Rotor",
    refreshOnProfileChange = true,
    reboot = false,
    eepromWrite = true,
    labels = labels,
    fields = fields,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
