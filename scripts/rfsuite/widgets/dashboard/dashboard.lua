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
local dashboard = {}  -- main namespace for all dashboard functionality

-- cache some functions and variables for performance
local compile = rfsuite.compiler.loadfile
local i18n = rfsuite.i18n.get
local baseDir = rfsuite.config.baseDir
local preferences = rfsuite.config.preferences
local utils = rfsuite.utils
local log = utils.log
local tasks = rfsuite.tasks


-- Supported resolutions
local supportedResolutions = {
    { 784, 294 },   -- X20, X20RS etc
    { 784, 316 },   -- X20, X20RS etc (no title)
    { 800, 458 },   -- X20, X20RS etc (full screen)
    { 800, 480 },   -- X20, X20RS etc (full screen / no title)
    { 472, 191 },   -- TWXLITE, X18, X18S
    { 472, 210 },   -- TWXLITE, X18, X18S (no title)
    { 480, 301 },   -- TWXLITE, X18, X18S (full screen)
    { 480, 320 },   -- TWXLITE, X18, X18S (full screen / no title)
    { 630, 236 },   -- X14
    { 630, 258 },   -- X14 (no title)
    { 640, 338 },   -- X14 (full screen)
    { 640, 360 },   -- X14 (full screen / no title)
}


-- Track the previous flight mode so we can detect changes on wakeup
local lastFlightMode = nil

-- Capture the script start time for uptime or performance measurements
local initTime = os.clock()

local lastWakeup = os.clock()

-- Default theme to fall back on if user or system theme fails to load
dashboard.DEFAULT_THEME = "system/default"

-- Base paths for loading themes:
--   themesBasePath: where system themes are stored
--   themesUserPath: where user-defined themes are stored (preferences)
local themesBasePath = "SCRIPTS:/" .. baseDir .. "/widgets/dashboard/themes/"
local themesUserPath = "SCRIPTS:/" .. preferences .. "/dashboard/"

-- Create the user theme directory if it doesn't exist
os.mkdir(themesUserPath)

-- Cache for loaded state modules (preflight, inflight, postflight)
local loadedStateModules = {}

-- Counter used by wakeup to cycle through tasks
local wakeupScheduler = 0

-- Spread scheduling of object wakeups to avoid doing them all at once:
local objectWakeupIndex = 1             -- current object index for wakeup
local objectWakeupsPerCycle = nil       -- number of objects to wake per cycle (calculated later)
local objectsThreadedWakeupCount = 0
local lastLoadedBoxCount = 0
local lastBoxRectsCount = 0

-- Some placeholders used by dashboard loader
local moduleState

-- Track background loading of remaining flight mode modules
local statePreloadQueue = {"inflight", "postflight"}
local statePreloadIndex = 1

local unsupportedResolution = false  -- flag to track unsupported resolutions

-- Track last known telemetry values for targeted invalidation
dashboard._objectDirty = {}

-- precompute indices of boxes whose object has its own `scheduler` field,
-- so we can wake them every cycle without scanning all `boxRects`.
local scheduledBoxIndices = {}

-- Flag to perform initialization logic only once on first wakeup
local firstWakeup = true
local firstWakeupCustomTheme = true
lcd.invalidate() -- force an initial redraw to show the hourglass

-- Layout state for boxes (UI elements):
dashboard.boxRects = {}              -- will hold {x, y, w, h, box} for each box
dashboard.selectedBoxIndex = 1       -- tracks which box is currently selected (for input)

-- Track whether a fallback theme was used, and when, per state:
dashboard.themeFallbackUsed = { preflight = false, inflight = false, postflight = false }
dashboard.themeFallbackTime = { preflight = 0,     inflight = 0,        postflight = 0 }

-- Current flightmode driving which state module to use (preflight/inflight/postflight)
dashboard.flightmode = rfsuite.flightmode.current or "preflight"

-- Path to the current widget/theme in use (set during theme loading)
dashboard.currentWidgetPath = nil

-- Any overlay message to display on screen (e.g., error or status)
dashboard.overlayMessage = nil

-- Loaded dashboard objects organized by their "type" field
dashboard.objectsByType = {}

-- * CONFIGURABLE SIZES *
-- Fraction of min(width, height) to use for the spinner/overlay radius.
-- Increase to ~0.36 for a 20% larger spinner (0.3 * 1.2)
dashboard.loaderScale    = 0.38
dashboard.overlayScale      = 0.38

-- dark mode state
local darkModeState = lcd.darkMode()

-- initialize cache once
dashboard._moduleCache = dashboard._moduleCache or {}

-- how many paint‐cycles to keep showing the spinner 
dashboard._hg_cycles_required = 2
dashboard._hg_cycles = 0

-- how long the loader must stay visible (in seconds)
dashboard._loader_min_duration = 1.5
dashboard._loader_start_time = nil

-- Utility methods loaded from external utils.lua (drawing, color helpers, etc.)
dashboard.utils = assert(
    compile("SCRIPTS:/" .. baseDir .. "/widgets/dashboard/lib/utils.lua")
)()

dashboard.loaders = assert(
    compile("SCRIPTS:/" .. baseDir .. "/widgets/dashboard/lib/loaders.lua")
)()

function dashboard.loader(x, y, w, h)
        dashboard.loaders.staticLoader(dashboard, x, y, w, h)
        lcd.invalidate()
end

local function forceInvalidateAllObjects()
    for i, rect in ipairs(dashboard.boxRects) do
        local obj = dashboard.objectsByType[rect.box.type]
        if obj and obj.dirty and obj.dirty(rect.box) then
            lcd.invalidate(rect.x, rect.y, rect.w, rect.h)
        end
    end
end

function dashboard.overlaymessage(x, y, w, h, txt)
    dashboard.loaders.staticOverlayMessage(dashboard, x, y, w, h, txt)
end

--- Calculates the scheduler percentage based on the number of objects.
-- This function determines what fraction of objects should be processed per cycle,
-- depending on the total count. Fewer objects result in a higher percentage processed
-- per cycle, while more objects reduce the percentage to avoid overloading.
-- @param count number The total number of objects to schedule.
-- @return number The percentage (as a decimal) of objects to process per cycle.
local function computeObjectSchedulerPercentage(count)
    if count <= 10 then return 0.8      -- fewer objects → more per cycle
    elseif count <= 15 then return 0.7
    elseif count <= 25 then return 0.6
    elseif count <= 40 then return 0.5
    else return 0.4 end                -- many objects → fewer per cycle
