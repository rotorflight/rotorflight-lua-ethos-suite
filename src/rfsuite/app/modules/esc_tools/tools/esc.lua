--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local lcd = lcd
local osClock = os.clock

local function loadMask(path)
    local ui = rfsuite.app and rfsuite.app.ui
    if ui and ui.loadMask then return ui.loadMask(path) end
    return lcd.loadMask(path)
end

local pages = {}
local DEFAULT_TOOL_SCRIPT = "esc_tools/tools/esc_tool.lua"
local FOUR_WAY_TOOL_SCRIPT = "esc_tools/tools/esc_tool_4way.lua"
local ESC_SENSOR_CONFIG_API = "ESC_SENSOR_CONFIG"
local ESC_SENSOR_CONFIG_MIN_API_VERSION = {12, 0, 6}
local ESC_SENSOR_CONFIG_TIMEOUT = 3.0
local function noop() end
local pageButtonMeta = {}
local pageButtonHandlers = {}
local mfgProtocolMeta = {}
local detectedProtocolId = nil
local protocolFilterReady = false
local protocolReadPending = false
local protocolReadAttempted = false
local protocolReadDeadline = nil
local protocolRequestToken = 0
local openPage
local closePage
local onNavMenu
local entryWarningPending = false
local entryWarningDelayTicks = 0
local entryWarningTitle = nil
local entryWarningDialog = nil
local entryWarningStartedAt = nil
local ENTRY_WARNING_DURATION = 8.0

local function prefBool(value, default)
    if value == nil then return default end
    if value == true or value == "true" or value == 1 or value == "1" then return true end
    if value == false or value == "false" or value == 0 or value == "0" then return false end
    return default
end

local function openProgressDialog(...)
    if rfsuite.utils.ethosVersionAtLeast({26, 1, 0}) and form.openWaitDialog then
        local arg1 = select(1, ...)
        if type(arg1) == "table" then
            arg1.progress = true
            return form.openWaitDialog(arg1)
        end
        local title = arg1
        local message = select(2, ...)
        return form.openWaitDialog({title = title, message = message, progress = true})
    end
    return form.openProgressDialog(...)
end

local function closeEntryWarningDialog()
    if not entryWarningDialog then return end
    local dialog = entryWarningDialog
    entryWarningDialog = nil
    entryWarningStartedAt = nil
    if dialog.close then
        pcall(dialog.close, dialog)
    end
end

local function showEntryWarningDialog(title)
    closeEntryWarningDialog()
    entryWarningDialog = openProgressDialog(title, "@i18n(app.modules.esc_tools.remove_blades_warning)@")
    if not entryWarningDialog then return end
    entryWarningStartedAt = osClock()
    if entryWarningDialog.value then
        entryWarningDialog:value(0)
    end
    if entryWarningDialog.closeAllowed then
        entryWarningDialog:closeAllowed(false)
    end
    if rfsuite.utils and rfsuite.utils.playFileCommon then
        rfsuite.utils.playFileCommon("beep.wav")
    end
end

local function clearEntryWarningState()
    entryWarningPending = false
    entryWarningDelayTicks = 0
    entryWarningTitle = nil
    closeEntryWarningDialog()
end

local function queueEntryWarning(title)
    entryWarningPending = true
    entryWarningDelayTicks = 1
    entryWarningTitle = title
end

local function shouldQueueEntryWarning(opts)
    if not prefBool(rfsuite.preferences.general.show_esc_tools_warning, true) then
        return false
    end
    if type(opts) ~= "table" then
        return false
    end
    if rfsuite.app and rfsuite.app._openedFromShortcuts == true then
        return false
    end
    if type(opts.returnStack) == "table" then
        return false
    end
    return true
end

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

local function clearProtocolMetaCache()
    for k in pairs(mfgProtocolMeta) do
        mfgProtocolMeta[k] = nil
    end
end

local function resetProtocolDetectionState()
    protocolRequestToken = protocolRequestToken + 1
    detectedProtocolId = nil
    protocolFilterReady = false
    protocolReadPending = false
    protocolReadAttempted = false
    protocolReadDeadline = nil
end

