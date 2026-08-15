-- Ports page. Loaded on demand from Setup -> Ports.
--
-- This page intentionally owns its own save chain instead of using
-- app/page_runtime.lua's one-write-per-source path: MSP_SET_SERIAL_CONFIG
-- writes a single port record, and the original suite writes one packet
-- per reported port before EEPROM_WRITE + reboot.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local header = requireModule("app/header.lua")
local closeKey = requireModule("app/close_key.lua")
local memstats = requireModule("lib/memstats.lua")
local progressDialog = requireModule("app/progress_dialog.lua")
local serialConfig = requireModule("lib/msp_serial_config.lua")
local rxConfig = requireModule("lib/msp_rx_config.lua")
local eeprom = requireModule("lib/msp_eeprom.lua")
local reboot = requireModule("lib/msp_reboot.lua")

local PAGE_TITLE = "@i18n(app.modules.ports.name)@"
local MSG_SAVE_TITLE = "@i18n(app.msg_save_settings)@"
local MSG_SAVE_BODY = "@i18n(app.msg_save_current_page)@"
local MSG_RELOAD_TITLE = "@i18n(reload)@"
local MSG_RELOAD_BODY = "@i18n(app.msg_reload_settings)@"
local MSG_LOADING_TITLE = "@i18n(app.msg_loading)@"
local MSG_LOADING_BODY = "@i18n(app.msg_loading_from_fbl)@"
local MSG_SAVING_TITLE = "@i18n(app.msg_saving)@"
local MSG_SAVING_BODY = "@i18n(app.msg_saving_settings)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"

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
  "400000", "460800", "500000", "921600", "1000000", "1500000", "2000000", "2470000",
}

local PORT_FUNCTIONS = {
  {id = 0, excl = 0, name = "@i18n(app.modules.ports.function_disabled)@", type = PORT_TYPE_DISABLED},
  {id = 1, excl = 1, name = "MSP", type = PORT_TYPE_MSP},
  {id = 2, excl = 2, name = "GPS", type = PORT_TYPE_GPS},
  {id = 64, excl = 64, name = "@i18n(app.modules.ports.function_rx_serial)@", type = PORT_TYPE_AUTO},
  {id = 1024, excl = 1024, name = "@i18n(app.modules.ports.function_esc_sensor)@", type = PORT_TYPE_AUTO},
  {id = 128, excl = 128, name = "@i18n(app.modules.ports.function_blackbox)@", type = PORT_TYPE_BLACKBOX},
  {id = 262144, excl = 262144, name = "@i18n(app.modules.ports.function_sbus_out)@", type = PORT_TYPE_AUTO},
  {id = 524288, excl = 524288, name = "@i18n(app.modules.ports.function_fbus_out)@", type = PORT_TYPE_AUTO},
  {id = 1048576, excl = 1048576, name = "@i18n(app.modules.ports.function_sport_input)@", type = PORT_TYPE_AUTO},
  {id = 4, excl = 4668, name = "@i18n(app.modules.ports.function_telem_frsky)@", type = PORT_TYPE_TELEM},
  {id = 32, excl = 4668, name = "@i18n(app.modules.ports.function_telem_smartport)@", type = PORT_TYPE_TELEM},
  {id = 4096, excl = 4668, name = "@i18n(app.modules.ports.function_telem_ibus)@", type = PORT_TYPE_TELEM},
  {id = 8, excl = 4668, name = "@i18n(app.modules.ports.function_telem_hott)@", type = PORT_TYPE_TELEM},
  {id = 512, excl = 4668, name = "@i18n(app.modules.ports.function_telem_mavlink)@", type = PORT_TYPE_MAVLINK},
  {id = 16, excl = 4668, name = "@i18n(app.modules.ports.function_telem_ltm)@", type = PORT_TYPE_TELEM},
}

local BAUD_OPTIONS = {
  [PORT_TYPE_DISABLED] = {0},
  [PORT_TYPE_MSP] = {1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12},
  [PORT_TYPE_GPS] = {0, 1, 2, 3, 4, 5, 6, 9},
  [PORT_TYPE_TELEM] = {0},
  [PORT_TYPE_MAVLINK] = {0, 1, 2, 3, 4, 5, 6, 9},
  [PORT_TYPE_BLACKBOX] = {0, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15},
  [PORT_TYPE_CUSTOM] = {0},
  [PORT_TYPE_AUTO] = {0},
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
  [31] = "SOFTSERIAL2",
}

