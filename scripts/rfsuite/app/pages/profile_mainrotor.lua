local labels = {}
local fields = {}

local activateWakeup = false
local currentProfileChecked = false

labels[#labels + 1] = {t = "Collective Pitch Compensation", t2 = "Col. Pitch Compensation", label = "cpcomp", inline_size = 40.15}
fields[#fields + 1] = {t = "", help = "profilesPitchFFCollective", inline = 1, label = "cpcomp", min = 0, max = 250, default = 0, vals = {28}}

-- main rotor settings
labels[#labels + 1] = {t = "Cyclic Cross coupling", label = "cycliccc1", inline_size = 40.15}
if tonumber(rfsuite.config.apiVersion) >= 12.07 then
    fields[#fields + 1] = {t = "Gain", help = "profilesCyclicCrossCouplingGain", inline = 1, label = "cycliccc1", line = false, min = 0, max = 250, default = 50, vals = {34}}
else
    fields[#fields + 1] = {t = "Gain", help = "profilesCyclicCrossCouplingGain", inline = 1, label = "cycliccc1", line = false, min = 0, max = 250, default = 25, vals = {34}}
end

labels[#labels + 1] = {t = "", label = "cycliccc2", inline_size = 40.15}
fields[#fields + 1] = {t = "Ratio", help = "profilesCyclicCrossCouplingRatio", inline = 1, label = "cycliccc2", line = false, min = 0, max = 200, default = 0, unit = "%", vals = {35}}

labels[#labels + 1] = {t = "", label = "cycliccc3", inline_size = 40.15}
if tonumber(rfsuite.config.apiVersion) >= 12.07 then
    fields[#fields + 1] = { t = "Cutoff", help = "profilesCyclicCrossCouplingCutoff", scale = 10, decimals = 1, inline = 1, label = "cycliccc3", line = true, min = 1, max = 250, default = 2.5, unit = "Hz", vals = {36} }
else
    fields[#fields + 1] = { t = "Cutoff", help = "profilesCyclicCrossCouplingCutoff", inline = 1, label = "cycliccc3", line = true, min = 1, max = 250, default = 15, unit = "Hz", vals = {36} }
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
            rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " #" .. rfsuite.config.activeRateProfile)
            currentProfileChecked = true
        end

    end

end

return {
    read = 94, -- msp_PID_PROFILE
    write = 95, -- msp_SET_PID_PROFILE
    title = "Main Rotor",
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