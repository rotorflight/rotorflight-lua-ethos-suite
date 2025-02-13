--[[
 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]] --
--[[
set crsf_flight_mode_reuse = GOV_ADJFUNC
]] --
local rf2gov = {refresh = true, environment = system.getVersion(), oldsensors = {govmode = ""}, wakeupSchedulerUI = os.clock()}

local governorMap = {[0] = "OFF", [1] = "IDLE", [2] = "SPOOLUP", [3] = "RECOVERY", [4] = "ACTIVE", [5] = "THR-OFF", [6] = "LOST-HS", [7] = "AUTOROT", [8] = "BAILOUT", [100] = "DISABLED", [101] = "DISARMED"}

local sensors

-- error function
local function screenError(msg)
    local w, h = lcd.getWindowSize()
    local isDarkMode = lcd.darkMode()

    lcd.font(FONT_STD)
    local tsizeW, tsizeH = lcd.getTextSize(msg)

    -- Set color based on theme
    local textColor = isDarkMode and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90)
    lcd.color(textColor)

    -- Center the text on the screen
    local x = (w - tsizeW) / 2
    local y = (h - tsizeH) / 2
    lcd.drawText(x, y, msg)
end

-- Helper function to convert a value to a valid number
function rf2gov.sensorMakeNumber(value)
    value = value or 0
    local num = tonumber(string.gsub(tostring(value), "%D+", ""))
    return num or 0
end

function rf2gov.create(widget)
    -- Placeholder for widget creation logic
end

function rf2gov.paint(widget)

    if not rfsuite.utils.ethosVersionAtLeast() then
        status.screenError(string.format("ETHOS < V%d.%d.%d", 
            rfsuite.config.ethosVersion[1], 
            rfsuite.config.ethosVersion[2], 
            rfsuite.config.ethosVersion[3])
        )
        return
    end

    local w, h = lcd.getWindowSize()
    lcd.font(FONT_XXL)

    local str = rfsuite.bg.active() and (sensors and sensors.govmode or "") or "BG TASK DISABLED"
    local tsizeW, tsizeH = lcd.getTextSize(str)

    local posX = (w - tsizeW) / 2
    local posY = (h - tsizeH) / 2 + 5

    lcd.drawText(posX, posY, str)
end

function rf2gov.getSensors()
    if not rfsuite.bg.active() then return end

    local govmode = ""

    if rf2gov.environment.simulation then
        govmode = "DISABLED"
    else
        local govSOURCE = rfsuite.bg.telemetry.getSensorSource("governor")

        if rfsuite.bg.telemetry.getSensorProtocol() == 'lcrsf' then
            govmode = govSOURCE and govSOURCE:stringValue() or ""
        else
            local govId = govSOURCE and govSOURCE:value()
            govmode = governorMap[govId] or (govId and "UNKNOWN" or "")
        end
    end

    if rf2gov.oldsensors.govmode ~= govmode then rf2gov.refresh = true end

    sensors = {govmode = govmode}
    rf2gov.oldsensors = sensors

    return sensors
end

-- Main wakeup function
function rf2gov.wakeup(widget)
    local schedulerUI = lcd.isVisible() and 0.25 or 1
    local now = os.clock()

    if (now - rf2gov.wakeupSchedulerUI) >= schedulerUI then
        rf2gov.wakeupSchedulerUI = now
        rf2gov.wakeupUI()
    end
end

function rf2gov.wakeupUI()
    rf2gov.refresh = false
    rf2gov.getSensors()

    if rf2gov.refresh then lcd.invalidate() end
end

return rf2gov
