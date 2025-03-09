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
