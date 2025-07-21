local i18n = rfsuite.i18n.get
local enableWakeup = false

-- Local config table for in-memory edits
local config = {}


local function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

local function openPage(pageIdx, title, script)
    enableWakeup = true
    if not rfsuite.app.navButtons then rfsuite.app.navButtons = {} end
    rfsuite.app.triggers.closeProgressLoader = true
    form.clear()

    rfsuite.app.lastIdx    = pageIdx
    rfsuite.app.lastTitle  = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader(
        i18n("app.modules.settings.name") .. " / " .. i18n("app.modules.settings.txt_general")
    )
    rfsuite.app.formLineCnt = 0
    local formFieldCount = 0

    -- Prepare working config as a shallow copy of general preferences
    local saved = rfsuite.preferences.general or {}
    for k, v in pairs(saved) do
        config[k] = v
    end

    -- Icon size choice field
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine(
        i18n("app.modules.settings.txt_iconsize")
    )
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(
        rfsuite.app.formLines[rfsuite.app.formLineCnt],
        nil,
        {
            { i18n("app.modules.settings.txt_text"),  0 },
            { i18n("app.modules.settings.txt_small"), 1 },
            { i18n("app.modules.settings.txt_large"), 2 },
        },
        function()
            return config.iconsize ~= nil and config.iconsize or 1
        end,
        function(newValue)
            config.iconsize = newValue
        end
    )

    -- Sync-name toggle field
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine(
        i18n("app.modules.settings.txt_syncname")
    )
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        rfsuite.app.formLines[rfsuite.app.formLineCnt],
        nil,
        function()
            return config.syncname or false
        end,
        function(newValue)
            config.syncname = newValue
        end
    )

    -- --- TX Battery Panel ---
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    local txPanel = form.addExpansionPanel(i18n("widgets.dashboard.tx_batt"))
    txPanel:open(true)

    -- TX Min field
    local txMinLine = txPanel:addLine(i18n("widgets.dashboard.min"))
    formFieldCount = formFieldCount + 1
    rfsuite.app.formFields[formFieldCount] = form.addNumberField(
        txMinLine, nil, 60, 95,
        function() return math.floor((config.tx_min or GENERAL_DEFAULTS.tx_min) * 10 + 0.5) end,
        function(val)
            local min_val = val / 10
            config.tx_min = clamp(min_val, 6.0, (config.tx_max or GENERAL_DEFAULTS.tx_max) - 0.1)
        end
    )
    rfsuite.app.formFields[formFieldCount]:decimals(1)
    rfsuite.app.formFields[formFieldCount]:suffix("V")

    -- TX Warn field
    local txWarnLine = txPanel:addLine(i18n("widgets.dashboard.warning"))
    formFieldCount = formFieldCount + 1
    rfsuite.app.formFields[formFieldCount] = form.addNumberField(
        txWarnLine, nil, 60, 95,
        function() return math.floor((config.tx_warn or GENERAL_DEFAULTS.tx_warn) * 10 + 0.5) end,
        function(val)
            local warn_val = val / 10
            config.tx_warn = clamp(warn_val, (config.tx_min or GENERAL_DEFAULTS.tx_min) + 0.1, (config.tx_max or GENERAL_DEFAULTS.tx_max) - 0.1)
        end
    )
    rfsuite.app.formFields[formFieldCount]:decimals(1)
    rfsuite.app.formFields[formFieldCount]:suffix("V")

    -- TX Max field
    local txMaxLine = txPanel:addLine(i18n("widgets.dashboard.max"))
    formFieldCount = formFieldCount + 1
    rfsuite.app.formFields[formFieldCount] = form.addNumberField(
        txMaxLine, nil, 70, 99,
        function() return math.floor((config.tx_max or GENERAL_DEFAULTS.tx_max) * 10 + 0.5) end,
        function(val)
            local max_val = val / 10
            config.tx_max = clamp(max_val, (config.tx_warn or GENERAL_DEFAULTS.tx_warn) + 0.1, 9.9)
        end
    )
    rfsuite.app.formFields[formFieldCount]:decimals(1)
    rfsuite.app.formFields[formFieldCount]:suffix("V")

    -- Always enable all fields and Save
    for i, field in ipairs(rfsuite.app.formFields) do
        if field and field.enable then field:enable(true) end
    end
    rfsuite.app.navButtons.save = true
end

local function onNavMenu()
    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(
        pageIdx,
        i18n("app.modules.settings.name"),
        "settings/settings.lua"
    )
end

local function onSaveMenu()
    local buttons = {
        {
            label  = i18n("app.btn_ok_long"),
            action = function()
                local msg = i18n("app.modules.profile_select.save_prompt_local")
                rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))
                for key, value in pairs(config) do
                    rfsuite.preferences.general[key] = value
                end
                rfsuite.ini.save_ini_file(
                    "SCRIPTS:/" .. rfsuite.config.preferences .. "/preferences.ini",
                    rfsuite.preferences
                )
                rfsuite.app.triggers.closeSave = true
                return true
            end,
        },
        {
            label  = i18n("app.modules.profile_select.cancel"),
            action = function()
                return true
            end,
        },
    }

    form.openDialog({
        width   = nil,
        title   = i18n("app.modules.profile_select.save_settings"),
        message = i18n("app.modules.profile_select.save_prompt_local"),
        buttons = buttons,
        wakeup  = function() end,
        paint   = function() end,
        options = TEXT_LEFT,
    })
end

local function event(widget, category, value, x, y)
    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage(
            pageIdx,
            i18n("app.modules.settings.name"),
            "settings/settings.lua"
        )
        return true
    end
end

return {
    event      = event,
    openPage   = openPage,
    onNavMenu  = onNavMenu,
    onSaveMenu = onSaveMenu,
    navButtons = {
        menu   = true,
        save   = true,
        reload = false,
        tool   = false,
        help   = false,
    },
    API = {},
}
