--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local lcd = lcd

local container = {}
local MENU_ONLY_NAV_BUTTONS = {menu = true, save = false, reload = false, tool = false, help = false}
local NOOP_PAINT = function() end

local function wipeTable(t)
    if type(t) ~= "table" then return end
    for k in pairs(t) do t[k] = nil end
end

local function loadMaskCached(app, path)
    if type(path) ~= "string" or path == "" then return nil end
    local ui = app and app.ui
    if ui and ui.loadMask then return ui.loadMask(path) end
    return lcd.loadMask(path)
end

local function isManifestMenuRouterScript(script)
    return type(script) == "string" and (script == "manifest_menu/menu.lua" or script == "app/modules/manifest_menu/menu.lua")
end

local function copyReturnContext(base, menuId)
    local ctx = {
        idx = base.idx,
        title = base.title,
        script = base.script
    }
    if type(menuId) == "string" and menuId ~= "" then
        ctx.menuId = menuId
    end
    return ctx
end

local function resolveScriptFromRules(rules)
    if type(rules) ~= "table" then return nil, nil end
    local utils = rfsuite.utils
    for _, rule in ipairs(rules) do
        local op = rule.op or rule[1]
        local ver = rule.ver or rule[2]
        local script = rule.script or rule[3]
        if op and ver and script and utils and utils.apiVersionCompare(op, ver) then
            return script, rule.loaderspeed
        end
    end
    return nil, nil
end

local function resolveItemScript(item)
    local rules = item.script_by_mspversion or item.scriptByMspVersion
    if rules then
        local chosen, speed = resolveScriptFromRules(rules)
        if chosen then return chosen, speed end
        if item.script_default then return item.script_default, item.loaderspeed end
    end
    return item.script, item.loaderspeed
end

local function iconPathFor(cfg, item)
    if cfg.iconPathResolver then
        return cfg.iconPathResolver(item)
    end

    if type(item.image) == "string" and item.image:sub(1, 4) == "app/" then
        return item.image
    end

    if cfg.iconPrefix and item.image then
        return cfg.iconPrefix .. item.image
    end

    return item.image
end

local function scriptPathFor(cfg, item, resolvedScript)
    if cfg.scriptPathResolver then return cfg.scriptPathResolver(item) end
    local script = resolvedScript or item.script
    if type(script) == "string" and script:sub(1, 4) == "app/" then
        return script
    end
    return (cfg.scriptPrefix or "") .. script
end

local function titleForChild(cfg, pageTitle, item)
    if cfg.childTitleResolver then return cfg.childTitleResolver(pageTitle, item) end
    if type(cfg.childTitlePrefix) == "string" and cfg.childTitlePrefix ~= "" then
        return cfg.childTitlePrefix .. " / " .. (item.name or "")
    end
    return (pageTitle or "") .. " / " .. (item.name or "")
end

local function apiVersionMatches(item)
    local utils = rfsuite.utils
    if type(item) ~= "table" or not utils or not utils.apiVersionCompare then return true end
    return (item.apiversion == nil or utils.apiVersionCompare(">=", item.apiversion)) and
        (item.apiversionlt == nil or utils.apiVersionCompare("<", item.apiversionlt)) and
        (item.apiversiongt == nil or utils.apiVersionCompare(">", item.apiversiongt)) and
        (item.apiversionlte == nil or utils.apiVersionCompare("<=", item.apiversionlte)) and
        (item.apiversiongte == nil or utils.apiVersionCompare(">=", item.apiversiongte))
end