local function normalizeProtocolIds(rawIds)
    if type(rawIds) == "number" then
        return {math.floor(rawIds)}, true
    end
    if type(rawIds) ~= "table" then
        return nil, false
    end

    local ids = {}
    for i = 1, #rawIds do
        local value = tonumber(rawIds[i])
        if value ~= nil then
            ids[#ids + 1] = math.floor(value)
        end
    end
    return ids, #ids > 0
end

local function getMfgProtocolMeta(folder)
    local cached = mfgProtocolMeta[folder]
    if cached then return cached end

    local meta = {hasMapping = false, ids = nil, potential = false}
    local ok, escMeta = pcall(function()
        return assert(loadfile("app/modules/esc_tools/tools/escmfg/" .. folder .. "/init.lua"))()
    end)

    if ok and type(escMeta) == "table" then
        local ids, hasMapping = normalizeProtocolIds(escMeta.escSensorProtocolIds or escMeta.escSensorProtocolId)
        meta.hasMapping = hasMapping
        meta.ids = ids
        meta.potential = escMeta.escSensorProtocolPotential == true
    end

    mfgProtocolMeta[folder] = meta
    return meta
end

local function matchesDetectedProtocol(entry)
    local meta = getMfgProtocolMeta(entry.folder)
    if meta.hasMapping ~= true or detectedProtocolId == nil then
        return true
    end

    for i = 1, #meta.ids do
        if meta.ids[i] == detectedProtocolId then
            return true
        end
    end
    return false
end

local function canDetectEscProtocol()
    local tasks = rfsuite.tasks
    local msp = tasks and tasks.msp
    local api = msp and msp.api
    return rfsuite.session.apiVersion
        and rfsuite.utils.apiVersionCompare(">=", ESC_SENSOR_CONFIG_MIN_API_VERSION)
        and type(api) == "table"
        and type(api.load) == "function"
end

local function computeEntryDisabled(entry)
    if entry.apiversion and rfsuite.session.apiVersion and not rfsuite.utils.apiVersionCompare(">=", entry.apiversion) then
        return true
    end
    if canDetectEscProtocol() then
        if protocolReadPending == true or protocolFilterReady ~= true then
            return true
        end
        if not matchesDetectedProtocol(entry) then
            return true
        end
    end
    return false
end

local function buildEscPages()
    for i = 1, #pages do
        pages[i] = nil
    end

    for i, entry in ipairs(MFG_INDEX) do
        pages[i] = {
            folder = entry.folder,
            toolName = entry.toolName,
            image = entry.image,
            script = entry.script or DEFAULT_TOOL_SCRIPT,
            disabled = computeEntryDisabled(entry)
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

local function getStoredSelectedIdx()
    local selectedIdx = tonumber(rfsuite.preferences.menulastselected["escmain"]) or 1
    if selectedIdx < 1 then selectedIdx = 1 end
    if selectedIdx > #pages then selectedIdx = #pages end
    if selectedIdx < 1 then selectedIdx = 1 end
    rfsuite.preferences.menulastselected["escmain"] = selectedIdx
    return selectedIdx
end

local function getFocusIndex()
    local selectedIdx = getStoredSelectedIdx()
    if pages[selectedIdx] and pages[selectedIdx].disabled ~= true then
        return selectedIdx
    end

    for i = 1, #pages do
        if pages[i].disabled ~= true then
            return i
        end
    end
    return nil
end

local function applyButtonStates()
    local focusIdx = getFocusIndex()

    for childIdx, entry in ipairs(MFG_INDEX) do
        local disabled = computeEntryDisabled(entry)
        if pages[childIdx] then
            pages[childIdx].disabled = disabled
        end

        local button = rfsuite.app.formFields[childIdx]
        if button and button.enable then
            button:enable(disabled ~= true)
        end
        if focusIdx == childIdx and button and button.focus then
            button:focus()
        end
    end

    if focusIdx == nil then
        local menuButton = rfsuite.app.formNavigationFields and rfsuite.app.formNavigationFields.menu
        if menuButton and menuButton.focus then
            menuButton:focus()
        end
    end
end

local function isEscPageActive()
    return rfsuite.app and rfsuite.app.Page and rfsuite.app.Page.openPage == openPage
end

local function requestEscProtocol()
    if protocolReadAttempted == true or protocolReadPending == true or not canDetectEscProtocol() then
        return
    end

    local API = rfsuite.tasks.msp.api.load(ESC_SENSOR_CONFIG_API)
    if not API then
        protocolReadAttempted = true
        return
    end

    protocolReadAttempted = true
    protocolReadPending = true
    protocolReadDeadline = osClock() + ESC_SENSOR_CONFIG_TIMEOUT
    protocolRequestToken = protocolRequestToken + 1
    local requestToken = protocolRequestToken

    API.setCompleteHandler(function()
        if requestToken ~= protocolRequestToken then return end

        local value = rfsuite.utils.getEffectiveEscSensorProtocol(API.readValue and API.readValue("protocol") or nil)
        if value ~= nil then
            detectedProtocolId = value
            protocolFilterReady = true
        else
            detectedProtocolId = nil
            protocolFilterReady = false
        end

        protocolReadPending = false
        protocolReadDeadline = nil

        if isEscPageActive() then
            applyButtonStates()
        end
    end)

    API.setErrorHandler(function()
        if requestToken ~= protocolRequestToken then return end

        detectedProtocolId = nil
        protocolFilterReady = false
        protocolReadPending = false
        protocolReadDeadline = nil

        if isEscPageActive() then
            applyButtonStates()
        end
    end)

    local ok = API.read()
    if ok == false then
        protocolReadPending = false
        protocolReadDeadline = nil
    end
end

openPage = function(opts)
    local pidx = opts.idx
    local title = opts.title
    local script = opts.script
    local _, relativeScript = resolveModulePath(script)
    local mspProtocol = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.protocol

    if mspProtocol then
        mspProtocol.mspIntervalOveride = nil
    end
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

    resetProtocolDetectionState()
    requestEscProtocol()
    pages = buildEscPages()
    clearButtonMeta()
    getStoredSelectedIdx()

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
            if rfsuite.app.gfx_buttons["escmain"][childIdx] == nil then
                rfsuite.app.gfx_buttons["escmain"][childIdx] = loadMask("app/modules/esc_tools/tools/escmfg/" .. pvalue.folder .. "/" .. pvalue.image)
            end
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

        lc = lc + 1
        if lc == numPerRow then lc = 0 end
    end

    clearEntryWarningState()
    applyButtonStates()
    rfsuite.app.triggers.closeProgressLoader = true

    if shouldQueueEntryWarning(opts) then
        queueEntryWarning(title)
    end
end

local function wakeup()
    if protocolReadPending == true and protocolReadDeadline ~= nil and osClock() >= protocolReadDeadline then
        protocolRequestToken = protocolRequestToken + 1
        protocolReadPending = false
        protocolReadDeadline = nil
        detectedProtocolId = nil
        protocolFilterReady = false

        if isEscPageActive() then
            applyButtonStates()
        end
    end

    if entryWarningDialog then
        if not isEscPageActive() then
            closeEntryWarningDialog()
            return
        end

        local elapsed = osClock() - (entryWarningStartedAt or osClock())
        if entryWarningDialog.value then
            local pct = math.floor((elapsed / ENTRY_WARNING_DURATION) * 100)
            if pct < 0 then pct = 0 end
            if pct > 100 then pct = 100 end
            entryWarningDialog:value(pct)
        end
        if elapsed >= ENTRY_WARNING_DURATION then
            closeEntryWarningDialog()
            return
        end
    end

    if entryWarningPending ~= true then return end
    if not isEscPageActive() then
        clearEntryWarningState()
        return
    end
    if entryWarningDelayTicks > 0 then
        entryWarningDelayTicks = entryWarningDelayTicks - 1
        return
    end

    local title = entryWarningTitle or rfsuite.app.lastTitle or "@i18n(app.modules.esc_tools.name)@"
    clearEntryWarningState()
    showEntryWarningDialog(title)
end

closePage = function()
    clearEntryWarningState()
    resetProtocolDetectionState()
    clearProtocolMetaCache()
    if rfsuite.app and rfsuite.app.gfx_buttons then
        rfsuite.app.gfx_buttons["escmain"] = nil
    end
    pages = {}
    clearButtonCache()
    clearEscMaskCache()
end

onNavMenu = function()
    closePage()
    pageRuntime.openMenuContext({defaultSection = "system"})
    return true
end

rfsuite.app.uiState = rfsuite.app.uiStatus.pages

return {
    pages = pages,
    openPage = openPage,
    wakeup = wakeup,
    close = closePage,
    onNavMenu = onNavMenu,
    event = function(_, category, value) return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu}) end,
    navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
    API = {}
}
