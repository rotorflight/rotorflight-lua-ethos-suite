--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local app = rfsuite.app
local tasks = rfsuite.tasks

local BEEPER_FIELDS = {
    { bit = 0, label = "@i18n(app.modules.beepers.field_gyro_calibrated)@" },
    { bit = 1, label = "@i18n(app.modules.beepers.field_rx_lost)@" },
    { bit = 2, label = "@i18n(app.modules.beepers.field_rx_lost_landing)@" },
    { bit = 3, label = "@i18n(app.modules.beepers.field_disarming)@" },
    { bit = 4, label = "@i18n(app.modules.beepers.field_arming)@" },
    { bit = 5, label = "@i18n(app.modules.beepers.field_arming_gps_fix)@" },
    { bit = 6, label = "@i18n(app.modules.beepers.field_bat_crit_low)@" },
    { bit = 7, label = "@i18n(app.modules.beepers.field_bat_low)@" },
    { bit = 8, label = "@i18n(app.modules.beepers.field_gps_status)@" },
    { bit = 9, label = "@i18n(app.modules.beepers.field_rx_set)@" },
    { bit = 10, label = "@i18n(app.modules.beepers.field_acc_calibration)@" },
    { bit = 11, label = "@i18n(app.modules.beepers.field_acc_calibration_fail)@" },
    { bit = 12, label = "@i18n(app.modules.beepers.field_ready_beep)@" },
    { bit = 14, label = "@i18n(app.modules.beepers.field_disarm_repeat)@" },
    { bit = 15, label = "@i18n(app.modules.beepers.field_armed)@" },
    { bit = 16, label = "@i18n(app.modules.beepers.field_system_init)@" },
    { bit = 17, label = "@i18n(app.modules.beepers.field_usb)@" },
    { bit = 18, label = "@i18n(app.modules.beepers.field_blackbox_erase)@" },
    { bit = 21, label = "@i18n(app.modules.beepers.field_arming_gps_no_fix)@" }
}

local state = {
    loading = false,
    loaded = false,
    saving = false,
    dirty = false,
    pendingReads = 0,
    cfg = {
        beeper_off_flags = 0,
        dshotBeaconTone = 1,
        dshotBeaconOffFlags = 0
    },
    form = {
        toggles = {}
    }
}

