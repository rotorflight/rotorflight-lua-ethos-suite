--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local pages = {}
local sections = loadfile("app/modules/sections.lua")()

if rfsuite.app.moduleList == nil then rfsuite.app.moduleList = rfsuite.utils.findModules() end

local function findSectionIndex(sectionTitle)
    for index, section in ipairs(sections) do if section.id == sectionTitle then return index end end
    return nil
end

for _, module in ipairs(rfsuite.app.moduleList) do
    local sectionIndex = findSectionIndex(module.section)
    if sectionIndex then
        pages[#pages + 1] = {title = module.title, section = sectionIndex, script = module.script, order = module.order or 0, image = module.image, folder = module.folder, ethosversion = module.ethosversion, mspversion = module.mspversion, apiform = module.apiform, offline = module.offline or false}
    else
        rfsuite.utils.log("Warning: Section '" .. module.section .. "' not found for module '" .. module.title .. "'", "debug")
    end
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
