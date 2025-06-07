local enableWakeup = false

-- Returns a filesystem-safe model name
local function getModelName()
    local name = model.name()
    name = name:gsub("%s+", "_"):gsub("%W", "_")
    return name
end

-- Ensures the log directory exists and returns its path
local function getLogPath()
    os.mkdir("LOGS:")
    os.mkdir("LOGS:/rfsuite")
    os.mkdir("LOGS:/rfsuite/telemetry")
    if rfsuite.session.activeLogDir then
        return string.format("LOGS:/rfsuite/telemetry/%s/", rfsuite.session.activeLogDir)
    end
    return "LOGS:/rfsuite/telemetry/"
end

-- Retrieves up to `maxEntries` most recent CSV log files and cleans up older ones
local function getLogs(logDir)
    local files = system.listFiles(logDir)
    local entries = {}
    for _, fname in ipairs(files) do
        if fname:match("%.csv$") then
            local date, time = fname:match("(%d%d%d%d%-%d%d%-%d%d)_(%d%d%-%d%d%-%d%d)_")
            if date and time then
                table.insert(entries, {name = fname, ts = date .. 'T' .. time})
            end
        end
    end

    table.sort(entries, function(a, b) return a.ts > b.ts end)
    local maxEntries = 50
    for i = maxEntries + 1, #entries do
        os.remove(logDir .. "/" .. entries[i].name)
    end
    local result = {}
    for i = 1, math.min(#entries, maxEntries) do
        result[#result+1] = entries[i].name
    end
    return result
end

-- Lists subdirectories in a log directory
local function getLogsDir(logDir)
    local files = system.listFiles(logDir)
    local dirs = {}
    for _, name in ipairs(files) do
        if not name:match('^%.') then
            dirs[#dirs+1] = {foldername = name}
        end
    end
    return dirs
end

-- Loads the model name from logs.ini or returns 'Unknown'
local function resolveModelName(folder)
    if not folder then return "Unknown" end
    local iniPath = string.format("LOGS:rfsuite/telemetry/%s/logs.ini", folder)
    local ini = rfsuite.ini.load_ini_file(iniPath) or {}
    return (ini.model and ini.model.name) or "Unknown"
end

-- Builds and displays the Logs page
local function openPage(idx, title, script)
    rfsuite.session.activeLogDir = nil
    if not rfsuite.utils.ethosVersionAtLeast() then return end

    if rfsuite.tasks.msp then
        rfsuite.tasks.msp.protocol.mspIntervalOveride = nil
    end

    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.pages
    form.clear()

    rfsuite.app.lastIdx, rfsuite.app.lastTitle, rfsuite.app.lastScript = idx, title, script

    local w, h = rfsuite.utils.getWindowSize()
    local prefs = rfsuite.preferences.general
    local radio = rfsuite.app.radio
    local icons = prefs.iconsize
    local padding, btnW, btnH, perRow

    if icons == 0 then
        padding = radio.buttonPaddingSmall
        btnW = (rfsuite.session.lcdWidth - padding) / radio.buttonsPerRow - padding
        btnH = radio.navbuttonHeight
        perRow = radio.buttonsPerRow
    elseif icons == 1 then
        padding = radio.buttonPaddingSmall
        btnW, btnH = radio.buttonWidthSmall, radio.buttonHeightSmall
        perRow = radio.buttonsPerRowSmall
    else -- icons == 2
        padding = radio.buttonPadding
        btnW, btnH = radio.buttonWidth, radio.buttonHeight
        perRow = radio.buttonsPerRow
    end

    rfsuite.app.ui.fieldHeader("Logs")

    local logDir = getLogPath()
    local folders = getLogsDir(logDir)

    if #folders == 0 then
        local msg = rfsuite.i18n.get("app.modules.logs.msg_no_logs_found")
        local tw, th = lcd.getTextSize(msg)
        local x = w/2 - tw/2
        local y = h/2 - th/2
        form.addLine()
        form.addStaticText(nil, {x=x,y=y,w=tw,h=btnH}, msg)
    else
        local x, y, col = 0, form.height() + padding, 0
        rfsuite.app.gfx_buttons.logs = rfsuite.app.gfx_buttons.logs or {}

        for i, item in ipairs(folders) do
            if col >= perRow then
                col, y = 0, y + btnH + padding
            end
            local modelName = resolveModelName(item.foldername)
            if icons ~= 0 then
                rfsuite.app.gfx_buttons.logs[i] = rfsuite.app.gfx_buttons.logs[i]
                  or lcd.loadMask("app/modules/logs/folder.png")
            else
                rfsuite.app.gfx_buttons.logs[i] = nil
            end

            local btn = form.addButton(nil, {x=col*(btnW+padding), y=y, w=btnW, h=btnH}, {
                text = modelName,
                options = FONT_S,
                icon    = rfsuite.app.gfx_buttons.logs[i],
                press   = function()
                    rfsuite.preferences.menulastselected.logs = i
                    rfsuite.app.ui.progressDisplay()
                    rfsuite.session.activeLogDir = item.foldername
                    rfsuite.utils.log("Opening logs for: " .. item.foldername, "info")
                    rfsuite.app.ui.openPage(i, "Logs", "logs/logs_logs.lua")
                end
            })
            btn:enable(true)
            if rfsuite.preferences.menulastselected.logs_folder == i then
                btn:focus()
            end
            col = col + 1
        end
    end

    if rfsuite.tasks.msp then
        rfsuite.app.triggers.closeProgressLoader = true
    end
    enableWakeup = true
end

-- Handles form events
local function event(widget, category, value)
    if value == 35 then
        rfsuite.app.ui.openMainMenu()
        return true
    end
    return false
end

-- Called periodically to handle wakeup logic
local function wakeup()
    if enableWakeup then
        -- wakeup handler logic
    end
end

-- Opens the main navigation menu
local function onNavMenu()
    rfsuite.app.ui.openMainMenu()
end

return {
    event      = event,
    openPage   = openPage,
    wakeup     = wakeup,
    onNavMenu  = onNavMenu,
    navButtons = { menu=true, save=false, reload=false, tool=false, help=true },
    API        = {}
}
