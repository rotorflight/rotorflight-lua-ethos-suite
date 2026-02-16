--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local shortcuts = {}
local registryCache = nil

local function isTruthy(value)
    return value == true or value == "true" or value == 1 or value == "1"
end

local function buildMenuOrder(manifest)
    local menus = manifest.menus or {}
    local order = {}
    local visited = {}

    for _, group in ipairs(manifest.sections or {}) do
        for _, section in ipairs(group.sections or {}) do
            if type(section) == "table" and type(section.menuId) == "string" and section.menuId ~= "" then
                if not visited[section.menuId] then
                    visited[section.menuId] = true
                    order[#order + 1] = section.menuId
                end
            end
        end
    end

    for menuId in pairs(menus) do
        if not visited[menuId] then
            order[#order + 1] = menuId
        end
    end

    return order
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
    local out = {
        name = page.name,
        menuId = page.menuId,
        script = resolveScriptPath(menu.scriptPrefix, page.script),
        image = resolveImagePath(menu.iconPrefix, page.image)
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
    local order = buildMenuOrder(manifest)

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
                if type(page) == "table" and type(page.name) == "string" and page.name ~= "" then
                    pageIndex = pageIndex + 1
                    local id = "s_" .. tostring(groupIndex) .. "_" .. tostring(pageIndex)
                    local entry = {
                        id = id,
                        name = page.name,
                        menuId = menuId,
                        groupTitle = group.title,
                        menu = menu,
                        page = page
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

function shortcuts.buildSelectedPages(prefs)
    local registry = shortcuts.buildRegistry()
    local pages = {}
    for _, item in ipairs(registry.items) do
        if shortcuts.isSelected(prefs, item.id) then
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
    local sections = {}
    for _, item in ipairs(registry.items) do
        if shortcuts.isSelected(prefs, item.id) then
            local page = resolvePage(item.menu or {}, item.page or {})
            local section = {
                id = "shortcut_" .. item.id,
                title = page.name,
                image = page.image,
                loaderspeed = page.loaderspeed,
                offline = page.offline,
                bgtask = page.bgtask,
                group = "shortcuts",
                groupTitle = "@i18n(app.header_shortcuts)@"
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

function shortcuts.resetRegistry()
    registryCache = nil
end

return shortcuts
