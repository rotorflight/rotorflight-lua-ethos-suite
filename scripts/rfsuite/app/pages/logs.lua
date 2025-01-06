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

-- Helper function to check if directory exists
local function dir_exists(base, name)
    base = base or "./"
    for _, v in pairs(system.listFiles(base)) do if v == name then return true end end
    return false
end

local function getModelName()
    local logdir
    logdir = string.gsub(model.name(), "%s+", "_")
    logdir = string.gsub(logdir, "%W", "_")
    return logdir
end

local function getLogPath()

    -- do some checks to make sure stuff exists
    local base_path = (rfsuite.utils.ethosVersionToMinor() >= 16) and "./" or (rfsuite.config.suiteDir .. "/")
    local logs_path = (rfsuite.utils.ethosVersionToMinor() >= 16) and "logs" or (rfsuite.config.suiteDir .. "/logs")
    local logs_path_telemetry = (rfsuite.utils.ethosVersionToMinor() >= 16) and "logs/telemetry" or (rfsuite.config.suiteDir .. "/logs/telemetry")

    if not dir_exists(base_path, logs_path) then os.mkdir(logs_path) end
    if not dir_exists(logs_path_telemetry) then os.mkdir(logs_path_telemetry) end

    return logs_path_telemetry
end

local function getLogs(logDir)
    local files = system.listFiles(logDir)

    local reversed = {}
    for i = #files, 1, -1 do
        if files[i] ~= ".." and files[i]:sub(-4) == ".csv" then -- Check for .csv files and skip ".."
            table.insert(reversed, files[i])
        end
    end

    -- Limit to a maximum of 50 entries
    local maxEntries = 50
    local result = {}
    for i = 1, math.min(#reversed, maxEntries) do table.insert(result, reversed[i]) end

    -- Call deleteData for the remaining files outside the truncated list
    for i = maxEntries + 1, #reversed do os.remove(logDir .. "/" .. reversed[i]) end

    return result
end

local function extractShortTimestamp(filename)
    -- Match the date and time components in the filename, ignoring the prefix
    local date, time = filename:match(".-(%d%d%d%d%-%d%d%-%d%d)_(%d%d%-%d%d%-%d%d)")
    if date and time then
        -- Replace dashes with slashes or colons for a compact format
        return date:gsub("%-", "/") .. " " .. time:gsub("%-", ":")
    end
    return nil -- Return nil if the pattern doesn't match
end

function extractName(input)
    -- Match everything before the first underscore followed by a date pattern
    local name = input:match("^(.-)_%d%d%d%d%-%d%d%-%d%d")
    return name
end

local function openPage(pidx, title, script, displaymode)

    currentDisplayMode = displaymode

    rfsuite.bg.msp.protocol.mspIntervalOveride = nil

    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.pages

    form.clear()

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    local w, h = rfsuite.utils.getWindowSize()
    local windowWidth = w
    local windowHeight = h
    local padding = rfsuite.app.radio.buttonPadding

    local sc
    local panel

    rfsuite.app.ui.fieldHeader("Logs")

    local buttonW
    local buttonH
    local padding
    local numPerRow

    padding = rfsuite.app.radio.buttonPaddingSmall
    buttonW = (rfsuite.config.lcdWidth - padding) / (rfsuite.app.radio.logGraphButtonsPerRow - 1) - padding
    buttonH = rfsuite.app.radio.navbuttonHeight
    numPerRow = rfsuite.app.radio.buttonsPerRow - 1

    local x = windowWidth - buttonW + 10

    local lc = 0
    local bx = 0

    if rfsuite.app.gfx_buttons["logs"] == nil then rfsuite.app.gfx_buttons["logs"] = {} end
    if rfsuite.app.menuLastSelected["logs"] == nil then rfsuite.app.menuLastSelected["logs"] = 1 end

    if rfsuite.app.gfx_buttons["logs"] == nil then rfsuite.app.gfx_buttons["logs"] = {} end
    if rfsuite.app.menuLastSelected["logs"] == nil then rfsuite.app.menuLastSelected["logs"] = 1 end

    local logDir = getLogPath()

    local logs = getLogs(logDir)

    if #logs == 0 then

        LCD_W, LCD_H = rfsuite.utils.getWindowSize()
        local str = "NO LOG FILES FOUND"
        local ew = LCD_W
        local eh = LCD_H
        local etsizeW, etsizeH = lcd.getTextSize(str)
        local eposX = ew / 2 - etsizeW / 2
        local eposY = eh / 2 - etsizeH / 2

        local posErr = {w = etsizeW, h = rfsuite.app.radio.navbuttonHeight, x = eposX, y = ePosY}

        line = form.addLine("", nil, false)
        form.addStaticText(line, posErr, str)

    else

        for pidx, name in ipairs(logs) do

            if lc == 0 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end

            if lc >= 0 then bx = (buttonW + padding) * lc end

            rfsuite.app.formFields[pidx] = form.addButton(nil, {x = bx, y = y, w = buttonW, h = buttonH}, {
                text = extractShortTimestamp(name),
                options = FONT_S,
                paint = function()
                end,
                press = function()
                    rfsuite.app.menuLastSelected["logs"] = pidx
                    rfsuite.app.ui.progressDisplay()
                    rfsuite.app.ui.openPage(pidx, "Logs", "logs_tool.lua", name, currentDisplayMode)
                end
            })

            rfsuite.app.formFields[pidx]:enable(true)

            if rfsuite.app.menuLastSelected["logs"] == pidx then rfsuite.app.formFields[pidx]:focus() end

            lc = lc + 1

            if lc == numPerRow then lc = 0 end

        end
    end

    rfsuite.app.triggers.closeProgressLoader = true

    enableWakeup = true

    return
end

local function event(widget, category, value, x, y)

    -- if category == 5 or value == 35 then
    --    rfsuite.app.Page.onNavMenu(self)
    --    return true
    -- end

    return false
end

local function wakeup()

    if enableWakeup == true then
        -- local now = os.clock()
        -- if (now - wakeupScheduler) >= 0.5 then
        -- end   
    end

end

local function onNavMenu()

    if currentDisplayMode == 1 then
        system.exit()
    else
        rfsuite.app.ui.openMainMenu()
    end

end

return {title = "Logs", event = event, openPage = openPage, wakeup = wakeup, onNavMenu = onNavMenu, navButtons = {menu = true, save = false, reload = false, tool = false, help = true}}
