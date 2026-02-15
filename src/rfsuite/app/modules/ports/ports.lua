--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local navHandlers = pageRuntime.createMenuHandlers({defaultSection = "hardware"})

local MSP_SET_SERIAL_CONFIG = 55
local MSP_EEPROM_WRITE = 250

local PORT_TYPE_DISABLED = 0
local PORT_TYPE_MSP = 1
local PORT_TYPE_GPS = 2
local PORT_TYPE_TELEM = 3
local PORT_TYPE_MAVLINK = 4
local PORT_TYPE_BLACKBOX = 5
local PORT_TYPE_CUSTOM = 6
local PORT_TYPE_AUTO = 7

local FUNCTION_MASK_RX_SERIAL = 64

local BAUD_RATES = {
    "AUTO", "9600", "19200", "38400", "57600", "115200", "230400", "250000",
    "400000", "460800", "500000", "921600", "1000000", "1500000", "2000000", "2470000"
}

local PORT_FUNCTIONS = {
    {id = 0, excl = 0, name = "@i18n(app.modules.ports.function_disabled)@", type = PORT_TYPE_DISABLED},
    {id = 1, excl = 1, name = "MSP", type = PORT_TYPE_MSP},
    {id = 2, excl = 2, name = "GPS", type = PORT_TYPE_GPS},
    {id = 64, excl = 64, name = "@i18n(app.modules.ports.function_rx_serial)@", type = PORT_TYPE_AUTO},
    {id = 1024, excl = 1024, name = "@i18n(app.modules.ports.function_esc_sensor)@", type = PORT_TYPE_AUTO},
    {id = 128, excl = 128, name = "@i18n(app.modules.ports.function_blackbox)@", type = PORT_TYPE_BLACKBOX},
    {id = 262144, excl = 262144, name = "@i18n(app.modules.ports.function_sbus_out)@", type = PORT_TYPE_AUTO, minApi = "12.07"},
    {id = 524288, excl = 524288, name = "@i18n(app.modules.ports.function_fbus_out)@", type = PORT_TYPE_AUTO, minApi = "12.09"},
    {id = 4, excl = 4668, name = "@i18n(app.modules.ports.function_telem_frsky)@", type = PORT_TYPE_TELEM},
    {id = 32, excl = 4668, name = "@i18n(app.modules.ports.function_telem_smartport)@", type = PORT_TYPE_TELEM},
    {id = 4096, excl = 4668, name = "@i18n(app.modules.ports.function_telem_ibus)@", type = PORT_TYPE_TELEM},
    {id = 8, excl = 4668, name = "@i18n(app.modules.ports.function_telem_hott)@", type = PORT_TYPE_TELEM},
    {id = 512, excl = 4668, name = "@i18n(app.modules.ports.function_telem_mavlink)@", type = PORT_TYPE_MAVLINK},
    {id = 16, excl = 4668, name = "@i18n(app.modules.ports.function_telem_ltm)@", type = PORT_TYPE_TELEM}
}

local BAUD_OPTIONS = {
    [PORT_TYPE_DISABLED] = {0},
    [PORT_TYPE_MSP] = {1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12},
    [PORT_TYPE_GPS] = {0, 1, 2, 3, 4, 5, 6, 9},
    [PORT_TYPE_TELEM] = {0},
    [PORT_TYPE_MAVLINK] = {0, 1, 2, 3, 4, 5, 6, 9},
    [PORT_TYPE_BLACKBOX] = {0, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15},
    [PORT_TYPE_CUSTOM] = {0},
    [PORT_TYPE_AUTO] = {0}
}

local UART_NAMES = {
    [0] = "UART1",
    [1] = "UART2",
    [2] = "UART3",
    [3] = "UART4",
    [4] = "UART5",
    [5] = "UART6",
    [6] = "UART7",
    [7] = "UART8",
    [8] = "UART9",
    [9] = "UART10",
    [20] = "USB VCP",
    [30] = "SOFTSERIAL1",
    [31] = "SOFTSERIAL2"
}

local state = {
    title = "@i18n(app.modules.ports.name)@",
    loading = false,
    loaded = false,
    saving = false,
    loadError = nil,
    saveError = nil,
    dirty = false,
    needsRender = false,
    rxSerialProvider = 0,
    portsOriginal = {},
    portsWorking = {}
}

local function queueDirect(message, uuid)
    if message and uuid and message.uuid == nil then message.uuid = uuid end
    return rfsuite.tasks.msp.mspQueue:add(message)
end

local function shallowCopy(tbl)
    local out = {}
    for k, v in pairs(tbl) do out[k] = v end
    return out
end

