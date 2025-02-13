local labels = {}
local fields = {}
local simulatorResponse
local minBytes


fields[#fields + 1] = { t = "Mode" , postEdit = function(self) self.setGovernorMode(self) end , type=1, apikey="gov_mode"}
fields[#fields + 1] = {t = "Handover throttle%", help = "govHandoverThrottle", apikey = "gov_handover_throttle"}

if rfsuite.config.apiVersion >= 12.08 then 
fields[#fields + 1] = {t = "Min spoolup throttle%", help = "govSpoolupThrottle", apikey = "gov_spoolup_min_throttle"}
end

fields[#fields + 1] = {t = "Startup time", help = "govStartupTime", apikey = "gov_startup_time"}
fields[#fields + 1] = {t = "Spoolup time", help = "govSpoolupTime", apikey = "gov_spoolup_time"}
fields[#fields + 1] = {t = "Tracking time", help = "govTrackingTime", apikey = "gov_tracking_time"}
fields[#fields + 1] = {t = "Recovery time", help = "govRecoveryTime", apikey = "gov_recovery_time"}

local function disableFields()
    for i, v in ipairs(rfsuite.app.formFields) do if i ~= 1 then rfsuite.app.formFields[i]:enable(false) end end
end

local function enableFields()
    for i, v in ipairs(rfsuite.app.formFields) do if i ~= 1 then rfsuite.app.formFields[i]:enable(true) end end
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
    rfsuite.app.triggers.isReady = true
end

local function preSavePayload(payload)

    if rfsuite.config.governorMode ~= payload[1] then rfsuite.config.governorMode = payload[1] end

    return payload
end

return {
    mspapi="GOVERNOR_CONFIG",
    title = "Governor",
    reboot = true,
    eepromWrite = true,
    labels = labels,
    setGovernorMode = setGovernorMode,
    fields = fields,
    postLoad = postLoad,
    preSavePayload = preSavePayload,
    API = {},
}
