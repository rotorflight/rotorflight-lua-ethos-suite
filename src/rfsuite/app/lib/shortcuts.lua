--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local shortcuts = {}
local registryCache = nil
local MAX_SHORTCUTS = 5
local ITEM_ID = 1
local ITEM_NAME = 2
local ITEM_MENU_ID = 3
local ITEM_SCRIPT = 4
local ITEM_IMAGE = 5
local ITEM_METADATA = 6

local rfsuite = require("rfsuite")

local function isTruthy(value)
    return value == true or value == "true" or value == 1 or value == "1"
end

local function normalizeMaxSelected(value)
    local limit = tonumber(value)
    if limit == nil then limit = MAX_SHORTCUTS end
    limit = math.floor(limit)
    if limit < 1 then limit = 1 end
    return limit
end

local function preferredApiVersion()
    local prefs = rfsuite.preferences and rfsuite.preferences.developer
    local idx = prefs and prefs.apiversion
    local supported = rfsuite.config and rfsuite.config.supportedMspApiVersion
    if type(supported) == "table" and idx and supported[idx] then
        return supported[idx]
    end
    return nil
end

local function apiVersionCompare(op, req)
    local utils = rfsuite.utils
    if not utils or not utils.apiVersionCompare then return false end

    local session = rfsuite.session
    local hasSessionVersion = session and session.apiVersion ~= nil
    if hasSessionVersion then
        return utils.apiVersionCompare(op, req)
    end

    local preferred = preferredApiVersion()
    if preferred and session then
        local old = session.apiVersion
        session.apiVersion = preferred
        local ok = utils.apiVersionCompare(op, req)
        session.apiVersion = old
        return ok
    end

    return utils.apiVersionCompare(op, req)
end

local function apiVersionMatches(spec)
    if type(spec) ~= "table" then return true end
    return (spec.apiversion == nil or apiVersionCompare(">=", spec.apiversion)) and
        (spec.apiversionlt == nil or apiVersionCompare("<", spec.apiversionlt)) and
        (spec.apiversiongt == nil or apiVersionCompare(">", spec.apiversiongt)) and
        (spec.apiversionlte == nil or apiVersionCompare("<=", spec.apiversionlte)) and
        (spec.apiversiongte == nil or apiVersionCompare(">=", spec.apiversiongte))
end

local function pageVisible(page)
    if type(page) ~= "table" then return false end
    local utils = rfsuite.utils
    if page.ethosversion and utils and utils.ethosVersionAtLeast and not utils.ethosVersionAtLeast(page.ethosversion) then
        return false
    end
    if page.mspversion and utils and utils.apiVersionCompare and utils.apiVersionCompare("<", page.mspversion) then
        return false
    end
    if not apiVersionMatches(page) then return false end
    return true
end

local function groupVisible(group)
    local visibility = group and group.visibility
    if type(visibility) ~= "table" then return true end
    for _, spec in ipairs(visibility) do
        if not pageVisible(spec) then return false end
    end
    return true
end

local function itemVisible(item)
    local metadata = item and item[ITEM_METADATA]
    return metadata == false or pageVisible(metadata)
end

local COPY_KEYS = {
    "loaderspeed",
    "offline",
    "bgtask",
    "disabled",
    "mspversion",
    "ethosversion",
    "apiversion",
    "apiversionlt",
    "apiversiongt",
    "apiversionlte",
    "apiversiongte",
    "script_by_mspversion",
    "scriptByMspVersion",
    "script_default"
}

local function copyShortcutPage(item)
    local out = {
        name = item[ITEM_NAME],
        menuId = item[ITEM_MENU_ID] or nil,
        script = item[ITEM_SCRIPT] or nil,
        image = item[ITEM_IMAGE]
    }
    local metadata = item[ITEM_METADATA]
    for _, key in ipairs(COPY_KEYS) do
        if type(metadata) == "table" and metadata[key] ~= nil then out[key] = metadata[key] end
    end
    return out
end