local function clonePorts(ports)
    local out = {}
    for i = 1, #ports do out[i] = shallowCopy(ports[i]) end
    return out
end

local function portLabel(identifier)
    local name = UART_NAMES[identifier]
    if name then return name end
    return "@i18n(app.modules.ports.port_prefix)@ " .. tostring(identifier)
end

local function setLoadError(reason)
    state.loading = false
    state.loaded = false
    state.loadError = reason or "@i18n(app.modules.ports.error_failed_load)@"
    state.needsRender = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function getPortFunctionById(functionMask)
    for i = 1, #PORT_FUNCTIONS do
        if PORT_FUNCTIONS[i].id == functionMask then return PORT_FUNCTIONS[i] end
    end
    return nil
end

local function getPortType(functionMask)
    local f = getPortFunctionById(functionMask)
    if f then return f.type end
    return PORT_TYPE_CUSTOM
end

local function getPortExcl(functionMask)
    local f = getPortFunctionById(functionMask)
    if f then return f.excl end
    return functionMask
end

local function functionAvailable(def)
    if def.minApi and not rfsuite.utils.apiVersionCompare(">=", def.minApi) then return false end
    if def.maxApi and not rfsuite.utils.apiVersionCompare("<=", def.maxApi) then return false end
    return true
end

local function getActiveBaudIndex(port)
    local ptype = getPortType(port.function_mask)
    if ptype == PORT_TYPE_MSP then return port.msp_baud_index end
    if ptype == PORT_TYPE_GPS then return port.gps_baud_index end
    if ptype == PORT_TYPE_BLACKBOX then return port.blackbox_baud_index end
    if ptype == PORT_TYPE_MAVLINK then return port.telem_baud_index end
    if ptype == PORT_TYPE_CUSTOM then return port.msp_baud_index end
    return 0
end

local function setActiveBaudIndex(port, baudIndex)
    local ptype = getPortType(port.function_mask)
    if ptype == PORT_TYPE_MSP then
        port.msp_baud_index = baudIndex
    elseif ptype == PORT_TYPE_GPS then
        port.gps_baud_index = baudIndex
    elseif ptype == PORT_TYPE_BLACKBOX then
        port.blackbox_baud_index = baudIndex
    elseif ptype == PORT_TYPE_MAVLINK then
        port.telem_baud_index = baudIndex
    elseif ptype == PORT_TYPE_CUSTOM then
        port.msp_baud_index = baudIndex
    end
end

