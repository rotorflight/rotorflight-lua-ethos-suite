local labels = {}
local fields = {}

local activateWakeup = false
local currentProfileChecked = false
local governorDisabledMsg = false

if rfsuite.config.governorMode == 1 then

    -- passthru mode is only possible to set max
    fields[#fields + 1] = {t = "Max throttle", help = "govMaxThrottle", min = 40, max = 100, default = 100, unit = "%", vals = {13}}

elseif rfsuite.config.governorMode >= 2 then

    -- governor modes have lots of options

    fields[#fields + 1] = {t = "Full headspeed", help = "govHeadspeed", min = 0, max = 50000, default = 1000, unit = "rpm", step = 10, vals = {1, 2}}
    fields[#fields + 1] = {t = "PID master gain", help = "govMasterGain", min = 0, max = 250, default = 40, vals = {3}}

    labels[#labels + 1] = {subpage = 1, t = "Gains", label = 1, inline_size = 8.15}
    fields[#fields + 1] = {t = "P", help = "govPGain", inline = 4, label = 1, min = 0, max = 250, default = 40, vals = {4}}
    fields[#fields + 1] = {t = "I", help = "govIGain", inline = 3, label = 1, min = 0, max = 250, default = 50, vals = {5}}
    fields[#fields + 1] = {t = "D", help = "govDGain", inline = 2, label = 1, min = 0, max = 250, default = 0, vals = {6}}
    fields[#fields + 1] = {t = "F", help = "govFGain", inline = 1, label = 1, min = 0, max = 250, default = 10, vals = {7}}

    labels[#labels + 1] = {subpage = 1, t = "Precomp", label = 2, inline_size = 8.15}
    fields[#fields + 1] = {t = "Yaw", help = "govYawPrecomp", inline = 3, label = 2, min = 0, max = 250, default = 0, vals = {10}}
    fields[#fields + 1] = {t = "Cyc", help = "govCyclicPrecomp", inline = 2, label = 2, min = 0, max = 250, default = 10, vals = {11}}
    fields[#fields + 1] = {t = "Col", help = "govCollectivePrecomp", inline = 1, label = 2, min = 0, max = 250, default = 100, vals = {12}}

    labels[#labels + 1] = {subpage = 1, t = "Tail Torque Assist", label = 3}
    fields[#fields + 1] = {t = "Gain", help = "govTTAGain", inline = 2, label = 3, min = 0, max = 250, default = 0, vals = {8}}
    fields[#fields + 1] = {t = "Limit", help = "govTTALimit", inline = 1, label = 3, min = 0, max = 250, default = 20, unit = "%", vals = {9}}

    if tonumber(rfsuite.config.apiVersion) >= 12.07 then fields[#fields + 1] = {t = "Min throttle", help = "govMinThrottle", min = 0, max = 100, default = 10, unit = "%", vals = {14}} end

    fields[#fields + 1] = {t = "Max throttle", help = "govMaxThrottle", min = 40, max = 100, default = 100, unit = "%", vals = {13}}

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

        if rfsuite.config.governorMode == 0 then
            if governorDisabledMsg == false then
                governorDisabledMsg = true

                -- disable save button
                rfsuite.app.formNavigationFields['save']:enable(false)
                -- disable reload button
                rfsuite.app.formNavigationFields['reload']:enable(false)
                -- add field to formFields
                rfsuite.app.formLines[#rfsuite.app.formLines + 1] = form.addLine("Rotorflight governor is not enabled")

            end
        end

    end

end

return {
    read = 148, -- msp_GOVERNOR_PROFILE
    write = 149, -- msp_SET_GOVERNOR_PROFILE
    title = "Governor",
    reboot = false,
    refreshOnProfileChange = true,
    eepromWrite = true,
    simulatorResponse = {208, 7, 100, 10, 125, 5, 20, 0, 20, 10, 40, 100, 100, 10},
    minBytes = 13,
    labels = labels,
    fields = fields,
    postLoad = postLoad,
    wakeup = wakeup
}