end

--- Loads a single dashboard object type (box) if not already loaded.
-- Used during wakeup preload to load one box at a time.
-- @param box A box configuration table with a `type` field.
function dashboard.loadObjectType(box)
    local typ = box and box.type
    if not typ then return end

    if not dashboard._moduleCache[typ] then
        local baseDir = baseDir or "default"
        local objPath = "SCRIPTS:/" .. baseDir .. "/widgets/dashboard/objects/" .. typ .. ".lua"
        local ok, obj = pcall(function()
            return assert(compile(objPath))()
        end)
        if ok and type(obj) == "table" then
            dashboard._moduleCache[typ] = obj
        else
            log("Failed to load object: " .. tostring(typ), "info")
            dashboard._moduleCache[typ] = false
        end
    end

    if dashboard._moduleCache[typ] then
        dashboard.objectsByType[typ] = dashboard._moduleCache[typ]
    end
end

--- Loads and caches dashboard object modules based on the provided box configurations.
-- Iterates through each box config, loading the corresponding object Lua file only once per type.
-- Loaded objects are stored in `dashboard.objectsByType` for later use.
-- Logs a message if an object fails to load.
-- @param boxConfigs Table of box configuration tables, each containing a `type` field.
function dashboard.loadAllObjects(boxConfigs)
    dashboard.objectsByType = {}  -- clear old cache of active objects
    for _, box in ipairs(boxConfigs or {}) do
        local typ = box.type
        if typ then
            -- only load from disk the first time we see this type
            if not dashboard._moduleCache[typ] then
                local baseDir = baseDir or "default"
                local objPath = "SCRIPTS:/" .. baseDir .. "/widgets/dashboard/objects/" .. typ .. ".lua"
                local ok, obj = pcall(function()
                    return assert(compile(objPath))()
                end)
                if ok and type(obj) == "table" then
                    dashboard._moduleCache[typ] = obj
                else
                    log("Failed to load object: " .. tostring(typ), "info")
                    -- ensure we don’t retry a broken type endlessly
                    dashboard._moduleCache[typ] = false
                end
            end

            -- if we have a valid cached module, assign it
            if dashboard._moduleCache[typ] then
                dashboard.objectsByType[typ] = dashboard._moduleCache[typ]
            end
        end
    end
end

--- Returns a table of indices for boxes in `dashboard.boxRects` that have an `onpress` handler.
-- @return table Indices of boxes with an `onpress` function.
local function getOnpressBoxIndices()
    local indices = {}
    for i, rect in ipairs(dashboard.boxRects) do
        if rect.box.onpress then
            indices[#indices + 1] = i
        end
    end
    return indices
end

--- Computes and returns an overlay message for the dashboard widget based on the current system state.
-- The message indicates issues such as theme load errors, incompatible Ethos version, inactive background tasks,
-- disabled RF modules, missing sensors, or invalid telemetry sensors. Returns `nil` if no issues are detected.
-- @return string|nil Overlay message if an issue is detected, otherwise `nil`.
function dashboard.computeOverlayMessage()

    local state = dashboard.flightmode or "preflight"
    local telemetry = tasks.telemetry
    local pad = "      " -- for RF version banner

    -- 1) Theme load error (recent only)
    if dashboard.themeFallbackUsed and dashboard.themeFallbackUsed[state] and
       (os.clock() - (dashboard.themeFallbackTime and dashboard.themeFallbackTime[state] or 0)) < 10 then
        return i18n("widgets.dashboard.theme_load_error")
    end

    -- 2) Background task
    if not tasks.active() then
        return i18n("widgets.dashboard.check_bg_task")
    end    
  
    -- 3) As soon as we know RF version, show it with precedence
    if rfsuite.session.apiVersion and rfsuite.session.rfVersion and not rfsuite.session.isConnectedLow and state ~= "postflight" then
        if system.getVersion().simulation == true then
            return pad .. "SIM " .. rfsuite.session.apiVersion .. pad
        else
            return pad .. "RF" .. rfsuite.session.rfVersion .. pad
        end
    end

    -- 4) LAST: generic waiting message (don’t let it mask actionable errors)
    if not rfsuite.session.isConnectedHigh and state ~= "postflight" then
        return i18n("widgets.dashboard.waiting_for_connection")
    end

    return nil
end


--- Calculates the width and height of a box based on its properties.
-- Supports percentage-based, fixed, and grid-span sizing.
-- @param box Table containing box properties (w_pct, h_pct, w, h, colspan, rowspan)
-- @param boxWidth Default width for a single box/grid cell
-- @param boxHeight Default height for a single box/grid cell
-- @param PADDING Padding between boxes/cells
-- @param WIDGET_W Total widget width (for percentage calculations)
-- @param WIDGET_H Total widget height (for percentage calculations)
-- @return w, h Calculated width and height of the box
local function getBoxSize(box,boxWidth, boxHeight, PADDING, WIDGET_W, WIDGET_H)
    if box.w_pct and box.h_pct then
        local wp = box.w_pct
        local hp = box.h_pct
        if wp > 1 then wp = wp / 100 end
        if hp > 1 then hp = hp / 100 end
        local w = math.floor(wp * WIDGET_W)
        local h = math.floor(hp * WIDGET_H)
        return w, h
    elseif box.w and box.h then
        return tonumber(box.w) or boxWidth, tonumber(box.h) or boxHeight
    elseif box.colspan or box.rowspan then
        local w = math.floor((box.colspan or 1) * boxWidth + ((box.colspan or 1) - 1) * PADDING)
        local h = math.floor((box.rowspan or 1) * boxHeight + ((box.rowspan or 1) - 1) * PADDING)
        return w, h
    else
        return boxWidth, boxHeight
    end
end

