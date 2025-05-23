local settings = {}

local function openPage(pageIdx, title, script)
    enableWakeup = true
    rfsuite.app.triggers.closeProgressLoader = true
    form.clear()

    rfsuite.app.lastIdx    = pageIdx
    rfsuite.app.lastTitle  = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader(
        rfsuite.i18n.get("app.modules.settings.name") .. " / " .. rfsuite.i18n.get("app.modules.settings.txt_general")
    )
    rfsuite.session.formLineCnt = 0

    local formFieldCount = 0

    settings = rfsuite.preferences.general

    -- Icon size choice field
    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = form.addLine(
        rfsuite.i18n.get("app.modules.settings.txt_iconsize")
    )
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(
        rfsuite.app.formLines[rfsuite.session.formLineCnt],
        nil,
        {
            { rfsuite.i18n.get("app.modules.settings.txt_text"),  0 },
            { rfsuite.i18n.get("app.modules.settings.txt_small"), 1 },
            { rfsuite.i18n.get("app.modules.settings.txt_large"), 2 },
        },
        function()
            if rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.iconsize then
                return settings.iconsize
            else
                return 1
            end
        end,
        function(newValue)
            if rfsuite.preferences and rfsuite.preferences.general then
                settings.iconsize = newValue
            end
        end
    )

    -- Sync-name toggle field
    formFieldCount = formFieldCount + 1
    rfsuite.session.formLineCnt = rfsuite.session.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.session.formLineCnt] = form.addLine(
        rfsuite.i18n.get("app.modules.settings.txt_syncname")
    )
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
        rfsuite.app.formLines[rfsuite.session.formLineCnt],
        nil,
        function()
            if rfsuite.preferences and rfsuite.preferences.general then
                return settings.syncname
            end
        end,
        function(newValue)
            if rfsuite.preferences and rfsuite.preferences.general then
                settings.syncname = newValue
            end
        end
    )
end

local function onNavMenu()
    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(
        pageIdx,
        rfsuite.i18n.get("app.modules.settings.name"),
        "settings/settings.lua"
    )
end

local function onSaveMenu()
    local buttons = {
        {
            label  = rfsuite.i18n.get("app.btn_ok_long"),
            action = function()
                local msg = rfsuite.i18n.get("app.modules.profile_select.save_prompt_local")
                rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))
                for key, value in pairs(settings) do
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
            label  = rfsuite.i18n.get("app.modules.profile_select.cancel"),
            action = function()
                return true
            end,
        },
    }

    form.openDialog({
        width   = nil,
        title   = rfsuite.i18n.get("app.modules.profile_select.save_settings"),
        message = rfsuite.i18n.get("app.modules.profile_select.save_prompt_local"),
        buttons = buttons,
        wakeup  = function() end,
        paint   = function() end,
        options = TEXT_LEFT,
    })
end

return {
    event      = event,
    openPage   = openPage,
    wakeup     = wakeup,
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
