
local folder = "am32"
local ESC = assert(loadfile("app/modules/esc_tools/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse
local activateWakeup = false

local mspapi = {
    api = {
        [1] = "ESC_PARAMETERS_AM32",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "Timing",  mspapi = 1, type = 1, apikey = "timing_advance"},
        }
    }                 
}

local foundEsc = false
local foundEscDone = false

function postLoad()
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function onNavMenu(self)
    rfsuite.app.triggers.escToolEnableButtons = true
    rfsuite.app.ui.openPage(pidx, folder , "esc_tools/esc_tool.lua")
end

local function event(widget, category, value, x, y)
    
    if category == 5 or value == 35 then
        rfsuite.app.ui.openPage(pidx, folder , "esc_tools/esc_tool.lua")
        return true
    end

    return false
end

local function wakeup(self)
    if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then
        activateWakeup = false
    end
end

return {
    mspapi=mspapi,
    eepromWrite = true,
    reboot = false,
    title = "Advanced Setup",
    escinfo = escinfo,
    simulatorResponse =  simulatorResponse,
    svTiming = 0,
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / AM32 / Advanced",
    headerLine = rfsuite.escHeaderLineText,
    wakeup = wakeup
}
