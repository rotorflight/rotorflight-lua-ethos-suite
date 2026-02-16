--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local submenuBuilder = assert(loadfile("app/lib/submenu_builder.lua"))()

-- Shared manifest submenu router.
-- Why this exists:
-- 1) `ui.openPage()` resolves relative scripts under `app/modules/`.
-- 2) Main menu and submenu buttons can pass only a `menuId`.
-- 3) This single module reads that pending `menuId` and builds the target menu.
-- Result: menu structure stays centralized in `manifest.lua` with no per-menu wrappers.
local app = rfsuite.app
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

    local manifest = loadManifest()
    local sectionMenuId = findSectionMenuId(manifest, app.lastMenu)
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
return submenuBuilder.createFromManifest(menuId)
