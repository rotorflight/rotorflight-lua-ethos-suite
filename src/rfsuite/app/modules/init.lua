--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local pages = {}
-- Manifest is the single source of truth for menu structure.
local manifest = loadfile("app/modules/manifest.lua")()
local sections = {}
local missingModules = {}

local function isTruthy(value)
    return value == true or value == "true" or value == 1 or value == "1"
end

local function developerToolsEnabled()
    local pref = rfsuite.preferences and rfsuite.preferences.general
    return pref and isTruthy(pref.developer_tools) or false
end

local function resolveLoaderSpeed(value)
    if value == nil then return nil end
    if type(value) == "number" then return value end
    if type(value) == "string" then
        local speeds = rfsuite.app and rfsuite.app.loaderSpeed
        if speeds and speeds[value] then return speeds[value] end
        local num = tonumber(value)
        if num ~= nil then return num end
    end
    return nil
end

-- Load a module's init.lua to retrieve script/title/order/etc.
-- Returns a table with `folder` set, or nil on error.
local function loadModuleConfig(folder)
    local init_path = "app/modules/" .. folder .. "/init.lua"
    local func, err = loadfile(init_path)
    if not func then
        rfsuite.utils.log("Failed to load module init " .. init_path .. ": " .. err, "info")
        missingModules[#missingModules + 1] = folder
        return nil
    end

    local mconfig = func()
    if type(mconfig) ~= "table" or not mconfig.script then
        rfsuite.utils.log("Invalid configuration in " .. init_path, "info")
        missingModules[#missingModules + 1] = folder
        return nil
    end

    mconfig.folder = folder
    return mconfig
end

-- Fill in missing keys from src without overriding explicit manifest values.
-- This lets the manifest stay minimal: when a module's init.lua changes (title,
-- script, offline flags, etc.), the main menu inherits those updates unless the
-- manifest intentionally overrides them. Only change this if you want the
-- manifest to become the authoritative source for those fields.
local function applyDefaults(dest, src, keys)
    for _, k in ipairs(keys) do
        if dest[k] == nil and src[k] ~= nil then dest[k] = src[k] end
    end
end

-- Build `sections` (main menu entries) and `pages` (submenu items) from manifest.
for _, section in ipairs(manifest.sections or {}) do
    local out = {}
    for k, v in pairs(section) do
        if k ~= "entry" and k ~= "pages" then out[k] = v end
    end

    if section.entry then
        -- `entry` points to a module that opens directly from the main menu.
        local mod = loadModuleConfig(section.entry)
        if mod then
            applyDefaults(out, mod, {
                "title",
                "script",
                "offline",
                "bgtask",
                "loaderspeed",
                "ethosversion",
                "mspversion",
                "apiform",
                "disable",
                "developer"
            })
            out.module = out.module or section.entry
            if out.image == nil and mod.image then
                -- Normalize image to absolute app/modules path for main menu icons.
                out.image = "app/modules/" .. section.entry .. "/" .. mod.image
            end
        end
    end

    local sectionIsDeveloper = isTruthy(out.developer) or isTruthy(section.developer)
    local showDeveloperModules = developerToolsEnabled()
    if not sectionIsDeveloper or showDeveloperModules then
        out.loaderspeed = resolveLoaderSpeed(out.loaderspeed)
        local sectionIndex = #sections + 1
        sections[sectionIndex] = out

        if section.pages then
            -- `pages` defines submenu items; each entry maps to a module folder.
            for _, pageSpec in ipairs(section.pages) do
                local folder = nil
                local overrides = nil

                if type(pageSpec) == "string" then
                    folder = pageSpec
                elseif type(pageSpec) == "table" then
                    -- Allow overrides (e.g. order, title) alongside folder/module name.
                    folder = pageSpec.folder or pageSpec.module or pageSpec[1]
                    overrides = pageSpec
                end

                if folder then
                    local mod = loadModuleConfig(folder)
                    if mod then
                        -- Start with module config, then apply any manifest overrides.
                        local page = {}
                        for k, v in pairs(mod) do page[k] = v end
                        page.folder = folder
                        page.section = sectionIndex

                        if overrides then
                            for k, v in pairs(overrides) do
                                if k ~= "folder" and k ~= "module" then page[k] = v end
                            end
                        end

                        local pageIsDeveloper = isTruthy(page.developer)
                        if not pageIsDeveloper or showDeveloperModules then
                            page.loaderspeed = resolveLoaderSpeed(page.loaderspeed)
                            pages[#pages + 1] = page
                        end
                    end
                end
            end
        end
    end
end

if #missingModules > 0 then
    -- Keep this as a single log line to avoid spam on low-memory radios.
    rfsuite.utils.log("Manifest modules missing or invalid: " .. table.concat(missingModules, ", "), "info")
end

local function sortPagesBySectionAndOrder(pages)

    local groupedPages = {}

    for _, page in ipairs(pages) do
        if not groupedPages[page.section] then groupedPages[page.section] = {} end
        table.insert(groupedPages[page.section], page)
    end

    for section, pagesGroup in pairs(groupedPages) do table.sort(pagesGroup, function(a, b) return a.order < b.order end) end

    local sortedPages = {}
    for section = 1, #sections do if groupedPages[section] then for _, page in ipairs(groupedPages[section]) do sortedPages[#sortedPages + 1] = page end end end

    return sortedPages
end

pages = sortPagesBySectionAndOrder(pages)

return {pages = pages, sections = sections}
