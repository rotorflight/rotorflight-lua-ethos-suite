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


local function armingDisableFlagsToString(flags)
    local t = ""
    for i = 0, 25 do
        if (flags & (1 << i)) ~= 0 then
            if t ~= "" then t = t .. ", " end
            if i == 0 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_0") end
            if i == 1 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_1") end
            if i == 2 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_2") end
            if i == 3 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_3") end
            if i == 4 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_4") end
            if i == 5 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_5") end
            -- if i == 6 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_6") end
            if i == 7 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_7") end
            if i == 8 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_8") end
            if i == 9 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_9") end
            if i == 10 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_10") end
            if i == 11 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_11") end
            if i == 12 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_12") end
            if i == 13 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_13") end
            if i == 14 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_14") end
            if i == 15 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_15") end
            if i == 16 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_16") end
            if i == 17 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_17") end
            if i == 18 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_18") end
            if i == 19 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_19") end
            if i == 20 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_20") end
            if i == 21 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_21") end
            if i == 22 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_22") end
            if i == 23 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_23") end
            if i == 24 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_24") end
            if i == 25 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_25") end
        end
    end

    if t == "" then t = rfsuite.i18n.get("app.modules.status.ok") end
    return t
end

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

local function getSensors()
    if not rfsuite then return end
    if not rfsuite.tasks.active() then return end


    local armdisableflagsSOURCE = rfsuite.tasks.telemetry.getSensorSource("armdisableflags")

    if not rfsuite.tasks.telemetry.active() then
        armdisableflags = rfsuite.i18n.get("no_link"):upper()
    elseif armdisableflagsSOURCE then
        local value = armdisableflagsSOURCE:value()
        if value ~= nil then
            value = math.floor(value)
        end
        armdisableflags = armingDisableFlagsToString(value)
    else    
        armdisableflags = rfsuite.i18n.get("no_link"):upper()
    end


    if disarmed.oldsensors.armdisableflags ~= armdisableflags then disarmed.refresh = true end

    sensors = {armdisableflags = armdisableflags}
    disarmed.oldsensors = sensors

    return sensors
end

local function wakeupUI()

    getSensors()

    if disarmed.refresh then lcd.invalidate() end
    disarmed.refresh = false
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
        screenError(string.format(string.upper(rfsuite.i18n.get("ethos")) .." < V%d.%d.%d", 
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
    local schedulerUI = lcd.isVisible() and 0.5 or 5
    local now = os.clock()

    if (now - disarmed.wakeupSchedulerUI) >= schedulerUI then
        disarmed.wakeupSchedulerUI = now
        wakeupUI()
    end

end

-- this is called if a langage swap event occurs
function disarmed.i18n()

end    

return disarmed