--- Calculates the (x, y) position for a UI box based on its configuration.
-- Priority for position: percentage (x_pct/y_pct) > absolute (x/y) > grid (col/row).
-- @param box Table containing box position properties.
-- @param w Optional width override for the box.
-- @param h Optional height override for the box.
-- @param boxWidth Default width of the box.
-- @param boxHeight Default height of the box.
-- @param PADDING Padding between boxes.
-- @param WIDGET_W Total widget width.
-- @param WIDGET_H Total widget height.
-- @return x, y Calculated top-left position of the box.
local function getBoxPosition(box, w, h, boxWidth, boxHeight, PADDING, WIDGET_W, WIDGET_H)
    -- Priority: x_pct/y_pct > x/y > col/row
    if box.x_pct and box.y_pct then
        local xp = box.x_pct
        local yp = box.y_pct
        if xp > 1 then xp = xp / 100 end
        if yp > 1 then yp = yp / 100 end
        -- x/y is top-left corner; w/h is known
        local x = math.floor(xp * (WIDGET_W - (w or boxWidth)))
        local y = math.floor(yp * (WIDGET_H - (h or boxHeight)))
        return x, y
    elseif box.x and box.y then
        local x = tonumber(box.x) or 0
        local y = tonumber(box.y) or 0
        return x, y
    elseif box.col and box.row then
        local col = box.col or 1
        local row = box.row or 1
        local x = math.floor((col - 1) * (boxWidth + PADDING)) + (box.xOffset or 0)
        local y = math.floor(PADDING + (row - 1) * (boxHeight + PADDING))
        return x, y
    else
        return 0, 0
    end
end

