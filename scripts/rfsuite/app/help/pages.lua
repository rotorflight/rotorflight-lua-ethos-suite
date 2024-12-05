data = {}

-- LuaFormatter off

-- PIDS
data["pids"] = {}
data["pids"]["TEXT"] = {
        "Increase D, P, I in order until each wobbles, then back off.", 
        "Set F for a good response in full stick flips and rolls.", 
        "If necessary, tweak P:D ratio to set response damping to your liking.",
        "Increase O until wobbles occur when jabbing elevator at full collective, back off a bit.", 
        "Increase B if you want sharper response."
}

-- FLIGHT TUNING RATES
data["rates"] = {}
data["rates"]["table"] = {}
data["rates"]["TEXT"] = {
        "Default: We keep this to make button appear for rates.", 
        "We will use the sub keys below."
}

-- RATE TABLE NONE
data["rates"]["table"][0] = {
        "All values are set to zero because no RATE TABLE is in use."
}

-- RATE TABLE BETAFLIGHT
data["rates"]["table"][1] = {
        "RC Rate: Maximum rotation rate at full stick deflection.", 
        "SuperRate: Increases maximum rotation rate while reducing sensitivity around half stick.",
        "Expo: Reduces sensitivity near the stick's center where fine controls are needed."
}

-- RATE TABLE RACEFLIGHT
data["rates"]["table"][2] = {
        "Rate: Maximum rotation rate at full stick deflection in degrees per second.", 
        "Acro+: Increases the maximum rotation rate while reducing sensitivity around half stick.",
        "Expo: Reduces sensitivity near the stick's center where fine controls are needed."
}

-- RATE TABLE KISS
data["rates"]["table"][3] = {
        "RC Rate: Maximum rotation rate at full stick deflection.", 
        "Rate: Increases maximum rotation rate while reducing sensitivity around half stick.",
        "RC Curve: Reduces sensitivity near the stick's center where fine controls are needed."
}

-- RATE TABLE ACTUAL
data["rates"]["table"][4] = {
        "Center Sensitivity: Use to reduce sensitivity around center stick. Set Center Sensitivity set to the same as Max Rate for a linear response. A lower number than Max Rate will reduce sensitivity around center stick. Note that higher than Max Rate will increase the Max Rate - not recommended as it causes issues in the Blackbox log.",
        "Max Rate: Maximum rotation rate at full stick deflection in degrees per second.", 
        "Expo: Reduces sensitivity near the stick's center where fine controls are needed."
}

-- RATE TABLE QUICK
data["rates"]["table"][5] = {
        "RC Rate: Use to reduce sensitivity around center stick. RC Rate set to one half of the Max Rate is linear. A lower number will reduce sensitivity around center stick. Higher than one half of the Max Rate will also increase the Max Rate.",
        "Max Rate: Maximum rotation rate at full stick deflection in degrees per second.", 
        "Expo: Reduces sensitivity near the stick's center where fine controls are needed."
}

-- FLIGHT TUNING - MAIN ROTOR
data["profile_mainrotor"] = {}
data["profile_mainrotor"]["TEXT"] = {
        "Collective Pitch Compensation: Increasing will compensate for the pitching motion caused by tail drag when climbing.", 
        "Cross Coupling Gain: Removes roll coupling when only elevator is applied.",
        "Cross Coupling Ratio: Amount of compensation (pitch vs roll) to apply.", 
        "Cross Coupling Feq. Limit: Frequency limit for the compensation, higher value will make the compensation action faster."
}

-- FLIGHT TUNING - TAIL ROTOR
data["profile_tailrotor"] = {}
data["profile_tailrotor"]["TEXT"] = {
        "Yaw Stop Gain: Higher stop gain will make the tail stop more aggressively but may cause oscillations if too high. Adjust CW or CCW to make the yaw stops even.",
        "Precomp Cutoff: Frequency limit for all yaw precompensation actions.", 
        "Cyclic FF Gain: Tail precompensation for cyclic inputs.",
        "Collective FF Gain: Tail precompensation for collective inputs.",
        "Collective Impulse FF: Impulse tail precompensation for collective inputs. If you need extra tail precompensation at the beginning of collective input."
}

-- FLIGHT TUNING - TRIM
data["trim"] = {}
data["trim"]["TEXT"] = {
        "Link trims: Use to trim out small leveling issues in your swash plate. Typically only used if the swash links are non-adjustable.",
        "Motorised tail: If using a motorised tail, use this to set the minimum idle speed and zero yaw."
}

-- FLIGHT TUNING - GOVERNOR
data["profile_governor"] = {}
data["profile_governor"]["TEXT"] = {
        "Full headspeed: Headspeed target when at 100% throttle input.", 
        "PID master gain: How hard the governor works to hold the RPM.", "Gains: Fine tuning of the governor.",
        "Precomp: Governor precomp gain for yaw, cyclic, and collective inputs.", 
        "Max throttle: The maximum throttle % the governor is allowed to use.",
        "Tail Torque Assist: For motorized tails. Gain and limit of headspeed increase when using main rotor torque for yaw assist."
}

-- ADVANCED TUNING - PID CONTROLLER
data["profile_pidcontroller"] = {}
data["profile_pidcontroller"]["TEXT"] = {
        "Error decay ground: PID decay to help prevent heli from tipping over when on the ground.", 
        "Error limit: Angle limit for I-term.", "Offset limit: Angle limit for High Speed Integral (O-term).",
        "Error rotation: Allow errors to be shared between all axes.",
        "I-term relax: Limit accumulation of I-term during fast movements - helps reduce bounce back after fast stick movements. Generally needs to be lower for large helis and can be higher for small helis. Best to only reduce as much as is needed for your flying style."
}

