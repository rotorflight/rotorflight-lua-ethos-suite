--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local lcd = lcd
local system = system

local function loadMask(path)
    local ui = rfsuite.app and rfsuite.app.ui
    if ui and ui.loadMask then return ui.loadMask(path) end
    return lcd.loadMask(path)
end

local pages = {}

local function resolveModulePath(script)
    if type(script) ~= "string" then return nil, nil end
    local relativeScript = script
    if relativeScript:sub(1, 12) == "app/modules/" then
        relativeScript = relativeScript:sub(13)
    end
    local modulePath = script
    if modulePath:sub(1, 4) ~= "app/" then
        modulePath = "app/modules/" .. modulePath
    end
    return modulePath, relativeScript
end

local function findMFG()
    local mfgsList = {}

    local mfgs_path = "app/modules/esc_tools/tools/escmfg/"

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
                    if mconfig.apiversion and rfsuite.session.apiVersion and not rfsuite.utils.apiVersionCompare(">=", mconfig.apiversion) then
                        mconfig.disabled = true
                    end
                    table.insert(mfgsList, mconfig)
                end
            end
        end
    end

    return mfgsList
end

local function openPage(opts)

    local parentIdx = opts.idx
    local title = opts.title
    local script = opts.script
    local modulePath, relativeScript = resolveModulePath(script)

    rfsuite.tasks.msp.protocol.mspIntervalOveride = nil
    rfsuite.session.escDetails = nil
    rfsuite.session.escBuffer = nil

    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.mainMenu

    form.clear()

    rfsuite.app.lastIdx = parentIdx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = relativeScript or script

    if rfsuite.preferences.general.iconsize == nil or rfsuite.preferences.general.iconsize == "" then
        rfsuite.preferences.general.iconsize = 1
    else
        rfsuite.preferences.general.iconsize = tonumber(rfsuite.preferences.general.iconsize)
    end

    rfsuite.app.ui.fieldHeader(title)

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

    assert(loadfile(modulePath))()
    pages = findMFG()
    local lc = 0
    local bx = 0
    local y = 0

    for childIdx, pvalue in ipairs(pages) do

        if lc == 0 then
            if rfsuite.preferences.general.iconsize == 0 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.preferences.general.iconsize == 1 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.preferences.general.iconsize == 2 then y = form.height() + rfsuite.app.radio.buttonPadding end
        end

        if lc >= 0 then bx = (buttonW + padding) * lc end

        if rfsuite.preferences.general.iconsize ~= 0 then
            if rfsuite.app.gfx_buttons["escmain"][childIdx] == nil then rfsuite.app.gfx_buttons["escmain"][childIdx] = loadMask("app/modules/esc_tools/tools/escmfg/" .. pvalue.folder .. "/" .. pvalue.image) end
        else
            rfsuite.app.gfx_buttons["escmain"][childIdx] = nil
        end

        rfsuite.app.formFields[childIdx] = form.addButton(line, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = pvalue.toolName,
            icon = rfsuite.app.gfx_buttons["escmain"][childIdx],
            options = FONT_S,
            paint = function() end,
                press = function()
                    rfsuite.preferences.menulastselected["escmain"] = childIdx
                    rfsuite.app.ui.progressDisplay(nil,nil,0.5)
                    local toolScript = "esc_tools/tools/esc_tool.lua"
                    if pvalue.esc4way == true then
                        toolScript = "esc_tools/tools/esc_tool_4way.lua"
                    end
                    rfsuite.app.ui.openPage({
                        idx = childIdx,
                        title = title .. " / " .. pvalue.toolName,
                        folder = pvalue.folder,
                        script = toolScript,
                        returnContext = {idx = parentIdx, title = title, script = relativeScript or script}
                    })
                end
            })

        if pvalue.disabled == true then rfsuite.app.formFields[childIdx]:enable(false) end

        if rfsuite.preferences.menulastselected["escmain"] == childIdx then rfsuite.app.formFields[childIdx]:focus() end

        lc = lc + 1

        if lc == numPerRow then lc = 0 end

    end

    rfsuite.app.triggers.closeProgressLoader = true

    return
end

local function onNavMenu()
    pageRuntime.openMenuContext({defaultSection = "system"})
    return true
end

rfsuite.app.uiState = rfsuite.app.uiStatus.pages

return {
    pages = pages,
    openPage = openPage,
    onNavMenu = onNavMenu,
    event = function(_, category, value) return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu}) end,
    navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
    API = {}
}