function container.create(cfg)
    local app = rfsuite.app
    local prefs = rfsuite.preferences
    local tasks = rfsuite.tasks
    local moduleKey = tostring(cfg.moduleKey or "_menu_container")

    local pages = cfg.pages or {}
    local navHandlers = pageRuntime.createMenuHandlers(cfg.navOptions or {})
    local enableWakeup = false
    local lastLinkState = nil
    local lastFieldEnabled = {}
    app._menuContainerPressSpecs = app._menuContainerPressSpecs or {}
    app._menuContainerPressHandlers = app._menuContainerPressHandlers or {}

    local function onNavMenuPress()
        if app.Page and app.Page.onNavMenu then
            app.Page.onNavMenu(app.Page)
        else
            navHandlers.onNavMenu()
        end
    end

    local function getPagePressHandler(index)
        local handlersByModule = app._menuContainerPressHandlers
        handlersByModule[moduleKey] = handlersByModule[moduleKey] or {}
        local handlers = handlersByModule[moduleKey]
        if handlers[index] then return handlers[index] end

        handlers[index] = function()
            local specsByModule = app._menuContainerPressSpecs
            local specs = specsByModule and specsByModule[moduleKey]
            local spec = specs and specs[index]
            if type(spec) ~= "table" then return end

            local item = spec.item
            if type(item) ~= "table" then return end

            prefs.menulastselected[moduleKey] = index

            local resolvedScript, speedOverride
            if type(item.menuId) == "string" and item.menuId ~= "" then
                speedOverride = item.loaderspeed
            else
                resolvedScript, speedOverride = resolveItemScript(item)
            end
            local showLoader = speedOverride ~= false
            local loaderSpeed = cfg.loaderSpeed or app.loaderSpeed.FAST
            if speedOverride ~= nil and speedOverride ~= false then
                loaderSpeed = speedOverride
            end
            if type(loaderSpeed) == "string" and app.loaderSpeed then
                loaderSpeed = app.loaderSpeed[loaderSpeed] or app.loaderSpeed.FAST
            end
            local targetScript
            if type(item.menuId) == "string" and item.menuId ~= "" then
                app.pendingManifestMenuId = item.menuId
                targetScript = "manifest_menu/menu.lua"
            else
                targetScript = scriptPathFor(cfg, item, resolvedScript)
                if showLoader then
                    app.ui.progressDisplay(nil, nil, loaderSpeed)
                end
            end
            local openOpts = {
                idx = index,
                title = titleForChild(cfg, spec.pageTitle, item),
                script = targetScript,
                menuId = item.menuId,
                returnContext = copyReturnContext({
                    idx = spec.parentIdx,
                    title = spec.pageTitle,
                    script = spec.parentScript
                }, spec.currentMenuId)
            }

            local ok, err = pcall(app.ui.openPage, openOpts)
            if not ok then
                local msg = tostring(err)
                if msg:find("Max instructions count", 1, true) then
                    -- Retry on next wakeup tick when the VM budget resets.
                    app._pendingOpenPageOpts = openOpts
                    return
                end
                error(err)
            end
        end

        return handlers[index]
    end

    local function openPage(opts)
        if cfg.onOpenPre then cfg.onOpenPre(opts) end

        local pidx = opts.idx
        local pageTitle = opts.title or cfg.title
        local script = opts.script
        local currentMenuId = opts.menuId
        if (type(currentMenuId) ~= "string" or currentMenuId == "") and isManifestMenuRouterScript(script) and type(app.activeManifestMenuId) == "string" and app.activeManifestMenuId ~= "" then
            currentMenuId = app.activeManifestMenuId
        end
        if type(currentMenuId) == "string" and currentMenuId ~= "" then
            app.activeManifestMenuId = currentMenuId
        end

        if tasks and tasks.msp then tasks.msp.protocol.mspIntervalOveride = nil end

        app.triggers.isReady = false
        app.uiState = app.uiStatus.mainMenu

        form.clear()
        app._menuFocusEpoch = (app._menuFocusEpoch or 0) + 1

        app.lastIdx = pidx
        app.lastTitle = pageTitle
        app.lastScript = script

        for k in pairs(app.gfx_buttons) do
            if k ~= moduleKey then app.gfx_buttons[k] = nil end
        end

        prefs.general.iconsize = tonumber(prefs.general.iconsize) or 1

        if app.Page then app.Page.navButtons = MENU_ONLY_NAV_BUTTONS end

        if app.ui and app.ui.fieldHeader then
            app.ui.fieldHeader(pageTitle)
            if app.ui.disableAllNavigationFields and app.ui.enableNavigationField then
                app.ui.disableAllNavigationFields()
                app.ui.enableNavigationField("menu")
            end
        else
            local w = lcd.getWindowSize()
            local windowWidth = w
            local headerButtonH = (app.ui and app.ui.getHeaderNavButtonHeight and app.ui.getHeaderNavButtonHeight()) or app.radio.navbuttonHeight
            local headerButtonY = (app.ui and app.ui.getHeaderNavButtonY and app.ui.getHeaderNavButtonY(app.radio.linePaddingTop)) or app.radio.linePaddingTop
            local headerTitleY = (app.ui and app.ui.getHeaderTitleY and app.ui.getHeaderTitleY(app.radio.linePaddingTop)) or app.radio.linePaddingTop

            local header = form.addLine("")
            if app.ui and app.ui.setHeaderTitle then
                app.ui.setHeaderTitle(pageTitle, header, MENU_ONLY_NAV_BUTTONS)
            else
                form.addStaticText(header, {x = 0, y = headerTitleY, w = windowWidth - 115, h = headerButtonH}, pageTitle or "")
            end
            local navX = windowWidth - 110
            app.formNavigationFields["menu"] = form.addButton(header, {x = navX, y = headerButtonY, w = 100, h = headerButtonH}, {
                text = "@i18n(app.navigation_menu)@",
                icon = nil,
                options = FONT_S,
                paint = NOOP_PAINT,
                press = onNavMenuPress
            })
            app.formNavigationFields["menu"]:focus()
        end

        local buttonW
        local buttonH
        local padding
        local numPerRow

        if prefs.general.iconsize == 0 then
            padding = app.radio.buttonPaddingSmall
            buttonW = (app.lcdWidth - padding) / app.radio.buttonsPerRow - padding
            buttonH = app.radio.navbuttonHeight
            numPerRow = app.radio.buttonsPerRow
        elseif prefs.general.iconsize == 1 then
            padding = app.radio.buttonPaddingSmall
            buttonW = app.radio.buttonWidthSmall
            buttonH = app.radio.buttonHeightSmall
            numPerRow = app.radio.buttonsPerRowSmall
        else
            padding = app.radio.buttonPadding
            buttonW = app.radio.buttonWidth
            buttonH = app.radio.buttonHeight
            numPerRow = app.radio.buttonsPerRow
        end

        app.gfx_buttons[moduleKey] = app.gfx_buttons[moduleKey] or {}
        prefs.menulastselected[moduleKey] = prefs.menulastselected[moduleKey] or 1
        app._menuContainerPressSpecs[moduleKey] = app._menuContainerPressSpecs[moduleKey] or {}
        wipeTable(app._menuContainerPressSpecs[moduleKey])

        wipeTable(app.formFields)
        wipeTable(app.formLines)

        app.formFieldsOffline = {}
        app.formFieldsBGTask = {}

        local lc = 0
        local y = 0

        for i, item in ipairs(pages) do
            local hideEntry = (item.ethosversion and not rfsuite.utils.ethosVersionAtLeast(item.ethosversion)) or
                (item.mspversion and rfsuite.utils.apiVersionCompare("<", item.mspversion)) or
                (not apiVersionMatches(item))

            app.formFieldsOffline[i] = item.offline or false
            app.formFieldsBGTask[i] = item.bgtask or false

            if not hideEntry then
                if lc == 0 then
                    y = form.height() + ((prefs.general.iconsize == 2) and app.radio.buttonPadding or app.radio.buttonPaddingSmall)
                end

                local bx = (buttonW + padding) * lc

                if prefs.general.iconsize ~= 0 then
                    local iconPath = iconPathFor(cfg, item)
                    if iconPath then
                        app.gfx_buttons[moduleKey][i] = loadMaskCached(app, iconPath)
                    else
                        app.gfx_buttons[moduleKey][i] = nil
                    end
                else
                    app.gfx_buttons[moduleKey][i] = nil
                end

                app._menuContainerPressSpecs[moduleKey][i] = {
                    item = item,
                    pageTitle = pageTitle,
                    parentIdx = pidx,
                    parentScript = script,
                    currentMenuId = currentMenuId
                }
                app.formFields[i] = form.addButton(line, {x = bx, y = y, w = buttonW, h = buttonH}, {
                    text = item.name,
                    icon = app.gfx_buttons[moduleKey][i],
                    options = FONT_S,
                    paint = NOOP_PAINT,
                    press = getPagePressHandler(i)
                })

                if item.disabled == true then app.formFields[i]:enable(false) end

                if prefs.menulastselected[moduleKey] == i then app.formFields[i]:focus() end

                lc = lc + 1
                if lc == numPerRow then lc = 0 end
            end
        end

        app.triggers.closeProgressLoader = true
        enableWakeup = true
        app.uiState = app.uiStatus.pages

        if cfg.onOpenPost then cfg.onOpenPost(opts) end
    end

    local function wakeup()
        if not enableWakeup then return end

        if cfg.onWakeup then
            local handled = cfg.onWakeup()
            if handled == true then return end
        end

        if type(app.formFields) ~= "table" or type(app.formFieldsOffline) ~= "table" then return end

        local tasksActive = tasks and tasks.active and tasks.active()
        local liveSession = rfsuite.session
        local isConnected = (liveSession and liveSession.isConnected and liveSession.mcu_id) and true or false

        if not isConnected then
            -- Offline mode is manifest-driven: only entries explicitly marked offline remain enabled.
            for i, v in pairs(app.formFieldsOffline) do
                local field = app.formFields[i]
                if field and field.enable then
                    local blockedByBgTask = (app.formFieldsBGTask[i] == true) and (not tasksActive)
                    local shouldEnable = (v == true) and (not blockedByBgTask)
                    if lastFieldEnabled[i] ~= shouldEnable then
                        field:enable(shouldEnable)
                        lastFieldEnabled[i] = shouldEnable
                    end
                end
            end
        elseif not tasksActive then
            for i, field in pairs(app.formFields) do
                if field and field.enable then
                    local shouldEnable = app.formFieldsBGTask[i] ~= true
                    if lastFieldEnabled[i] ~= shouldEnable then
                        field:enable(shouldEnable)
                        lastFieldEnabled[i] = shouldEnable
                    end
                end
            end
        else
            for i, field in pairs(app.formFields) do
                if field and field.enable then
                    if lastFieldEnabled[i] ~= true then
                        field:enable(true)
                        lastFieldEnabled[i] = true
                    end
                end
            end
        end

        if lastLinkState ~= isConnected then
            lastLinkState = isConnected
            if form and form.invalidate then form.invalidate() end
        end
    end

    local function event(widget, category, value)
        return navHandlers.event(widget, category, value)
    end

    return {
        pages = pages,
        openPage = openPage,
        wakeup = wakeup,
        onNavMenu = navHandlers.onNavMenu,
        event = event,
        API = cfg.API or {},
        navButtons = MENU_ONLY_NAV_BUTTONS
    }
end

return container
