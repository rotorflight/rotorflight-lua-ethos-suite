--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local activateWakeup = false
local extraMsgOnSave = nil
local resetRates = false
local doFullReload = false

if rfsuite.session.activeRateTable == nil then rfsuite.session.activeRateTable = rfsuite.config.defaultRateProfile end

local apidata = {api = {[1] = 'RC_TUNING'}, formdata = {labels = {}, fields = {{t = "@i18n(app.modules.rates_advanced.rate_table)@", mspapi = 1, apikey = "rates_type", type = 1, ratetype = 1, postEdit = function(self) self.flagRateChange(self, true) end}}}}

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

    local v = apidata.values[apidata.api[1]].rates_type

    rfsuite.utils.log("Active Rate Table: " .. rfsuite.session.activeRateTable, "debug")

    if v ~= rfsuite.session.activeRateTable then
        rfsuite.utils.log("Switching Rate Table: " .. v, "info")
        rfsuite.app.triggers.reloadFull = true
        rfsuite.session.activeRateTable = v
        return
    end

    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function wakeup()
    if activateWakeup and rfsuite.tasks.msp.mspQueue:isProcessed() then

        if rfsuite.session.activeRateProfile then rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " #" .. rfsuite.session.activeRateProfile) end

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

return {
    apidata = apidata,
    title = "@i18n(app.modules.rates_advanced.rates_type)@",
    reboot = false,
    eepromWrite = true,
    refreshOnRateChange = true,
    rTableName = rTableName,
    flagRateChange = flagRateChange,
    postLoad = postLoad,
    wakeup = wakeup,
    preSave = preSave,
    postEepromWrite = postEepromWrite,
    extraMsgOnSave = extraMsgOnSave,
    API = {}
}
