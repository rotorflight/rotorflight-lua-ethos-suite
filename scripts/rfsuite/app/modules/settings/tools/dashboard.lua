


local S_PAGES = {
    [1] = {name = "@i18n(app.modules.settings.dashboard_theme)@", script = "dashboard_theme.lua", image = "dashboard_theme.png"},
    [2] = {name = "@i18n(app.modules.settings.dashboard_settings)@", script = "dashboard_settings.lua", image = "dashboard_settings.png"},
}

local enableWakeup = false
local prevConnectedState = nil
local initTime = os.clock()

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
        if i ~= "settings_dashboard" then
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
        "@i18n(app.modules.settings.name)@" .. " / " .. "@i18n(app.modules.settings.dashboard)@"
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


    if rfsuite.app.gfx_buttons["settings_dashboard"] == nil then rfsuite.app.gfx_buttons["settings_dashboard"] = {} end
    if rfsuite.preferences.menulastselected["settings_dashboard"] == nil then rfsuite.preferences.menulastselected["settings_dashboard"] = 1 end


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
            if rfsuite.app.gfx_buttons["settings_dashboard"][pidx] == nil then rfsuite.app.gfx_buttons["settings_dashboard"][pidx] = lcd.loadMask("app/modules/settings/gfx/" .. pvalue.image) end
        else
            rfsuite.app.gfx_buttons["settings_dashboard"][pidx] = nil
        end

        rfsuite.app.formFields[pidx] = form.addButton(line, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = pvalue.name,
            icon = rfsuite.app.gfx_buttons["settings_dashboard"][pidx],
            options = FONT_S,
            paint = function()
            end,
            press = function()
                rfsuite.preferences.menulastselected["settings_dashboard"] = pidx
                rfsuite.app.ui.progressDisplay(nil,nil,true)
                rfsuite.app.ui.openPage(pidx, pvalue.folder, "settings/tools/" .. pvalue.script)
            end
        })

        if pvalue.disabled == true then rfsuite.app.formFields[pidx]:enable(false) end

        local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false
            
        if rfsuite.preferences.menulastselected["settings_dashboard"] == pidx then rfsuite.app.formFields[pidx]:focus() end

        lc = lc + 1

        if lc == numPerRow then lc = 0 end

    end

    rfsuite.app.triggers.closeProgressLoader = true
    collectgarbage()
    enableWakeup = true
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


local function wakeup()
    if not enableWakeup then
        return
    end

    -- Exit if less than 0.25 second since init
    -- This prevents the icon getting trashed due to being disabled before rendering
    if os.clock() - initTime < 0.25 then
        return
    end

    -- current combined state: true only if both are truthy
    local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false

    -- only update if state has changed
    if currState ~= prevConnectedState then
        -- toggle all three fields together
        rfsuite.app.formFields[2]:enable(currState)

        if not currState then
            rfsuite.app.formNavigationFields['menu']:focus()
        end

        -- remember for next time
        prevConnectedState = currState
    end
end


rfsuite.app.uiState = rfsuite.app.uiStatus.pages

return {
    pages = pages, 
    openPage = openPage,
    onNavMenu = onNavMenu,
    event = event,
    wakeup = wakeup,
    API = {},
        navButtons = {
        menu   = true,
        save   = false,
        reload = false,
        tool   = false,
        help   = false,
    },    
}
