

local apidata = {
        api = {
            [1] = 'GOVERNOR_CONFIG',
        },
        formdata = {
            labels = {
            },
            fields = {
            { t = "@i18n(app.modules.governor.startup_time)@",     mspapi = 1, apikey = "gov_startup_time"},
            { t = "@i18n(app.modules.governor.spoolup_time)@",     mspapi = 1, apikey = "gov_spoolup_time"},
            { t = "@i18n(app.modules.governor.spooldown_time)@",     mspapi = 1, apikey = "gov_spooldown_time"},
            { t = "@i18n(app.modules.governor.tracking_time)@",     mspapi = 1, apikey = "gov_tracking_time" },
            { t = "@i18n(app.modules.governor.recovery_time)@",     mspapi = 1, apikey = "gov_recovery_time" }
            }
        }               
    }    

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
end


local function event(widget, category, value, x, y)
    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage(pidx, title, "governor/governor.lua")  
        return true
    end
end


local function onNavMenu()
    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(pidx, title, "governor/governor.lua")  
    return true
end

return {
    apidata = apidata,
    reboot = true,
    eepromWrite = true,
    postLoad = postLoad,
    onNavMenu = onNavMenu,
    event = event
}