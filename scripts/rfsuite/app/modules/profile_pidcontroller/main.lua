local labels = {}
local fields = {}

local activateWakeup = false
local currentProfileChecked = false

-- pid controller settings =
-- labels[#labels + 1] = { subpage=1,t ="Ground Error Decay", label=1          }
fields[#fields + 1] = {t = "Ground Error Decay", help = "profilesErrorDecayGround", min = 0, max = 250, unit = "s", default = 250, vals = {2}, decimals = 1, scale = 10}

labels[#labels + 1] = {t = "Inflight Error Decay", label = 2, inline_size = 13.6}
fields[#fields + 1] = {t = "Time", help = "profilesErrorDecayGroundCyclicTime", inline = 2, label = 2, min = 0, max = 250, unit = "s", default = 180, vals = {3}, decimals = 1, scale = 10}
fields[#fields + 1] = {t = "Limit", help = "profilesErrorDecayGroundCyclicLimit", inline = 1, label = 2, min = 0, max = 250, unit = "°", default = 20, vals = {5}}

labels[#labels + 1] = {t = "Error limit", label = 4, inline_size = 8.15}
fields[#fields + 1] = {t = "R", help = "profilesErrorLimit", inline = 3, label = 4, min = 0, max = 180, default = 30, unit = "°", vals = {8}}
fields[#fields + 1] = {t = "P", help = "profilesErrorLimit", inline = 2, label = 4, min = 0, max = 180, default = 30, unit = "°", vals = {9}}
fields[#fields + 1] = {t = "Y", help = "profilesErrorLimit", inline = 1, label = 4, min = 0, max = 180, default = 45, unit = "°", vals = {10}}

labels[#labels + 1] = {t = "HSI Offset limit", label = 5, inline_size = 8.15}
fields[#fields + 1] = {t = "R", help = "profilesErrorHSIOffsetLimit", inline = 3, label = 5, min = 0, max = 180, default = 45, unit = "°", vals = {37}}
fields[#fields + 1] = {t = "P", help = "profilesErrorHSIOffsetLimit", inline = 2, label = 5, min = 0, max = 180, default = 45, unit = "°", vals = {38}}

fields[#fields + 1] = {t = "Error rotation", help = "profilesErrorRotation", min = 0, max = 1, vals = {7}, table = {[0] = "OFF", "ON"}}

labels[#labels + 1] = {t = "I-term relax", label = 6, inline_size = 40.15}
fields[#fields + 1] = {t = "", help = "profilesItermRelaxType", inline = 1, label = 6, min = 0, max = 2, vals = {17}, table = {[0] = "OFF", "RP", "RPY"}}

labels[#labels + 1] = {t = "        Cut-off point", label = 15, inline_size = 8.15}
fields[#fields + 1] = {t = "R", help = "profilesItermRelax", inline = 3, label = 15, min = 1, max = 100, default = 10, vals = {18}}
fields[#fields + 1] = {t = "P", help = "profilesItermRelax", inline = 2, label = 15, min = 1, max = 100, default = 10, vals = {19}}
fields[#fields + 1] = {t = "Y", help = "profilesItermRelax", inline = 1, label = 15, min = 1, max = 100, default = 10, vals = {20}}

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
    title = "PID Controller",
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
