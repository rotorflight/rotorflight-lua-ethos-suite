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

local function onSaveMenu()
    local buttons = {
        {
            label = "@i18n(app.btn_ok_long)@",
            action = function()
                local msg = "@i18n(app.modules.profile_select.save_prompt_local)@"
                rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))
                if page and page.write then page.write() end
                rfsuite.widgets.dashboard.reload_themes()
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

    rfsuite.app.dashboardEditingTheme = source .. "/" .. folder

    local modulePath = themeScript

    page = assert(loadfile(modulePath))(idx)

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
