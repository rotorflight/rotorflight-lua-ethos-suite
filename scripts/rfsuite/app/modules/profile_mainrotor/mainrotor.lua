local labels = {}
local fields = {}

local activateWakeup = false
local currentProfileChecked = false

labels[#labels + 1] = {t = "Collective Pitch Compensation", t2 = "Col. Pitch Compensation", label = "cpcomp", inline_size = 40.15}
fields[#fields + 1] = {t = "", inline = 1, label = "cpcomp", apikey = "pitch_collective_ff_gain"}

-- main rotor settings
labels[#labels + 1] = {t = "Cyclic Cross coupling", label = "cycliccc1", inline_size = 40.15}
if tonumber(rfsuite.config.apiVersion) >= 12.07 then
    fields[#fields + 1] = {t = "Gain", inline = 1, label = "cycliccc1", apikey = "cyclic_cross_coupling_gain"}
else
    fields[#fields + 1] = {t = "Gain", inline = 1, label = "cycliccc1", apikey = "cyclic_cross_coupling_gain"}
end

labels[#labels + 1] = {t = "", label = "cycliccc2", inline_size = 40.15}
fields[#fields + 1] = {t = "Ratio", inline = 1, label = "cycliccc2", apikey = "cyclic_cross_coupling_ratio"}

labels[#labels + 1] = {t = "", label = "cycliccc3", inline_size = 40.15}
if tonumber(rfsuite.config.apiVersion) >= 12.07 then
    fields[#fields + 1] = {t = "Cutoff", inline = 1, label = "cycliccc3", apikey = "cyclic_cross_coupling_cutoff"}
else
    fields[#fields + 1] = {t = "Cutoff", inline = 1, label = "cycliccc3", apikey = "cyclic_cross_coupling_cutoff"}
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
