local folder = "flrtr"
local ESC = assert(rfsuite.compiler.loadfile("app/modules/esc_tools/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse

local foundEsc = false
local foundEscDone = false

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_FLYROTOR",
    },
    formdata = {
        labels = {
        },
        fields = {
            { t = "@i18n(app.modules.esc_tools.mfg.flrtr.throttle_protocol)@",  mspapi = 1, apikey = "throttle_protocol",  type = 1,        apiversiongte = 12.08 },
            { t = "@i18n(app.modules.esc_tools.mfg.flrtr.telemetry_protocol)@", mspapi = 1, apikey = "telemetry_protocol", type = 1,        apiversiongte = 12.08 },
            { t = "@i18n(app.modules.esc_tools.mfg.flrtr.led_color)@",          mspapi = 1, apikey = "led_color_index",    type = 1,        apiversiongte = 12.08 },
            { t = "@i18n(app.modules.esc_tools.mfg.flrtr.motor_temp_sensor)@",  mspapi = 1, apikey = "motor_temp_sensor",  type = 1,        apiversiongte = 12.08 },
            { t = "@i18n(app.modules.esc_tools.mfg.flrtr.motor_temp)@",         mspapi = 1, apikey = "motor_temp",         apiversiongte = 12.08 },
            { t = "@i18n(app.modules.esc_tools.mfg.flrtr.battery_capacity)@",   mspapi = 1, apikey = "battery_capacity",   apiversiongte = 12.08 },
        }
    }
}

if rfsuite.session.escDetails and rfsuite.session.escDetails.model then
    -- known models strings are
    -- FLYROTOR 280A
    -- FLYROTOR 150A

    -- note.  if you change the order of items in mspapi above - this will need to be updated
    if string.find(rfsuite.session.escDetails.model, "FLYROTOR 150A") then
        -- this works because battery capacity is last item in list.
        -- we just keep popping off the first item until we get to the battery capacity
        if rfsuite.app.Page and rfsuite.app.Page.apidata and rfsuite.app.Page.apidata.formdata and rfsuite.app.Page.apidata.formdata.fields then
            table.remove(rfsuite.app.Page.apidata.formdata.fields, 1)  -- throttle protocol
            table.remove(rfsuite.app.Page.apidata.formdata.fields, 1)  -- telemetry protocol
            table.remove(rfsuite.app.Page.apidata.formdata.fields, 1)  -- led color
            table.remove(rfsuite.app.Page.apidata.formdata.fields, 1)  -- motor temp sensor
            table.remove(rfsuite.app.Page.apidata.formdata.fields, 1)  -- motor temp
        end
    end

end

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
    apidata = apidata,
    eepromWrite = true,
    reboot = false,
    escinfo = escinfo,
    postLoad = postLoad,
    simulatorResponse = simulatorResponse,
    navButtons = { menu = true, save = true, reload = true, tool = false, help = false },
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.flrtr.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.flrtr.other)@",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5,
}
