local i18n = rfsuite.i18n.get


local enableWakeup = false
local prevConnectedState = nil
local page

local function openPage(idx, title, script, source, folder,themeScript)
    -- Initialize global UI state and clear form data
    rfsuite.app.uiState = rfsuite.app.uiStatus.pages
    rfsuite.app.triggers.isReady = false
    rfsuite.app.formFields = {}
    rfsuite.app.formLines = {}
    rfsuite.app.lastLabel = nil

    rfsuite.app.dashboardEditingTheme = source .. "/" .. folder

    -- Load the module
    local modulePath =  themeScript

    page = assert(rfsuite.compiler.loadfile(modulePath))(idx)

    -- load up the menu
    local w, h = lcd.getWindowSize()
    local windowWidth = w
    local windowHeight = h
    local padding = rfsuite.app.radio.buttonPadding

    local sc
    local panel   

    form.clear()

    --form.addLine("../ " .. i18n("app.modules.settings.dashboard") .. " / " .. i18n("app.modules.settings.name") .. " / " .. title)
    form.addLine( i18n("app.modules.settings.name") .. " / " .. title)
    buttonW = 100
    local x = windowWidth - (buttonW * 2) - 15

    rfsuite.app.formNavigationFields['menu'] = form.addButton(line, {x = x, y = rfsuite.app.radio.linePaddingTop, w = buttonW, h = rfsuite.app.radio.navbuttonHeight}, {
        text = i18n("app.navigation_menu"),
        icon = nil,
        options = FONT_S,
        paint = function()
        end,
        press = function()
            rfsuite.app.lastIdx = nil
            rfsuite.session.lastPage = nil

            if rfsuite.app.Page and rfsuite.app.Page.onNavMenu then rfsuite.app.Page.onNavMenu(rfsuite.app.Page) end


            rfsuite.app.ui.openPage(
                pageIdx,
                i18n("app.modules.settings.dashboard"),
                "settings/tools/dashboard_settings.lua"
            )
        end
    })
    rfsuite.app.formNavigationFields['menu']:focus()


    local x = windowWidth - buttonW - 10
    rfsuite.app.formNavigationFields['save'] = form.addButton(line, {x = x, y = rfsuite.app.radio.linePaddingTop, w = buttonW, h = rfsuite.app.radio.navbuttonHeight}, {
        text = "SAVE",
        icon = nil,
        options = FONT_S,
        paint = function()
        end,
        press = function()

                local buttons = {
                    {
                        label  = i18n("app.btn_ok_long"),
                        action = function()
                            local msg = i18n("app.modules.profile_select.save_prompt_local")
                            rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))
                            if page.write then
                                page.write()
                            end    
                            -- update dashboard theme
                            rfsuite.widgets.dashboard.reload_themes()
                            rfsuite.app.triggers.closeSave = true
                            return true
                        end,
                    },
                    {
                        label  = i18n("app.modules.profile_select.cancel"),
                        action = function()
                            return true
                        end,
                    },
                }

                form.openDialog({
                    width   = nil,
                    title   = i18n("app.modules.profile_select.save_settings"),
                    message = i18n("app.modules.profile_select.save_prompt_local"),
                    buttons = buttons,
                    wakeup  = function() end,
                    paint   = function() end,
                    options = TEXT_LEFT,
                })

        end
    })
    rfsuite.app.formNavigationFields['menu']:focus()

    
    rfsuite.app.uiState = rfsuite.app.uiStatus.pages
    enableWakeup = true

    
    -- If the Page has its own openPage function, use it and return early
    if page.configure then
        page.configure(idx, title, script, extra1, extra2, extra3, extra5, extra6)
        rfsuite.utils.reportMemoryUsage(title)
        rfsuite.app.triggers.closeProgressLoader = true
        return
    end

end

local function event(widget, category, value, x, y)
    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage(
            pageIdx,
            i18n("app.modules.settings.dashboard"),
            "settings/tools/dashboard.lua"
        )
        return true
    end

    if page.event then
        page.event()
    end

end

local function onNavMenu()
    rfsuite.app.ui.progressDisplay(nil,nil,true)
        rfsuite.app.ui.openPage(
            pageIdx,
            i18n("app.modules.settings.dashboard"),
            "settings/tools/dashboard.lua"
        )
        return true
end

local function wakeup()

    if not enableWakeup then
        return
    end

    -- current combined state: true only if both are truthy
    local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false

    -- only update if state has changed
    if currState ~= prevConnectedState then
        -- we cant be here anymore... jump to previous page
        if currState == false then
            onNavMenu()
        end
        -- remember for next time
        prevConnectedState = currState
    end

    if page.wakeup then
        page.wakeup()
    end

end

return {
    pages = pages, 
    openPage = openPage,
    API = {},
    navButtons = {
        menu   = true,
        save   = false,
        reload = false,
        tool   = false,
        help   = false,
    }, 
    event = event,
    onNavMenu = onNavMenu,
    wakeup = wakeup,
}
