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

local themesBasePath = "SCRIPTS:/".. rfsuite.config.baseDir.. "/widgets/dashboard/themes/"
local themesUserPath = "SCRIPTS:/".. rfsuite.config.preferences.. "/dashboard/"
local loadedStateModules = {}
local loadedThemeIntervals = { wakeup = 0.5, wakeup_bg = 2 }
local wakeupScheduler = 0

dashboard.boxRects = {}  -- Will store {x, y, w, h, box} for each box
dashboard.selectedBoxIndex = 1 -- track the selected box index
dashboard.themeFallbackUsed = { preflight = false, inflight = false, postflight = false }
dashboard.themeFallbackTime = { preflight = 0, inflight = 0, postflight = 0 }

dashboard.flightmode = rfsuite.session.flightMode or "preflight" -- To be set by your state logic

dashboard.utils = assert(rfsuite.compiler.loadfile("SCRIPTS:/".. rfsuite.config.baseDir.. "/widgets/dashboard/utils.lua"))()

local function getOnpressBoxIndices()
    local indices = {}
    for i, rect in ipairs(dashboard.boxRects) do
        if rect.box.onpress then
            indices[#indices + 1] = i
        end
    end
    return indices
end

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

    local selectColor = (resolve(config.layout) and resolve(config.layout).selectcolor) or dashboard.utils.resolveColor("yellow") or lcd.RGB(255, 255, 0)
    local selectBorder = (resolve(config.layout) and resolve(config.layout).selectborder) or 2

    local WIDGET_W, WIDGET_H = lcd.getWindowSize()
    local COLS, ROWS = resolve(config.layout).cols, resolve(config.layout).rows
    local PADDING = resolve(config.layout).padding

    local contentWidth = WIDGET_W - ((COLS - 1) * PADDING)
    local contentHeight = WIDGET_H - ((ROWS + 1) * PADDING)

    local boxWidth = contentWidth / COLS
    local boxHeight = contentHeight / ROWS

    utils.setBackgroundColourBasedOnTheme()

    local function getBoxPosition(col, row)
        local x = math.floor((col - 1) * (boxWidth + PADDING))
        local y = math.floor(PADDING + (row - 1) * (boxHeight + PADDING))
        return x, y
    end

    for i, box in ipairs(resolve(config.boxes) or {}) do
        local x, y = getBoxPosition(box.col, box.row)
        local w = math.floor((box.colspan or 1) * boxWidth + ((box.colspan or 1) - 1) * PADDING)
        local h = math.floor((box.rowspan or 1) * boxHeight + ((box.rowspan or 1) - 1) * PADDING)

        dashboard.boxRects[#dashboard.boxRects + 1] = {x = x, y = y, w = w, h = h, box = box}

        if box.type == "telemetry" then
            local value = nil
            if box.source then
                local sensor = telemetry and telemetry.getSensorSource(box.source)
                value = sensor and sensor:value()
                if type(box.transform) == "string" and math[box.transform] then
                    value = value and math[box.transform](value)
                elseif type(box.transform) == "function" then
                    value = value and box.transform(value)
                elseif type(box.transform) == "number" then
                    value = value and box.transform(value)
                end
            end
            local displayValue = value
            local displayUnit = box.unit

            if value == nil then
                displayValue = box.novalue or "-"
                displayUnit = nil
            end

            utils.telemetryBox(
                x, y, w, h,
                box.color, box.title, displayValue, displayUnit, box.bgcolor,
                box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
                box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
                box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
            )
        elseif box.type == "text" then

            local displayValue = box.value
            local displayUnit = ""


            utils.telemetryBox(
                x, y, w, h,
                box.color, box.title, displayValue, displayUnit, box.bgcolor,
                box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
                box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
                box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
            )
        elseif box.type == "image" then
            utils.imageBox(
                x, y, w, h,
                box.color, box.title,
                box.value or box.source or "widgets/dashboard/default_image.png",
                box.imagewidth, box.imageheight, box.imagealign,
                box.bgcolor, box.titlealign, box.titlecolor, box.titlepos,
                box.imagepadding, box.imagepaddingleft, box.imagepaddingright, box.imagepaddingtop, box.imagepaddingbottom
            )
        elseif box.type == "modelimage" then
            utils.modelImageBox(
                x, y, w, h,
                box.color, box.title,
                box.imagewidth, box.imageheight, box.imagealign,
                box.bgcolor, box.titlealign, box.titlecolor, box.titlepos,
                box.imagepadding, box.imagepaddingleft, box.imagepaddingright, box.imagepaddingtop, box.imagepaddingbottom
            )
        elseif box.type == "governor" then
            local value = nil
            local sensor = telemetry and telemetry.getSensorSource("governor")
            value = sensor and sensor:value()
            local displayValue = rfsuite.utils.getGovernorState(value)
            if displayValue == nil then
                displayValue = box.novalue or "-"
            end

            utils.telemetryBox(
                x, y, w, h,
                box.color, box.title, displayValue, box.unit, box.bgcolor,
                box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
                box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
                box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
            )
        elseif box.type == "craftname" then
            local displayValue = rfsuite.session.craftName
            if displayValue == nil or (type(displayValue) == "string" and displayValue:match("^%s*$")) then
                displayValue = box.novalue or "-"
            end

            utils.telemetryBox(
                x, y, w, h,
                box.color, box.title, displayValue, box.unit, box.bgcolor,
                box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
                box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
                box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
            )
        elseif box.type == "apiversion" then
            local displayValue = rfsuite.session.apiVersion
            if displayValue == nil then
                displayValue = box.novalue or "-"
            end

            utils.telemetryBox(
                x, y, w, h,
                box.color, box.title, displayValue, box.unit, box.bgcolor,
                box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
                box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
                box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
            )
        elseif box.type == "session" then
            local displayValue = rfsuite.session[box.source]
            if displayValue == nil then
                displayValue = box.novalue or "-"
            end

            utils.telemetryBox(
                x, y, w, h,
                box.color, box.title, displayValue, box.unit, box.bgcolor,
                box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
                box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
                box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
            )   
        elseif box.type == "blackbox" then

            local displayValue = nil
            local totalSize = rfsuite.session.bblSize 
            local usedSize = rfsuite.session.bblUsed

            if totalSize and usedSize then
                displayValue= string.format("%.1f/%.1f " .. rfsuite.i18n.get("app.modules.status.megabyte"),
                usedSize / (1024 * 1024),
                totalSize / (1024 * 1024))
            end    

            if displayValue == nil then
                displayValue = box.novalue or "-"
            end

            utils.telemetryBox(
                x, y, w, h,
                box.color, box.title, displayValue, box.unit, box.bgcolor,
                box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
                box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
                box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
            )                                  
        elseif box.type == "function" then
            if box.value and type(box.value) == "function" then
                box.value(x, y, w, h)
            end  
        end  

        -- Is this the selected onpress-enabled box?
        if dashboard.selectedBoxIndex == i and box.onpress then
            lcd.color(selectColor)
            lcd.drawRectangle(x, y, w, h, selectBorder)
        end


    end

    -- display overlay error message if any
    local apiVersionAsString = tostring(rfsuite.session.apiVersion)
    local moduleState = (model.getModule(0):enable()  or model.getModule(1):enable()) or false
    local sportSensor = system.getSource({appId = 0xF101})
    local elrsSensor = system.getSource({crsfId=0x14, subIdStart=0, subIdEnd=1})
    local overlayMessage = nil

    -- Check for fallback theme message FIRST, and display for 20 seconds max
    local state = dashboard.flightmode or "preflight"
    if dashboard.themeFallbackUsed and dashboard.themeFallbackUsed[state] and
        (os.clock() - (dashboard.themeFallbackTime and dashboard.themeFallbackTime[state] or 0)) < 10 then
        overlayMessage = rfsuite.i18n.get("widgets.dashboard.theme_load_error")
    elseif not rfsuite.utils.ethosVersionAtLeast() then
        overlayMessage = string.format(string.upper(rfsuite.i18n.get("ethos")).. " < V%d.%d.%d",
            rfsuite.config.ethosVersion[1],
            rfsuite.config.ethosVersion[2],
            rfsuite.config.ethosVersion[3])
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
            -- Fallback to utils if no screenErrorOverlay function is defined
            utils.screenErrorOverlay(overlayMessage)
        end
    end 

end

local function load_state_script(theme_folder, state)
    local usedFallback = false

    -- theme_folder is now "system/foo" or "user/bar"
    local source, folder = theme_folder:match("([^/]+)/(.+)")
    local themeBasePath = (source == "user") and themesUserPath or themesBasePath

    -- Handle mangled or empty paths (fallback immediately)
    if not source or not folder then
        theme_folder = dashboard.DEFAULT_THEME
        source, folder = theme_folder:match("([^/]+)/(.+)")
        themeBasePath = (source == "user") and themesUserPath or themesBasePath
        usedFallback = true
    end

    -- 1) Try to load init.lua from selected theme, else fallback to default
    local initPath = themeBasePath .. folder .. "/init.lua"
    local initChunk, initErr = rfsuite.compiler.loadfile(initPath)

    if not initChunk then
        usedFallback = true
        local fallbackSource, fallbackFolder = dashboard.DEFAULT_THEME:match("([^/]+)/(.+)")
        local fallbackBasePath = (fallbackSource == "user") and themesUserPath or themesBasePath
        local fallbackInitPath = fallbackBasePath .. fallbackFolder .. "/init.lua"
        rfsuite.utils.log(
            "dashboard: Could not load init.lua for " .. tostring(folder) ..
            ". Falling back to default. Error: " .. tostring(initErr),
            "info"
        )
        initChunk, initErr = rfsuite.compiler.loadfile(fallbackInitPath)
        if not initChunk then
            rfsuite.utils.log(
                "dashboard: Could not load default theme's init.lua. Error: " .. tostring(initErr),
                "error"
            )
            dashboard.themeFallbackUsed[state] = true
            dashboard.themeFallbackTime[state] = os.clock()
            return nil
        end
        folder = fallbackFolder
        themeBasePath = fallbackBasePath
    end

    local ok, initTable = pcall(initChunk)
    if not ok or type(initTable) ~= "table" then
        rfsuite.utils.log(
            "dashboard: Error running init.lua for " .. tostring(folder) ..
            ": " .. tostring(initTable) .. ". Falling back to default.",
            "error"
        )
        -- Try default theme's init.lua as a last resort
        if theme_folder ~= dashboard.DEFAULT_THEME then
            usedFallback = true
            local fallbackSource, fallbackFolder = dashboard.DEFAULT_THEME:match("([^/]+)/(.+)")
            local fallbackBasePath = (fallbackSource == "user") and themesUserPath or themesBasePath
            local fallbackInitPath = fallbackBasePath .. fallbackFolder .. "/init.lua"
            local fallbackChunk, fallbackErr = rfsuite.compiler.loadfile(fallbackInitPath)
            if fallbackChunk then
                ok, initTable = pcall(fallbackChunk)
                if ok and type(initTable) == "table" then
                    folder = fallbackFolder
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

    -- 2) Pick the file name from init (e.g. initTable.preflight == "status.lua")
    local scriptName = initTable[state]
    if type(scriptName) ~= "string" or scriptName == "" then
        scriptName = state .. ".lua"
    end

    -- 3) Try loading that file
    local script_path = themeBasePath .. folder .. "/" .. scriptName
    local chunk, err = rfsuite.compiler.loadfile(script_path)

    -- 4) If it fails, fall back to default theme (using the same scriptName)
    if not chunk then
        usedFallback = true
        local fallbackPath = themesBasePath .. dashboard.DEFAULT_THEME:match("[^/]+/(.+)") .. "/" .. scriptName
        chunk, err = rfsuite.compiler.loadfile(fallbackPath)
        if not chunk then
            rfsuite.utils.log(
                "dashboard: Could not load " .. scriptName ..
                " for " .. tostring(folder) .. " or default. Error: " .. tostring(err),
                "info"
            )
            dashboard.themeFallbackUsed[state] = true
            dashboard.themeFallbackTime[state] = os.clock()
            return nil
        end
    end

    -- Set fallback flag/timer if any fallback happened
    if usedFallback then
        dashboard.themeFallbackUsed[state] = true
        dashboard.themeFallbackTime[state] = os.clock()
    else
        dashboard.themeFallbackUsed[state] = false
        dashboard.themeFallbackTime[state] = 0
    end

    -- 5) Run it and return the module
    if initTable.standalone then
        return chunk  -- theme takes full control
    else
        local ok2, module = pcall(chunk)
        if not ok2 then
            rfsuite.utils.log(
                "dashboard: Error running " .. scriptName .. ": " .. tostring(module),
                "error"
            )
            dashboard.themeFallbackUsed[state] = true
            dashboard.themeFallbackTime[state] = os.clock()
            return nil
        end
        return module
    end