local function maskHasAny(mask, bits)
  if bits == 0 then return false end
  local bit = 1
  while bits > 0 do
    if bits % 2 == 1 and math.floor((mask or 0) / bit) % 2 == 1 then
      return true
    end
    bits = math.floor(bits / 2)
    bit = bit * 2
  end
  return false
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
  return UART_NAMES[identifier] or ("@i18n(app.modules.ports.port_prefix)@ " .. tostring(identifier))
end

local function getPortFunctionById(functionMask)
  for i = 1, #PORT_FUNCTIONS do
    if PORT_FUNCTIONS[i].id == functionMask then return PORT_FUNCTIONS[i] end
  end
  return nil
end

local function getPortType(functionMask)
  local f = getPortFunctionById(functionMask)
  return f and f.type or PORT_TYPE_CUSTOM
end

local function getPortExcl(functionMask)
  local f = getPortFunctionById(functionMask)
  return f and f.excl or functionMask
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
  local allowed = BAUD_OPTIONS[getPortType(port.function_mask)] or BAUD_OPTIONS[PORT_TYPE_AUTO]
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

local function functionAllowedForPort(def, portIndex, ports)
  if def.id == 0 then return true end
  for i = 1, #ports do
    if i ~= portIndex and maskHasAny(getPortExcl(ports[i].function_mask), def.id) then
      return false
    end
  end
  return true
end

