--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local pages = {}
local manifest = loadfile("app/modules/manifest.lua")()
local sections = {}

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

local function cloneShallow(src)
    local out = {}
    for k, v in pairs(src or {}) do out[k] = v end
    return out
end

local showDeveloperModules = developerToolsEnabled()

local function includeByDeveloper(spec)
    local isDev = isTruthy(spec and spec.developer)
    return (not isDev) or showDeveloperModules
end

local function addSection(spec)
    if not includeByDeveloper(spec) then return nil end

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

for _, sectionSpec in ipairs(manifest.sections or {}) do
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
