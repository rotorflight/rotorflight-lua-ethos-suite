local utils = assert(rfsuite.compiler.loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/app/modules/logs/lib/utils.lua"))()

local triggerOverRide = false
local triggerOverRideAll = false
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
    -- Capture hour and minute from the time-portion (HH-MM-SS) after the underscore
    local hour, minute = filename:match(".-%d%d%d%d%-%d%d%-%d%d_(%d%d)%-(%d%d)%-%d%d")
    if hour and minute then
        return hour .. ":" .. minute
    end
    return nil
end

local function format_date(iso_date)
  local y, m, d = iso_date:match("^(%d+)%-(%d+)%-(%d+)$")
  return os.date("%d %B %Y", os.time{
    year  = tonumber(y),
    month = tonumber(m),
    day   = tonumber(d),
  })
end

local function openPage(pidx, title, script, displaymode)

    -- hard exit on error
    if not rfsuite.utils.ethosVersionAtLeast() then
        return
    end

    if not rfsuite.tasks.active() then

        local buttons = {{
            label = "@i18n(app.btn_ok)@",
            action = function()

                rfsuite.app.triggers.exitAPP = true
                rfsuite.app.dialogs.nolinkDisplayErrorDialog = false
                return true
            end
        }}

        form.openDialog({
            width = nil,
            title = "@i18n(error)@",
            message = "@i18n(app.check_bg_task)@",
            buttons = buttons,
            wakeup = function()
            end,
            paint = function()
            end,
            options = TEXT_LEFT
        })

    end


    currentDisplayMode = displaymode

    if rfsuite.tasks.msp then
        rfsuite.tasks.msp.protocol.mspIntervalOveride = nil
    end

    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.pages

    form.clear()

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    local w, h = lcd.getWindowSize()
    local windowWidth = w
    local windowHeight = h
    local padding = rfsuite.app.radio.buttonPadding

    local sc
    local panel

     local logDir = utils.getLogPath()

    local logs = utils.getLogs(logDir)   


    local name = utils.resolveModelName(rfsuite.session.mcu_id or rfsuite.app.activeLogDir)
    rfsuite.app.ui.fieldHeader("Logs / " .. name)

    local buttonW
    local buttonH
    local padding
    local numPerRow

   if rfsuite.preferences.general.iconsize == 0 then
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = (rfsuite.app.lcdWidth - padding) / rfsuite.app.radio.buttonsPerRow - padding
        buttonH = rfsuite.app.radio.navbuttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end
    -- SMALL ICONS
    if rfsuite.preferences.general.iconsize == 1 then

        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = rfsuite.app.radio.buttonWidthSmall
        buttonH = rfsuite.app.radio.buttonHeightSmall
        numPerRow = rfsuite.app.radio.buttonsPerRowSmall
    end
    -- LARGE ICONS
    if rfsuite.preferences.general.iconsize == 2 then

        padding = rfsuite.app.radio.buttonPadding
        buttonW = rfsuite.app.radio.buttonWidth
        buttonH = rfsuite.app.radio.buttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end


    local x = windowWidth - buttonW + 10

    local lc = 0
    local bx = 0

    if rfsuite.app.gfx_buttons["logs_logs"] == nil then rfsuite.app.gfx_buttons["logs_logs"] = {} end
    if rfsuite.preferences.menulastselected["logs"] == nil then rfsuite.preferences.menulastselected["logs_logs"] = 1 end

    if rfsuite.app.gfx_buttons["logs"] == nil then rfsuite.app.gfx_buttons["logs"] = {} end
    if rfsuite.preferences.menulastselected["logs_logs"] == nil then rfsuite.preferences.menulastselected["logs_logs"] = 1 end

    -- Group logs by date
    local groupedLogs = {}
    for _, filename in ipairs(logs) do
        local datePart = filename:match("(%d%d%d%d%-%d%d%-%d%d)_")
        if datePart then
            groupedLogs[datePart] = groupedLogs[datePart] or {}
            table.insert(groupedLogs[datePart], filename)
        end
    end

    -- Sort dates descending
    local dates = {}
    for date,_ in pairs(groupedLogs) do table.insert(dates, date) end
    table.sort(dates, function(a,b) return a > b end)


    if #dates == 0 then

        LCD_W, LCD_H = lcd.getWindowSize()
        local str = "@i18n(app.modules.logs.msg_no_logs_found)@"
        local ew = LCD_W
        local eh = LCD_H
        local etsizeW, etsizeH = lcd.getTextSize(str)
        local eposX = ew / 2 - etsizeW / 2
        local eposY = eh / 2 - etsizeH / 2

        local posErr = {w = etsizeW, h = rfsuite.app.radio.navbuttonHeight, x = eposX, y = ePosY}

        line = form.addLine("", nil, false)
        form.addStaticText(line, posErr, str)

    else
        rfsuite.app.gfx_buttons["logs_logs"] = rfsuite.app.gfx_buttons["logs_logs"] or {}
        rfsuite.preferences.menulastselected["logs_logs"] = rfsuite.preferences.menulastselected["logs_logs"] or 1

        for idx, section in ipairs(dates) do

                form.addLine(format_date(section))
                local lc, y = 0, 0

                for pidx, page in ipairs(groupedLogs[section]) do

                            if lc == 0 then
                                y = form.height() + (rfsuite.preferences.general.iconsize == 2 and rfsuite.app.radio.buttonPadding or rfsuite.app.radio.buttonPaddingSmall)
                            end

                            local x = (buttonW + padding) * lc
                            if rfsuite.preferences.general.iconsize ~= 0 then
                                if rfsuite.app.gfx_buttons["logs_logs"][pidx] == nil then rfsuite.app.gfx_buttons["logs_logs"][pidx] = lcd.loadMask("app/modules/logs/gfx/logs.png") end
                            else
                                rfsuite.app.gfx_buttons["logs_logs"][pidx] = nil
                            end

                            rfsuite.app.formFields[pidx] = form.addButton(line, {x = x, y = y, w = buttonW, h = buttonH}, {
                                text = extractHourMinute(page),
                                icon = rfsuite.app.gfx_buttons["logs_logs"][pidx],
                                options = FONT_S,
                                paint = function() end,
                                press = function()
                                    rfsuite.preferences.menulastselected["logs_logs"] = tostring(idx) .. "_" .. tostring(pidx)
                                    rfsuite.app.ui.progressDisplay()
                                    rfsuite.app.ui.openPage(pidx, "Logs", "logs/logs_view.lua", page)                       
                                end
                            })

                            if rfsuite.preferences.menulastselected["logs_logs"] == tostring(idx) .. "_" .. tostring(pidx) then
                                rfsuite.app.formFields[pidx]:focus()
                            end

                            lc = (lc + 1) % numPerRow

                end

        end   

            
    end

    if rfsuite.tasks.msp then
        rfsuite.app.triggers.closeProgressLoader = true
    end
    enableWakeup = true

    return
end

local function event(widget, category, value, x, y)
    if  value == 35 then
        rfsuite.app.ui.openPage(rfsuite.app.lastIdx, rfsuite.app.lastTitle, "logs/logs_dir.lua")
        return true
    end
    return false
end

local function wakeup()

    if enableWakeup == true then

    end

end

local function onNavMenu()

      rfsuite.app.ui.openPage(rfsuite.app.lastIdx, rfsuite.app.lastTitle, "logs/logs_dir.lua")


end

return {
    event = event,
    openPage = openPage,
    wakeup = wakeup,
    onNavMenu = onNavMenu,
    navButtons = {
        menu = true,
        save = false,
        reload = false,
        tool = false,
        help = true
    },
    API = {},
}