function dashboard.renderLayout(widget, config)
    local utils     = dashboard.utils
    local telemetry = tasks.telemetry

    -- create once    
    dashboard.boxRects = dashboard.boxRects or {}
    scheduledBoxIndices = scheduledBoxIndices or {}
    dashboard._objectDirty = dashboard._objectDirty or {} 

    local function resolve(val, ...) return type(val) == "function" and val(...) or val end

    -- Load layout and box definitions
    local layout    = resolve(config.layout) or {}
    local headerLayout = resolve(config.header_layout) or {}
    local boxes     = resolve(config.boxes or layout.boxes or {})
    local headerBoxes = resolve(config.header_boxes or {})

    -- Reload widgets if layout changed
    if (#boxes + #headerBoxes) ~= lastLoadedBoxCount then
        local allBoxes = {}
        for _, b in ipairs(boxes) do table.insert(allBoxes, b) end
        for _, b in ipairs(headerBoxes) do table.insert(allBoxes, b) end
        dashboard.loadAllObjects(allBoxes)
        lastLoadedBoxCount = #boxes + #headerBoxes
    end


    for k in pairs(dashboard._objectDirty) do dashboard._objectDirty[k] = nil end   

    -- Grid and screen setup
    local W_raw, H_raw = lcd.getWindowSize()
    local isFullScreen = utils.isFullScreen(W_raw, H_raw)
    local cols         = layout.cols or 1
    local rows         = layout.rows or 1
    local pad          = layout.padding or 0

    local function adjustDimension(dim, cells, padCount)
    return dim - ((dim - padCount*pad) % cells)
    end

    -- Adjust height for header if specified
    if isFullScreen and headerLayout and headerLayout.height and type(headerLayout.height) == "number" then
        H_raw = H_raw - headerLayout.height
    end

    local W = adjustDimension(W_raw, cols, cols - 1)
    local H = adjustDimension(H_raw, rows, rows + 1) -- +1 for vertical pad
    local xOffset = math.floor((W_raw - W) / 2)

    local contentW = W - ((cols - 1) * pad)
    local contentH = H - ((rows + 1) * pad)
    local boxW     = contentW / cols
    local boxH     = contentH / rows

    ----------------------------------------------------------------
    -- PHASE 1: Build Box Rects and Collect Scheduled Indices
    ----------------------------------------------------------------
    utils.setBackgroundColourBasedOnTheme()

    for i=#dashboard.boxRects,1,-1 do dashboard.boxRects[i] = nil end
    for i=#scheduledBoxIndices,1,-1 do scheduledBoxIndices[i] = nil end

    for _, box in ipairs(boxes) do
        local w, h = getBoxSize(box, boxW, boxH, pad, W, H)
        box.xOffset = xOffset
        local x, y = getBoxPosition(box, w, h, boxW, boxH, pad, W, H)
        if isFullScreen and headerLayout and headerLayout.height and type(headerLayout.height) == "number"  then
            y = y + headerLayout.height  -- Adjust y position for header
        end

        local rect = { x = x, y = y, w = w, h = h, box = box, isHeader = false }
        table.insert(dashboard.boxRects, rect)

        local rectIndex = #dashboard.boxRects
        dashboard._objectDirty[rectIndex] = nil

        local obj = dashboard.objectsByType[box.type]
        if obj and obj.scheduler and obj.wakeup then
            table.insert(scheduledBoxIndices, rectIndex)
        end
    end

    -- now do the same for headerBoxes so they get scheduled and invalidated just like normal boxes
    if isFullScreen then
        local headerGeoms = {}
        local rightmost_idx, rightmost_x = 1, 0
        for idx, box in ipairs(headerBoxes) do
            local w, h = getBoxSize(box, boxW, boxH, pad, W_raw, headerLayout.height)
            local x, y = getBoxPosition(box, w, h, boxW, boxH, pad, W_raw, headerLayout.height)
            headerGeoms[idx] = {x = x, y = y, w = w, h = h, box = box}
            if x > rightmost_x then
                rightmost_idx = idx
                rightmost_x = x
            end
        end

        -- Now insert header rects, stretching the rightmost box
        for idx, geom in ipairs(headerGeoms) do
            local w = geom.w
            if idx == rightmost_idx then
                w = W_raw - geom.x
            end

            local rect = { x = geom.x, y = geom.y, w = w, h = geom.h, box = geom.box, isHeader = true }
            table.insert(dashboard.boxRects, rect)
            local idx_rect = #dashboard.boxRects
            dashboard._objectDirty[idx_rect] = nil

            local obj = dashboard.objectsByType[geom.box.type]
            if obj and obj.scheduler and obj.wakeup then
                table.insert(scheduledBoxIndices, idx_rect)
            end
        end
    end

    -- Scheduler setup
    if not objectWakeupsPerCycle or #dashboard.boxRects ~= lastBoxRectsCount then
        local count = #dashboard.boxRects
        local percentage = dashboard._spreadRatioOverride or computeObjectSchedulerPercentage(count)

        if objectsThreadedWakeupCount < 1 then
            percentage = 1.0
            log("Accelerating first wakeup pass with 100% objects per cycle", "info")
        end

        objectWakeupsPerCycle = math.max(1, math.ceil(count * percentage))
        lastBoxRectsCount     = count

        log("Object scheduler set to " .. objectWakeupsPerCycle ..
                          " out of " .. count .. " boxes", "info")
    end

    ----------------------------------------------------------------
    -- PHASE 2: Spinner Until First Wakeup Pass Completes
    ----------------------------------------------------------------
    dashboard._loader_start_time = dashboard._loader_start_time or os.clock()
    local loaderElapsed = os.clock() - dashboard._loader_start_time
    if objectsThreadedWakeupCount < 1 or loaderElapsed < dashboard._loader_min_duration then
        local loaderY = (isFullScreen and headerLayout.height) or 0
        dashboard.loader(0, loaderY, W, H - loaderY)
        lcd.invalidate()
        return
    end

    ----------------------------------------------------------------
    -- PHASE 3: Paint Actual Widgets
    ----------------------------------------------------------------
    local selColor  = layout.selectcolor  or utils.resolveColor("yellow") or lcd.RGB(255,255,0)
    local selBorder = layout.selectborder or 2

    for i, rect in ipairs(dashboard.boxRects) do
        if not rect.isHeader then
            local box = rect.box
            local obj = dashboard.objectsByType[box.type]
            if obj and obj.paint then
                obj.paint(rect.x, rect.y, rect.w, rect.h, box)
            end

            if dashboard.selectedBoxIndex == i and box.onpress then
                lcd.color(selColor)
                lcd.drawRectangle(rect.x, rect.y, rect.w, rect.h, selBorder)
            end
        end
    end



    ------------------------------------------------------------------------
    -- PHASE 4: Draw Header - if applicable
    ------------------------------------------------------------------------
    if isFullScreen and config.header_layout and #headerBoxes > 0 then
        local header = config.header_layout
        local h_cols = header.cols or 1
        local h_rows = header.rows or 1
        local h_pad  = header.padding or 0

        local headerW = W_raw
        local headerH = header.height or 0

        local function adjustHeaderDimension(dim, cells, padCount)
            return dim - ((dim - padCount * h_pad) % cells)
        end

        local adjustedW = adjustHeaderDimension(headerW, h_cols, h_cols - 1)
        local adjustedH = adjustHeaderDimension(headerH, h_rows, h_rows - 1)

        local contentW = adjustedW - ((h_cols - 1) * h_pad)
        local contentH = adjustedH - ((h_rows - 1) * h_pad)
        local h_boxW   = contentW / h_cols
        local h_boxH   = contentH / h_rows

        -- Build box geoms and find rightmost
        local rightmost_idx, rightmost_x = 1, 0
        local headerGeoms = {}
        for idx, box in ipairs(headerBoxes) do
            local w, h = getBoxSize(box, h_boxW, h_boxH, h_pad, adjustedW, adjustedH)
            local x, y = getBoxPosition(box, w, h, h_boxW, h_boxH, h_pad, adjustedW, adjustedH)
            headerGeoms[idx] = {x = x, y = y, w = w, h = h, box = box}
            if x > rightmost_x then
                rightmost_idx = idx
                rightmost_x = x
            end
        end

        -- Paint all boxes, stretch rightmost to edge
        for idx, geom in ipairs(headerGeoms) do
            local w = geom.w
            if idx == rightmost_idx then
                w = W_raw - geom.x
            end
            local obj = dashboard.objectsByType[geom.box.type]
            if obj and obj.paint then
                obj.paint(geom.x, geom.y, w, geom.h, geom.box)
            end
        end


        -- Optional: Draw header grid if header_layout.showgrid is set
        if isFullScreen and headerLayout and headerLayout.showgrid then
            lcd.color(headerLayout.showgrid)
            lcd.pen(1)

            for i = 1, h_cols - 1 do
                local x = math.floor(i * (h_boxW + h_pad)) - math.floor(h_pad / 2)
                lcd.drawLine(x, 0, x, headerLayout.height)
            end

            for i = 1, h_rows - 1 do
                local y = math.floor(i * (h_boxH + h_pad)) - math.floor(h_pad / 2)
                lcd.drawLine(0, y, W_raw, y)
            end

            lcd.pen(SOLID)
        end


    end


    -- Draw optional grid overlay
    if layout.showgrid then
        lcd.color(layout.showgrid)
        lcd.pen(1)

        local headerOffset = (isFullScreen and headerLayout and headerLayout.height) or 0

        -- Vertical lines
        for i = 1, cols - 1 do
            local x = math.floor(i * (boxW + pad)) + xOffset - math.floor(pad / 2)
            lcd.drawLine(x, headerOffset, x, H_raw + headerOffset)
        end

        -- Horizontal lines
        for i = 1, rows - 1 do
            local y = math.floor(i * (boxH + pad)) + pad + headerOffset
            lcd.drawLine(0, y, W_raw, y)
        end

        lcd.pen(SOLID)
    end




    -- Handle overlay messages
    if dashboard.overlayMessage then
        dashboard._hg_cycles = dashboard._hg_cycles_required
    end
    if dashboard._hg_cycles > 0 then
        local loaderY = (isFullScreen and headerLayout.height) or 0
        dashboard.overlaymessage(0, loaderY, W, H - loaderY, dashboard.overlayMessage)
        dashboard._hg_cycles = dashboard._hg_cycles - 1
        lcd.invalidate()
        return
    end

    dashboard._forceFullRepaint = true
end


-- Utility to resolve a theme for a given flight mode
local function getThemeForState(state)
    local prefs = rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.dashboard
    local fallback = rfsuite.preferences.dashboard
    local val = prefs and prefs["theme_" .. state]
    return (val and val ~= "nil" and val) or fallback["theme_" .. state] or dashboard.DEFAULT_THEME
end


--- Loads a state-specific script for the dashboard widget, handling theme selection and fallbacks.
-- 
-- This function attempts to load the `init.lua` file from the specified `theme_folder` to determine
-- the script to use for the given `state`. If loading fails at any point, it falls back to the default theme.
-- It also updates fallback tracking and the current widget path.
--
-- @param theme_folder (string) The theme folder in the format "source/folder" (e.g., "user/mytheme").
-- @param state (string) The dashboard state for which to load the script (e.g., "main", "settings").
-- @return (function|table|nil) Returns the loaded script chunk or module table, or nil if loading fails.
--
-- Side effects:
--   - Updates `dashboard.themeFallbackUsed[state]` and `dashboard.themeFallbackTime[state]` on fallback.
--   - Sets `dashboard.currentWidgetPath` to the active theme path.
--
-- Logging:
--   - Logs info and error messages if loading or execution fails.
local function load_state_script(theme_folder, state, isFallback)
    isFallback = isFallback or false

    local src, folder = theme_folder:match("([^/]+)/(.+)")
    local base = (src == "user") and themesUserPath or themesBasePath

    -- if parsing failed, try default
    if not src or not folder then
        if not isFallback then
            return load_state_script(dashboard.DEFAULT_THEME, state, true)
        end
        -- default is broken too
        dashboard.themeFallbackUsed[state] = true
        dashboard.themeFallbackTime[state] = os.clock()
        return nil
    end

    -- helper to set the current widget path
    local function setPath() dashboard.currentWidgetPath = src.."/"..folder end

    -- 1) load init.lua
    local initPath = base..folder.."/init.lua"
    local initChunk, initErr = compile(initPath)
    if not initChunk then
        if not isFallback then
            return load_state_script(dashboard.DEFAULT_THEME, state, true)
        end
        dashboard.themeFallbackUsed[state] = true
        dashboard.themeFallbackTime[state] = os.clock()
        return nil
    end

    -- run init.lua
    local ok, initTable = pcall(initChunk)
    if not ok or type(initTable) ~= "table" then
        if not isFallback then
            return load_state_script(dashboard.DEFAULT_THEME, state, true)
        end
        dashboard.themeFallbackUsed[state] = true
        dashboard.themeFallbackTime[state] = os.clock()
        return nil
    end

    -- decide which state file to load
    local scriptName = (type(initTable[state])=="string" and initTable[state]~="") 
                       and initTable[state] 
                       or (state..".lua")
    local scriptPath = base..folder.."/"..scriptName

    -- 2) load the actual state script (or fallback to default)
    local chunk, chunkErr = compile(scriptPath)
    if not chunk then
        if not isFallback then
            return load_state_script(dashboard.DEFAULT_THEME, state, true)
        end
        -- even default missing? give up
        log("dashboard: Could not load "..scriptName.." for "..folder.." or default: "..tostring(chunkErr), "info")
        dashboard.themeFallbackUsed[state] = true
        dashboard.themeFallbackTime[state] = os.clock()
        return nil
    end

    -- at this point, we successfully have a chunk; mark no fallback
    dashboard.themeFallbackUsed[state] = (isFallback == true)
    dashboard.themeFallbackTime[state] = isFallback and os.clock() or 0
    setPath()

    -- if standalone, return the chunk itself; otherwise run it and return module
    if initTable.standalone then
        return chunk
    else
        local ok2, module = pcall(chunk)
        if not ok2 then
            if not isFallback then
                return load_state_script(dashboard.DEFAULT_THEME, state, true)
            end
            dashboard.themeFallbackUsed[state] = true
            dashboard.themeFallbackTime[state] = os.clock()
            return nil
        end
        return module
    end