end


function dashboard.reload_themes()
    dashboard.utils.resetImageCache()  -- clear cached images
    loadedStateModules = {
        preflight  = load_state_script(rfsuite.preferences.dashboard.theme_preflight  or dashboard.DEFAULT_THEME, "preflight"),
        inflight   = load_state_script(rfsuite.preferences.dashboard.theme_inflight    or dashboard.DEFAULT_THEME, "inflight"),
        postflight = load_state_script(rfsuite.preferences.dashboard.theme_postflight  or dashboard.DEFAULT_THEME, "postflight"),
    }
    wakeupScheduler = 0
end

dashboard.reload_themes()

local function callStateFunc(funcName, widget, paintFallback)
    local state = dashboard.flightmode or "preflight"
    local module = loadedStateModules[state]

    if not rfsuite.tasks.active() then
        return nil
    end

    -- Declarative module: directly a layout table
    if type(module) == "table" and module.layout and funcName == "paint" then
        return module  -- Let `dashboard.paint()` handle rendering
    end

    -- Traditional function-based module
    if module and type(module[funcName]) == "function" then
        return module[funcName](widget)
    end

    if paintFallback then
        local msg = "dashboard: " .. funcName .. " not implemented for " .. state .. "."
        dashboard.utils.screenError(msg)
    end