local function buildBaudChoiceTable(port)
    local ptype = getPortType(port.function_mask)
    local allowed = BAUD_OPTIONS[ptype] or BAUD_OPTIONS[PORT_TYPE_AUTO]
    local current = getActiveBaudIndex(port)
    local present = {}
    local tableData = {}

    for i = 1, #allowed do
        local idx = allowed[i]
        if BAUD_RATES[idx + 1] then
            tableData[#tableData + 1] = {BAUD_RATES[idx + 1], idx}
            present[idx] = true
        end
    end

    if BAUD_RATES[current + 1] and not present[current] then
        tableData[#tableData + 1] = {BAUD_RATES[current + 1], current}
    end

    return tableData
end

local function buildFunctionChoiceTable(portIndex)
    local port = state.portsWorking[portIndex]
    if not port then return {} end

    local forbidden = 0
    for i = 1, #state.portsWorking do
        if i ~= portIndex then
            forbidden = forbidden | getPortExcl(state.portsWorking[i].function_mask)
        end
    end

    local tableData = {}
    local seen = {}

    for i = 1, #PORT_FUNCTIONS do
        local def = PORT_FUNCTIONS[i]
        if functionAvailable(def) then
            local allowed = ((def.id & forbidden) == 0)
            if allowed or def.id == port.function_mask then
                tableData[#tableData + 1] = {def.name, def.id}
                seen[def.id] = true
            end
        end
    end

    if not seen[port.function_mask] then
        tableData[#tableData + 1] = {"@i18n(app.modules.ports.function_custom)@ (" .. tostring(port.function_mask) .. ")", port.function_mask}
    end

    return tableData
end

local function applyReceiverGuardToWorkingCopy()
    for i = 1, #state.portsWorking do
        if state.portsWorking[i].receiver_locked then
            state.portsWorking[i] = shallowCopy(state.portsOriginal[i])
        end
    end
end

local function canSave()
    local pref = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.save_dirty_only
    local requireDirty = not (pref == false or pref == "false")
    return state.loaded and (not state.loading) and (not state.saving) and ((not requireDirty) or state.dirty)
end

local function updateSaveButtonState()
    local nav = rfsuite.app and rfsuite.app.formNavigationFields
    local saveField = nav and nav["save"] or nil
    if saveField and saveField.enable then saveField:enable(canSave()) end
end

local function parseSerialConfig(serialApi)
    local ports = {}
    local maxPorts = 12

    for i = 1, maxPorts do
        local identifier = serialApi.readValue("port_" .. i .. "_identifier")
        if identifier == nil then break end
        if identifier ~= 20 then

            local functionMask = serialApi.readValue("port_" .. i .. "_function_mask") or 0
            local port = {
                identifier = identifier,
                function_mask = functionMask,
                msp_baud_index = serialApi.readValue("port_" .. i .. "_msp_baud_index") or 0,
                gps_baud_index = serialApi.readValue("port_" .. i .. "_gps_baud_index") or 0,
                telem_baud_index = serialApi.readValue("port_" .. i .. "_telem_baud_index") or 0,
                blackbox_baud_index = serialApi.readValue("port_" .. i .. "_blackbox_baud_index") or 0,
                receiver_locked = (functionMask & FUNCTION_MASK_RX_SERIAL) ~= 0
            }
            ports[#ports + 1] = port
        end
    end

    state.portsOriginal = clonePorts(ports)
    state.portsWorking = clonePorts(ports)
end

local function readRxConfig(done)
    local rxApi = rfsuite.tasks.msp.api.load("RX_CONFIG")
    if not rxApi then
        state.rxSerialProvider = 0
        done()
        return
    end

    rxApi.setCompleteHandler(function()
        state.rxSerialProvider = tonumber(rxApi.readValue("serialrx_provider") or 0)
        done()
    end)

    rxApi.setErrorHandler(function()
        state.rxSerialProvider = 0
        done()
    end)

    rxApi.read()
end

local function startLoad()
    state.loading = true
    state.loaded = false
    state.saving = false
    state.loadError = nil
    state.saveError = nil
    state.dirty = false

    rfsuite.app.ui.progressDisplay("@i18n(app.modules.ports.name)@", "@i18n(app.modules.ports.progress_loading)@", 0.08)

    local serialApi = rfsuite.tasks.msp.api.load("SERIAL_CONFIG")
    if not serialApi then
        setLoadError("@i18n(app.modules.ports.error_serial_api_unavailable)@")
        return
    end

    serialApi.setCompleteHandler(function()
        parseSerialConfig(serialApi)
        readRxConfig(function()
            state.loading = false
            state.loaded = true
            state.needsRender = true
            rfsuite.app.triggers.closeProgressLoader = true
        end)
    end)

    serialApi.setErrorHandler(function()
        setLoadError("@i18n(app.modules.ports.error_read_serial_ports)@")
    end)

    serialApi.read()
end

local function u32ToBytes(value)
    local v = value or 0
    return v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF
end

local function queueSetSerialPort(port, done, failed)
    local b1, b2, b3, b4 = u32ToBytes(port.function_mask)
    local payload = {
        port.identifier,
        b1, b2, b3, b4,
        port.msp_baud_index,
        port.gps_baud_index,
        port.telem_baud_index,
        port.blackbox_baud_index
    }

    local message = {
        command = MSP_SET_SERIAL_CONFIG,
        payload = payload,
        processReply = function() if done then done() end end,
        errorHandler = function() if failed then failed("@i18n(app.modules.ports.error_serial_write_failed_for)@ " .. portLabel(port.identifier)) end end,
        simulatorResponse = {}
    }

    local ok, reason = queueDirect(message, "ports.set." .. tostring(port.identifier))
    if not ok and failed then failed(reason or "queue_rejected") end
end

local function queueEepromWrite(done, failed)
    local message = {
        command = MSP_EEPROM_WRITE,
        processReply = function() if done then done() end end,
        errorHandler = function() if failed then failed("@i18n(app.modules.ports.error_eeprom_write_failed)@") end end,
        simulatorResponse = {}
    }
    local ok, reason = queueDirect(message, "ports.eeprom")
    if not ok and failed then failed(reason or "queue_rejected") end
end

local function savePorts()
    state.saving = true
    state.saveError = nil

    -- Hard guard: never write modified settings for ports that currently carry RX_SERIAL.
    applyReceiverGuardToWorkingCopy()

    rfsuite.app.ui.progressDisplay("@i18n(app.modules.ports.name)@", "@i18n(app.modules.ports.progress_saving)@", 0.08)

    local index = 1
    local total = #state.portsWorking

    local function failed(reason)
        state.saving = false
        state.saveError = reason or "@i18n(app.modules.ports.error_save_failed)@"
        state.needsRender = true
        rfsuite.app.triggers.closeProgressLoader = true
    end

    local function writeNext()
        if index > total then
            queueEepromWrite(function()
                state.saving = false
                state.dirty = false
                state.saveError = nil
                state.portsOriginal = clonePorts(state.portsWorking)
                state.needsRender = true
                rfsuite.app.triggers.closeProgressLoader = true

                -- Ports changes require reboot to ensure serial service state is rebuilt.
                rfsuite.app.ui.rebootFc()
            end, failed)
            return
        end

        queueSetSerialPort(state.portsWorking[index], function()
            index = index + 1
            writeNext()
        end, failed)
    end

    writeNext()
end

local function render()
    local app = rfsuite.app
    form.clear()
    app.ui.fieldHeader(state.title)

    if state.loading then
        form.addLine("@i18n(app.modules.ports.loading)@")
        return
    end

    if state.loadError then
        form.addLine("@i18n(app.modules.ports.load_error_prefix)@ " .. tostring(state.loadError))
        return
    end

    if #state.portsWorking == 0 then
        form.addLine("@i18n(app.modules.ports.no_ports_reported)@")
        return
    end

    if state.saveError then
        form.addLine("@i18n(app.modules.ports.save_error_prefix)@ " .. tostring(state.saveError))
    end

    local width = app.lcdWidth
    local h = app.radio.navbuttonHeight
    local y = app.radio.linePaddingTop
    local rightPadding = 8
    local gap = 6

    local wBaud = math.floor(width * 0.28)
    local wFunc = math.floor(width * 0.42)

    local xBaud = width - rightPadding - wBaud
    local xFunc = xBaud - gap - wFunc

    for i = 1, #state.portsWorking do
        local port = state.portsWorking[i]
        local lineTitle = portLabel(port.identifier)
        if port.receiver_locked then lineTitle = lineTitle .. " @i18n(app.modules.ports.rx_tag)@" end

        local line = form.addLine(lineTitle)

        local functionChoices = buildFunctionChoiceTable(i)
        local functionField = form.addChoiceField(
            line,
            {x = xFunc, y = y, w = wFunc, h = h},
            functionChoices,
            function() return port.function_mask end,
            function(value)
                if port.receiver_locked then return end
                if value ~= port.function_mask then
                    port.function_mask = value
                    local baudChoices = buildBaudChoiceTable(port)
                    local currentBaud = getActiveBaudIndex(port)
                    local currentStillAllowed = false
                    for b = 1, #baudChoices do
                        if baudChoices[b][2] == currentBaud then
                            currentStillAllowed = true
                            break
                        end
                    end
                    if not currentStillAllowed and #baudChoices > 0 then
                        setActiveBaudIndex(port, baudChoices[1][2])
                    end
                    state.dirty = true
                    state.needsRender = true
                end
            end
        )

        local baudChoices = buildBaudChoiceTable(port)
        local baudField = form.addChoiceField(
            line,
            {x = xBaud, y = y, w = wBaud, h = h},
            baudChoices,
            function() return getActiveBaudIndex(port) end,
            function(value)
                if port.receiver_locked then return end
                if value ~= getActiveBaudIndex(port) then
                    setActiveBaudIndex(port, value)
                    state.dirty = true
                end
            end
        )

        if functionField and functionField.enable then functionField:enable(not port.receiver_locked) end
        if baudField and baudField.enable then baudField:enable(not port.receiver_locked) end
    end

end

local function wakeup()
    if state.needsRender then
        render()
        state.needsRender = false
    end
    updateSaveButtonState()
end

local function onSaveMenu()
    if state.loading or state.saving or not state.loaded then return end

    local pref = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.save_dirty_only
    local requireDirty = not (pref == false or pref == "false")
    if requireDirty and not state.dirty then return end

    if rfsuite.preferences.general.save_confirm == false or rfsuite.preferences.general.save_confirm == "false" then
        savePorts()
        return
    end

    local buttons = {
        {label = "@i18n(app.btn_ok_long)@", action = function() savePorts(); return true end},
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
    startLoad()
end

local function openPage(opts)
    state.title = opts.title or "@i18n(app.modules.ports.name)@"

    rfsuite.app.lastIdx = opts.idx
    rfsuite.app.lastTitle = state.title
    rfsuite.app.lastScript = opts.script
    rfsuite.session.lastPage = opts.script

    startLoad()
    state.needsRender = true
end

return {
    title = "@i18n(app.modules.ports.name)@",
    openPage = openPage,
    wakeup = wakeup,
    onSaveMenu = onSaveMenu,
    onReloadMenu = onReloadMenu,
    onNavMenu = navHandlers.onNavMenu,
    eepromWrite = false,
    reboot = true,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    API = {},
    canSave = canSave
}