end

-- Utility to get the correct theme for a given state
local function getThemeForState(state)
    local modelPrefs = rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.dashboard
    local userPrefs = rfsuite.preferences.dashboard
    local val = nil
    if modelPrefs then
        val = modelPrefs["theme_" .. state]
        if val == "nil" then val = nil end
    end
    return val or userPrefs["theme_" .. state] or dashboard.DEFAULT_THEME
end

-- Reload just the active state script
local function reload_state_only(state)
    dashboard.utils.resetImageCache()
    loadedStateModules[state] = load_state_script(getThemeForState(state), state)
    lastLoadedBoxCount = 0
    lastBoxRectsCount = 0
    objectWakeupIndex = 1
    objectsThreadedWakeupCount = 0
    objectWakeupsPerCycle = nil
    dashboard.boxRects = {}
    lcd.invalidate()
end


function dashboard.reload_active_theme_only(force)
    dashboard.utils.resetImageCache()

    local state = dashboard.flightmode or "preflight"
    local theme = getThemeForState(state)

    if force or not loadedStateModules[state] then
        log("Reloading active theme: " .. theme, "info")
        loadedStateModules[state] = load_state_script(theme, state)
    else
        log("Skipped reloading active theme: already loaded", "info")
    end
    
    firstWakeup = true
    lcd.invalidate()  -- Triggers paint, which shows the loader

    -- Reset scheduler & layout state so the hourglass & wakeup cycle restart cleanly
    wakeupScheduler             = 0
    dashboard.boxRects          = {}
    objectsThreadedWakeupCount  = 0
    objectWakeupIndex           = 1
    lastLoadedBoxCount          = 0
    lastBoxRectsCount           = 0
    objectWakeupsPerCycle       = nil

    -- Force spinner draw
    lcd.invalidate()
end

function dashboard.applySchedulerSettings()

    local active = dashboard.flightmode or "preflight"
    local mod = loadedStateModules[active]
    if mod and mod.scheduler then
        local initTable = (type(mod.scheduler) == "function") and mod.scheduler() or mod.scheduler
        if type(initTable) == "table" then

            dashboard._useSpreadScheduling = (initTable.spread_scheduling ~= false)
            dashboard._useSpreadSchedulingPaint = (initTable.spread_scheduling_paint ~= false)

            -- NEW: optionally override spread ratio
            dashboard._spreadRatioOverride = (type(initTable.spread_ratio) == "number" and initTable.spread_ratio > 0 and initTable.spread_ratio <= 1)
                and initTable.spread_ratio
                or nil
        else
            dashboard._useSpreadScheduling = true
            dashboard._useSpreadSchedulingPaint = true
            dashboard._spreadRatioOverride = nil
        end
    else
        dashboard._useSpreadScheduling = true
        dashboard._useSpreadSchedulingPaint = true
        dashboard._spreadRatioOverride = nil
    end

end

function dashboard.reload_themes(force)

    -- Clear cached subtype renderers (e.g. time/flight/telemetry modules)
    dashboard.renders = {}

    -- Step 1: Load just the active theme and reset core state
    dashboard.reload_active_theme_only(force)

    -- Step 2: Reset state preload index (wake-up loop will handle it)
    statePreloadIndex = 1  -- start loading immediately

    -- Step 3: Apply scheduler settings
    dashboard.applySchedulerSettings()

    -- Step 4: Load object types for active module only
    local boxes = {}
    if mod and mod.boxes then
        local rawBoxes = type(mod.boxes) == "function" and mod.boxes() or mod.boxes
        for _, box in ipairs(rawBoxes or {}) do
            table.insert(boxes, box)
        end
    end
    dashboard.loadAllObjects(boxes)


    -- Force full redraw from top
    firstWakeup = true
    dashboard._loader_start_time = nil
    dashboard._hg_cycles = dashboard._hg_cycles_required

    -- Reset rendering state explicitly
    dashboard._forceFullRepaint = true
    dashboard.boxRects = {}
    lastBoxRectsCount = 0
    lastLoadedBoxCount = 0
    objectWakeupIndex = 1
    objectWakeupsPerCycle = nil
    objectsThreadedWakeupCount = 0

    -- force module.layout to be rendered
    local mod = loadedStateModules[dashboard.flightmode or "preflight"]
    if type(mod) == "table" and mod.layout and mod.boxes then
        log("Manually triggering renderLayout after theme reload", "info")
        dashboard.renderLayout(nil, mod)
    end


