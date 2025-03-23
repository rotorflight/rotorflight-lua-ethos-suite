local idx = rfsuite.app.batteryIndex
local setActiveProfile = nil

local mspapi = {
    api = {
        [1] = 'BATTERY_CONFIG',
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = rfsuite.i18n.get("app.modules.battery.max_cell_voltage"), mspapi = 1, apikey="vbatmaxcellvoltage"},
            {t = rfsuite.i18n.get("app.modules.battery.full_cell_voltage"), mspapi = 1,  apikey="vbatfullcellvoltage"},
            {t = rfsuite.i18n.get("app.modules.battery.warn_cell_voltage"), mspapi = 1,  apikey="vbatwarningcellvoltage"},
            {t = rfsuite.i18n.get("app.modules.battery.min_cell_voltage"), mspapi = 1,  apikey="vbatmincellvoltage"},
            {t = rfsuite.i18n.get("app.modules.battery.battery_capacity"), mspapi = 1,  apikey="batteryCapacity_".. idx},
            {t = rfsuite.i18n.get("app.modules.battery.cell_count"), mspapi = 1,  apikey="batteryCellCount_".. idx}
        }
    }
}

local function onNavMenu(self)

    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(rfsuite.app.lastIdx, rfsuite.app.lastTitle, "battery/battery.lua")

end



return {
    mspapi = mspapi,
    eepromWrite = true,
    reboot = false,
    API = {},
    wakeup = wakeup,
    navButtons = getNavButtons,
    onToolMenu = onToolMenu,
    onNavMenu = onNavMenu,
}
