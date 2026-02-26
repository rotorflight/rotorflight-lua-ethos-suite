--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local navHandlers = pageRuntime.createMenuHandlers({defaultSection = "hardware"})

local activateWakeup = false
local extraMsgOnSave = nil
local resetRates = false
local doFullReload = false

if rfsuite.session.activeRateTable == nil then rfsuite.session.activeRateTable = rfsuite.config.defaultRateProfile end

local apidata = {
        api = {
            {id = 1, name = "RC_TUNING", enableDeltaCache = false, rebuildOnWrite = true},
        },
        formdata = {labels = {}, fields = {{t = "@i18n(app.modules.rates_advanced.rate_table)@", mspapi = 1, apikey = "rates_type", type = 1, ratetype = 1, postEdit = function(self) self.flagRateChange(self, true) end}}}
    }

local function getApiEntryName(entry)
    if type(entry) == "table" then return entry.name end
    return entry
end

local function getRateType()
    local apiName = getApiEntryName(apidata and apidata.api and apidata.api[1])
    local values = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api and rfsuite.tasks.msp.api.apidata and rfsuite.tasks.msp.api.apidata.values

    if values and apiName and values[apiName] and values[apiName].rates_type ~= nil then
        return values[apiName].rates_type
    end

    local fields = rfsuite.app and rfsuite.app.Page and rfsuite.app.Page.apidata and rfsuite.app.Page.apidata.formdata and rfsuite.app.Page.apidata.formdata.fields
    if fields then
        for i = 1, #fields do
            if fields[i] and fields[i].apikey == "rates_type" then
                return fields[i].value
            end
        end
    end

    return nil
end

local function preSave(self)
    if resetRates == true then

        local table_id = rfsuite.app.Page.apidata.formdata.fields[1].value

        local tables = {}
        tables[0] = "app/modules/rates/ratetables/none.lua"
        tables[1] = "app/modules/rates/ratetables/betaflight.lua"
        tables[2] = "app/modules/rates/ratetables/raceflight.lua"
        tables[3] = "app/modules/rates/ratetables/kiss.lua"
        tables[4] = "app/modules/rates/ratetables/actual.lua"
        tables[5] = "app/modules/rates/ratetables/quick.lua"
        tables[6] = "app/modules/rates/ratetables/rotorflight.lua"

        local mytable = assert(loadfile(tables[table_id]))()

        rfsuite.utils.log("Using defaults from table " .. tables[table_id], "info")

        for _, y in pairs(mytable.formdata.fields) do
            if y.default then
                local found = false

                for i, v in ipairs(rfsuite.app.Page.apidata.formdata.fields) do
                    if v.apikey == y.apikey then

                        rfsuite.app.Page.apidata.formdata.fields[i] = y
                        found = true
                        break
                    end
                end

                if not found then table.insert(rfsuite.app.Page.apidata.formdata.fields, y) end
            end
        end

        for i, v in ipairs(rfsuite.app.Page.apidata.formdata.fields) do

            if v.apikey == "rates_type" then
                v.value = table_id
            else

                local default = v.default or 0
                default = default * rfsuite.app.utils.decimalInc(v.decimals)
                if v.mult ~= nil then default = math.floor(default * (v.mult)) end
                if v.scale ~= nil then default = math.floor(default / v.scale) end

                rfsuite.utils.log("Saving default value for " .. v.apikey .. " as " .. default, "debug")
                rfsuite.app.utils.saveFieldValue(v, default)
            end
        end

    end

end

local function postLoad(self)

    local v = getRateType()

    if v == nil then
        rfsuite.utils.log("Unable to resolve rates_type from RC_TUNING data", "warning")
        rfsuite.app.triggers.closeProgressLoader = true
        activateWakeup = true
        return
    end

    local activeRateTable = tonumber(rfsuite.session.activeRateTable) or rfsuite.session.activeRateTable
    local requestedRateTable = tonumber(v) or v

    rfsuite.utils.log("Active Rate Table: " .. tostring(activeRateTable), "debug")

    if requestedRateTable ~= activeRateTable then
        rfsuite.utils.log("Switching Rate Table: " .. tostring(requestedRateTable), "info")
        rfsuite.app.triggers.reloadFull = true
        rfsuite.session.activeRateTable = requestedRateTable
        return
    end

    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function wakeup()
    if activateWakeup and rfsuite.tasks.msp.mspQueue:isProcessed() then

        local activeRateProfile = rfsuite.session and rfsuite.session.activeRateProfile
        if activeRateProfile ~= nil then
            local baseTitle = rfsuite.app.lastTitle or (rfsuite.app.Page and rfsuite.app.Page.title) or ""
            baseTitle = tostring(baseTitle):gsub("%s+#%d+$", "")
            rfsuite.app.ui.setHeaderTitle(baseTitle .. " #" .. activeRateProfile, nil, rfsuite.app.Page and rfsuite.app.Page.navButtons)
        end

        if doFullReload == true then
            rfsuite.utils.log("Reloading full after rate type change", "info")
            rfsuite.app.triggers.reload = true
            doFullReload = false
        end
    end
end

local function flagRateChange(self)

    if math.floor(rfsuite.app.Page.apidata.formdata.fields[1].value) == math.floor(rfsuite.session.activeRateTable) then
        self.extraMsgOnSave = nil
        rfsuite.app.ui.enableAllFields()
        resetRates = false
    else
        self.extraMsgOnSave = "@i18n(app.modules.rates_advanced.msg_reset_to_defaults)@"
        resetRates = true
        rfsuite.app.ui.disableAllFields()
        rfsuite.app.formFields[1]:enable(true)
    end
end


local function postEepromWrite(self) if resetRates == true then doFullReload = true end end

return {apidata = apidata, title = "@i18n(app.modules.rates_advanced.rates_type)@", onNavMenu = navHandlers.onNavMenu, event = navHandlers.event, reboot = false, eepromWrite = true, refreshOnRateChange = true, rTableName = rTableName, flagRateChange = flagRateChange, postLoad = postLoad, wakeup = wakeup, preSave = preSave, postEepromWrite = postEepromWrite, extraMsgOnSave = extraMsgOnSave, API = {}}
