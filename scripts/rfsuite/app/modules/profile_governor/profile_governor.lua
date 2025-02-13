local labels = {}
local fields = {}

local activateWakeup = false
local currentProfileChecked = false
local governorDisabledMsg = false

if rfsuite.config.governorMode == 1 then

    -- passthru mode is only possible to set max
    fields[#fields + 1] = {t = "Max throttle", apikey = "governor_max_throttle"}

elseif rfsuite.config.governorMode >= 2 then

    -- governor modes have lots of options

    fields[#fields + 1] = {t = "Full headspeed", apikey = "governor_headspeed"}
    fields[#fields + 1] = {t = "PID master gain", apikey = "governor_gain"}

    labels[#labels + 1] = {t = "Gains", label = 1, inline_size = 8.15}
    fields[#fields + 1] = {t = "P", inline = 4, label = 1, apikey = "governor_p_gain"}
    fields[#fields + 1] = {t = "I", inline = 3, label = 1, apikey = "governor_i_gain"}
    fields[#fields + 1] = {t = "D", inline = 2, label = 1, apikey = "governor_d_gain"}
    fields[#fields + 1] = {t = "F", inline = 1, label = 1, apikey = "governor_f_gain"}

    labels[#labels + 1] = {t = "Precomp", label = 2, inline_size = 8.15}
    fields[#fields + 1] = {t = "Yaw", inline = 3, label = 2, apikey = "governor_yaw_ff_weight"}
    fields[#fields + 1] = {t = "Cyc", inline = 2, label = 2, apikey = "governor_cyclic_ff_weight"}
    fields[#fields + 1] = {t = "Col", inline = 1, label = 2, apikey = "governor_collective_ff_weight"}

    labels[#labels + 1] = {t = "Tail Torque Assist", label = 3}
    fields[#fields + 1] = {t = "Gain", inline = 2, label = 3, apikey = "governor_tta_gain"}
    fields[#fields + 1] = {t = "Limit", inline = 1, label = 3, apikey = "governor_tta_limit"}

    fields[#fields + 1] = {t = "Min throttle", apikey = "governor_min_throttle"}

    fields[#fields + 1] = {t = "Max throttle", apikey = "governor_max_throttle"}

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
    mspapi = "GOVERNOR_PROFILE",
    title = "Governor",
    reboot = false,
    refreshOnProfileChange = true,
    eepromWrite = true,
    labels = labels,
    fields = fields,
    postLoad = postLoad,
    wakeup = wakeup,
    API = {},
}
