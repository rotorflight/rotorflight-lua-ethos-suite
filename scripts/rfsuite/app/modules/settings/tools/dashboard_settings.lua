

local themesBasePath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/themes/"
local themesUserPath = "SCRIPTS:/" .. rfsuite.config.preferences .. "/dashboard/"

local enableWakeup = false
local prevConnectedState = nil

local function openPage(pidx, title, script)
    -- Get the installed themes
    local themeList = rfsuite.widgets.dashboard.listThemes()

    rfsuite.app.dashboardEditingTheme = nil
    enableWakeup = true
    rfsuite.app.triggers.closeProgressLoader = true
    form.clear()

    -- Clear old icons
    for i in pairs(rfsuite.app.gfx_buttons) do
        if i ~= "settings_dashboard_themes" then
            rfsuite.app.gfx_buttons[i] = nil
        end
    end   


    rfsuite.app.lastIdx    = pageIdx
    rfsuite.app.lastTitle  = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader(
        "@i18n(app.modules.settings.name)@" .. " / " .. "@i18n(app.modules.settings.dashboard)@" .. " / " .. "@i18n(app.modules.settings.dashboard_settings)@"
    )

    -- Icon/button layout settings
    local buttonW, buttonH, padding, numPerRow
    if rfsuite.preferences.general.iconsize == 0 then
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = (rfsuite.app.lcdWidth - padding) / rfsuite.app.radio.buttonsPerRow - padding
        buttonH = rfsuite.app.radio.navbuttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    elseif rfsuite.preferences.general.iconsize == 1 then
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = rfsuite.app.radio.buttonWidthSmall
        buttonH = rfsuite.app.radio.buttonHeightSmall
        numPerRow = rfsuite.app.radio.buttonsPerRowSmall
    else
        padding = rfsuite.app.radio.buttonPadding
        buttonW = rfsuite.app.radio.buttonWidth
        buttonH = rfsuite.app.radio.buttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end

    -- Image cache table for theme icons
    if rfsuite.app.gfx_buttons["settings_dashboard_themes"] == nil then
        rfsuite.app.gfx_buttons["settings_dashboard_themes"] = {}
    end
    if rfsuite.preferences.menulastselected["settings_dashboard_themes"] == nil then
        rfsuite.preferences.menulastselected["settings_dashboard_themes"] = 1
    end

    local lc, bx, y = 0, 0, 0

    local n  = 0
    
    for idx, theme in ipairs(themeList) do

        if theme.configure then

            if lc == 0 then
                if rfsuite.preferences.general.iconsize == 0 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
                if rfsuite.preferences.general.iconsize == 1 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
                if rfsuite.preferences.general.iconsize == 2 then y = form.height() + rfsuite.app.radio.buttonPadding end
            end
            if lc >= 0 then bx = (buttonW + padding) * lc end

            -- Only load image once per theme index
            if rfsuite.app.gfx_buttons["settings_dashboard_themes"][idx] == nil then

                local icon  
                if theme.source == "system" then
                    icon = themesBasePath .. theme.folder .. "/icon.png"
                else 
                    icon = themesUserPath .. theme.folder .. "/icon.png"
                end    
                rfsuite.app.gfx_buttons["settings_dashboard_themes"][idx] = lcd.loadMask(icon)
            end

            rfsuite.app.formFields[idx] = form.addButton(nil, {x = bx, y = y, w = buttonW, h = buttonH}, {
                text = theme.name,
                icon = rfsuite.app.gfx_buttons["settings_dashboard_themes"][idx],
                options = FONT_S,
                paint = function() end,
                press = function()
                    -- Optional: your action when pressing a theme
                    -- Example: rfsuite.app.ui.loadTheme(theme.folder)
                    rfsuite.preferences.menulastselected["settings_dashboard_themes"] = idx
                rfsuite.app.ui.progressDisplay(nil,nil,true)
                    local configure = theme.configure
                    local source = theme.source
                    local folder = theme.folder

                    local themeScript
                    if theme.source == "system" then
                        themeScript = themesBasePath .. folder .. "/" .. configure 
                    else 
                        themeScript = themesUserPath .. folder .. "/" .. configure 
                    end    

                    local wrapperScript = "settings/tools/dashboard_settings_theme.lua"

                    rfsuite.app.ui.openPage(idx, theme.name, wrapperScript, source, folder,themeScript)               
                end
            })

            if not theme.configure then
                rfsuite.app.formFields[idx]:enable(false)
            end


            --local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false 
            if rfsuite.preferences.menulastselected["settings_dashboard_themes"] == idx then
                rfsuite.app.formFields[idx]:focus()
            end

            lc = lc + 1
            n = lc + 1
            if lc == numPerRow then lc = 0 end
        end   
    end

    if n == 0 then
        local w, h = lcd.getWindowSize()
        local msg = "@i18n(app.modules.settings.no_themes_available_to_configure)@"
        local tw, th = lcd.getTextSize(msg)
        local x = w / 2 - tw / 2
        local y = h / 2 - th / 2
        local btnH = rfsuite.app.radio.navbuttonHeight
        form.addStaticText(nil, { x = x, y = y, w = tw, h = btnH }, msg)
    end

    rfsuite.app.triggers.closeProgressLoader = true
    collectgarbage()
    enableWakeup = true
    return
end


rfsuite.app.uiState = rfsuite.app.uiStatus.pages

local function event(widget, category, value, x, y)
    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage(
            pageIdx,
            "@i18n(app.modules.settings.dashboard)@",
            "settings/tools/dashboard.lua"
        )
        return true
    end
end

local function onNavMenu()
    rfsuite.app.ui.progressDisplay(nil,nil,true)
    rfsuite.app.ui.openPage(
        pageIdx,
        "@i18n(app.modules.settings.dashboard)@",
        "settings/tools/dashboard.lua"
    )
        return true
end

local function wakeup()
    if not enableWakeup then
        return
    end

    -- current combined state: true only if both are truthy
    local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false

    -- only update if state has changed
    if currState ~= prevConnectedState then
        -- we cant be here anymore... jump to previous page
        if currState == false then
            onNavMenu()
        end
        -- remember for next time
        prevConnectedState = currState
    end
end

return {
    pages = pages, 
    openPage = openPage,
    API = {},
    navButtons = {
        menu   = true,
        save   = false,
        reload = false,
        tool   = false,
        help   = false,
    }, 
    event = event,
    onNavMenu = onNavMenu,
    wakeup = wakeup,
}
