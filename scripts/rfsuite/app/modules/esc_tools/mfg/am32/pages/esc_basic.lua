

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
            {t = "Direction", type = 1, mspapi = 1, apikey = "motor_direction"},
            {t = "Motor KV", mspapi = 1, apikey = "motor_kv"},
            {t = "Motor Poles", mspapi = 1, apikey = "motor_poles"},
            {t = "startup Power", mspapi = 1, apikey = "startup_power"},
            {t = "Complementary PWM", type = 1, mspapi = 1, apikey = "complementary_pwm"},
            {t = "Brake on Stop", type = 1, mspapi = 1, apikey = "brake_on_stop"},
            {t = "Brake Strength", mspapi = 1, apikey = "brake_strength"},
            {t = "Running Brake", mspapi = 1, apikey = "running_brake_level"},

        }
    }                 
}


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

local foundEsc = false
local foundEscDone = false

return {
    mspapi=mspapi,
    eepromWrite = false,
    reboot = false,
    title = "Basic Setup",
    escinfo = escinfo,
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / AM32 / Basic",
    headerLine = rfsuite.escHeaderLineText,
    wakeup = wakeup
}

