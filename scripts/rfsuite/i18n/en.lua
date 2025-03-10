--[[

 * Copyright (C) Rotorflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]] --

local en = {
    -- General terms
    ethos                      = "ethos",
    version                    = "version",
    bg_task_disabled           = "bg task disabled",
    background_task_disabled   = "background task disabled",
    no_link                    = "no link",
    image                      = "image",
    error                      = "error",
    reload                     = "reload",
    save                       = "save",

    -- App
    app = {
        -- startup checks
        check_bg_task              = "Please enable the background task.",
        check_rf_module_on         = "Please check your rf module is turned on.",
        check_discovered_sensors   = "Please check you have discovered all sensors.",
        check_heli_on              = "Please check your heli is powered up and radio connected.",
        check_msp_version          = "Unable to determine MSP version in use.",
        check_supported_version    = "This version of the Lua script \ncan't be used with the selected model",

        -- error messages
        error_timed_out            = "Error: timed out",

        -- messages
        msg_save_current_page      = "Save current page to flight controller?",
        msg_save_settings          = "Save settings",
        msg_reload_settings        = "Reload data from flight controller?",
        msg_saving_settings        = "Saving settings...",
        msg_rebooting              = "Rebooting...",
        msg_save_not_commited      = "Save not committed to EEPROM",
        msg_please_disarm_to_save  = "Please disarm to save to ensure data integrity when saving.",
        msg_loading                = "Loading...",
        msg_loading_from_fbl       = "Loading data from flight controller...",
        msg_connecting             = "Connecting",
        msg_connecting_to_fbl      = "Connecting to flight controller...",
        msg_saving                 = "Saving...",
        msg_saving_to_fbl          = "Saving data to flight controller...",

        -- buttons
        btn_ok                     = "          OK           ",    -- intentionaly padded to make it bigger
        btn_cancel                 = "CANCEL",
        btn_close                  = "CLOSE",

        -- menu
        navigation_menu            = "MENU",
        navigation_save            = "SAVE",
        navigation_reload          = "RELOAD",
        navigation_tools           = "*",
        navigation_help            = "?",

        -- sections
        menu_section_flight_tuning = "Flight Tuning",
        menu_section_advanced      = "Advanced",
        menu_section_hardware      = "Hardware",
        menu_section_tools         = "Tools",
        menu_section_developer     = "Developer",
        menu_section_about         = "About",

        -- modules
        modules = {
            about = {
                name                = "About",
                version             = "Version",
                ethos_version       = "Ethos Version",
                msp_version         = "MSP Version",
                msp_transport       = "MSP Transport",
                supported_versions  = "Supported MSP Versions",
                simulation          = "Simulation",
                msgbox_credits      = "Credits",
                opener              = "Rotorflight is an open source project. Contribution from other like minded people, keen to assist in making this software even better, is welcomed and encouraged. You do not have to be a hardcore programmer to help.",
                credits             = "Notable contributors to both the Rotorflight firmware and this software are: Petri Mattila, Egon Lubbers, Rob Thomson, Rob Gayle, Phil Kaighin, Robert Burrow, Keith Williams, Bertrand Songis, Venbs Zhou... and many more who have spent hours testing and providing feedback!",
                license             = "You may copy, distribute, and modify the software as long as you track changes/dates in source files. Any modifications to or software including (via compiler) GPL-licensed code must also be made available under the GPL along with build & install instructions.",       
                help_p1               = "This page provides some useful information that you may be asked for when requesting support.",
                help_p2               = "For support, please first read the help pages on www.rotorflight.org",
            },
            accelerometer = {
                name =              "Accelerometer",
                roll =              "Roll",
                pitch =             "Pitch",
                help_p1 =            "The accelerometer is used to measure the angle of the flight controller in relation to the horizon. This data is used to stabilize the aircraft and provide self-leveling functionality.",
            },
            battery = {
                name =              "Battery",
                max_cell_voltage =  "Max Cell Voltage",
                full_cell_voltage = "Full Cell Voltage",
                warn_cell_voltage = "Warn Cell Voltage",
                min_cell_voltage =  "Min Cell Voltage",
                battery_capacity =  "Battery Capacity",
                cell_count =        "Cell Count",
                help_p1 =           "The battery settings are used to configure the flight controller to monitor the battery voltage and provide warnings when the voltage drops below a certain level.",   
            },
            copyprofiles = {
                name =              "Copy Profiles",
                profile_type =      "Profile Type",
                source_profile =    "Source Profile",
                dest_profile =      "Dest. Profile",
                profile_type_pid =  "PID",
                profile_type_rate = "Rate",
                msgbox_save =       "Save settings",
                msgbox_msg  =       "Save current page to flight controller?",
                help_p1 =           "Copy PID profile or Rate profile from Source to Destination.", 
                help_p2 =           "Choose the source and destinations and save to copy the profile.",
            },
            esc_motors = {
                name                    = "ESC/Motors",
                main_motor_ratio        = "Main Motor Ratio",
                tail_motor_ratio        = "Tail Motor Ratio",
                pinion                  = "Pinion",
                main                    = "Main",
                rear                    = "Rear",
                front                   = "Front",
                motor_pole_count        = "Motor Pole Count",
                min_throttle            = "0% Throttle PWM Value",
                max_throttle            = "100% Throttle PWM value",
                mincommand              = "Motor Stop PWM Value",
                voltage_correction      = "Voltage Correction",
                current_correction      = "Current Correction",
                consumption_correction  = "Consumption Correction",
                help_p1                 = "Configure the motor and speed controller features.",

            },
            esc_tools = {
                name =              "ESC Tools",
            },
            filters = {
                name                = "Filters",
                lowpass_1           = "Lowpass 1",
                lowpass_1_dyn       = "Lowpass 1 dyn.",
                lowpass_2           = "Lowpass 2",
                notch_1             = "Notch 1",
                notch_2             = "Notch 2",
                filter_type         = "Filter type",
                cutoff              = "Cutoff",
                min_cutoff          = "Min cutoff",
                max_cutoff          = "Max cutoff",
                center              = "Center",
                help_p1             = "Typically you would not edit this page without checking your Blackbox logs!", 
                help_p2             = "Gyro lowpass: Lowpass filters for the gyro signal. Typically left at default.", 
                help_p3             = "Gyro notch filters: Use for filtering specific frequency ranges. Typically not needed in most helis.", 
                help_p4             = "Dynamic Notch Filters: Automatically creates notch filters within the min and max frequency range.",
            },
            governor = {
                name                 = "Governor",
                mode                 = "Mode",
                handover_throttle    = "Handover throttle%",
                spoolup_min_throttle = "Min spoolup throttle%",
                startup_time         = "Startup time",
                spoolup_time         = "Spoolup time",
                tracking_time        = "Tracking time",
                recovery_time        = "Recovery time",
                help_p1              = "These parameters apply globally to the governor regardless of the profile in use.",
                help_p2              = "Each parameter is simply a time value in seconds for each governor action."
            },
            logs = {
                name                 = "Logs",
                msg_no_logs_found    = "NO LOG FILES FOUND",
                help_logs_p1         = "Please select a log file from the list below.",
                help_logs_p2         = "Note. To enable logging it is essential for you to have the following sensors enabled.",
                help_logs_p3         = "- arm status, voltage, headspeed, current, esc temperature",
                help_logs_tool_p1    = "Please use the slider to navigate the graph.",
            },
            mixer = {
                name                           = "Mixer",
                collective_tilt_correction     = "Collective Tilt Correction",
                geo_correction                 = "Geo Correction",
                swash_pitch_limit              = "Total Pitch Limit",
                collective_tilt_correction_pos = "Positive",
                collective_tilt_correction_neg = "Negative",
                swash_phase                    = "Phase Angle",
                swash_tta_precomp              = "TTA Precomp",
                tail_motor_idle                = "Tail Idle Thr%",
                help_p1                        = "Adust swash plate geometry, phase angles, and limits.",
            },
            msp_exp = {
                name =              "MSP Expermintal",
            },
            msp_speed = {
                name =              "MSP Speed",
            },
            pids = {
                name =              "PIDs",
            },
            profile_autolevel = {
                name =              "Autolevel",
            },
            profile_governor = {
                name =              "Governor",
            },
            profile_mainrotor = {
                name =              "Main Rotor",
            },
            profile_pidbandwidth = {
                name =              "PID Bandwidth",
            },
            profile_pidcontroller = {
                name =              "PID Controller",
            },
            profile_rescue = {
                name =              "Rescue",
            },
            profile_select = {
                name =              "Select Profile",
            },
            profile_tailrotor = {
                name =              "Tail Rotor",
            },
            radio_config = {
                name =              "Radio Config",
            },
            rates = {
                name =              "Rates",
            },
            rates_advanced = {
                name =              "Rates",
            },
            sbusout = {
                name =              "SBUS Out",
            },
            servos  = {
                name =              "Servos",
            },
            status = {
                name =              "Status",
            },
            trim = {
                name =              "Trim",
            },
            validate_sensors = {
                name =              "Sensors",
            },

        },

    },

    -- Widgets
    widgets = {
        governor = {
                UNKNOWN   = "UNKNOWN",
                OFF       = "OFF",
                IDLE      = "IDLE",
                SPOOLUP   = "SPOOLUP",
                RECOVERY  = "RECOVERY",
                ACTIVE    = "ACTIVE",
                THROFF    = "THR-OFF",
                LOSTHS    = "LOST-HS",
                AUTOROT   = "AUTOROT",
                BAILOUT   = "BAILOUT",
                DISABLED  = "DISABLED",
                DISARMED  = "DISARMED"
        },
    },

}

return en