function shortcuts.buildRegistry()
    if type(registryCache) == "table" then
        return registryCache
    end

    local chunk = loadfile("app/modules/manifest_shortcuts.lua")
    local shortcutManifest = chunk and chunk() or {}
    if type(shortcutManifest) ~= "table" then
        registryCache = {groups = {}, items = {}, byId = {}}
        return registryCache
    end

    local groups = {}
    local items = {}
    local byId = {}

    for _, groupSpec in ipairs(shortcutManifest.groups or {}) do
        if type(groupSpec) == "table" and groupVisible(groupSpec) then
            local group = {title = groupSpec.title, menuId = groupSpec.menuId, menuContextId = groupSpec.menuContextId, items = {}}

            for _, entry in ipairs(groupSpec.items or {}) do
                if type(entry) == "table" and type(entry[ITEM_ID]) == "string" and type(entry[ITEM_NAME]) == "string" and entry[ITEM_NAME] ~= "" and itemVisible(entry) then
                    group.items[#group.items + 1] = entry
                    items[#items + 1] = entry
                    byId[entry[ITEM_ID]] = entry
                end
            end

            if #group.items > 0 then
                groups[#groups + 1] = group
            end
        end
    end

    registryCache = {groups = groups, items = items, byId = byId}
    return registryCache
end

function shortcuts.isSelected(prefs, id)
    if type(prefs) ~= "table" or type(id) ~= "string" then return false end
    return isTruthy(prefs[id])
end

function shortcuts.itemId(item)
    return type(item) == "table" and item[ITEM_ID] or nil
end

function shortcuts.itemName(item)
    return type(item) == "table" and item[ITEM_NAME] or nil
end

function shortcuts.getMaxSelected()
    return MAX_SHORTCUTS
end

function shortcuts.limitSelectionMap(prefs, maxSelected)
    local registry = shortcuts.buildRegistry()
    local selectedMap = {}
    if type(prefs) ~= "table" then return selectedMap, 0 end

    local limit = normalizeMaxSelected(maxSelected)
    local selectedCount = 0
    for _, item in ipairs(registry.items or {}) do
        local id = item[ITEM_ID]
        if shortcuts.isSelected(prefs, id) then
            selectedCount = selectedCount + 1
            if selectedCount <= limit then
                selectedMap[id] = true
            end
        end
    end

    return selectedMap, selectedCount
end

function shortcuts.buildSelectedPages(prefs)
    local registry = shortcuts.buildRegistry()
    local selectedMap = shortcuts.limitSelectionMap(prefs, MAX_SHORTCUTS)
    local pages = {}
    for _, item in ipairs(registry.items) do
        if selectedMap[item[ITEM_ID]] then
            pages[#pages + 1] = copyShortcutPage(item)
        end
    end
    return pages
end

local function scriptToModuleAndScript(script)
    if type(script) ~= "string" or script == "" then return nil, nil end
    if script:sub(1, 12) == "app/modules/" then
        script = script:sub(13)
    elseif script:sub(1, 4) == "app/" then
        return nil, nil
    end
    local slash = script:find("/", 1, true)
    if not slash then return nil, nil end
    return script:sub(1, slash - 1), script:sub(slash + 1)
end

function shortcuts.buildSelectedSections(prefs)
    local registry = shortcuts.buildRegistry()
    local selectedMap = shortcuts.limitSelectionMap(prefs, MAX_SHORTCUTS)
    local sections = {}
    for _, group in ipairs(registry.groups) do
        for _, item in ipairs(group.items) do
            local id = item[ITEM_ID]
            if selectedMap[id] then
                local page = copyShortcutPage(item)
                local section = {
                    id = "shortcut_" .. id,
                    title = page.name,
                    image = page.image,
                    loaderspeed = page.loaderspeed,
                    offline = page.offline,
                    bgtask = page.bgtask,
                    group = "shortcuts",
                    groupTitle = "@i18n(app.header_shortcuts)@",
                    menuContextId = group.menuContextId,
                    forceMenuToMain = true,
                    clearReturnStack = true
                }

                for _, key in ipairs(COPY_KEYS) do
                    if page[key] ~= nil then section[key] = page[key] end
                end

                if type(page.menuId) == "string" and page.menuId ~= "" then
                    section.menuId = page.menuId
                else
                    local module, script = scriptToModuleAndScript(page.script)
                    if module and script then
                        section.module = module
                        section.script = script
                    else
                        section = nil
                    end
                end

                if section then
                    sections[#sections + 1] = section
                end
            end
        end
    end
    return sections
end

function shortcuts.resetRegistry()
    registryCache = nil
end

return shortcuts
