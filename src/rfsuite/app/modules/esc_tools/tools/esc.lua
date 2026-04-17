--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local lcd = lcd

local function loadMask(path)
    local ui = rfsuite.app and rfsuite.app.ui
    if ui and ui.loadMask then return ui.loadMask(path) end
    return lcd.loadMask(path)
end

local pages = {}
local DEFAULT_TOOL_SCRIPT = "esc_tools/tools/esc_tool.lua"
local FOUR_WAY_TOOL_SCRIPT = "esc_tools/tools/esc_tool_4way.lua"
local function noop() end
local pageButtonMeta = {}
local pageButtonHandlers = {}
local MFG_INDEX = {
    {folder = "am32",  toolName = "AM32",                                         image = "am32.jpg",      apiversion = {12, 0, 9}, script = FOUR_WAY_TOOL_SCRIPT},
    {folder = "blheli_s", toolName = "BLHeli_S",                                  image = "blheli_s.jpg",  apiversion = {12, 0, 9}, script = FOUR_WAY_TOOL_SCRIPT},
    {folder = "bluejay", toolName = "@i18n(app.modules.esc_tools.mfg.bluejay.name)@", image = "blheli_s.jpg",  apiversion = {12, 0, 9}, script = FOUR_WAY_TOOL_SCRIPT},
    {folder = "flrtr", toolName = "@i18n(app.modules.esc_tools.mfg.flrtr.name)@", image = "flrtr.png",     apiversion = {12, 0, 7}},
    {folder = "hw5",   toolName = "@i18n(app.modules.esc_tools.mfg.hw5.name)@",   image = "hobbywing.png", apiversion = {12, 0, 6}},
    {folder = "omp",   toolName = "@i18n(app.modules.esc_tools.mfg.omp.name)@",   image = "omp.png",       apiversion = {12, 0, 9}},
    {folder = "scorp", toolName = "@i18n(app.modules.esc_tools.mfg.scorp.name)@", image = "scorpion.png",  apiversion = {12, 0, 6}},
    {folder = "xdfly", toolName = "@i18n(app.modules.esc_tools.mfg.xdfly.name)@", image = "xdfly.png",     apiversion = {12, 0, 8}},
    {folder = "yge",   toolName = "@i18n(app.modules.esc_tools.mfg.yge.name)@",   image = "yge.png",       apiversion = {12, 0, 6}},
    {folder = "ztw",   toolName = "@i18n(app.modules.esc_tools.mfg.ztw.name)@",   image = "ztw.png",       apiversion = {12, 0, 9}}
}

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

local function buildEscPages()
    for i = 1, #pages do
        pages[i] = nil
    end

    for i, entry in ipairs(MFG_INDEX) do
        local disabled = false
        if entry.apiversion and rfsuite.session.apiVersion and not rfsuite.utils.apiVersionCompare(">=", entry.apiversion) then
            disabled = true
        end

        pages[i] = {
            folder = entry.folder,
            toolName = entry.toolName,
            image = entry.image,
            script = entry.script or DEFAULT_TOOL_SCRIPT,
            disabled = disabled
        }
    end

    return pages
end

local function clearEscMaskCache()
    local ui = rfsuite.app and rfsuite.app.ui
    local cache = ui and ui._maskCache
    local order = ui and ui._maskCacheOrder
    if type(cache) ~= "table" then return end

    local prefix = "app/modules/esc_tools/tools/escmfg/"
    local removed = false
    for path in pairs(cache) do
        if type(path) == "string" and path:sub(1, #prefix) == prefix then
            cache[path] = nil
            removed = true
        end
    end
    if not removed or type(order) ~= "table" then return end

    local writeIdx = 1
    for i = 1, #order do
        local path = order[i]
        if cache[path] ~= nil then
            order[writeIdx] = path
            writeIdx = writeIdx + 1
        end
    end
    for i = writeIdx, #order do
        order[i] = nil
    end
end

local function clearButtonMeta()
    for k in pairs(pageButtonMeta) do
        pageButtonMeta[k] = nil
    end
end

local function clearButtonCache()
    clearButtonMeta()
    for k in pairs(pageButtonHandlers) do
        pageButtonHandlers[k] = nil
    end
end

local function pressMainButton(childIdx)
    local meta = pageButtonMeta[childIdx]
    if not meta then return end

    rfsuite.preferences.menulastselected["escmain"] = childIdx
    rfsuite.app.ui.progressDisplay(nil, nil, 0.5)
    rfsuite.app.ui.openPage({
        idx = childIdx,
        title = meta.childTitle,
        folder = meta.folder,
        script = meta.script,
        returnContext = {
            idx = childIdx,
            title = meta.title,
            script = meta.returnScript
        }
    })
end

local function getMainButtonHandler(childIdx)
    local handler = pageButtonHandlers[childIdx]
    if handler then return handler end
    handler = function()
        pressMainButton(childIdx)
    end
    pageButtonHandlers[childIdx] = handler
    return handler
end

local function openPage(opts)

    local pidx = opts.idx
    local title = opts.title
    local script = opts.script
    local _, relativeScript = resolveModulePath(script)

    rfsuite.tasks.msp.protocol.mspIntervalOveride = nil
    rfsuite.session.escDetails = nil
    rfsuite.session.escBuffer = nil

    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.pages

    form.clear()

    rfsuite.app.lastIdx = pidx
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

    pages = buildEscPages()
    clearButtonMeta()
    local selectedIdx = tonumber(rfsuite.preferences.menulastselected["escmain"]) or 1
    if selectedIdx < 1 then selectedIdx = 1 end
    if selectedIdx > #pages then selectedIdx = #pages end
    if selectedIdx < 1 then selectedIdx = 1 end
    rfsuite.preferences.menulastselected["escmain"] = selectedIdx

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

        pageButtonMeta[childIdx] = {
            title = title,
            childTitle = title .. " / " .. pvalue.toolName,
            folder = pvalue.folder,
            script = pvalue.script,
            returnScript = relativeScript or script
        }

        rfsuite.app.formFields[childIdx] = form.addButton(nil, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = pvalue.toolName,
            icon = rfsuite.app.gfx_buttons["escmain"][childIdx],
            options = FONT_S,
            paint = noop,
            press = getMainButtonHandler(childIdx)
        })

        if pvalue.disabled == true then rfsuite.app.formFields[childIdx]:enable(false) end

        if selectedIdx == childIdx then rfsuite.app.formFields[childIdx]:focus() end

        lc = lc + 1

        if lc == numPerRow then lc = 0 end

    end

    rfsuite.app.triggers.closeProgressLoader = true

    return
end

local function closePage()
    if rfsuite.app and rfsuite.app.gfx_buttons then
        rfsuite.app.gfx_buttons["escmain"] = nil
    end
    pages = {}
    clearButtonCache()
    clearEscMaskCache()
end

local function onNavMenu()
    closePage()
    pageRuntime.openMenuContext({defaultSection = "system"})
    return true
end

rfsuite.app.uiState = rfsuite.app.uiStatus.pages

return {
    pages = pages,
    openPage = openPage,
    close = closePage,
    onNavMenu = onNavMenu,
    event = function(_, category, value) return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu}) end,
    navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
    API = {}
}
