local labels = {}
local fields = {}
local simulatorResponse
local minBytes

if rfsuite.config.apiVersion >= 12.08 then
    simulatorResponse = {3, 100, 0, 100, 0, 20, 0, 20, 0, 30, 0, 10, 0, 0, 0, 0, 0, 50, 0, 10, 5, 10, 0, 10, 5}
    minBytes = 25
else
    simulatorResponse = {3, 100, 0, 100, 0, 20, 0, 20, 0, 30, 0, 10, 0, 0, 0, 0, 0, 50, 0, 10, 5, 10, 0, 10}
    minBytes = 24
end

fields[#fields + 1] = {
    t = "Mode",
    min = 0,
    max = 4,
    vals = {1},
    table = {[0] = "OFF", "PASSTHROUGH", "STANDARD", "MODE1", "MODE2"},
    postEdit = function(self)
        self.setGovernorMode(self)
    end
}
fields[#fields + 1] = {t = "Handover throttle%", help = "govHandoverThrottle", min = 10, max = 50, unit = "%", default = 20, vals = {20}}

if rfsuite.config.apiVersion >= 12.08 then fields[#fields + 1] = {t = "Min  spoolup throttle%", help = "govSpoolupThrottle", min = 0, max = 50, unit = "%", default = 0, vals = {25}} end

fields[#fields + 1] = {t = "Startup time", help = "govStartupTime", min = 0, max = 600, unit = "s", default = 200, vals = {2, 3}, decimals = 1, scale = 10}
fields[#fields + 1] = {t = "Spoolup time", help = "govSpoolupTime", min = 0, max = 600, unit = "s", default = 100, vals = {4, 5}, decimals = 1, scale = 10}
fields[#fields + 1] = {t = "Tracking time", help = "govTrackingTime", min = 0, max = 100, unit = "s", default = 10, vals = {6, 7}, decimals = 1, scale = 10}
fields[#fields + 1] = {t = "Recovery time", help = "govRecoveryTime", min = 0, max = 100, unit = "s", default = 21, vals = {8, 9}, decimals = 1, scale = 10}

labels[#labels + 1] = {t = "Auto Rotation", label = "ar", inline_size = 40.15}
fields[#fields + 1] = {t = "Bailout", help = "govAutoBailoutTime", inline = 1, label = "ar", min = 0, max = 100, unit = "s", default = 0, vals = {16, 17}, decimals = 1, scale = 10}

labels[#labels + 1] = {t = "", label = "ar2", inline_size = 40.15}
fields[#fields + 1] = {t = "Timeout", help = "govAutoTimeout", inline = 1, label = "ar2", min = 0, max = 600, unit = "s", default = 0, vals = {14, 15}, decimals = 1, scale = 10}

labels[#labels + 1] = {t = "", label = "ar3", inline_size = 40.15}
fields[#fields + 1] = {t = "Min Entry", help = "govAutoMinEntryTime", inline = 1, label = "ar3", min = 0, max = 600, unit = "s", default = 50, vals = {18, 19}, decimals = 1, scale = 10}

fields[#fields + 1] = {t = "Zero throttle Timeout", t2 = "Zero Thr. Timeout", help = "govZeroThrottleTimeout", min = 0, max = 100, unit = "s", default = 30, vals = {10, 11}, decimals = 1, scale = 10}
fields[#fields + 1] = {t = "HS signal timeout", help = "govLostHeadspeedTimeout", min = 0, max = 100, unit = "s", default = 10, vals = {12, 13}, decimals = 1, scale = 10}
fields[#fields + 1] = {t = "HS filter cutoff", help = "govHeadspeedFilterHz", min = 0, max = 250, unit = "Hz", default = 10, vals = {22}}
fields[#fields + 1] = {t = "Volt. filter cutoff", help = "govVoltageFilterHz", min = 0, max = 250, unit = "Hz", default = 5, vals = {21}}
fields[#fields + 1] = {t = "TTA bandwidth", help = "govTTABandwidth", min = 0, max = 250, unit = "Hz", default = 0, vals = {23}}
fields[#fields + 1] = {t = "Precomp bandwidth", help = "govTTAPrecomp", min = 0, max = 250, unit = "Hz", default = 10, vals = {24}}

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
    read = 142, -- msp_GOVERNOR_CONFIG
    write = 143, -- msp_SET_GOVERNOR_CONFIG
    title = "Governor",
    reboot = true,
    simulatorResponse = simulatorResponse, -- variable based on version code above
    eepromWrite = true,
    minBytes = minBytes, -- variable based on version code above
    labels = labels,
    setGovernorMode = setGovernorMode,
    fields = fields,
    postLoad = postLoad,
    preSavePayload = preSavePayload
}