end


function dashboard.create(widget)
    return callStateFunc("create", widget)
end

function dashboard.paint(widget)
    local state = dashboard.flightmode or "preflight"
    local module = loadedStateModules[state]

    if type(module) == "table" and module.layout and module.boxes then
        -- Normal layout rendering
        dashboard.renderLayout(widget, module)
        -- Custom overlay if present
        if type(module.paint) == "function" then
            module.paint(widget, module.layout, module.boxes)
        end
    else
        -- legacy fallback, etc.
        callStateFunc("paint", widget)
    end
end

function dashboard.configure(widget)
    return callStateFunc("configure", widget) or widget
end

function dashboard.read(widget)
    return callStateFunc("read", widget)
end

function dashboard.write(widget)
    return callStateFunc("write", widget)
end

function dashboard.build(widget)
    return callStateFunc("build", widget)
end

function dashboard.event(widget, category, value, x, y)

    -- Handle keypad/rotary
    if category == EVT_KEY then
        local indices = getOnpressBoxIndices()
        local count = #indices
        if count == 0 then return end

        local current = dashboard.selectedBoxIndex or 1
        -- Find current index position in the onpress-only array:
        local pos = 1
        for i, idx in ipairs(indices) do
            if idx == current then pos = i break end
        end

        if value == 4099 then -- rotary left
            pos = pos - 1
            if pos < 1 then pos = count end
            dashboard.selectedBoxIndex = indices[pos]
            lcd.invalidate(widget) -- Force redraw
            return true
        elseif value == 4100 then -- rotary right
            pos = pos + 1
            if pos > count then pos = 1 end
            dashboard.selectedBoxIndex = indices[pos]
            lcd.invalidate(widget) -- Force redraw
            return true
        elseif value == 33 and category == EVT_KEY then 
            local inIndices = false
            for i=1, #indices do
                if indices[i] == dashboard.selectedBoxIndex then inIndices = true break end
            end

            if not inIndices then
                -- No highlight or highlight is not valid: set it
                dashboard.selectedBoxIndex = indices[1]
                lcd.invalidate(widget)
                return true
            else
                -- Valid highlight: trigger onpress
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



    -- Handle EXIT key (category 0, value 35)
    if value == 35 then
        dashboard.selectedBoxIndex = nil
        lcd.invalidate(widget)
        return true
    end

    -- Touch handling (already present)
    if category == 1 and value == 16641 and lcd.hasFocus() then
        if x and y then
            for i, rect in ipairs(dashboard.boxRects) do
                if x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h then
                    if rect.box.onpress then
                        dashboard.selectedBoxIndex = i  -- Shift highlight focus!
                        lcd.invalidate(widget)
                        rect.box.onpress(widget, rect.box, x, y, category, value)
                        system.killEvents(16640)
                        return true
                    end
                    -- fallback etc.
                end
            end
        end
    end    

    -- fallback to theme event
    local state = dashboard.flightmode or "preflight"
    local module = loadedStateModules[state]
    if type(module) == "table" and type(module.event) == "function" then
        return module.event(widget, category, value, x, y)
    end
