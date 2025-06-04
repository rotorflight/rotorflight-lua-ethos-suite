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
local LCD_W, LCD_H

-- List of available sub-widgets (folder names must match these entries)
local toolBoxList = {
  [1] = { script = "armflags.lua",   name = "Arm Flags"   },
  [2] = { script = "blackbox.lua",   name = "Blackbox"    },
  [3] = { script = "modelimage.lua", name = "Model Image" },
  [4] = { script = "craftname.lua",  name = "Craft Name"  },
  [5] = { script = "governor.lua",   name = "Governor"    },
}

-----------------------------------------------------------------------------
-- 1) Keep load_object so sub-widgets (armflags/governor/etc.) can call it
-----------------------------------------------------------------------------
-- Sub-widgets like governor.lua do “rfsuite.widgets.toolbox.load_object(box.type)”
-- to pull in their dashboard/objects/<type>.lua. If load_object is missing, they
-- will throw “chunk did not return a table” errors.
function toolbox.load_object(object)
  local path = "SCRIPTS:/" .. rfsuite.config.baseDir 
             .. "/widgets/dashboard/objects/" .. object .. ".lua"
  local chunk = rfsuite.compiler.loadfile(path)
  if not chunk then
    error("toolbox.load_object: failed to load “" .. object .. ".lua” from " .. path)
  end
  local ok, mod = pcall(chunk)
  if not ok or type(mod) ~= "table" then
    error("toolbox.load_object: chunk for “" .. object .. ".lua” did not return a table")
  end
  return mod
end

-----------------------------------------------------------------------------
-- 2) Caches for compiled chunks & base module‐tables
--    We compile each <object>.lua exactly once, store that function in
--      baseCompiledCache[ script ] = <function> 
--    We run it once to get a “baseMod” (table), store in
--      baseModuleCache[ script ] = <table>
--    Every time a new widget instance chooses that script, we shallow‐copy the
--    base module‐table (so instance state doesn’t collide) and run init().
-----------------------------------------------------------------------------
local baseCompiledCache = {}   -- script‐filename → compiled chunk (function)
local baseModuleCache   = {}   -- script‐filename → “base” module table

-- Helper to do a shallow copy of any table
local function shallowCopy(tbl)
  local copy = {}
  for k, v in pairs(tbl) do
    copy[k] = v
  end
  return copy
end

-- Build a { {displayName, index}, … } list for the configure form
local function generateWidgetList(tbl)
  local widgets = {}
  for i, tool in ipairs(tbl) do
    table.insert(widgets, { tool.name, i })
  end
  return widgets
end

-----------------------------------------------------------------------------
-- 3) create(): called once per widget instance. We attach per-instance state.
--    - state.setup:           whether we’ve already loaded a sub-widget
--    - loadedWidget:          the shallow‐copied module‐table
--    - wakeupSchedulerUI:     timestamp if you still want to throttle (not used here)
-----------------------------------------------------------------------------
function toolbox.create()
  return {
    value             = 0,
    state             = { setup = false },
    loadedWidget      = nil,
    wakeupSchedulerUI = 0,
  }
end

-----------------------------------------------------------------------------
-- 4) tryLoadSubWidget(): if widget.object is set but not yet loaded, do:
--      (A) compile once via loadfile → store chunk in baseCompiledCache
--      (B) run chunk() once → store “base” module in baseModuleCache
--      (C) shallow‐copy baseModuleCache[script] → widget.loadedWidget
--      (D) run loadedWidget.init(widget), set state.setup=true, lcd.invalidate()
-----------------------------------------------------------------------------
local function tryLoadSubWidget(widget)
  if widget.loadedWidget or not widget.object then
    return
  end

  local entry = toolBoxList[ widget.object ]
  if not entry or not entry.script then
    return
  end

  -- Path to sub‐widget’s file in SCRIPTS:/…/widgets/toolbox/objects/
  local widgetPath = "SCRIPTS:/" .. rfsuite.config.baseDir
                   .. "/widgets/toolbox/objects/" .. entry.script

  -- (A) Compile (once) if needed
  local chunk = baseCompiledCache[ entry.script ]
  if not chunk then
    local okChunk, fnOrErr = pcall(function()
      return rfsuite.compiler.loadfile(widgetPath)
    end)
    if not okChunk or type(fnOrErr) ~= "function" then
      print("Error compiling “" .. entry.script .. "” from path:", widgetPath)
      return
    end
    baseCompiledCache[ entry.script ] = fnOrErr
    chunk = fnOrErr
  end

  -- (B) Run chunk() once to get the “base” module table if needed
  local baseMod = baseModuleCache[ entry.script ]
  if not baseMod then
    local okModule, modTbl = pcall(chunk)
    if not okModule or type(modTbl) ~= "table" then
      print("Error loading module “" .. entry.script .. "”: chunk did not return a table")
      return
    end
    baseModuleCache[ entry.script ] = modTbl
    baseMod = modTbl
  end

  -- (C) Shallow‐copy that base table for *this* instance
  local instanceMod = shallowCopy(baseMod)
  widget.loadedWidget = instanceMod

  -- (D) Call init() if provided, mark setup=true, and request repaint
  if type(instanceMod.init) == "function" then
    instanceMod.init(widget)
  end
  widget.state.setup = true
  lcd.invalidate()
