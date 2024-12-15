local pages = {}
local sections = {}



-- pages
-- title = Page Title
-- section = int 
-- script = file.lua
-- image = image.png
-- ethosversion = 1516 or other (disables button if less than version)
-- developer = true or false (hides the whole section or page

-- sections
-- developer = true or false (hides the whole section or page
-- ethosversion = 1516 or other (disables section if less than version)

sections[#sections + 1] = {title = "Flight Tuning", section = 1}
pages[#pages + 1] = {title = "PIDs", section = 1, script = "pids.lua", image = "pids.png"}
pages[#pages + 1] = {title = "Rates", section = 1, script = "rates.lua", image = "rates.png"}
pages[#pages + 1] = {title = "Main Rotor", section = 1, script = "profile_mainrotor.lua", image = "mainrotor.png"}
pages[#pages + 1] = {title = "Tail Rotor", section = 1, script = "profile_tailrotor.lua", image = "tailrotor.png"}
pages[#pages + 1] = {title = "Governor", section = 1, script = "profile_governor.lua", image = "governor.png"}
pages[#pages + 1] = {title = "Trim", section = 1, script = "trim.lua", image = "trim.png"}

sections[#sections + 1] = {title = "Advanced", section = 2}
pages[#pages + 1] = {title = "PID Controller", section = 2, script = "profile_pidcontroller.lua", image = "pids-controller.png"}
pages[#pages + 1] = {title = "PID Bandwidth", section = 2, script = "profile_pidbandwidth.lua", image = "pids-bandwidth.png"}
pages[#pages + 1] = {title = "Auto Level", section = 2, script = "profile_autolevel.lua", image = "autolevel.png"}
pages[#pages + 1] = {title = "Rescue", section = 2, script = "profile_rescue.lua", image = "rescue.png"}
pages[#pages + 1] = {title = "Rates", section = 2, script = "rates_advanced.lua", image = "rates.png"}

sections[#sections + 1] = {title = "Hardware", section = 4}
pages[#pages + 1] = {title = "Motors", section = 4, script = "motors.lua", image = "motors.png"}
pages[#pages + 1] = {title = "Servos", section = 4, script = "servos.lua", image = "servos.png"}
pages[#pages + 1] = {title = "SBUS Output", section = 4, script = "sbusout.lua", image = "sbusout.png"}
pages[#pages + 1] = {title = "Mixer", section = 4, script = "mixer.lua", image = "mixer.png"}
pages[#pages + 1] = {title = "Accelerometer", section = 4, script = "accelerometer.lua", image = "acc.png"}
pages[#pages + 1] = {title = "Filters", section = 4, script = "filters.lua", image = "filters.png"}
pages[#pages + 1] = {title = "Radio Config", section = 4, script = "radio_config.lua", image = "radio_config.png"}
pages[#pages + 1] = {title = "Governor", section = 4, script = "governor.lua", image = "governor.png"}
pages[#pages + 1] = {title = "ESC", section = 4, script = "esc.lua", image = "esc.png"}

sections[#sections + 1] = {title = "Tools", section = 5}
pages[#pages + 1] = {title = "Copy Profiles", section = 5, script = "copy_profiles.lua", image = "copy.png"}
pages[#pages + 1] = {title = "Set Profiles", section = 5, script = "select_profile.lua", image = "select_profile.png"}
pages[#pages + 1] = {title = "Status", section = 5, script = "status.lua", image = "status.png"}
pages[#pages + 1] = {title = "Logs", section = 5, script = "logs.lua", image = "logs.png"}


sections[#sections + 1] = {title = "Developer", section = 6, developer = true}
pages[#pages + 1] = {title = "MSP Speed", section = 6, script = "msp_speed.lua", image = "msp_speed.png"}
pages[#pages + 1] = {title = "Experimental", section = 6, script = "msp_exp.lua", image = "msp_exp.png"}

sections[#sections + 1] = {title = "About", section = 7}
pages[#pages + 1] = {title = "About", section = 7, script = "about.lua", image = "about.png"}

return {pages = pages, sections = sections}
