--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    ["minthrottle"] = "This PWM value is sent to the ESC/Servo at low throttle",
    ["maxthrottle"] = "This PWM value is sent to the ESC/Servo at full throttle",
    ["mincommand"] = "This PWM value is sent when the motor is stopped",
    ["motor_count_blheli"] = "@i18n(api.MOTOR_CONFIG.motor_count_blheli)@",
    ["motor_pole_count_blheli"] = "@i18n(api.MOTOR_CONFIG.motor_pole_count_blheli)@",
    ["use_dshot_telemetry"] = "@i18n(api.MOTOR_CONFIG.use_dshot_telemetry)@",
    ["motor_pwm_protocol"] = "The protocol used to communicate with the ESC",
    ["motor_pwm_rate"] = "The frequency at which the ESC sends PWM signals to the motor",
    ["use_unsynced_pwm"] = "@i18n(api.MOTOR_CONFIG.use_unsynced_pwm)@",
    ["motor_pole_count_0"] = "The number of magnets on the motor bell.",
    ["motor_pole_count_1"] = "@i18n(api.MOTOR_CONFIG.motor_pole_count_1)@",
    ["motor_pole_count_2"] = "@i18n(api.MOTOR_CONFIG.motor_pole_count_2)@",
    ["motor_pole_count_3"] = "@i18n(api.MOTOR_CONFIG.motor_pole_count_3)@",
    ["motor_rpm_lpf_0"] = "@i18n(api.MOTOR_CONFIG.motor_rpm_lpf_0)@",
    ["motor_rpm_lpf_1"] = "@i18n(api.MOTOR_CONFIG.motor_rpm_lpf_1)@",
    ["motor_rpm_lpf_2"] = "@i18n(api.MOTOR_CONFIG.motor_rpm_lpf_2)@",
    ["motor_rpm_lpf_3"] = "@i18n(api.MOTOR_CONFIG.motor_rpm_lpf_3)@",
    ["main_rotor_gear_ratio_0"] = "Motor Pinion Gear Tooth Count",
    ["main_rotor_gear_ratio_1"] = "Main Gear Tooth Count",
    ["tail_rotor_gear_ratio_0"] = "Tail Gear Tooth Count",
    ["tail_rotor_gear_ratio_1"] = "Autorotation Gear Tooth Count",
}
