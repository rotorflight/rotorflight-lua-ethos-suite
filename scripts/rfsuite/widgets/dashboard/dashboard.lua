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

-- Supported resolutions
local supportedResolutions = {
    { 784, 294 },   -- X20, X20RS etc
    { 784, 316 },   -- X20, X20RS etc (no title)
    { 472, 191 },   -- TWXLITE, X18, X18S
    { 472, 210 },   -- TWXLITE, X18, X18S (no title)
    { 630, 236 },   -- X14
    { 630, 258 },   -- X14 (no title)
}


-- Track the previous flight mode so we can detect changes on wakeup
local lastFlightMode = nil

-- Capture the script start time for uptime or performance measurements
local initTime = os.clock()

-- Default theme to fall back on if user or system theme fails to load
dashboard.DEFAULT_THEME = "system/default"

-- Base paths for loading themes:
--   themesBasePath: where system themes are stored
--   themesUserPath: where user-defined themes are stored (preferences)
local themesBasePath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/themes/"
local themesUserPath = "SCRIPTS:/" .. rfsuite.config.preferences .. "/dashboard/"

-- Create the user theme directory if it doesn't exist
os.mkdir(themesUserPath)

-- Cache for loaded state modules (preflight, inflight, postflight)
local loadedStateModules = {}

-- Intervals (in seconds) for various scheduler and paint operations:
local loadedThemeIntervals = {
    wakeup_interval     = 0.25,  -- how often to wake the widget when visible
    wakeup_interval_bg  = nil,   -- how often to wake when not visible (nil = skip)
    paint_interval      = 0.5,   -- how often to force a repaint
}

-- Counter used by wakeup to cycle through tasks
local wakeupScheduler = 0

-- Spread scheduling of object wakeups to avoid doing them all at once:
local objectWakeupIndex = 1             -- current object index for wakeup
local objectWakeupsPerCycle = nil       -- number of objects to wake per cycle (calculated later)
local objectsThreadedWakeupCount = 0
local lastLoadedBoxCount = 0

-- Track background loading of remaining flight mode modules
local statePreloadQueue = {"inflight", "postflight"}
local statePreloadIndex = 1

local unsupportedResolution = false  -- flag to track unsupported resolutions

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
dashboard.flightmode = rfsuite.session.flightMode or "preflight"

-- Path to the current widget/theme in use (set during theme loading)
dashboard.currentWidgetPath = nil

-- Any overlay message to display on screen (e.g., error or status)
dashboard.overlayMessage = nil

-- Loaded dashboard objects organized by their "type" field
dashboard.objectsByType = {}

-- Timestamps of the last wakeup calls to throttle based on intervals:
local lastWakeup   = 0  -- for visible wakeup
local lastWakeupBg = 0  -- for background wakeup

-- * CONFIGURABLE SIZES *
-- Fraction of min(width, height) to use for the spinner/overlay radius.
-- Increase to ~0.36 for a 20% larger spinner (0.3 * 1.2)
dashboard.loaderScale    = 0.38
dashboard.overlayScale      = 0.38

-- initialize cache once
dashboard._moduleCache = dashboard._moduleCache or {}

-- how many paint‐cycles to keep showing the spinner (5 s ÷ paint_interval)
 dashboard._hg_cycles_required = math.ceil(2.5 / (loadedThemeIntervals.paint_interval or 0.5))
 dashboard._hg_cycles = 0

-- Utility methods loaded from external utils.lua (drawing, color helpers, etc.)
dashboard.utils = assert(
    rfsuite.compiler.loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/lib/utils.lua")
)()

dashboard.loaders = assert(
    rfsuite.compiler.loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/lib/loaders.lua")
)()

function dashboard.loader(x, y, w, h)
    dashboard.loaders.pulseLoader(dashboard, x, y, w, h)
end

function dashboard.overlaymessage(x, y, w, h, txt)
    dashboard.loaders.pulseOverlayMessage(dashboard, x, y, w, h, txt)
end

