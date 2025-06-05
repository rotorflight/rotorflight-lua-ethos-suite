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

local disarmed = { 
    refresh = true, 
    environment = system.getVersion(), 
    oldsensors = {armdisableflags = ""}, 
    wakeupSchedulerUI = os.clock()
}

local sensors


local function getSensors()
    if not rfsuite then return end
    if not rfsuite.tasks.active() then return end


    local armdisableflagsSOURCE = rfsuite.tasks.telemetry.getSensorSource("armdisableflags")

    if not rfsuite.tasks.telemetry.active() then
        armdisableflags = rfsuite.i18n.get("no_link"):upper()
    elseif rfsuite.session.apiVersion and rfsuite.session.apiVersion < 12.08 then
        armdisableflags = "RF < 2.2"
    elseif armdisableflagsSOURCE then
        local value = armdisableflagsSOURCE:value()
        if value ~= nil then
            value = math.floor(value)
        end
        armdisableflags = rfsuite.app.utils.armingDisableFlagsToString(value)

    elseif armdisableflagsSOURCE  == nil then
        armdisableflags = rfsuite.i18n.get("no_sensor"):upper()
    else            
        armdisableflags = rfsuite.i18n.get("no_link"):upper()
    end


    if disarmed.oldsensors.armdisableflags ~= armdisableflags then disarmed.refresh = true end

    sensors = {armdisableflags = armdisableflags}
    disarmed.oldsensors = sensors

    return sensors
end

-- Helper function to convert a value to a valid number
function disarmed.sensorMakeNumber(value)
    value = value or 0
    local num = tonumber(string.gsub(tostring(value), "%D+", ""))
    return num or 0
end

function disarmed.create(widget)
    -- Placeholder for widget creation logic
end

function disarmed.paint(widget)
    if not rfsuite.utils.ethosVersionAtLeast() then
        rfsuite.widgets.toolbox.utils.screenError(string.format(string.upper(rfsuite.i18n.get("ethos")) .." < V%d.%d.%d", 
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
    local str = rfsuite.tasks.active() and (sensors and sensors.armdisableflags or "") or string.upper(rfsuite.i18n.get("bg_task_disabled"))

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

-- Main wakeup function
function disarmed.wakeup(widget)

    getSensors()

    if disarmed.refresh then lcd.invalidate() end
    disarmed.refresh = false
end

-- this is called if a langage swap event occurs
function disarmed.i18n()

end    

return disarmed
