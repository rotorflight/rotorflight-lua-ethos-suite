--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local lcd = lcd

local enableWakeup = false
local prevConnectedState = nil
local page
local pageIdx
local onNavMenu

-- Reuses app/lib/ui.lua's own page-chunk cache (ui._pageChunkCache) rather
-- than a separate one here -- same reasoning: this theme settings page can
-- be opened repeatedly (a different idx per theme button, see
-- app/modules/settings/tools/dashboard_settings.lua), and each open used to
-- re-parse themeScript from disk every single time via a plain loadfile().
-- Caching the compiled chunk, not its call result, means `page` below is
-- still built fresh (module-scope local, reassigned inside openPage() every
-- call) on every visit -- only the disk-read+parse+compile step is skipped
-- on repeat visits to the same theme.
local function loadThemeChunk(modulePath)
    local ui = rfsuite.app.ui
    local cache = ui and ui._pageChunkCache
    if not cache then
        return assert(loadfile(modulePath))
    end
    local chunk = cache[modulePath]
    if not chunk then
        chunk = assert(loadfile(modulePath))
        cache[modulePath] = chunk
    end
    return chunk
end

local function onSaveMenu()
    local buttons = {
        {
            label = "@i18n(app.btn_ok_long)@",
            action = function()
                local msg = "@i18n(app.modules.profile_select.save_prompt_local)@"
                rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))
                if page and page.write then page.write() end
                rfsuite.bus.notify("dashboard.reload_themes", {})
                rfsuite.app.triggers.closeSave = true
                return true
            end
        }, {label = "@i18n(app.modules.profile_select.cancel)@", action = function() return true end}
    }

    form.openDialog({
        width = nil,
        title = "@i18n(app.modules.profile_select.save_settings)@",
        message = "@i18n(app.modules.profile_select.save_prompt_local)@",
        buttons = buttons,
        wakeup = function() end,
        paint = function() end,
        options = TEXT_LEFT
    })
    return true
end

local function openPage(opts)

    local idx = opts.idx
    local title = opts.title
    local script = opts.script
    local source = opts.source
    local folder = opts.folder
    local themeScript = opts.themeScript
    pageIdx = idx

    rfsuite.app.uiState = rfsuite.app.uiStatus.pages
    rfsuite.app.triggers.isReady = false
    rfsuite.app.lastLabel = nil

    local app = rfsuite.app
    if app.formFields then for k in pairs(app.formFields) do app.formFields[k] = nil end end
    if app.formLines then for k in pairs(app.formLines) do app.formLines[k] = nil end end

    rfsuite.session.dashboardEditingTheme = source .. "/" .. folder

    local modulePath = themeScript

    page = loadThemeChunk(modulePath)(idx)

    form.clear()
    rfsuite.app.ui.fieldHeader("@i18n(app.modules.settings.name)@" .. " / " .. title)

    rfsuite.app.uiState = rfsuite.app.uiStatus.pages
    enableWakeup = true

    if page.configure then
        page.configure({idx = idx, title = title, script = script, source = source, folder = folder, themeScript = themeScript})
        rfsuite.utils.reportMemoryUsage(title)
        rfsuite.app.triggers.closeProgressLoader = true
        return
    end

end

local function event(widget, category, value, x, y)

    if pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu}) then
        return true
    end

    if page.event then page.event() end

end

onNavMenu = function()
    pageRuntime.openMenuContext()
    return true
end

local function wakeup()

    if not enableWakeup then return end

    local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false

    if currState ~= prevConnectedState then

        if currState == false then onNavMenu() end

        prevConnectedState = currState
    end

    if page.wakeup then page.wakeup() end

end

return {
    pages = pages,
    openPage = openPage,
    API = {},
    navButtons = {menu = true, save = true, reload = false, tool = false, help = false},
    event = event,
    onNavMenu = onNavMenu,
    onSaveMenu = onSaveMenu,
    wakeup = wakeup
}