end



--- Calls a state-specific function for the dashboard widget, handling fallbacks and errors.
-- @param funcName string: The name of the function to call (e.g., "paint").
-- @param widget table: The widget instance to pass to the state function.
-- @param paintFallback boolean: If true, displays an error if the function is not implemented for the current state.
-- @return any: The result of the called state function, the module (for "paint" layout), or nil if not applicable.
local function callStateFunc(funcName, widget, paintFallback)
    local state = dashboard.flightmode or "preflight"
    local module = loadedStateModules[state]

    if not tasks.active() then
        return nil
    end

    if type(module) == "table" and module.layout and funcName == "paint" then
        return module  -- Let `dashboard.paint()` handle rendering
    end

    if module and type(module[funcName]) == "function" then
        return module[funcName](widget)
    end

    if paintFallback then
        local msg = "dashboard: " .. funcName .. " not implemented for " .. state .. "."
        dashboard.utils.screenError(msg)
    end
end

--- Creates a dashboard widget by invoking the "create" state function.
-- @param widget The widget instance to be created.
-- @return The result of the "create" state function for the given widget.
function dashboard.create(widget)
    return {value=0}
end


--- Paints the dashboard widget based on the current flight mode state.
-- Determines the current state and retrieves the corresponding module from `loadedStateModules`.
-- If the module is valid and contains `layout` and `boxes`, it renders the layout and calls the module's custom paint function if available.
-- Otherwise, it falls back to calling a generic state paint function.
-- @param widget The widget object to be painted.
function dashboard.paint(widget)

    if unsupportedResolution then
        -- If the resolution is unsupported, show an error message and return
        local W, H = lcd.getWindowSize()
        if H < (system.getVersion().lcdHeight/5) or W < (system.getVersion().lcdWidth/10) then
           dashboard.utils.screenError(i18n("widgets.dashboard.unsupported_resolution"), true, 0.4)
        else
            dashboard.overlaymessage(0, 0, W, H , i18n("widgets.dashboard.unsupported_resolution"))
        end     
        return
    end


    -- on the *first* paint, immediately draw the spinner and bail out
    if firstWakeup then
        local W, H = lcd.getWindowSize()
        local loaderY = (isFullScreen and headerLayout.height) or 0
        dashboard.loader(0, loaderY, W, H - loaderY)
        lcd.invalidate()  -- Ensures repaint while theme loads
        return
    end

    local state = dashboard.flightmode or "preflight"
    local module = loadedStateModules[state]

    if type(module) == "table" and module.layout and module.boxes then
        dashboard.renderLayout(widget, module)
        if type(module.paint) == "function" then
            module.paint(widget, module.layout, module.boxes)
        end
    else
        callStateFunc("paint", widget)
    end


end

--- Configures the given dashboard widget by invoking the "configure" state function.
-- If the state function does not return a value, the original widget is returned.
-- @param widget table: The widget instance to configure.
-- @return table: The configured widget, or the original widget if no configuration was applied.
function dashboard.configure(widget)
    return callStateFunc("configure", widget) or widget
end

--- Reads data from the given dashboard widget by invoking the appropriate state function.
-- @param widget The widget instance to read data from.
-- @return The result of the state function call for reading the widget.
function dashboard.read(widget)
    return callStateFunc("read", widget)
end

--- Writes data to the specified widget by invoking the appropriate state function.
-- @param widget The widget object to write data to.
-- @return The result of the state function call for writing.
function dashboard.write(widget)
    return callStateFunc("write", widget)
end

--- Builds the dashboard widget by invoking the appropriate state function.
-- @param widget The widget instance to be built.
-- @return The result of the state function call for building the widget.
function dashboard.build(widget)
    return callStateFunc("build", widget)
end

--- Handles events for the dashboard widget, including key presses, rotary encoder, and touch events.
-- 
-- @param widget The widget instance receiving the event.
-- @param category The event category (e.g., EVT_KEY for key events, 1 for touch).
-- @param value The event value (e.g., key code, touch code).
-- @param x (optional) The x-coordinate for touch events.
-- @param y (optional) The y-coordinate for touch events.
--
-- Handles the following:
--   - State transitions between "preflight" and "postflight" modes.
--   - Navigation between selectable boxes using rotary encoder or keys.
--   - Selection and activation of boxes via key or touch events.
--   - Delegates event handling to the current state module if available.
--   - Clears selection on EXIT key.
--   - Ensures focus and valid indices before processing events.
-- 
-- @return true if the event was handled, otherwise delegates to the state module or returns nil.
function dashboard.event(widget, category, value, x, y)

    local state = dashboard.flightmode or "preflight"
    local module = loadedStateModules[state]

    if state == "postflight" and category == EVT_KEY and value == 131 then
        rfsuite.widgets.dashboard.flightmode = "preflight"
        dashboard.resetFlightModeAsk()
    end

    if category == EVT_KEY and lcd.hasFocus() then
        local indices = getOnpressBoxIndices()
        local count = #indices
        if count == 0 then return end

        local current = dashboard.selectedBoxIndex or 1
        local pos = 1
        for i, idx in ipairs(indices) do
            if idx == current then pos = i break end
        end

        if value == 4099 then -- rotary left
            pos = pos - 1
            if pos < 1 then pos = count end
            dashboard.selectedBoxIndex = indices[pos]
            lcd.invalidate(widget)
            return true
        elseif value == 4100 then -- rotary right
            pos = pos + 1
            if pos > count then pos = 1 end
            dashboard.selectedBoxIndex = indices[pos]
            lcd.invalidate(widget)
            return true  
        elseif value == 33 and category == EVT_KEY then
            local inIndices = false
            for i = 1, #indices do
                if indices[i] == dashboard.selectedBoxIndex then inIndices = true break end
            end
            if not inIndices then
                dashboard.selectedBoxIndex = indices[1]
                lcd.invalidate(widget)
                return true
            else
                local idx = dashboard.selectedBoxIndex
                local rect = dashboard.boxRects[idx]
                if rect and rect.box.onpress then
                    rect.box.onpress(widget, rect.box, rect.x, rect.y, category, value)
                    system.killEvents(97)
                    return true
                end
            end
        end
    end
    if value == 35 and dashboard.selectedBoxIndex then -- EXIT key
        dashboard.selectedBoxIndex = nil
        lcd.invalidate(widget)
        return true
    end

    if category == 1 and value == 16641 and lcd.hasFocus() then -- touch
        if x and y then
            for i, rect in ipairs(dashboard.boxRects) do
                if x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h then
                    if rect.box.onpress then
                        dashboard.selectedBoxIndex = i
                        lcd.invalidate(widget)
                        rect.box.onpress(widget, rect.box, x, y, category, value)
                        system.killEvents(16640)
                        return true
                    end
                end
            end
        end
    end

    if type(module) == "table" and type(module.event) == "function" then
        return module.event(widget, category, value, x, y)
    end