local function copyTable(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do
        if type(v) == "table" then dst[k] = copyTable(v) else dst[k] = v end
    end
    return dst
end

local function isBitSet(mask, bit)
    local m = tonumber(mask or 0) or 0
    return (m & (1 << bit)) ~= 0
end

local function setBit(mask, bit, set)
    local m = tonumber(mask or 0) or 0
    local f = (1 << bit)
    if set then
        return (m | f)
    end
    return (m & (~f))
end

local function isBeeperEnabled(bit)
    local offMask = tonumber(state.cfg.beeper_off_flags or 0) or 0
    return not isBitSet(offMask, bit)
end

local function setBeeperEnabled(bit, enabled)
    state.cfg.beeper_off_flags = setBit(state.cfg.beeper_off_flags, bit, not enabled)
end

local function markDirty()
    state.dirty = true
end

local function useDirtySave()
    local pref = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.save_dirty_only
    return not (pref == false or pref == "false")
end

local function updateSaveEnabled()
    local save = app.formNavigationFields and app.formNavigationFields.save
    if save and save.enable then
        local allow = state.loaded and (not state.saving) and ((not useDirtySave()) or state.dirty)
        save:enable(allow)
    end
end

local function renderLoading(message)
    form.clear()
    app.ui.fieldHeader("@i18n(app.modules.beepers.name)@ / @i18n(app.modules.beepers.menu_configuration)@")
    local line = form.addLine("@i18n(app.modules.beepers.status)@")
    form.addStaticText(line, nil, message or "@i18n(app.msg_loading)@")
end

local function renderForm()
    form.clear()
    app.ui.fieldHeader("@i18n(app.modules.beepers.name)@ / @i18n(app.modules.beepers.menu_configuration)@")

    state.form.toggles = {}

    for i = 1, #BEEPER_FIELDS do
        local def = BEEPER_FIELDS[i]
        local line = form.addLine(def.label)
        state.form.toggles[def.bit] = form.addBooleanField(line, nil, function()
            return isBeeperEnabled(def.bit)
        end, function(v)
            setBeeperEnabled(def.bit, v)
            markDirty()
            updateSaveEnabled()
        end)
    end

    updateSaveEnabled()
    app.triggers.closeProgressLoader = true
end

local function syncSessionSnapshot()
    if not rfsuite.session then return end
    if not rfsuite.session.beepers then rfsuite.session.beepers = {} end
    rfsuite.session.beepers.config = copyTable(state.cfg)
    rfsuite.session.beepers.ready = true
end

local function onReadDone()
    state.pendingReads = state.pendingReads - 1
    if state.pendingReads <= 0 then
        state.loading = false
        state.loaded = true
        syncSessionSnapshot()
        renderForm()
    end
end

local function loadFromSessionSnapshot()
    local snapshot = rfsuite.session and rfsuite.session.beepers or nil
    if not snapshot or not snapshot.config then return false end

    local parsed = snapshot.config
    state.cfg.beeper_off_flags = tonumber(parsed.beeper_off_flags or 0) or 0
    state.cfg.dshotBeaconTone = tonumber(parsed.dshotBeaconTone or 1) or 1
    state.cfg.dshotBeaconOffFlags = tonumber(parsed.dshotBeaconOffFlags or 0) or 0
    return true
end

local function requestData(forceApiRead)
    if state.loading then return end

    state.loading = true
    state.loaded = false
    state.dirty = false

    renderLoading("@i18n(app.modules.beepers.loading)@")

    if not forceApiRead and loadFromSessionSnapshot() then
        state.loading = false
        state.loaded = true
        renderForm()
        return
    end

    state.pendingReads = 1

    local API = tasks.msp.api.load("BEEPER_CONFIG")
    API.setUUID("beepers-config-main")
    API.setCompleteHandler(function()
        local d = API.data()
        local parsed = d and d.parsed or nil
        if parsed then
            state.cfg.beeper_off_flags = tonumber(parsed.beeper_off_flags or 0) or 0
            state.cfg.dshotBeaconTone = tonumber(parsed.dshotBeaconTone or 1) or 1
            state.cfg.dshotBeaconOffFlags = tonumber(parsed.dshotBeaconOffFlags or 0) or 0
        end
        onReadDone()
    end)
    API.setErrorHandler(function() onReadDone() end)
    API.read()
end

local function openPage()
    requestData(false)
end

local function performSave()
    if not state.loaded or state.saving then return end
    if useDirtySave() and (not state.dirty) then return end

    state.saving = true
    app.ui.progressDisplaySave("@i18n(app.modules.beepers.saving)@")

    local API = tasks.msp.api.load("BEEPER_CONFIG")
    API.setUUID("beepers-config-write")
    API.setErrorHandler(function()
        state.saving = false
        app.triggers.closeSave = true
        app.triggers.showSaveArmedWarning = true
        updateSaveEnabled()
    end)
    API.setCompleteHandler(function()
        local eepromWrite = {
            command = 250,
            processReply = function()
                state.saving = false
                state.dirty = false
                syncSessionSnapshot()
                app.triggers.closeSave = true
                updateSaveEnabled()
            end,
            errorHandler = function()
                state.saving = false
                app.triggers.closeSave = true
                app.triggers.showSaveArmedWarning = true
                updateSaveEnabled()
            end,
            simulatorResponse = {}
        }
        local ok = tasks.msp.mspQueue:add(eepromWrite)
        if not ok then
            state.saving = false
            app.triggers.closeSave = true
            app.triggers.showSaveArmedWarning = true
            updateSaveEnabled()
        end
    end)

    API.setValue("beeper_off_flags", state.cfg.beeper_off_flags)
    API.setValue("dshotBeaconTone", state.cfg.dshotBeaconTone)
    API.setValue("dshotBeaconOffFlags", state.cfg.dshotBeaconOffFlags)
    API.write()
end

local function onSaveMenu()
    if not state.loaded then return end
    if useDirtySave() and (not state.dirty) then return end

    if rfsuite.preferences.general.save_confirm == false or rfsuite.preferences.general.save_confirm == "false" then
        performSave()
        return
    end

    local buttons = {
        {
            label = "@i18n(app.btn_ok_long)@",
            action = function()
                performSave()
                return true
            end
        },
        {
            label = "@i18n(app.btn_cancel)@",
            action = function() return true end
        }
    }

    form.openDialog({
        width = nil,
        title = "@i18n(app.msg_save_settings)@",
        message = "@i18n(app.msg_save_current_page)@",
        buttons = buttons,
        wakeup = function() end,
        paint = function() end,
        options = TEXT_LEFT
    })
end

local function onReloadMenu()
    requestData(true)
end

local function wakeup()
    updateSaveEnabled()
end

local function event(widget, category, value)
    if category == EVT_CLOSE and (value == 0 or value == 35) then
        app.ui.openPage({idx = app.lastIdx, title = "@i18n(app.modules.beepers.name)@", script = "beepers/beepers.lua"})
        return true
    end
end

local function onNavMenu()
    app.ui.openPage({idx = app.lastIdx, title = "@i18n(app.modules.beepers.name)@", script = "beepers/beepers.lua"})
end

return {
    openPage = openPage,
    wakeup = wakeup,
    onSaveMenu = onSaveMenu,
    onReloadMenu = onReloadMenu,
    event = event,
    onNavMenu = onNavMenu,
    eepromWrite = true,
    reboot = false,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = true},
    API = {}
}
