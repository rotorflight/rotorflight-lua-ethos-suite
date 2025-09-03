local i18n = rfsuite.i18n.get

local apidata = {
        api = {
            [1] = 'GOVERNOR_CONFIG',
        },
        formdata = {
            labels = {
            },
            fields = {
            { t = i18n("app.modules.governor.mode"),                  mspapi = 1, apikey = "gov_mode", postEdit = function(self) self.setGovernorMode(self) end,  type = 1},
            { t = i18n("app.modules.governor.throttle_type"),         mspapi = 1, apikey = "gov_throttle_type", type = 1},
            { t = i18n("app.modules.governor.idle_collective"),       mspapi = 1, apikey = "gov_idle_collective" },
            { t = i18n("app.modules.governor.wot_collective"),        mspapi = 1, apikey = "gov_wot_collective" },
            { t = i18n("app.modules.governor.handover_throttle"),     mspapi = 1, apikey = "gov_handover_throttle" },
            {t = i18n("app.modules.profile_governor.idle_throttle"),  mspapi = 1, apikey = "governor_idle_throttle", enablefunction = function() return (rfsuite.session.governorMode >=1 ) end},
            {t = i18n("app.modules.profile_governor.auto_throttle"),  mspapi = 1, apikey = "governor_auto_throttle", enablefunction = function() return (rfsuite.session.governorMode >=1 ) end},
            { t = i18n("app.modules.governor.throttle_hold_timeout"), mspapi = 1, apikey = "gov_throttle_hold_timeout" },
            }
        }               
    }    

local function disableFields()
    for i, _ in ipairs(rfsuite.app.formFields) do

        if type(rfsuite.app.formFields[i]) == "userdata" then
            if i ~= 1 and rfsuite.app.formFields[i] then
                rfsuite.app.formFields[i]:enable(false)
            end
        end
    end
end

local function enableFields()
    for i, _ in ipairs(rfsuite.app.formFields) do
        if type(rfsuite.app.formFields[i]) == "userdata" then
            if i ~= 1 and rfsuite.app.formFields[i] then
               rfsuite.app.formFields[i]:enable(true)
            end
        end
    end
end

local function setGovernorMode(self)
    local currentIndex = math.floor(rfsuite.app.Page.fields[1].value)
    if currentIndex == 0 then
        disableFields()
    else
        enableFields()
    end
end

local function postLoad(self)
    setGovernorMode(self)
    rfsuite.app.triggers.closeProgressLoader = true
end

local function postSave(self)

    if rfsuite.session.governorMode ~= rfsuite.app.Page.fields[1].value then
        rfsuite.session.governorMode = rfsuite.app.Page.fields[1].value
        rfsuite.utils.log("Governor mode: " .. rfsuite.session.governorMode,"info")
    end
    return payload
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
    setGovernorMode = setGovernorMode,
    postLoad = postLoad,
    postSave = postSave,
    onNavMenu = onNavMenu,
    event = event
}