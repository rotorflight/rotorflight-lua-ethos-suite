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

local toolbox = {}
local wakeupScheduler
local LCD_W, LCD_H

-- List of available sub-widgets (folder names must match these entries)
local toolBoxList = {
    [1] = { object = "armflags",   name = "Arming Flags"        },
    [2] = { object = "bbl",        name = "Black Box"           },
    [3] = { object = "craftname",  name = "Craft Name"          },
    [4] = { object = "governor",   name = "Governor"            },
    [5] = { object = "craftimage", name = "Craft Image"         },
}


-- Helper to build a list of “{ displayName, index }” for the form
local function generateWidgetList(tbl)
    local widgets = {}
    for i, tool in ipairs(tbl) do
        table.insert(widgets, { tool.name, i })
    end
    return widgets
end

-- Called once when the widget is created.
-- We attach per-instance state and loadedWidget fields to 'widget'.
function toolbox.create()

    wakeupScheduler = os.clock()

    return {
        value = 0,
        state = { setup = false },
        loadedWidget = nil
    }
end

-- Delegate paint to the chosen sub-widget (once set up)
function toolbox.paint(widget)
 
    if not rfsuite.session.toolbox then
        return
    end

    if not widget.object then
        return
    end

    local msg = rfsuite.session.toolbox[toolBoxList[widget.object].object] or "-"
    local title = toolBoxList[widget.object].name 

    local w, h = lcd.getWindowSize()
    local isDarkMode = lcd.darkMode()

    local offsetY = 0

    local TITLE_COLOR = lcd.darkMode() and lcd.RGB(154,154,154) or lcd.RGB(77, 73, 77)
    local TEXT_COLOR = lcd.darkMode() and lcd.RGB(255, 255, 255) or lcd.RGB(77, 73, 77)

    ---------------------------------------------------------------------------
    -- Step 1.  Display the title at top of the screen
    ---------------------------------------------------------------------------
    if widget.title then
        local fonts = {FONT_XXS, FONT_XS, FONT_S}

    -- Determine the maximum width and height with 10% padding
        local maxW, maxH = w * 0.9 , h
        local bestFont = FONT_XXS
        local bestW, bestH = 0, 0

        -- Loop through font sizes and find the largest one that fits
        for _, font in ipairs(fonts) do
            lcd.font(font)
            local tsizeW, tsizeH = lcd.getTextSize(title)
            
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

        -- Center the text at top of the screen
        local x = (w - bestW) / 2
        local y = bestH/4
        lcd.color(TITLE_COLOR)  -- Set title color
        lcd.drawText(x, y, title)    

        -- if we have a title, we need to bump the y position down for the display of the value message
        offsetY = bestH - 3  -- Add some padding below the title

    end

    ---------------------------------------------------------------------------
    -- Step 2.  Display the value message in the center of the screen
    ---------------------------------------------------------------------------
    if type(msg) == "string" then
            -- Available font sizes in order from smallest to largest
            local fonts = {FONT_XXS, FONT_XS, FONT_S, FONT_M, FONT_L, FONT_XL, FONT_XXL}

            -- Determine the maximum width and height with 10% padding
            local maxW, maxH = w * 0.9 , h 
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

            -- Center the text on the screen
            local x = (w - bestW) / 2
            local y = (h - bestH) / 2 + offsetY  -- Adjust y position based on title height
            lcd.color(TEXT_COLOR)  -- Reset text color for values
            lcd.drawText(x, y, msg)
        elseif type(msg) == "function" then
            msg()
        else 
            -- we probably have an image!
            local bitmapPtr = msg
            local bitmapX = 0
            local bitmapY = 0
            local bitmapW = w
            local bitmapH = h

            lcd.drawBitmap(bitmapX, bitmapY + offsetY, bitmapPtr, bitmapW, bitmapH - offsetY)

        end
end


-- Delegate wakeup to the chosen sub-widget (once set up)
function toolbox.wakeup(widget)

    -- initialise this - which then enables the bgtask
    if not rfsuite.session.toolbox then
        rfsuite.session.toolbox = {}
        return
    end

    local scheduler = lcd.isVisible() and 0.25 or 5
    local now = os.clock()

    --run lcd.invalidate on the schedule provided by scheduler
    if now - (widget.wakeupScheduler or 0) > scheduler then
        lcd.invalidate()
        widget.wakeupScheduler = now
    end
 


end

function toolbox.menu(widget)
        if widget.state.setup and widget.loadedWidget and type(widget.loadedWidget.menu) == "function" then
            return widget.loadedWidget.menu(widget)
        end
        return {}
end       

function toolbox.i18n(widget)
    if not widget then return {} end
        if widget.state.setup and widget.loadedWidget and type(widget.loadedWidget.i18n) == "function" then
            return widget.loadedWidget.i18n(widget)
        end
        return {}
end  

-- Build the “Configure” form so the user can pick which sub-widget to use
function toolbox.configure(widget)
    local formLines = {}
    local formFields = {}
    local formLineCnt = 0
    local formFieldCount = 0

        formLineCnt = formLineCnt + 1
        formLines[formLineCnt] = form.addLine("Title")
        formFieldCount = formFieldCount + 1
        formFields[formFieldCount] = form.addBooleanField(formLines[formLineCnt], 
        nil, 
        function() 
          return widget.title
        end, 
        function(newValue) 
          if widget.title and widget.title ~= newValue then
            widget.state.setup       = false
            widget.loadedWidget      = nil
            widget.wakeupSchedulerUI = 0
          end
          widget.title = newValue
        end)  



    formLineCnt = formLineCnt + 1
    formLines[formLineCnt] = form.addLine("Widget type")
    formFieldCount = formFieldCount + 1
    formFields[formFieldCount] = form.addChoiceField(
        formLines[formLineCnt],
        nil,
        generateWidgetList(toolBoxList),
        function()
            if not widget.object then
                widget.object = 1
            end
            return widget.object
        end,
        function(newValue)
            widget.object = newValue
            -- Reset per-instance state so we reload the new sub-widget
            widget.state.setup = false
            widget.loadedWidget = nil
        end
    )
end

-- Persist the user’s selection
function toolbox.read(widget)
    widget.title = (function(ok, result) return ok and result end)(pcall(storage.read, "title"))
    widget.object = (function(ok, result) return ok and result end)(pcall(storage.read, "object"))
end

-- Save the user’s selection
function toolbox.write(widget)
    storage.write("title", widget.title)
    storage.write("object", widget.object)
end

function toolbox.close()
    rfsuite.session.toolbox = nil
end

-- No titles are used by this wrapper
toolbox.title = false

return toolbox
