-- Setup Wizard step: ESC telemetry, in eight screens. Opened by app/pages/setup_wizard.lua after the
-- Connect servos gate, so the servos are plugged in. The first screen is the blades card. The step is
-- a restart point: a restart owed from the steps before it, or the port change made on screen 1, is
-- done with Save and restart, and the step reopens on the wiring screen, where the port is live.
--
-- Screen 1, as the Configurator's ESC telemetry step on the radio:
--   * Used or Not used: the ESC sensor feature (bit 27) on or off.
--   * Protocol: the ESC's telemetry protocol (MSP_ESC_SENSOR_CONFIG), by API version.
--   * Port: when used, a free UART takes the ESC sensor function (bit 1024, MSP_SET_SERIAL_CONFIG).
--     Not used clears it again. The port change applies after the restart.
--
-- Screen 2, the wiring, as the Configurator's EscWiringDetectWizard on the radio:
--   * Detect: the flight controller tries the half-duplex and pin-swap combinations on the
--     telemetry port (MSP2_ESC_SENSOR_TRIAL, lib/msp_esc_sensor_trial.lua). The step polls it
--     while it runs, and stops after the trial's timeout.
--   * Found: half duplex and pin swap are written to the ESC sensor config. They take effect
--     after a restart, which is Save and restart on this step.
--   * Battery voltage and ESC temperature from the telemetry, read live (lib/live_sensors.lua)
--     over the session's transport (sport or crsf). They show "--" until the port is live.
--
-- Screens 3 to 7, the power settings the EdgeTX suite's helicopter wizard shows on the same step
-- (app/setup_wizard_power.lua):
--   3 voltage source, 4 current source: the source, and its live reading. The ESC's own
--     telemetry is read live; ADC and F.BUS read the flight controller (MSP_ANALOG, lib/msp_analog.lua).
--   5 battery: the active profile (shown only) and its cell count.
--   6 capacity: the six battery capacities, Battery 1 to 3 on the left of each row and 4 to 6 on the right.
--   7 SmartFuel: the firmware's SmartFuel mode, with a note when it needs a voltage source.
--
-- Everything is written as it is set and kept for Discard. Leaving the step cancels a running trial.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")
local power = requireModule("app/setup_wizard_power.lua")
local bus = requireModule("lib/bus.lua")
local live = requireModule("lib/live_sensors.lua")
local analog = requireModule("lib/msp_analog.lua")
local trialConfig = requireModule("lib/msp_esc_sensor_trial.lua")
local escSensor = requireModule("lib/msp_esc_sensor_config.lua")
local featureConfig = requireModule("lib/msp_feature_config.lua")
local serialConfig = requireModule("lib/msp_serial_config.lua")
local motorConfig = requireModule("lib/msp_motor_config.lua")
local boardInfo = requireModule("lib/msp_board_info.lua")
local portLabels = requireModule("lib/port_labels.lua")

local OWNED = {}