--- Calculates the scheduler percentage based on the number of objects.
-- This function determines what fraction of objects should be processed per cycle,
-- depending on the total count. Fewer objects result in a higher percentage processed
-- per cycle, while more objects reduce the percentage to avoid overloading.
-- @param count number The total number of objects to schedule.
-- @return number The percentage (as a decimal) of objects to process per cycle.
local function computeObjectSchedulerPercentage(count)
    if count <= 10 then return 0.5      -- fewer objects → more per cycle
    elseif count <= 15 then return 0.4
    elseif count <= 25 then return 0.3
    elseif count <= 40 then return 0.2
    else return 0.15 end                -- many objects → fewer per cycle
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
                local baseDir = rfsuite.config.baseDir or "default"
                local objPath = "SCRIPTS:/" .. baseDir .. "/widgets/dashboard/objects/" .. typ .. ".lua"
                local ok, obj = pcall(function()
                    return assert(rfsuite.compiler.loadfile(objPath))()
                end)
                if ok and type(obj) == "table" then
                    dashboard._moduleCache[typ] = obj
                else
                    rfsuite.utils.log("Failed to load object: " .. tostring(typ), "info")
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
    local apiVersionAsString = tostring(rfsuite.session.apiVersion)
    local state = dashboard.flightmode or "preflight"
    local moduleState = (model.getModule(0):enable() or model.getModule(1):enable()) or false
    local sportSensor = system.getSource({appId = 0xF101})
    local elrsSensor = system.getSource({crsfId = 0x14, subIdStart = 0, subIdEnd = 1})

    if dashboard.themeFallbackUsed and dashboard.themeFallbackUsed[state] and
       (os.clock() - (dashboard.themeFallbackTime and dashboard.themeFallbackTime[state] or 0)) < 10 then
        return rfsuite.i18n.get("widgets.dashboard.theme_load_error")
    elseif not rfsuite.utils.ethosVersionAtLeast() then
        return string.format(
            string.upper(rfsuite.i18n.get("ethos")) .. " < V%d.%d.%d",
            rfsuite.config.ethosVersion[1],
            rfsuite.config.ethosVersion[2],
            rfsuite.config.ethosVersion[3]
        )
    elseif not rfsuite.tasks.active() then
        return rfsuite.i18n.get("widgets.dashboard.check_bg_task")
    elseif moduleState == false then
        return rfsuite.i18n.get("widgets.dashboard.check_rf_module_on")
    elseif not (sportSensor or elrsSensor) then
        return rfsuite.i18n.get("widgets.dashboard.check_discovered_sensors")
    elseif not rfsuite.session.isConnected and  state ~= "postflight" then
        return rfsuite.i18n.get("widgets.dashboard.waiting_for_connection")    
    elseif not rfsuite.session.telemetryState and state == "preflight" then
        return rfsuite.i18n.get("widgets.dashboard.no_link")
    elseif rfsuite.session.telemetryState and rfsuite.tasks.telemetry and not rfsuite.tasks.telemetry.validateSensors() then
        return rfsuite.i18n.get("widgets.dashboard.validate_sensors")
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
    local telemetry = rfsuite.tasks.telemetry

    -- tiny resolver for function-or-value patterns
    local function resolve(val, ...)
      if type(val) == "function" then return val(...) else return val end
    end

    -- grab layout & boxes
    local layout   = resolve(config.layout) or {}
    local rawBoxes = config.boxes or layout.boxes or {}
    local boxes    = (type(rawBoxes) == "function") and rawBoxes() or rawBoxes

    -- only reload widget modules if your boxes definition changed
    if #boxes ~= lastLoadedBoxCount then
        dashboard.loadAllObjects(boxes)
        lastLoadedBoxCount = #boxes
    end

    -- overall size
    local W_raw, H_raw = lcd.getWindowSize()
    local cols    = layout.cols    or 1
    local rows    = layout.rows    or 1
    local pad     = layout.padding or 0

    -- Find the largest W/H values that divide cleanly into grid cells
    local function adjustDimension(dim, cells, padCount)
        local target = dim
        while ((target - (padCount * pad)) % cells) ~= 0 do
            target = target - 1
        end
        return target
    end

    local W = adjustDimension(W_raw, cols, cols - 1)
    local H = adjustDimension(H_raw, rows, rows + 1)  -- +1 to account for extra vertical padding in Ethos
    local xOffset = math.floor((W_raw - W) / 2)

    -- Now we proceed with perfect divisions:
    local contentW = W - ((cols - 1) * pad)
    local contentH = H - ((rows + 1) * pad)
    local boxW     = contentW / cols
    local boxH     = contentH / rows

    ----------------------------------------------------------------
    -- PHASE 1: ALWAYS MEASURE & BUILD dashboard.boxRects
    ----------------------------------------------------------------
    dashboard.boxRects = {}
    local cols    = layout.cols    or 1
    local rows    = layout.rows    or 1
    local pad     = layout.padding or 0

    local contentW = W - ((cols - 1) * pad)
    local contentH = H - ((rows + 1) * pad)
    local boxW     = contentW / cols
    local boxH     = contentH / rows

    for i, box in ipairs(boxes) do
        local w, h = getBoxSize(box, boxW, boxH, pad, W, H)
        box.xOffset = xOffset
        local x, y = getBoxPosition(box, w, h, boxW, boxH, pad, W, H)
        dashboard.boxRects[#dashboard.boxRects+1] = { x=x, y=y, w=w, h=h, box=box }
    end

    -- recompute how many objects to wake per cycle if the count changed
    if not objectWakeupsPerCycle or lastBoxRectsCount ~= #dashboard.boxRects then
        local count = #dashboard.boxRects
        local percentage = computeObjectSchedulerPercentage(count)
        objectWakeupsPerCycle = math.max(1, math.ceil(count * percentage))
        lastBoxRectsCount     = count
        rfsuite.utils.log("Object scheduler set to " .. tostring(objectWakeupsPerCycle) ..
                        " out of " .. tostring(count) .. " boxes", "info")
    end

    scheduledBoxIndices = {}
    for i, rect in ipairs(dashboard.boxRects) do
        local obj = dashboard.objectsByType[rect.box.type]
        if obj and obj.scheduler and obj.wakeup then
            scheduledBoxIndices[#scheduledBoxIndices + 1] = i
        end
    end    

    ----------------------------------------------------------------
    -- PHASE 2: HOURGLASS until first threaded‐wakeup pass completes
    ----------------------------------------------------------------
    if objectsThreadedWakeupCount < 1 then
        dashboard.loader    (0, 0, W, H)
        lcd.invalidate()
        return
    end

    ----------------------------------------------------------------
    -- PHASE 3: REAL PAINT (only fill background once here)
    ----------------------------------------------------------------
    utils.setBackgroundColourBasedOnTheme()

    local selColor  = layout.selectcolor  or utils.resolveColor("yellow") or lcd.RGB(255,255,0)
    local selBorder = layout.selectborder or 2

    for i, rect in ipairs(dashboard.boxRects) do
        local x, y, w, h, box = rect.x, rect.y, rect.w, rect.h, rect.box
        local obj = dashboard.objectsByType[box.type]
        if obj and obj.paint then
            -- paint the widget’s content
            obj.paint(x, y, w, h, box, telemetry)
        end
        -- highlight if selected
        if dashboard.selectedBoxIndex == i and box.onpress then
            lcd.color(selColor)
            lcd.drawRectangle(x, y, w, h, selBorder)
        end
    end

    -- overlay spinner: reset or countdown our cycle counter
    if dashboard.overlayMessage then
      -- new overlay → restart full 5s worth of cycles
      dashboard._hg_cycles = dashboard._hg_cycles_required
    end
    if dashboard._hg_cycles > 0 then
      -- still have cycles left → keep drawing spinner
      dashboard.overlaymessage(0, 0, W, H, dashboard.overlayMessage or "")
      dashboard._hg_cycles = dashboard._hg_cycles - 1
      lcd.invalidate()
    end

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
local function load_state_script(theme_folder, state)
    local usedFallback = false
    local source, folder = theme_folder:match("([^/]+)/(.+)")
    local themeBasePath = (source == "user") and themesUserPath or themesBasePath

    -- fallback if parsing failed
    if not source or not folder then
        theme_folder = dashboard.DEFAULT_THEME
        source, folder = theme_folder:match("([^/]+)/(.+)")
        themeBasePath = (source == "user") and themesUserPath or themesBasePath
        usedFallback = true
    end

    local function setCurrentWidgetPath()
        dashboard.currentWidgetPath = source .. "/" .. folder
    end

    -- Try to load init.lua
    local initPath = themeBasePath .. folder .. "/init.lua"
    local initChunk, initErr = rfsuite.compiler.loadfile(initPath)

    if not initChunk then
        usedFallback = true
        local fallbackSource, fallbackFolder = dashboard.DEFAULT_THEME:match("([^/]+)/(.+)")
        local fallbackBasePath = (fallbackSource == "user") and themesUserPath or themesBasePath
        local fallbackInitPath = fallbackBasePath .. fallbackFolder .. "/init.lua"

        rfsuite.utils.log("dashboard: Could not load init.lua for " .. tostring(folder) ..
                          ". Falling back to default. Error: " .. tostring(initErr), "info")

        initChunk, initErr = rfsuite.compiler.loadfile(fallbackInitPath)
        if not initChunk then
            rfsuite.utils.log("dashboard: Could not load default theme's init.lua. Error: " .. tostring(initErr), "error")
            dashboard.themeFallbackUsed[state] = true
            dashboard.themeFallbackTime[state] = os.clock()
            return nil
        end

        source, folder = fallbackSource, fallbackFolder
        themeBasePath = fallbackBasePath
    end

    local ok, initTable = pcall(initChunk)
    if not ok or type(initTable) ~= "table" then
        rfsuite.utils.log("dashboard: Error running init.lua for " .. tostring(folder) .. ": " ..
                          tostring(initTable) .. ". Falling back to default.", "error")

        if theme_folder ~= dashboard.DEFAULT_THEME then
            usedFallback = true
            local fallbackSource, fallbackFolder = dashboard.DEFAULT_THEME:match("([^/]+)/(.+)")
            local fallbackBasePath = (fallbackSource == "user") and themesUserPath or themesBasePath
            local fallbackInitPath = fallbackBasePath .. fallbackFolder .. "/init.lua"
            local fallbackChunk, fallbackErr = rfsuite.compiler.loadfile(fallbackInitPath)

            if fallbackChunk then
                ok, initTable = pcall(fallbackChunk)
                if ok and type(initTable) == "table" then
                    source, folder = fallbackSource, fallbackFolder
                    themeBasePath = fallbackBasePath
                else
                    dashboard.themeFallbackUsed[state] = true
                    dashboard.themeFallbackTime[state] = os.clock()
                    return nil
                end
            else
                dashboard.themeFallbackUsed[state] = true
                dashboard.themeFallbackTime[state] = os.clock()
                return nil
            end
        else
            dashboard.themeFallbackUsed[state] = true
            dashboard.themeFallbackTime[state] = os.clock()
            return nil
        end
    end

    local scriptName = initTable[state]
    if type(scriptName) ~= "string" or scriptName == "" then
        scriptName = state .. ".lua"
    end

    local script_path = themeBasePath .. folder .. "/" .. scriptName
    local chunk, err = rfsuite.compiler.loadfile(script_path)

    if not chunk then
        usedFallback = true
        local fallbackPath = themesBasePath .. dashboard.DEFAULT_THEME:match("[^/]+/(.+)") .. "/" .. scriptName
        chunk, err = rfsuite.compiler.loadfile(fallbackPath)
        if not chunk then
            rfsuite.utils.log("dashboard: Could not load " .. scriptName .. " for " .. tostring(folder) ..
                              " or default. Error: " .. tostring(err), "info")
            dashboard.themeFallbackUsed[state] = true
            dashboard.themeFallbackTime[state] = os.clock()
            return nil
        end
    end

    if usedFallback then
        dashboard.themeFallbackUsed[state] = true
        dashboard.themeFallbackTime[state] = os.clock()
    else
        dashboard.themeFallbackUsed[state] = false
        dashboard.themeFallbackTime[state] = 0
    end

    setCurrentWidgetPath()  -- <<< IMPORTANT: Set the correct widget path

    if initTable.standalone then
        return chunk
    else
        local ok2, module = pcall(chunk)
        if not ok2 then
            rfsuite.utils.log("dashboard: Error running " .. scriptName .. ": " .. tostring(module), "error")
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


--- Reloads dashboard themes and updates related state modules and intervals.
-- This function performs the following steps:
-- 1. Resets the dashboard image cache.
-- 2. Loads state modules (`preflight`, `inflight`, `postflight`) using the selected or default themes.
-- 3. Attempts to load interval settings (`wakeup_interval`, `wakeup_interval_bg`, `paint_interval`)
--    from the `scheduler` table or function in any loaded state module.
-- 4. Collects all box objects from all loaded state modules and loads them into the dashboard.
-- 5. Resets the wakeup scheduler and clears the dashboard's box rectangles.
function dashboard.reload_themes(force)
    -- Clear any cached images
    dashboard.utils.resetImageCache()

    local theme_preflight = getThemeForState("preflight")
    local theme_inflight = getThemeForState("inflight")
    local theme_postflight = getThemeForState("postflight")

    if force then
        rfsuite.utils.log("Full theme reload requested", "info")
        loadedStateModules.preflight  = load_state_script(theme_preflight, "preflight")
    else
        if not loadedStateModules.preflight then
            loadedStateModules.preflight = load_state_script(theme_preflight, "preflight")
            rfsuite.utils.log("Reloading preflight module (was not yet loaded)", "info")
        else
            rfsuite.utils.log("Skipped reloading preflight (already loaded)", "info")
        end
    end

    loadedStateModules.inflight   = load_state_script(theme_inflight, "inflight")
    loadedStateModules.postflight = load_state_script(theme_postflight, "postflight")

    -- Try to pick up any custom scheduler intervals defined by the theme
    local function tryLoadIntervals()
        for _, mod in pairs(loadedStateModules) do
            if mod and mod.scheduler then
                local initTable = (type(mod.scheduler) == "function") and mod.scheduler() or mod.scheduler
                if type(initTable) == "table" then
                    loadedThemeIntervals.wakeup_interval    = initTable.wakeup_interval    or 0.25
                    loadedThemeIntervals.wakeup_interval_bg = initTable.wakeup_interval_bg
                    loadedThemeIntervals.paint_interval     = initTable.paint_interval     or 0.5
                    return
                end
            end
        end
    end
    tryLoadIntervals()

    -- Gather every box from all loaded states so we can preload their object modules
    local allBoxes = {}
    for _, mod in pairs(loadedStateModules) do
        if mod and mod.boxes then
            local boxes = type(mod.boxes) == "function" and mod.boxes() or mod.boxes
            for _, box in ipairs(boxes or {}) do
                table.insert(allBoxes, box)
            end
        end
    end

    -- Preload all object types used by these boxes
    dashboard.loadAllObjects(allBoxes)

    -- Reset scheduler & layout state so the hourglass & wakeup cycle restart cleanly
    wakeupScheduler             = 0
    dashboard.boxRects          = {}
    objectsThreadedWakeupCount  = 0
    objectWakeupIndex           = 1
    lastLoadedBoxCount          = 0
    lastBoxRectsCount           = 0
    objectWakeupsPerCycle       = nil

    -- Force an immediate repaint so the spinner appears right away
    lcd.invalidate()
end


--- Calls a state-specific function for the dashboard widget, handling fallbacks and errors.
-- @param funcName string: The name of the function to call (e.g., "paint").
-- @param widget table: The widget instance to pass to the state function.
-- @param paintFallback boolean: If true, displays an error if the function is not implemented for the current state.
-- @return any: The result of the called state function, the module (for "paint" layout), or nil if not applicable.
local function callStateFunc(funcName, widget, paintFallback)
    local state = dashboard.flightmode or "preflight"
    local module = loadedStateModules[state]

    if not rfsuite.tasks.active() then
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
           dashboard.utils.screenError(rfsuite.i18n.get("widgets.dashboard.unsupported_resolution"), true, 0.4)
        else
            dashboard.overlaymessage(0, 0, W, H , rfsuite.i18n.get("widgets.dashboard.unsupported_resolution"))
        end     
        return
    end


    -- on the *first* paint, immediately draw the spinner and bail out
    if firstWakeup then
        local W, H = lcd.getWindowSize()
        dashboard.loader(0, 0, W, H)
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

    local W, H = lcd.getWindowSize()

    -- Bail out if resolution is not supported:
    if not dashboard.utils.supportedResolution(W,H, supportedResolutions) then
        unsupportedResolution = true
        lcd.invalidate(widget)
        return
    else
        unsupportedResolution = false    
    end

    -- load only preflight theme on first wakeup for speed
    if firstWakeup then
        firstWakeup = false
        local theme = getThemeForState("preflight")
        rfsuite.utils.log("Initial loading of preflight theme: " .. theme, "info")
        loadedStateModules.preflight = load_state_script(theme, "preflight")
    end

    -- Background load inflight/postflight modules one at a time
    if statePreloadIndex <= #statePreloadQueue then
        local state = statePreloadQueue[statePreloadIndex]
        if not loadedStateModules[state] then
            local theme = getThemeForState(state)
            rfsuite.utils.log("Preloading dashboard state: " .. state .. " with theme: " .. theme, "info")
            loadedStateModules[state] = load_state_script(theme, state)
        end
        statePreloadIndex = statePreloadIndex + 1
    end

    -- catch scenario where mcu_id is found and we have to reload to model theme
    if firstWakeupCustomTheme and 
        rfsuite.session.mcu_id and 
        rfsuite.session.modelPreferences and 
        rfsuite.session.modelPreferences.dashboard then
            
        local modelPrefs = rfsuite.session.modelPreferences.dashboard
        local currentPrefs = rfsuite.preferences.dashboard
        
        -- The value of nil being in quotes is correct. This is a string comparison as it is sourced from the ini file.
        if (modelPrefs.theme_preflight   and modelPrefs.theme_preflight ~= "nil" and modelPrefs.theme_preflight  ~= currentPrefs.theme_preflight) or
            (modelPrefs.theme_inflight   and modelPrefs.theme_preflight ~= "nil" and  modelPrefs.theme_inflight   ~= currentPrefs.theme_inflight) or
            (modelPrefs.theme_postflight and modelPrefs.theme_preflight ~= "nil" and  modelPrefs.theme_postflight ~= currentPrefs.theme_postflight) then

            dashboard.reload_themes()
            firstWakeupCustomTheme = false
        end

    end


    local now = os.clock()
    local visible = lcd.isVisible() 

    -- These values must be assigned from your config/init table after loading!
    -- Example:
    -- loadedThemeIntervals.wakeup_interval      = initTable.wakeup_interval or 0.25
    -- loadedThemeIntervals.wakeup_interval_bg   = initTable.wakeup_interval_bg -- may be nil
    -- loadedThemeIntervals.paint_interval       = initTable.paint_interval or 0.5

    if visible then
    local base_interval = loadedThemeIntervals.wakeup_interval or 0.25
    local interval = base_interval

        -- if the base interval is < 0.5s and there are >10 boxes
        if base_interval < 0.5 and #dashboard.boxRects > 10 then
            interval = 0.5
        end   

        if (now - lastWakeup) < interval then
            return
        end
        lastWakeup = now
    else
        local interval_bg = loadedThemeIntervals.wakeup_interval_bg
        if interval_bg == nil then
            -- Not visible, and no background interval set: skip entirely
            return
        end
        if (now - lastWakeupBg) < interval_bg then
            return
        end
        lastWakeupBg = now
    end

    -- ==== Main wakeup logic starts here ====

    local currentFlightMode = rfsuite.session.flightMode or "preflight"
    if lastFlightMode ~= currentFlightMode then
        dashboard.flightmode = currentFlightMode
        reload_state_only(currentFlightMode)
        lastFlightMode = currentFlightMode
    end

    -- Periodically check for overlay message changes
    local newMessage = dashboard.computeOverlayMessage()
    if dashboard.overlayMessage ~= newMessage then
        dashboard.overlayMessage = newMessage
        lcd.invalidate(widget) -- Redraw only if message changed
    end

    local state = dashboard.flightmode or "preflight"
    local module = loadedStateModules[state]

    if type(module) == "table" and module.layout then
        lcd.invalidate(widget)
        if type(module.wakeup) == "function" then
            module.wakeup(widget)
        end
    else
        callStateFunc("wakeup", widget)
    end

    -- Spread-scheduled wakeup for dashboard objects
    if #dashboard.boxRects > 0 and objectWakeupsPerCycle then
        -- 1) Wake every “custom-scheduler” object (using precomputed indices)
        for _, idx in ipairs(scheduledBoxIndices) do
            local rect = dashboard.boxRects[idx]
            local obj  = dashboard.objectsByType[rect.box.type]
            if obj and obj.wakeup then
                obj.wakeup(rect.box, rfsuite.tasks.telemetry)
            end
        end

        for i = 1, objectWakeupsPerCycle do
            local idx = objectWakeupIndex
            local rect = dashboard.boxRects[idx]
            if rect then
                local obj = dashboard.objectsByType[rect.box.type]
                if obj and obj.wakeup and not obj.scheduler then
                    obj.wakeup(rect.box, rfsuite.tasks.telemetry)
                end
            end
            objectWakeupIndex = (#dashboard.boxRects > 0) and ((objectWakeupIndex % #dashboard.boxRects) + 1) or 1
        end

        if objectWakeupIndex == 1 then
            objectsThreadedWakeupCount = objectsThreadedWakeupCount + 1
        end
    end

    if not lcd.hasFocus(widget) and dashboard.selectedBoxIndex ~= nil then
        rfsuite.utils.log("Removing focus from box " .. tostring(dashboard.selectedBoxIndex), "info")
        dashboard.selectedBoxIndex = nil
        lcd.invalidate(widget)
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
            if folder ~= ".." and folder ~= "." then
                local themeDir = basePath .. folder .. "/"
                local initPath = themeDir .. "init.lua"
                if rfsuite.utils.dir_exists(basePath, folder) then
                    local chunk, err = rfsuite.compiler.loadfile(initPath)
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
    local basePath = "SCRIPTS:/" .. rfsuite.config.preferences
    if rfsuite.utils.dir_exists(basePath, 'dashboard') then
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
        return rfsuite.ini.getvalue(rfsuite.session.modelPreferences, rfsuite.session.dashboardEditingTheme, key)
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
        rfsuite.ini.setvalue(rfsuite.session.modelPreferences, rfsuite.session.dashboardEditingTheme, key, value)
        return rfsuite.ini.save_ini_file(rfsuite.session.modelPreferencesFile, rfsuite.session.modelPreferences)
    end
end

-- Ask user for confirmation before erasing dataflash
function dashboard.resetFlightModeAsk()

    local buttons = {{
        label = rfsuite.i18n.get("app.btn_ok"),
        action = function()

            -- we push this to the background task to do its job
            rfsuite.session.flightMode = "preflight"
            rfsuite.tasks.events.flightmode.reset()
            dashboard.reload_themes()
            reload_state_only("preflight")
            return true
        end
    }, {
        label = rfsuite.i18n.get("app.btn_cancel"),
        action = function()
            return true
        end
    }}

    form.openDialog({
        width = nil,
        title =  rfsuite.i18n.get("widgets.dashboard.reset_flight_ask_title"),
        message = rfsuite.i18n.get("widgets.dashboard.reset_flight_ask_text"),
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
        {rfsuite.i18n.get("widgets.dashboard.reset_flight"), dashboard.resetFlightModeAsk},
    }
end


return dashboard