local function buildFunctionChoiceTable(portIndex, ports)
  local port = ports[portIndex]
  if not port then return {} end

  local tableData = {}
  local seen = {}
  for i = 1, #PORT_FUNCTIONS do
    local def = PORT_FUNCTIONS[i]
    if functionAllowedForPort(def, portIndex, ports) or def.id == port.function_mask then
      tableData[#tableData + 1] = {def.name, def.id}
      seen[def.id] = true
    end
  end

  if not seen[port.function_mask] then
    tableData[#tableData + 1] = {
      "@i18n(app.modules.ports.function_custom)@ (" .. tostring(port.function_mask) .. ")",
      port.function_mask,
    }
  end

  return tableData
end

local function openProgress(title, message)
  return progressDialog.open({
    title = title,
    message = message,
  })
end

local function open(opts)
  local disposed = false
  local loaded = false
  local busy = false
  local dirty = false
  local loadError = nil
  local saveError = nil
  local saveNotice = nil
  local needsRender = false
  local isArmed = nil
  local activeDialog = nil
  local headerHandle = nil
  local fields = {}
  local sessionHandler = nil
  local pendingSaveConfirm = false
  local portsOriginal = {}
  local portsWorking = {}
  local rxSerialProvider = 0

  memstats.print("ports open")

  local function closeDialog(focusFn)
    if activeDialog then
      activeDialog:value(100)
      activeDialog:close()
      activeDialog = nil
    end
    if focusFn then
      focusFn()
    elseif headerHandle then
      headerHandle.focusMenu()
    end
  end

  local function setBusy(value)
    busy = value == true
    if headerHandle then
      headerHandle.setSaveEnabled(loaded and dirty and not busy)
      headerHandle.setReloadEnabled(not busy)
    end
    for _, fieldInfo in pairs(fields) do
      local field = fieldInfo.field
      if field and field.enable then
        field:enable(loaded and not busy and not fieldInfo.locked)
      end
    end
  end

  local function applyReceiverGuard()
    for i = 1, #portsWorking do
      if portsWorking[i].receiver_locked then
        portsWorking[i] = shallowCopy(portsOriginal[i])
      end
    end
  end

  local function dispose()
    if disposed then return end
    disposed = true
    if opts.setEventHandler then opts.setEventHandler(nil) end
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    if sessionHandler then bus.unsubscribe("session.update", sessionHandler) end
    closeDialog()
    for _, fieldInfo in pairs(fields) do
      local field = fieldInfo and fieldInfo.field
      if field and field.enable then pcall(function() field:enable(false) end) end
    end
    portsOriginal = {}
    portsWorking = {}
    fields = {}
    package.loaded["rfsuite.lib.msp_serial_config"] = nil
    package.loaded["rfsuite.lib.msp_rx_config"] = nil
    memstats.print("ports disposed")
  end

  local function goBack()
    memstats.print("ports exit")
    dispose()
    if opts.onBack then opts.onBack() end
    collectgarbage("collect")
    memstats.print("ports after back")
  end

  local function startLoad(focusFn)
    if disposed then return end
    loaded = false
    dirty = false
    loadError = nil
    saveError = nil
    saveNotice = nil
    setBusy(true)
    activeDialog = openProgress(MSG_LOADING_TITLE, MSG_LOADING_BODY)

    bus.publish("msp.request", serialConfig.buildReadMessage(function(data)
      if disposed then return end
      local filtered = {}
      local ports = data and data.ports or {}
      for i = 1, #ports do
        local port = shallowCopy(ports[i])
        if port.identifier ~= 20 then
          port.receiver_locked = maskHasAny(port.function_mask, FUNCTION_MASK_RX_SERIAL)
          filtered[#filtered + 1] = port
        end
      end
      portsOriginal = clonePorts(filtered)
      portsWorking = clonePorts(filtered)

      bus.publish("msp.request", rxConfig.buildReadMessage(function(rxData)
        if disposed then return end
        rxSerialProvider = rxData and rxData.serialrx_provider or 0
        loaded = true
        closeDialog(focusFn)
        setBusy(false)
        needsRender = true
      end, function()
        if disposed then return end
        rxSerialProvider = 0
        loaded = true
        closeDialog(focusFn)
        setBusy(false)
        needsRender = true
      end))
    end, function()
      if disposed then return end
      loadError = "@i18n(app.modules.ports.error_read_serial_ports)@"
      closeDialog(focusFn)
      setBusy(false)
      needsRender = true
    end))
  end

  local function openSaveDialog()
    if not loaded or not dirty or busy then return end
    form.openDialog({
      title = MSG_SAVE_TITLE,
      message = MSG_SAVE_BODY,
      buttons = {
        {label = BTN_OK, action = function()
          if not disposed then
            applyReceiverGuard()
            setBusy(true)
            activeDialog = openProgress(MSG_SAVING_TITLE, MSG_SAVING_BODY)
            saveError = nil
            saveNotice = nil

            local index = 1
            local function fail()
              if disposed then return end
              loaded = true
              saveError = "@i18n(app.modules.ports.error_save_failed)@"
              closeDialog(headerHandle and headerHandle.focusSave)
              setBusy(false)
              needsRender = true
            end
            -- EEPROM_WRITE is rejected by the FC while armed -- not a real
            -- failure, the per-port MSP_SET_SERIAL_CONFIG writes above
            -- already landed and the FC commits them for real on disarm.
            -- Mirrors app/page_runtime.lua's own performSave()/showSaveArmed().
            local function failEeprom()
              if disposed then return end
              if isArmed == true then
                loaded = true
                dirty = false
                portsOriginal = clonePorts(portsWorking)
                saveNotice = "@i18n(app.modules.ports.save_armed)@"
                closeDialog(headerHandle and headerHandle.focusSave)
                setBusy(false)
                needsRender = true
                return
              end
              fail()
            end
            local function writeNext()
              if disposed then return end
              if index > #portsWorking then
                bus.publish("msp.request", eeprom.buildWriteMessage(function()
                  if disposed then return end
                  dirty = false
                  portsOriginal = clonePorts(portsWorking)
                  closeDialog(headerHandle and headerHandle.focusSave)
                  setBusy(false)
                  if isArmed ~= true then
                    bus.publish("msp.request", reboot.buildWriteMessage())
                  end
                end, failEeprom))
                return
              end
              local port = portsWorking[index]
              bus.publish("msp.request", serialConfig.buildWriteMessage(port, function()
                if disposed then return end
                index = index + 1
                writeNext()
              end, fail))
            end
            writeNext()
          end
          return true
        end},
        {label = BTN_CANCEL, action = function() return true end},
      },
      wakeup = function() end,
      paint = function() end,
    })
  end

  local function render()
    if disposed then return end

    form.clear()
    fields = {}
    headerHandle = header.build(PAGE_TITLE, {
      onBack = goBack,
      onSave = function()
        openSaveDialog()
      end,
      onReload = function()
        if busy then return end
        form.openDialog({
          title = MSG_RELOAD_TITLE,
          message = MSG_RELOAD_BODY,
          buttons = {
            {label = BTN_OK, action = function()
              startLoad(headerHandle and headerHandle.focusReload)
              return true
            end},
            {label = BTN_CANCEL, action = function() return true end},
          },
          wakeup = function() end,
          paint = function() end,
        })
      end,
    })

    if loadError then
      form.addLine("@i18n(app.modules.ports.load_error_prefix)@ " .. tostring(loadError))
      setBusy(false)
      return
    end
    if not loaded then
      form.addLine("@i18n(app.modules.ports.loading)@")
      setBusy(true)
      return
    end
    if saveError then
      form.addLine("@i18n(app.modules.ports.save_error_prefix)@ " .. tostring(saveError))
    end
    if saveNotice then
      form.addLine(tostring(saveNotice))
    end
    if #portsWorking == 0 then
      form.addLine("@i18n(app.modules.ports.no_ports_reported)@")
      setBusy(false)
      return
    end

    local width = 480
    if lcd and lcd.getWindowSize then
      width = lcd.getWindowSize()
    end
    local rightPadding = 8
    local gap = 6
    local wBaud = math.floor(width * 0.28)
    local wFunc = math.floor(width * 0.42)
    local xBaud = width - rightPadding - wBaud
    local xFunc = xBaud - gap - wFunc

    for i = 1, #portsWorking do
      local port = portsWorking[i]
      local title = portLabel(port.identifier)
      if port.receiver_locked then
        title = title .. " @i18n(app.modules.ports.rx_tag)@"
      end
      local line = form.addLine(title)
      local rowSlot = form.getFieldSlots(line, {0})[1]
      local functionField = form.addChoiceField(line, {x = xFunc, y = rowSlot.y, w = wFunc, h = rowSlot.h},
        buildFunctionChoiceTable(i, portsWorking),
        function() return port.function_mask end,
        function(value)
          if port.receiver_locked or value == port.function_mask then return end
          port.function_mask = value
          local baudChoices = buildBaudChoiceTable(port)
          local current = getActiveBaudIndex(port)
          local found = false
          for b = 1, #baudChoices do
            if baudChoices[b][2] == current then found = true end
          end
          if not found and #baudChoices > 0 then setActiveBaudIndex(port, baudChoices[1][2]) end
          dirty = true
          needsRender = true
        end)
      local baudField = form.addChoiceField(line, {x = xBaud, y = rowSlot.y, w = wBaud, h = rowSlot.h},
        buildBaudChoiceTable(port),
        function() return getActiveBaudIndex(port) end,
        function(value)
          if port.receiver_locked or value == getActiveBaudIndex(port) then return end
          setActiveBaudIndex(port, value)
          dirty = true
          setBusy(false)
        end)
      fields[#fields + 1] = {field = functionField, locked = port.receiver_locked}
      fields[#fields + 1] = {field = baudField, locked = port.receiver_locked}
      if functionField and functionField.enable then
        functionField:enable(not port.receiver_locked and loaded and not busy)
      end
      if baudField and baudField.enable then
        baudField:enable(not port.receiver_locked and loaded and not busy)
      end
    end

    setBusy(busy)
  end

  sessionHandler = function(update)
    if disposed then return end
    isArmed = update and update.isArmed
  end
  bus.subscribe("session.update", sessionHandler)

  if opts.setEventHandler then
    opts.setEventHandler(function(category, value)
      if value == KEY_ENTER_LONG then
        system.killEvents(KEY_ENTER_BREAK)
        if loaded and dirty and not busy then
          pendingSaveConfirm = true
        end
        return true
      end
      if closeKey.shouldHandleClose(category, value) then
        goBack()
        return true
      end
      return false
    end)
  end

  if opts.setWakeupHandler then
    opts.setWakeupHandler(function()
      if disposed then return end
      if needsRender then
        needsRender = false
        render()
      end
      if pendingSaveConfirm then
        pendingSaveConfirm = false
        openSaveDialog()
      end
      if headerHandle then
        headerHandle.setSaveEnabled(loaded and dirty and not busy)
        headerHandle.setReloadEnabled(not busy)
      end
    end)
  end

  if opts.setCleanupHandler then
    opts.setCleanupHandler(dispose)
  end

  render()
  memstats.print("ports fields built")
  startLoad()
end

return {open = open}
