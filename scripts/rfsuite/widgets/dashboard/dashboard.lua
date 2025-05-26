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

local dashboard = {}
local lastFlightMode = nil
local initTime = os.clock()

dashboard.DEFAULT_THEME = "system/default" -- fallback

local themesBasePath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/themes/"
local themesUserPath = "SCRIPTS:/" .. rfsuite.config.preferences .. "/dashboard/"
local loadedStateModules = {}
local loadedThemeIntervals = { wakeup = 0.5, wakeup_bg = 2 }
local wakeupScheduler = 0

dashboard.boxRects = {}  -- Will store {x, y, w, h, box} for each box
dashboard.selectedBoxIndex = 1 -- track the selected box index
dashboard.themeFallbackUsed = { preflight = false, inflight = false, postflight = false }
dashboard.themeFallbackTime = { preflight = 0, inflight = 0, postflight = 0 }
dashboard.flightmode = rfsuite.session.flightMode or "preflight" -- To be set by your state logic

dashboard.currentWidgetPath = nil 

dashboard.utils = assert(
    rfsuite.compiler.loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/lib/utils.lua")
)()
dashboard.render = assert(
    rfsuite.compiler.loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/lib/render.lua")
)()

--[[ 
    Returns a list of indices of boxes that have an `onpress` handler.
]]
local function getOnpressBoxIndices()
    local indices = {}
    for i, rect in ipairs(dashboard.boxRects) do
        if rect.box.onpress then
            indices[#indices + 1] = i
        end
    end
    return indices
end

--[[ 
    Renders an overlay message if there are any dashboard, theme, or telemetry errors.
    Chooses the right overlay function depending on the module.
]]
local function renderOverlayMessage(module, utils)
    local apiVersionAsString = tostring(rfsuite.session.apiVersion)
    local moduleState = (model.getModule(0):enable() or model.getModule(1):enable()) or false
    local sportSensor = system.getSource({appId = 0xF101})
    local elrsSensor = system.getSource({crsfId = 0x14, subIdStart = 0, subIdEnd = 1})
    local overlayMessage = nil

    local state = dashboard.flightmode or "preflight"
    if dashboard.themeFallbackUsed and dashboard.themeFallbackUsed[state] and
       (os.clock() - (dashboard.themeFallbackTime and dashboard.themeFallbackTime[state] or 0)) < 10 then
        overlayMessage = rfsuite.i18n.get("widgets.dashboard.theme_load_error")
    elseif not rfsuite.utils.ethosVersionAtLeast() then
        overlayMessage = string.format(
            string.upper(rfsuite.i18n.get("ethos")) .. " < V%d.%d.%d",
            rfsuite.config.ethosVersion[1],
            rfsuite.config.ethosVersion[2],
            rfsuite.config.ethosVersion[3]
        )
    elseif not rfsuite.tasks.active() then
        overlayMessage = rfsuite.i18n.get("app.check_bg_task")
    elseif moduleState == false then
        overlayMessage = rfsuite.i18n.get("app.check_rf_module_on")
    elseif not (sportSensor or elrsSensor) then
        overlayMessage = rfsuite.i18n.get("app.check_discovered_sensors")
    elseif rfsuite.session.telemetryState and rfsuite.tasks.telemetry and not rfsuite.tasks.telemetry.validateSensors() then
        overlayMessage = rfsuite.i18n.get("widgets.dashboard.validate_sensors")
    end

    if overlayMessage then
        if module and module.overlayMessage then
            module.screenErrorOverlay(overlayMessage)
        else
            utils.screenErrorOverlay(overlayMessage)
        end
    end
end

--[[ 
    Renders the main dashboard layout, drawing all boxes and handling highlights.
    Called automatically by paint().
]]
function dashboard.renderLayout(widget, config)
    dashboard.boxRects = {} -- clear previous box rectangles

    local function resolve(val, ...)
        if type(val) == "function" then
            return val(...)
        else
            return val
        end
    end

    local telemetry = rfsuite.tasks.telemetry
    local utils = dashboard.utils
    local state = dashboard.flightmode or "preflight"
    local module = loadedStateModules[state]

    local selectColor = (resolve(config.layout) and resolve(config.layout).selectcolor) or
        dashboard.utils.resolveColor("yellow") or lcd.RGB(255, 255, 0)
    local selectBorder = (resolve(config.layout) and resolve(config.layout).selectborder) or 2

    local WIDGET_W, WIDGET_H = lcd.getWindowSize()
    local COLS, ROWS = resolve(config.layout).cols, resolve(config.layout).rows
    local PADDING = resolve(config.layout).padding

    local contentWidth = WIDGET_W - ((COLS - 1) * PADDING)
    local contentHeight = WIDGET_H - ((ROWS + 1) * PADDING)

    local boxWidth = contentWidth / COLS
    local boxHeight = contentHeight / ROWS

    utils.setBackgroundColourBasedOnTheme()

    -- Helper to get box width/height (percent, pixel, or grid)
    local function getBoxSize(box)
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

    -- Helper to get box position (percent, pixel, or grid)
    local function getBoxPosition(box, w, h)
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
            local x = math.floor((col - 1) * (boxWidth + PADDING))
            local y = math.floor(PADDING + (row - 1) * (boxHeight + PADDING))
            return x, y
        else
            return 0, 0
        end
    end

    for i, box in ipairs(resolve(config.boxes) or {}) do
        local w, h = getBoxSize(box)
        local x, y = getBoxPosition(box, w, h)

        dashboard.boxRects[#dashboard.boxRects + 1] = { x = x, y = y, w = w, h = h, box = box }
        dashboard.render.object(box.type, x, y, w, h, box, telemetry)

        if dashboard.selectedBoxIndex == i and box.onpress then
            lcd.color(selectColor)
            lcd.drawRectangle(x, y, w, h, selectBorder)
        end
    end

    renderOverlayMessage(module, utils)
end

--[[
    Loads the Lua state module for the specified theme and state.
    Handles fallback logic and logs any failures.
    Returns the loaded module, or nil on failure.
]]
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


--[[
    Reloads all dashboard state modules for each flight mode.
    Also resets theme fallback flags and the image cache.
]]
function dashboard.reload_themes()
    dashboard.utils.resetImageCache()
    loadedStateModules = {
        preflight  = load_state_script(rfsuite.preferences.dashboard.theme_preflight  or dashboard.DEFAULT_THEME, "preflight"),
        inflight   = load_state_script(rfsuite.preferences.dashboard.theme_inflight    or dashboard.DEFAULT_THEME, "inflight"),
        postflight = load_state_script(rfsuite.preferences.dashboard.theme_postflight  or dashboard.DEFAULT_THEME, "postflight"),
    }
    wakeupScheduler = 0
end

dashboard.reload_themes()

--[[
    Helper: Calls the named function for the current state module, if available.
    Used to delegate widget lifecycle calls.
]]
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

--[[
    Creates the widget using the state module's `create` method, if present.
]]
function dashboard.create(widget)
    return callStateFunc("create", widget)
end

--[[
    Main paint/draw function for the dashboard.
    Uses either a table-based layout or falls back to the state's paint method.
]]
function dashboard.paint(widget)
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

--[[
    Calls the state's configure method, or returns the widget as is.
]]
function dashboard.configure(widget)
    return callStateFunc("configure", widget) or widget
end

--[[
    Calls the state's read method, if available.
]]
function dashboard.read(widget)
    return callStateFunc("read", widget)
end

--[[
    Calls the state's write method, if available.
]]
function dashboard.write(widget)
    return callStateFunc("write", widget)
end

--[[
    Calls the state's build method, if available.
]]
function dashboard.build(widget)
    return callStateFunc("build", widget)
end

--[[
    Handles all user input events (key, rotary, touch).
    Manages box selection and onpress handlers, then delegates to theme if present.
]]
function dashboard.event(widget, category, value, x, y)

    local state = dashboard.flightmode or "preflight"
    local module = loadedStateModules[state]

    if state == "postflight" and category == EVT_KEY and value == 131 then
        rfsuite.widgets.dashboard.flightmode = "preflight"
        state = "preflight"
    end

    if category == EVT_KEY then
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

    if value == 35 then -- EXIT key
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

--[[
    Called periodically; manages redraw intervals, reloads themes if flightmode changes,
    and clears highlight when widget loses focus.
]]
function dashboard.wakeup(widget)
    local now = os.clock()
    local visible = lcd.isVisible and lcd.isVisible() or true
    local interval = visible and loadedThemeIntervals.wakeup or loadedThemeIntervals.wakeup_bg

    local currentFlightMode = rfsuite.session.flightMode or "preflight"
    if lastFlightMode ~= currentFlightMode then
        dashboard.flightmode = currentFlightMode
        dashboard.reload_themes()
        lastFlightMode = currentFlightMode
    end

    if (now - wakeupScheduler) >= interval then
        wakeupScheduler = now

        local state = dashboard.flightmode or "preflight"
        local module = loadedStateModules[state]

        if type(module) == "table" and module.layout then
            lcd.invalidate(widget)
            if type(module.wakeup) == "function" then
                module.wakeup(widget)
            end
        else
            return callStateFunc("wakeup", widget)
        end
    end

    if not lcd.hasFocus(widget) and dashboard.selectedBoxIndex ~= nil then
        rfsuite.utils.log("Removing focus from box " .. tostring(dashboard.selectedBoxIndex), "info")
        dashboard.selectedBoxIndex = nil
        lcd.invalidate(widget)
    end
end

--[[
    Scans and lists available system and user dashboard themes.
    Returns a table of {name, folder, idx, source}.
]]
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

function dashboard.getPreference(key)
    if not rfsuite.session.modelPreferences or not dashboard.currentWidgetPath then return nil end

    if not rfsuite.app.guiIsRunning then
        return rfsuite.ini.getvalue(rfsuite.session.modelPreferences, dashboard.currentWidgetPath, key)
    else
        return rfsuite.ini.getvalue(rfsuite.session.modelPreferences, rfsuite.session.dashboardEditingTheme, key)
    end
end

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

return dashboard
