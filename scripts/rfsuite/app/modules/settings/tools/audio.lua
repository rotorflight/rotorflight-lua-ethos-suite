



local S_PAGES = {
    {name = "@i18n(app.modules.settings.txt_audio_events)@", script = "audio_events.lua", image = "audio_events.png"},
    {name = "@i18n(app.modules.settings.txt_audio_switches)@", script = "audio_switches.lua", image = "audio_switches.png"},
    {name = "@i18n(app.modules.settings.txt_audio_timer)@", script = "audio_timer.lua", image = "audio_timer.png"},
}

local function openPage(pidx, title, script)


    rfsuite.tasks.msp.protocol.mspIntervalOveride = nil


    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.mainMenu

    form.clear()

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    -- Clear old icons
    for i in pairs(rfsuite.app.gfx_buttons) do
        if i ~= "settings_dashboard_audio" then
            rfsuite.app.gfx_buttons[i] = nil
        end
    end

    -- size of buttons
    if rfsuite.preferences.general.iconsize == nil or rfsuite.preferences.general.iconsize == "" then
        rfsuite.preferences.general.iconsize = 1
    else
        rfsuite.preferences.general.iconsize = tonumber(rfsuite.preferences.general.iconsize)
    end

    local w, h = lcd.getWindowSize()
    local windowWidth = w
    local windowHeight = h
    local padding = rfsuite.app.radio.buttonPadding

    local sc
    local panel



    local buttonW = 100
    local x = windowWidth - buttonW - 10

    rfsuite.app.ui.fieldHeader(
        "@i18n(app.modules.settings.name)@" .. " / " .. "@i18n(app.modules.settings.audio)@"
    )

    local buttonW
    local buttonH
    local padding
    local numPerRow

    -- TEXT ICONS
    -- TEXT ICONS
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


    if rfsuite.app.gfx_buttons["settings_dashboard_audio"] == nil then rfsuite.app.gfx_buttons["settings_dashboard_audio"] = {} end
    if rfsuite.preferences.menulastselected["settings_dashboard_audio"] == nil then rfsuite.preferences.menulastselected["settings_dashboard_audio"] = 1 end


    local Menu = assert(rfsuite.compiler.loadfile("app/modules/" .. script))()
    local pages = S_PAGES
    local lc = 0
    local bx = 0



    for pidx, pvalue in ipairs(S_PAGES) do

        if lc == 0 then
            if rfsuite.preferences.general.iconsize == 0 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.preferences.general.iconsize == 1 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.preferences.general.iconsize == 2 then y = form.height() + rfsuite.app.radio.buttonPadding end
        end

        if lc >= 0 then bx = (buttonW + padding) * lc end

        if rfsuite.preferences.general.iconsize ~= 0 then
            if rfsuite.app.gfx_buttons["settings_dashboard_audio"][pidx] == nil then rfsuite.app.gfx_buttons["settings_dashboard_audio"][pidx] = lcd.loadMask("app/modules/settings/gfx/" .. pvalue.image) end
        else
            rfsuite.app.gfx_buttons["settings_dashboard_audio"][pidx] = nil
        end

        rfsuite.app.formFields[pidx] = form.addButton(line, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = pvalue.name,
            icon = rfsuite.app.gfx_buttons["settings_dashboard_audio"][pidx],
            options = FONT_S,
            paint = function()
            end,
            press = function()
                rfsuite.preferences.menulastselected["settings_dashboard_audio"] = pidx
                rfsuite.app.ui.progressDisplay(nil,nil,true)
                rfsuite.app.ui.openPage(pidx, pvalue.folder, "settings/tools/" .. pvalue.script)
            end
        })

        if pvalue.disabled == true then rfsuite.app.formFields[pidx]:enable(false) end

        if rfsuite.preferences.menulastselected["settings_dashboard_audio"] == pidx then rfsuite.app.formFields[pidx]:focus() end

        lc = lc + 1

        if lc == numPerRow then lc = 0 end

    end

    rfsuite.app.triggers.closeProgressLoader = true
    collectgarbage()
    return
end

local function event(widget, category, value, x, y)
    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage(
            pageIdx,
            "@i18n(app.modules.settings.name)@",
            "settings/settings.lua"
        )
        return true
    end
end


local function onNavMenu()
    rfsuite.app.ui.progressDisplay(nil,nil,true)
        rfsuite.app.ui.openPage(
            pageIdx,
            "@i18n(app.modules.settings.name)@",
            "settings/settings.lua"
        )
        return true
end

rfsuite.app.uiState = rfsuite.app.uiStatus.pages

return {
    pages = pages, 
    openPage = openPage,
    onNavMenu = onNavMenu,
    API = {},
    event = event,
    navButtons = {
        menu   = true,
        save   = false,
        reload = false,
        tool   = false,
        help   = false,
    },    
}