end

-----------------------------------------------------------------------------
-- 5) paint(widget): 
--    - If not set up, do one last tryLoadSubWidget
--    - If loadedWidget.paint exists, call it
--    - Otherwise draw “NOT CONFIGURED”
-----------------------------------------------------------------------------
function toolbox.paint(widget)
  -- Cache window size once
  if not LCD_W or not LCD_H then
    LCD_W, LCD_H = lcd.getWindowSize()
  end

  -- If the user has selected an object but we haven’t loaded it yet:
  if not widget.state.setup then
    tryLoadSubWidget(widget)
  end

  if widget.state.setup 
     and widget.loadedWidget 
     and type(widget.loadedWidget.paint) == "function" then

    widget.loadedWidget.paint(widget)
  else
    -- Draw “NOT CONFIGURED” centered
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

-----------------------------------------------------------------------------
-- 6) wakeup(widget):
--    - If widget.object is set but we haven’t loaded it, do so
--    - If loadedWidget.wakeup exists, call it unconditionally
--    - Then lcd.invalidate() so it repaints (both instances will repaint)
-----------------------------------------------------------------------------
function toolbox.wakeup(widget)
  -- (1) If the user chose an index but we haven’t loaded it, do so now
  if widget.object and not widget.state.setup then
    tryLoadSubWidget(widget)
  end

  -- (2) If sub-widget has wakeup(), run it on a throttled interval
  if widget.state.setup 
     and widget.loadedWidget 
     and type(widget.loadedWidget.wakeup) == "function" then

    -- Run at 0.5 s intervals when visible, or 5 s when hidden
    local interval = lcd.isVisible() and 0.5 or 5
    local now = os.clock()
    if (now - (widget.wakeupSchedulerUI or 0)) >= interval then
      widget.wakeupSchedulerUI = now
      widget.loadedWidget.wakeup(widget)
      lcd.invalidate()
    end

  else
    -- If no wakeup() to run, still redraw so the UI stays up-to-date
    lcd.invalidate()
  end
end

function toolbox.menu(widget)
  if widget.state.setup 
     and widget.loadedWidget 
     and type(widget.loadedWidget.menu) == "function" then
    return widget.loadedWidget.menu(widget)
  end
  return {}
end       

function toolbox.i18n(widget)
  if widget.state.setup 
     and widget.loadedWidget 
     and type(widget.loadedWidget.i18n) == "function" then
    return widget.loadedWidget.i18n(widget)
  end
  return {}
end  

-----------------------------------------------------------------------------
-- 7) configure(widget):
--    Build a single “ChoiceField” so the user picks which sub‐widget to load.
--    If they pick a different one, we clear loadedWidget (so init() runs fresh)
--    but leave the baseCompiledCache/baseModuleCache intact (no recompile).
-----------------------------------------------------------------------------
function toolbox.configure(widget)
  local formLines  = {}
  local formFields = {}
  local formLineCnt   = 0
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
      if widget.object and widget.object ~= newValue then
        widget.state.setup       = false
        widget.loadedWidget      = nil
        widget.wakeupSchedulerUI = 0
      end
      widget.object = newValue
    end
  )
end

-----------------------------------------------------------------------------
-- 8) read/write for persistence
-----------------------------------------------------------------------------
function toolbox.read(widget)
  widget.title = (function(ok, result) return ok and result end)(pcall(storage.read, "title"))
  widget.object = (function(ok, result) return ok and result end)(pcall(storage.read, "object"))
end

function toolbox.write(widget)
  storage.write("title", widget.object)
  storage.write("object", widget.object)
end

-- We don’t use titles in this wrapper
toolbox.title = false

return toolbox
