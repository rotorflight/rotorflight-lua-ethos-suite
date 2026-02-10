--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd
local system = system

local pages = {}

local function findMFG()
    local mfgsList = {}

    local mfgs_path = "app/modules/esc_motors/tools/escmfg/"

    for _, v in pairs(system.listFiles(mfgs_path)) do

        local init_path = mfgs_path .. v .. '/init.lua'

        local f = os.stat(init_path)
        if f then

            local func, err = loadfile(init_path)

            if func then
                local mconfig = func()
                if type(mconfig) ~= "table" or not mconfig.toolName then
                    rfsuite.utils.log("Invalid configuration in " .. init_path)
                else
                    mconfig['folder'] = v
                    table.insert(mfgsList, mconfig)
                end
            end
        end
    end

    return mfgsList
end

local function openPage(opts)

    local pidx = opts.idx
    local title = opts.title
    local script = opts.script

    rfsuite.tasks.msp.protocol.mspIntervalOveride = nil
    rfsuite.session.escDetails = nil

    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.mainMenu

    form.clear()

    rfsuite.app.lastIdx = pidx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    if rfsuite.preferences.general.iconsize == nil or rfsuite.preferences.general.iconsize == "" then
        rfsuite.preferences.general.iconsize = 1
    else
        rfsuite.preferences.general.iconsize = tonumber(rfsuite.preferences.general.iconsize)
    end

    local windowWidth = lcd.getWindowSize()

    form.addLine(title)

    local navButtonW = 100
    local x = windowWidth - navButtonW - 10

    rfsuite.app.formNavigationFields['menu'] = form.addButton(line, {x = x, y = rfsuite.app.radio.linePaddingTop, w = navButtonW, h = rfsuite.app.radio.navbuttonHeight}, {
        text = "@i18n(app.navigation_menu)@",
        icon = nil,
        options = FONT_S,
        paint = function() end,
        press = function()
            rfsuite.app.lastIdx = nil
            rfsuite.session.lastPage = nil

            if rfsuite.app.Page and rfsuite.app.Page.onNavMenu then rfsuite.app.Page.onNavMenu(rfsuite.app.Page) end

            rfsuite.app.ui.openPage({idx = pidx, title = title, script = "esc_motors/esc_motors.lua"})
        end
    })
    rfsuite.app.formNavigationFields['menu']:focus()

    local buttonW
    local buttonH
    local padding
    local numPerRow

    if rfsuite.preferences.general.iconsize == 0 then
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = (rfsuite.app.lcdWidth - padding) / rfsuite.app.radio.buttonsPerRow - padding
        buttonH = rfsuite.app.radio.navbuttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end

    if rfsuite.preferences.general.iconsize == 1 then

        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = rfsuite.app.radio.buttonWidthSmall
        buttonH = rfsuite.app.radio.buttonHeightSmall
        numPerRow = rfsuite.app.radio.buttonsPerRowSmall
    end

    if rfsuite.preferences.general.iconsize == 2 then

        padding = rfsuite.app.radio.buttonPadding
        buttonW = rfsuite.app.radio.buttonWidth
        buttonH = rfsuite.app.radio.buttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end

    if rfsuite.app.gfx_buttons["escmain"] == nil then rfsuite.app.gfx_buttons["escmain"] = {} end
    if rfsuite.preferences.menulastselected["escmain"] == nil then rfsuite.preferences.menulastselected["escmain"] = 1 end

    assert(loadfile("app/modules/" .. script))()
    pages = findMFG()
    local lc = 0
    local bx = 0
    local y = 0

    for pidx, pvalue in ipairs(pages) do

        if lc == 0 then
            if rfsuite.preferences.general.iconsize == 0 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.preferences.general.iconsize == 1 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.preferences.general.iconsize == 2 then y = form.height() + rfsuite.app.radio.buttonPadding end
        end

        if lc >= 0 then bx = (buttonW + padding) * lc end

        if rfsuite.preferences.general.iconsize ~= 0 then
            if rfsuite.app.gfx_buttons["escmain"][pidx] == nil then rfsuite.app.gfx_buttons["escmain"][pidx] = lcd.loadMask("app/modules/esc_motors/tools/escmfg/" .. pvalue.folder .. "/" .. pvalue.image) end
        else
            rfsuite.app.gfx_buttons["escmain"][pidx] = nil
        end

        rfsuite.app.formFields[pidx] = form.addButton(line, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = pvalue.toolName,
            icon = rfsuite.app.gfx_buttons["escmain"][pidx],
            options = FONT_S,
            paint = function() end,
            press = function()
                rfsuite.preferences.menulastselected["escmain"] = pidx
                rfsuite.app.ui.progressDisplay(nil,nil,0.5)
                rfsuite.app.ui.openPage({idx = pidx, title = pvalue.folder, script = "esc_motors/tools/esc_tool.lua"})
            end
        })

        if pvalue.disabled == true then rfsuite.app.formFields[pidx]:enable(false) end

        if rfsuite.preferences.menulastselected["escmain"] == pidx then rfsuite.app.formFields[pidx]:focus() end

        lc = lc + 1

        if lc == numPerRow then lc = 0 end

    end

    rfsuite.app.triggers.closeProgressLoader = true

    return
end

rfsuite.app.uiState = rfsuite.app.uiStatus.pages

return {pages = pages, openPage = openPage, API = {}}