end

--- Handles the periodic wakeup logic for the dashboard widget.
-- 
-- This function is called regularly by the Ethos system to update the dashboard's state.
-- It manages theme reloading on first wakeup, interval-based updates depending on widget visibility,
-- flight mode changes, overlay message updates, state-specific wakeup logic, and per-object wakeups.
-- It also handles focus removal from selected boxes when the widget loses focus.
--
-- @param widget The widget instance to update.
function dashboard.wakeup(widget)

    -- Check if MSP is allow msp to be prioritized
    if rfsuite.app and rfsuite.app.triggers.mspBusy and not (rfsuite.session and rfsuite.session.isConnected) then return end

    local telemetry = tasks.telemetry
    local W, H = lcd.getWindowSize()

    if not dashboard.utils.supportedResolution(W, H, supportedResolutions) then
        unsupportedResolution = true
        lcd.invalidate(widget)
        return
    else
        unsupportedResolution = false
    end

    if lcd.darkMode() ~= darkModeState then
        darkModeState = lcd.darkMode()
        dashboard.reload_themes(true)
    end

    if firstWakeup then
        firstWakeup = false
        local theme = getThemeForState("preflight")
        log("Initial loading of preflight theme: " .. theme, "info")
        loadedStateModules.preflight = load_state_script(theme, "preflight")
        dashboard.applySchedulerSettings()
    end

    if statePreloadIndex <= #statePreloadQueue then
        local state = statePreloadQueue[statePreloadIndex]
        if not loadedStateModules[state] then
            local theme = getThemeForState(state)
            log("Preloading theme: " .. theme .. " for " .. state, "info")
            loadedStateModules[state] = load_state_script(theme, state)

            local mod = loadedStateModules[state]
            if mod and mod.boxes then
                local boxes = type(mod.boxes) == "function" and mod.boxes() or mod.boxes
                for _, box in ipairs(boxes or {}) do
                    dashboard.loadObjectType(box)
                end
            end
        end
        statePreloadIndex = statePreloadIndex + 1
    end

    if firstWakeupCustomTheme and
        rfsuite.session.mcu_id and
        rfsuite.session.modelPreferences and
        rfsuite.session.modelPreferences.dashboard then

        local modelPrefs = rfsuite.session.modelPreferences.dashboard
        local currentPrefs = rfsuite.preferences.dashboard

        if (modelPrefs.theme_preflight and modelPrefs.theme_preflight ~= "nil" and modelPrefs.theme_preflight ~= currentPrefs.theme_preflight) or
           (modelPrefs.theme_inflight and modelPrefs.theme_inflight ~= "nil" and modelPrefs.theme_inflight ~= currentPrefs.theme_inflight) or
           (modelPrefs.theme_postflight and modelPrefs.theme_postflight ~= "nil" and modelPrefs.theme_postflight ~= currentPrefs.theme_postflight) then
            dashboard.reload_themes()
            firstWakeupCustomTheme = false
        end
    end

    local now = os.clock()
    local visible = lcd.isVisible()
    local admin = rfsuite.app and rfsuite.app.guiIsRunning 

    -- Throttle CPU usage based on connection and visibility
    if not rfsuite.session.isConnected then
        -- if not connected, then poll every 1 second
        if (now - lastWakeup) < 1 then return end
    elseif admin or not visible then
        -- if admin app is running or quick return
        return 
    else
        -- default rate limit of 0.05s (50% of clock speed)
        if (now - lastWakeup) < 0.05 then return end   
    end

    local currentFlightMode = rfsuite.flightmode.current or "preflight"
    if lastFlightMode ~= currentFlightMode then
        dashboard.flightmode = currentFlightMode
        reload_state_only(currentFlightMode)
        lastFlightMode = currentFlightMode
        if dashboard._useSpreadSchedulingPaint then
            lcd.invalidate(widget)
        end    
    end

    local newMessage = dashboard.computeOverlayMessage()
    if dashboard.overlayMessage ~= newMessage then
        dashboard.overlayMessage = newMessage
        dashboard._hg_cycles = newMessage and dashboard._hg_cycles_required or 0
        lcd.invalidate(widget)
    end

    local state = dashboard.flightmode or "preflight"
    local module = loadedStateModules[state]

    if module and type(module.wakeup) == "function" then
        module.wakeup(widget)
    else
        callStateFunc("wakeup", widget)
    end

    if #dashboard.boxRects > 0 then
        -- Always wake explicitly scheduled objects
        for _, idx in ipairs(scheduledBoxIndices) do
            local rect = dashboard.boxRects[idx]
            local obj = dashboard.objectsByType[rect.box.type]
            if obj and obj.wakeup then
                obj.wakeup(rect.box)
            end
        end

        local needsFullInvalidate = dashboard._forceFullRepaint or dashboard.overlayMessage or objectsThreadedWakeupCount < 1
        local dirtyRects = {}

        if dashboard._useSpreadScheduling == false then
            -- Wake up all boxes regardless of scheduler flag
            for i, rect in ipairs(dashboard.boxRects) do
                local obj = dashboard.objectsByType[rect.box.type]
                if obj and obj.wakeup and not obj.scheduler then
                    obj.wakeup(rect.box)
                end
                if not needsFullInvalidate then
                    local dirtyFn = obj and obj.dirty
                    if dirtyFn and dirtyFn(rect.box) then
                        table.insert(dirtyRects, {
                            x = rect.x - 1, y = rect.y - 1,
                            w = rect.w + 2, h = rect.h + 2
                        })
                    end
                end
            end

        else
            -- Spread mode: stagger wakeups
            for i = 1, objectWakeupsPerCycle do
                local idx = objectWakeupIndex
                local rect = dashboard.boxRects[idx]
                if rect then
                    local obj = dashboard.objectsByType[rect.box.type]
                    if obj and obj.wakeup and not obj.scheduler then
                        obj.wakeup(rect.box)
                    end
                    if not needsFullInvalidate then
                        local dirtyFn = obj and obj.dirty
                        if dirtyFn and dirtyFn(rect.box) then
                            table.insert(dirtyRects, {
                                x = rect.x - 1, y = rect.y - 1,
                                w = rect.w + 2, h = rect.h + 2
                            })
                        end
                    end
                end
                objectWakeupIndex = (#dashboard.boxRects > 0) and ((objectWakeupIndex % #dashboard.boxRects) + 1) or 1
            end

        end

        objectsThreadedWakeupCount = objectsThreadedWakeupCount + 1

        -- Force repaint
        if dashboard._useSpreadSchedulingPaint then
            if needsFullInvalidate then
                lcd.invalidate()
            else
                for _, r in ipairs(dirtyRects) do
                    lcd.invalidate(r.x, r.y, r.w, r.h)
                end
            end
        else
            lcd.invalidate()
        end
    end


    if not lcd.hasFocus(widget) and dashboard.selectedBoxIndex ~= nil then
        log("Removing focus from box " .. tostring(dashboard.selectedBoxIndex), "info")
        dashboard.selectedBoxIndex = nil
        if dashboard._useSpreadSchedulingPaint then
            lcd.invalidate(widget)
        end    
    end

    if not dashboard._useSpreadSchedulingPaint then
        lcd.invalidate()
    end
end


--- Lists available dashboard themes by scanning system and user theme directories.
-- 
-- This function searches for theme folders in predefined base paths, loads their `init.lua` files,
-- and collects theme metadata if the theme is valid and permitted by developer settings.
--
-- @return themes (table) A list of theme tables, each containing:
--   - name (string): The display name of the theme.
--   - configure (function|nil): Optional configuration function for the theme.
--   - folder (string): The folder name where the theme is located.
--   - idx (number): The index of the theme in the list.
--   - source (string): The source type ("system" or "user").
function dashboard.listThemes()
    local themes = {}
    local num = 0

    local function scanThemes(basePath, sourceType)
        local folders = system.listFiles(basePath)
        if not folders then return end
        for _, folder in ipairs(folders) do
            if folder ~= ".." and folder ~= "." and not folder:match("%.%a+$") then    
                local themeDir = basePath .. folder .. "/"
                local initPath = themeDir .. "init.lua"
                if utils.dir_exists(basePath, folder) then
                    local chunk, err = compile(initPath)
                    if chunk then
                        local ok, initTable = pcall(chunk)
                        if ok and initTable and type(initTable.name) == "string" then
                            if not initTable.developer or rfsuite.preferences.developer.devtools == true then
                                num = num + 1
                                themes[num] = {
                                    name = initTable.name,
                                    configure = initTable.configure,
                                    folder = folder,
                                    idx = num,
                                    source = sourceType,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    scanThemes(themesBasePath, "system")
    local basePath = "SCRIPTS:/" .. preferences
    if utils.dir_exists(basePath, 'dashboard') then
        scanThemes(themesUserPath, "user")
    end

    return themes
end

--- Retrieves a preference value for the dashboard widget.
-- Depending on whether the GUI is running, this function fetches the preference value
-- from either the current widget path or the dashboard editing theme.
-- @param key string: The preference key to retrieve.
-- @return any|nil: The value associated with the given key, or nil if not found or prerequisites are missing.
function dashboard.getPreference(key)
    if not rfsuite.session.modelPreferences or not dashboard.currentWidgetPath then return nil end

    if not rfsuite.app.guiIsRunning then
        return rfsuite.ini.getvalue(rfsuite.session.modelPreferences, dashboard.currentWidgetPath, key)
    else
        return rfsuite.ini.getvalue(rfsuite.session.modelPreferences, rfsuite.app.dashboardEditingTheme, key)
    end
end

--- Saves a user preference for the dashboard widget.
-- Depending on whether the GUI is running, the preference is saved either for the current widget path
-- or for the dashboard editing theme.
-- @param key string: The preference key to save.
-- @param value any: The value to associate with the key.
-- @return boolean: True if the preference was saved successfully, false otherwise.
function dashboard.savePreference(key, value)
    if not rfsuite.session.modelPreferences or not rfsuite.session.modelPreferencesFile or not dashboard.currentWidgetPath then
        return false
    end
    if not rfsuite.app.guiIsRunning then
        rfsuite.ini.setvalue(rfsuite.session.modelPreferences, dashboard.currentWidgetPath, key, value)
        return rfsuite.ini.save_ini_file(rfsuite.session.modelPreferencesFile, rfsuite.session.modelPreferences)
    else
        rfsuite.ini.setvalue(rfsuite.session.modelPreferences, rfsuite.app.dashboardEditingTheme, key, value)
        return rfsuite.ini.save_ini_file(rfsuite.session.modelPreferencesFile, rfsuite.session.modelPreferences)
    end
end

-- Ask user for confirmation before erasing dataflash
function dashboard.resetFlightModeAsk()

    local buttons = {{
        label = i18n("app.btn_ok"),
        action = function()
            tasks.events.flightmode.reset()
            lcd.invalidate()
            return true
        end
    }, {
        label = i18n("app.btn_cancel"),
        action = function()
            return true
        end
    }}

    form.openDialog({
        width = nil,
        title =  i18n("widgets.dashboard.reset_flight_ask_title"),
        message = i18n("widgets.dashboard.reset_flight_ask_text"),
        buttons = buttons,
        wakeup = function()
        end,
        paint = function()
        end,
        options = TEXT_LEFT
    })

end    

function dashboard.menu(widget)

    return {
        {i18n("widgets.dashboard.reset_flight"), dashboard.resetFlightModeAsk},
    }
end

-- table to stall object cache
dashboard.renders = dashboard.renders or {}

-- disabled use of title
dashboard.title = false

return dashboard
