local toolbox = {}

local LCD_W, LCD_H

-- Base path for loading “objects” (each object is a widget under widgets/dashboard/objects/)
local objectsBasePath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/objects/"

-- ------------------------------------------------------------------------------
--  List of available objects for the Configure form (label, index)
-- ------------------------------------------------------------------------------
local objectList = {
  { "TELEMETRY BOX",  1 },
  { "GAUGE",           2 },
  { "ARCGAUGE",        3 },
  { "ARCMAXGAUGE",     4 },
}

-- Map object index → Lua filename
local objectFiles = {
  [1] = objectsBasePath .. "telemetry.lua",
  [2] = objectsBasePath .. "gauge.lua",
  [3] = objectsBasePath .. "arcgauge.lua",
  [4] = objectsBasePath .. "arcmaxgauge.lua",
}

-- ------------------------------------------------------------------------------
--  Sensor‐list: each entry is { "Label shown in form", <numeric ID> }
--  When the user picks a numeric ID, we later look up the string name here:
--  sensorMap[<numeric ID>] = "<string sensor name>"
-- ------------------------------------------------------------------------------
local sensorList = {
  { "Voltage (ID 0)",     0 },
  { "Current (ID 1)",     1 },
  { "RPM (ID 2)",         2 },
  { "Speed (ID 3)",       3 },
  { "Temperature (ID 4)", 4 },
  -- Add/remove entries to match your actual telemetry channels...
}

-- Map numeric ID → string key (for box.source).  Adjust names as your objects expect.
local sensorMap = {
  [0] = "voltage",
  [1] = "current",
  [2] = "rpm",
  [3] = "speed",
  [4] = "temperature",
  -- etc...
}

--------------------------------------------------------------------------------
-- create( widget )
--   *** Keep this exactly as you originally wrote it ***
--------------------------------------------------------------------------------
function toolbox.create()
  return { value = 0 }
end

--------------------------------------------------------------------------------
-- read( config )
--   Restore both .object (integer index) and .sensor (integer ID).
--------------------------------------------------------------------------------
function toolbox.read(config)
  -- Restore config.object; if storage.read fails, leave config.object = nil
  local okObj, storedObj = pcall(storage.read, "object")
  config.object = okObj and storedObj or nil

  -- Restore config.sensor; if storage.read fails, leave config.sensor = nil
  local okSen, storedSen = pcall(storage.read, "sensor")
  config.sensor = okSen and storedSen or nil
end

--------------------------------------------------------------------------------
-- write( config )
--   Persist both .object and .sensor exactly as you had:
--------------------------------------------------------------------------------
function toolbox.write(config)
  storage.write("object", config.object)
  storage.write("sensor", config.sensor)
end

--------------------------------------------------------------------------------
-- configure( config )
--   Let user pick “object” (choice field) and “sensor” (numeric choice field).
--------------------------------------------------------------------------------
function toolbox.configure(config)
  -- ────────────────────────────────────────────────────────────────────────────
  -- 1) Object‐type picker (config.object = 1..4)
  -- ────────────────────────────────────────────────────────────────────────────
  local line1 = form.addLine("Choose object to display")
  form.addChoiceField(
    line1,
    nil,
    objectList,
    function()
      -- If not yet chosen, default to 1
      if not config.object or config.object == 0 then
        config.object = 1
      end
      return config.object
    end,
    function(newVal)
      config.object = newVal
    end
  )

  -- ────────────────────────────────────────────────────────────────────────────
  -- 2) Sensor‐picker (config.sensor = numeric ID, e.g. 0,1,2…)
  -- ────────────────────────────────────────────────────────────────────────────
  local line2 = form.addLine("Choose sensor channel")
  form.addChoiceField(
    line2,
    nil,
    sensorList,
    function()
      -- If not yet chosen, default to first entry’s ID
      if not config.sensor then
        config.sensor = sensorList[1][2]
      end
      return config.sensor
    end,
    function(newVal)
      config.sensor = newVal
    end
  )
end

