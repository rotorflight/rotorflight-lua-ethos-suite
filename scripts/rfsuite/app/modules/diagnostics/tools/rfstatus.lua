local fields = {}
local labels = {}
local i18n = rfsuite.i18n.get
local enableWakeup = false

local w, h = lcd.getWindowSize()
local buttonW = 100
local buttonWs = buttonW - (buttonW * 20) / 100
local x = w - 15

local displayPos = {x = x - buttonW - buttonWs - 5 - buttonWs, y = rfsuite.app.radio.linePaddingTop, w = 100, h = rfsuite.app.radio.navbuttonHeight}


local function openPage(pidx, title, script)
    enableWakeup = false
    rfsuite.app.triggers.closeProgressLoader = true

    form.clear()

    -- track page
    rfsuite.app.lastIdx   = pidx   -- was idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript= script

    rfsuite.app.ui.fieldHeader(rfsuite.i18n.get("app.modules.diagnostics.name")  .. " / " .. rfsuite.i18n.get("app.modules.rfstatus.name"))

    -- fresh tables so lookups are never stale/nil
    rfsuite.app.formLineCnt = 0
    rfsuite.app.formFields  = {}
    rfsuite.app.formLines   = {}


    enableWakeup = true
end


local function postLoad(self)
    rfsuite.utils.log("postLoad","debug")
end

local function postRead(self)
    rfsuite.utils.log("postRead","debug")
end


local function wakeup()

    -- prevent wakeup running until after initialised
    if enableWakeup == false then return end

end


local function event(widget, category, value, x, y)
    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage(
            pageIdx,
            i18n("app.modules.diagnostics.name"),
            "diagnostics/diagnostics.lua"
        )
        return true
    end
end


local function onNavMenu()
    rfsuite.app.ui.progressDisplay(nil,nil,true)
    rfsuite.app.ui.openPage(
        pageIdx,
        i18n("app.modules.diagnostics.name"),
        "diagnostics/diagnostics.lua"
    )
end

return {
    reboot = false,
    eepromWrite = false,
    minBytes = 0,
    wakeup = wakeup,
    refreshswitch = false,
    simulatorResponse = {},
    postLoad = postLoad,
    postRead = postRead,
    openPage = openPage,
    onNavMenu = onNavMenu,
    event = event,
    navButtons = {
        menu = true,
        save = false,
        reload = false,
        tool = false,
        help = true
    },
    API = {},
}
