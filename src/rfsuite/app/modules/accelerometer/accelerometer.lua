--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local labels = {}
local fields = {}

local calibrate = false
local calibrateComplete = false
local calibrateQueued = false
local eepromQueued = false
local calibrationAPI
local eepromAPI

local apidata = {
    api = {
        [1] = 'ACC_TRIM'
    },
    formdata = {
        labels = {},
        fields = {
            { t = "@i18n(app.modules.accelerometer.roll)@",  mspapi = 1, apikey = "roll" },
            { t = "@i18n(app.modules.accelerometer.pitch)@", mspapi = 1, apikey = "pitch" }
        }
    }
}

local function onToolMenu(self)

    local buttons = {
        {
            label = "@i18n(app.btn_ok)@",
            action = function()

                calibrate = true
                calibrateQueued = false
                calibrateComplete = false
                eepromQueued = false
                return true
            end
        }, {label = "@i18n(app.btn_cancel)@", action = function() return true end}
    }

    form.openDialog({width = nil, title = "@i18n(app.modules.accelerometer.name)@", message = "@i18n(app.modules.accelerometer.msg_calibrate)@", buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})

end

local function ensureApis()
    if not calibrationAPI then
        calibrationAPI = rfsuite.tasks.msp.api.loadPage("ACC_CALIBRATION")
        calibrationAPI.setUUID("accelerometer-calibration")
    end
    if not eepromAPI then
        eepromAPI = rfsuite.tasks.msp.api.loadPage("EEPROM_WRITE")
        eepromAPI.setUUID("accel-eeprom")
    end
end

local function applySettings()
    ensureApis()
    eepromAPI.resetWriteStatus()
    local ok, reason = eepromAPI.write()
    if ok then
        eepromQueued = true
    else
        rfsuite.utils.log("Accelerometer EEPROM enqueue rejected: " .. tostring(reason), "info")
    end
end

local function wakeup()

    if calibrate == true and calibrateQueued == false then
        ensureApis()
        calibrationAPI.resetWriteStatus()
        local ok, reason = calibrationAPI.write()
        if ok then
            calibrateQueued = true
        else
            rfsuite.utils.log("Accelerometer calibration enqueue rejected: " .. tostring(reason), "info")
            calibrate = false
        end

    end

    if calibrateQueued == true and calibrationAPI and calibrationAPI.writeComplete() then
        rfsuite.utils.log("Accelerometer calibrated.", "info")
        calibrate = false
        calibrateQueued = false
        applySettings()
    end

    if eepromQueued == true and eepromAPI and eepromAPI.writeComplete() then
        eepromQueued = false
        rfsuite.utils.log("Writing to EEPROM", "info")
        calibrateComplete = true
    end

    if calibrateComplete == true then
        calibrateComplete = false
        rfsuite.utils.playFileCommon("beep.wav")
    end

end

return {apidata = apidata, eepromWrite = true, reboot = false, API = {}, navButtons = {menu = true, save = true, reload = true, tool = true, help = true}, onToolMenu = onToolMenu, wakeup = wakeup}