--------------------------------------------------------------------------------
-- wakeup( widget )
--   Each instance has its own .currentObject, .loadedObject, .box, .setup, .lastCall.
--------------------------------------------------------------------------------
function toolbox.wakeup(widget)
  ----------------------------------------------------------------------
  -- 1) Throttle: 0.5 s if visible, 5 s if in background
  ----------------------------------------------------------------------
  widget.lastCall = widget.lastCall or 0
  local interval = lcd.isVisible() and 0.5 or 5
  local now = os.clock()
  if (now - widget.lastCall) < interval then
    return
  end
  widget.lastCall = now

  ----------------------------------------------------------------------
  -- 2) If user never picked an object (config.object is nil/0), do nothing
  ----------------------------------------------------------------------
  if not widget.object or widget.object == 0 then
    return
  end

  ----------------------------------------------------------------------
  -- 3) Mark that we have at least one valid selection → widget.setup = true
  ----------------------------------------------------------------------
  widget.setup = true

  ----------------------------------------------------------------------
  -- 4) If first load, or user changed widget.object, reload the module
  ----------------------------------------------------------------------
  if (not widget.loadedObject) or (widget.currentObject ~= widget.object) then
    widget.currentObject = widget.object
    widget.loadedObject = nil
    widget.box = nil

    local filename = objectFiles[widget.object]
    if filename then
      local chunk = rfsuite.compiler.loadfile(filename)
      if chunk then
        widget.loadedObject = chunk()
      end
    end
  end

  ----------------------------------------------------------------------
  -- 5) If module loaded and has wakeup(), ensure widget.box exists
  --    (with correct string source) and call module.wakeup(box, telemetryAPI)
  ----------------------------------------------------------------------
  if widget.loadedObject and widget.loadedObject.wakeup then
    -- Create widget.box once (full‐screen). If it already exists, we only update source.
    if not widget.box then
      if not LCD_W or not LCD_H then
        LCD_W, LCD_H = lcd.getWindowSize()
      end

      -- Look up the string name for the chosen numeric sensor ID:
      local srcID = widget.sensor or sensorList[1][2]
      local srcName = sensorMap[srcID] or sensorMap[sensorList[1][2]]

      widget.box = {
        x = 0,
        y = 0,
        w = LCD_W,
        h = LCD_H,    -- lowercase `h` is required by paint()
        source     = srcName,      -- string sensor key, e.g. "voltage"
        title      = "Telemetry Box",
        unit       = "m/s",
        transform  = "abs",
        thresholds = {
          { value = 10, textcolor = COLOR_RED },
          { value =  5, textcolor = COLOR_ORANGE },
        },
      }
    else
      -- If user changed sensor after box already exists, update the string:
      local srcID = widget.sensor or sensorList[1][2]
      widget.box.source = sensorMap[srcID] or sensorMap[sensorList[1][2]]
    end

    -- Finally, invoke the module’s wakeup()
    widget.loadedObject.wakeup(widget.box, rfsuite.tasks.telemetry)
  end

  ----------------------------------------------------------------------
  -- 6) Force this widget to redraw
  ----------------------------------------------------------------------
  lcd.invalidate()
end

--------------------------------------------------------------------------------
-- paint( widget )
--   If not configured → “NOT CONFIGURED”. Otherwise, forward to module.paint().
--------------------------------------------------------------------------------
function toolbox.paint(widget)
  if not LCD_W or not LCD_H then
    LCD_W, LCD_H = lcd.getWindowSize()
  end

  -- 1) If user never picked an object, show centered “NOT CONFIGURED”
  if not widget.setup then
    if lcd.darkMode() then
      lcd.color(COLOR_WHITE)
    else
      lcd.color(COLOR_BLACK)
    end
    local msg = "NOT CONFIGURED"
    local mw, mh = lcd.getTextSize(msg)
    lcd.drawText((LCD_W - mw) / 2, (LCD_H - mh) / 2, msg)
    return
  end

  -- 2) If module has paint() and we have a valid box, delegate to it
  if widget.loadedObject and widget.loadedObject.paint and widget.box then
    widget.loadedObject.paint(
      0,           -- x
      0,           -- y
      LCD_W,       -- w
      LCD_H,       -- h
      widget.box   -- box
    )
    return
  end

  -- 3) Fallback: clear if something is missing
  lcd.invalidate()
end

--------------------------------------------------------------------------------
-- No title line in the widget bar
--------------------------------------------------------------------------------
toolbox.title = false

return toolbox
