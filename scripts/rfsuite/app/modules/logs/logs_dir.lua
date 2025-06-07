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
    -- make sure folder exists
    os.mkdir("LOGS:")
    os.mkdir("LOGS:/rfsuite")
    os.mkdir("LOGS:/rfsuite/telemetry")
    if rfsuite.session.activeLogDir  then 
         return "LOGS:/rfsuite/telemetry/" .. rfsuite.session.activeLogDir .. "/"
    end
    return "LOGS:/rfsuite/telemetry/" 
end

local function getLogs(logDir)

    local files = system.listFiles(logDir)
    local csvFiles = {}

    -- Extract CSV files and parse date-time from filenames
    for i = 1, #files do
        if files[i] ~= ".." and files[i]:sub(-4) == ".csv" then
            local datePart, timePart = files[i]:match("(%d%d%d%d%-%d%d%-%d%d)_(%d%d%-%d%d%-%d%d)_")
            if datePart and timePart then
                local sortableDateTime = datePart .. "T" .. timePart -- Concatenating for sorting
                table.insert(csvFiles, {filename = files[i], datetime = sortableDateTime})
            end
        end
    end

    -- Sort files by extracted date-time string
    table.sort(csvFiles, function(a, b)
        return a.datetime > b.datetime -- Sort in descending order (latest first)
    end)

    -- Limit to a maximum of 50 entries
    local maxEntries = 50
    local result = {}
    for i = 1, math.min(#csvFiles, maxEntries) do table.insert(result, csvFiles[i].filename) end

    -- Delete the remaining files outside the truncated list
    for i = maxEntries + 1, #csvFiles do os.remove(logDir .. "/" .. csvFiles[i].filename) end

    return result
end

local function getLogsDir(logDir)

    local files = system.listFiles(logDir)
    local folders = {}

    -- Extract CSV files and parse date-time from filenames
    for i = 1, #files do
        if files[i]:sub(1,1) ~= "." then
            table.insert(folders, {foldername = files[i]})
        end
    end

    return folders
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

local function resolveModelName(foldername)
    if foldername == nil then return "Unknown" end

    local iniName = "LOGS:rfsuite/telemetry/" .. foldername .. "/logs.ini"
    local iniData = rfsuite.ini.load_ini_file(iniName) or {}

    if iniData["model"] and iniData["model"].name then
        return iniData["model"].name
    end
    return "Unknown"
end

local function openPage(pidx, title, script)
    rfsuite.session.activeLogDir = nil
    -- hard exit on error
    if not rfsuite.utils.ethosVersionAtLeast() then
        return
    end

    if rfsuite.tasks.msp then
        rfsuite.tasks.msp.protocol.mspIntervalOveride = nil
    end

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

   if rfsuite.preferences.general.iconsize == 0 then
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = (rfsuite.session.lcdWidth - padding) / rfsuite.app.radio.buttonsPerRow - padding
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

    if rfsuite.app.gfx_buttons["logs"] == nil then rfsuite.app.gfx_buttons["logs"] = {} end
    if rfsuite.preferences.menulastselected["logs"] == nil then rfsuite.preferences.menulastselected["logs"] = 1 end

    if rfsuite.app.gfx_buttons["logs"] == nil then rfsuite.app.gfx_buttons["logs"] = {} end
    if rfsuite.preferences.menulastselected["logs"] == nil then rfsuite.preferences.menulastselected["logs"] = 1 end

    local logDir = getLogPath()

    local logs = getLogsDir(logDir)

    if #logs == 0 then

        LCD_W, LCD_H = rfsuite.utils.getWindowSize()
        local str = rfsuite.i18n.get("app.modules.logs.msg_no_logs_found")
        local ew = LCD_W
        local eh = LCD_H
        local etsizeW, etsizeH = lcd.getTextSize(str)
        local eposX = ew / 2 - etsizeW / 2
        local eposY = eh / 2 - etsizeH / 2

        local posErr = {w = etsizeW, h = rfsuite.app.radio.navbuttonHeight, x = eposX, y = ePosY}

        line = form.addLine("", nil, false)
        form.addStaticText(line, posErr, str)

    else

        for pidx, item in ipairs(logs) do

        if lc == 0 then
            if rfsuite.preferences.general.iconsize == 0 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.preferences.general.iconsize == 1 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.preferences.general.iconsize == 2 then y = form.height() + rfsuite.app.radio.buttonPadding end
        end

        if lc >= 0 then bx = (buttonW + padding) * lc end

            local name = resolveModelName(item.foldername)

            if rfsuite.preferences.general.iconsize ~= 0 then
                if rfsuite.app.gfx_buttons["logs"][pidx] == nil then rfsuite.app.gfx_buttons["logs"][pidx] = lcd.loadMask("app/modules/logs/folder.png") end
            else
                rfsuite.app.gfx_buttons["logs"][pidx] = nil
            end


            rfsuite.app.formFields[pidx] = form.addButton(nil, {x = bx, y = y, w = buttonW, h = buttonH}, {
                text = name,
                options = FONT_S,
                icon = rfsuite.app.gfx_buttons["logs"][pidx],
                paint = function()
                end,
                press = function()
                    rfsuite.preferences.menulastselected["logs"] = pidx
                    rfsuite.app.ui.progressDisplay()
                    rfsuite.session.activeLogDir = item.foldername
                    rfsuite.utils.log("Opening logs for: " .. item.foldername,"info")
                    rfsuite.app.ui.openPage(pidx, "Logs", "logs/logs_logs.lua", name)
                    
                end
            })

            rfsuite.app.formFields[pidx]:enable(true)

            if rfsuite.preferences.menulastselected["logs_folder"] == pidx then rfsuite.app.formFields[pidx]:focus() end

            lc = lc + 1

            if lc == numPerRow then lc = 0 end

        end
    end

    if rfsuite.tasks.msp then
        rfsuite.app.triggers.closeProgressLoader = true
    end
    enableWakeup = true

    return
end

local function event(widget, category, value, x, y)
    if value == 35 then
        rfsuite.app.ui.openMainMenu()
        return true
    end
    return false
end

local function wakeup()

    if enableWakeup == true then

    end

end

local function onNavMenu()

        rfsuite.app.ui.openMainMenu()


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
