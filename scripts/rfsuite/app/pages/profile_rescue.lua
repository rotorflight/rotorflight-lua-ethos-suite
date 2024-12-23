local labels = {}
local fields = {}

local activateWakeup = false
local currentProfileChecked = false

-- fields[#fields + 1] = { t = "Rescue mode enable",  min = 0, max = 2,         vals = { 1 }, table = { [0] = "Off", "On", "Alt hold" } }
fields[#fields + 1] = {t = "Rescue mode enable", min = 0, max = 1, default = 0, ftype = "bool", type = "1", vals = {1}, table = {[0] = "Off", "On"}}
fields[#fields + 1] = {t = "Flip to upright", help = "profilesRescueFlipMode", min = 0, max = 1, default = 0, vals = {2}, table = {[0] = "No flip", "Flip"}}

labels[#labels + 1] = {subpage = 1, t = "Pull-up", label = "pullup", inline_size = 13.6}
fields[#fields + 1] = {t = "Collective", help = "profilesRescuePullupCollective", inline = 2, label = "pullup", min = 0, max = 1000, default = 650, unit = "%", type = "1", vals = {9, 10}, scale = 10}
fields[#fields + 1] = {t = "Time", help = "profilesRescuePullupTime", inline = 1, label = "pullup", min = 0, max = 250, default = 50, unit = "s", vals = {5}, decimals = 1, scale = 10}

labels[#labels + 1] = {subpage = 1, t = "Climb", label = "climb", inline_size = 13.6}
fields[#fields + 1] = {t = "Collective", help = "profilesRescueClimbCollective", inline = 2, label = "climb", min = 0, max = 1000, default = 450, unit = "%", vals = {11, 12}, scale = 10}
fields[#fields + 1] = {t = "Time", help = "profilesRescueClimbTime", inline = 1, label = "climb", min = 0, max = 250, default = 200, unit = "s", vals = {6}, decimals = 1, scale = 10}

labels[#labels + 1] = {subpage = 1, t = "Hover", label = "hover", inline_size = 13.6}
fields[#fields + 1] = {t = "Collective", help = "profilesRescueHoverCollective", inline = 2, label = "hover", min = 0, max = 1000, default = 350, unit = "%", vals = {13, 14}, decimals = 1, scale = 10}

labels[#labels + 1] = {subpage = 1, t = "Flip", label = "flip", inline_size = 13.6}
fields[#fields + 1] = {t = "Fail time", help = "profilesRescueFlipTime", inline = 2, label = "flip", min = 0, max = 250, default = 100, unit = "s", vals = {7}, decimals = 1, scale = 10}
fields[#fields + 1] = {t = "Exit time", help = "profilesRescueExitTime", inline = 1, label = "flip", min = 0, max = 250, default = 50, unit = "s", vals = {8}, decimals = 1, scale = 10}

labels[#labels + 1] = {subpage = 1, t = "Gains", label = "rescue", inline_size = 13.6}
fields[#fields + 1] = {t = "Level", help = "profilesRescueLevelGain", label = "rescue", inline = 2, min = 5, max = 250, default = 40, unit = nil, vals = {4}}
fields[#fields + 1] = {t = "Flip", help = "profilesRescueFlipGain", label = "rescue", inline = 1, min = 5, max = 250, default = 50, unit = nil, vals = {3}}

labels[#labels + 1] = {subpage = 1, t = "", label = "rescue2", inline_size = 40.15}
fields[#fields + 1] = {t = "Rate", help = "profilesRescueMaxRate", label = "rescue2", inline = 1, min = 1, max = 1000, default = 250, unit = "°/s", vals = {25, 26}}

labels[#labels + 1] = {subpage = 1, t = "", label = "rescue3", inline_size = 40.15}
fields[#fields + 1] = {t = "Accel", help = "profilesRescueMaxAccel", label = "rescue3", inline = 1, min = 1, max = 10000, default = 2000, unit = "°/^2", vals = {27, 28}}

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
    read = 146, -- msp_RESCUE_PROFILE
    write = 147, -- msp_SET_RESCUE_PROFILE
    title = "Rescue",
    reboot = false,
    refreshOnProfileChange = true,
    eepromWrite = true,
    simulatorResponse = {1, 0, 200, 100, 5, 3, 10, 5, 182, 3, 188, 2, 194, 1, 244, 1, 20, 0, 20, 0, 10, 0, 232, 3, 44, 1, 184, 11},
    minBytes = 28,
    labels = labels,
    fields = fields,
    postLoad = postLoad,
    wakeup = wakeup
}
