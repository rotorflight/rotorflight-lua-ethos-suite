local labels = {}
local fields = {}

-- gear ratio and motor pole count

labels[#labels + 1] = {t = "Main Motor Ratio", t2 = "Main Motor Gear Ratio", label = 1, inline_size = 14.5}
fields[#fields + 1] = {t = "Pinion", label = 1, inline = 2, help = "motorGearRatioPinion", apikey = "main_rotor_gear_ratio_0"}
fields[#fields + 1] = {t = "Main", label = 1, inline = 1, help = "motorGearRatioMain", apikey = "main_rotor_gear_ratio_1"}

labels[#labels + 1] = {t = "Tail Motor Ratio", t2 = "Tail Motor Gear Ratio", label = 2, inline_size = 14.5}
fields[#fields + 1] = {t = "Rear", label = 2, inline = 2, help = "motorGearRatioTailRear", apikey = "tail_rotor_gear_ratio_0"}
fields[#fields + 1] = {t = "Front", label = 2, inline = 1, help = "motorGearRatioTailFront", apikey = "tail_rotor_gear_ratio_1"}

fields[#fields + 1] = {t = "Motor Pole Count", help = "motorPollCount", apikey = "motor_pole_count_0"}

-- question of if below params are put elsewhere?
fields[#fields + 1] = {t = "0% Throttle PWM Value", help = "motorMinThrottle", apikey = "minthrottle"}
fields[#fields + 1] = {t = "100% Throttle PWM value", help = "motorMaxThrottle", apikey = "maxthrottle"}
fields[#fields + 1] = {t = "Motor Stop PWM Value", help = "motorMinCommand", apikey = "mincommand"}

local function postLoad(self)
    rfsuite.app.triggers.isReady = true
end



return {
    mspapi = "MOTOR_CONFIG",
    title = "Motors",
    reboot = false,
    eepromWrite = true,
    labels = labels,
    fields = fields,
    postLoad = postLoad,
    API = {},
}