-- ADVANCED TUNING - PID BANDWIDTH
data["profile_pidbandwidth"] = {}
data["profile_pidbandwidth"]["TEXT"] = {
        "PID Bandwidth: Overall bandwidth in HZ used by the PID loop.", 
        "D-term cutoff: D-term cutoff frequency in HZ.", 
        "B-term cutoff: B-term cutoff frequency in HZ."
}

-- ADVANCED TUNING - AUTO LEVEL
data["profile_autolevel"] = {}
data["profile_autolevel"]["TEXT"] = {
        "Acro Trainer: How aggressively the heli tilts back to level when flying in Acro Trainer Mode.", 
        "Angle Mode: How aggressively the heli tilts back to level when flying in Angle Mode.",
        "Horizon Mode: How aggressively the heli tilts back to level when flying in Horizon Mode."
}

-- ADVANCED TUNING - RESCUE
data["profile_rescue"] = {}
data["profile_rescue"]["TEXT"] = {
        "Flip to upright: Flip the heli upright when rescue is activated.", 
        "Pull-up: How much collective and for how long to arrest the fall.",
        "Climb: How much collective to maintain a steady climb - and how long.", 
        "Hover: How much collective to maintain a steady hover.",
        "Flip: How long to wait before aborting because the flip did not work.", 
        "Gains: How hard to fight to keep heli level when engaging rescue mode.",
        "Rate and Accel: Max rotation and acceleration rates when leveling during rescue."
}

-- ADVANCED TUNING - RATES
data["rates_advanced"] = {}
data["rates_advanced"]["TEXT"] = {
        "Rates type: Choose the rate type you prefer flying with. Raceflight and Actual are the most straightforward.",
        "Dynamics: Applied regardless of rates type. Typically left on defaults but can be adjusted to smooth heli movements, like with scale helis."
}

-- HARDWARE - SERVO TOOL
data["servos"] = {}
data["servos"]["TEXT"] = {
        "Please select the servo you would like to configure from the list below.", "Primary flight controls that use the rotoflight mixer will display in the section called 'mixer",
        "Any other servos that are not controlled by the primary flight mixer will be displayed in the section called 'Other servos'."
}

-- HARDWARE - SERVO TOOL
data["servos_tool"] = {}
data["servos_tool"]["TEXT"] = {
        "Override: [*]  Enable override to allow real time updates of servo center point.", 
        "Center: Adjust the center position of the servo.",
        "Minimum/Maximum: Adjust the end points of the selected servo.", 
        "Scale: Adjust the amount the servo moves for a given input.",
        "Rate: The frequency the servo runs best at - check with manufacturer.",
        "Speed: The speed the servo moves. Generally only used for the cyclic servos to help the swash move evenly. Optional - leave all at 0 if unsure."
}

-- HARDWARE - MIXER
data["mixer"] = {}
data["mixer"]["TEXT"] = {
        "Adust swash plate geometry, phase angles, and limits."
}

-- HARDWARE - ACCELEROMETER
data["accelerometer"] = {}
data["accelerometer"]["TEXT"] = {
        "If your helicopter drifts forward, back, left, or right when in angle mode, use the trim values to compensate."
}

-- HARDWARE - FILTERS
data["filters"] = {}
data["filters"]["TEXT"] = {
        "Typically you would not edit this page without checking your Blackbox logs!", 
        "Gyro lowpass: Lowpass filters for the gyro signal. Typically left at default.",
        "Gyro notch filters: Use for filtering specific frequency ranges. Typically not needed in most helis.",
        "Dynamic Notch Filters: Automatically creates notch filters within the min and max frequency range."
}

-- HARDWARE - GOVERNOR
data["governor"] = {}
data["governor"]["TEXT"] = {
        "These parameters apply globally to the governor regardless of the profile in use.", 
        "Each parameter is simply a time value in seconds for each governor action."
}

-- STATUS
data["status"] = {}
data["status"]["TEXT"] = {
        "Use this page to view your current flight controller status. This can be useful when determining why your heli will not arm.",
        "To erase the dataflash for more log file storage, press the button on the menu denoted by a '*'."
}

-- STATUS
data["about"] = {}
data["about"]["TEXT"] = {
        "This page provides some useful information that you may be asked for when requesting support.", 
        "For support, please first read the help pages on www.rotorflight.org"
}

-- SELECT PROFILE
data["select_profile"] = {}
data["select_profile"]["TEXT"] = {
        "Set the current flight profile or rate profile you would like to use.",
        "If you use use a switch on your radio to change flight or rate modes, this will over-ride this choice as soon as you toggle the switch."
}

-- COPY PROFILES
data["copy_profiles"] = {}
data["copy_profiles"]["TEXT"] = {
        "Copy PID profile or Rate profile from Source to Destination.", 
        "Choose the source and destinations and save to copy the profile."
}

-- SELECT PROFILE
data["msp_speed"] = {}
data["msp_speed"]["TEXT"] = {
        "This tool attempt to determine the quality of your MSP data link by performing as many large MSP queries within 30 seconds as possible."
}

-- EXP MSP
data["msp_exp"] = {}
data["msp_exp"]["TEXT"] = {
        "This tool provides the ability to send a custom byte string to the flight controller. It is useful for developers when debugging values.",
        "If you do not understand what you are doing, do not use it as bad things can happen."
}

-- LOGS
data["logs"] = {}
data["logs"]["TEXT"] = {
        "Please select a log file from the list below.",
        "Note. To enable logging it is essential for you to have the following sensors enabled.",
        "- arm status, voltage, headspeed, current,esc temperature"
}

-- LOGS TOOL
data["logs_tool"] = {}
data["logs_tool"]["TEXT"] = {
        "Please use the slider to navigate the graph.",
}


-- LuaFormatter on

return {data = data}
