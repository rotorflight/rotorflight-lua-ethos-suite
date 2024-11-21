local labels = {}
local fields = {}

-- gear ratio and motor pole count

labels[#labels + 1] = {t = "Main Motor Ratio", t2 = "Main Motor Gear Ratio", label = 1, inline_size = 14.5}
fields[#fields + 1] = {t = "Pinion", label = 1, inline=2, help = "motorGearRatioPinion", min = 0, max = 2000, default = 1, vals = {22,23}}
fields[#fields + 1] = {t = "Main", label = 1, inline=1, help = "motorGearRatioMain", min = 0, max = 2000, default = 1, vals = {24,25}}

labels[#labels + 1] = {t = "Tail Motor Ratio", t = "Tail Motor Gear Ratio", label = 2, inline_size = 14.5}
fields[#fields + 1] = {t = "Rear", label = 2, inline=2,  help = "motorGearRatioTailRear", min = 0, max = 2000, default = 1, vals = {26,27}}
fields[#fields + 1] = {t = "Front", label = 2, inline=1,  help = "motorGearRatioTailFront", min = 0, max = 2000, default = 1, vals = {28,29}}

fields[#fields + 1] = {t = "Motor Pole Count", help = "motorPollCount", min = 0, max = 256, default = 8, vals = {14}}

-- question of if below params are put elsewhere?
--fields[#fields + 1] = {t = "0% Throttle PWM Value", help = "motorMinThrottle", min = 50, max = 2250, default = 1070, vals = {1,2}}
--fields[#fields + 1] = {t = "100% Throttle PWM value", help = "motorMaxThrottle", min = 50, max = 2250, default = 1070, vals = {3,4}}
--fields[#fields + 1] = {t = "Motor Stop PWM Value", help = "motorMinCommand", min = 50, max = 2250, default = 1070, vals = {5,6}}



local function postLoad(self)
    rfsuite.app.triggers.isReady = true
end

local function preSavePayload(payload)

    -- this is really horrible.  the write command does not honour the order of the read command.
    -- this function mangles stuff to the right locations.

    local newPayload = {}

    for i,v in ipairs(payload) do   
            if i > 6 then
                    newPayload[i] = payload[i+1]
            else
                newPayload[i] = payload[i]     
            end
            
    end

    
    return newPayload

end

return {
    read = 131,
    write = 222,
    title = "DriveTrain",
    reboot = false,
    simulatorResponse = {45, 4, 208, 7, 232, 3, 1, 6, 0, 0, 250, 0, 1, 6, 4, 2, 1, 8, 7, 7, 8, 20, 0, 50, 0, 9, 0, 30, 0},
    eepromWrite = true,
    minBytes = 29,
    labels = labels,
    fields = fields,
    postLoad = postLoad,
    preSavePayload = preSavePayload
}
