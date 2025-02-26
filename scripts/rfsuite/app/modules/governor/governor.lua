
local mspapi = {
    api = {
        [1] = 'GOVERNOR_CONFIG',
    },
    formdata = {
        labels = {
        },
        fields = {
        { t = "Mode",                  mspapi = 1, apikey = "gov_mode", postEdit = function(self) self.setGovernorMode(self) end,  type = 1},
        { t = "Handover throttle%",    mspapi = 1, apikey = "gov_handover_throttle" },
        { t = "Min spoolup throttle%", mspapi = 1, apikey = "gov_spoolup_min_throttle", apiversion = 12.08 },
        { t = "Startup time",          mspapi = 1, apikey = "gov_startup_time" },
        { t = "Spoolup time",          mspapi = 1, apikey = "gov_spoolup_time" },
        { t = "Tracking time",         mspapi = 1, apikey = "gov_tracking_time" },
        { t = "Recovery time",         mspapi = 1, apikey = "gov_recovery_time" },
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

return {
    mspapi=mspapi,
    reboot = true,
    eepromWrite = true,
    labels = labels,
    setGovernorMode = setGovernorMode,
    fields = fields,
    postLoad = postLoad,
    postSave = postSave
}