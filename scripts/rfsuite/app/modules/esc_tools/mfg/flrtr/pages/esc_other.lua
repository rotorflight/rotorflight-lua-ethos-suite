local folder = "flrtr"
local ESC = assert(loadfile("app/modules/esc_tools/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse

local foundEsc = false
local foundEscDone = false

local mspapi = {
    api = {
        [1] = "ESC_PARAMETERS_FLYROTOR",
    },
    formdata = {
        labels = {
        },
        fields = {
            { t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.throttle_protocol"),  mspapi = 1, apikey = "throttle_protocol",  type = 1,        mspapigt = 12.08 },
            { t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.telemetry_protocol"), mspapi = 1, apikey = "telemetry_protocol", type = 1,        mspapigt = 12.08 },
            { t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.led_color"),          mspapi = 1, apikey = "led_color_index",    type = 1,        mspapigt = 12.08 },
            { t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.motor_temp_sensor"),  mspapi = 1, apikey = "motor_temp_sensor",  type = 1,        mspapigt = 12.08 },
            { t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.motor_temp"),         mspapi = 1, apikey = "motor_temp",         mspapigt = 12.08 },
            { t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.battery_capacity"),   mspapi = 1, apikey = "battery_capacity",   mspapigt = 12.08 },
        }
    }
}

function postLoad()
    rfsuite.app.triggers.closeProgressLoader = true
end

local function onNavMenu(self)
    rfsuite.app.triggers.escToolEnableButtons = true
    rfsuite.app.ui.openPage(pidx, folder, "esc_tools/esc_tool.lua")
end

local function event(widget, category, value, x, y)
    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        if powercycleLoader then powercycleLoader:close() end
        rfsuite.app.ui.openPage(pidx, folder, "esc_tools/esc_tool.lua")
        return true
    end
end

return {
    mspapi = mspapi,
    eepromWrite = true,
    reboot = false,
    escinfo = escinfo,
    postLoad = postLoad,
    simulatorResponse = simulatorResponse,
    navButtons = { menu = true, save = true, reload = true, tool = false, help = false },
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = rfsuite.i18n.get("app.modules.esc_tools.name") .. " / " .. rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.name") .. " / " .. rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.other"),
    headerLine = rfsuite.escHeaderLineText
}
