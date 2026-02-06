--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local utils = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/app/modules/logs/lib/utils.lua"))()
local res = system.getVersion()
local LCD_W = res.lcdWidth
local LCD_H = res.lcdHeight

local graphPos = {}
graphPos['menu_offset'] = rfsuite.app.radio.logGraphMenuOffset
graphPos['height_offset'] = rfsuite.app.radio.logGraphHeightOffset or 0
graphPos['x_start'] = 0
graphPos['y_start'] = 0 + graphPos['menu_offset']
graphPos['width'] = math.floor(LCD_W * rfsuite.app.radio.logGraphWidthPercentage)
graphPos['key_width'] = LCD_W - graphPos['width']
graphPos['height'] = LCD_H - graphPos['menu_offset'] - graphPos['menu_offset'] - 40 + graphPos['height_offset']
graphPos['slider_y'] = LCD_H - (graphPos['menu_offset'] + 30) + graphPos['height_offset']

local zoomLevel = 1
local zoomCount = 5
local enableWakeup = false
local activeLogFile
local logPadding = 5

local logFileHandle = nil
local logDataRaw = {}
local logChunkSize = 1000
local logFileReadOffset = 0
local logDataRawReadComplete = false
local readNextChunk
local logData = {}
local maxMinData = {}
local progressLoader
local progressLoaderBaseMessage
local progressLoaderMspStatusLast
local logLineCount

local logColumns = rfsuite.tasks.logging.getLogTable()

local sliderPosition = 1
local sliderPositionOld = 1

local processedLogData = false
local currentDataIndex = 1

local paintCache = {points = {}, step_size = 0, position = 1, graphCount = 0, laneHeight = 0, currentLane = 0, decimationFactor = 1, needsUpdate = false}

local zoomLevelToDecimation = {[1] = 5, [2] = 4, [3] = 2, [4] = 1, [5] = 1}

local zoomLevelToTime = {[1] = 600, [2] = 300, [3] = 120, [4] = 60, [5] = 30}

local SAMPLE_RATE = 1
local function secondsToSamples(sec) return math.floor(sec * SAMPLE_RATE) end

local function setProgressLoaderMessage(baseMessage)
    if not progressLoader then return end
    progressLoaderBaseMessage = baseMessage
    local showMsp = rfsuite.preferences and rfsuite.preferences.developer and rfsuite.preferences.developer.mspstatusdialog
    local mspStatus = (showMsp and rfsuite.session and rfsuite.session.mspStatusMessage) or nil
    if mspStatus and mspStatus ~= "" then
        if #mspStatus > 32 then mspStatus = string.sub(mspStatus, 1, 29) .. "..." end
        progressLoader:message(baseMessage .. " [" .. mspStatus .. "]")
        progressLoaderMspStatusLast = mspStatus
    else
        progressLoader:message(baseMessage)
        progressLoaderMspStatusLast = nil
    end
end

local function refreshProgressLoaderMessage()
    if not progressLoader or not progressLoaderBaseMessage then return end
    local showMsp = rfsuite.preferences and rfsuite.preferences.developer and rfsuite.preferences.developer.mspstatusdialog
    local mspStatus = (showMsp and rfsuite.session and rfsuite.session.mspStatusMessage) or nil
    if mspStatus ~= progressLoaderMspStatusLast then
        if mspStatus and mspStatus ~= "" then
            if #mspStatus > 32 then mspStatus = string.sub(mspStatus, 1, 29) .. "..." end
            progressLoader:message(progressLoaderBaseMessage .. " [" .. mspStatus .. "]")
            progressLoaderMspStatusLast = mspStatus
        else
            progressLoader:message(progressLoaderBaseMessage)
            progressLoaderMspStatusLast = nil
        end
    end
end

