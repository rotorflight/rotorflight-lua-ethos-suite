--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local shortcuts = assert(loadfile("app/lib/shortcuts.lua"))()

local pages = {}
local manifest = loadfile("app/modules/manifest.lua")()
local sections = {}

local function isTruthy(value)
    return value == true or value == "true" or value == 1 or value == "1"
end

local function prefBool(value)
    if value == nil then return nil end
    if type(value) == "boolean" then return value end
    if type(value) == "number" then return value > 0 end
    if type(value) == "string" then
        local lowered = value:lower():match("^%s*(.-)%s*$")
        if lowered == "true" or lowered == "1" or lowered == "yes" or lowered == "on" then return true end
        if lowered == "false" or lowered == "0" or lowered == "no" or lowered == "off" then return false end
        if lowered:find("mix", 1, true) then return true end
        if lowered:find("dock", 1, true) then return false end
        local num = tonumber(lowered)
        if num ~= nil then return num > 0 end
    end
    return nil
end

local function developerToolsEnabled()
    local pref = rfsuite.preferences and rfsuite.preferences.general
    return pref and isTruthy(pref.developer_tools) or false
end

local function shortcutsEnabled()
    local prefs = rfsuite.preferences and rfsuite.preferences.shortcuts
    if type(prefs) ~= "table" then return false end
    for _, value in pairs(prefs) do
        if isTruthy(value) then return true end
    end
    return false
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

local function cloneShallow(src)
    local out = {}
    for k, v in pairs(src or {}) do out[k] = v end
    return out
end

local showDeveloperModules = developerToolsEnabled()
local shortcutSections = nil

local function includeByDeveloper(spec)
    local isDev = isTruthy(spec and spec.developer)
    return (not isDev) or showDeveloperModules
end

local function includeByShortcuts(spec)
    local requiresShortcuts = isTruthy(spec and spec.requiresShortcuts)
    if requiresShortcuts then
        return shortcutsEnabled()
    end
    return true
end

local function addSection(spec)
    if not includeByDeveloper(spec) then return nil end
    if not includeByShortcuts(spec) then return nil end

    local section = cloneShallow(spec)
    section.loaderspeed = resolveLoaderSpeed(section.loaderspeed)
    section.pages = nil
    section.order = nil
    section.parent = nil

    local idx = #sections + 1
    sections[idx] = section
    return idx
end

local function addLeafPage(sectionIndex, spec)
    if not includeByDeveloper(spec) then return end
    if not includeByShortcuts(spec) then return end

    local page = cloneShallow(spec)
    page.section = sectionIndex
    page.folder = page.folder or page.module
    page.loaderspeed = resolveLoaderSpeed(page.loaderspeed)

    if not (page.folder and page.script) then
        rfsuite.utils.log("Manifest page missing folder/module or script: " .. tostring(page.title), "info")
        return
    end

    pages[#pages + 1] = page
end

local function resolveShortcutSections()
    if shortcutSections ~= nil then return shortcutSections end
    local prefs = rfsuite.preferences and rfsuite.preferences.shortcuts or {}
    shortcutSections = shortcuts.buildSelectedSectionsFromManifest(manifest, prefs)
    return shortcutSections
end

local function shortcutDisplayMode()
    local general = rfsuite.preferences and rfsuite.preferences.general
    local mixedPref = prefBool(general and general.shortcuts_mixed_in)
    return (mixedPref == true) and "mixed" or "dock"
end

local function flattenSectionSpecs(rawSections)
    local out = {}
    if type(rawSections) ~= "table" then return out end

    local shortcutMode = shortcutDisplayMode()
    local extras = resolveShortcutSections()
    if type(extras) ~= "table" then extras = {} end
    local mixedInserted = false

    local function appendMixedShortcuts()
        for _, extra in ipairs(extras) do
            local appended = cloneShallow(extra)
            appended.newline = nil
            appended._mixedShortcut = true
            out[#out + 1] = appended
        end
    end

    for _, entry in ipairs(rawSections) do
        if type(entry) == "table" and type(entry.sections) == "table" then
            for _, child in ipairs(entry.sections) do
                if type(child) == "table" then
                    local spec = cloneShallow(child)
                    if spec.group == nil then spec.group = entry.id end
                    if spec.groupTitle == nil then spec.groupTitle = entry.title end
                    out[#out + 1] = spec
                end
            end
            if shortcutMode == "dock" and entry.id == "configuration" then
                for _, extra in ipairs(extras) do
                    out[#out + 1] = extra
                end
            end
            if shortcutMode == "mixed" and entry.id == "configuration" then
                appendMixedShortcuts()
                mixedInserted = true
            end
        elseif type(entry) == "table" then
            out[#out + 1] = entry
        end
    end

    if shortcutMode == "mixed" and not mixedInserted then
        appendMixedShortcuts()
    end

    return out
end

for _, sectionSpec in ipairs(flattenSectionSpecs(manifest.sections)) do
    local sectionIndex = addSection(sectionSpec)
    if sectionIndex then
        if sectionSpec.pages then
            for _, pageSpec in ipairs(sectionSpec.pages) do
                addLeafPage(sectionIndex, pageSpec)
            end
        end
    end
end

local function sortPagesBySectionAndOrder(pageList)
    local groupedPages = {}

    for _, page in ipairs(pageList) do
        if not groupedPages[page.section] then groupedPages[page.section] = {} end
        groupedPages[page.section][#groupedPages[page.section] + 1] = page
    end

    for _, pagesGroup in pairs(groupedPages) do
        table.sort(pagesGroup, function(a, b)
            local ao = tonumber(a.order) or 9999
            local bo = tonumber(b.order) or 9999
            if ao == bo then
                return tostring(a.title or "") < tostring(b.title or "")
            end
            return ao < bo
        end)
    end

    local sortedPages = {}
    for section = 1, #sections do
        if groupedPages[section] then
            for _, page in ipairs(groupedPages[section]) do
                sortedPages[#sortedPages + 1] = page
            end
        end
    end

    return sortedPages
end

pages = sortPagesBySectionAndOrder(pages)

return {pages = pages, sections = sections}
