local title = "Motor/ESC Features"
local enableWakeup = false

local apiform = {
    mspapi = {'ESC_SENSOR_CONFIG','MOTOR_CONFIG'},
    formdata = {
        {
            title = "ESC Throttle Protocol", 
            inline_size = nil,
            fields = {
                {
                    title = nil,
                    mspapi = 'MOTOR_CONFIG',
                    apikey = 'motor_pwm_protocol',
                },
            }
        },    
        {
            title = "ESC Telemetry Protocol", 
            inline_size = nil,
            fields = {
                {
                    title = nil,
                    mspapi = 'ESC_SENSOR_CONFIG',
                    apikey = 'protocol',
                },
            }
        },               
        {
            title = "Main Motor Gear Ratio", 
            inline_size = 14,
            fields = {
                {
                    title = "Pinion",
                    mspapi = 'MOTOR_CONFIG',
                    apikey = 'main_rotor_gear_ratio_0',
                },
                {
                    title = "Main",
                    mspapi = 'MOTOR_CONFIG',
                    apikey = 'main_rotor_gear_ratio_1',
                }
            }
        },
        {
            title = "Tail Motor Gear Ratio",
            inline_size = 14.5,
            fields = {
                {
                    title = "Rear",
                    mspapi = 'MOTOR_CONFIG',
                    apikey = 'tail_rotor_gear_ratio_0',
                },
                {
                    title = "Front",
                    mspapi = 'MOTOR_CONFIG',
                    apikey = 'tail_rotor_gear_ratio_1',
                }
            }
        },
        {
            title = "Motor Pole Count",
            inline_size = 14.5,   
            fields = {
                {
                    title = "Main",
                    mspapi = 'MOTOR_CONFIG',
                    apikey = 'main_rotor_pole_count',
                },
                {
                    title = "Tail",
                    mspapi = 'MOTOR_CONFIG',
                    apikey = 'tail_rotor_pole_count',
                }
            }
        },
        {
            title = "0% Throttle PWM Value",
            inline_size = nil,   
            fields = {
                {
                    title = "Main",
                    mspapi = 'MOTOR_CONFIG',
                    apikey = 'minthrottle',
                },
            }
        },      
        {
            title = "100% Throttle PWM Value",
            inline_size = nil,   
            fields = {
                {
                    title = "Main",
                    mspapi = 'MOTOR_CONFIG',
                    apikey = 'maxthrottle',
                },
            }
        },    
        {
            title = "Motor Stop PWM Value",
            inline_size = nil,   
            fields = {
                {
                    title = "Main",
                    mspapi = 'MOTOR_CONFIG',
                    apikey = 'mincommand',
                },
            }
        },   
    }                 
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true

end

local function wakeup()
    if enableWakeup == true then

    end
end

return {
    title = title,
    event = event,
    apiform = apiform,
    wakeup = wakeup,
    postLoad = postLoad,
}
