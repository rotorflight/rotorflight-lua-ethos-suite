--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local navHandlers = pageRuntime.createMenuHandlers({defaultSection = "hardware"})

local app = rfsuite.app
local tasks = rfsuite.tasks

local BEEPER_FIELDS = {
    { bit = 0, label = "Gyro calibrated" },
    { bit = 1, label = "RX lost" },
    { bit = 2, label = "RX lost landing" },
    { bit = 3, label = "Disarming" },
    { bit = 4, label = "Arming" },
    { bit = 5, label = "Arming GPS fix" },
    { bit = 6, label = "Battery critical low" },
    { bit = 7, label = "Battery low" },
    { bit = 8, label = "GPS status" },
    { bit = 9, label = "RX set" },
    { bit = 10, label = "ACC calibration" },
    { bit = 11, label = "ACC calibration fail" },
    { bit = 12, label = "Ready beep" },
    { bit = 14, label = "Disarm repeat" },
    { bit = 15, label = "Armed" },
    { bit = 16, label = "System init" },
    { bit = 17, label = "USB" },
    { bit = 18, label = "Blackbox erase" },
    { bit = 21, label = "Arming GPS no fix" }
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
local pageTitle = "Beepers / Configuration"

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
    app.ui.fieldHeader(pageTitle)
    local line = form.addLine("Status")
    form.addStaticText(line, nil, message or "Loading...")
end

local function renderForm()
    form.clear()
    app.ui.fieldHeader(pageTitle)

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

    renderLoading("Loading beeper configuration...")

    if not forceApiRead and loadFromSessionSnapshot() then
        state.loading = false
        state.loaded = true
        renderForm()
        return
    end

    state.pendingReads = 1

    local API = tasks.msp.api.loadPage("BEEPER_CONFIG")
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

local function openPage(opts)
    pageTitle = (opts and opts.title) or pageTitle
    requestData(false)
end

local function performSave()
    if not state.loaded or state.saving then return end
    if useDirtySave() and (not state.dirty) then return end

    state.saving = true
    app.ui.progressDisplaySave("Saving Beepers...")

    local API = tasks.msp.api.loadPage("BEEPER_CONFIG")
    API.setUUID("beepers-config-write")
    API.setErrorHandler(function()
        state.saving = false
        app.triggers.closeSave = true
        app.triggers.showSaveArmedWarning = true
        updateSaveEnabled()
    end)
    API.setCompleteHandler(function()
        local EAPI = tasks.msp.api.loadPage("EEPROM_WRITE")
        EAPI.setUUID("beepers.configuration.eeprom")
        EAPI.setCompleteHandler(function()
            state.saving = false
            state.dirty = false
            syncSessionSnapshot()
            app.triggers.closeSave = true
            updateSaveEnabled()
        end)
        EAPI.setErrorHandler(function()
            state.saving = false
            app.triggers.closeSave = true
            app.triggers.showSaveArmedWarning = true
            updateSaveEnabled()
        end)
        local ok = EAPI.write()
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
            label = "                OK                ",
            action = function()
                performSave()
                return true
            end
        },
        {
            label = "CANCEL",
            action = function() return true end
        }
    }

    form.openDialog({
        width = nil,
        title = "Save settings",
        message = "Save current page to flight controller?",
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

return {
    openPage = openPage,
    wakeup = wakeup,
    onSaveMenu = onSaveMenu,
    onReloadMenu = onReloadMenu,
    event = navHandlers.event,
    onNavMenu = navHandlers.onNavMenu,
    eepromWrite = true,
    reboot = false,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = true},
    API = {}
}
