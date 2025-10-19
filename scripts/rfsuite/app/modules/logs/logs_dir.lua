--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local utils = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/app/modules/logs/lib/utils.lua"))()

local enableWakeup = false

local function openPage(idx, title, script)
    rfsuite.app.activeLogDir = nil
    if not rfsuite.utils.ethosVersionAtLeast() then return end

    if rfsuite.tasks.msp then rfsuite.tasks.msp.protocol.mspIntervalOveride = nil end

    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.pages
    form.clear()

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    local w, h = lcd.getWindowSize()
    local prefs = rfsuite.preferences.general
    local radio = rfsuite.app.radio
    local icons = prefs.iconsize
    local padding, btnW, btnH, perRow

    if icons == 0 then
        padding = radio.buttonPaddingSmall
        btnW = (rfsuite.app.lcdWidth - padding) / radio.buttonsPerRow - padding
        btnH = radio.navbuttonHeight
        perRow = radio.buttonsPerRow
    elseif icons == 1 then
        padding = radio.buttonPaddingSmall
        btnW, btnH = radio.buttonWidthSmall, radio.buttonHeightSmall
        perRow = radio.buttonsPerRowSmall
    else
        padding = radio.buttonPadding
        btnW, btnH = radio.buttonWidth, radio.buttonHeight
        perRow = radio.buttonsPerRow
    end

    rfsuite.app.ui.fieldHeader("Logs")

    local logDir = utils.getLogPath()
    local folders = utils.getLogsDir(logDir)

    if #folders == 0 then
        local msg = "@i18n(app.modules.logs.msg_no_logs_found)@"
        local tw, th = lcd.getTextSize(msg)
        local x = w / 2 - tw / 2
        local y = h / 2 - th / 2
        form.addStaticText(nil, {x = x, y = y, w = tw, h = btnH}, msg)
    else

        local x, y, col = 0, form.height() + padding, 0
        rfsuite.app.gfx_buttons.logs = rfsuite.app.gfx_buttons.logs or {}

        for i, item in ipairs(folders) do
            if col >= perRow then col, y = 0, y + btnH + padding end

            local modelName = utils.resolveModelName(item.foldername)

            if icons ~= 0 then
                rfsuite.app.gfx_buttons.logs[i] = rfsuite.app.gfx_buttons.logs[i] or lcd.loadMask("app/modules/logs/gfx/folder.png")
            else
                rfsuite.app.gfx_buttons.logs[i] = nil
            end

            local btn = form.addButton(nil, {x = col * (btnW + padding), y = y, w = btnW, h = btnH}, {
                text = modelName,
                options = FONT_S,
                icon = rfsuite.app.gfx_buttons.logs[i],
                press = function()
                    rfsuite.preferences.menulastselected.logs = i
                    rfsuite.app.ui.progressDisplay()
                    rfsuite.app.activeLogDir = item.foldername
                    rfsuite.utils.log("Opening logs for: " .. item.foldername, "info")
                    rfsuite.app.ui.openPage(i, "Logs", "logs/logs_logs.lua")
                end
            })

            btn:enable(true)

            if rfsuite.preferences.menulastselected.logs_folder == i then btn:focus() end

            col = col + 1
        end
    end

    if rfsuite.tasks.msp then rfsuite.app.triggers.closeProgressLoader = true end

    enableWakeup = true
end

local function event(widget, category, value)
    if value == 35 or category == 3 then
        rfsuite.app.ui.openMainMenu()
        return true
    end
    return false
end

local function wakeup() if enableWakeup then end end

local function onNavMenu() rfsuite.app.ui.openMainMenu() end

return {event = event, openPage = openPage, wakeup = wakeup, onNavMenu = onNavMenu, navButtons = {menu = true, save = false, reload = false, tool = false, help = true}, API = {}}
