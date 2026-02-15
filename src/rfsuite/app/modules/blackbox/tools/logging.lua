--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local app = rfsuite.app
local tasks = rfsuite.tasks

local FEATURE_BITS = {
    gps = 7,
    governor = 26,
    esc_sensor = 27
}

local state = {
    loading = false,
    loaded = false,
    saving = false,
    dirty = false,
    pendingReads = 0,
    featureBitmap = 0,
    cfg = {
        blackbox_supported = 0,
        device = 0,
        mode = 0,
        denom = 8,
        fields = 0,
        initialEraseFreeSpaceKiB = 0,
        rollingErase = 0,
        gracePeriod = 5
    },
    form = {
        toggles = {}
    }
}

local FIELD_DEFS = {
    {label = "@i18n(app.modules.blackbox.log_command)@", bit = 0},
    {label = "@i18n(app.modules.blackbox.log_setpoint)@", bit = 1},
    {label = "@i18n(app.modules.blackbox.log_mixer)@", bit = 2},
    {label = "@i18n(app.modules.blackbox.log_pid)@", bit = 3},
    {label = "@i18n(app.modules.blackbox.log_attitude)@", bit = 4},
    {label = "@i18n(app.modules.blackbox.log_gyro_raw)@", bit = 5},
    {label = "@i18n(app.modules.blackbox.log_gyro)@", bit = 6},
    {label = "@i18n(app.modules.blackbox.log_acc)@", bit = 7},
    {label = "@i18n(app.modules.blackbox.log_mag)@", bit = 8},
    {label = "@i18n(app.modules.blackbox.log_alt)@", bit = 9},
    {label = "@i18n(app.modules.blackbox.log_battery)@", bit = 10},
    {label = "@i18n(app.modules.blackbox.log_rssi)@", bit = 11},
    {label = "@i18n(app.modules.blackbox.log_gps)@", bit = 12, featureBit = FEATURE_BITS.gps},
    {label = "@i18n(app.modules.blackbox.log_rpm)@", bit = 13},
    {label = "@i18n(app.modules.blackbox.log_motors)@", bit = 14},
    {label = "@i18n(app.modules.blackbox.log_servos)@", bit = 15},
    {label = "@i18n(app.modules.blackbox.log_vbec)@", bit = 16},
    {label = "@i18n(app.modules.blackbox.log_vbus)@", bit = 17},
    {label = "@i18n(app.modules.blackbox.log_temps)@", bit = 18},
    {label = "@i18n(app.modules.blackbox.log_esc)@", bit = 19, apiversiongte = "12.07", featureBit = FEATURE_BITS.esc_sensor},
    {label = "@i18n(app.modules.blackbox.log_bec)@", bit = 20, apiversiongte = "12.07", featureBit = FEATURE_BITS.esc_sensor},
    {label = "@i18n(app.modules.blackbox.log_esc2)@", bit = 21, apiversiongte = "12.07", featureBit = FEATURE_BITS.esc_sensor},
    {label = "@i18n(app.modules.blackbox.log_governor)@", bit = 22, apiversiongte = "12.09", featureBit = FEATURE_BITS.governor}
}

