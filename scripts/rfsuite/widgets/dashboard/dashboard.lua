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

local ACTIVE_THEME = "status_eol"
local themesBasePath = "SCRIPTS:/".. rfsuite.config.baseDir.. "/widgets/dashboard/themes/"
local loadedThemeModule = nil
local loadedThemeIntervals = { wakeup = 0.5, wakeup_bg = 2 } -- defaults
local wakeupScheduler = 0
local loadError = nil
local loadErrorMessage = nil

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

local function load_theme()
    local themeDir = themesBasePath .. ACTIVE_THEME .. "/"
    if not rfsuite.utils.dir_exists(themesBasePath, ACTIVE_THEME) then
        loadErrorMessage = "Theme directory not found: " .. themeDir
        return nil
    end

    local initPath = themeDir .. "init.lua"
    local chunk, err = rfsuite.compiler.loadfile(initPath)
    if not chunk then
        loadErrorMessage = "Error loading theme init.lua: " .. err
        return nil
    end

    local initTable = chunk()
    if not initTable or not initTable.script then
        loadErrorMessage  = "No script specified in theme init.lua"
        return nil
    end

    -- Load wakeup intervals (NEW LOGIC)
    loadedThemeIntervals.wakeup = tonumber(initTable.wakeup) or 0.5
    loadedThemeIntervals.wakeup_bg = tonumber(initTable.wakeup_bg) or 2

    local scriptPath = themeDir .. initTable.script
    local scriptChunk, scriptErr = rfsuite.compiler.loadfile(scriptPath)
    if not scriptChunk then
        loadErrorMessage = "Error loading theme script: " .. scriptErr
        return nil
    end

    return scriptChunk()
end

-- Call this at startup or after changing ACTIVE_THEME
function dashboard.reload_theme()
    loadedThemeModule = load_theme()
    wakeupScheduler = 0 -- reset scheduler when reloading theme
end

-- Initial theme load
dashboard.reload_theme()

function dashboard.create(widget)
    if loadedThemeModule and loadedThemeModule.create then
        return loadedThemeModule.create(widget)
    end
end

function dashboard.paint(widget)
    if loadedThemeModule and loadedThemeModule.paint then
        return loadedThemeModule.paint(widget)
    else
        screenError(loadErrorMessage)    
    end
end

function dashboard.configure(widget)

    if loadedThemeModule and loadedThemeModule.configure then
        return loadedThemeModule.configure(widget)
    end
    return widget
end

function dashboard.read(widget)
    if loadedThemeModule and loadedThemeModule.read then
        return loadedThemeModule.read(widget)
    end
end

function dashboard.write(widget)
    if loadedThemeModule and loadedThemeModule.write then
        return loadedThemeModule.write(widget)
    end
end

function dashboard.event(widget)
    if loadedThemeModule and loadedThemeModule.create then
        return loadedThemeModule.event(widget)
    end
end

function dashboard.wakeup(widget)
    local now = os.clock()
    local visible = lcd.isVisible and lcd.isVisible() or true -- fallback if function not available
    local interval = visible and loadedThemeIntervals.wakeup or loadedThemeIntervals.wakeup_bg

    if (now - wakeupScheduler) >= interval then
        wakeupScheduler = now
        if loadedThemeModule and loadedThemeModule.wakeup then
            return loadedThemeModule.wakeup(widget)
        end
    end
    -- Optionally, force screen redraw if needed when in error
    if not loadedThemeModule then
        lcd.invalidate()
    end
end

function dashboard.listThemes()
    local themes = {}
    local folders = system.listFiles(themesBasePath)
    if not folders then
        return themes
    end

    local num = 0
    for _, folder in ipairs(folders) do
        if folder ~= ".." and folder ~= "." then
            local themeDir = themesBasePath .. folder .. "/"
            local initPath = themeDir .. "init.lua"
            -- Check if the theme folder and init.lua exist
            if rfsuite.utils.dir_exists(themesBasePath, folder) then
                local chunk, err = rfsuite.compiler.loadfile(initPath)
                if chunk then
                    local ok, initTable = pcall(chunk)
                    if ok and initTable and type(initTable.name) == "string" then
                        num = num + 1
                        themes[num] = {
                            name=initTable.name,
                            folder=folder,
                            idx = num
                        }
                    end
                end
            end
        end
    end

    return themes
end


return dashboard
