-- Load utility functions
local utils = assert(rfsuite.compiler.loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/app/modules/logs/lib/utils.lua"))()
local i18n = rfsuite.i18n.get
-- Wakeup control flag
local enableWakeup = false

-- Build and display the Logs directory selection page
local function openPage(idx, title, script)
    rfsuite.app.activeLogDir = nil
    if not rfsuite.utils.ethosVersionAtLeast() then return end

    -- Reset any running MSP task overrides
    if rfsuite.tasks.msp then
        rfsuite.tasks.msp.protocol.mspIntervalOveride = nil
    end

    -- Initialize page state
    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.pages
    form.clear()

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    -- UI layout settings
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
    else -- icons == 2
        padding = radio.buttonPadding
        btnW, btnH = radio.buttonWidth, radio.buttonHeight
        perRow = radio.buttonsPerRow
    end

    rfsuite.app.ui.fieldHeader("Logs")

    local logDir = utils.getLogPath()
    local folders = utils.getLogsDir(logDir)

    -- Show message if no logs exist
    if #folders == 0 then
        local msg = i18n("app.modules.logs.msg_no_logs_found")
        local tw, th = lcd.getTextSize(msg)
        local x = w / 2 - tw / 2
        local y = h / 2 - th / 2
        form.addStaticText(nil, { x = x, y = y, w = tw, h = btnH }, msg)
    else
        -- Display buttons for each log directory
        local x, y, col = 0, form.height() + padding, 0
        rfsuite.app.gfx_buttons.logs = rfsuite.app.gfx_buttons.logs or {}

        for i, item in ipairs(folders) do
            if col >= perRow then
                col, y = 0, y + btnH + padding
            end

            local modelName = utils.resolveModelName(item.foldername)

            if icons ~= 0 then
                rfsuite.app.gfx_buttons.logs[i] = rfsuite.app.gfx_buttons.logs[i] or lcd.loadMask("app/modules/logs/gfx/folder.png")
            else
                rfsuite.app.gfx_buttons.logs[i] = nil
            end

            local btn = form.addButton(nil, {
                x = col * (btnW + padding), y = y, w = btnW, h = btnH
            }, {
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

-- Handle form navigation or keypress events
local function event(widget, category, value)
    if value == 35 then
        rfsuite.app.ui.openMainMenu()
        return true
    end
    return false
end

-- Background wakeup handler (placeholder for future logic)
local function wakeup()
    if enableWakeup then
        -- Future periodic update logic
    end
end

-- Navigation menu handler
local function onNavMenu()
    rfsuite.app.ui.openMainMenu()
end

-- Module export
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
    API = {}
}
