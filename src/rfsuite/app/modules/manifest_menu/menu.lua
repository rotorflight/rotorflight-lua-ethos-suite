--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

-- Shared manifest submenu router.
-- Why this exists:
-- 1) `ui.openPage()` resolves relative scripts under `app/modules/`.
-- 2) Main menu and submenu buttons can pass only a `menuId`.
-- 3) This single module reads that pending `menuId` and builds the target menu.
-- Result: menu structure stays centralized in `manifest.lua` with no per-menu wrappers.
local app = rfsuite.app

local function getSubmenuBuilder()
    if app._submenuBuilder then return app._submenuBuilder end
    app._submenuBuilder = assert(loadfile("app/lib/submenu_builder.lua"))()
    return app._submenuBuilder
end

local function findSectionMenuIdFromMainMenu(sectionId)
    if type(app) ~= "table" or type(sectionId) ~= "string" or sectionId == "" then return nil end
    local sections = app.MainMenu and app.MainMenu.sections
    if type(sections) ~= "table" then return nil end

    for i = 1, #sections do
        local section = sections[i]
        if section and section.id == sectionId and type(section.menuId) == "string" and section.menuId ~= "" then
            return section.menuId
        end
    end

    return nil
end

local function firstManifestMenuIdFromMainMenu()
    if type(app) ~= "table" then return nil end
    local sections = app.MainMenu and app.MainMenu.sections
    if type(sections) ~= "table" then return nil end

    for i = 1, #sections do
        local section = sections[i]
        if section and type(section.menuId) == "string" and section.menuId ~= "" then
            return section.menuId
        end
    end

    return nil
end

local function loadManifest()
    local chunk = assert(loadfile("app/modules/manifest.lua"))
    local manifest = chunk()
    if type(manifest) ~= "table" then return {} end
    return manifest
end

local function findSectionMenuId(manifest, sectionId)
    if type(manifest) ~= "table" or type(sectionId) ~= "string" or sectionId == "" then return nil end
    for _, group in ipairs(manifest.sections or {}) do
        for _, section in ipairs(group.sections or {}) do
            if section.id == sectionId and type(section.menuId) == "string" and section.menuId ~= "" then
                return section.menuId
            end
        end
    end
    return nil
end

local function firstManifestMenuId(manifest)
    if type(manifest) ~= "table" then return nil end
    for _, group in ipairs(manifest.sections or {}) do
        for _, section in ipairs(group.sections or {}) do
            if type(section.menuId) == "string" and section.menuId ~= "" then
                return section.menuId
            end
        end
    end
    return nil
end

local function resolveMenuId()
    if type(app) ~= "table" then return nil end

    if type(app.pendingManifestMenuId) == "string" and app.pendingManifestMenuId ~= "" then
        return app.pendingManifestMenuId
    end

    if type(app.activeManifestMenuId) == "string" and app.activeManifestMenuId ~= "" then
        return app.activeManifestMenuId
    end

    local sectionMenuId = findSectionMenuIdFromMainMenu(app.lastMenu)
    if sectionMenuId then
        return sectionMenuId
    end

    local firstFromMain = firstManifestMenuIdFromMainMenu()
    if firstFromMain then
        return firstFromMain
    end

    local manifest = loadManifest()
    sectionMenuId = findSectionMenuId(manifest, app.lastMenu)
    if sectionMenuId then
        return sectionMenuId
    end

    return firstManifestMenuId(manifest)
end

local menuId = resolveMenuId()
if type(menuId) ~= "string" or menuId == "" then
    error("manifest_menu/menu.lua could not resolve manifest menu id")
end

app.pendingManifestMenuId = nil
app.activeManifestMenuId = menuId
return getSubmenuBuilder().createFromManifest(menuId)
