

local i18n = rfsuite.i18n.get
local S_PAGES = {
    [1] = {name = i18n("app.modules.governor.menu_general"), script = "general.lua", image = "general.png"},
    [2] = {name = i18n("app.modules.governor.menu_time"), script = "time.lua", image = "time.png"},
    [3] = {name = i18n("app.modules.governor.menu_filters"), script = "filters.lua", image = "filters.png"},
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
        if i ~= "governor" then
            rfsuite.app.gfx_buttons[i] = nil
        end
    end    

    ESC = {}

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


    buttonW = 100
    local x = windowWidth - buttonW - 10

    rfsuite.app.ui.fieldHeader(
        i18n(i18n("app.modules.governor.name"))
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


    if rfsuite.app.gfx_buttons["governor"] == nil then rfsuite.app.gfx_buttons["governor"] = {} end
    if rfsuite.preferences.menulastselected["governor"] == nil then rfsuite.preferences.menulastselected["governor"] = 1 end


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
            if rfsuite.app.gfx_buttons["governor"][pidx] == nil then rfsuite.app.gfx_buttons["governor"][pidx] = lcd.loadMask("app/modules/governor/gfx/" .. pvalue.image) end
        else
            rfsuite.app.gfx_buttons["governor"][pidx] = nil
        end

        rfsuite.app.formFields[pidx] = form.addButton(line, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = pvalue.name,
            icon = rfsuite.app.gfx_buttons["governor"][pidx],
            options = FONT_S,
            paint = function()
            end,
            press = function()
                rfsuite.preferences.menulastselected["governor"] = pidx
                rfsuite.app.ui.progressDisplay()
                local name = i18n("app.modules.governor.name") .. " / " .. pvalue.name
                rfsuite.app.ui.openPage(pidx, name, "governor/tools/" .. pvalue.script)
            end
        })

        if pvalue.disabled == true then rfsuite.app.formFields[pidx]:enable(false) end

        local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false
            
        if rfsuite.preferences.menulastselected["governor"] == pidx then rfsuite.app.formFields[pidx]:focus() end

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
        rfsuite.app.ui.openMainMenuSub(rfsuite.app.lastMenu)
        return true
    end
end


local function onNavMenu()
    rfsuite.app.ui.progressDisplay()
        rfsuite.app.ui.openMainMenuSub(rfsuite.app.lastMenu)
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
