local i18n = rfsuite.i18n.get

local apidata = {
        api = {
            [1] = 'GOVERNOR_CONFIG',
        },
        formdata = {
            labels = {
            },
            fields = {
            { t = i18n("app.modules.governor.startup_time"),     mspapi = 1, apikey = "gov_rpm_filter"},
            { t = i18n("app.modules.governor.gov_pwr_filter"),     mspapi = 1, apikey = "gov_pwr_filter"},
            { t = i18n("app.modules.governor.gov_tta_filter"),     mspapi = 1, apikey = "gov_tta_filter"},
            { t = i18n("app.modules.governor.gov_ff_filter"),      mspapi = 1, apikey = "gov_ff_filter"},                        
            { t = i18n("app.modules.governor.gov_d_filter"),       mspapi = 1, apikey = "gov_d_filter"},			
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