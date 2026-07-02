--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local utils = rfsuite.utils

local function listThemes()
    local themes = {}
    local num = 0
    if not utils then return themes end

    local baseDir = rfsuite.config.baseDir
    local preferences = rfsuite.config.preferences
    local themesBasePath = "SCRIPTS:/" .. baseDir .. "/widgets/dashboard/themes/"
    local themesUserPath = "SCRIPTS:/" .. preferences .. "/dashboard/"

    local function scanThemes(basePath, sourceType)
        if not basePath or basePath == "" then return end
        local folders = system.listFiles(basePath)
        if not folders then return end

        for _, folder in ipairs(folders) do
            if folder ~= ".." and folder ~= "." and not folder:match("%.%a+$") then
                if utils.dir_exists(basePath, folder) then
                    local themeDir = basePath .. folder .. "/"
                    local initPath = themeDir .. "init.lua"

                    local chunk = loadfile(initPath)
                    if chunk then
                        local ok, initTable = pcall(chunk)
                        if ok and initTable and type(initTable.name) == "string" then
                            num = num + 1
                            themes[num] = {
                                name = initTable.name,
                                configure = initTable.configure,
                                folder = folder,
                                idx = num,
                                source = sourceType,
                                minResolution = initTable.minResolution
                            }
                        end
                    end
                end
            end
        end
    end

    scanThemes(themesBasePath, "system")
    local basePath = "SCRIPTS:/" .. preferences .. "/"
    if utils.dir_exists(basePath, "dashboard") then
        scanThemes(themesUserPath, "user")
    end

    return themes
end

return { listThemes = listThemes }
