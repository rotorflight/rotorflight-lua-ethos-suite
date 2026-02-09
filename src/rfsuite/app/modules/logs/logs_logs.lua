--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd
local model = model
local app = rfsuite.app
local prefs = rfsuite.preferences
local tasks = rfsuite.tasks
local rfutils = rfsuite.utils
local session = rfsuite.session

local utils = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/app/modules/logs/lib/utils.lua"))()

local lastServoCountTime = os.clock()
local enableWakeup = false
local wakeupScheduler = os.clock()
local currentDisplayMode

local function getCleanModelName()
    local logdir
    logdir = string.gsub(model.name(), "%s+", "_")
    logdir = string.gsub(logdir, "%W", "_")
    return logdir
end

local function extractHourMinute(filename)

    local hour, minute = filename:match(".-%d%d%d%d%-%d%d%-%d%d_(%d%d)%-(%d%d)%-%d%d")
    if hour and minute then return hour .. ":" .. minute end
    return nil
end

local function format_date(iso_date)
    local y, m, d = iso_date:match("^(%d+)%-(%d+)%-(%d+)$")
    return os.date("%d %B %Y", os.time {year = tonumber(y), month = tonumber(m), day = tonumber(d)})
end

local function openPage(pidx, title, script, displaymode)

    if not rfutils.ethosVersionAtLeast() then return end

    if not tasks.active() then

        local buttons = {
            {
                label = "@i18n(app.btn_ok)@",
                action = function()

                    app.triggers.exitAPP = true
                    app.dialogs.nolinkDisplayErrorDialog = false
                    return true
                end
            }
        }

        form.openDialog({width = nil, title = "@i18n(error)@", message = "@i18n(app.check_bg_task)@", buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})

    end

    currentDisplayMode = displaymode

    if tasks.msp then tasks.msp.protocol.mspIntervalOveride = nil end

    app.triggers.isReady = false
    app.uiState = app.uiStatus.pages

    form.clear()

    app.lastIdx = idx
    app.lastTitle = title
    app.lastScript = script

    local w, h = lcd.getWindowSize()
    local windowWidth = w
    local windowHeight = h
    local padding = app.radio.buttonPadding

    local sc
    local panel

    local logDir = utils.getLogPath()

    local logs = utils.getLogs(logDir)

    local name = utils.resolveModelName(session.mcu_id or app.activeLogDir)
    app.ui.fieldHeader("Logs / " .. name)

    local buttonW
    local buttonH
    local padding
    local numPerRow

    if prefs.general.iconsize == 0 then
        padding = app.radio.buttonPaddingSmall
        buttonW = (app.lcdWidth - padding) / app.radio.buttonsPerRow - padding
        buttonH = app.radio.navbuttonHeight
        numPerRow = app.radio.buttonsPerRow
    end

    if prefs.general.iconsize == 1 then

        padding = app.radio.buttonPaddingSmall
        buttonW = app.radio.buttonWidthSmall
        buttonH = app.radio.buttonHeightSmall
        numPerRow = app.radio.buttonsPerRowSmall
    end

    if prefs.general.iconsize == 2 then

        padding = app.radio.buttonPadding
        buttonW = app.radio.buttonWidth
        buttonH = app.radio.buttonHeight
        numPerRow = app.radio.buttonsPerRow
    end

    local x = windowWidth - buttonW + 10

    local lc = 0
    local bx = 0

    if app.gfx_buttons["logs_logs"] == nil then app.gfx_buttons["logs_logs"] = {} end
    if prefs.menulastselected["logs"] == nil then prefs.menulastselected["logs_logs"] = 1 end

    if app.gfx_buttons["logs"] == nil then app.gfx_buttons["logs"] = {} end
    if prefs.menulastselected["logs_logs"] == nil then prefs.menulastselected["logs_logs"] = 1 end

    local groupedLogs = {}
    for _, filename in ipairs(logs) do
        local datePart = filename:match("(%d%d%d%d%-%d%d%-%d%d)_")
        if datePart then
            groupedLogs[datePart] = groupedLogs[datePart] or {}
            table.insert(groupedLogs[datePart], filename)
        end
    end

    local dates = {}
    for date, _ in pairs(groupedLogs) do table.insert(dates, date) end
    table.sort(dates, function(a, b) return a > b end)

    if #dates == 0 then

        LCD_W, LCD_H = lcd.getWindowSize()
        local str = "@i18n(app.modules.logs.msg_no_logs_found)@"
        local ew = LCD_W
        local eh = LCD_H
        local etsizeW, etsizeH = lcd.getTextSize(str)
        local eposX = ew / 2 - etsizeW / 2
        local eposY = eh / 2 - etsizeH / 2

        local posErr = {w = etsizeW, h = app.radio.navbuttonHeight, x = eposX, y = ePosY}

        line = form.addLine("", nil, false)
        form.addStaticText(line, posErr, str)

    else
        app.gfx_buttons["logs_logs"] = app.gfx_buttons["logs_logs"] or {}
        prefs.menulastselected["logs_logs"] = prefs.menulastselected["logs_logs"] or 1

        for idx, section in ipairs(dates) do

            form.addLine(format_date(section))
            local lc, y = 0, 0

            for pidx, page in ipairs(groupedLogs[section]) do

                if lc == 0 then y = form.height() + (prefs.general.iconsize == 2 and app.radio.buttonPadding or app.radio.buttonPaddingSmall) end

                local x = (buttonW + padding) * lc
                if prefs.general.iconsize ~= 0 then
                    if app.gfx_buttons["logs_logs"][pidx] == nil then app.gfx_buttons["logs_logs"][pidx] = lcd.loadMask("app/modules/logs/gfx/logs.png") end
                else
                    app.gfx_buttons["logs_logs"][pidx] = nil
                end

                app.formFields[pidx] = form.addButton(line, {x = x, y = y, w = buttonW, h = buttonH}, {
                    text = extractHourMinute(page),
                    icon = app.gfx_buttons["logs_logs"][pidx],
                    options = FONT_S,
                    paint = function() end,
                    press = function()
                        prefs.menulastselected["logs_logs"] = tostring(idx) .. "_" .. tostring(pidx)
                        app.ui.progressDisplay()
                        app.ui.openPage(pidx, "Logs", "logs/logs_view.lua", page)
                    end
                })

                if prefs.menulastselected["logs_logs"] == tostring(idx) .. "_" .. tostring(pidx) then app.formFields[pidx]:focus() end

                lc = (lc + 1) % numPerRow

            end

        end

    end

    if tasks.msp then app.triggers.closeProgressLoader = true end
    enableWakeup = true

    return
end

local function event(widget, category, value, x, y)
    if value == 35 then
        app.ui.openPage(app.lastIdx, app.lastTitle, "logs/logs_dir.lua")
        return true
    end
    return false
end

local function wakeup() end

local function onNavMenu() app.ui.openPage(app.lastIdx, app.lastTitle, "logs/logs_dir.lua") end

return {event = event, openPage = openPage, wakeup = wakeup, onNavMenu = onNavMenu, navButtons = {menu = true, save = false, reload = false, tool = false, help = true}, API = {}}
