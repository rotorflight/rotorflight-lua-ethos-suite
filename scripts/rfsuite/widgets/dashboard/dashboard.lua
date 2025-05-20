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



dashboard.DEFAULT_THEME = "default" -- fallback

local themesBasePath = "SCRIPTS:/".. rfsuite.config.baseDir.. "/widgets/dashboard/themes/"
local loadedStateModules = {}
local loadedThemeIntervals = { wakeup = 0.5, wakeup_bg = 2 }
local wakeupScheduler = 0

dashboard.flightmode = rfsuite.session.flightMode or "preflight" -- To be set by your state logic

dashboard.utils = assert(rfsuite.compiler.loadfile("SCRIPTS:/".. rfsuite.config.baseDir.. "/widgets/dashboard/utils.lua"))()

local function load_state_script(theme_folder, state)
    -- 1) Load init.lua so we can read the init table
    local initPath  = themesBasePath .. theme_folder .. "/init.lua"
    local initChunk, initErr = rfsuite.compiler.loadfile(initPath)
    if not initChunk then
        rfsuite.utils.log(
          "dashboard: Could not load init.lua for " .. theme_folder ..
          ". Error: " .. tostring(initErr),
          "error"
        )
        return nil
    end

    local ok, initTable = pcall(initChunk)
    if not ok or type(initTable) ~= "table" then
        rfsuite.utils.log(
          "dashboard: Error running init.lua for " .. theme_folder ..
          ": " .. tostring(initTable),
          "error"
        )
        return nil
    end

    -- 2) Pick the file name from init (e.g. initTable.preflight == "status.lua")
    local scriptName = initTable[state]
    if type(scriptName) ~= "string" or scriptName == "" then
        scriptName = state .. ".lua"
    end

    -- 3) Try loading that file
    local script_path = themesBasePath .. theme_folder .. "/" .. scriptName
    local chunk, err = rfsuite.compiler.loadfile(script_path)

    -- 4) If it fails, fall back to default theme (using the same scriptName)
    if not chunk then
        local fallbackPath = themesBasePath .. dashboard.DEFAULT_THEME .. "/" .. scriptName
        chunk, err = rfsuite.compiler.loadfile(fallbackPath)
        if not chunk then
            rfsuite.utils.log(
              "dashboard: Could not load " .. scriptName ..
              " for " .. theme_folder .. " or default. Error: " .. tostring(err),
              "error"
            )
            return nil
        end
    end

    -- 5) Run it and return the module
    local ok2, module = pcall(chunk)
    if not ok2 then
        rfsuite.utils.log(
          "dashboard: Error running " .. scriptName .. ": " .. tostring(module),
          "error"
        )
        return nil
    end

    return module
end


function dashboard.reload_themes()
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
    elseif module and type(module[funcName]) == "function" then
        return module[funcName](widget)
    else
        local msg = "dashboard: " .. funcName .. " not implemented for " .. state .. "."
        --rfsuite.utils.log(msg, "info")
        if paintFallback then
            dashboard.utils.screenError(msg)
        end
    end
end

function dashboard.create(widget)
    return callStateFunc("create", widget)
end

function dashboard.paint(widget)
    return callStateFunc("paint", widget, true)
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

function dashboard.event(widget)
    return callStateFunc("event", widget)
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
        return callStateFunc("wakeup", widget)
    end
end

function dashboard.listThemes()
    local themes = {}
    local folders = system.listFiles(themesBasePath)
    if not folders then return themes end
    local num = 0
    for _, folder in ipairs(folders) do
        if folder ~= ".." and folder ~= "." then
            local themeDir = themesBasePath .. folder .. "/"
            local initPath = themeDir .. "init.lua"
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

