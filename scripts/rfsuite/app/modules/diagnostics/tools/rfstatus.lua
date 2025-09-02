local fields = {}
local labels = {}
local i18n = rfsuite.i18n.get
local enableWakeup = false
local lastWakeup = 0  -- store last run time in seconds
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
    local config = {}

    rfsuite.app.ui.fieldHeader(rfsuite.i18n.get("app.modules.diagnostics.name")  .. " / " .. rfsuite.i18n.get("app.modules.rfstatus.name"))

    -- fresh tables so lookups are never stale/nil
    rfsuite.app.formLineCnt = 0
    rfsuite.app.formFields  = {}
    rfsuite.app.formLines   = {}
    local formFieldCount = 0

    -- Background Task status
    local bgtaskStatus = rfsuite.i18n.get("app.modules.rfstatus.ok")
    if not rfsuite.tasks.active() then bgtaskStatus = rfsuite.i18n.get("app.modules.rfstatus.error") end
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine(rfsuite.i18n.get("app.modules.rfstatus.bgtask"))
    rfsuite.app.formFields[formFieldCount] = form.addStaticText(
                    rfsuite.app.formLines[rfsuite.app.formLineCnt], 
                    nil, 
                    bgtaskStatus
                )
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    formFieldCount = formFieldCount + 1


    -- RF Module Status
    local moduleState = (model.getModule(0):enable()  or model.getModule(1):enable()) or false            
    local moduleStatus = rfsuite.i18n.get("app.modules.rfstatus.ok")
    if not moduleState then moduleStatus = rfsuite.i18n.get("app.modules.rfstatus.error") end
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine(rfsuite.i18n.get("app.modules.rfstatus.rfmodule"))
    rfsuite.app.formFields[formFieldCount] = form.addStaticText(
                    rfsuite.app.formLines[rfsuite.app.formLineCnt], 
                    nil, 
                    moduleStatus
                )
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    formFieldCount = formFieldCount + 1

    -- MSP Sensor Status
    local sportSensor = system.getSource({appId = 0xF101})
    local elrsSensor = system.getSource({crsfId=0x14, subIdStart=0, subIdEnd=1})
    local mspStatus = rfsuite.i18n.get("app.modules.rfstatus.ok")
    if not (sportSensor or elrsSensor)  then mspStatus = rfsuite.i18n.get("app.modules.rfstatus.error") end
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine(rfsuite.i18n.get("app.modules.rfstatus.mspsensor"))
    rfsuite.app.formFields[formFieldCount] = form.addStaticText(
                    rfsuite.app.formLines[rfsuite.app.formLineCnt], 
                    nil, 
                    mspStatus
                )
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    formFieldCount = formFieldCount + 1

    -- Telemetry Sensor Status
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine(rfsuite.i18n.get("app.modules.rfstatus.telemetrysensors"))
    rfsuite.app.formFields[formFieldCount] = form.addStaticText(
                    rfsuite.app.formLines[rfsuite.app.formLineCnt], 
                    nil, 
                    "-")
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    formFieldCount = formFieldCount + 1


    enableWakeup = true
end


local function postLoad(self)
    rfsuite.utils.log("postLoad","debug")
end

local function postRead(self)
    rfsuite.utils.log("postRead","debug")
end


local function wakeup()
    if enableWakeup == false then return end

    -- check time since last execution
    local now = os.clock()
    if (now - lastWakeup) < 2 then return end
    lastWakeup = now

    -- Background Task
    do
        local field = rfsuite.app.formFields and rfsuite.app.formFields[0]
        if field then
            if rfsuite.tasks and rfsuite.tasks.active() then
                field:value(i18n("app.modules.rfstatus.ok"))
                field:color(GREEN)
            else
                field:value(i18n("app.modules.rfstatus.error"))
                field:color(RED)
            end
        end
    end

    -- RF Module
    do
        local field = rfsuite.app.formFields and rfsuite.app.formFields[1]
        if field then
            local m0 = model.getModule(0)
            local m1 = model.getModule(1)
            local enabled = (m0 and m0:enable()) or (m1 and m1:enable()) or false
            if enabled then
                field:value(i18n("app.modules.rfstatus.ok"))
                field:color(GREEN)
            else
                field:value(i18n("app.modules.rfstatus.error"))
                field:color(RED)
            end
        end
    end

    -- MSP Sensor
    do
        local field = rfsuite.app.formFields and rfsuite.app.formFields[2]
        if field then
            local sportSensor = system.getSource({appId = 0xF101})
            local elrsSensor  = system.getSource({crsfId = 0x14, subIdStart = 0, subIdEnd = 1})
            if sportSensor or elrsSensor then
                field:value(i18n("app.modules.rfstatus.ok"))
                field:color(GREEN)
            else
                field:value(i18n("app.modules.rfstatus.error"))
                field:color(RED)
            end
        end
    end

    -- Telemetry Sensors
    do
        local field = rfsuite.app.formFields and rfsuite.app.formFields[3]
        if field then
            local sensors = rfsuite.tasks and rfsuite.tasks.telemetry
                          and rfsuite.tasks.telemetry.validateSensors(false) or false
            if type(sensors) == "table" then
                if #sensors == 0 then
                    field:value(i18n("app.modules.rfstatus.ok"))
                    field:color(GREEN)
                else
                    field:value(i18n("app.modules.rfstatus.error"))
                    field:color(RED)
                end
            else
                field:value("-")
            end
        end
    end
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
