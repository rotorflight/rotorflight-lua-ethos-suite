--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local app = rfsuite.app
local tasks = rfsuite.tasks

local state = {
    loading = false,
    loaded = false,
    loadStartedAt = 0,
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
    media = {
        dataflashSupported = true,
        sdcardSupported = true
    },
    form = {}
}

local function onoffTable()
    return {
        {"@i18n(app.modules.blackbox.off)@", 0},
        {"@i18n(app.modules.blackbox.on)@", 1}
    }
end

local function modeTable()
    return {
        {"@i18n(app.modules.blackbox.mode_off)@", 0},
        {"@i18n(app.modules.blackbox.mode_normal)@", 1},
        {"@i18n(app.modules.blackbox.mode_armed)@", 2},
        {"@i18n(app.modules.blackbox.mode_switch)@", 3}
    }
end

local function formatRateHz(denom)
    local d = tonumber(denom or 1) or 1
    if d < 1 then d = 1 end
    local hz = 1000 / d
    if math.floor(hz) == hz then
        return string.format("%dHz", hz)
    end
    return string.format("%.1fHz", hz)
end

local function denomTable(currentDenom)
    local presets = {1, 2, 4, 10, 20, 40, 100}
    local tbl = {}
    local seen = false
    local current = tonumber(currentDenom or 1) or 1
    if current < 1 then current = 1 end

    for i = 1, #presets do
        local d = presets[i]
        if d == current then seen = true end
        tbl[#tbl + 1] = {formatRateHz(d), d}
    end

    if not seen then
        tbl[#tbl + 1] = {string.format("@i18n(app.modules.blackbox.rate_custom)@", formatRateHz(current), current), current}
    end

    return tbl
end

local function deviceTable()
    local t = {{"@i18n(app.modules.blackbox.device_disabled)@", 0}}
    if state.media.dataflashSupported then t[#t + 1] = {"@i18n(app.modules.blackbox.device_onboard_flash)@", 1} end
    if state.media.sdcardSupported then t[#t + 1] = {"@i18n(app.modules.blackbox.device_sdcard)@", 2} end
    t[#t + 1] = {"@i18n(app.modules.blackbox.device_serial_port)@", 3}
    return t
end

local function markDirty()
    state.dirty = true
end

local function canEdit()
    return state.loaded and tonumber(state.cfg.blackbox_supported or 0) == 1
end

local function useDirtySave()
    local pref = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.save_dirty_only
    return not (pref == false or pref == "false")
end

local function updateSaveEnabled()
    local save = app.formNavigationFields and app.formNavigationFields.save
    if save and save.enable then
        local allow = canEdit() and (not state.saving) and ((not useDirtySave()) or state.dirty)
        save:enable(allow)
    end
end

local function updateVisibility()
    local edit = canEdit()
    local device = tonumber(state.cfg.device or 0) or 0
    local mode = tonumber(state.cfg.mode or 0) or 0

    if state.form.denom and state.form.denom.enable then state.form.denom:enable(edit) end
    if state.form.device and state.form.device.enable then state.form.device:enable(edit) end
    if state.form.mode and state.form.mode.enable then state.form.mode:enable(edit) end

    if state.form.initialErase and state.form.initialErase.enable then
        state.form.initialErase:enable(edit and device == 1 and rfsuite.utils.apiVersionCompare(">=", "12.08"))
    end

    if state.form.rollingErase and state.form.rollingErase.enable then
        state.form.rollingErase:enable(edit and device == 1 and rfsuite.utils.apiVersionCompare(">=", "12.08"))
    end

    if state.form.gracePeriod and state.form.gracePeriod.enable then
        state.form.gracePeriod:enable(edit and device ~= 0 and (mode == 1 or mode == 2) and rfsuite.utils.apiVersionCompare(">=", "12.08"))
    end

    updateSaveEnabled()
end

local function renderLoading(message)
    form.clear()
    app.ui.fieldHeader("@i18n(app.modules.blackbox.name)@ / @i18n(app.modules.blackbox.menu_configuration)@")
    local line = form.addLine("@i18n(app.modules.blackbox.status)@")
    form.addStaticText(line, nil, message or "@i18n(app.msg_loading)@")
end

local function renderForm()
    form.clear()
    app.ui.fieldHeader("@i18n(app.modules.blackbox.name)@ / @i18n(app.modules.blackbox.menu_configuration)@")

    local line = form.addLine("@i18n(app.modules.blackbox.device)@")
    state.form.device = form.addChoiceField(line, nil, deviceTable(), function() return state.cfg.device end, function(v)
        state.cfg.device = v
        markDirty()
        updateVisibility()
    end)

    line = form.addLine("@i18n(app.modules.blackbox.logging_mode)@")
    state.form.mode = form.addChoiceField(line, nil, modeTable(), function() return state.cfg.mode end, function(v)
        state.cfg.mode = v
        markDirty()
        updateVisibility()
    end)

    line = form.addLine("@i18n(app.modules.blackbox.logging_rate)@")
    state.form.denom = form.addChoiceField(line, nil, denomTable(state.cfg.denom), function() return state.cfg.denom end, function(v)
        state.cfg.denom = v
        markDirty()
        updateSaveEnabled()
    end)

    line = form.addLine("@i18n(app.modules.blackbox.disarm_grace_period)@")
    state.form.gracePeriod = form.addNumberField(line, nil, 0, 255, function() return state.cfg.gracePeriod end, function(v)
        state.cfg.gracePeriod = v
        markDirty()
        updateSaveEnabled()
    end)
    if state.form.gracePeriod and state.form.gracePeriod.suffix then state.form.gracePeriod:suffix("s") end

    line = form.addLine("@i18n(app.modules.blackbox.initial_erase)@")
    state.form.initialErase = form.addNumberField(line, nil, 0, 65535, function() return state.cfg.initialEraseFreeSpaceKiB end, function(v)
        state.cfg.initialEraseFreeSpaceKiB = v
        markDirty()
        updateSaveEnabled()
    end)
    if state.form.initialErase and state.form.initialErase.suffix then state.form.initialErase:suffix("KiB") end

    line = form.addLine("@i18n(app.modules.blackbox.rolling_erase)@")
    state.form.rollingErase = form.addBooleanField(line, nil, function()
        return tonumber(state.cfg.rollingErase or 0) == 1
    end, function(v)
        state.cfg.rollingErase = v and 1 or 0
        markDirty()
        updateSaveEnabled()
    end)

    updateVisibility()
    app.triggers.closeProgressLoader = true
end

local function onReadDone()
    state.pendingReads = state.pendingReads - 1
    if state.pendingReads <= 0 then
        if rfsuite.session then
            if not rfsuite.session.blackbox then rfsuite.session.blackbox = {} end
            rfsuite.session.blackbox.feature = {enabledFeatures = state.featureBitmap or 0}
            rfsuite.session.blackbox.config = {
                blackbox_supported = state.cfg.blackbox_supported,
                device = state.cfg.device,
                mode = state.cfg.mode,
                denom = state.cfg.denom,
                fields = state.cfg.fields,
                initialEraseFreeSpaceKiB = state.cfg.initialEraseFreeSpaceKiB,
                rollingErase = state.cfg.rollingErase,
                gracePeriod = state.cfg.gracePeriod
            }
            rfsuite.session.blackbox.ready = tonumber(state.cfg.blackbox_supported or 0) == 1
        end
        state.loading = false
        state.loaded = true
        renderForm()
    end
end

local function loadFromSessionSnapshot()
    local snapshot = rfsuite.session and rfsuite.session.blackbox or nil
    if not snapshot or not snapshot.config then return false end

    local parsed = snapshot.config
    state.featureBitmap = tonumber(snapshot.feature and snapshot.feature.enabledFeatures or 0) or 0
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
    state.loadStartedAt = os.clock()
    state.dirty = false
    state.pendingReads = 0

    renderLoading("@i18n(app.modules.blackbox.loading_feature_config)@")

    local seededFromSession = false
    if not forceApiRead then
        seededFromSession = loadFromSessionSnapshot()
    end

    if seededFromSession then
        state.loading = false
        state.loaded = true
        renderForm()
        return
    end

    state.pendingReads = 2

    local FAPI = tasks.msp.api.load("FEATURE_CONFIG")
    FAPI.setUUID("blackbox-config-feature")
    FAPI.setCompleteHandler(function()
        local d = FAPI.data()
        local parsed = d and d.parsed or nil
        state.featureBitmap = (parsed and parsed.enabledFeatures) or 0
        onReadDone()
    end)
    FAPI.setErrorHandler(function() onReadDone() end)
    FAPI.read()

    local BAPI = tasks.msp.api.load("BLACKBOX_CONFIG")
    BAPI.setUUID("blackbox-config-main")
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
    if not canEdit() or state.saving then return end
    if useDirtySave() and (not state.dirty) then return end

    state.saving = true
    app.ui.progressDisplaySave("@i18n(app.modules.blackbox.saving)@")

    local API = tasks.msp.api.load("BLACKBOX_CONFIG")
    API.setUUID("blackbox-config-write")
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
                if rfsuite.session and rfsuite.session.blackbox then
                    rfsuite.session.blackbox.config = {
                        blackbox_supported = state.cfg.blackbox_supported,
                        device = state.cfg.device,
                        mode = state.cfg.mode,
                        denom = state.cfg.denom,
                        fields = state.cfg.fields,
                        initialEraseFreeSpaceKiB = state.cfg.initialEraseFreeSpaceKiB,
                        rollingErase = state.cfg.rollingErase,
                        gracePeriod = state.cfg.gracePeriod
                    }
                end
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
    if not canEdit() then return end
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
    if state.loading and state.loadStartedAt > 0 and (os.clock() - state.loadStartedAt) > 2.5 then
        state.loading = false
        state.loaded = true
        renderForm()
    end
    updateVisibility()
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
