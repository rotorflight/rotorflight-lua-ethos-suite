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

-- Dashboard module table
local toolbox= {}  

local wakeupSchedulerUI = os.clock()
local LCD_W, LCD_H


local config = {
    object = nil,
}

local state = {
    setup = false,
}

local objectList = {
    {"Telemetry", 1},
    {"ArcGauge",2},
    {"ArcGauge2",3},
}

function toolbox.create()
    return {value=0}
end    

function toolbox.paint(config)
    if not LCD_W or not LCD_H then
        LCD_W, LCD_H = lcd.getWindowSize()
    end

    -- if not configured, show a message
    if state.setup == false then
        if lcd.darkMode() then
            lcd.color(COLOR_WHITE)
        else
            lcd.color(COLOR_BLACK)
        end

        local message = "NOT CONFIGURED"
        local mw,mh = lcd.getTextSize(message)

        lcd.drawText((LCD_W - mw) / 2, (LCD_H - mh) / 2, message)
        return
    else
        if lcd.darkMode() then
            lcd.color(COLOR_WHITE)
        else
            lcd.color(COLOR_BLACK)
        end

        local message = config.object
        local mw,mh = lcd.getTextSize(message)

        lcd.drawText((LCD_W - mw) / 2, (LCD_H - mh) / 2, message)
        return
    end


end

function toolbox.wakeup(config)
    local schedulerUI = lcd.isVisible() and 0.5 or 5
    local now = os.clock()

    if (now - wakeupSchedulerUI) >= schedulerUI then
        wakeupSchedulerUI = now

        if config.object then
            state.setup = true
        end
        lcd.invalidate()
    end

end

function toolbox.configure(config)

    -- inflight theme selection                                                          
    local formFieldCount = (formFieldCount or 0) + 1
    local formLineCnt = (formLineCnt or 0) + 1
    local formLines = {}
    local formFields = {}
    
    formLines[formLineCnt] = form.addLine("Object type")                    
    formFields[formFieldCount] = form.addChoiceField(formLines[formLineCnt], nil, 
                                                        objectList, 
                                                        function()
                                                            if not config.object then config.object = 1 end    
                                                            return config.object
                                                        end, 
                                                        function(newValue) 
                                                            config.object = newValue
                                                        end)    


end

function toolbox.read(config)
    print("toolbox.read()")
    config.object = (function(ok, result) return ok and result end)(pcall(storage.read, "object"))
end

function toolbox.write(config)
    print("toolbox.write()")
    storage.write("object", config.object)
end 

-- no titles used
toolbox.title = false

return toolbox
