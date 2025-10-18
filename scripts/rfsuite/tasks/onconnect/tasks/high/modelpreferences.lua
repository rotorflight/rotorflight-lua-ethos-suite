--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local modelpreferences = {}

local modelpref_defaults = {dashboard = {theme_preflight = "nil", theme_inflight = "nil", theme_postflight = "nil"}, general = {flightcount = 0, totalflighttime = 0, lastflighttime = 0, batterylocalcalculation = 1}, battery = {sag_multiplier = 0.5, calc_local = 0, alert_type = 0, becalertvalue = 6.5, rxalertvalue = 7.5, flighttime = 300}}

function modelpreferences.wakeup()

    if rfsuite.session.apiVersion == nil then
        rfsuite.session.modelPreferences = nil
        return
    end

    if rfsuite.session.mspBusy then return end

    if not rfsuite.session.mcu_id then
        rfsuite.session.modelPreferences = nil
        return
    end

    if (rfsuite.session.modelPreferences == nil) then

        if rfsuite.config.preferences and rfsuite.session.mcu_id then

            local modelpref_file = "SCRIPTS:/" .. rfsuite.config.preferences .. "/models/" .. rfsuite.session.mcu_id .. ".ini"
            rfsuite.utils.log("Preferences file: " .. modelpref_file, "info")

            os.mkdir("SCRIPTS:/" .. rfsuite.config.preferences)
            os.mkdir("SCRIPTS:/" .. rfsuite.config.preferences .. "/models")

            local slave_ini = modelpref_defaults
            local master_ini = rfsuite.ini.load_ini_file(modelpref_file) or {}

            local updated_ini = rfsuite.ini.merge_ini_tables(master_ini, slave_ini)
            rfsuite.session.modelPreferences = updated_ini
            rfsuite.session.modelPreferencesFile = modelpref_file

            if not rfsuite.ini.ini_tables_equal(master_ini, slave_ini) then rfsuite.ini.save_ini_file(modelpref_file, updated_ini) end

        end
    end

end

function modelpreferences.reset()
    rfsuite.session.modelPreferences = nil
    rfsuite.session.modelPreferencesFile = nil
end

function modelpreferences.isComplete() if rfsuite.session.modelPreferences ~= nil then return true end end

return modelpreferences
