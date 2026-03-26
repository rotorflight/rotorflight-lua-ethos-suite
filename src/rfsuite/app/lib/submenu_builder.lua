--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local buildContainer = assert(loadfile("app/lib/menu_container.lua"))()

local submenu = {}
local manifestPath = "app/modules/manifest.lua"
local menuSpecPathPrefix = "app/modules/manifest_menus/"
local manifestCache = nil
local manifestMenuSpecCache = {}

local function cloneShallow(src)
    local out = {}
    for k, v in pairs(src or {}) do out[k] = v end
    return out
end

local function mergeShallow(base, override)
    local out = {}
    for k, v in pairs(base or {}) do out[k] = v end
    for k, v in pairs(override or {}) do out[k] = v end
    return out
end

local function loadHooks(path)
    if not path then return {} end
    local chunk = assert(loadfile(path))
    local hooks = chunk()
    if type(hooks) ~= "table" then return {} end
    return hooks
end

local function resolvePages(opts, hooks)
    if type(hooks.getPages) == "function" then
        local pages = hooks.getPages(opts)
        if type(pages) == "table" then return pages end
    end
    if type(hooks.pages) == "table" then return hooks.pages end
    return opts.pages or {}
end

local function loadManifest()
    if type(manifestCache) == "table" then return manifestCache end

    local chunk = assert(loadfile(manifestPath))
    local manifest = chunk()
    if type(manifest) ~= "table" then
        manifestCache = {}
    else
        manifestCache = manifest
    end

    return manifestCache
end

local function loadManifestMenuSpec(menuId)
    if type(menuId) ~= "string" or menuId == "" then return nil end

    local cached = manifestMenuSpecCache[menuId]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end

    local chunk = loadfile(menuSpecPathPrefix .. menuId .. ".lua")
    if not chunk then
        manifestMenuSpecCache[menuId] = false
        return nil
    end
    local ok, spec = pcall(chunk)
    if not ok or type(spec) ~= "table" then
        manifestMenuSpecCache[menuId] = false
        return nil
    end
    manifestMenuSpecCache[menuId] = spec
    return spec
end

local function resolveManifestMenuSpec(menuId)
    if type(menuId) ~= "string" or menuId == "" then
        error("submenu.createFromManifest requires opts.menuId")
    end

    local spec = loadManifestMenuSpec(menuId)
    if type(spec) ~= "table" then
        local manifest = loadManifest()
        local menus = manifest.menus
        if type(menus) ~= "table" then
            error("Manifest has no menus table for submenu id: " .. menuId)
        end

        spec = menus[menuId]
        if type(spec) ~= "table" then
            error("No manifest submenu entry for id: " .. menuId)
        end
    end

    local cfg = cloneShallow(spec)
    if cfg.moduleKey == nil then cfg.moduleKey = menuId end
    return cfg
end

function submenu.create(opts)
    local hooks = loadHooks(opts.hooksScript)

    local cfg = {
        moduleKey = hooks.moduleKey or opts.moduleKey,
        title = hooks.title or opts.title,
        pages = resolvePages(opts, hooks),
        scriptPrefix = hooks.scriptPrefix or opts.scriptPrefix,
        iconPrefix = hooks.iconPrefix or opts.iconPrefix,
        loaderSpeed = hooks.loaderSpeed or opts.loaderSpeed,
        navOptions = mergeShallow(opts.navOptions, hooks.navOptions),
        onOpenPre = hooks.onOpenPre or opts.onOpenPre,
        onOpenPost = hooks.onOpenPost or opts.onOpenPost,
        onWakeup = hooks.onWakeup or opts.onWakeup,
        scriptPathResolver = hooks.scriptPathResolver or opts.scriptPathResolver,
        iconPathResolver = hooks.iconPathResolver or opts.iconPathResolver,
        childTitlePrefix = hooks.childTitlePrefix or opts.childTitlePrefix,
        childTitleResolver = hooks.childTitleResolver or opts.childTitleResolver,
        API = hooks.API or opts.API
    }

    local page = buildContainer.create(cfg)
    page.navButtons = hooks.navButtons or opts.navButtons or page.navButtons

    if type(hooks.extendPage) == "function" then
        local extended = hooks.extendPage(page, opts)
        if type(extended) == "table" then return extended end
    end

    return page
end

function submenu.createFromManifest(opts)
    local options = opts
    if type(options) == "string" then options = {menuId = options} end
    if type(options) ~= "table" then
        error("submenu.createFromManifest expects a table or menu id string")
    end

    local menuId = options.menuId or options.id
    local manifestCfg = resolveManifestMenuSpec(menuId)
    local merged = mergeShallow(manifestCfg, options)
    merged.menuId = nil
    merged.id = nil

    return submenu.create(merged)
end

return submenu
