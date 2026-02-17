--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local shortcuts = {}
local registryCache = nil
local MAX_SHORTCUTS = 5

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

local function buildMenuOrderAndContext(manifest)
    local menus = manifest.menus or {}
    local order = {}
    local queue = {}
    local queued = {}
    local visited = {}
    local menuContextByMenuId = {}

    local function enqueueMenu(menuId, contextId)
        if type(menuId) ~= "string" or menuId == "" then return end
        if type(contextId) == "string" and contextId ~= "" and menuContextByMenuId[menuId] == nil then
            menuContextByMenuId[menuId] = contextId
        end
        if queued[menuId] then return end
        queued[menuId] = true
        queue[#queue + 1] = menuId
    end

    for _, group in ipairs(manifest.sections or {}) do
        for _, section in ipairs(group.sections or {}) do
            if type(section) == "table" and pageVisible(section) then
                local menuId = section.menuId
                if type(menuId) == "string" and menuId ~= "" then
                    local contextId = (type(section.id) == "string" and section.id ~= "") and section.id or nil
                    enqueueMenu(menuId, contextId)
                end
            end
        end
    end

    local head = 1
    while head <= #queue do
        local menuId = queue[head]
        head = head + 1

        if not visited[menuId] then
            visited[menuId] = true
            order[#order + 1] = menuId

            local menu = menus[menuId]
            local contextId = menuContextByMenuId[menuId]
            if type(menu) == "table" and type(menu.pages) == "table" then
                for _, page in ipairs(menu.pages) do
                    if type(page) == "table" and pageVisible(page) then
                        local childMenuId = page.menuId
                        if type(childMenuId) == "string" and childMenuId ~= "" then
                            enqueueMenu(childMenuId, contextId)
                        end
                    end
                end
            end
        end
    end

    return order, menuContextByMenuId
end

local function resolveScriptPath(scriptPrefix, script)
    if type(script) ~= "string" or script == "" then return nil end
    if script:sub(1, 4) == "app/" then return script end
    return (scriptPrefix or "") .. script
end

local function resolveImagePath(iconPrefix, image)
    if type(image) ~= "string" or image == "" then return nil end
    if image:sub(1, 4) == "app/" then return image end
    return (iconPrefix or "") .. image
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

local function resolvePage(menu, page)
    local fallbackImage = "app/gfx/tools.png"
    local out = {
        name = page.name,
        menuId = page.menuId,
        script = resolveScriptPath(menu.scriptPrefix, page.script),
        image = resolveImagePath(menu.iconPrefix, page.image) or fallbackImage
    }
    for _, key in ipairs(COPY_KEYS) do
        if page[key] ~= nil then out[key] = page[key] end
    end
    return out
end

function shortcuts.buildRegistry()
    if type(registryCache) == "table" then
        return registryCache
    end

    local chunk = loadfile("app/modules/manifest.lua")
    local manifest = chunk and chunk() or {}
    if type(manifest) ~= "table" then
        registryCache = {groups = {}, items = {}, byId = {}}
        return registryCache
    end

    local menus = manifest.menus or {}
    local order, menuContextByMenuId = buildMenuOrderAndContext(manifest)

    local groups = {}
    local items = {}
    local byId = {}

    local groupIndex = 0
    for _, menuId in ipairs(order) do
        local menu = menus[menuId]
        if type(menu) == "table" and type(menu.pages) == "table" then
            groupIndex = groupIndex + 1
            local group = {title = menu.title or menuId, menuId = menuId, menu = menu, items = {}}

            local pageIndex = 0
            for _, page in ipairs(menu.pages) do
                if type(page) == "table" and type(page.name) == "string" and page.name ~= "" and pageVisible(page) then
                    pageIndex = pageIndex + 1
                    local id = "s_" .. tostring(groupIndex) .. "_" .. tostring(pageIndex)
                    local entry = {
                        id = id,
                        name = page.name,
                        menuId = menuId,
                        groupTitle = group.title,
                        menu = menu,
                        page = page,
                        menuContextId = menuContextByMenuId[menuId]
                    }
                    group.items[#group.items + 1] = entry
                    items[#items + 1] = entry
                    byId[id] = entry
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
        if shortcuts.isSelected(prefs, item.id) then
            selectedCount = selectedCount + 1
            if selectedCount <= limit then
                selectedMap[item.id] = true
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
        if selectedMap[item.id] then
            pages[#pages + 1] = resolvePage(item.menu or {}, item.page or {})
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
    for _, item in ipairs(registry.items) do
        if selectedMap[item.id] then
            local page = resolvePage(item.menu or {}, item.page or {})
            local section = {
                id = "shortcut_" .. item.id,
                title = page.name,
                image = page.image,
                loaderspeed = page.loaderspeed,
                offline = page.offline,
                bgtask = page.bgtask,
                group = "shortcuts",
                groupTitle = "@i18n(app.header_shortcuts)@",
                menuContextId = item.menuContextId,
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
    return sections
end

function shortcuts.buildSelectedSectionsFromManifest(manifest, prefs)
    if type(manifest) ~= "table" then return {} end
    local selected = prefs or {}
    local maxSelected = normalizeMaxSelected(MAX_SHORTCUTS)
    local selectedCount = 0
    local menus = manifest.menus or {}
    local order, menuContextByMenuId = buildMenuOrderAndContext(manifest)

    local sections = {}
    local groupIndex = 0
    for _, menuId in ipairs(order) do
        local menu = menus[menuId]
        if type(menu) == "table" and type(menu.pages) == "table" then
            groupIndex = groupIndex + 1
            local pageIndex = 0
            for _, page in ipairs(menu.pages) do
                if type(page) == "table" and type(page.name) == "string" and page.name ~= "" and pageVisible(page) then
                    pageIndex = pageIndex + 1
                    local id = "s_" .. tostring(groupIndex) .. "_" .. tostring(pageIndex)
                    if isTruthy(selected[id]) then
                        selectedCount = selectedCount + 1
                        if selectedCount > maxSelected then
                            goto continue
                        end
                        local pageSpec = resolvePage(menu, page)
                        local section = {
                            id = "shortcut_" .. id,
                            title = pageSpec.name,
                            image = pageSpec.image,
                            loaderspeed = pageSpec.loaderspeed,
                            offline = pageSpec.offline,
                            bgtask = pageSpec.bgtask,
                            group = "shortcuts",
                            groupTitle = "@i18n(app.header_shortcuts)@",
                            menuContextId = menuContextByMenuId[menuId],
                            forceMenuToMain = true,
                            clearReturnStack = true
                        }

                        for _, key in ipairs(COPY_KEYS) do
                            if pageSpec[key] ~= nil then section[key] = pageSpec[key] end
                        end

                        if type(pageSpec.menuId) == "string" and pageSpec.menuId ~= "" then
                            section.menuId = pageSpec.menuId
                        else
                            local module, script = scriptToModuleAndScript(pageSpec.script)
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
                ::continue::
            end
        end
    end

    return sections
end

function shortcuts.resetRegistry()
    registryCache = nil
end

return shortcuts
