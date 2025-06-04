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
local wakeupSchedulerUI = os.clock()
local LCD_W, LCD_H

-- List of available sub-widgets (folder names must match these entries)
local toolBoxList = {
    [1] = { folder = "armed",      name = "Armed"      },
    [2] = { folder = "bbl",        name = "BBL"        },
    [3] = { folder = "craftimage", name = "Craft Image"},
    [4] = { folder = "craftname",  name = "Craft Name" },
    [5] = { folder = "disarmed",   name = "Disarmed"   },
    [6] = { folder = "governor",   name = "Governor"   },
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
    return {
        value = 0,
        state = { setup = false },
        loadedWidget = nil
    }
end

-- Internal function: attempt to load the chosen sub-widget into widget.loadedWidget
local function tryLoadSubWidget(widget)
    if widget.loadedWidget or not widget.object then
        return
    end

    local entry = toolBoxList[widget.object]
    if not (entry and entry.folder) then
        return
    end

    -- Construct path to the sub-widget’s main Lua file
    -- (expects: SCRIPTS:/<baseDir>/widgets/toolbox/widgets/<folder>/<folder>.lua)
    local widgetPath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/toolbox/objects/" .. entry.folder .. "/" .. entry.folder .. ".lua"


    -- First, attempt to load the chunk (returns a function)
    local okChunk, chunk = pcall(function()
        return rfsuite.compiler.loadfile(widgetPath)
    end)
    if not okChunk or type(chunk) ~= "function" then
        print("Error loading chunk from path")
        return
    end

    -- Now execute the chunk to get the module table
    local okModule, mod = pcall(chunk)
    if not okModule or type(mod) ~= "table" then
        print("Error: loaded chunk did not return a table")
        return
    end

    widget.loadedWidget = mod
    -- If the sub-widget has its own init(), call it now
    if type(widget.loadedWidget.init) == "function" then
        widget.loadedWidget.init(widget)
    end

    -- Mark as set up so paint won’t show “NOT CONFIGURED”
    widget.state.setup = true

    -- Force a redraw so paint() can display the newly loaded widget
    lcd.invalidate()
end

-- Delegate paint to the chosen sub-widget (once set up)
function toolbox.paint(widget)
    -- Cache window size once
    if not LCD_W or not LCD_H then
        LCD_W, LCD_H = lcd.getWindowSize()
    end

    -- If the user hasn’t selected a sub-widget yet, show “NOT CONFIGURED”
    if not widget.state.setup then
        -- Try loading now (in case wakeup hasn’t run yet)
        tryLoadSubWidget(widget)
    end

    if widget.state.setup and widget.loadedWidget and type(widget.loadedWidget.paint) == "function" then
        widget.loadedWidget.paint(widget)
    else
        -- Fallback: show “NOT CONFIGURED”
        if lcd.darkMode() then
            lcd.color(COLOR_WHITE)
        else
            lcd.color(COLOR_BLACK)
        end
        local message = "NOT CONFIGURED"
        local mw, mh = lcd.getTextSize(message)
        lcd.drawText((LCD_W - mw) / 2, (LCD_H - mh) / 2, message)
    end
end

-- Delegate wakeup to the chosen sub-widget (once set up)
function toolbox.wakeup(widget)
    local schedulerUI = lcd.isVisible() and 0.5 or 5
    local now = os.clock()

    if (now - wakeupSchedulerUI) >= schedulerUI then
        wakeupSchedulerUI = now

        -- Once there’s a selected index, mark setup = true and attempt load
        if widget.object then
            if not widget.state.setup then
                tryLoadSubWidget(widget)
            end
        end

        -- Always invalidate so the next paint() reflects any changes
        lcd.invalidate()
    end

    -- If setup is done and we have a loaded sub-widget, delegate wakeup()
    if widget.state.setup and widget.loadedWidget and type(widget.loadedWidget.wakeup) == "function" then
        widget.loadedWidget.wakeup(widget)
    end
end

function toolbox.menu(widget)
        if widget.state.setup and widget.loadedWidget and type(widget.loadedWidget.menu) == "function" then
            return widget.loadedWidget.menu(widget)
        end
        return {}
end       

function toolbox.i18n(widget)
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
    print("toolbox.read()")
    widget.object = (function(ok, result) return ok and result end)(pcall(storage.read, "object"))
end

-- Save the user’s selection
function toolbox.write(widget)
    print("toolbox.write()")
    storage.write("object", widget.object)
end

-- No titles are used by this wrapper
toolbox.title = false

return toolbox
