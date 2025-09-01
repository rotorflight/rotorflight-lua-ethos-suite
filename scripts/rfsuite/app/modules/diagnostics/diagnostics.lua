local i18n = rfsuite.i18n.get
local app = rfsuite.app
local log = rfsuite.utils.log

local S_PAGES = {
    {
        name = i18n("app.modules.rfstatus.name"),
        script = "rfstatus.lua",
        image = "rfstatus.png",
        bgtask = false,  -- requires background tasks for icon to be enabled
        offline = false  -- requires connection to fbl to run
    }, 
    {
        name = i18n("app.modules.msp_speed.name"),
        script = "msp_speed.lua",
        image = "msp_speed.png",
        bgtask = true,  -- requires background tasks for icon to be enabled
        offline = true  -- requires connection to fbl to run
    },       
    {
        name = i18n("app.modules.validate_sensors.name"),
        script = "sensors.lua",
        image = "sensors.png",
        bgtask = true,  -- requires background tasks for icon to be enabled
        offline = true  -- requires connection to fbl to run
    }, 
    {
        name = i18n("app.modules.fblstatus.name"),
        script = "fblstatus.lua",
        image = "fblstatus.png",
        bgtask = true,  -- requires background tasks for icon to be enabled
        offline = true  -- requires connection to fbl to run
    },     
    {
        name = i18n("app.modules.info.name"),
        script = "info.lua",
        image = "info.png",
        bgtask = true,  -- requires background tasks for icon to be enabled
        offline = true  -- requires connection to fbl to run
    },      
}

local function openPage(pidx, title, script)


    app.triggers.isReady = false
    app.uiState = app.uiStatus.mainMenu

    form.clear()

    app.lastIdx = idx
    app.lastTitle = title
    app.lastScript = script

    -- Clear old icons
    for i in pairs(app.gfx_buttons) do
        if i ~= "diagnostics" then
            app.gfx_buttons[i] = nil
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
    local padding = app.radio.buttonPadding

    local sc
    local panel

    form.addLine(title)

    buttonW = 100
    local x = windowWidth - buttonW - 10

    app.formNavigationFields['menu'] = form.addButton(line, {x = x, y = app.radio.linePaddingTop, w = buttonW, h = app.radio.navbuttonHeight}, {
        text = "MENU",
        icon = nil,
        options = FONT_S,
        paint = function()
        end,
        press = function()
            app.lastIdx = nil
            rfsuite.session.lastPage = nil

            if app.Page and app.Page.onNavMenu then 
                    app.Page.onNavMenu(app.Page) 
            else
                app.ui.progressDisplay(nil,nil,true)
            end
            app.ui.openMainMenu()
        end
    })
    app.formNavigationFields['menu']:focus()

    local buttonW
    local buttonH
    local padding
    local numPerRow

    -- TEXT ICONS
    -- TEXT ICONS
    if rfsuite.preferences.general.iconsize == 0 then
        padding = app.radio.buttonPaddingSmall
        buttonW = (app.lcdWidth - padding) / app.radio.buttonsPerRow - padding
        buttonH = app.radio.navbuttonHeight
        numPerRow = app.radio.buttonsPerRow
    end
    -- SMALL ICONS
    if rfsuite.preferences.general.iconsize == 1 then

        padding = app.radio.buttonPaddingSmall
        buttonW = app.radio.buttonWidthSmall
        buttonH = app.radio.buttonHeightSmall
        numPerRow = app.radio.buttonsPerRowSmall
    end
    -- LARGE ICONS
    if rfsuite.preferences.general.iconsize == 2 then

        padding = app.radio.buttonPadding
        buttonW = app.radio.buttonWidth
        buttonH = app.radio.buttonHeight
        numPerRow = app.radio.buttonsPerRow
    end


    if app.gfx_buttons["diagnostics"] == nil then app.gfx_buttons["diagnostics"] = {} end
    if rfsuite.preferences.menulastselected["diagnostics"] == nil then rfsuite.preferences.menulastselected["diagnostics"] = 1 end


    local Menu = assert(rfsuite.compiler.loadfile("app/modules/" .. script))()
    local pages = S_PAGES
    local lc = 0
    local bx = 0

    app.formFields         = {}
    app.formFieldsOffline  = {}
    app.formFieldsBGTask   = {}    


    for pidx, pvalue in ipairs(S_PAGES) do

        app.formFieldsOffline[pidx] = pvalue.offline or false
        app.formFieldsBGTask[pidx] = pvalue.bgtask or false

        if lc == 0 then
            if rfsuite.preferences.general.iconsize == 0 then y = form.height() + app.radio.buttonPaddingSmall end
            if rfsuite.preferences.general.iconsize == 1 then y = form.height() + app.radio.buttonPaddingSmall end
            if rfsuite.preferences.general.iconsize == 2 then y = form.height() + app.radio.buttonPadding end
        end

        if lc >= 0 then bx = (buttonW + padding) * lc end

        if rfsuite.preferences.general.iconsize ~= 0 then
            if app.gfx_buttons["diagnostics"][pidx] == nil then app.gfx_buttons["diagnostics"][pidx] = lcd.loadMask("app/modules/diagnostics/gfx/" .. pvalue.image) end
        else
            app.gfx_buttons["diagnostics"][pidx] = nil
        end

        app.formFields[pidx] = form.addButton(line, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = pvalue.name,
            icon = app.gfx_buttons["diagnostics"][pidx],
            options = FONT_S,
            paint = function()
            end,
            press = function()
                rfsuite.preferences.menulastselected["diagnostics"] = pidx
                app.ui.progressDisplay(nil,nil,true)
                app.ui.openPage(pidx, rfsuite.i18n.get("app.modules.diagnostics.name")  .. " / " .. pvalue.name, "diagnostics/tools/" .. pvalue.script)
            end
        })

        if rfsuite.preferences.menulastselected["diagnostics"] == pidx then app.formFields[pidx]:focus() end

        lc = lc + 1

        if lc == numPerRow then lc = 0 end

    end

    app.triggers.closeProgressLoader = true
    collectgarbage()
    return
end

local function wakeup()

    if not rfsuite.tasks.active() then
          for i, v in pairs(app.formFieldsBGTask) do
            if v == true then
              if app.formFields[i] then
                app.formFields[i]:enable(false)
              else
                log("Main Menu Icon " .. i .. " not found in formFields", "info")
              end
            end
          end 
    elseif not rfsuite.session.isConnected then
        for i, v in pairs(app.formFieldsOffline) do
            if v == true then
            if app.formFields[i] then
                app.formFields[i]:enable(false)
            else
                log("Main Menu Icon " .. i .. " not found in formFields", "info")
            end
            end
        end
    else
        for i, v in pairs(app.formFields) do
            app.formFields[i]:enable(true)
        end               
    end    
end

app.uiState = app.uiStatus.pages

return {
    pages = pages, 
    openPage = openPage,
    wakeup = wakeup,
    API = {},
}