local function copyTable(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do
        if type(v) == "table" then dst[k] = copyTable(v) else dst[k] = v end
    end
    return dst
end

local function hasBit(mask, bit)
    local b = tonumber(bit or 0) or 0
    return (((tonumber(mask or 0) or 0) & (1 << b)) ~= 0)
end

local function setBit(mask, bit, enable)
    local m = tonumber(mask or 0) or 0
    local b = tonumber(bit or 0) or 0
    local f = (1 << b)
    if enable then
        return (m | f)
    end
    return (m & (~f))
end

local function supportsField(def)
    if def.apiversiongte and not rfsuite.utils.apiVersionCompare(">=", def.apiversiongte) then
        return false
    end
    if def.featureBit and not hasBit(state.featureBitmap, def.featureBit) then
        return false
    end
    return true
end

local function markDirty()
    state.dirty = true
end

local function canEdit()
    local supported = tonumber(state.cfg.blackbox_supported or 0) == 1
    local device = tonumber(state.cfg.device or 0) or 0
    local mode = tonumber(state.cfg.mode or 0) or 0
    return state.loaded and supported and device ~= 0 and mode ~= 0
end

local function updateSaveEnabled()
    local save = app.formNavigationFields and app.formNavigationFields.save
    if save and save.enable then save:enable(canEdit() and state.dirty and not state.saving) end
end

local function updateFieldEnabled()
    local editable = canEdit()
    for _, w in pairs(state.form.toggles) do
        if w and w.enable then w:enable(editable) end
    end
    updateSaveEnabled()
end

local function renderLoading(message)
    form.clear()
    app.ui.fieldHeader("@i18n(app.modules.blackbox.name)@ / @i18n(app.modules.blackbox.menu_logging)@")
    local line = form.addLine("@i18n(app.modules.blackbox.status)@")
    form.addStaticText(line, nil, message or "@i18n(app.msg_loading)@")
end

local function renderForm()
    form.clear()
    app.ui.fieldHeader("@i18n(app.modules.blackbox.name)@ / @i18n(app.modules.blackbox.menu_logging)@")

    state.form.toggles = {}

    for i = 1, #FIELD_DEFS do
        local def = FIELD_DEFS[i]
        if supportsField(def) then
            local line = form.addLine(def.label)
            state.form.toggles[def.bit] = form.addBooleanField(line, nil, function()
                return hasBit(state.cfg.fields, def.bit)
            end, function(v)
                state.cfg.fields = setBit(state.cfg.fields, def.bit, v)
                markDirty()
                updateSaveEnabled()
            end)
        end
    end

    updateFieldEnabled()
    app.triggers.closeProgressLoader = true
end

local function syncSessionSnapshot()
    if not rfsuite.session then return end
    if not rfsuite.session.blackbox then rfsuite.session.blackbox = {} end
    rfsuite.session.blackbox.feature = {enabledFeatures = state.featureBitmap or 0}
    rfsuite.session.blackbox.config = copyTable(state.cfg)
    rfsuite.session.blackbox.ready = tonumber(state.cfg.blackbox_supported or 0) == 1
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
    local snapshot = rfsuite.session and rfsuite.session.blackbox or nil
    if not snapshot or not snapshot.config then return false end

    state.featureBitmap = tonumber(snapshot.feature and snapshot.feature.enabledFeatures or 0) or 0
    local parsed = snapshot.config
    state.cfg.blackbox_supported = tonumber(parsed.blackbox_supported or 0) or 0
    state.cfg.device = tonumber(parsed.device or 0) or 0
    state.cfg.mode = tonumber(parsed.mode or 0) or 0
    state.cfg.denom = tonumber(parsed.denom or 1) or 1
    state.cfg.fields = tonumber(parsed.fields or 0) or 0
    state.cfg.initialEraseFreeSpaceKiB = tonumber(parsed.initialEraseFreeSpaceKiB or 0) or 0
    state.cfg.rollingErase = tonumber(parsed.rollingErase or 0) or 0
    state.cfg.gracePeriod = tonumber(parsed.gracePeriod or 0) or 0
    return true
end

local function requestData(forceApiRead)
    if state.loading then return end

    state.loading = true
    state.loaded = false
    state.dirty = false

    renderLoading("@i18n(app.modules.blackbox.loading_logging)@")

    if not forceApiRead and loadFromSessionSnapshot() then
        state.loading = false
        state.loaded = true
        renderForm()
        return
    end

    state.pendingReads = 2

    local FAPI = tasks.msp.api.load("FEATURE_CONFIG")
    FAPI.setUUID("blackbox-logging-feature")
    FAPI.setCompleteHandler(function()
        local d = FAPI.data()
        local parsed = d and d.parsed or nil
        state.featureBitmap = tonumber(parsed and parsed.enabledFeatures or 0) or 0
        onReadDone()
    end)
    FAPI.setErrorHandler(function() onReadDone() end)
    FAPI.read()

    local BAPI = tasks.msp.api.load("BLACKBOX_CONFIG")
    BAPI.setUUID("blackbox-logging-config")
    BAPI.setCompleteHandler(function()
        local d = BAPI.data()
        local parsed = d and d.parsed or nil
        if parsed then
            state.cfg.blackbox_supported = tonumber(parsed.blackbox_supported or 0) or 0
            state.cfg.device = tonumber(parsed.device or 0) or 0
            state.cfg.mode = tonumber(parsed.mode or 0) or 0
            state.cfg.denom = tonumber(parsed.denom or 1) or 1
            state.cfg.fields = tonumber(parsed.fields or 0) or 0
            state.cfg.initialEraseFreeSpaceKiB = tonumber(parsed.initialEraseFreeSpaceKiB or 0) or 0
            state.cfg.rollingErase = tonumber(parsed.rollingErase or 0) or 0
            state.cfg.gracePeriod = tonumber(parsed.gracePeriod or 0) or 0
        end
        onReadDone()
    end)
    BAPI.setErrorHandler(function() onReadDone() end)
    BAPI.read()
end

local function openPage()
    requestData(false)
end

local function performSave()
    if not canEdit() or not state.dirty or state.saving then return end

    state.saving = true
    app.ui.progressDisplaySave("@i18n(app.modules.blackbox.saving)@")

    local API = tasks.msp.api.load("BLACKBOX_CONFIG")
    API.setUUID("blackbox-logging-write")
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

    API.setValue("device", state.cfg.device)
    API.setValue("mode", state.cfg.mode)
    API.setValue("denom", state.cfg.denom)
    API.setValue("fields", state.cfg.fields)
    API.setValue("initialEraseFreeSpaceKiB", state.cfg.initialEraseFreeSpaceKiB)
    API.setValue("rollingErase", state.cfg.rollingErase)
    API.setValue("gracePeriod", state.cfg.gracePeriod)
    API.write()
end

local function onSaveMenu()
    if not canEdit() or not state.dirty then return end

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
    updateFieldEnabled()
end

local function event(widget, category, value)
    if category == EVT_CLOSE and (value == 0 or value == 35) then
        app.ui.openPage({idx = app.lastIdx, title = "@i18n(app.modules.blackbox.name)@", script = "blackbox/blackbox.lua"})
        return true
    end
end

local function onNavMenu()
    app.ui.openPage({idx = app.lastIdx, title = "@i18n(app.modules.blackbox.name)@", script = "blackbox/blackbox.lua"})
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
