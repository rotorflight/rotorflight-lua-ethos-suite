--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local navHandlers = pageRuntime.createMenuHandlers({defaultSection = "hardware"})

local FEATURE_BIT_GPS = 7
local FEATURE_BIT_LED_STRIP = 16
local FEATURE_BIT_CMS = 19

local PID_LOOP_DENOMS = {1, 2, 3, 4}

local state = {
    title = "@i18n(app.modules.configuration.name)@",
    loading = false,
    loaded = false,
    saving = false,
    dirty = false,
    needsRender = false,
    loadError = nil,
    saveError = nil,
    pendingReads = 0,
    currentName = "",
    currentPidLoop = 1,
    currentFeatures = 0,
    gyroDeltaUs = 250,
    pidBaseHz = 0
}

local function bitIsSet(value, bit)
    local mask = 1 << bit
    return (value & mask) ~= 0
end

local function setBit(value, bit, enabled)
    local mask = 1 << bit
    if enabled then
        return value | mask
    end
    return value & (~mask)
end

local function toBool(v)
    return v == true or v == 1
end

local function markDirty()
    if not state.dirty then
        state.dirty = true
    end
end

local function canSave()
    local pref = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.save_dirty_only
    local requireDirty = not (pref == false or pref == "false")
    if state.loading or state.saving or not state.loaded then return false end
    if requireDirty then return state.dirty end
    return true
end

local function updateSaveButtonState()
    local nav = rfsuite.app and rfsuite.app.formNavigationFields
    local saveField = nav and nav.save or nil
    if saveField and saveField.enable then saveField:enable(canSave()) end
end

