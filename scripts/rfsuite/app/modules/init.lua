--[[

 * Copyright (C) Rotorflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]] --
local pages = {}
local sections = loadfile("app/modules/sections.lua")()

-- find the modules (this should already have been done in the tasks/bg.lua script but we catch and retry on the offchance it hasn't)
if rfsuite.app.moduleList == nil then rfsuite.app.moduleList = rfsuite.utils.findModules() end

-- Helper function to find section index
local function findSectionIndex(sectionTitle)
    for index, section in ipairs(sections) do if section.title == sectionTitle then return index end end
    return nil -- Section not found
end

-- Populate pages with mapped modules
for _, module in ipairs(rfsuite.app.moduleList) do
    local sectionIndex = findSectionIndex(module.section)
    if sectionIndex then
        pages[#pages + 1] = {title = module.title, section = sectionIndex, script = module.script, order = module.order or 0, image = module.image, folder = module.folder, ethosversion = module.ethosversion, mspversion = module.mspversion, apiform = module.apiform}
    else
        rfsuite.utils.log("Warning: Section '" .. module.section .. "' not found for module '" .. module.title .. "'","debug")
    end
end

-- Function to sort pages by order within each section
local function sortPagesBySectionAndOrder(pages)
    -- Group pages by section
    local groupedPages = {}

    for _, page in ipairs(pages) do
        if not groupedPages[page.section] then groupedPages[page.section] = {} end
        table.insert(groupedPages[page.section], page)
    end

    -- Sort each group by order
    for section, pagesGroup in pairs(groupedPages) do
        table.sort(pagesGroup, function(a, b)
            return a.order < b.order
        end)
    end

    -- Reconstruct the pages table in the correct order
    local sortedPages = {}
    for section = 1, #sections do if groupedPages[section] then for _, page in ipairs(groupedPages[section]) do sortedPages[#sortedPages + 1] = page end end end

    return sortedPages
end

-- Sort the pages
pages = sortPagesBySectionAndOrder(pages)

return {pages = pages, sections = sections}
