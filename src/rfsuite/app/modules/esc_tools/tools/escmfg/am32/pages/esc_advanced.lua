--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()

local folder = "am32"
local ESC = assert(loadfile("app/modules/esc_tools/tools/escmfg/" .. folder .. "/init.lua"))()
local simulatorResponse = ESC.simulatorResponse
local activateWakeup = false

local function buildTimingAdvanceTableNew()
    local tableEthos = {}
    for raw = 10, 42 do
        local degrees = (raw - 10) * 0.9375
        tableEthos[#tableEthos + 1] = {string.format("%.2f°", degrees), raw}
    end
    return tableEthos
end

local function applyTimingAdvanceTable()
    local values = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api and rfsuite.tasks.msp.api.apidata and rfsuite.tasks.msp.api.apidata.values
    local parsed = values and values["ESC_PARAMETERS_AM32"]
    local isNew = parsed and parsed.timing_advance_is_new

    local fields = rfsuite.app.Page and rfsuite.app.Page.apidata and rfsuite.app.Page.apidata.formdata and rfsuite.app.Page.apidata.formdata.fields
    if not fields then return end

    local fieldIndex
    for i, f in ipairs(fields) do
        if f.apikey == "timing_advance" then
            fieldIndex = i
            break
        end
    end

    if not fieldIndex then return end

    local field = fields[fieldIndex]
    local formField = rfsuite.app.formFields and rfsuite.app.formFields[fieldIndex]

    if isNew then
        local tableEthos = buildTimingAdvanceTableNew()
        field.tableEthos = tableEthos
        if formField and formField.values then
            formField:values(tableEthos)
        end
    else
        field.tableEthos = nil
        if formField and formField.values and field.table then
            local tbldata = rfsuite.app.utils.convertPageValueTable(field.table, field.tableIdxInc)
            formField:values(tbldata)
        end
    end
end

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_AM32",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.am32.timing)@",  mspapi = 1, type = 1, apikey = "timing_advance", minEepromVersion = 1},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.autotiming)@",  mspapi = 1, type = 1, apikey = "auto_advance", minEepromVersion = 1},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.variablepwm)@",  mspapi = 1, type = 1, apikey = "variable_pwm_frequency", minEepromVersion = 1},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.stuckrotorprotection)@",  mspapi = 1, type = 1, apikey = "stuck_rotor_protection", minEepromVersion = 1},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.sinusoidalstartup)@",  mspapi = 1, type = 1, apikey = "sinusoidal_startup", minEepromVersion = 1},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.sinepowermode)@",  mspapi = 1, apikey = "sine_mode_power", minEepromVersion = 1},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.sinemoderange)@",  mspapi = 1, apikey = "sine_mode_range", minEepromVersion = 1},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.bidirectionalmode)@",  mspapi = 1, type = 1, apikey = "bidirectional_mode", minEepromVersion = 1},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.protocol)@",  mspapi = 1, type = 1, apikey = "esc_protocol", minEepromVersion = 1},
        }
    }
}

local function postLoad()
    applyTimingAdvanceTable()
    rfsuite.app.triggers.closeProgressLoader = true
end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)

local foundEsc = false
local foundEscDone = false

return {
    apidata = apidata,
    eepromWrite = false,
    reboot = false,
    escinfo = escinfo,
    svFlags = 0,
    simulatorResponse = simulatorResponse,
    postLoad = postLoad,
    navButtons = navHandlers.navButtons,
    onNavMenu = navHandlers.onNavMenu,
    event = navHandlers.event,
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.am32.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.am32.advanced)@",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5
}

