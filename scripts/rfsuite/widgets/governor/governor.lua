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

local rf2gov = {refresh = true, environment = system.getVersion(), oldsensors = {govmode = ""}, wakeupSchedulerUI = os.clock()}

local sensors

local function buildGovernorMap()
    local map = {     
        [0] =  rfsuite.i18n.get("widgets.governor.OFF"),
        [1] =  rfsuite.i18n.get("widgets.governor.IDLE"),
        [2] =  rfsuite.i18n.get("widgets.governor.SPOOLUP"),
        [3] =  rfsuite.i18n.get("widgets.governor.RECOVERY"),
        [4] =  rfsuite.i18n.get("widgets.governor.ACTIVE"),
        [5] =  rfsuite.i18n.get("widgets.governor.THROFF"),
        [6] =  rfsuite.i18n.get("widgets.governor.LOSTHS"),
        [7] =  rfsuite.i18n.get("widgets.governor.AUTOROT"),
        [8] =  rfsuite.i18n.get("widgets.governor.BAILOUT"),
        [100] = rfsuite.i18n.get("widgets.governor.DISABLED"),
        [101] = rfsuite.i18n.get("widgets.governor.DISARMED")
    }

    return map
end

local governorMap = buildGovernorMap()

-- error function
local function screenError(msg)
    local w, h = lcd.getWindowSize()
    local isDarkMode = lcd.darkMode()

    -- Available font sizes in order from smallest to largest
    local fonts = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL}

    -- Determine the maximum width and height with 10% padding
    local maxW, maxH = w * 0.9, h * 0.9
    local bestFont = FONT_XXS
    local bestW, bestH = 0, 0

    -- Loop through font sizes and find the largest one that fits
    for _, font in ipairs(fonts) do
        lcd.font(font)
        local tsizeW, tsizeH = lcd.getTextSize(msg)
        
        if tsizeW <= maxW and tsizeH <= maxH then
            bestFont = font
            bestW, bestH = tsizeW, tsizeH
        else
            break  -- Stop checking larger fonts once one exceeds limits
        end
    end

    -- Set the optimal font
    lcd.font(bestFont)

    -- Set text color based on dark mode
    local textColor = isDarkMode and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90)
    lcd.color(textColor)

    -- Center the text on the screen
    local x = (w - bestW) / 2
    local y = (h - bestH) / 2
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
        status.screenError(string.format(string.upper(rfsuite.i18n.get("ethos")) .." < V%d.%d.%d", 
            rfsuite.config.ethosVersion[1], 
            rfsuite.config.ethosVersion[2], 
            rfsuite.config.ethosVersion[3])
        )
        return
    end

    local w, h = lcd.getWindowSize()

    -- Available font sizes ordered from smallest to largest
    local fonts = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL}

    -- Determine the maximum width and height with 10% padding
    local maxW, maxH = w * 0.9, h * 0.9
    local bestFont = FONT_XXS
    local bestW, bestH = 0, 0

    -- Determine the text to display
    local str = rfsuite.tasks.active() and (sensors and sensors.govmode or "") or string.upper(rfsuite.i18n.get("bg_task_disabled"))

    -- Loop through font sizes and find the largest one that fits
    for _, font in ipairs(fonts) do
        lcd.font(font)
        local tsizeW, tsizeH = lcd.getTextSize(str)
        
        if tsizeW <= maxW and tsizeH <= maxH then
            bestFont = font
            bestW, bestH = tsizeW, tsizeH
        else
            break  -- Stop checking larger fonts once one exceeds limits
        end
    end

    -- Set the optimal font
    lcd.font(bestFont)

    -- Calculate centered position
    local posX = (w - bestW) / 2
    local posY = (h - bestH) / 2 + 5

    -- Draw the text
    lcd.drawText(posX, posY, str)
end


function rf2gov.getSensors()
    if not rfsuite.tasks.active() then return end

    local govmode = ""

    local govSOURCE = rfsuite.tasks.telemetry.getSensorSource("governor")

    if rfsuite.tasks.telemetry.getSensorProtocol() == 'lcrsf' then
        govmode = govSOURCE and govSOURCE:stringValue() or ""
    else
        local govId = govSOURCE and govSOURCE:value()
        govmode = governorMap[govId] or (govId and rfsuite.i18n.get("widgets.governor.UNKNOWN") or "")
    end


    if rf2gov.oldsensors.govmode ~= govmode then rf2gov.refresh = true end

    sensors = {govmode = govmode}
    rf2gov.oldsensors = sensors

    return sensors
end

-- Main wakeup function
function rf2gov.wakeup(widget)
    local schedulerUI = lcd.isVisible() and 0.25 or 5
    local now = os.clock()

    if (now - rf2gov.wakeupSchedulerUI) >= schedulerUI then
        rf2gov.wakeupSchedulerUI = now
        rf2gov.wakeupUI()
    end

end

function rf2gov.wakeupUI()

    rf2gov.getSensors()

    if rf2gov.refresh then lcd.invalidate() end
    rf2gov.refresh = false
end

-- this is called if a langage swap event occurs
function rf2gov.i18n()
    governorMap = buildGovernorMap()
end    

return rf2gov
