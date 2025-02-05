local labels = {}
local fields = {}

local activateWakeup = false
local currentProfileChecked = false

-- pid controller bandwidth
labels[#labels + 1] = {t = "PID Bandwidth", inline_size = 8.15, label = "pidbandwidth", type = 1}
fields[#fields + 1] = {t = "R", help = "profilesPIDBandwidth", inline = 3, label = "pidbandwidth", min = 0, max = 250, default = 50, apikey = "gyro_cutoff_0"}
fields[#fields + 1] = {t = "P", help = "profilesPIDBandwidth", inline = 2, label = "pidbandwidth", min = 0, max = 250, default = 50, apikey = "gyro_cutoff_1"}
fields[#fields + 1] = {t = "Y", help = "profilesPIDBandwidth", inline = 1, label = "pidbandwidth", min = 0, max = 250, default = 100, apikey = "gyro_cutoff_2"}

labels[#labels + 1] = {t = "D-term cut-off", inline_size = 8.15, label = "dcutoff", type = 1}
fields[#fields + 1] = {t = "R", help = "profilesPIDBandwidthDtermCutoff", inline = 3, label = "dcutoff", min = 0, max = 250, default = 15, apikey = "dterm_cutoff_0"}
fields[#fields + 1] = {t = "P", help = "profilesPIDBandwidthDtermCutoff", inline = 2, label = "dcutoff", min = 0, max = 250, default = 15, apikey = "dterm_cutoff_1"}
fields[#fields + 1] = {t = "Y", help = "profilesPIDBandwidthDtermCutoff", inline = 1, label = "dcutoff", min = 0, max = 250, default = 20, apikey = "dterm_cutoff_2"}

labels[#labels + 1] = {t = "B-term cut-off", inline_size = 8.15, label = "bcutoff", type = 1}
fields[#fields + 1] = {t = "R", help = "profilesPIDBandwidthBtermCutoff", inline = 3, label = "bcutoff", min = 0, max = 250, default = 15, apikey = "bterm_cutoff_0"}
fields[#fields + 1] = {t = "P", help = "profilesPIDBandwidthBtermCutoff", inline = 2, label = "bcutoff", min = 0, max = 250, default = 15, apikey = "bterm_cutoff_1"}
fields[#fields + 1] = {t = "Y", help = "profilesPIDBandwidthBtermCutoff", inline = 1, label = "bcutoff", min = 0, max = 250, default = 20, apikey = "bterm_cutoff_2"}

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

return {mspapi = "PID_PROFILE", title = "PID Bandwidth", refreshOnProfileChange = true, reboot = false, eepromWrite = true, labels = labels, fields = fields, postLoad = postLoad, wakeup = wakeup}
