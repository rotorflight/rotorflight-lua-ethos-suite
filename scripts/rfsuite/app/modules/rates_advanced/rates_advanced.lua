
local activateWakeup = false
local currentProfileChecked = false
local extraMsgOnSave = nil
local originalRateTable = nil

if rfsuite.RateTable == nil then rfsuite.RateTable = rfsuite.preferences.defaultRateProfile end

local mspapi = {
    api = {
        [1] = 'RC_TUNING',
    },
    formdata = {
        labels = {
            {t = "Roll dynamics",       label = 1, inline_size = 14.6},
            {t = "Pitch dynamics",      label = 2, inline_size = 14.6},
            {t = "Yaw dynamics",        label = 3, inline_size = 14.6},
            {t = "Collective dynamics", label = 4, inline_size = 14.6}
        },
        fields = {
            {t = "Rates Type",                        mspapi = 1, apikey = "rates_type", type = 1, ratetype = 1, postEdit = function(self) self.flagRateChange(self, true) end},
            {t = "Time",       inline = 2, label = 1, mspapi = 1, apikey = "response_time_1"},
            {t = "Accel",      inline = 1, label = 1, mspapi = 1, apikey = "accel_limit_1"},
            {t = "Time",       inline = 2, label = 2, mspapi = 1, apikey = "response_time_2"},
            {t = "Accel",      inline = 1, label = 2, mspapi = 1, apikey = "accel_limit_2"},
            {t = "Time",       inline = 2, label = 3, mspapi = 1, apikey = "response_time_3"},
            {t = "Accel",      inline = 1, label = 3, mspapi = 1, apikey = "accel_limit_3"},
            {t = "Time",       inline = 2, label = 4, mspapi = 1, apikey = "response_time_4"},
            {t = "Accel",      inline = 1, label = 4, mspapi = 1, apikey = "accel_limit_4"},
        }
    }                 
}

--[[
-- rate table defaults
local function defaultRates(x)
    local defaults = {}
    defaults[0] = {0,   0,  0,  0,  0,  0,  0,   0,  0,  0,  0,  0,  0,   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0}  -- NONE
    defaults[1] = {1, 180,  0,  0,  0,  0,  0, 180,  0,  0,  0,  0,  0, 180,  0,  0,  0,  0,  0, 203,  0,  1,  0,  0,  0} -- BF
    defaults[2] = {2,  36,  0,  0,  0,  0,  0,  36,  0,  0,  0,  0,  0,  36,  0,  0,  0,  0,  0,  50,  0,  0,  0,  0,  0} -- RACEFL
    defaults[3] = {3, 180,  0,  0,  0,  0,  0, 180,  0,  0,  0,  0,  0, 180,  0,  0,  0,  0,  0, 250,  0,  0,  0,  0,  0} -- KISS
    defaults[4] = {4,  36,  0, 36,  0,  0,  0,  36,  0, 36,  0,  0,  0,  36,  0, 36,  0,  0,  0,  48,  0, 48,  0,  0,  0} -- ACTUAL
    defaults[5] = {5, 180,  0, 36,  0,  0,  0, 180,  0, 36,  0,  0,  0, 180,  0, 36,  0,  0,  0, 250,  0,104,  0,  0,  0} -- QUICK

    return defaults[x]
end
]]--

--[[
local function preSavePayload(payload)
    if rfsuite.app.triggers.resetRates == true then
        rfsuite.app.triggers.resetRates = false
        rfsuite.NewRateTable = rfsuite.app.Page.values[1]
        payload = defaultRates(rfsuite.NewRateTable)
    end

    return payload
end
]]--

local function preSave(self)
    if rfsuite.app.triggers.resetRates == true then
        rfsuite.utils.log("Resetting rates to defaults","info")
    end     
end    

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function wakeup()
    if activateWakeup and not currentProfileChecked and rfsuite.bg.msp.mspQueue:isProcessed() then
        -- update active profile
        -- the check happens in postLoad          
        if rfsuite.session.activeRateProfile then
            rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " #" .. rfsuite.session.activeRateProfile)
            currentProfileChecked = true
        end

        -- set this after all data has loaded
        if not originalRateTable then
            originalRateTable = rfsuite.app.Page.fields[1].value
        end
    end
end

-- enable and disable fields if rate type changes
local function flagRateChange(self)
    if rfsuite.app.Page.fields[1].value == originalRateTable then
        self.extraMsgOnSave = nil
        rfsuite.app.ui.enableAllFields()
        rfsuite.app.triggers.resetRates = false
    else
        self.extraMsgOnSave = "Rate type changed. Values will be reset to defaults."
        rfsuite.app.triggers.resetRates = true
        rfsuite.app.ui.disableAllFields()
        rfsuite.app.formFields[1]:enable(true)
    end
end

return {
    mspapi = mspapi,
    title = "Rates",
    reboot = false,
    eepromWrite = true,
    refreshOnRateChange = true,
    rTableName = rTableName,
    flagRateChange = flagRateChange,
    postLoad = postLoad,
    wakeup = wakeup,
    preSave = preSave,
    extraMsgOnSave = extraMsgOnSave,
    API = {},
}
