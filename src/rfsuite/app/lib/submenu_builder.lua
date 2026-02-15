--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local buildContainer = assert(loadfile("app/lib/menu_container.lua"))()

local submenu = {}

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

return submenu
