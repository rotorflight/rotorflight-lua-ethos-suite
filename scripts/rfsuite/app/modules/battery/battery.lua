-- create 16 battery in disabled state
local batteryTable = {}
batteryTable = {}
batteryTable['sections'] = {}

local triggerOverRide = false
local triggerOverRideAll = false

local setActiveProfile = nil
local activateWakeup = false

local function openPage(pidx, title, script)

    rfsuite.app.batteryIndex = nil

    rfsuite.tasks.msp.protocol.mspIntervalOveride = nil

    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.pages

    form.clear()

    rfsuite.app.lastIdx = pidx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    -- size of buttons
    if rfsuite.preferences.iconSize == nil or rfsuite.preferences.iconSize == "" then
        rfsuite.preferences.iconSize = 1
    else
        rfsuite.preferences.iconSize = tonumber(rfsuite.preferences.iconSize)
    end

    local w, h = rfsuite.utils.getWindowSize()
    local windowWidth = w
    local windowHeight = h
    local padding = rfsuite.app.radio.buttonPadding

    local sc
    local panel

    buttonW = 100
    local x = windowWidth - buttonW - 10

    rfsuite.app.ui.fieldHeader(rfsuite.i18n.get("app.modules.battery.name"))

    local buttonW
    local buttonH
    local padding
    local numPerRow

    -- TEXT ICONS
    -- TEXT ICONS
    if rfsuite.preferences.iconSize == 0 then
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = (rfsuite.session.lcdWidth - padding) / rfsuite.app.radio.buttonsPerRow - padding
        buttonH = rfsuite.app.radio.navbuttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end
    -- SMALL ICONS
    if rfsuite.preferences.iconSize == 1 then

        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = rfsuite.app.radio.buttonWidthSmall
        buttonH = rfsuite.app.radio.buttonHeightSmall
        numPerRow = rfsuite.app.radio.buttonsPerRowSmall
    end
    -- LARGE ICONS
    if rfsuite.preferences.iconSize == 2 then

        padding = rfsuite.app.radio.buttonPadding
        buttonW = rfsuite.app.radio.buttonWidth
        buttonH = rfsuite.app.radio.buttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end

    local lc = 0
    local bx = 0

    if rfsuite.app.gfx_buttons["battery"] == nil then rfsuite.app.gfx_buttons["battery"] = {} end
    if rfsuite.app.menuLastSelected["battery"] == nil then rfsuite.app.menuLastSelected["battery"] = 1 end

    if rfsuite.app.gfx_buttons["battery"] == nil then rfsuite.app.gfx_buttons["battery"] = {} end
    if rfsuite.app.menuLastSelected["battery"] == nil then rfsuite.app.menuLastSelected["battery"] = 1 end

    for pidx = 0, 5 do
        local pvalue = pidx

            if lc == 0 then
                if rfsuite.preferences.iconSize == 0 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
                if rfsuite.preferences.iconSize == 1 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
                if rfsuite.preferences.iconSize == 2 then y = form.height() + rfsuite.app.radio.buttonPadding end
            end

            if lc >= 0 then bx = (buttonW + padding) * lc end

            if rfsuite.preferences.iconSize ~= 0 then
                if rfsuite.app.gfx_buttons["battery"][pidx] == nil then rfsuite.app.gfx_buttons["battery"][pidx] = lcd.loadMask("app/modules/battery/gfx/battery_" .. pidx + 1 .. ".png") end
            else
                rfsuite.app.gfx_buttons["battery"][pidx] = nil
            end

            rfsuite.app.formFields[pidx] = form.addButton(nil, {x = bx, y = y, w = buttonW, h = buttonH}, {
                text = "Battery " .. pidx + 1,
                icon = rfsuite.app.gfx_buttons["battery"][pidx],
                options = FONT_S,
                paint = function()
                end,
                press = function()
                    rfsuite.app.menuLastSelected["battery"] = pidx
                    rfsuite.currentbatteryIndex = pidx
                    rfsuite.app.ui.progressDisplay()
                    rfsuite.app.batteryIndex = pidx + 1
                    rfsuite.app.ui.openPage(pidx, "Battery " .. pidx + 1, "battery/battery_tool.lua", batteryTable)
                end
            })


            if rfsuite.app.menuLastSelected["battery"] == pidx then rfsuite.app.formFields[pidx]:focus() end

            lc = lc + 1

            if lc == numPerRow then lc = 0 end
        end


    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
    collectgarbage()
    return
end


local function event(widget, category, value, x, y)


end



local function wakeup()

    if activateWakeup == true then

        if setActiveProfile ~= nil then
            local API = rfsuite.tasks.msp.api.load("SELECT_BATTERY")
            API.setCompleteHandler(function(self, buf)
                rfsuite.utils.log("Battery Profile Set to " .. setActiveProfile - 1,"info")
                setActiveProfile = nil

            end)
            API.setUUID("123e4567-e89b-12d3-a456-426614174000")
            API.setValue("id", setActiveProfile)
            API.write()
           
        end

    end

end


local function onNavMenu(self)

    -- rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openMainMenu()

end

local function onReloadMenu()
    rfsuite.app.triggers.triggerReloadFull = true
end

local function onToolMenu(self)

    local buttons = {
        {
            label = " 6 ",
            action = function()
                setActiveProfile = 6
                return true
            end
        },{
            label = " 5 ",
            action = function()
                setActiveProfile = 5
                return true
            end
        },{
            label = " 4 ",
            action = function()
                setActiveProfile = 4
                return true
            end
        },{
            label = " 3 ",
            action = function()
                setActiveProfile = 3
                return true
            end
        },{
            label = " 2 ",
            action = function()
                setActiveProfile = 2
                return true
            end
        }, {
            label = " 1 ",
            action = function()
                setActiveProfile = 1
                return true
            end
        }
    }

    form.openDialog({
        width = nil,
        title = title,
        message = "Please set the active profile",
        buttons = buttons,
        wakeup = function()
        end,
        paint = function()
        end,
        options = TEXT_LEFT
    })


end

-- not changing to custom api at present due to complexity of read/write scenario in these modules
return {
    event = event,
    openPage = openPage,
    onNavMenu = onNavMenu,
    onToolMenu = onToolMenu,
    wakeup = wakeup,
    navButtons = {
        menu = true,
        save = false,
        reload = false,
        tool = true,
        help = false
    },  
    API = {},
}