local function getPidLoopChoices(currentValue)
    local rawGyroHz = (state.pidBaseHz > 0 and state.pidBaseHz) or (1000000 / (state.gyroDeltaUs > 0 and state.gyroDeltaUs or 250))
    local gyroHz = math.floor((rawGyroHz / 1000) + 0.5) * 1000
    local function formatPidLoopKhz(valueKhz)
        local rounded = math.floor((valueKhz * 100) + 0.5) / 100
        local text = string.format("%.2f", rounded):gsub("0+$", ""):gsub("%.$", "")
        if not text:find("%.") and rounded >= 2 then
            text = text .. ".0"
        end
        return string.format("%s kHz", text)
    end
    local tableData = {}
    local present = {}
    for i = 1, #PID_LOOP_DENOMS do
        local denom = PID_LOOP_DENOMS[i]
        local pidKhz = (gyroHz / denom) / 1000
        tableData[#tableData + 1] = {formatPidLoopKhz(pidKhz), denom}
        present[denom] = true
    end
    if currentValue and not present[currentValue] then
        local pidKhz = (gyroHz / currentValue) / 1000
        tableData[#tableData + 1] = {formatPidLoopKhz(pidKhz), currentValue}
    end
    return tableData
end

local function render()
    local app = rfsuite.app
    form.clear()
    app.ui.fieldHeader(state.title)

    if state.loading then
        form.addLine("@i18n(app.modules.configuration.loading)@")
        return
    end

    if state.loadError then
        form.addLine("@i18n(app.modules.configuration.load_error_prefix)@ " .. tostring(state.loadError))
    end

    if state.saveError then
        form.addLine("@i18n(app.modules.configuration.save_error_prefix)@ " .. tostring(state.saveError))
    end

    local lineY = app.radio.linePaddingTop
    local fieldH = app.radio.navbuttonHeight
    local rightPad = 8
    local width = app.lcdWidth
    local textW = math.floor(width * 0.46)
    local boolW = math.floor(width * 0.24)
    local textX = width - rightPad - textW
    local boolX = width - rightPad - boolW

    local lineName = form.addLine("@i18n(app.modules.configuration.craft_name)@")
    form.addTextField(
        lineName,
        {x = textX, y = lineY, w = textW, h = fieldH},
        function() return state.currentName end,
        function(newValue)
            local val = newValue or ""
            if val ~= state.currentName then
                state.currentName = val
                markDirty()
            end
        end
    )

    local linePid = form.addLine("@i18n(app.modules.configuration.pid_loop_speed)@")
    form.addChoiceField(
        linePid,
        {x = textX, y = lineY, w = textW, h = fieldH},
        getPidLoopChoices(state.currentPidLoop),
        function() return state.currentPidLoop end,
        function(newValue)
            if newValue ~= state.currentPidLoop then
                state.currentPidLoop = newValue
                markDirty()
                state.needsRender = true
            end
        end
    )

    local lineGps = form.addLine("@i18n(app.modules.configuration.feature_gps)@")
    form.addBooleanField(
        lineGps,
        {x = boolX, y = lineY, w = boolW, h = fieldH},
        function() return bitIsSet(state.currentFeatures, FEATURE_BIT_GPS) end,
        function(newValue)
            local oldValue = state.currentFeatures
            state.currentFeatures = setBit(state.currentFeatures, FEATURE_BIT_GPS, toBool(newValue))
            if state.currentFeatures ~= oldValue then markDirty() end
        end
    )

    local lineLed = form.addLine("@i18n(app.modules.configuration.feature_led_strip)@")
    form.addBooleanField(
        lineLed,
        {x = boolX, y = lineY, w = boolW, h = fieldH},
        function() return bitIsSet(state.currentFeatures, FEATURE_BIT_LED_STRIP) end,
        function(newValue)
            local oldValue = state.currentFeatures
            state.currentFeatures = setBit(state.currentFeatures, FEATURE_BIT_LED_STRIP, toBool(newValue))
            if state.currentFeatures ~= oldValue then markDirty() end
        end
    )

    local lineCms = form.addLine("@i18n(app.modules.configuration.feature_cms)@")
    form.addBooleanField(
        lineCms,
        {x = boolX, y = lineY, w = boolW, h = fieldH},
        function() return bitIsSet(state.currentFeatures, FEATURE_BIT_CMS) end,
        function(newValue)
            local oldValue = state.currentFeatures
            state.currentFeatures = setBit(state.currentFeatures, FEATURE_BIT_CMS, toBool(newValue))
            if state.currentFeatures ~= oldValue then markDirty() end
        end
    )
end

local function onReadDone()
    state.pendingReads = state.pendingReads - 1
    if state.pendingReads > 0 then return end
    state.loading = false
    state.loaded = true
    state.needsRender = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function startLoad()
    if state.loading or state.saving then return end

    state.loading = true
    state.loaded = false
    state.pendingReads = 4
    state.loadError = nil
    state.saveError = nil
    state.dirty = false
    state.currentName = ""
    state.currentPidLoop = 1
    state.currentFeatures = 0
    state.gyroDeltaUs = 250
    state.pidBaseHz = 0
    state.needsRender = true

    rfsuite.app.ui.progressDisplay("@i18n(app.modules.configuration.name)@", "@i18n(app.modules.configuration.progress_loading)@", 0.08)

    local nameApi = rfsuite.tasks.msp.api.load("NAME")
    if not nameApi then
        state.loadError = "@i18n(app.modules.configuration.error_name_api_unavailable)@"
        onReadDone()
    else
        nameApi.setCompleteHandler(function()
            local parsed = nameApi.data() and nameApi.data().parsed or nil
            state.currentName = parsed and tostring(parsed.name or "") or ""
            onReadDone()
        end)
        nameApi.setErrorHandler(function()
            state.loadError = state.loadError or "@i18n(app.modules.configuration.error_name_read_failed)@"
            onReadDone()
        end)
        nameApi.read()
    end

    local advApi = rfsuite.tasks.msp.api.load("ADVANCED_CONFIG")
    if not advApi then
        state.loadError = state.loadError or "@i18n(app.modules.configuration.error_advanced_api_unavailable)@"
        onReadDone()
    else
        advApi.setCompleteHandler(function()
            local parsed = advApi.data() and advApi.data().parsed or nil
            state.currentPidLoop = tonumber(parsed and parsed.pid_process_denom or 1) or 1
            onReadDone()
        end)
        advApi.setErrorHandler(function()
            state.loadError = state.loadError or "@i18n(app.modules.configuration.error_advanced_read_failed)@"
            onReadDone()
        end)
        advApi.read()
    end

    local featureApi = rfsuite.tasks.msp.api.load("FEATURE_CONFIG")
    if not featureApi then
        state.loadError = state.loadError or "@i18n(app.modules.configuration.error_feature_api_unavailable)@"
        onReadDone()
    else
        featureApi.setCompleteHandler(function()
            local parsed = featureApi.data() and featureApi.data().parsed or nil
            state.currentFeatures = tonumber(parsed and parsed.enabledFeatures or 0) or 0
            onReadDone()
        end)
        featureApi.setErrorHandler(function()
            state.loadError = state.loadError or "@i18n(app.modules.configuration.error_feature_read_failed)@"
            onReadDone()
        end)
        featureApi.read()
    end

    local boardApi = rfsuite.tasks.msp.api.load("BOARD_INFO")
    if not boardApi then
        onReadDone()
    else
        boardApi.setCompleteHandler(function()
            local parsed = boardApi.data() and boardApi.data().parsed or nil
            local sampleRateHz = tonumber(parsed and parsed.gyro_sample_rate_hz or 0) or 0
            if sampleRateHz > 0 then state.pidBaseHz = sampleRateHz end
            onReadDone()
        end)
        boardApi.setErrorHandler(function() onReadDone() end)
        boardApi.read()
    end

    state.pendingReads = state.pendingReads + 1
    local statusApi = rfsuite.tasks.msp.api.load("STATUS")
    if not statusApi then
        onReadDone()
    else
        statusApi.setCompleteHandler(function()
            local parsed = statusApi.data() and statusApi.data().parsed or nil
            local delta = tonumber(parsed and parsed.task_delta_time_gyro or 0) or 0
            if delta > 0 then state.gyroDeltaUs = delta end
            onReadDone()
        end)
        statusApi.setErrorHandler(function() onReadDone() end)
        statusApi.read()
    end
end

local function saveDone()
    state.saving = false
    state.dirty = false
    state.saveError = nil
    state.needsRender = true
    rfsuite.app.triggers.closeProgressLoader = true
    rfsuite.app.ui.rebootFc()
end

local function saveFailed(msg)
    state.saving = false
    state.saveError = msg or "@i18n(app.modules.configuration.error_save_failed)@"
    state.needsRender = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function performSave()
    if not canSave() then return end
    state.saving = true
    state.saveError = nil
    rfsuite.app.ui.progressDisplaySave("@i18n(app.modules.configuration.progress_saving)@")

    local nameApi = rfsuite.tasks.msp.api.load("NAME")
    if not nameApi then
        saveFailed("@i18n(app.modules.configuration.error_name_api_unavailable)@")
        return
    end

    local advApi = rfsuite.tasks.msp.api.load("ADVANCED_CONFIG")
    if not advApi then
        saveFailed("@i18n(app.modules.configuration.error_advanced_api_unavailable)@")
        return
    end

    local featureApi = rfsuite.tasks.msp.api.load("FEATURE_CONFIG")
    if not featureApi then
        saveFailed("@i18n(app.modules.configuration.error_feature_api_unavailable)@")
        return
    end

    local eepromApi = rfsuite.tasks.msp.api.load("EEPROM_WRITE")
    if not eepromApi then
        saveFailed("@i18n(app.modules.configuration.error_eeprom_api_unavailable)@")
        return
    end

    eepromApi.setCompleteHandler(function() saveDone() end)
    eepromApi.setErrorHandler(function() saveFailed("@i18n(app.modules.configuration.error_eeprom_write_failed)@") end)

    featureApi.setCompleteHandler(function()
        eepromApi.write()
    end)
    featureApi.setErrorHandler(function()
        saveFailed("@i18n(app.modules.configuration.error_feature_write_failed)@")
    end)

    advApi.setCompleteHandler(function()
        featureApi.setValue("enabledFeatures", state.currentFeatures)
        featureApi.write()
    end)
    advApi.setErrorHandler(function()
        saveFailed("@i18n(app.modules.configuration.error_advanced_write_failed)@")
    end)

    nameApi.setCompleteHandler(function()
        local gyroCompat = 1
        local advRead = advApi.data() and advApi.data().parsed or nil
        if advRead and advRead.gyro_sync_denom_compat then
            gyroCompat = tonumber(advRead.gyro_sync_denom_compat) or 1
        end
        advApi.setValue("gyro_sync_denom_compat", gyroCompat)
        advApi.setValue("pid_process_denom", state.currentPidLoop)
        advApi.write()
    end)
    nameApi.setErrorHandler(function()
        saveFailed("@i18n(app.modules.configuration.error_name_write_failed)@")
    end)

    nameApi.setValue("name", state.currentName or "")
    nameApi.write()
end

local function onSaveMenu()
    if not canSave() then return end

    if rfsuite.preferences.general.save_confirm == false or rfsuite.preferences.general.save_confirm == "false" then
        performSave()
        return
    end

    local buttons = {
        {label = "@i18n(app.btn_ok_long)@", action = function() performSave(); return true end},
        {label = "@i18n(app.btn_cancel)@", action = function() return true end}
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
    if state.saving then return end
    rfsuite.app.triggers.triggerReloadFull = true
end

local function openPage(opts)
    state.title = opts.title or "@i18n(app.modules.configuration.name)@"
    rfsuite.app.lastIdx = opts.idx
    rfsuite.app.lastTitle = state.title
    rfsuite.app.lastScript = opts.script
    rfsuite.session.lastPage = opts.script
    startLoad()
end

local function wakeup()
    if state.needsRender then
        render()
        state.needsRender = false
    end
    updateSaveButtonState()
end

return {
    title = "@i18n(app.modules.configuration.name)@",
    openPage = openPage,
    wakeup = wakeup,
    onSaveMenu = onSaveMenu,
    onReloadMenu = onReloadMenu,
    onNavMenu = navHandlers.onNavMenu,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    eepromWrite = false,
    reboot = true,
    canSave = canSave,
    API = {}
}