local function readNextChunk()
    if logDataRawReadComplete then return end

    if not logFileHandle then
        system.messageBox("Log file handle lost.")
        return
    end

    logFileHandle:seek("set", logFileReadOffset)
    local chunk = logFileHandle:read(logChunkSize)

    if chunk then
        table.insert(logDataRaw, chunk)
        logFileReadOffset = logFileReadOffset + #chunk
        rfsuite.utils.log("Read " .. #chunk .. " bytes from log file", "debug")
    else
        logFileHandle:close()
        logFileHandle = nil
        logDataRawReadComplete = true
        logDataRaw = table.concat(logDataRaw)

        rfsuite.utils.log("Read complete, total size: " .. #logDataRaw .. " bytes", "debug")
    end
end

local function format_time(seconds)

    local minutes = math.floor(seconds / 60)
    local seconds_remainder = seconds % 60

    return string.format("%02d:%02d", minutes, seconds_remainder)
end

local function calculateZoomSteps(logLineCount)

    local logDurationSec = logLineCount / SAMPLE_RATE

    local maxZoomLevel = 1
    for level = 5, 1, -1 do
        local desiredTime = zoomLevelToTime[level]

        if logDurationSec >= desiredTime * 1.5 then
            maxZoomLevel = level
            break
        end
    end

    return maxZoomLevel
end

local function calculateSeconds(totalSeconds, sliderValue)

    if sliderValue < 1 or sliderValue > 100 then error("Slider value must be between 1 and 100") end

    local secondsPassed = math.floor(((sliderValue - 1) / 100) * totalSeconds)
    return secondsPassed
end

local function paginate_table(data, step_size, position, decimationFactor)
    decimationFactor = decimationFactor or 1

    local start_index = math.max(1, position)
    local end_index = math.min(start_index + step_size - 1, #data)

    local page = {}
    for i = start_index, end_index, decimationFactor do table.insert(page, data[i]) end

    return page
end

local function padTable(tbl, padCount)

    local first = tbl[1]
    local last = tbl[#tbl]

    local paddedTable = {}

    for i = 1, padCount do table.insert(paddedTable, first) end

    for _, value in ipairs(tbl) do table.insert(paddedTable, value) end

    for i = 1, padCount do table.insert(paddedTable, last) end

    return paddedTable
end

local function map(x, in_min, in_max, out_min, out_max) return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min end

local function getColumn(csvData, colIndex)
    local column = {}
    local start = 1
    local len = #csvData

    while start <= len do

        local newlinePos = csvData:find("\n", start)
        if not newlinePos then newlinePos = len + 1 end

        local row = csvData:sub(start, newlinePos - 1)

        local colStart = 1
        local colEnd = 1
        local colCount = 0
        while true do
            colEnd = row:find(",", colStart)
            if not colEnd then colEnd = #row + 1 end

            colCount = colCount + 1
            if colCount == colIndex then
                table.insert(column, row:sub(colStart, colEnd - 1))
                break
            end

            colStart = colEnd + 1
            if colEnd == #row + 1 then break end
        end

        start = newlinePos + 1
    end

    return column
end

local function cleanColumn(data)
    local out = {}
    for i, v in ipairs(data) do if i ~= 1 then out[i - 1] = tonumber(v) end end
    return out
end

local function getValueAtPercentage(array, percentage)

    if percentage < 0 or percentage > 100 then error("Percentage must be between 0 and 100") end

    local arraySize = #array
    if arraySize == 0 then error("Array cannot be empty") end

    local index = math.ceil((percentage / 100) * arraySize)
    return array[index]
end

local function extractShortTimestamp(filename)

    local date, time = filename:match(".-(%d%d%d%d%-%d%d%-%d%d)_(%d%d%-%d%d%-%d%d)")
    if date and time then return date:gsub("%-", "/") .. " " .. time:gsub("%-", ":") end
    return nil
end

local function drawGraph(points, color, pen, x_start, y_start, width, height, min_val, max_val)

    local padding = math.max(5, math.floor(height * 0.1))
    y_start = y_start + (padding / 2)
    height = height - padding

    for i, v in ipairs(points) do if type(v) ~= "number" then error("Point at index " .. i .. " is not a number") end end

    min_val = min_val or math.min(table.unpack(points))
    max_val = max_val or math.max(table.unpack(points))

    if max_val == min_val then
        max_val = max_val + 1
        min_val = min_val - 1
    end

    if color ~= nil then
        lcd.color(color)
    else
        lcd.color(COLOR_GREY)
    end
    if pen ~= nil then
        lcd.pen(pen)
    else
        lcd.pen(DOTTED)
    end

    local x_scale = width / (#points - 1)
    local y_scale = height / (max_val - min_val)

    for i = 1, #points - 1 do

        local x1 = x_start + (i - 1) * x_scale
        local y1 = y_start + height - (points[i] - min_val) * y_scale
        local x2 = x_start + i * x_scale
        local y2 = y_start + height - (points[i + 1] - min_val) * y_scale

        lcd.drawLine(x1, y1, x2, y2)
    end
end

local function drawKey(name, keyunit, keyminmax, keyfloor, color, minimum, maximum, laneY, laneHeight)
    local w = LCD_W - graphPos['width'] - 10
    local boxpadding = 3

    lcd.font(rfsuite.app.radio.logKeyFont)
    local _, th = lcd.getTextSize(name)
    local boxHeight = th + boxpadding

    local x = graphPos['width']
    local y = laneY

    if keyfloor then
        minimum = math.floor(minimum)
        maximum = math.floor(maximum)
    end

    lcd.color(color)
    lcd.drawFilledRectangle(x, y, w, boxHeight)

    lcd.color(COLOR_BLACK)
    local textY = y + (boxHeight / 2 - th / 2)
    lcd.drawText(x + 5, textY, name, LEFT)

    lcd.font(rfsuite.app.radio.logKeyFontSmall)
    if lcd.darkMode() then
        lcd.color(COLOR_WHITE)
    else
        lcd.color(COLOR_BLACK)
    end

    local min_trunc
    if keyunit == "rpm" and (minimum >= 10000 or maximum >= 10000) then
        min_trunc = string.format("%.1fK", minimum / 10000)
        max_trunc = string.format("%.1fK", maximum / 10000)
    end

    local max_str
    local min_str
    if keyminmax == 1 then
        min_str = "↓ " .. (min_trunc or minimum) .. keyunit
        max_str = " ↑ " .. (max_trunc or maximum) .. keyunit
    else
        min_str = ""
        max_str = "↑ " .. (max_trun or maximum) .. keyunit
    end

    local mmY = y + boxHeight + 2
    lcd.drawText(x + 5, mmY, min_str, LEFT)

    local tw, th = lcd.getTextSize(max_str)
    lcd.drawText((LCD_W - tw) + boxpadding, mmY, max_str, LEFT)

    if rfsuite.app.radio.logShowAvg == true then
        local avg_str = "Ø " .. math.floor((minimum + maximum) / 2) .. keyunit
        local avgY = mmY + th - 2
        lcd.drawText(x + 5, avgY, avg_str, LEFT)
    end
end

local function drawCurrentIndex(points, position, totalPoints, keyindex, keyunit, keyfloor, name, color, laneY, laneHeight, laneNumber, totalLanes)
    if position < 1 then position = 1 end

    local sliderPadding = rfsuite.app.radio.logSliderPaddingLeft
    local w = graphPos['width'] - sliderPadding

    local linePos = map(position, 1, 100, 1, w - 10) + sliderPadding
    if linePos < 1 then linePos = 0 end

    local boxpadding = 3

    local idxPos, textAlign, boxPos
    if position > 50 then
        idxPos = linePos - (boxpadding * 2)
        textAlign = RIGHT
        boxPos = linePos - boxpadding
    else
        idxPos = linePos + (boxpadding * 2)
        textAlign = LEFT
        boxPos = linePos + boxpadding
    end

    local value = getValueAtPercentage(points, position)
    if keyfloor then value = math.floor(value) end
    value = value .. keyunit

    lcd.font(rfsuite.app.radio.logKeyFont)
    local tw, th = lcd.getTextSize(value)

    local boxHeight = th + boxpadding
    local boxY = laneY
    local textY = boxY + (boxHeight / 2 - th / 2)

    if position > 50 then boxPos = boxPos - tw - (boxpadding * 2) end

    lcd.color(color)
    lcd.drawFilledRectangle(boxPos, boxY, tw + (boxpadding * 2), boxHeight)

    if lcd.darkMode() then
        lcd.color(COLOR_BLACK)
    else
        lcd.color(COLOR_WHITE)
    end
    lcd.drawText(idxPos, textY, value, textAlign)

    if laneNumber == 1 then
        local current_s = calculateSeconds(totalPoints, position)
        local time_str = format_time(math.floor(current_s))

        local logDurSec = math.floor(logLineCount / SAMPLE_RATE)
        local desiredWinSec = zoomLevelToTime[zoomLevel] or zoomLevelToTime[1]
        local windowSec = math.min(desiredWinSec, logDurSec)
        local win_label
        if windowSec < 60 then
            win_label = string.format("%ds", windowSec)
        else
            win_label = string.format("%d:%02d", math.floor(windowSec / 60), windowSec % 60)
        end

        local full_label = string.format("%s [+%s]", time_str, win_label)

        lcd.font(rfsuite.app.radio.logKeyFont)
        local ty = graphPos['height'] + graphPos['menu_offset'] - 10

        lcd.color(COLOR_WHITE)
        lcd.drawText(idxPos, ty, full_label, textAlign)

        if lcd.darkMode() then
            lcd.color(COLOR_WHITE)
        else
            lcd.color(COLOR_BLACK)
        end
        lcd.drawLine(linePos, graphPos['menu_offset'] - 5, linePos, graphPos['menu_offset'] + graphPos['height'])

        if lcd.darkMode() then
            lcd.color(lcd.RGB(40, 40, 40))
        else
            lcd.color(lcd.RGB(240, 240, 240))
        end

        local z_x = (LCD_W - 25)
        local z_y = graphPos['slider_y']
        local z_w = 20
        local z_h = 40
        local z_lh = z_h / zoomCount

        local lineOffsetY = (zoomCount - zoomLevel) * z_lh

        lcd.drawFilledRectangle(z_x, z_y, z_w, z_h)

        if zoomCount > 1 then
            if lcd.darkMode() then
                lcd.color(COLOR_WHITE)
            else
                lcd.color(COLOR_BLACK)
            end
        else
            lcd.color(COLOR_GREY)
        end
        lcd.drawFilledRectangle(z_x, z_y + lineOffsetY, z_w, z_lh)
    end
end

local function findMaxNumber(numbers)
    local max = numbers[1]
    for i = 2, #numbers do if numbers[i] > max then max = numbers[i] end end
    return max
end

local function findMinNumber(numbers)
    local min = numbers[1]
    for i = 2, #numbers do if numbers[i] < min then min = numbers[i] end end
    return min
end

local function findAverage(numbers)
    local sum = 0
    for i = 1, #numbers do sum = sum + numbers[i] end
    local average = sum / #numbers
    return average
end

local function openPage(pidx, title, script, logfile, displaymode, dirname)

    rfsuite.tasks.msp.protocol.mspIntervalOveride = nil

    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.pages

    form.clear()

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    local err

    local name = utils.resolveModelName(rfsuite.session.mcu_id or rfsuite.app.activeLogDir)
    rfsuite.app.ui.fieldHeader("Logs / " .. name .. " / " .. extractShortTimestamp(logfile))
    activeLogFile = logfile

    local filePath

    if rfsuite.app.activeLogDir then
        filePath = utils.getLogDir(rfsuite.app.activeLogDir) .. "/" .. logfile
    else
        filePath = utils.getLogDir() .. "/" .. logfile
    end
    logFileHandle, err = io.open(filePath, "rb")

    local posField = {x = graphPos['x_start'], y = graphPos['slider_y'], w = graphPos['width'] - 10, h = 40}
    rfsuite.app.formFields[1] = form.addSliderField(nil, posField, 0, 100, function() return sliderPosition end, function(newValue) sliderPosition = newValue end)

    local zoomButtonWidth = (graphPos['key_width'] / 2) - 20

    local posField = {x = graphPos['width'], y = graphPos['slider_y'], w = zoomButtonWidth, h = 40}
    rfsuite.app.formFields[2] = form.addButton(line, posField, {
        text = "-",
        icon = nil,
        options = FONT_STD,
        press = function()
            if zoomLevel > 1 then
                zoomLevel = zoomLevel - 1
                paintCache.needsUpdate = true
                lcd.invalidate()
                rfsuite.app.formFields[2]:enable(true)
                rfsuite.app.formFields[3]:enable(true)
            end
            if zoomLevel == 1 then
                rfsuite.app.formFields[2]:enable(false)
                rfsuite.app.formFields[3]:focus()
            end
        end
    })

    rfsuite.app.formFields[2]:enable(false)

    local posField = {x = graphPos['width'] + zoomButtonWidth + 10, y = graphPos['slider_y'], w = zoomButtonWidth, h = 40}
    rfsuite.app.formFields[3] = form.addButton(line, posField, {
        text = "+",
        icon = nil,
        options = FONT_STD,
        press = function()
            if zoomLevel < zoomCount then
                zoomLevel = zoomLevel + 1
                paintCache.needsUpdate = true
                lcd.invalidate()
                rfsuite.app.formFields[2]:enable(true)
                rfsuite.app.formFields[3]:enable(true)
            end
            if zoomLevel == zoomCount then
                rfsuite.app.formFields[3]:enable(false)
                rfsuite.app.formFields[2]:focus()
            end
        end
    })

    rfsuite.app.formFields[1]:step(1)

    logDataRaw = {}
    logFileReadOffset = 0
    logDataRawReadComplete = false

    rfsuite.app.triggers.closeProgressLoader = true
    lcd.invalidate()
    enableWakeup = true
    return
end

local function event(event, category, value, x, y)
    if value == 35 then
        rfsuite.app.ui.openPage(rfsuite.app.lastIdx, rfsuite.app.lastTitle, "logs/logs_logs.lua")
        return true
    end
    return false
end

local slowcount = 0
local carriedOver = nil
local subStepSize = nil

local function updatePaintCache()
    if not logData or not processedLogData then return end

    local logDurSec = math.floor(logLineCount / SAMPLE_RATE)
    local desiredWinSec = zoomLevelToTime[zoomLevel] or zoomLevelToTime[1]
    local winSec = math.min(desiredWinSec, logDurSec)
    paintCache.step_size = secondsToSamples(winSec)

    local maxPosition = math.max(1, logLineCount - paintCache.step_size + 1)
    paintCache.position = math.floor(map(sliderPosition, 1, 100, 1, maxPosition))
    if paintCache.position < 1 then paintCache.position = 1 end

    paintCache.graphCount = 0
    for _, v in ipairs(logData) do if v.graph then paintCache.graphCount = paintCache.graphCount + 1 end end

    paintCache.laneHeight = graphPos['height'] / paintCache.graphCount
    paintCache.currentLane = 0
    paintCache.decimationFactor = zoomLevelToDecimation[zoomLevel] or 1

    if zoomCount == 1 then paintCache.decimationFactor = 1 end

    paintCache.points = {}

    for _, v in ipairs(logData) do
        if v.graph then
            paintCache.currentLane = paintCache.currentLane + 1
            paintCache.points[paintCache.currentLane] = {points = paginate_table(v.data, paintCache.step_size, paintCache.position, paintCache.decimationFactor), color = v.color, pen = v.pen, minimum = v.minimum, maximum = v.maximum, keyname = v.keyname, keyunit = v.keyunit, keyminmax = v.keyminmax, keyfloor = v.keyfloor, name = v.name, keyindex = v.keyindex}
        end
    end

    paintCache.needsUpdate = false
end

local function wakeup()
    if not enableWakeup then return end

    if sliderPosition ~= sliderPositionOld or paintCache.needsUpdate then
        updatePaintCache()
        lcd.invalidate()
        sliderPositionOld = sliderPosition
    end

    if logFileHandle and not logDataRawReadComplete then
        readNextChunk()
        return
    end

    if not progressLoader then
        progressLoader = form.openProgressDialog("Processing", "Loading log data")
        progressLoader:closeAllowed(false)
        setProgressLoaderMessage("Loading log data")
        rfsuite.app.ui.registerProgressDialog(progressLoader, progressLoaderBaseMessage or "Loading log data")
    end

    refreshProgressLoaderMessage()

    if not logDataRawReadComplete then
        progressLoader:value(slowcount)
        slowcount = slowcount + 0.025
        return
    end

    if logDataRawReadComplete and not processedLogData then

        if not carriedOver then

            rfsuite.app.formNavigationFields['menu']:focus(true)
            carriedOver = slowcount
            subStepSize = (100 - carriedOver) / (#logColumns * 5)
        end

        local function updateProgress(subStep)
            local overallProgress = carriedOver + ((currentDataIndex - 1) * (subStepSize * 5)) + (subStep * subStepSize)
            progressLoader:value(overallProgress)
        end

        logData[currentDataIndex] = {}
        logData[currentDataIndex]['name'] = logColumns[currentDataIndex].name
        logData[currentDataIndex]['color'] = logColumns[currentDataIndex].color
        logData[currentDataIndex]['pen'] = logColumns[currentDataIndex].pen
        logData[currentDataIndex]['keyindex'] = logColumns[currentDataIndex].keyindex
        logData[currentDataIndex]['keyname'] = logColumns[currentDataIndex].keyname
        logData[currentDataIndex]['keyunit'] = logColumns[currentDataIndex].keyunit
        logData[currentDataIndex]['keyminmax'] = logColumns[currentDataIndex].keyminmax
        logData[currentDataIndex]['keyfloor'] = logColumns[currentDataIndex].keyfloor
        logData[currentDataIndex]['graph'] = logColumns[currentDataIndex].graph

        updateProgress(1)
        local rawColumn = getColumn(logDataRaw, currentDataIndex + 1)
        local cleanedColumn = cleanColumn(rawColumn)

        updateProgress(2)
        logData[currentDataIndex]['data'] = padTable(cleanedColumn, logPadding)

        updateProgress(3)
        logData[currentDataIndex]['maximum'] = findMaxNumber(logData[currentDataIndex]['data'])

        updateProgress(4)
        logData[currentDataIndex]['minimum'] = findMinNumber(logData[currentDataIndex]['data'])

        updateProgress(5)
        logData[currentDataIndex]['average'] = findAverage(logData[currentDataIndex]['data'])

        setProgressLoaderMessage("Processing data " .. currentDataIndex .. " of " .. #logColumns)

        if currentDataIndex >= #logColumns then
            logLineCount = #logData[currentDataIndex]['data']

            zoomCount = calculateZoomSteps(logLineCount)
            if zoomLevel > zoomCount then zoomLevel = zoomCount end

            local btnMinus = rfsuite.app.formFields[2]
            local btnPlus = rfsuite.app.formFields[3]
            if zoomCount <= 1 then
                btnMinus:enable(false);
                btnPlus:enable(false)
            else
                btnMinus:enable(zoomLevel > 1)
                btnPlus:enable(zoomLevel < zoomCount)
            end

            progressLoader:close()
            rfsuite.app.ui.clearProgressDialog(progressLoader)
            progressLoaderBaseMessage = nil
            progressLoaderMspStatusLast = nil
            processedLogData = true
            paintCache.needsUpdate = true
            lcd.invalidate()
        end

        currentDataIndex = currentDataIndex + 1
        return
    end
end

local function paint()
    local menu_offset = graphPos['menu_offset']
    local x_start = graphPos['x_start']
    local y_start = graphPos['y_start']
    local width = graphPos['width'] - 10
    local height = graphPos['height']

    if enableWakeup and processedLogData then
        if paintCache.points and #paintCache.points > 0 then
            for laneNumber, laneData in ipairs(paintCache.points) do
                local laneY = y_start + (laneNumber - 1) * paintCache.laneHeight

                drawGraph(laneData.points, laneData.color, laneData.pen, x_start, laneY, width, paintCache.laneHeight, laneData.minimum, laneData.maximum)
                drawKey(laneData.keyname, laneData.keyunit, laneData.keyminmax, laneData.keyfloor, laneData.color, laneData.minimum, laneData.maximum, laneY, paintCache.laneHeight)
                drawCurrentIndex(laneData.points, sliderPosition, logLineCount + logPadding, laneData.keyindex, laneData.keyunit, laneData.keyfloor, laneData.name, laneData.color, laneY, paintCache.laneHeight, laneNumber, paintCache.graphCount)
            end
        end
    end
end

local function onNavMenu(self)
    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(rfsuite.app.lastIdx, rfsuite.app.lastTitle, "logs/logs_logs.lua")
end

return {event = event, openPage = openPage, wakeup = wakeup, paint = paint, onNavMenu = onNavMenu, navButtons = {menu = true, save = false, reload = false, tool = false, help = true}, API = {}}