local ESC_SENSOR_BIT = 27
local ESC_SENSOR_FUNCTION = 1024
-- Identifiers 0 to 9 are UART1 to UART10 (app/pages/ports.lua's UART_NAMES).
local UART_MAX = 9
local NO_PORT = -1
local CASTLE = motorConfig.CASTLE_PROTOCOL
local MIN_VOLTAGE = 1
local POLL_INTERVAL = 0.2     -- seconds between polls while the flight controller tries
local TRIAL_TIMEOUT = 6       -- seconds, as the Configurator's detection gives up
local ANALOG_INTERVAL = 0.5   -- seconds between MSP_ANALOG reads on a flight controller source
local ANALOG_MAX_AGE = 1.0    -- a reading older than this is shown as "--"

local BLADES, SETUP, WIRING, VOLTAGE, CURRENT, BATTERY, CAPS, SMARTFUEL = 1, 2, 3, 4, 5, 6, 7, 8
local SCREEN_COUNT = 8
-- Rows of the wiring screen: status, detect, then the readings. Rows of a source screen: the
-- source, then its reading.
local STATUS_ROW, VOLTAGE_ROW, TEMP_ROW = 1, 3, 4
local READING_ROW = 2

local T = {
  title = "@i18n(app.modules.setup_wizard.tel_title)@",
  blades = "@i18n(app.modules.setup_wizard.sen_blades_removed)@",
  bladesText = "@i18n(app.modules.setup_wizard.mot_prepare_blades)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  wiringTitle = "@i18n(app.modules.setup_wizard.wir_title)@",
  telemetry = "@i18n(app.modules.setup_wizard.tel_row_used)@",
  used = "@i18n(app.modules.setup_wizard.tel_used)@",
  notUsed = "@i18n(app.modules.setup_wizard.tel_not_used)@",
  protocol = "@i18n(app.modules.setup_wizard.tel_protocol)@",
  port = "@i18n(app.modules.setup_wizard.tel_port)@",
  noPort = "@i18n(app.modules.setup_wizard.tel_no_port)@",
  restart = "@i18n(app.modules.setup_wizard.swa_restart)@",
  wiringRestart = "@i18n(app.modules.setup_wizard.wir_restart)@",
  wiring = "@i18n(app.modules.setup_wizard.wir_row_wiring)@",
  detect = "@i18n(app.modules.setup_wizard.wir_detect)@",
  stop = "@i18n(app.modules.setup_wizard.wir_stop)@",
  status = "@i18n(app.modules.setup_wizard.wir_status)@",
  trying = "@i18n(app.modules.setup_wizard.wir_trying_fmt)@",
  idle = "@i18n(app.modules.setup_wizard.wir_idle)@",
  found = "@i18n(app.modules.setup_wizard.wir_found)@",
  notFound = "@i18n(app.modules.setup_wizard.wir_not_found)@",
  rejected = "@i18n(app.modules.setup_wizard.wir_rejected)@",
  timeout = "@i18n(app.modules.setup_wizard.wir_timeout)@",
  unsupported = "@i18n(app.modules.setup_wizard.wir_unsupported)@",
  stopped = "@i18n(app.modules.setup_wizard.wir_stopped)@",
  voltage = "@i18n(app.modules.setup_wizard.tel_voltage)@",
  temperature = "@i18n(app.modules.setup_wizard.tel_temperature)@",
  needRestart = "@i18n(app.modules.setup_wizard.wir_need_restart)@",
  needProtocol = "@i18n(app.modules.setup_wizard.wir_need_protocol)@",
  needPort = "@i18n(app.modules.setup_wizard.wir_need_port)@",
  castle = "@i18n(app.modules.setup_wizard.wir_castle)@",
  voltageSource = "@i18n(app.modules.power.voltage_meter_source)@",
  currentSource = "@i18n(app.modules.power.current_meter_source)@",
  sensorVoltage = "@i18n(telemetry.sensor_voltage)@",
  sensorCurrent = "@i18n(telemetry.sensor_current)@",
  srcBody = "@i18n(app.modules.setup_wizard.pwr_src_body)@",
  battery = "@i18n(app.modules.power.battery_name)@",
  selected = "@i18n(app.modules.power.selected)@",
  cellCount = "@i18n(app.modules.power.cell_count)@",
  batBody = "@i18n(app.modules.setup_wizard.pwr_bat_body)@",
  capacity = "@i18n(app.modules.power.capacity)@",
  capBody = "@i18n(app.modules.setup_wizard.pwr_cap_body)@",
  smartFuel = "@i18n(app.modules.power.smartfuel_name)@",
  smartFuelRow = "@i18n(sensors.smartfuel)@",
  sfBody = "@i18n(app.modules.setup_wizard.pwr_sf_body)@",
  sfVoltage = "@i18n(app.modules.setup_wizard.pwr_sf_voltage)@",
  sfMissing = "@i18n(app.modules.setup_wizard.pwr_sf_missing)@",
  loading = "@i18n(app.msg_loading)@",
  loadFailed = "@i18n(app.msg_load_failed_body)@",
}

-- The session's transport, from the bus (one subscription per wizard session).
local transports = package.loaded["rfsuite.setup_wizard.esctelemetry"] or setmetatable({}, {__mode = "k"})
package.loaded["rfsuite.setup_wizard.esctelemetry"] = transports
-- The wiring result of the session. It outlives the step instance, so it still shows after the
-- restart that Found asks for (the step reopens on screen 2).
local outcomes = package.loaded["rfsuite.setup_wizard.esctelemetry.outcomes"] or setmetatable({}, {__mode = "k"})
package.loaded["rfsuite.setup_wizard.esctelemetry.outcomes"] = outcomes

local function hasBit(value, bit)
  return math.floor((value or 0) / (2 ^ bit)) % 2 == 1
end

local function withBit(value, bit, on)
  value = value or 0
  local has = hasBit(value, bit)
  if on and not has then return value + 2 ^ bit end
  if not on and has then return value - 2 ^ bit end
  return value
end

local function copy(t)
  local r = {}
  for k, v in pairs(t) do r[k] = v end
  return r
end

-- The names the Ports page uses (app/pages/ports.lua's UART_NAMES).
local PORT_NAMES = {[20] = "USB VCP", [30] = "SOFTSERIAL1", [31] = "SOFTSERIAL2"}
local USB_VCP = 20
-- The receiver function (ports.lua's FUNCTION_MASK_RX_SERIAL): such a port is locked on the Ports page.
local FUNCTION_MASK_RX_SERIAL = 64

-- The name a port has on this board: the silkscreen name of the board (lib/port_labels.lua, as the
-- Ports page shows it) with the UART name beside it, or the UART name alone.
local function portName(port, board)
  local uart = port.identifier <= UART_MAX and ("UART" .. (port.identifier + 1))
    or PORT_NAMES[port.identifier] or ("Port " .. tostring(port.identifier))
  local silk = board and portLabels.lookup(board.boardDesign, port.identifier, board.boardName)
  if silk then return silk .. " (" .. uart .. ")" end
  return uart
end

local function voltageText(v)
  if v == nil or v < MIN_VOLTAGE then return "--" end
  return string.format("%.1f V", v)
end

local function tempText(t)
  if t == nil then return "--" end
  return string.format("%d °C", math.floor(t + 0.5))
end

local function sourceVoltageText(v)
  if v == nil then return "--" end
  return string.format("%.2f V", v)
end

local function sourceCurrentText(c)
  if c == nil then return "--" end
  return string.format("%.2f A", c)
end

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  local picture = art.image("motor-esc", 220, 160)
  -- The blades card comes first on a fresh visit; a restart reopens on the wiring screen.
  local screen = wiz.takeResume() == WIRING and WIRING or BLADES
  local left = false       -- set when the step is left
  local answers = {blades = false}   -- the safety answer, kept across rebuilds
  local pw = power.new(wiz)

  -- The transport the link runs on, from the session. The subscription lives while the step does.
  if not transports[wiz] then
    local state = {}
    state.handler = function(snapshot)
      state.transport = snapshot and snapshot.mspTransport
    end
    transports[wiz] = state
    bus.subscribe("session.update", state.handler)
  end

  local loaded, failed = false, false
  local features = 0       -- the enabled feature bits
  local esc = nil          -- the ESC sensor config
  local ports = {}         -- the serial ports
  local motor = nil        -- the motor config (the protocol decides whether there is a wiring)
  local trial = nil        -- {startedAt, nextPoll, inFlight, combo} while the flight controller tries
  local shownStatus = nil
  local shownVoltage, shownTemp = nil, nil
  local shownReading = nil
  local analogData, analogAt, analogNext = nil, nil, 0

  local protocolValues = {}
  for _, c in ipairs(escSensor.choicesFor(wiz.apiAtLeast(10) and 10 or 0)) do
    protocolValues[#protocolValues + 1] = {text = c[1], value = c[2]}
  end

  local function used() return hasBit(features, ESC_SENSOR_BIT) end

  -- The port that has the ESC sensor function, if any.
  local function escPort()
    for _, p in ipairs(ports) do
      if (p.function_mask or 0) & ESC_SENSOR_FUNCTION ~= 0 then return p end
    end
    return nil
  end

  local function hasEscPort()
    return escPort() ~= nil
  end

  local function freePort()
    for _, p in ipairs(ports) do
      if (p.function_mask or 0) == 0 and p.identifier <= UART_MAX then return p end
    end
    return nil
  end

  wiz.fetch({
    feature = function(ok, err) return featureConfig.buildReadMessage(ok, err) end,
    esc = function(ok, err) return escSensor.buildReadMessage(ok, err) end,
    serial = function(ok, err) return serialConfig.buildReadMessage(ok, err) end,
    motor = function(ok, err) return motorConfig.buildReadMessage(ok, err) end,
  }, function(results, failedAny)
    features = results.feature and results.feature.enabledFeatures or 0
    esc = results.esc
    ports = results.serial and results.serial.ports or {}
    motor = results.motor
    failed = failedAny or esc == nil
    loaded = true
    wiz.rebuild()
  end)

  -- The power settings load on their own: a failed read does not fail the telemetry step.
  pw.load(function() wiz.rebuild() end)

  -- The board's name for its ports, read on its own too: without it the ports show their UART names.
  local board = nil
  wiz.fetch({
    board = function(ok, err) return boardInfo.buildReadMessage(ok, err) end,
  }, function(results)
    board = results.board
    wiz.rebuild()
  end)

  -- Writes: each reads the value it changes first, so the others are kept.
  local function writeFeature(on)
    wiz.send(featureConfig.buildReadMessage(function(f)
      wiz.send(featureConfig.buildWriteMessage({enabledFeatures = withBit(f.enabledFeatures, ESC_SENSOR_BIT, on)}))
    end))
  end

  local function writeEsc(data)
    wiz.send(escSensor.buildWriteMessage(data))
  end

  local function writePort(port, mask)
    port.function_mask = mask
    wiz.send(serialConfig.buildWriteMessage(port))
  end

  -- The values as they are, for Discard.
  local function snapshot()
    local ps = {}
    for i, p in ipairs(ports) do ps[i] = copy(p) end
    return {on = used(), esc = esc and copy(esc) or nil, ports = ps}
  end

  local function restore(o)
    writeFeature(o.on)
    if o.esc then
      esc = copy(o.esc)
      writeEsc(copy(esc))
    end
    for _, p in ipairs(o.ports) do
      local now = nil
      for _, q in ipairs(ports) do if q.identifier == p.identifier then now = q end end
      if now and now.function_mask ~= p.function_mask then writePort(copy(now), p.function_mask) end
    end
    wiz.requestReboot()
    wiz.rebuild()
  end

  local function setUsed(on)
    if on == used() then return end
    wiz.change("esc_telemetry", snapshot(), restore)
    outcomes[wiz] = nil
    features = withBit(features, ESC_SENSOR_BIT, on)
    writeFeature(on)
    if on then
      if not escPort() then
        local free = freePort()
        if free then
          writePort(free, ESC_SENSOR_FUNCTION)
          free.function_mask = ESC_SENSOR_FUNCTION
        end
      end
    else
      local old = escPort()
      if old then writePort(old, 0) end
    end
    wiz.requestReboot()
    wiz.rebuild()
  end

  -- The ports the Ports page offers for the ESC sensor: every serial port but the USB VCP, and not
  -- one that receives (a receiver port keeps its function). Choosing one replaces its function, as
  -- on the Ports page, and the port the telemetry had before is freed.
  local function portValues()
    local values = {}
    local current = escPort()
    if not current then values[#values + 1] = {text = T.noPort, value = NO_PORT} end
    for _, p in ipairs(ports) do
      -- Only free ports (and the one already in use) are offered, so an occupied
      -- port (S.Port, GPS, MSP, SBUS out, ...) is never replaced silently.
      local free = (p.function_mask or 0) == 0
      if p.identifier ~= USB_VCP and (free or p == current) then
        values[#values + 1] = {text = portName(p, board), value = p.identifier}
      end
    end
    return values
  end

  local function setPort(identifier)
    if not identifier or identifier == NO_PORT then return end
    local target = nil
    for _, p in ipairs(ports) do if p.identifier == identifier then target = p end end
    local old = escPort()
    if not target or (old and old.identifier == identifier) then return end
    wiz.change("esc_telemetry", snapshot(), restore)
    outcomes[wiz] = nil
    if old then writePort(old, 0) end
    writePort(target, ESC_SENSOR_FUNCTION)
    wiz.requestReboot()
    wiz.rebuild()
  end

  local function setProtocol(v)
    if not esc or v == esc.protocol then return end
    wiz.change("esc_telemetry", snapshot(), restore)
    outcomes[wiz] = nil
    esc.protocol = v
    writeEsc(copy(esc))
    wiz.rebuild()
  end

  -- Wiring: the detection. ---------------------------------------------------------------

  local function readValues()
    local transport = transports[wiz] and transports[wiz].transport
    if not transport then return nil, nil end
    return live.value(transport, "voltage"), live.value(transport, "temp_esc")
  end

  -- The ESC's own live reading of a signal, or nil.
  local function escLive(signal)
    local transport = transports[wiz] and transports[wiz].transport
    if not transport then return nil end
    return live.value(transport, signal)
  end

  -- Why detection cannot run now, as the text to show; nil when it can.
  local function blocker()
    if wiz.rebootPending() then return T.needRestart end
    if not esc or (esc.protocol or 0) == 0 then return T.needProtocol end
    if not hasEscPort() then return T.needPort end
    if motor and motor.motor_pwm_protocol == CASTLE then return T.castle end
    return nil
  end

  local function statusText()
    if trial then return string.format(T.trying, trial.combo + 1, trialConfig.COMBINATIONS) end
    return outcomes[wiz] or T.idle
  end

  -- Ends the run: a cancel makes the flight controller restore its wiring, and the outcome
  -- is shown. Nothing happens when no run is going.
  local function stopWith(text)
    if not trial then return end
    trial = nil
    wiz.send(trialConfig.buildCancelMessage())
    outcomes[wiz] = text
    wiz.rebuild()
  end

  local function found(halfDuplex, pinSwap)
    trial = nil
    wiz.change("esc_wiring", snapshot(), restore)
    esc.half_duplex = halfDuplex
    esc.pin_swap = pinSwap
    wiz.send(escSensor.buildWriteMessage(copy(esc)))
    wiz.requestReboot()
    outcomes[wiz] = T.found
    wiz.rebuild()
  end

  local function fail()
    stopWith(T.unsupported)
  end

  local function handle(d)
    if not trial then return end   -- a late reply, after the run was stopped
    trial.inFlight = false
    local S = trialConfig.STATE
    if d.state == S.RUNNING then
      trial.combo = d.combo_index
      return
    end
    if d.state == S.SUCCESS then
      return found(d.half_duplex, d.pin_swap)
    end
    trial = nil
    wiz.send(trialConfig.buildCancelMessage())
    outcomes[wiz] = d.state == S.FAILED and T.notFound or T.rejected
    wiz.rebuild()
  end

  local function start()
    if trial or blocker() then return end
    outcomes[wiz] = nil
    trial = {startedAt = os.clock(), nextPoll = 0, inFlight = true, combo = 0}
    wiz.send(trialConfig.buildStartMessage(handle, fail))
    wiz.rebuild()
  end

  local function stop()
    stopWith(T.stopped)
  end

  -- Navigation ---------------------------------------------------------------------------

  local function go(to)
    if to ~= WIRING and trial then stopWith(T.stopped) end
    screen = to
    wiz.rebuild()
  end

  -- Moves on to a screen. Changes made on this screen are saved first (Save and continue), as the
  -- step saves them on its last screen; the move waits for the write, and does not run once the
  -- step has been left.
  local function moveTo(to)
    if not wiz.hasPending() then return go(to) end
    wiz.saveThen(function()
      if not left then go(to) end
    end)
  end

  -- The way forward from a screen. A restart owed (the port change on screen 2, a wiring
  -- found on screen 3, or one from before) is done first, and the step reopens on the wiring
  -- screen. Otherwise the next screen follows; after the last one the step is finished.
  local function forwardFrom(from)
    if wiz.rebootPending() then
      wiz.setResume(WIRING)
      wiz.finishStep()
      return
    end
    if from < SCREEN_COUNT then
      moveTo(from + 1)
      return
    end
    wiz.finishStep()
  end

  local function backTo(index)
    return function() go(index - 1) end
  end

  -- Power settings: the readings --------------------------------------------------------

  -- The live reading of a source: the ESC's telemetry, or the flight controller's analog
  -- reading for ADC and F.BUS, shown only while it is fresh.
  local function sourceReadingText(key, signal)
    local source = pw.source(key)
    if source == power.SOURCE_NONE or not pw.loaded then return "--" end
    if source == power.SOURCE_ESC then
      local v = escLive(signal)
      if signal == "voltage" then return sourceVoltageText(v) end
      return sourceCurrentText(v)
    end
    local age = analogAt and os.clock() - analogAt
    if not analogData or not age or age > ANALOG_MAX_AGE then return "--" end
    if signal == "voltage" then return sourceVoltageText(analogData.voltage / 100) end
    return sourceCurrentText(analogData.current / 100)
  end

  local function pollAnalog(now)
    if now < analogNext then return end
    analogNext = now + ANALOG_INTERVAL
    wiz.send(analog.buildReadMessage(function(d)
      analogData, analogAt = d, os.clock()
    end))
  end

  -- Screens ------------------------------------------------------------------------------

  -- The safety card first: the blades are off before the port and the power settings are touched.
  local function buildBlades()
    scr:text(T.title, T.bladesText)
    scr:picture(picture)
    scr:step(BLADES, SCREEN_COUNT)
    return scr:safety(answers, {{key = "blades", label = T.blades}}, T.start, function() go(SETUP) end)
  end

  local function buildSetup()
    local isUsed = used()

    local accent = wiz.rebootPending() and T.restart or nil
    scr:text(T.title, nil, accent)
    scr:picture(picture)
    local rows = {
      {label = T.telemetry, choice = {
        values = {{text = T.used, value = 1}, {text = T.notUsed, value = 0}},
        get = function() return used() and 1 or 0 end,
        set = function(val) setUsed(tonumber(val) == 1) end}},
      {label = T.protocol, choice = {
        values = protocolValues,
        get = function() return esc and esc.protocol or 0 end,
        set = function(val) setProtocol(tonumber(val)) end,
        disabled = not isUsed}},
      {label = T.port, choice = {
        values = portValues(),
        get = function() local p = escPort(); return p and p.identifier or NO_PORT end,
        set = function(val) setPort(tonumber(val)) end,
        disabled = not isUsed}},
    }
    local field = scr:checks(rows)
    scr:step(SETUP, SCREEN_COUNT)
    local rowField = scr:row(nil, nil, wiz.forward(function() forwardFrom(SETUP) end))
    return field or rowField
  end

  local function buildWiring()
    local accent = wiz.rebootPending() and T.wiringRestart or nil
    scr:text(T.wiringTitle, nil, accent)
    scr:picture(picture)

    local running = trial ~= nil
    local reason = (not running) and blocker() or nil
    shownStatus = statusText()
    local v, t = readValues()
    shownVoltage, shownTemp = v, t
    local rows = {
      {label = T.status, value = shownStatus},
      {label = T.wiring,
        answer = running and T.stop or T.detect,
        press = running and stop or start,
        disabled = reason ~= nil},
      {label = T.voltage, value = voltageText(v)},
      {label = T.temperature, value = tempText(t)},
    }
    if reason then rows[#rows + 1] = {note = reason} end
    local field = scr:checks(rows)
    scr:step(WIRING, SCREEN_COUNT)
    local rowField = scr:row(backTo(WIRING), nil, wiz.forward(function() forwardFrom(WIRING) end))
    return field or rowField
  end

  -- A voltage or current source and its reading: the source as a drop-down, the reading below.
  local function buildSource(index)
    local key = index == VOLTAGE and "voltageMeterSource" or "currentMeterSource"
    local signal = index == VOLTAGE and "voltage" or "current"
    local values = {}
    for i, c in ipairs(power.SOURCE_CHOICES) do values[i] = c end
    local current = pw.source(key)
    local known = false
    for _, c in ipairs(values) do if c.value == current then known = true end end
    if not known then values[#values + 1] = {text = tostring(current), value = current} end

    scr:text(index == VOLTAGE and T.voltageSource or T.currentSource, T.srcBody)
    scr:picture(art.power(index == VOLTAGE and "voltage" or "current"))
    shownReading = sourceReadingText(key, signal)
    local rows = {
      {label = index == VOLTAGE and T.voltageSource or T.currentSource, choice = {
        values = values,
        get = function() return pw.source(key) end,
        set = function(val) pw.setSource(key, tonumber(val)); wiz.rebuild() end}},
      {label = index == VOLTAGE and T.sensorVoltage or T.sensorCurrent, value = shownReading},
    }
    local field = scr:checks(rows)
    scr:step(index, SCREEN_COUNT)
    local rowField = scr:row(backTo(index), nil, wiz.forward(function() forwardFrom(index) end))
    return field or rowField
  end

  local function buildBattery()
    scr:text(T.battery, T.batBody)
    scr:picture(art.power("battery"))
    local profile = pw.activeProfile()
    local rows = {
      {label = T.selected, value = profile and (T.battery .. " #" .. (profile + 1)) or "--"},
      {label = T.cellCount, number = {
        0, power.CELL_MAX,
        function() return pw.cellCount() end,
        function(val) pw.setCellCount(val) end}},
    }
    local field = scr:checks(rows)
    scr:step(BATTERY, SCREEN_COUNT)
    local rowField = scr:row(backTo(BATTERY), nil, wiz.forward(function() forwardFrom(BATTERY) end))
    return field or rowField
  end

  -- The six capacities on one screen, across the full width: three rows, each with two cells.
  -- Battery 1 to 3 on the left, Battery 4 to 6 on the right, each label before its field.
  local function buildCapacities()
    scr:text(T.capacity, T.capBody)
    scr:wide()
    local rows = {}
    for k = 1, 3 do
      local left, right = k - 1, k + 2
      rows[#rows + 1] = {cells = {
        {label = T.battery .. " " .. (left + 1), number = {0, power.CAPACITY_MAX,
          function() return pw.capacity(left) end,
          function(val) pw.setCapacity(left, val) end, "mAh"}},
        {label = T.battery .. " " .. (right + 1), number = {0, power.CAPACITY_MAX,
          function() return pw.capacity(right) end,
          function(val) pw.setCapacity(right, val) end, "mAh"}}}}
    end
    local field = scr:checks(rows)
    scr:step(CAPS, SCREEN_COUNT)
    local rowField = scr:row(backTo(CAPS), nil, wiz.forward(function() forwardFrom(CAPS) end))
    return field or rowField
  end

  local function buildSmartFuel()
    scr:text(T.smartFuel, T.sfBody)
    scr:picture(art.power("smartfuel"))
    local rows
    if not pw.hasSmartFuel() then
      rows = {{note = T.sfMissing}}
    else
      rows = {
        {label = T.smartFuelRow, choice = {
          values = power.MODE_CHOICES,
          get = function() return pw.mode() end,
          set = function(val) pw.setMode(tonumber(val)); wiz.rebuild() end}},
      }
      if pw.voltageMissing() then rows[#rows + 1] = {note = T.sfVoltage} end
    end
    local field = scr:checks(rows)
    scr:step(SMARTFUEL, SCREEN_COUNT)
    local rowField = scr:row(backTo(SMARTFUEL), nil, wiz.forward(function() forwardFrom(SMARTFUEL) end))
    return field or rowField
  end

  function self.build()
    scr:begin()
    if failed then
      scr:text(T.title, T.loadFailed)
      return scr:row()
    end
    if not loaded then
      scr:text(T.title, T.loading)
      return scr:row()
    end
    if screen == BLADES then return buildBlades() end
    if screen == WIRING then return buildWiring() end
    if screen == SETUP then return buildSetup() end
    if not pw.loaded then
      scr:text(T.title, T.loading)
      return scr:row()
    end
    if not pw.battery and screen ~= SMARTFUEL then
      scr:text(T.title, T.loadFailed)
      return scr:row()
    end
    if screen == VOLTAGE or screen == CURRENT then return buildSource(screen) end
    if screen == BATTERY then return buildBattery() end
    if screen == CAPS then return buildCapacities() end
    return buildSmartFuel()
  end

  function self.paint() scr:paint() end

  -- The status and the readings update in place, without a rebuild.
  local function updateWiringInPlace()
    local changed = false
    local text = statusText()
    if text ~= shownStatus then
      shownStatus = text
      changed = scr:setCheckValue(STATUS_ROW, text) or changed
    end
    local v, t = readValues()
    if v ~= shownVoltage then
      shownVoltage = v
      changed = scr:setCheckValue(VOLTAGE_ROW, voltageText(v)) or changed
    end
    if t ~= shownTemp then
      shownTemp = t
      changed = scr:setCheckValue(TEMP_ROW, tempText(t)) or changed
    end
    if changed then wiz.invalidate() end
  end

  local function updateSourceInPlace(index)
    local key = index == VOLTAGE and "voltageMeterSource" or "currentMeterSource"
    local signal = index == VOLTAGE and "voltage" or "current"
    local text = sourceReadingText(key, signal)
    if text ~= shownReading then
      shownReading = text
      if scr:setCheckValue(READING_ROW, text) then wiz.invalidate() end
    end
  end

  -- Polls while the wiring trial runs, and gives up after the timeout. The readings and the
  -- source readings follow in place; flight controller analog readings are polled.
  function self.wakeup()
    if not loaded or failed then return end
    local now = os.clock()
    if screen == WIRING then
      updateWiringInPlace()
      if not trial then return end
      if now - trial.startedAt > TRIAL_TIMEOUT then
        return stopWith(T.timeout)
      end
      if trial.inFlight or now < trial.nextPoll then return end
      trial.inFlight = true
      trial.nextPoll = now + POLL_INTERVAL
      wiz.send(trialConfig.buildPollMessage(handle, fail))
      return
    end
    if screen == VOLTAGE or screen == CURRENT then
      local key = screen == VOLTAGE and "voltageMeterSource" or "currentMeterSource"
      local source = pw.source(key)
      if source ~= power.SOURCE_ESC and source ~= power.SOURCE_NONE then pollAnalog(now) end
      updateSourceInPlace(screen)
    end
  end

  -- Leaving the step (Back, the picker, another step) ends a running trial.
  function self.released()
    left = true
    if trial then stopWith(T.stopped) end
    local state = transports[wiz]
    if state and state.handler then
      bus.unsubscribe("session.update", state.handler)
      transports[wiz] = nil
    end
    scr:refresh()
  end

  return self
end

return {new = new, owned = OWNED}
