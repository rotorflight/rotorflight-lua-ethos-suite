--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local enableWakeup = false
local prevConnectedState = nil
local page

local function openPage(opts)

    local idx = opts.idx
    local title = opts.title
    local script = opts.script
    local source = opts.source
    local folder = opts.folder
    local themeScript = opts.themeScript
    local pageIdx = idx

    rfsuite.app.uiState = rfsuite.app.uiStatus.pages
    rfsuite.app.triggers.isReady = false
    rfsuite.app.lastLabel = nil

    local app = rfsuite.app
    if app.formFields then for i = 1, #app.formFields do app.formFields[i] = nil end end
    if app.formLines then for i = 1, #app.formLines do app.formLines[i] = nil end end

    rfsuite.app.dashboardEditingTheme = source .. "/" .. folder

    local modulePath = themeScript

    page = assert(loadfile(modulePath))(idx)

    local w, h = lcd.getWindowSize()
    local windowWidth = w
    local windowHeight = h
    local padding = rfsuite.app.radio.buttonPadding

    local sc
    local panel

    form.clear()

    form.addLine("@i18n(app.modules.settings.name)@" .. " / " .. title)
    local buttonW = 100
    local x = windowWidth - (buttonW * 2) - 15

    rfsuite.app.formNavigationFields['menu'] = form.addButton(line, {x = x, y = rfsuite.app.radio.linePaddingTop, w = buttonW, h = rfsuite.app.radio.navbuttonHeight}, {
        text = "@i18n(app.navigation_menu)@",
        icon = nil,
        options = FONT_S,
        paint = function() end,
        press = function()
            rfsuite.app.lastIdx = nil
            rfsuite.session.lastPage = nil

            if rfsuite.app.Page and rfsuite.app.Page.onNavMenu then rfsuite.app.Page.onNavMenu(rfsuite.app.Page) end

            rfsuite.app.ui.openPage({idx = pageIdx, title = "@i18n(app.modules.settings.dashboard)@", script = "settings/tools/dashboard_settings.lua"})
        end
    })
    rfsuite.app.formNavigationFields['menu']:focus()

    local x = windowWidth - buttonW - 10
    rfsuite.app.formNavigationFields['save'] = form.addButton(line, {x = x, y = rfsuite.app.radio.linePaddingTop, w = buttonW, h = rfsuite.app.radio.navbuttonHeight}, {
        text = "SAVE",
        icon = nil,
        options = FONT_S,
        paint = function() end,
        press = function()

            local buttons = {
                {
                    label = "@i18n(app.btn_ok_long)@",
                    action = function()
                        local msg = "@i18n(app.modules.profile_select.save_prompt_local)@"
                        rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))
                        if page.write then page.write() end

                        rfsuite.widgets.dashboard.reload_themes()
                        rfsuite.app.triggers.closeSave = true
                        return true
                    end
                }, {label = "@i18n(app.modules.profile_select.cancel)@", action = function() return true end}
            }

            form.openDialog({width = nil, title = "@i18n(app.modules.profile_select.save_settings)@", message = "@i18n(app.modules.profile_select.save_prompt_local)@", buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})

        end
    })
    rfsuite.app.formNavigationFields['menu']:focus()

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

    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage({idx = pageIdx, title = "@i18n(app.modules.settings.dashboard)@", script = "settings/tools/dashboard.lua"})
        return true
    end

    if page.event then page.event() end

end

local function onNavMenu()
    rfsuite.app.ui.progressDisplay(nil, nil, rfsuite.app.loaderSpeed.FAST)
    rfsuite.app.ui.openPage({idx = pageIdx, title = "@i18n(app.modules.settings.dashboard)@", script = "settings/tools/dashboard.lua"})
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

return {pages = pages, openPage = openPage, API = {}, navButtons = {menu = true, save = false, reload = false, tool = false, help = false}, event = event, onNavMenu = onNavMenu, wakeup = wakeup}