end


function dashboard.wakeup(widget)
    local now = os.clock()
    local visible = lcd.isVisible and lcd.isVisible() or true
    local interval = visible and loadedThemeIntervals.wakeup or loadedThemeIntervals.wakeup_bg

    -- Check if flightMode changed, and reload themes if needed
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
            -- Declarative layout → force redraw
            lcd.invalidate(widget)
            -- If module has a wakeup function, run it
            if type(module.wakeup) == "function" then
                module.wakeup(widget)
            end
        else
            return callStateFunc("wakeup", widget)
        end
    end

    -- Handle removing highlighted box if no focus
    if not lcd.hasFocus(widget) and dashboard.selectedBoxIndex ~= nil then
        rfsuite.utils.log("Removing focus from box " .. tostring(dashboard.selectedBoxIndex), "info")
        dashboard.selectedBoxIndex = nil
        lcd.invalidate(widget)
    end

end

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
                            -- Only show dev themes if devmode is enabled
                            if not initTable.developer or rfsuite.preferences.developer.devtools == true then
                                num = num + 1
                                themes[num] = {
                                    name = initTable.name,
                                    folder = folder,
                                    idx = num,
                                    source = sourceType, -- 'system' or 'user'
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    -- Scan system themes
    scanThemes(themesBasePath, "system")

    -- Scan user themes if path exists
    local basePath = "SCRIPTS:/".. rfsuite.config.preferences
    if rfsuite.utils.dir_exists(basePath, 'dashboard') then
        scanThemes(themesUserPath, "user")
    end

    return themes
end



return dashboard

