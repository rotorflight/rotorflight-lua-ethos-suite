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

local modelpreferences = {}

local modelpref_defaults ={
    dashboard = {
        theme_preflight = "nil",
        theme_inflight = "nil",
        theme_postflight = "nil",
    },
    general ={
        flightcount = 0,
        totalflighttime = 0,
        lastflighttime = 0,
        batterylocalcalculation = 1,
    },
    battery = {
        sag_multiplier = 0.5,
        calc_local = 0,
        alert_type = 0,
        becalertvalue = 6.5,
        rxalertvalue = 7.5,
        flighttime = 300,
    }
}

function modelpreferences.wakeup()

    -- quick exit if no apiVersion
    if rfsuite.session.apiVersion == nil then
        rfsuite.session.modelPreferences = nil 
        return 
    end    

    --- check if we have a mcu_id
    if not rfsuite.session.mcu_id then
        rfsuite.session.modelPreferences = nil
        return
    end
  

    if (rfsuite.session.modelPreferences == nil)  then
             -- populate the model preferences variable

        if rfsuite.config.preferences and rfsuite.session.mcu_id then

            local modelpref_file = "SCRIPTS:/" .. rfsuite.config.preferences .. "/models/" .. rfsuite.session.mcu_id ..".ini"
            rfsuite.utils.log("Preferences file: " .. modelpref_file, "info")

            os.mkdir("SCRIPTS:/" .. rfsuite.config.preferences)
            os.mkdir("SCRIPTS:/" .. rfsuite.config.preferences .. "/models")


            local slave_ini = modelpref_defaults
            local master_ini  = rfsuite.ini.load_ini_file(modelpref_file) or {}


            local updated_ini = rfsuite.ini.merge_ini_tables(master_ini, slave_ini)
            rfsuite.session.modelPreferences = updated_ini
            rfsuite.session.modelPreferencesFile = modelpref_file

            if not rfsuite.ini.ini_tables_equal(master_ini, slave_ini) then
                rfsuite.ini.save_ini_file(modelpref_file, updated_ini)
            end      
                   
        end
    end

end

function modelpreferences.reset()
    rfsuite.session.modelPreferences = nil
    rfsuite.session.modelPreferencesFile = nil
end

function modelpreferences.isComplete()
    if rfsuite.session.modelPreferences ~= nil  then
        return true
    end
end

return modelpreferences