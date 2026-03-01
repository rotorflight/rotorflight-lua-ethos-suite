--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd
local lcdColor = lcd.color
local lcdDrawText = lcd.drawText
local lcdFont = lcd.font
local lcdGetTextSize = lcd.getTextSize
local lcdGetWindowSize = lcd.getWindowSize
local lcdLoadMask = lcd.loadMask
local osClock = os.clock
local tableConcat = table.concat
local mathFloor = math.floor
local app = rfsuite.app
local session = rfsuite.session
local rfutils = rfsuite.utils

local ui = {}

local function wipeTable(t)
    if type(t) ~= "table" then return end
    for k in pairs(t) do t[k] = nil end
end

local function NOOP_PAINT() end

local MASK_CACHE_MAX = 16  -- a small cache for recently used masks; evict old entries to avoid unbounded memory growth.
ui._maskCache = ui._maskCache or {}
ui._maskCacheOrder = ui._maskCacheOrder or {}

local function maskCacheInsert(path, mask)
    local cache = ui._maskCache
    local order = ui._maskCacheOrder
    if cache[path] ~= nil then return end

    cache[path] = mask
    order[#order + 1] = path

    while #order > MASK_CACHE_MAX do
        local evictPath = order[1]
        table.remove(order, 1)
        if evictPath ~= nil then
            cache[evictPath] = nil
        end
    end
end

function ui.loadMask(path)
    if type(path) ~= "string" or path == "" then return nil end

    local cached = ui._maskCache[path]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end

    local mask = lcdLoadMask(path)
    -- Cache misses too so bad/optional paths do not repeatedly allocate/check.
    maskCacheInsert(path, mask or false)
    return mask
end

function ui.clearMaskCaches()
    wipeTable(ui._maskCache)
    wipeTable(ui._maskCacheOrder)
end

local arg = {...}
local config = arg[1]
local preferences = rfsuite.preferences
local utils = rfsuite.utils
local tasks = rfsuite.tasks
local apiCore
local navigation = assert(loadfile("app/lib/navigation.lua"))()

local MSP_DEBUG_PLACEHOLDER = "MSP Waiting"
local MAIN_MENU_CATEGORY_CONFIGURATION = "@i18n(app.header_configuration)@"
local MAIN_MENU_CATEGORY_SYSTEM = "@i18n(app.header_system)@"
local HEADER_NAV_HEIGHT_REDUCTION = 4
local HEADER_NAV_Y_SHIFT = 6
local HEADER_OVERLAY_Y_OFFSET = 5
local MENU_TRANSITION_PROGRESS = false
local NAV_FOCUS_ORDER = {"menu", "save", "reload", "tool", "help"}

local function isManifestMenuRouterScript(script)
    return type(script) == "string" and (script == "manifest_menu/menu.lua" or script == "app/modules/manifest_menu/menu.lua")
end

local function resolveScriptFromRules(rules)
    if type(rules) ~= "table" then return nil end
    for _, rule in ipairs(rules) do
        local op = rule.op or rule[1]
        local ver = rule.ver or rule[2]
        local script = rule.script or rule[3]
        if op and ver and script and utils.apiVersionCompare(op, ver) then
            return script, rule.loaderspeed
        end
    end
    return nil
end

local function resolvePageScript(page, section)
    local rules = page.script_by_mspversion or page.scriptByMspVersion
    if not rules and section then
        rules = section.script_by_mspversion or section.scriptByMspVersion
    end
    if rules then
        local chosen, speed = resolveScriptFromRules(rules)
        if chosen then return chosen, speed end
        if page.script_default then return page.script_default, page.loaderspeed end
    end
    return page.script, page.loaderspeed
end

local function resolveModuleScriptPath(moduleName, script)
    if type(script) ~= "string" or script == "" then return nil end
    if script:sub(1, 4) == "app/" then return script end
    if type(moduleName) ~= "string" or moduleName == "" then return script end

    local prefix = moduleName .. "/"
    if script:sub(1, #prefix) == prefix then return script end
    return prefix .. script
end

local function apiVersionMatches(spec)
    if type(spec) ~= "table" then return true end
    return (spec.apiversion == nil or utils.apiVersionCompare(">=", spec.apiversion)) and
        (spec.apiversionlt == nil or utils.apiVersionCompare("<", spec.apiversionlt)) and
        (spec.apiversiongt == nil or utils.apiVersionCompare(">", spec.apiversiongt)) and
        (spec.apiversionlte == nil or utils.apiVersionCompare("<=", spec.apiversionlte)) and
        (spec.apiversiongte == nil or utils.apiVersionCompare(">=", spec.apiversiongte))
end

local function menuEntryVisible(spec)
    if type(spec) ~= "table" then return false end
    if spec.ethosversion and not utils.ethosVersionAtLeast(spec.ethosversion) then return false end
    if spec.mspversion and utils.apiVersionCompare("<", spec.mspversion) then return false end
    if not apiVersionMatches(spec) then return false end
    return true
end

local function trimText(value)
    if type(value) ~= "string" then return "" end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function isTruthy(value)
    return value == true or value == "true" or value == 1 or value == "1"
end

local function splitBreadcrumbTitle(title)
    local out = {}
    if type(title) ~= "string" then return out end

    local start = 1
    while true do
        local i, j = title:find(" / ", start, true)
        if not i then
            local tail = trimText(title:sub(start))
            if tail ~= "" then out[#out + 1] = tail end
            break
        end

        local part = trimText(title:sub(start, i - 1))
        if part ~= "" then out[#out + 1] = part end
        start = j + 1
    end

    return out
end

local function normalizeBreadcrumbMatchText(value)
    local text = trimText(value)
    if text == "" then return "" end
    text = text:lower()
    text = text:gsub("[^%w]+", " ")
    text = text:gsub("%s+", " ")
    text = trimText(text)
    if text == "" then return "" end

    local tokens = {}
    for token in text:gmatch("%S+") do
        if token ~= "i18n" and token ~= "app" and token ~= "modules" and token ~= "module" and token ~= "name" and token ~= "menu" and token ~= "section" and token ~= "header" then
            tokens[#tokens + 1] = token
        end
    end

    if #tokens > 0 then
        text = tableConcat(tokens, " ")
    end

    return trimText(text)
end

local function breadcrumbLeafMatchesDisplay(leafText, displayText)
    local leaf = normalizeBreadcrumbMatchText(leafText)
    local display = normalizeBreadcrumbMatchText(displayText)
    if leaf == "" or display == "" then return false end
    if leaf == display then return true end

    if #display > #leaf and display:sub(1, #leaf) == leaf then
        local nextChar = display:sub(#leaf + 1, #leaf + 1)
        if nextChar == " " then return true end
    end

    return false
end

local function stripBreadcrumbLeafForDisplay(breadcrumb, displayTitle)
    local crumb = trimText(breadcrumb)
    local leaf = trimText(displayTitle)
    if crumb == "" or leaf == "" then return breadcrumb end

    local parts = splitBreadcrumbTitle(crumb)
    if #parts == 0 then return crumb end
    if not breadcrumbLeafMatchesDisplay(parts[#parts], leaf) then return crumb end

    parts[#parts] = nil
    if #parts == 0 then return nil end
    return tableConcat(parts, " / ")
end

local function getMainMenuCategoryBySectionIndex(sectionIndex)
    if type(sectionIndex) ~= "number" then return nil end
    local menu = app and app.MainMenu
    local sections = menu and menu.sections
    if type(sections) ~= "table" then return nil end

    local category = MAIN_MENU_CATEGORY_CONFIGURATION
    for i = 1, #sections do
        local section = sections[i] or {}
        local groupTitle = trimText(section.groupTitle)
        if groupTitle ~= "" then
            category = groupTitle
        elseif section.newline then
            category = MAIN_MENU_CATEGORY_SYSTEM
        end
        if i == sectionIndex then return category end
    end

    return nil
end

local function composeSectionPath(sectionIndex, sectionTitle)
    local title = trimText(sectionTitle)
    if title == "" then return nil end

    local category = trimText(getMainMenuCategoryBySectionIndex(sectionIndex))
    if category == "" then return title end
    return category .. " / " .. title
end

local menuLookupCache = {menuRef = nil}

local function refreshMenuLookupCache()
    local menu = app and app.MainMenu
    if menuLookupCache.menuRef == menu then return menuLookupCache end

    local cache = {
        menuRef = menu,
        sectionPathByIndex = {},
        sectionPathById = {},
        sectionPathByMenuId = {},
        sectionPathByModule = {},
        sectionPathByFolder = {}
    }

    local sections = menu and menu.sections
    if type(sections) == "table" then
        for i = 1, #sections do
            local section = sections[i]
            if section and section.title then
                local path = composeSectionPath(i, section.title)
                cache.sectionPathByIndex[i] = path
                if section.id ~= nil then cache.sectionPathById[section.id] = path end
                if type(section.menuId) == "string" and section.menuId ~= "" then
                    cache.sectionPathByMenuId[section.menuId] = path
                end
                if type(section.module) == "string" and section.module ~= "" then
                    cache.sectionPathByModule[section.module] = path
                end
            end
        end
    end

    local pages = menu and menu.pages
    if type(pages) == "table" then
        for i = 1, #pages do
            local page = pages[i]
            if page and type(page.folder) == "string" and page.folder ~= "" then
                local path = cache.sectionPathByIndex[page.section]
                if path then cache.sectionPathByFolder[page.folder] = path end
            end
        end
    end

    menuLookupCache = cache
    return menuLookupCache
end

local function getHeaderNavButtonHeight()
    local base = (app and app.radio and app.radio.navbuttonHeight) or 0
    if base <= 0 then return base end
    return math.max(20, base - HEADER_NAV_HEIGHT_REDUCTION)
end

local function getHeaderNavButtonY(baseY)
    local y = tonumber(baseY) or 0
    return math.max(0, y - HEADER_NAV_Y_SHIFT)
end

local function getHeaderTitleY(baseY)
    -- Keep title aligned with the compact button row.
    return getHeaderNavButtonY(baseY)
end

local function getHeaderNavAreaBottom()
    local baseY = (app and app.radio and app.radio.linePaddingTop) or 0
    return getHeaderNavButtonY(baseY) + getHeaderNavButtonHeight()
end

local function appendBreadcrumbParts(parts, candidate)
    if type(parts) ~= "table" then return end
    local source = splitBreadcrumbTitle(candidate)
    if #source == 0 then
        local item = trimText(candidate)
        if item ~= "" then source = {item} end
    end

    local clean = {}
    for i = 1, #source do
        local part = trimText(source[i])
        if part ~= "" then clean[#clean + 1] = part end
    end
    if #clean == 0 then return end

    if #parts == 0 then
        for i = 1, #clean do parts[#parts + 1] = clean[i] end
        return
    end

    local maxOverlap = math.min(#parts, #clean)
    local overlap = 0
    for o = maxOverlap, 1, -1 do
        local matches = true
        for i = 1, o do
            if parts[#parts - o + i] ~= clean[i] then
                matches = false
                break
            end
        end
        if matches then
            overlap = o
            break
        end
    end

    for i = overlap + 1, #clean do
        parts[#parts + 1] = clean[i]
    end
end

local function getMenuSectionTitleById(sectionId)
    if not sectionId then return nil end
    return refreshMenuLookupCache().sectionPathById[sectionId]
end

local function getMenuSectionTitleByMenuId(menuId)
    if type(menuId) ~= "string" or menuId == "" then return nil end
    return refreshMenuLookupCache().sectionPathByMenuId[menuId]
end

local function getMenuSectionTitleByScript(script)
    if type(script) ~= "string" then return nil end
    if script:sub(1, 12) == "app/modules/" then
        script = script:sub(13)
    end
    local folder = script:match("^([^/]+)")
    if not folder or folder == "" then return nil end

    local cache = refreshMenuLookupCache()
    return cache.sectionPathByFolder[folder] or cache.sectionPathByModule[folder]
end

local function getBreadcrumbFromReturnStack()
    if not app or type(app.menuContextStack) ~= "table" then return nil end
    if #app.menuContextStack == 0 then return nil end

    local parts = {}
    for i = 1, #app.menuContextStack do
        local ctx = app.menuContextStack[i]
        if type(ctx) == "table" then
            local ctxPathParts = {}
            if type(ctx.script) == "string" then
                appendBreadcrumbParts(ctxPathParts, getMenuSectionTitleByScript(ctx.script))
            end
            appendBreadcrumbParts(ctxPathParts, getMenuSectionTitleByMenuId(ctx.menuId))
            appendBreadcrumbParts(ctxPathParts, ctx.title)
            appendBreadcrumbParts(parts, tableConcat(ctxPathParts, " / "))
        end
    end

    if #parts == 0 then return nil end
    return tableConcat(parts, " / ")
end

local function isRootMainMenuContext()
    if not app then return false end
    if app.uiState ~= (app.uiStatus and app.uiStatus.mainMenu) then return false end
    return app.lastMenu == "mainmenu"
end

local function resolveHeaderContext(rawTitle, script)
    local title = rawTitle
    if title == nil then title = "No Title" end
    if type(title) ~= "string" then title = tostring(title) end
    title = trimText(title)
    if title == "" then title = "No Title" end

    local parts = splitBreadcrumbTitle(title)
    local displayTitle = title
    local parentFromTitle = nil
    if #parts > 1 then
        displayTitle = parts[#parts]
        parts[#parts] = nil
        parentFromTitle = tableConcat(parts, " / ")
    elseif #parts == 1 then
        displayTitle = parts[1]
    end

    if isRootMainMenuContext() then
        if app then
            app.headerTitle = displayTitle
            app.headerParentBreadcrumb = nil
        end
        return displayTitle, nil
    end

    local parentBreadcrumb = getBreadcrumbFromReturnStack()
    if not parentBreadcrumb or parentBreadcrumb == "" then
        parentBreadcrumb = getMenuSectionTitleById(app and app.lastMenu)
    end
    if not parentBreadcrumb or parentBreadcrumb == "" then
        parentBreadcrumb = getMenuSectionTitleByMenuId(app and (app.activeManifestMenuId or app.pendingManifestMenuId))
    end
    if not parentBreadcrumb or parentBreadcrumb == "" then
        parentBreadcrumb = getMenuSectionTitleByScript(script or (app and app.lastScript))
    end
    if (not parentBreadcrumb or parentBreadcrumb == "") and parentFromTitle and parentFromTitle ~= "" then
        parentBreadcrumb = parentFromTitle
    end
    parentBreadcrumb = stripBreadcrumbLeafForDisplay(parentBreadcrumb, displayTitle)
    if parentBreadcrumb == displayTitle then parentBreadcrumb = nil end

    if app then
        app.headerTitle = displayTitle
        app.headerParentBreadcrumb = parentBreadcrumb
    end

    return displayTitle, parentBreadcrumb
end

local function fitTextToWidth(text, maxWidth)
    if type(text) ~= "string" or text == "" then return "" end
    if type(maxWidth) ~= "number" or maxWidth <= 0 then return "" end

    if lcdGetTextSize(text) <= maxWidth then return text end

    local ellipsis = "..."
    local clipped = text
    while #clipped > 0 and lcdGetTextSize(clipped .. ellipsis) > maxWidth do
        clipped = clipped:sub(1, -2)
    end

    if clipped == "" then return ellipsis end
    return clipped .. ellipsis
end

local function drawHeaderBreadcrumbOverlay(startY, reserveRightWidth)
    if not app then return false, startY end
    if isRootMainMenuContext() then
        app.headerParentBreadcrumb = nil
        return false, startY
    end
    local breadcrumb = app.headerParentBreadcrumb
    if type(breadcrumb) ~= "string" or trimText(breadcrumb) == "" then
        breadcrumb = getBreadcrumbFromReturnStack() or
            getMenuSectionTitleById(app.lastMenu) or
            getMenuSectionTitleByMenuId(app and (app.activeManifestMenuId or app.pendingManifestMenuId)) or
            getMenuSectionTitleByScript(app.lastScript)
        breadcrumb = stripBreadcrumbLeafForDisplay(breadcrumb, app.headerTitle or app.lastTitle)
        if type(breadcrumb) == "string" then app.headerParentBreadcrumb = breadcrumb end
    end
    if type(breadcrumb) ~= "string" then return false, startY end

    breadcrumb = trimText(breadcrumb)
    if breadcrumb == "" then return false, startY end

    local screenW = app.lcdWidth
    if not screenW or screenW <= 0 then
        screenW = lcdGetWindowSize()
    end
    if not screenW or screenW <= 0 then return false, startY end
    local reserved = math.max(0, tonumber(reserveRightWidth) or 0)
    local maxTextWidth = screenW - 8 - reserved
    if maxTextWidth <= 0 then return false, startY end

    lcdFont(FONT_XXS)
    lcdColor(lcd.RGB(170, 170, 170))

    local text = fitTextToWidth(breadcrumb, maxTextWidth)
    if text == "" then return false, startY end
    lcdDrawText(0, startY, text)

    local _, textH = lcdGetTextSize(text)
    if not textH or textH <= 0 then textH = 6 end
    return true, startY + textH + 2
end

local function getMspStatusExtras()
    local m = tasks and tasks.msp
    if not m then return nil end
    local q = m.mspQueue
    if not q then return nil end

    local parts = {}

    local common = m.common
    if common and common.getLastTxCmd then
        local ok_tx, tx = pcall(common.getLastTxCmd)
        if ok_tx and tx and tx ~= 0 then parts[#parts + 1] = "Transmit " .. tostring(tx) end
    end
    if common and common.getLastRxCmd then
        local ok_rx, rx = pcall(common.getLastRxCmd)
        if ok_rx and rx and rx ~= 0 then parts[#parts + 1] = "Receive " .. tostring(rx) end
    end

    if q.retryCount ~= nil then
        local retries = q.retryCount - 1
        if retries > 0 then
            parts[#parts + 1] = "Retry " .. tostring(retries)
        end
    end

    local crc = session and session.mspCrcErrors
    if crc and crc > 0 then
        parts[#parts + 1] = "CRC " .. tostring(crc)
    end

    if session then
        local tout = session.mspTimeouts or 0
        if tout > 0 then
            parts[#parts + 1] = "Timeout " .. tostring(tout)
        end
    end

    if #parts == 0 then return nil end
    return tableConcat(parts, " ")
end

local function getMspStatusForDialog()
    if not session then return nil end
    if session.mspStatusClearAt and osClock() >= session.mspStatusClearAt then
        session.mspStatusMessage = nil
        session.mspStatusClearAt = nil
    end
    local mspStatus = session.mspStatusMessage
    if not mspStatus and session.mspStatusLast and session.mspStatusUpdatedAt and (osClock() - session.mspStatusUpdatedAt) < 0.75 then
        mspStatus = session.mspStatusLast
    end
    if preferences and preferences.general and preferences.general.mspstatusdialog then
        local extras = getMspStatusExtras()
        if extras then
            if mspStatus then
                mspStatus = mspStatus .. " " .. extras
            else
                mspStatus = extras
            end
        end
    end

    return mspStatus
end

function ui.registerProgressDialog(handle, baseMessage)
    if not session then return end
    session.progressDialog = {
        handle = handle,
        baseMessage = baseMessage or ""
    }
end

function ui.clearProgressDialog(handle)
    if not session or not session.progressDialog then return end

    if app and app.dialogs then
        if handle == nil or app.dialogs.progress == handle then
            app.dialogs.progress = nil
        end
        if handle == nil or app.dialogs.save == handle then
            app.dialogs.save = nil
        end
    end

    if handle == nil or session.progressDialog.handle == handle then
        session.progressDialog = nil
    end
end

function ui.updateProgressDialogMessage(statusOverride)

    -- First update the standard app dialogs (the ones actually on screen)
    if app and app.dialogs then
        if app.dialogs.progressDisplay and app.dialogs.progress then
            local mspStatus = statusOverride or getMspStatusForDialog()
            local base = app.dialogs.progressBaseMessage or ""
            local showDebug = preferences and preferences.general and preferences.general.mspstatusdialog
            local msg = showDebug and (mspStatus or MSP_DEBUG_PLACEHOLDER) or base
            if showDebug and mspStatus then msg = mspStatus end
            pcall(function() app.dialogs.progress:message(msg) end)
        end
        if app.dialogs.saveDisplay and app.dialogs.save then
            local mspStatus = statusOverride or getMspStatusForDialog()
            local base = app.dialogs.saveBaseMessage or ""
            local showDebug = preferences and preferences.general and preferences.general.mspstatusdialog
            local msg = showDebug and (mspStatus or MSP_DEBUG_PLACEHOLDER) or base
            if showDebug and mspStatus then msg = mspStatus end
            pcall(function() app.dialogs.save:message(msg) end)
        end
    end

    -- Then update any custom registered dialog
    local pd = session and session.progressDialog
    if pd and pd.handle then
        local mspStatus = statusOverride or getMspStatusForDialog()
        local composedMessage = pd.baseMessage or ""
        local showDebug = preferences and preferences.general and preferences.general.mspstatusdialog
        if showDebug then
            composedMessage = mspStatus or MSP_DEBUG_PLACEHOLDER
        end
        pcall(function() pd.handle:message(composedMessage) end)
    end
end

local function getApiCore()
    if apiCore then return apiCore end
    apiCore = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()
    return apiCore
end

function ui.openMenuContext(defaultSectionId, showProgress, speed)
    -- Keep menu transitions allocation-light; opening/closing progress dialogs here
    -- can cause substantial native-memory churn on some radios.
    if MENU_TRANSITION_PROGRESS and showProgress then ui.progressDisplay(nil, nil, speed) end

    local target, parentStack = navigation.popReturnContext(app)
    if target then
        local openOpts = {}
        for k, v in pairs(target) do
            openOpts[k] = v
        end
        openOpts.returnStack = parentStack
        ui.openPage(openOpts)
        return
    end

    -- No explicit target means "back to root menu", not "re-open last section".
    if type(defaultSectionId) ~= "string" or defaultSectionId == "" then
        ui.openMainMenu()
        return
    end

    local targetSectionId = navigation.resolveMenuContext(app.MainMenu, app.lastMenu, defaultSectionId)
    if targetSectionId then
        ui.openMainMenu(targetSectionId)
        return
    end

    ui.openMainMenu()
end

local function openProgressDialog(opts)
    if utils.ethosVersionAtLeast({26, 1, 0}) and form.openWaitDialog then
        opts.progress = true
        return form.openWaitDialog(opts)
    end
    return form.openProgressDialog(opts)
end

function ui.progressDisplay(title, message, speed)


    if app.dialogs.progressDisplay then return end

    title = title or "@i18n(app.msg_loading)@"
    message = message or "@i18n(app.msg_loading_from_fbl)@"

    local speedMult = tonumber(speed)
    if speedMult == nil then
        speedMult = (app.loaderSpeed and app.loaderSpeed.DEFAULT) or 1.0
    end
    app.dialogs.progressSpeed = speedMult

    local reachedTimeout = false

    if session then session.mspTimeouts = 0 end
    app.dialogs.progressDisplay = true
    app.dialogs.progressWatchDog = osClock()
    app.dialogs.progressBaseMessage = message
    app.dialogs.progressMspStatusLast = nil
    local useWaitDialog = utils.ethosVersionAtLeast({26, 1, 0}) and form.openWaitDialog
    app.dialogs.progressIsWait = useWaitDialog or false
    app.dialogs.progress = openProgressDialog({
        title = title,
        message = message,
        close = function() end,
        wakeup = function()
            local now = osClock()
            local progress = app.dialogs.progress
            if not progress then
                app.dialogs.progressDisplay = false
                app.dialogs.progressSpeed = nil
                return
            end

            progress:value(app.dialogs.progressCounter)

            local mult = app.dialogs.progressSpeed or 1.0

            local isProcessing = (app.Page and app.Page.apidata and app.Page.apidata.apiState and app.Page.apidata.apiState.isProcessing) or false
            local apiV = tostring(session.apiVersion)

            if not app.triggers.closeProgressLoader then
                app.dialogs.progressCounter = app.dialogs.progressCounter + (2 * mult)
                if app.dialogs.progressCounter > 50 and session.apiVersion and not utils.stringInArray(rfsuite.config.supportedMspApiVersion, apiV) then print("No API version yet") end
            elseif isProcessing then
                app.dialogs.progressCounter = app.dialogs.progressCounter + (3 * mult)
            elseif app.triggers.closeProgressLoader and tasks.msp and tasks.msp.mspQueue:isProcessed() then
                if app.dialogs.progressIsWait then
                    progress:close()
                    ui.clearProgressDialog(progress)
                    app.dialogs.progressDisplay = false
                    app.dialogs.progressCounter = 0
                    app.triggers.closeProgressLoader = false
                    app.dialogs.progressSpeed = nil
                    app.triggers.closeProgressLoaderNoisProcessed = false
                    return
                end
                if preferences.general.hs_loader == 0 then mult = mult * 2 end
                app.dialogs.progressCounter = app.dialogs.progressCounter + (15 * mult)
                if app.dialogs.progressCounter >= 100 then
                    progress:close()
                    ui.clearProgressDialog(progress)
                    app.dialogs.progressDisplay = false
                    app.dialogs.progressCounter = 0
                    app.triggers.closeProgressLoader = false
                    app.dialogs.progressSpeed = nil
                    app.triggers.closeProgressLoaderNoisProcessed = false
                    return
                end
            elseif app.triggers.closeProgressLoader and app.triggers.closeProgressLoaderNoisProcessed then
                if app.dialogs.progressIsWait then
                    progress:close()
                    ui.clearProgressDialog(progress)
                    app.dialogs.progressDisplay = false
                    app.dialogs.progressCounter = 0
                    app.triggers.closeProgressLoader = false
                    app.dialogs.progressSpeed = nil
                    app.triggers.closeProgressLoaderNoisProcessed = false
                    return
                end
                if preferences.general.hs_loader == 0 then mult = mult * 1.5 end
                app.dialogs.progressCounter = app.dialogs.progressCounter + (15 * mult)
                if app.dialogs.progressCounter >= 100 then
                    progress:close()
                    ui.clearProgressDialog(progress)
                    app.dialogs.progressDisplay = false
                    app.dialogs.progressCounter = 0
                    app.triggers.closeProgressLoader = false
                    app.dialogs.progressSpeed = nil
                    app.triggers.closeProgressLoaderNoisProcessed = false
                    return
                end
            end

            if app.dialogs.progressWatchDog and tasks.msp and (osClock() - app.dialogs.progressWatchDog) > tonumber(tasks.msp.protocol.pageReqTimeout) and app.dialogs.progressDisplay == true and reachedTimeout == false then
                reachedTimeout = true
                if app.pageState == app.pageStatus.rebooting or (app.triggers and app.triggers.rebootInProgress) or (session and session.resetMSP) then
                    app.dialogs.progressCounter = 0
                    app.dialogs.progressSpeed = nil
                    app.dialogs.progressDisplay = false
                    app.dialogs.progressWatchDog = nil
                    app.triggers.closeProgressLoader = false
                    app.triggers.closeProgressLoaderNoisProcessed = false
                    pcall(function() progress:close() end)
                    ui.clearProgressDialog(progress)
                    return
                end
                app.audio.playTimeout = true
                progress:message("@i18n(app.error_timed_out)@")
                progress:closeAllowed(true)
                progress:value(100)
                ui.clearProgressDialog(progress)
                app.dialogs.progressCounter = 0
                app.dialogs.progressSpeed = nil
                app.dialogs.progressDisplay = false

                ui.disableAllFields()
                ui.disableAllNavigationFields()
                ui.enableNavigationField('menu')
                return

            end

            if not tasks.msp then
                app.dialogs.progressCounter = app.dialogs.progressCounter + (2 * mult)
                if app.dialogs.progressCounter >= 100 then
                    progress:close()
                    ui.clearProgressDialog(progress)
                    app.dialogs.progressDisplay = false
                    app.dialogs.progressCounter = 0
                    app.dialogs.progressSpeed = nil
                    return
                end
            end

            local mspStatus = getMspStatusForDialog()
            local showDebug = preferences and preferences.general and preferences.general.mspstatusdialog
            local msg = showDebug and (mspStatus or MSP_DEBUG_PLACEHOLDER) or (app.dialogs.progressBaseMessage or "")
            if showDebug and mspStatus then msg = mspStatus end
            pcall(function() progress:message(msg) end)

        end
    })

    app.dialogs.progressCounter = 0
    app.dialogs.progress:value(0)
    app.dialogs.progress:closeAllowed(false)
    ui.registerProgressDialog(app.dialogs.progress, app.dialogs.progressBaseMessage)
end

function ui.progressDisplaySave(message)

    local reachedTimeout = false

    if session then session.mspTimeouts = 0 end
    app.dialogs.saveDisplay = true
    app.dialogs.saveWatchDog = osClock()
    app.dialogs.saveBaseMessage = nil
    app.dialogs.saveMspStatusLast = nil

    local SAVE_MESSAGE_TAG = {[app.pageStatus.saving] = "@i18n(app.msg_saving_settings)@", [app.pageStatus.eepromWrite] = "@i18n(app.msg_saving_settings)@", [app.pageStatus.rebooting] = "@i18n(app.msg_rebooting)@"}

    local resolvedMessage = message or SAVE_MESSAGE_TAG[app.pageState] or "@i18n(app.msg_saving_settings)@"
    local title = "@i18n(app.msg_saving)@"
    app.dialogs.saveBaseMessage = resolvedMessage

    local useWaitDialog = utils.ethosVersionAtLeast({26, 1, 0}) and form.openWaitDialog
    app.dialogs.saveIsWait = useWaitDialog or false
    app.dialogs.save = openProgressDialog({
        title = title,
        message = resolvedMessage,
        close = function() end,
        wakeup = function()
            local now = osClock()

            app.dialogs.save:value(app.dialogs.saveProgressCounter)

            local isProcessing = (app.Page and app.Page.apidata and app.Page.apidata.apiState and app.Page.apidata.apiState.isProcessing) or false

            if not app.dialogs.saveProgressCounter then app.dialogs.saveProgressCounter = 0 end

            if isProcessing then
                app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 3
            elseif app.triggers.closeSaveFake then
                if app.dialogs.saveIsWait then
                    app.triggers.closeSaveFake = false
                    app.dialogs.saveProgressCounter = 0
                    app.dialogs.saveDisplay = false
                    app.dialogs.saveWatchDog = nil
                    app.dialogs.save:close()
                    ui.setPageDirty(false)
                    ui.clearProgressDialog(app.dialogs.save)
                    return
                end
                app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 5
                if app.dialogs.saveProgressCounter >= 100 then
                    app.triggers.closeSaveFake = false
                    app.dialogs.saveProgressCounter = 0
                    app.dialogs.saveDisplay = false
                    app.dialogs.saveWatchDog = nil
                    app.dialogs.save:close()
                    ui.setPageDirty(false)
                    ui.clearProgressDialog(app.dialogs.save)

                end
            elseif tasks.msp.mspQueue:isProcessed() then
                if app.dialogs.saveIsWait then
                    app.dialogs.save:close()
                    ui.setPageDirty(false)
                    ui.clearProgressDialog(app.dialogs.save)
                    app.dialogs.saveDisplay = false
                    app.dialogs.saveProgressCounter = 0
                    app.triggers.closeSave = false
                    app.triggers.isSaving = false
                    return
                end
                app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 15
                if app.dialogs.saveProgressCounter >= 100 then
                    app.dialogs.save:close()
                    ui.setPageDirty(false)
                    ui.clearProgressDialog(app.dialogs.save)
                    app.dialogs.saveDisplay = false
                    app.dialogs.saveProgressCounter = 0
                    app.triggers.closeSave = false
                    app.triggers.isSaving = false

                end
            else
                app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 2
            end

            local timeout = tonumber(tasks.msp.protocol.saveTimeout + 5)
            local watchdogExceeded = app.dialogs.saveWatchDog and (osClock() - app.dialogs.saveWatchDog) > timeout
            local progressExceeded = (app.dialogs.saveProgressCounter > 120 and tasks.msp.mspQueue:isProcessed())
            if (watchdogExceeded or progressExceeded) and app.dialogs.saveDisplay == true and reachedTimeout == false then
                reachedTimeout = true
                if app.pageState == app.pageStatus.rebooting or (app.triggers and app.triggers.rebootInProgress) then
                    app.dialogs.saveProgressCounter = 0
                    app.dialogs.saveDisplay = false
                    app.dialogs.saveWatchDog = nil
                    app.triggers.isSaving = false
                    app.triggers.closeSave = false
                    app.triggers.closeSaveFake = false
                    pcall(function() app.dialogs.save:close() end)
                    ui.clearProgressDialog(app.dialogs.save)
                    return
                end
                app.audio.playTimeout = true
                app.dialogs.save:message("@i18n(app.error_timed_out)@")
                app.dialogs.save:closeAllowed(true)
                app.dialogs.save:value(100)
                app.dialogs.saveProgressCounter = 0
                app.dialogs.saveDisplay = false
                app.triggers.isSaving = false
                ui.clearProgressDialog(app.dialogs.save)

            end

            local mspStatus = getMspStatusForDialog()
            local showDebug = preferences and preferences.general and preferences.general.mspstatusdialog
            local msg = showDebug and (mspStatus or MSP_DEBUG_PLACEHOLDER) or (app.dialogs.saveBaseMessage or "")
            if showDebug and mspStatus then msg = mspStatus end
            pcall(function() app.dialogs.save:message(msg) end)
        end
    })

    app.dialogs.save:value(0)
    app.dialogs.save:closeAllowed(false)
    ui.registerProgressDialog(app.dialogs.save, app.dialogs.saveBaseMessage)
end

function ui.progressDisplayIsActive()


    return app.dialogs.progressDisplay or app.dialogs.saveDisplay or app.dialogs.progressDisplayEsc or app.dialogs.nolinkDisplay or app.dialogs.badversionDisplay
end

function ui.disableAllFields()


    for _, field in pairs(app.formFields) do
        if type(field) == "userdata" then
            local ok, enableFn = pcall(function() return field.enable end)
            if ok and type(enableFn) == "function" then
                field:enable(false)
            end
        end
    end
end

function ui.enableAllFields()


    for _, field in pairs(app.formFields) do
        if type(field) == "userdata" then
            local ok, enableFn = pcall(function() return field.enable end)
            if ok and type(enableFn) == "function" then
                field:enable(true)
            end
        end
    end
end

function ui.disableAllNavigationFields()


    for _, v in pairs(app.formNavigationFields) do v:enable(false) end
end

function ui.enableAllNavigationFields()


    for _, v in pairs(app.formNavigationFields) do v:enable(true) end
end

function ui.enableNavigationField(x)


    local field = app.formNavigationFields[x]
    if field then field:enable(true) end
end

function ui.disableNavigationField(x)


    local field = app.formNavigationFields[x]
    if field then field:enable(false) end
end

function ui.cleanupCurrentPage()
    if preferences and preferences.developer and preferences.developer.memstats then
        local mem_kb = collectgarbage("count")
        local function tcount(t)
            if type(t) ~= "table" then return 0 end
            local n = 0
            for _ in pairs(t) do n = n + 1 end
            return n
        end
        local apidata = tasks and tasks.msp and tasks.msp.api and tasks.msp.api.apidata
        local apiLoader = tasks and tasks.msp and tasks.msp.api
        local cbq = tasks and tasks.callback and tasks.callback._queue
        local cacheStats = utils and utils.getCacheStats and utils.getCacheStats() or nil
        local pageLabel = (app and app.lastScript) or (app and app.Page and app.Page.pageTitle) or "?"
        local function gfxMaskCount()
            if not app or type(app.gfx_buttons) ~= "table" then return 0 end
            local total = 0
            for _, section in pairs(app.gfx_buttons) do
                if type(section) == "table" then
                    for _ in pairs(section) do total = total + 1 end
                end
            end
            return total
        end
        utils.log(string.format(
            "[mem] cleanup start: %.1f KB | page=%s | apidata v=%d s=%d b=%d bc=%d p=%d o=%d | apiCache file=%d chunk=%d | help=%d gfx=%d mask=%d cbq=%d",
            mem_kb, tostring(pageLabel),
            tcount(apidata and apidata.values),
            tcount(apidata and apidata.structure),
            tcount(apidata and apidata.receivedBytes),
            tcount(apidata and apidata.receivedBytesCount),
            tcount(apidata and apidata.positionmap),
            tcount(apidata and apidata.other),
            tcount(apiLoader and apiLoader._fileExistsCache),
            tcount(apiLoader and apiLoader._chunkCache),
            tcount(ui._helpCache),
            gfxMaskCount(),
            tcount(ui._maskCache),
            tcount(cbq)
        ), "debug")
    end

    -- Let the current page release resources.
    if app.Page then
        local hook = app.Page.close or app.Page.onClose or app.Page.destroy
        if type(hook) == "function" then
            local ok, err = pcall(hook, app.Page)
            if not ok then
                utils.log("Page cleanup error: " .. tostring(err), "debug")
            end
        end
    end

    if app.Page and app.Page.apidata then
        -- Drop cached MSP API data for just this page's APIs.
        if tasks and tasks.msp and tasks.msp.api and tasks.msp.api.apidata and app.Page.apidata.api then
            local apidata = tasks.msp.api.apidata
            for _, v in ipairs(app.Page.apidata.api) do
                local apiKey = type(v) == "string" and v or v.name
                if apiKey then
                    if apidata.values then apidata.values[apiKey] = nil end
                    if apidata.structure then apidata.structure[apiKey] = nil end
                    if apidata.receivedBytes then apidata.receivedBytes[apiKey] = nil end
                    if apidata.receivedBytesCount then apidata.receivedBytesCount[apiKey] = nil end
                    if apidata.positionmap then apidata.positionmap[apiKey] = nil end
                    if apidata.other then apidata.other[apiKey] = nil end
                end
            end
        end

        if app.Page.apidata.formdata then
            if app.Page.apidata.formdata.rows then for i = 1, #app.Page.apidata.formdata.rows do app.Page.apidata.formdata.rows[i] = nil end end
            if app.Page.apidata.formdata.cols then for i = 1, #app.Page.apidata.formdata.cols do app.Page.apidata.formdata.cols[i] = nil end end
            if app.Page.apidata.formdata.fields then for i = 1, #app.Page.apidata.formdata.fields do app.Page.apidata.formdata.fields[i] = nil end end
            if app.Page.apidata.formdata.labels then for i = 1, #app.Page.apidata.formdata.labels do app.Page.apidata.formdata.labels[i] = nil end end
        end

        if app.Page.apidata.api then for i = 1, #app.Page.apidata.api do app.Page.apidata.api[i] = nil end end
        if app.Page.apidata.api_reversed then
            for k in pairs(app.Page.apidata.api_reversed) do app.Page.apidata.api_reversed[k] = nil end
        end
        if app.Page.apidata.api_by_id then
            for k in pairs(app.Page.apidata.api_by_id) do app.Page.apidata.api_by_id[k] = nil end
        end

        app.Page.apidata = nil
    end

    wipeTable(app.formFields)
    wipeTable(app.formLines)
    wipeTable(app.formNavigationFields)
    if app.gfx_buttons then
        for k in pairs(app.gfx_buttons) do
            app.gfx_buttons[k] = nil
        end
    end

    app.fieldHelpTxt = nil
    app._fieldHelpSection = nil
    ui._helpCache = {}
    if tasks and tasks.msp and tasks.msp.api and tasks.msp.api.clearHelpCache then
        tasks.msp.api.clearHelpCache()
    end

    app.Page = nil

    collectgarbage('collect')

    local dev = preferences and preferences.developer
    local logMem = dev and dev.memstats == true
    local logCache = dev and dev.logcachestats == true
    if logMem or logCache then
        local function tcount(t)
            if type(t) ~= "table" then return 0 end
            local n = 0
            for _ in pairs(t) do n = n + 1 end
            return n
        end
        local apidata = tasks and tasks.msp and tasks.msp.api and tasks.msp.api.apidata
        local apiLoader = tasks and tasks.msp and tasks.msp.api
        local cbq = tasks and tasks.callback and tasks.callback._queue
        local cacheStats = (logCache and utils and utils.getCacheStats and utils.getCacheStats()) or nil
        local pageLabel = (app and app.lastScript) or (app and app.Page and app.Page.pageTitle) or "?"
        local function gfxMaskCount()
            if not app or type(app.gfx_buttons) ~= "table" then return 0 end
            local total = 0
            for _, section in pairs(app.gfx_buttons) do
                if type(section) == "table" then
                    for _ in pairs(section) do total = total + 1 end
                end
            end
            return total
        end
        if logMem then
            local mem_kb = collectgarbage("count")
            local cacheSuffix = ""
            if logCache then
                cacheSuffix = string.format(
                    " | caches imgBmp=%d imgPath=%d file=%d dir=%d mask=%d",
                    (cacheStats and cacheStats.imageBitmap) or 0,
                    (cacheStats and cacheStats.imagePath) or 0,
                    (cacheStats and cacheStats.fileExists) or 0,
                    (cacheStats and cacheStats.dirExists) or 0,
                    tcount(ui._maskCache)
                )
            end
            utils.log(string.format(
                "[mem] cleanup end: %.1f KB | page=%s | apidata v=%d s=%d b=%d bc=%d p=%d o=%d | apiCache file=%d chunk=%d | help=%d gfx=%d mask=%d cbq=%d%s",
                mem_kb, tostring(pageLabel),
                tcount(apidata and apidata.values),
                tcount(apidata and apidata.structure),
                tcount(apidata and apidata.receivedBytes),
                tcount(apidata and apidata.receivedBytesCount),
                tcount(apidata and apidata.positionmap),
                tcount(apidata and apidata.other),
                tcount(apiLoader and apiLoader._fileExistsCache),
                tcount(apiLoader and apiLoader._chunkCache),
                tcount(ui._helpCache),
                gfxMaskCount(),
                tcount(ui._maskCache),
                tcount(cbq),
                cacheSuffix
            ), "info")
        elseif logCache then
            utils.log(string.format(
                "[cache] cleanup end: page=%s | imgBmp=%d imgPath=%d file=%d dir=%d mask=%d",
                tostring(pageLabel),
                (cacheStats and cacheStats.imageBitmap) or 0,
                (cacheStats and cacheStats.imagePath) or 0,
                (cacheStats and cacheStats.fileExists) or 0,
                (cacheStats and cacheStats.dirExists) or 0,
                tcount(ui._maskCache)
            ), "info")
        end
    end
end

function ui.resetPageState(activesection)

    ui.cleanupCurrentPage()

    wipeTable(app.formFields)

    wipeTable(app.formLines)

    app.formFieldsOffline = {}
    app.formFieldsBGTask = {}
    app.lastLabel = nil
    app.isOfflinePage = false
    app.lastMenu = nil
    navigation.clearReturnStack(app)
    app.lastIdx = nil
    app.lastTitle = nil
    app.lastScript = nil
    app.headerTitle = nil
    app.headerParentBreadcrumb = nil
    app.activeManifestMenuId = nil
    app.pendingManifestMenuId = nil

    session.lastPage = nil
    app.triggers.isReady = false
    app.uiState = app.uiStatus.mainMenu
    app.triggers.disableRssiTimeout = false
    if tasks.msp then tasks.msp.api.resetApidata() end

    if activesection then
        if not app.gfx_buttons[activesection] then app.gfx_buttons[activesection] = {} end
        for k in pairs(app.gfx_buttons) do if k ~= activesection then app.gfx_buttons[k] = nil end end
    else
        if not app.gfx_buttons["mainmenu"] then app.gfx_buttons["mainmenu"] = {} end
        for k in pairs(app.gfx_buttons) do if k ~= "mainmenu" then app.gfx_buttons[k] = nil end end
    end

    collectgarbage('collect')
end

local function openMenuSectionById(sectionId)
    if not sectionId or sectionId == "mainmenu" then return false end

    local mainMenu = app.MainMenu or assert(loadfile("app/modules/init.lua"))()
    local section, sectionIndex = navigation.findSection(mainMenu, sectionId)
    if not section then return false end

    -- Section backed by a concrete module/script page.
    if section.module then
        if section.clearReturnStack then
            navigation.clearReturnStack(app)
        end
        if section.forceMenuToMain then
            app._forceMenuToMain = true
        else
            app._forceMenuToMain = false
        end
        app._openedFromShortcuts = (section.group == "shortcuts") or (section.groupTitle == "@i18n(app.header_shortcuts)@")
        app.lastMenu = (type(section.menuContextId) == "string" and section.menuContextId ~= "") and section.menuContextId or sectionId
        app._menuFocusEpoch = (app._menuFocusEpoch or 0) + 1

        local speed = tonumber(section.loaderspeed) or (app.loaderSpeed and app.loaderSpeed.DEFAULT) or 1.0
        local script, speedOverride = resolvePageScript(section)
        if speedOverride ~= nil then
            speed = tonumber(speedOverride) or (app.loaderSpeed and app.loaderSpeed[speedOverride]) or speed
        end
        local targetScript = resolveModuleScriptPath(section.module, script) or resolveModuleScriptPath(section.module, section.script)
        if not targetScript then return false end

        app.isOfflinePage = section.offline == true
        app.ui.progressDisplay(nil, nil, speed)
        app.ui.openPage({
            idx = sectionIndex,
            title = section.title,
            script = targetScript,
            openedFromShortcuts = (section.group == "shortcuts")
        })
        return true
    end

    -- Section backed by a manifest menu id loaded through a shared menu module.
    if type(section.menuId) == "string" and section.menuId ~= "" then
        if section.clearReturnStack then
            navigation.clearReturnStack(app)
        end
        if section.forceMenuToMain then
            app._forceMenuToMain = true
        else
            app._forceMenuToMain = false
        end
        app._openedFromShortcuts = (section.group == "shortcuts") or (section.groupTitle == "@i18n(app.header_shortcuts)@")
        app.lastMenu = (type(section.menuContextId) == "string" and section.menuContextId ~= "") and section.menuContextId or sectionId
        app._menuFocusEpoch = (app._menuFocusEpoch or 0) + 1

        local speed = tonumber(section.loaderspeed) or (app.loaderSpeed and app.loaderSpeed.DEFAULT) or 1.0
        app.pendingManifestMenuId = section.menuId
        app.isOfflinePage = section.offline == true
        app.ui.openPage({
            idx = sectionIndex,
            title = section.title,
            script = "manifest_menu/menu.lua",
            menuId = section.menuId,
            openedFromShortcuts = (section.group == "shortcuts")
        })
        return true
    end

    return false
end

local function getMainMenuPressHandler(menuIndex)
    app._mainMenuPressHandlers = app._mainMenuPressHandlers or {}
    local handlers = app._mainMenuPressHandlers
    if handlers[menuIndex] then return handlers[menuIndex] end

    handlers[menuIndex] = function()
        local specs = app._mainMenuPressSpecs
        local spec = specs and specs[menuIndex]
        if type(spec) ~= "table" then return end

        local menuItem = spec.item
        if type(menuItem) ~= "table" then return end

        preferences.menulastselected["mainmenu"] = menuIndex
        if type(menuItem.id) == "string" and menuItem.id ~= "" then
            app.lastMenu = menuItem.id
        end

        local speed = tonumber(menuItem.loaderspeed) or (app.loaderSpeed and app.loaderSpeed.DEFAULT) or 1.0
        if menuItem.module then
            app.isOfflinePage = true
            local script, speedOverride = resolvePageScript(menuItem)
            if speedOverride ~= nil then
                speed = tonumber(speedOverride) or (app.loaderSpeed and app.loaderSpeed[speedOverride]) or speed
            end
            local targetScript = resolveModuleScriptPath(menuItem.module, script) or resolveModuleScriptPath(menuItem.module, menuItem.script)
            if not targetScript then return end
            app.ui.progressDisplay(nil, nil, speed)
            app.ui.openPage({
                idx = menuIndex,
                title = menuItem.title,
                script = targetScript,
                openedFromShortcuts = (menuItem.group == "shortcuts")
            })
        elseif type(menuItem.menuId) == "string" and menuItem.menuId ~= "" then
            app.isOfflinePage = menuItem.offline == true
            app.pendingManifestMenuId = menuItem.menuId
            app.ui.openPage({
                idx = menuIndex,
                title = menuItem.title,
                script = "manifest_menu/menu.lua",
                menuId = menuItem.menuId,
                openedFromShortcuts = (menuItem.group == "shortcuts")
            })
        else
            app.ui.progressDisplay(nil, nil, speed)
            app.ui.openMainMenu(menuItem.id)
        end
    end

    return handlers[menuIndex]
end

function ui.openMainMenu(activesection)

    if openMenuSectionById(activesection) then return end
    app._forceMenuToMain = false
    app._openedFromShortcuts = false

    ui.resetPageState()
    app.lastMenu = "mainmenu"
    app._menuFocusEpoch = (app._menuFocusEpoch or 0) + 1

    utils.reportMemoryUsage("app.openMainMenu", "start")

    if tasks.msp then tasks.msp.protocol.mspIntervalOveride = nil end

    form.clear()

    if preferences.general.iconsize == nil or preferences.general.iconsize == "" then
        preferences.general.iconsize = 1
    else
        preferences.general.iconsize = tonumber(preferences.general.iconsize)
    end

    local w, h = lcdGetWindowSize()
    local windowWidth = w
    local windowHeight = h

    local buttonW, buttonH, padding, numPerRow

    if preferences.general.iconsize == 0 then
        padding = app.radio.buttonPaddingSmall
        buttonW = (app.lcdWidth - padding) / app.radio.buttonsPerRow - padding
        buttonH = app.radio.navbuttonHeight
        numPerRow = app.radio.buttonsPerRow
    elseif preferences.general.iconsize == 1 then
        padding = app.radio.buttonPaddingSmall
        buttonW = app.radio.buttonWidthSmall
        buttonH = app.radio.buttonHeightSmall
        numPerRow = app.radio.buttonsPerRowSmall
    elseif preferences.general.iconsize == 2 then
        padding = app.radio.buttonPadding
        buttonW = app.radio.buttonWidth
        buttonH = app.radio.buttonHeight
        numPerRow = app.radio.buttonsPerRow
    end

    app.gfx_buttons["mainmenu"] = app.gfx_buttons["mainmenu"] or {}
    preferences.menulastselected["mainmenu"] = preferences.menulastselected["mainmenu"] or 1

    -- Prefer the already-built menu structure; fallback resolves through modules/init normalization.
    local Menu = (app.MainMenu and app.MainMenu.sections) or (assert(loadfile("app/modules/init.lua"))().sections)

    local lc, bx, y = 0, 0, 0

    local menuOnlyNav = {menu = true, save = false, reload = false, tool = false, help = false}
    local header = form.addLine("")
    app.ui.setHeaderTitle("@i18n(app.header_configuration)@", header, menuOnlyNav)
    app.ui.navigationButtons(windowWidth - 5, getHeaderNavButtonY(app.radio.linePaddingTop), app.radio.menuButtonWidth or 100, getHeaderNavButtonHeight(), {
        navButtons = menuOnlyNav,
        onNavMenu = function()
            app.close()
        end
    })
    app.ui.disableAllNavigationFields()
    app.ui.enableNavigationField("menu")

    local pidx = 0
    local activeMenuGroup = nil
    app._mainMenuPressSpecs = app._mainMenuPressSpecs or {}
    wipeTable(app._mainMenuPressSpecs)
    for _, pvalue in ipairs(Menu) do
        if pvalue.parent == nil then
            local menuItem = pvalue
            if menuEntryVisible(menuItem) then
                pidx = pidx + 1
                local menuIndex = pidx

                app.formFieldsOffline[menuIndex] = menuItem.offline or false
                app.formFieldsBGTask[menuIndex] = menuItem.bgtask or false

                local treatAsMixedShortcut = (menuItem._mixedShortcut == true)
                local groupChanged = false
                if (not treatAsMixedShortcut) and type(menuItem.group) == "string" and menuItem.group ~= "" then
                    if activeMenuGroup ~= menuItem.group then
                        activeMenuGroup = menuItem.group
                        groupChanged = true
                    end
                end

                if groupChanged then
                    lc = 0
                    if pidx > 1 and type(menuItem.groupTitle) == "string" and menuItem.groupTitle ~= "" then
                        form.addLine(menuItem.groupTitle)
                    end
                elseif menuItem.newline and (not treatAsMixedShortcut) then
                    -- Legacy fallback for older manifests; grouped menus should use group/groupTitle.
                    lc = 0
                    form.addLine(menuItem.groupTitle or "@i18n(app.header_system)@")
                end

                if lc == 0 then y = form.height() + ((preferences.general.iconsize == 2) and app.radio.buttonPadding or app.radio.buttonPaddingSmall) end

                bx = (buttonW + padding) * lc

                if preferences.general.iconsize ~= 0 then
                    app.gfx_buttons["mainmenu"][menuIndex] = ui.loadMask(menuItem.image)
                else
                    app.gfx_buttons["mainmenu"][menuIndex] = nil
                end

                app._mainMenuPressSpecs[menuIndex] = {item = menuItem}
                app.formFields[menuIndex] = form.addButton(line, {x = bx, y = y, w = buttonW, h = buttonH}, {
                    text = menuItem.title,
                    icon = app.gfx_buttons["mainmenu"][menuIndex],
                    options = FONT_S,
                    paint = NOOP_PAINT,
                    press = getMainMenuPressHandler(menuIndex)
                })

                app.formFields[menuIndex]:enable(false)

                lc = lc + 1
                if lc == numPerRow then lc = 0 end
            end
        end
    end

    app.triggers.closeProgressLoader = true

    utils.reportMemoryUsage("app.openMainMenu", "end")

    collectgarbage('collect')
end

function ui.getLabel(id, page)
    if id == nil then return nil end
    for i = 1, #page do if page[i].label == id then return page[i] end end
    return nil
end

function ui._guardField(fields, i)
    if not (fields and fields[i]) then
        ui.disableAllFields()
        ui.disableAllNavigationFields()
        ui.enableNavigationField('menu')
        return nil
    end
    return fields[i]
end

function ui._prepareFieldLine(f, radioText)
    local formLines = app.formLines
    local posField

    if f.inline and f.inline >= 1 and f.label then
        if radioText == 2 and f.t2 then f.t = f.t2 end
        local p = app.utils.getInlinePositions(f)
        posField = p.posField
        form.addStaticText(formLines[app.formLineCnt], p.posText, f.t)
    else
        if radioText == 2 and f.t2 then f.t = f.t2 end
        if f.t then
            if f.label then f.t = "        " .. f.t end
        else
            f.t = ""
        end
        app.formLineCnt = app.formLineCnt + 1
        formLines[app.formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    return posField
end

function ui._shouldManageDirtySave()
    if not app.Page then return false end
    if app.Page.disableSaveUntilDirty == false then return false end
    local pref = preferences and preferences.general and preferences.general.save_dirty_only
    if pref == false or pref == "false" then return false end
    local save = app.formNavigationFields and app.formNavigationFields.save
    return save and save.enable
end

function ui.setPageDirty(isDirty)
    app.pageDirty = isDirty and true or false
    local save = app.formNavigationFields and app.formNavigationFields.save
    if save and save.enable then
        if app.Page and app.Page.canSave then
            save:enable(app.Page.canSave(app.Page) == true)
            return
        end
        if ui._shouldManageDirtySave() then
            save:enable(app.pageDirty)
        end
    end
end

function ui.markPageDirty()
    if app.pageDirty then return end
    ui.setPageDirty(true)
end

function ui._installDirtyCallbackWrappers()
    if ui._dirtyWrappersInstalled then return end
    if not form then return end

    local function wrapSetter(methodName)
        local original = form[methodName]
        if type(original) ~= "function" then return end
        form[methodName] = function(...)
            local argc = select("#", ...)
            local args = {...}
            local setterIdx = nil
            for i = argc, 1, -1 do
                if type(args[i]) == "function" then
                    setterIdx = i
                    break
                end
            end
            if setterIdx then
                local setter = args[setterIdx]
                args[setterIdx] = function(...)
                    ui.markPageDirty()
                    return setter(...)
                end
            end
            return original(table.unpack(args, 1, argc))
        end
    end

    wrapSetter("addBooleanField")
    wrapSetter("addChoiceField")
    wrapSetter("addNumberField")
    wrapSetter("addTextField")
    wrapSetter("addSourceField")
    wrapSetter("addSensorField")
    wrapSetter("addColorField")
    wrapSetter("addSwitchField")

    ui._dirtyWrappersInstalled = true
end

function ui.fieldBoolean(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = ui._guardField(fields, i)
    local formLines = app.formLines
    local formFields = app.formFields
    local radioText = app.radio.text

    if not f then return end

    local invert = (f.subtype == 1)

    local posField = ui._prepareFieldLine(f, radioText)

    local function decode()
        local active = ui._guardField(fields, i)
        if not active then return nil end
        local v = (active.value == 1) and 1 or 0
        if invert then v = (v == 1) and 0 or 1 end
        return (v == 1)
    end

    local function encode(b)
        local v = b and 1 or 0
        if invert then v = (v == 1) and 0 or 1 end
        return v
    end

    formFields[i] = form.addBooleanField(formLines[app.formLineCnt], posField, function() return decode() end, function(valueBool)
        ui.markPageDirty()
        local value = encode(valueBool == true)
        if f.postEdit then f.postEdit(page, value) end
        if f.onChange then f.onChange(page, value) end
        f.value = app.utils.saveFieldValue(fields[i], value)
    end)

    if f.disable then formFields[i]:enable(false) end
end

function ui.fieldBooleanInverted(i, lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields and fields[i] or nil
    local prevSubtype = f and f.subtype or nil
    if f then f.subtype = 1 end
    ui.fieldBoolean(i, lf)
    if f then f.subtype = prevSubtype end
end

function ui.fieldChoice(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields[i]
    local formLines = app.formLines
    local formFields = app.formFields
    local radioText = app.radio.text

    local posField = ui._prepareFieldLine(f, radioText)

    local tbldata = f.table and app.utils.convertPageValueTable(f.table, f.tableIdxInc) or {}
    if f.tableEthos then
        tbldata = f.tableEthos
    end


    formFields[i] = form.addChoiceField(formLines[app.formLineCnt], posField, tbldata, function()
        local active = ui._guardField(fields, i)
        if not active then return nil end
        return app.utils.getFieldValue(active)
    end, function(value)
        ui.markPageDirty()
        if f.postEdit then f.postEdit(page, value) end
        if f.onChange then f.onChange(page, value) end
        f.value = app.utils.saveFieldValue(fields[i], value)
    end)

    if f.disable then formFields[i]:enable(false) end
end

function ui.fieldSlider(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields[i]
    local formLines = app.formLines
    local formFields = app.formFields

    local posField = ui._prepareFieldLine(f)

    if f.offset then
        if f.min then f.min = f.min + f.offset end
        if f.max then f.max = f.max + f.offset end
    end

    local minValue = app.utils.scaleValue(f.min, f)
    local maxValue = app.utils.scaleValue(f.max, f)

    if f.mult then
        if minValue then minValue = minValue * f.mult end
        if maxValue then maxValue = maxValue * f.mult end
    end

    minValue = minValue or 0
    maxValue = maxValue or 0

    formFields[i] = form.addSliderField(formLines[app.formLineCnt], posField, minValue, maxValue, function()
        if not (fields and fields[i]) then
            ui.disableAllFields()
            ui.disableAllNavigationFields()
            ui.enableNavigationField('menu')
            return nil
        end
        return app.utils.getFieldValue(fields[i])
    end, function(value)
        ui.markPageDirty()
        if f.postEdit then f.postEdit(page) end
        if f.onChange then f.onChange(page) end
        f.value = app.utils.saveFieldValue(fields[i], value)
    end)

    local currentField = formFields[i]

    if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end

    if f.decimals then currentField:decimals(f.decimals) end
    if f.step then currentField:step(f.step) end
    if f.disable then currentField:enable(false) end

    if f.help or f.apikey then
        if not f.help and f.apikey then f.help = f.apikey end
        local fieldHelpTxt = ui.getFieldHelpTxt()
        if fieldHelpTxt and fieldHelpTxt[f.help] and fieldHelpTxt[f.help].t then currentField:help(fieldHelpTxt[f.help].t) end
    end

end

function ui.fieldNumber(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields[i]
    local formLines = app.formLines
    local formFields = app.formFields

    local posField = ui._prepareFieldLine(f)

    if f.offset then
        if f.min then f.min = f.min + f.offset end
        if f.max then f.max = f.max + f.offset end
    end

    local minValue = app.utils.scaleValue(f.min, f)
    local maxValue = app.utils.scaleValue(f.max, f)

    if f.mult then
        if minValue then minValue = minValue * f.mult end
        if maxValue then maxValue = maxValue * f.mult end
    end

    minValue = minValue or 0
    maxValue = maxValue or 0

    formFields[i] = form.addNumberField(formLines[app.formLineCnt], posField, minValue, maxValue, function()
        local active = ui._guardField(fields, i)
        if not active then return nil end
        return app.utils.getFieldValue(active)
    end, function(value)
        ui.markPageDirty()
        if f.postEdit then f.postEdit(page) end
        if f.onChange then f.onChange(page) end
        f.value = app.utils.saveFieldValue(page.apidata.formdata.fields[i], value)
    end)

    local currentField = formFields[i]

    if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end

    if f.default then
        if f.offset then f.default = f.default + f.offset end
        local default = f.default * rfutils.decimalInc(f.decimals)
        if f.mult then default = default * f.mult end
        local str = tostring(default)
        if str:match("%.0$") then default = math.ceil(default) end
        currentField:default(default)
    else
        currentField:default(0)
    end

    if f.decimals then currentField:decimals(f.decimals) end
    if f.unit then currentField:suffix(f.unit) end
    if f.step then currentField:step(f.step) end
    if f.disable then currentField:enable(false) end

    if f.help or f.apikey then
        if not f.help and f.apikey then f.help = f.apikey end
        local fieldHelpTxt = ui.getFieldHelpTxt()
        if fieldHelpTxt and fieldHelpTxt[f.help] and fieldHelpTxt[f.help].t then currentField:help(fieldHelpTxt[f.help].t) end
    end

    if f.instantChange == false then
        currentField:enableInstantChange(false)
    else
        currentField:enableInstantChange(true)
    end
end

function ui.fieldSource(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields[i]
    local formLines = app.formLines
    local formFields = app.formFields

    local posField = ui._prepareFieldLine(f)

    if f.offset then
        if f.min then f.min = f.min + f.offset end
        if f.max then f.max = f.max + f.offset end
    end

    local minValue = app.utils.scaleValue(f.min, f)
    local maxValue = app.utils.scaleValue(f.max, f)

    if f.mult then
        if minValue then minValue = minValue * f.mult end
        if maxValue then maxValue = maxValue * f.mult end
    end

    minValue = minValue or 0
    maxValue = maxValue or 0

    formFields[i] = form.addSourceField(formLines[app.formLineCnt], posField, function()
        local active = ui._guardField(fields, i)
        if not active then return nil end
        return app.utils.getFieldValue(active)
    end, function(value)
        ui.markPageDirty()
        if f.postEdit then f.postEdit(page) end
        if f.onChange then f.onChange(page) end
        f.value = app.utils.saveFieldValue(page.apidata.formdata.fields[i], value)
    end)

    local currentField = formFields[i]

    if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end

    if f.disable then currentField:enable(false) end

end

function ui.fieldSensor(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields[i]
    local formLines = app.formLines
    local formFields = app.formFields

    local posField = ui._prepareFieldLine(f)

    if f.offset then
        if f.min then f.min = f.min + f.offset end
        if f.max then f.max = f.max + f.offset end
    end

    local minValue = app.utils.scaleValue(f.min, f)
    local maxValue = app.utils.scaleValue(f.max, f)

    if f.mult then
        if minValue then minValue = minValue * f.mult end
        if maxValue then maxValue = maxValue * f.mult end
    end

    minValue = minValue or 0
    maxValue = maxValue or 0

    formFields[i] = form.addSensorField(formLines[app.formLineCnt], posField, function()
        local active = ui._guardField(fields, i)
        if not active then return nil end
        return app.utils.getFieldValue(active)
    end, function(value)
        ui.markPageDirty()
        if f.postEdit then f.postEdit(page) end
        if f.onChange then f.onChange(page) end
        f.value = app.utils.saveFieldValue(page.apidata.formdata.fields[i], value)
    end)

    local currentField = formFields[i]

    if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end

    if f.disable then currentField:enable(false) end

end

function ui.fieldColor(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields[i]
    local formLines = app.formLines
    local formFields = app.formFields

    local posField = ui._prepareFieldLine(f)

    if f.offset then
        if f.min then f.min = f.min + f.offset end
        if f.max then f.max = f.max + f.offset end
    end

    local minValue = app.utils.scaleValue(f.min, f)
    local maxValue = app.utils.scaleValue(f.max, f)

    if f.mult then
        if minValue then minValue = minValue * f.mult end
        if maxValue then maxValue = maxValue * f.mult end
    end

    minValue = minValue or 0
    maxValue = maxValue or 0

    formFields[i] = form.addColorField(formLines[app.formLineCnt], posField, function()
        local active = ui._guardField(fields, i)
        if not active then return COLOR_BLACK end
        local color = active
        if type(color) ~= "number" then
            return COLOR_BLACK
        else
            return color
        end
    end, function(value)
        ui.markPageDirty()
        if f.postEdit then f.postEdit(page) end
        if f.onChange then f.onChange(page) end
        f.value = app.utils.saveFieldValue(page.apidata.formdata.fields[i], value)
    end)

    local currentField = formFields[i]

    if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end

    if f.disable then currentField:enable(false) end

end

function ui.fieldSwitch(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields[i]
    local formLines = app.formLines
    local formFields = app.formFields

    local posField = ui._prepareFieldLine(f)

    if f.offset then
        if f.min then f.min = f.min + f.offset end
        if f.max then f.max = f.max + f.offset end
    end

    local minValue = app.utils.scaleValue(f.min, f)
    local maxValue = app.utils.scaleValue(f.max, f)

    if f.mult then
        if minValue then minValue = minValue * f.mult end
        if maxValue then maxValue = maxValue * f.mult end
    end

    minValue = minValue or 0
    maxValue = maxValue or 0

    formFields[i] = form.addSwitchField(formLines[app.formLineCnt], posField, function()
        local active = ui._guardField(fields, i)
        if not active then return nil end
        return app.utils.getFieldValue(active)
    end, function(value)
        ui.markPageDirty()
        if f.postEdit then f.postEdit(page) end
        if f.onChange then f.onChange(page) end
        f.value = app.utils.saveFieldValue(page.apidata.formdata.fields[i], value)
    end)

    local currentField = formFields[i]

    if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end

    if f.disable then currentField:enable(false) end

end

function ui.fieldStaticText(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields[i]
    local formLines = app.formLines
    local formFields = app.formFields
    local radioText = app.radio.text

    local posField = ui._prepareFieldLine(f, radioText)
    local active = ui._guardField(fields, i)
    if not active then return end
    formFields[i] = form.addStaticText(formLines[app.formLineCnt], posField, app.utils.getFieldValue(active))

    local currentField = formFields[i]
    if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end
    if f.decimals then currentField:decimals(f.decimals) end
    if f.unit then currentField:suffix(f.unit) end
    if f.step then currentField:step(f.step) end
end

function ui.fieldText(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields[i]
    local formLines = app.formLines
    local formFields = app.formFields
    local radioText = app.radio.text

    local posField = ui._prepareFieldLine(f, radioText)

    formFields[i] = form.addTextField(formLines[app.formLineCnt], posField, function()
        local active = ui._guardField(fields, i)
        if not active then return nil end
        return app.utils.getFieldValue(active)
    end, function(value)
        ui.markPageDirty()
        if f.postEdit then f.postEdit(page) end
        if f.onChange then f.onChange(page) end
        f.value = app.utils.saveFieldValue(fields[i], value)
    end)

    local currentField = formFields[i]
    if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end
    if f.disable then currentField:enable(false) end

    if f.help then
        local fieldHelpTxt = ui.getFieldHelpTxt()
        if fieldHelpTxt and fieldHelpTxt[f.help] and fieldHelpTxt[f.help].t then currentField:help(fieldHelpTxt[f.help].t) end
    end

    if f.instantChange == false then
        currentField:enableInstantChange(false)
    else
        currentField:enableInstantChange(true)
    end
end

function ui.fieldLabel(f, i, l)

    if f.t then
        if f.t2 then f.t = f.t2 end
        if f.label then f.t = "        " .. f.t end
    end

    if f.label then
        local label = app.ui.getLabel(f.label, l)
        local labelValue = label.t
        if label.t2 then labelValue = label.t2 end
        local labelName = f.t and labelValue or "unknown"

        if f.label ~= app.lastLabel then
            label.type = label.type or 0
            app.formLineCnt = app.formLineCnt + 1
            app.formLines[app.formLineCnt] = form.addLine(labelName)
            form.addStaticText(app.formLines[app.formLineCnt], nil, "")
            app.lastLabel = f.label
        end
    end
end

local function textWidth(s)
    local ok, tw = pcall(lcdGetTextSize, s or "")
    if ok and type(tw) == "number" then return tw end
    return #(s or "") * 10
end

function ui.fitHeaderTitle(rawTitle, maxW)
    local t = tostring(rawTitle or "")
    if textWidth(t) <= maxW then return t end

    local parts = {}
    for part in t:gmatch("([^/]+)") do
        parts[#parts + 1] = (part:gsub("^%s+", ""):gsub("%s+$", ""))
    end

    if #parts > 1 then
        for i = 2, #parts do
            local candidate = "... / " .. tableConcat(parts, " / ", i, #parts)
            if textWidth(candidate) <= maxW then return candidate end
        end
    end

    local ellipsis = "..."
    if textWidth(ellipsis) >= maxW then return ellipsis end

    local tail = t
    while #tail > 1 do
        local candidate = ellipsis .. tail
        if textWidth(candidate) <= maxW then return candidate end
        tail = tail:sub(2)
    end

    return ellipsis
end

function ui.getHeaderMetrics(navButtons)
    local radio = app.radio
    local w, _ = lcdGetWindowSize()
    local padding = 5
    local buttonW = radio.menuButtonWidth or 100
    local buttonH = getHeaderNavButtonHeight()
    local buttons = navButtons or {menu = true}
    local navX = w - 5
    local reserved = 0

    local menuOnlyHeader = (type(buttons) == "table")
        and (buttons.menu == true)
        and (buttons.save == nil)
        and (buttons.reload == nil)
        and (buttons.tool == nil)
        and (buttons.help == nil)

    -- Standard page headers always allocate full nav slots for stable layout.
    if menuOnlyHeader then
        reserved = buttonW + padding
    else
        reserved = (buttonW + padding) * 5
    end

    local titleRightEdge = navX - reserved
    local titleWidth = math.max(40, titleRightEdge - 8)
    return {
        windowWidth = w,
        buttonW = buttonW,
        buttonH = buttonH,
        titleWidth = titleWidth
    }
end

function ui.getHeaderNavButtonHeight()
    return getHeaderNavButtonHeight()
end

function ui.getHeaderNavButtonY(baseY)
    return getHeaderNavButtonY(baseY)
end

function ui.getHeaderTitleY(baseY)
    return getHeaderTitleY(baseY)
end

function ui.setHeaderTitle(rawTitle, lineRef, navButtons)
    local radio = app.radio
    local formFields = app.formFields
    local metrics = ui.getHeaderMetrics(navButtons)
    local resolvedTitle = resolveHeaderContext(rawTitle, app and app.lastScript)
    local displayTitle = ui.fitHeaderTitle(resolvedTitle, metrics.titleWidth)
    local titleY = getHeaderTitleY(radio.linePaddingTop)
    local lineObj = lineRef or (formFields and formFields["menu"]) or nil
    if not lineObj then return end

    if lineRef and formFields then
        formFields["title"] = form.addStaticText(lineObj, {x = 0, y = titleY, w = metrics.titleWidth, h = radio.navbuttonHeight}, displayTitle)
        return
    end

    if formFields and formFields["title"] and formFields["title"].value then
        pcall(function() formFields["title"]:value(displayTitle) end)
        return
    end

    if formFields then
        formFields["title"] = form.addStaticText(lineObj, {x = 0, y = titleY, w = metrics.titleWidth, h = radio.navbuttonHeight}, displayTitle)
    else
        form.addStaticText(lineObj, {x = 0, y = titleY, w = metrics.titleWidth, h = radio.navbuttonHeight}, displayTitle)
    end
end

function ui.fieldHeader(title)
    local radio = app.radio
    local formFields = app.formFields

    local navButtons = (app.Page and app.Page.navButtons) or {menu = true, save = true, reload = true, help = true}
    local metrics = ui.getHeaderMetrics(navButtons)
    formFields["menu"] = form.addLine("")
    ui.setHeaderTitle(title, formFields["menu"], navButtons)
    app.ui.navigationButtons(metrics.windowWidth - 5, getHeaderNavButtonY(radio.linePaddingTop), metrics.buttonW, metrics.buttonH)
end

function ui.openPageRefresh(opts)
    app.triggers.isReady = false
end


ui._helpCache = ui._helpCache or {}
ui._helpExistsCache = ui._helpExistsCache or {}

local function resolveHelpContext(scriptPath)
    if type(scriptPath) ~= "string" then return nil, nil end

    local normalized = scriptPath
    if normalized:sub(1, 12) == "app/modules/" then
        normalized = normalized:sub(13)
    end

    local section = normalized:match("([^/]+)")
    local script = normalized:match("/([^/]+)%.lua$")
    return section, script
end

local function sectionHasHelpFile(section)
    if type(section) ~= "string" or section == "" then return false end

    if ui._helpExistsCache[section] == nil then
        local helpPath = "app/modules/" .. section .. "/help.lua"
        ui._helpExistsCache[section] = (utils.file_exists(helpPath) == true)
    end

    return ui._helpExistsCache[section] == true
end

local function getHelpData(section)
    if type(section) ~= "string" or section == "" then return nil end

    if ui._helpCache[section] == nil then
        if sectionHasHelpFile(section) then
            local helpPath = "app/modules/" .. section .. "/help.lua"
            local chunk = loadfile(helpPath)
            local helpData = chunk and chunk() or nil

            ui._helpCache[section] =
                (type(helpData) == "table") and helpData or false
        else
            ui._helpCache[section] = false
        end
    end

    return ui._helpCache[section] or nil
end

function ui.getFieldHelpTxt()
    local section = resolveHelpContext(app.lastScript)
    if not section then
        app.fieldHelpTxt = nil
        app._fieldHelpSection = nil
        return nil
    end

    if app._fieldHelpSection ~= section then
        local helpData = getHelpData(section)
        app.fieldHelpTxt = helpData and helpData.fields or nil
        app._fieldHelpSection = section
    end

    return app.fieldHelpTxt
end

local function openSectionHelp(section, script)
    local helpData = getHelpData(section)
    if not (helpData and type(helpData.help) == "table") then return false end

    if script and helpData.help[script] then
        app.ui.openPageHelp(helpData.help[script])
        return true
    end

    if helpData.help["default"] then
        app.ui.openPageHelp(helpData.help["default"])
        return true
    end

    return false
end


function ui.openPage(opts)

    if type(opts) ~= "table" then
        error("ui.openPage expects a table")
    end

    local idx = opts.idx
    local title = opts.title
    local script = opts.script
    local returnContext = opts.returnContext
    local returnStack = opts.returnStack
    if not script then
        error("ui.openPage requires opts.script")
    end

    if isManifestMenuRouterScript(script) then
        if type(opts.menuId) == "string" and opts.menuId ~= "" then
            app.pendingManifestMenuId = opts.menuId
        elseif (type(app.pendingManifestMenuId) ~= "string" or app.pendingManifestMenuId == "") and type(app.activeManifestMenuId) == "string" and app.activeManifestMenuId ~= "" then
            app.pendingManifestMenuId = app.activeManifestMenuId
        end
    end

    if type(returnStack) == "table" then
        navigation.setReturnStack(app, returnStack)
    elseif type(returnContext) == "table" and type(returnContext.script) == "string" then
        navigation.pushReturnContext(app, returnContext)
    elseif returnContext == false then
        navigation.clearReturnStack(app)
    end

    utils.reportMemoryUsage("ui.openPage: " .. script, "start")
    ui._installDirtyCallbackWrappers()

    -- Ensure previous page releases resources before loading a new one.
    ui.cleanupCurrentPage()

    app.uiState = app.uiStatus.pages
    app.triggers.isReady = false
    app.lastLabel = nil

    wipeTable(app.formFields)
    wipeTable(app.formLines)

    local modulePath = script
    if type(modulePath) ~= "string" then
        error("ui.openPage requires opts.script to be a string")
    end
    if modulePath:sub(1, 4) ~= "app/" then
        modulePath = "app/modules/" .. modulePath
    end
    if opts.openedFromShortcuts ~= nil then
        app._openedFromShortcuts = (opts.openedFromShortcuts == true)
    end
    app.Page = assert(loadfile(modulePath))(idx)
    if app._openedFromShortcuts or app._forceMenuToMain then
        app.Page.onNavMenu = function()
            ui.openMainMenu()
            return true
        end
    end
    if app._forceMenuToMain then
        app._forceMenuToMain = false
        app.Page.onNavMenu = function()
            ui.openMainMenu()
            return true
        end
    end

    app.fieldHelpTxt = nil
    app._fieldHelpSection = nil

    if app.Page.openPage then
        app._pageUsesCustomOpen = true

        utils.reportMemoryUsage("app.Page.openPage: " .. script, "start")

        app.Page.openPage(opts)
        if ui._shouldManageDirtySave() and app.Page.disableSaveUntilDirty ~= false and not app.Page.canSave then
            app.Page.canSave = function()
                return app.pageDirty == true
            end
        end
        ui.setPageDirty(false)
        collectgarbage('collect')
        utils.reportMemoryUsage("app.Page.openPage: " .. script, "end")
        return
    end
    app._pageUsesCustomOpen = false

    app.lastIdx = idx
    app.lastTitle = title
    app.lastScript = script

    form.clear()
    session.lastPage = script

    local pageTitle = app.Page.pageTitle or title
    app.ui.fieldHeader(pageTitle)

    if app.Page.headerLine then
        local headerLine = form.addLine("")
        form.addStaticText(headerLine, {x = 0, y = app.radio.linePaddingTop, w = app.lcdWidth, h = app.radio.navbuttonHeight}, app.Page.headerLine)
    end

    app.formLineCnt = 0

    if not ui._fieldHandlers then
        ui._fieldHandlers = {
            [0] = ui.fieldStaticText,
            [1] = ui.fieldChoice,
            [2] = ui.fieldNumber,
            [3] = ui.fieldText,
            [4] = ui.fieldBoolean,
            [5] = ui.fieldBooleanInverted or ui.fieldBoolean,
            [6] = ui.fieldSlider,
            [7] = ui.fieldSource,
            [8] = ui.fieldSwitch,
            [9] = ui.fieldSensor,
            [10] = ui.fieldColor
        }
    end

    if app.Page.apidata and app.Page.apidata.formdata and app.Page.apidata.formdata.fields then
        for i, field in ipairs(app.Page.apidata.formdata.fields) do
            local label = app.Page.apidata.formdata.labels
            if session.apiVersion == nil then return end

            local valid = (field.apiversion == nil or utils.apiVersionCompare(">=", field.apiversion)) and (field.apiversionlt == nil or utils.apiVersionCompare("<", field.apiversionlt)) and (field.apiversiongt == nil or utils.apiVersionCompare(">", field.apiversiongt)) and (field.apiversionlte == nil or utils.apiVersionCompare("<=", field.apiversionlte)) and (field.apiversiongte == nil or utils.apiVersionCompare(">=", field.apiversiongte)) and
                              (field.enablefunction == nil or field.enablefunction())

            if field.hidden ~= true and valid then
                app.ui.fieldLabel(field, i, label)
                local fieldType = field.table and 1 or field.type
                local handler = ui._fieldHandlers[fieldType] or ui.fieldNumber
                handler(i)
            else
                app.formFields[i] = {}
            end
        end
    end

    utils.reportMemoryUsage("ui.openPage: " .. script, "end")

    collectgarbage('collect')
    collectgarbage('collect')
end

local function getNavButtonContext()
    app._navButtonContext = app._navButtonContext or {}
    return app._navButtonContext
end

local function onNavButtonMenuPress()
    local ctx = getNavButtonContext()
    if app._openedFromShortcuts or app._forceMenuToMain then
        app.ui.openMainMenu()
        return
    end
    if ctx.onNavMenu then
        ctx.onNavMenu()
    elseif app.Page and app.Page.onNavMenu then
        app.Page.onNavMenu(app.Page)
    else
        app.ui.openMenuContext()
    end
end

local function onNavButtonSavePress()
    if app.Page and app.Page.onSaveMenu then
        app.Page.onSaveMenu(app.Page)
    else
        app.triggers.triggerSave = true
    end
end

local function onNavButtonReloadPress()
    if app.Page and app.Page.onReloadMenu then
        app.Page.onReloadMenu(app.Page)
    else
        app.triggers.triggerReload = true
    end
    return true
end

local function onNavButtonToolPress()
    if app.Page and app.Page.onToolMenu then app.Page.onToolMenu(app.Page) end
end

local function onNavButtonHelpPress()
    local ctx = getNavButtonContext()
    if app.Page and app.Page.onHelpMenu then
        app.Page.onHelpMenu(app.Page)
    else
        openSectionHelp(ctx.section, ctx.script)
    end
end

local NAV_BUTTON_DEFS = {
    {key = "menu", text = "@i18n(app.navigation_menu)@", compact = false, press = onNavButtonMenuPress},
    {key = "save", text = "@i18n(app.navigation_save)@", compact = false, press = onNavButtonSavePress},
    {key = "reload", text = "@i18n(app.navigation_reload)@", compact = false, press = onNavButtonReloadPress},
    {key = "tool", text = "@i18n(app.navigation_tools)@", compact = true, press = onNavButtonToolPress},
    {key = "help", text = "@i18n(app.navigation_help)@", compact = true, press = onNavButtonHelpPress}
}

function ui.navigationButtons(x, y, w, h, opts)
    local padding = 5
    local wS = w - (w * 20) / 100
    local helpOffset = 0
    local toolOffset = 0
    local reloadOffset = 0
    local saveOffset = 0
    local menuOffset = 0

    local navOpts = opts or {}
    local navButtons = navOpts.navButtons or (app.Page and app.Page.navButtons)
    local collapseNavigation = isTruthy(preferences and preferences.general and preferences.general.collapse_unused_menu_entries)
    local menuEnabled, saveEnabled, reloadEnabled, toolEnabled, helpEnabled
    if navButtons == nil then
        menuEnabled = true
        saveEnabled = true
        reloadEnabled = true
        toolEnabled = false
        helpEnabled = true
    else
        menuEnabled = (navButtons.menu == true)
        saveEnabled = (navButtons.save == true)
        reloadEnabled = (navButtons.reload == true)
        toolEnabled = (navButtons.tool == true)
        helpEnabled = (navButtons.help == true)
    end

    local section, script = resolveHelpContext(app.lastScript)
    local navButtonCtx = getNavButtonContext()
    navButtonCtx.onNavMenu = navOpts.onNavMenu
    navButtonCtx.section = section
    navButtonCtx.script = script

    local hasHelpData = sectionHasHelpFile(section)
    local toolCanRun = (toolEnabled and app.Page and app.Page.onToolMenu ~= nil) and true or false
    local helpCanRun = (helpEnabled and ((app.Page and app.Page.onHelpMenu ~= nil) or hasHelpData)) and true or false
    local enabledState = {menu = menuEnabled, save = saveEnabled, reload = reloadEnabled, tool = toolCanRun, help = helpCanRun}

    if collapseNavigation then
        for i = 1, #NAV_BUTTON_DEFS do
            app.formNavigationFields[NAV_BUTTON_DEFS[i].key] = nil
        end

        -- Match legacy header gutter: right-most button stops at (x - padding).
        local rightEdge = x - padding
        for i = #NAV_BUTTON_DEFS, 1, -1 do
            local def = NAV_BUTTON_DEFS[i]
            if enabledState[def.key] then
                local width = def.compact and wS or w
                local bx = rightEdge - width
                app.formNavigationFields[def.key] = form.addButton(line, {x = bx, y = y, w = width, h = h}, {
                    text = def.text,
                    icon = nil,
                    options = FONT_S,
                    paint = NOOP_PAINT,
                    press = def.press
                })
                app.formNavigationFields[def.key]:enable(true)
                rightEdge = bx - padding
            end
        end
    else
        helpOffset = x - (wS + padding)
        toolOffset = helpOffset - (wS + padding)
        reloadOffset = toolOffset - (w + padding)
        saveOffset = reloadOffset - (w + padding)
        menuOffset = saveOffset - (w + padding)

        app.formNavigationFields["menu"] = form.addButton(line, {x = menuOffset, y = y, w = w, h = h}, {
            text = "@i18n(app.navigation_menu)@",
            icon = nil,
            options = FONT_S,
            paint = NOOP_PAINT,
            press = onNavButtonMenuPress
        })
        app.formNavigationFields["save"] = form.addButton(line, {x = saveOffset, y = y, w = w, h = h}, {
            text = "@i18n(app.navigation_save)@",
            icon = nil,
            options = FONT_S,
            paint = NOOP_PAINT,
            press = onNavButtonSavePress
        })
        app.formNavigationFields["reload"] = form.addButton(line, {x = reloadOffset, y = y, w = w, h = h}, {
            text = "@i18n(app.navigation_reload)@",
            icon = nil,
            options = FONT_S,
            paint = NOOP_PAINT,
            press = onNavButtonReloadPress
        })
        app.formNavigationFields["tool"] = form.addButton(line, {x = toolOffset, y = y, w = wS, h = h}, {
            text = "@i18n(app.navigation_tools)@",
            icon = nil,
            options = FONT_S,
            paint = NOOP_PAINT,
            press = onNavButtonToolPress
        })
        app.formNavigationFields["help"] = form.addButton(line, {x = helpOffset, y = y, w = wS, h = h}, {
            text = "@i18n(app.navigation_help)@",
            icon = nil,
            options = FONT_S,
            paint = NOOP_PAINT,
            press = onNavButtonHelpPress
        })

        app.formNavigationFields["menu"]:enable(enabledState.menu)
        app.formNavigationFields["save"]:enable(enabledState.save)
        app.formNavigationFields["reload"]:enable(enabledState.reload)
        app.formNavigationFields["tool"]:enable(enabledState.tool)
        app.formNavigationFields["help"]:enable(enabledState.help)
    end

    local focused = false
    for i = 1, #NAV_FOCUS_ORDER do
        local key = NAV_FOCUS_ORDER[i]
        local btn = app.formNavigationFields[key]
        if btn and enabledState[key] then
            btn:focus()
            focused = true
            break
        end
    end

    if not focused then
        for i = 1, #NAV_FOCUS_ORDER do
            local btn = app.formNavigationFields[NAV_FOCUS_ORDER[i]]
            if btn then
                btn:focus()
                focused = true
                break
            end
        end
    end

    if ui._shouldManageDirtySave() then
        ui.setPageDirty(false)
    end
end

function ui.openPageHelp(txtData, title)
    local message
    if type(txtData) == "table" then
        message = tableConcat(txtData, "\r\n\r\n")
    else
        message = txtData
    end

    if not title then title = "@i18n(app.header_help)@ - " .. (app.lastTitle or "") end

    form.openDialog({
        width = app.lcdWidth,
        title = title,
        message = message,
        buttons = {{
            label = "@i18n(app.btn_close)@",
            action = function()
                local section = resolveHelpContext(app.lastScript)
                if section then
                    ui._helpCache[section] = nil
                else
                    ui._helpCache = {}
                end
                app.fieldHelpTxt = nil
                app._fieldHelpSection = nil
                return true
            end
        }},
        options = TEXT_LEFT
    })
end

function ui.injectApiAttributes(formField, f, v)
    local log = utils.log

    if v.decimals and not f.decimals then
        if f.type ~= 1 then
            log("Injecting decimals: " .. v.decimals, "debug")
            f.decimals = v.decimals
            if formField.decimals then formField:decimals(v.decimals) end
        end
    end

    if v.scale and not f.scale then
        log("Injecting scale: " .. v.scale, "debug");
        f.scale = v.scale
    end
    if v.mult and not f.mult then
        log("Injecting mult: " .. v.mult, "debug");
        f.mult = v.mult
    end
    if v.offset and not f.offset then
        log("Injecting offset: " .. v.offset, "debug");
        f.offset = v.offset
    end

    if v.unit and not f.unit then
        if f.type ~= 1 then
            log("Injecting unit: " .. v.unit, "debug")
            if formField.suffix then formField:suffix(v.unit) end
        end
    end

    if v.step and not f.step then
        if f.type ~= 1 then
            log("Injecting step: " .. v.step, "debug")
            f.step = v.step
            if formField.step then formField:step(v.step) end
        end
    end

    if v.min and not f.min then
        f.min = v.min
        if f.offset then f.min = f.min + f.offset end
        if f.type ~= 1 then
            log("Injecting min: " .. f.min, "debug")
            if formField.minimum then formField:minimum(f.min) end
        end
    end

    if v.max and not f.max then
        f.max = v.max
        if f.offset then f.max = f.max + f.offset end
        if f.type ~= 1 then
            log("Injecting max: " .. f.max, "debug")
            if formField.maximum then formField:maximum(f.max) end
        end
    end

    if v.default and not f.default then
        f.default = v.default
        if f.offset then f.default = f.default + f.offset end
        local default = f.default * rfutils.decimalInc(f.decimals)
        if f.mult then default = default * f.mult end
        local str = tostring(default)
        if str:match("%.0$") then default = math.ceil(default) end
        if f.type ~= 1 then
            log("Injecting default: " .. default, "debug")
            if formField.default then formField:default(default) end
        end
    end

    if v.table and not f.table then
        f.table = v.table
        local idxInc = f.tableIdxInc or v.tableIdxInc
        local tbldata = app.utils.convertPageValueTable(v.table, idxInc)
        if f.type == 1 then
            log("Injecting table: {}", "debug")
            if formField.values then formField:values(tbldata) end
        end
    end

    if v.tableEthos and not f.tableEthos then
        local tbldata = v.tableEthos
        if f.type == 1 then
            log("Injecting table: {}", "debug")
            if formField.values then formField:values(tbldata) end
        end
    end

    if v.help then
        f.help = v.help
        log("Injecting help: {}", "debug")
        if formField.help then formField:help(v.help) end
    end

    if formField.focus then formField:focus(true) end
end

function ui.mspApiUpdateFormAttributes()

    local values = tasks.msp.api.apidata.values
    local structure = tasks.msp.api.apidata.structure

    local log = utils.log

    if not (app.Page.apidata.formdata and app.Page.apidata.api and app.Page.apidata.formdata.fields) then
        log("app.Page.apidata.formdata or its components are nil", "debug")
        return
    end

    local function combined_api_parts(s)
        local part1, part2 = s:match("^([^:]+):([^:]+)$")
        if part1 and part2 then
            local num = tonumber(part1)
            if num then
                part1 = num
            else
                part1 = app.Page.apidata.api_reversed[part1] or nil
            end
            if part1 then return {part1, part2} end
        end
        return nil
    end

    local fields = app.Page.apidata.formdata.fields
    local api = app.Page.apidata.api

    local function apiEntryName(entry)
        if type(entry) == "table" then return entry.name end
        return entry
    end

    local function apiEntryId(entry, index)
        if type(entry) == "table" and type(entry.id) == "number" then
            return entry.id
        end
        return index
    end

    if not app.Page.apidata.api_reversed then
        app.Page.apidata.api_reversed = {}
        app.Page.apidata.api_by_id = {}
        for index, value in pairs(app.Page.apidata.api) do
            local name = apiEntryName(value)
            if name then
                local id = apiEntryId(value, index)
                app.Page.apidata.api_reversed[name] = id
                app.Page.apidata.api_by_id[id] = name
            end
        end
    elseif not app.Page.apidata.api_by_id then
        app.Page.apidata.api_by_id = {}
        for index, value in pairs(app.Page.apidata.api) do
            local name = apiEntryName(value)
            if name then
                local id = apiEntryId(value, index)
                app.Page.apidata.api_by_id[id] = name
            end
        end
    end

    for i, f in ipairs(fields) do
        local formField = app.formFields[i]
        if type(formField) == 'userdata' then
            if f.api then
                log("API field found: " .. f.api, "debug")
                local parts = combined_api_parts(f.api)
                if parts then
                    f.mspapi = parts[1];
                    f.apikey = parts[2]
                end
            end

            local apikey = f.apikey
            local mspapiID = f.mspapi
            local mspapiNAME = (app.Page.apidata.api_by_id and app.Page.apidata.api_by_id[mspapiID]) or apiEntryName(api[mspapiID])
            local target = mspapiNAME and structure[mspapiNAME] or nil

            if mspapiID == nil or mspapiID == nil then
                log("API field missing mspapi or apikey", "debug")
            elseif not target then
                log("API field missing structure: " .. tostring(mspapiNAME), "debug")
            else
                for _, v in ipairs(target) do
                    if not v.bitmap then
                        if v.field == apikey and mspapiID == f.mspapi then

                            if v.help and (v.help == "" or v.help:match("^@i18n%b()@$")) then v.help = nil end

                            app.ui.injectApiAttributes(formField, f, v)

                            local scale = f.scale or 1
                            if values and values[mspapiNAME] and values[mspapiNAME][apikey] then app.Page.apidata.formdata.fields[i].value = values[mspapiNAME][apikey] / scale end

                            if values[mspapiNAME][apikey] == nil then
                                log("API field value is nil: " .. mspapiNAME .. " " .. apikey, "info")
                                formField:enable(false)
                            end
                            break
                        end
                    else

                        for bidx, b in ipairs(v.bitmap) do
                            local bitmapField = v.field .. "->" .. b.field
                            if bitmapField == apikey and mspapiID == f.mspapi then
                                if v.help and (v.help == "" or v.help:match("^@i18n%b()@$")) then v.help = nil end

                                app.ui.injectApiAttributes(formField, f, b)

                                local scale = f.scale or 1
                                if values and values[mspapiNAME] and values[mspapiNAME][v.field] then
                                    local raw_value = values[mspapiNAME][v.field]
                                    local bit_value = (raw_value >> bidx - 1) & 1
                                    app.Page.apidata.formdata.fields[i].value = bit_value / scale
                                end

                                if values[mspapiNAME][v.field] == nil then
                                    log("API field value is nil: " .. mspapiNAME .. " " .. apikey, "info")
                                    formField:enable(false)
                                end

                                app.Page.apidata.formdata.fields[i].bitmap = bidx - 1
                            end
                        end
                    end
                end
            end
        else
            log("Form field skipped; not valid for this api version?", "debug")
        end
    end

    -- During rapid page transitions the menu button may not exist yet.
    -- Focus the first available navigation field instead of assuming "menu".
    local navFields = app.formNavigationFields
    if type(navFields) == "table" then
        local focusOrder = {"menu", "save", "reload", "tool", "help"}
        for i = 1, #focusOrder do
            local navField = navFields[focusOrder[i]]
            if navField and navField.focus then
                navField:focus(true)
                break
            end
        end
    end
end

function ui.requestPage()
    local log = utils.log

    if not app.Page.apidata then return end
    if not app.Page.apidata.api and not app.Page.apidata.formdata then
        log("app.Page.apidata.api did not pass consistancy checks", "debug")
        return
    end

    if not app.Page.apidata.apiState then app.Page.apidata.apiState = {currentIndex = 1, isProcessing = false} end

    local apiList = app.Page.apidata.api
    local state = app.Page.apidata.apiState

    if state.isProcessing then
        log("requestPage is already running, skipping duplicate call.", "debug")
        return
    end
    state.isProcessing = true

    if not tasks.msp.api.apidata.values then
        log("requestPage Initialize values on first run", "debug")
        tasks.msp.api.apidata.values = {}
        tasks.msp.api.apidata.structure = {}
        tasks.msp.api.apidata.receivedBytesCount = {}
        tasks.msp.api.apidata.receivedBytes = {}
        tasks.msp.api.apidata.positionmap = {}
        tasks.msp.api.apidata.other = {}
    end

    if state.currentIndex == nil then state.currentIndex = 1 end

    local function checkForUnresolvedTimeouts()
        if not app or not app.Page or not app.Page.apidata then return end
        local hasUnresolvedTimeouts = false
        for apiKey, retries in pairs(app.Page.apidata.retryCount or {}) do
            if retries >= 3 then
                hasUnresolvedTimeouts = true
                log("[ALERT] API " .. apiKey .. " failed after 3 timeouts.", "info")
            end
        end
        if hasUnresolvedTimeouts then
            app.ui.disableAllFields()
            app.ui.disableAllNavigationFields()
            app.ui.enableNavigationField('menu')
            app.triggers.closeProgressLoader = true
        end
    end

    local function processNextAPI()
        if not app or not app.Page or not app.Page.apidata then
            log("App is closing. Stopping processNextAPI.", "debug")
            return
        end

        if state.currentIndex > #apiList or #apiList == 0 then
            if state.isProcessing then
                state.isProcessing = false
                state.currentIndex = 1
                app.triggers.isReady = true
                app.triggers.rebootInProgress = false
                if app.Page.postRead then app.Page.postRead(app.Page) end
                app.ui.mspApiUpdateFormAttributes()
                if app.Page.postLoad then
                    app.Page.postLoad(app.Page)
                else
                    app.triggers.closeProgressLoader = true
                end
                checkForUnresolvedTimeouts()

            end
            return
        end

        local v = apiList[state.currentIndex]
        local apiMeta = type(v) == "table" and v or nil
        local apiKey = type(v) == "string" and v or (apiMeta and apiMeta.name or nil)
        local retryCount = app.Page.apidata.retryCount and app.Page.apidata.retryCount[apiKey] or 0
        if not apiKey then
            log("API key is missing for index " .. tostring(state.currentIndex), "warning")
            state.currentIndex = state.currentIndex + 1
            local base = 0.25
            local backoff = math.min(2.0, base * (2 ^ retryCount))
            local jitter = math.random() * 0.2
            tasks.callback.inSeconds(backoff + jitter, processNextAPI)
            return
        end

        local enableDeltaCache = nil
        if apiMeta and apiMeta.enableDeltaCache ~= nil then
            enableDeltaCache = apiMeta.enableDeltaCache
        elseif app.Page.apidata and app.Page.apidata.enableDeltaCache ~= nil then
            enableDeltaCache = app.Page.apidata.enableDeltaCache
        end
        if enableDeltaCache ~= nil and type(enableDeltaCache) ~= "boolean" then
            enableDeltaCache = nil
        end

        local API = tasks.msp.api.load(apiKey, {loadHelp = true})
        if API and API.enableDeltaCache and enableDeltaCache ~= nil then
            API.enableDeltaCache(enableDeltaCache)
        end

        if app and app.Page and app.Page.apidata then app.Page.apidata.retryCount = app.Page.apidata.retryCount or {} end

        local handled = false

        log("[PROCESS] API: " .. apiKey .. " (Attempt " .. (retryCount + 1) .. ")", "debug")

        local function handleTimeout()
            if handled then return end
            handled = true
            if not app or not app.Page or not app.Page.apidata then
                log("App is closing. Timeout handling skipped.", "debug")
                return
            end
            retryCount = retryCount + 1
            app.Page.apidata.retryCount[apiKey] = retryCount
            if retryCount < 3 then
                log("[TIMEOUT] API: " .. apiKey .. " (Retry " .. retryCount .. ")", "warning")
                tasks.callback.inSeconds(0.25, processNextAPI)
            else
                log("[TIMEOUT FAIL] API: " .. apiKey .. " failed after 3 attempts. Skipping.", "error")
                state.currentIndex = state.currentIndex + 1
                tasks.callback.inSeconds(0.25, processNextAPI)
            end
        end

        tasks.callback.inSeconds(2, handleTimeout)

        API.setCompleteHandler(function(self, buf)
            if handled then return end
            handled = true
            if not app or not app.Page or not app.Page.apidata then
                log("App is closing. Skipping API success handling.", "debug")
                return
            end
            log("[SUCCESS] API: " .. apiKey .. " completed successfully.", "debug")
            local cacheEnabled = enableDeltaCache
            if cacheEnabled == nil and tasks.msp.api.isDeltaCacheEnabled then
                cacheEnabled = tasks.msp.api.isDeltaCacheEnabled(apiKey)
            end
            if type(cacheEnabled) ~= "boolean" then cacheEnabled = nil end
            if cacheEnabled == nil then cacheEnabled = true end

            local data = API.data()
            tasks.msp.api.apidata.values[apiKey] = data.parsed
            tasks.msp.api.apidata.structure[apiKey] = data.structure
            if cacheEnabled == true then
                tasks.msp.api.apidata.receivedBytes[apiKey] = data.buffer
                tasks.msp.api.apidata.receivedBytesCount[apiKey] = data.receivedBytesCount
                tasks.msp.api.apidata.positionmap[apiKey] = data.positionmap
            else
                tasks.msp.api.apidata.receivedBytes[apiKey] = nil
                tasks.msp.api.apidata.receivedBytesCount[apiKey] = nil
                tasks.msp.api.apidata.positionmap[apiKey] = nil
            end
            tasks.msp.api.apidata.other[apiKey] = data.other or {}
            app.Page.apidata.retryCount[apiKey] = 0
            state.currentIndex = state.currentIndex + 1
            API = nil

            tasks.callback.inSeconds(0.5, processNextAPI)
        end)

        API.setErrorHandler(function(self, err)
            if handled then return end
            handled = true
            if not app or not app.Page or not app.Page.apidata then
                log("App is closing. Skipping API error handling.", "debug")
                return
            end
            retryCount = retryCount + 1
            app.Page.apidata.retryCount[apiKey] = retryCount
            API = nil

            if retryCount < 3 then
                log("[ERROR] API: " .. apiKey .. " failed (Retry " .. retryCount .. "): " .. tostring(err), "warning")
                tasks.callback.inSeconds(0.5, processNextAPI)
            else
                log("[ERROR FAIL] API: " .. apiKey .. " failed after 3 attempts. Skipping.", "error")
                state.currentIndex = state.currentIndex + 1
                tasks.callback.inSeconds(0.5, processNextAPI)
            end
        end)

        API.read()
    end

    processNextAPI()
end

function ui.saveSettings(sourcePage)

    local log = utils.log
    local page = sourcePage or app.Page

    if app.pageState == app.pageStatus.saving then return end
    if not (page and page.apidata and page.apidata.formdata and page.apidata.formdata.fields and page.apidata.api) then
        log("saveSettings called without valid apidata; skipping.", "info")
        app.pageState = app.pageStatus.display
        app.triggers.isSaving = false
        app.triggers.closeSaveFake = true
        app.triggers.saveFailed = true
        return
    end

    app.pageState = app.pageStatus.saving
    app.saveTS = osClock()

    log("Saving data", "debug")

    local mspapi = page.apidata
    local apiList = mspapi.api
    local values = tasks.msp.api.apidata.values

    local totalRequests = #apiList
    local completedRequests = 0
    local enqueueFailures = 0

    page.apidata.apiState.isProcessing = true

    if page.preSave then page.preSave(page) end

    for apiID, apiEntry in ipairs(apiList) do

        local apiMeta = type(apiEntry) == "table" and apiEntry or nil
        local apiNAME = type(apiEntry) == "string" and apiEntry or (apiMeta and apiMeta.name or nil)
        if not apiNAME then
            log("saveSettings skipped entry with missing API name at index " .. tostring(apiID), "warning")
            completedRequests = completedRequests + 1
            goto continue
        end

        utils.reportMemoryUsage("ui.saveSettings " .. apiNAME, "start")

        local payloadData = values[apiNAME]
        local payloadStructure = tasks.msp.api.apidata.structure[apiNAME]

        local API = tasks.msp.api.load(apiNAME)
        if API and API.enableDeltaCache then
            local enableDeltaCache = nil
            if apiMeta and apiMeta.enableDeltaCache ~= nil then
                enableDeltaCache = apiMeta.enableDeltaCache
            elseif page.apidata and page.apidata.enableDeltaCache ~= nil then
                enableDeltaCache = page.apidata.enableDeltaCache
            end
            if type(enableDeltaCache) == "boolean" then
                API.enableDeltaCache(enableDeltaCache)
            end
        end
        if API and API.setRebuildOnWrite and apiMeta and apiMeta.rebuildOnWrite ~= nil then
            if type(apiMeta.rebuildOnWrite) == "boolean" then
                API.setRebuildOnWrite(apiMeta.rebuildOnWrite)
            end
        end
        API.setErrorHandler(function(self, buf) app.triggers.saveFailed = true end)
        API.setCompleteHandler(function(self, buf)
            completedRequests = completedRequests + 1
            log("API " .. apiNAME .. " write complete", "debug")
            API = nil

            if completedRequests == totalRequests then
                log("All API requests have been completed!", "debug")
                if page and page.apidata and page.apidata.apiState then
                    page.apidata.apiState.isProcessing = false
                end
                if enqueueFailures > 0 or app.triggers.saveFailed then
                    app.pageState = app.pageStatus.display
                    app.triggers.closeSaveFake = true
                    app.triggers.isSaving = false
                else
                    ui.setPageDirty(false)
                    if page and page.postSave then page.postSave(page) end
                    app.utils.settingsSaved(page)
                end
            end
        end)

        local fieldMap = {}
        local fieldMapBitmap = {}
        local apiId = apiID
        if apiMeta and type(apiMeta.id) == "number" then apiId = apiMeta.id end
        for fidx, f in ipairs(page.apidata.formdata.fields) do
            if not f.bitmap then
                if f.mspapi == apiId then fieldMap[f.apikey] = fidx end
            else
                local p1, p2 = string.match(f.apikey, "([^%-]+)%-%>(.+)")
                if not fieldMapBitmap[p1] then fieldMapBitmap[p1] = {} end
                fieldMapBitmap[p1][f.bitmap] = fidx
            end
        end

        for k, v in pairs(payloadData) do
            local fieldIndex = fieldMap[k]
            if fieldIndex then
                payloadData[k] = page.apidata.formdata.fields[fieldIndex].value
            elseif fieldMapBitmap[k] then
                local originalValue = tonumber(v) or 0
                local newValue = originalValue
                for bit, idx in pairs(fieldMapBitmap[k]) do
                    local fieldVal = mathFloor(tonumber(page.apidata.formdata.fields[idx].value) or 0)
                    local mask = 1 << (bit)
                    if fieldVal ~= 0 then
                        newValue = newValue | mask
                    else
                        newValue = newValue & (~mask)
                    end
                end
                payloadData[k] = newValue
            end
        end

        for k, v in pairs(payloadData) do
            log("Set value for " .. k .. " to " .. v, "debug")
            API.setValue(k, v)
        end

        local payload = nil
        if page.preSavePayload and payloadStructure then
            local core = getApiCore()
            if core and core.buildWritePayload then
                payload = core.buildWritePayload(apiNAME, payloadData, payloadStructure, false)
                local adjusted = page.preSavePayload(payload)
                if adjusted ~= nil then payload = adjusted end
            end
        end

        local ok, reason
        if payload then
            ok, reason = API.write(payload)
        else
            ok, reason = API.write()
        end

        if not ok then
            enqueueFailures = enqueueFailures + 1
            completedRequests = completedRequests + 1
            app.triggers.saveFailed = true
            log("API " .. apiNAME .. " enqueue rejected: " .. tostring(reason), "info")
            if completedRequests == totalRequests then
                if page and page.apidata and page.apidata.apiState then
                    page.apidata.apiState.isProcessing = false
                end
                app.pageState = app.pageStatus.display
                app.triggers.closeSaveFake = true
                app.triggers.isSaving = false
            end
        end

        utils.reportMemoryUsage("ui.saveSettings " .. apiNAME, "end")

        ::continue::

    end

end

function ui.rebootFc(sourcePage)
    local armflags = tasks and tasks.telemetry and tasks.telemetry.getSensor and tasks.telemetry.getSensor("armflags")
    local armedByFlags = (armflags == 1 or armflags == 3)
    local rebootPage = sourcePage or app.Page
    if (session and session.isArmed) or armedByFlags then
        utils.log("Blocked reboot while armed", "info")
        app.pageState = app.pageStatus.display
        app.triggers.closeSaveFake = true
        app.triggers.isSaving = false
        app.triggers.showSaveArmedWarning = true
        return false, "armed_blocked"
    end

    app.triggers.rebootInProgress = true
    app.pageState = app.pageStatus.rebooting
    local ok, reason = tasks.msp.mspQueue:add({
        command = 68,
        uuid = "ui.reboot",
        processReply = function(self, buf)
            if not app.Page and app.uiState == app.uiStatus.pages and rebootPage then
                app.Page = rebootPage
            end
            -- Keep the current page object alive across reboot transitions;
            -- loader/request logic will refresh live values when connection resumes.
            app.utils.invalidatePages({preserveCurrentPage = true})
            app.triggers.isReady = false
            utils.onReboot()
        end,
        simulatorResponse = {}
    })
    if ok and app.dialogs then
        if app.dialogs.saveDisplay then
            app.triggers.closeSaveFake = true
            app.dialogs.saveDisplay = false
            app.dialogs.saveWatchDog = nil
            app.dialogs.saveProgressCounter = 0
            app.triggers.isSaving = false
            app.triggers.closeSave = false
            app.triggers.closeSaveFake = false
            pcall(function() app.dialogs.save:close() end)
            ui.clearProgressDialog(app.dialogs.save)
        end
        if app.dialogs.progressDisplay then
            app.dialogs.progressDisplay = false
            app.dialogs.progressWatchDog = nil
            app.dialogs.progressCounter = 0
            app.dialogs.progressSpeed = nil
            app.triggers.closeProgressLoader = false
            app.triggers.closeProgressLoaderNoisProcessed = false
            pcall(function() app.dialogs.progress:close() end)
            ui.clearProgressDialog(app.dialogs.progress)
        end
    end
    if not ok then
        utils.log("Reboot enqueue rejected: " .. tostring(reason), "info")
        app.triggers.rebootInProgress = false
        app.pageState = app.pageStatus.display
        app.triggers.closeSaveFake = true
        app.triggers.isSaving = false
    end
    return ok, reason
end

function ui.adminStatsOverlay()

    local baseY = getHeaderNavAreaBottom() + HEADER_OVERLAY_Y_OFFSET
    local showStats = preferences and preferences.developer and preferences.developer.overlaystatsadmin and not (session and session.mspBusy)

    if not showStats then
        drawHeaderBreadcrumbOverlay(baseY)
        return
    end

    local cpuUsage = (rfsuite.performance and rfsuite.performance.cpuload) or 0
    local ramUsed = (rfsuite.performance and rfsuite.performance.usedram) or 0
    local luaRamKB = (rfsuite.performance and rfsuite.performance.luaRamKB) or 0

    local function fmtInt(n) return utils.round(n or 0, 0) end
    local function fmtKB(n) return string.format("%.0f", n or 0) end

    local loadColor = lcd.RGB(180, 230, 255)
    if cpuUsage >= 85 then
        loadColor = lcd.RGB(255, 130, 130)
    elseif cpuUsage >= 70 then
        loadColor = lcd.RGB(255, 210, 140)
    end
    local statColor = lcd.RGB(245, 245, 245)

    local rows = {
        {label = "LOAD:", value = tostring(fmtInt(cpuUsage)) .. "%", color = loadColor},
        {label = "USED:", value = tostring(fmtInt(ramUsed)) .. "kB", color = statColor},
        {label = "FREE:", value = tostring(fmtKB(luaRamKB)) .. "KB", color = statColor}
    }

    local screenW = app.lcdWidth
    if not screenW or screenW <= 0 then screenW = lcdGetWindowSize() end
    if not screenW or screenW <= 0 then return end

    lcdFont(FONT_XXS)
    local labelGap = 4
    local blockGap = 8
    local rightPad = 11
    local blocks = {}
    local totalWidth = 0

    for i = 1, #rows do
        local row = rows[i]
        local labelW = lcdGetTextSize(row.label)
        local valueW = lcdGetTextSize(row.value)
        local blockW = labelW + labelGap + valueW
        blocks[i] = {label = row.label, value = row.value, labelW = labelW, valueW = valueW, width = blockW}
        if i > 1 then totalWidth = totalWidth + blockGap end
        totalWidth = totalWidth + blockW
    end

    drawHeaderBreadcrumbOverlay(baseY, totalWidth + rightPad + 4)

    local x = math.max(0, screenW - rightPad - totalWidth)
    local y = baseY

    for i = 1, #blocks do
        local block = blocks[i]
        lcdColor(block.color or statColor)
        lcdDrawText(x, y, block.label)
        lcdDrawText(x + block.width - block.valueW, y, block.value)
        x = x + block.width + blockGap
    end
end

return ui
