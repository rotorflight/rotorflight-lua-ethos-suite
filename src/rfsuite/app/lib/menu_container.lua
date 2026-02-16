--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local lcd = lcd

local container = {}
local MENU_ONLY_NAV_BUTTONS = {menu = true, save = false, reload = false, tool = false, help = false}

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
    local session = rfsuite.session

    local pages = cfg.pages or {}
    local navHandlers = pageRuntime.createMenuHandlers(cfg.navOptions or {})
    local enableWakeup = false

    local function openPage(opts)
        if cfg.onOpenPre then cfg.onOpenPre(opts) end

        local pidx = opts.idx
        local pageTitle = opts.title or cfg.title
        local script = opts.script

        if tasks and tasks.msp then tasks.msp.protocol.mspIntervalOveride = nil end

        app.triggers.isReady = false
        app.uiState = app.uiStatus.mainMenu

        form.clear()
        app._menuFocusEpoch = (app._menuFocusEpoch or 0) + 1

        app.lastIdx = pidx
        app.lastTitle = pageTitle
        app.lastScript = script

        for k in pairs(app.gfx_buttons) do
            if k ~= cfg.moduleKey then app.gfx_buttons[k] = nil end
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
                paint = function() end,
                press = function()
                    if app.Page and app.Page.onNavMenu then
                        app.Page.onNavMenu(app.Page)
                    else
                        navHandlers.onNavMenu()
                    end
                end
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

        app.gfx_buttons[cfg.moduleKey] = app.gfx_buttons[cfg.moduleKey] or {}
        prefs.menulastselected[cfg.moduleKey] = prefs.menulastselected[cfg.moduleKey] or 1

        if app.formFields then for i = 1, #app.formFields do app.formFields[i] = nil end end
        if app.formLines then for i = 1, #app.formLines do app.formLines[i] = nil end end

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
                        app.gfx_buttons[cfg.moduleKey][i] = app.gfx_buttons[cfg.moduleKey][i] or lcd.loadMask(iconPath)
                    else
                        app.gfx_buttons[cfg.moduleKey][i] = nil
                    end
                else
                    app.gfx_buttons[cfg.moduleKey][i] = nil
                end

                app.formFields[i] = form.addButton(line, {x = bx, y = y, w = buttonW, h = buttonH}, {
                    text = item.name,
                    icon = app.gfx_buttons[cfg.moduleKey][i],
                    options = FONT_S,
                    paint = function() end,
                    press = function()
                        prefs.menulastselected[cfg.moduleKey] = i
                        local resolvedScript, speedOverride = resolveItemScript(item)
                        local loaderSpeed = speedOverride or cfg.loaderSpeed or app.loaderSpeed.FAST
                        if type(loaderSpeed) == "string" and app.loaderSpeed then
                            loaderSpeed = app.loaderSpeed[loaderSpeed] or app.loaderSpeed.FAST
                        end
                        app.ui.progressDisplay(nil, nil, loaderSpeed)
                        app.ui.openPage({
                            idx = i,
                            title = titleForChild(cfg, pageTitle, item),
                            script = scriptPathFor(cfg, item, resolvedScript),
                            returnContext = {idx = pidx, title = pageTitle, script = script}
                        })
                    end
                })

                if item.disabled == true then app.formFields[i]:enable(false) end

                if prefs.menulastselected[cfg.moduleKey] == i then app.formFields[i]:focus() end

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

        if not tasks.active() then
            for i, v in pairs(app.formFieldsBGTask) do
                if v == true and app.formFields[i] and app.formFields[i].enable then app.formFields[i]:enable(false) end
            end
        elseif not session.isConnected then
            for i, v in pairs(app.formFieldsOffline) do
                if v == true and app.formFields[i] and app.formFields[i].enable then app.formFields[i]:enable(false) end
            end
        else
            for i in pairs(app.formFields) do
                if app.formFields[i] and app.formFields[i].enable then app.formFields[i]:enable(true) end
            end
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
