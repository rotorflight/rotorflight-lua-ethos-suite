-- Real engine + real widget tests; no FC, BLE or GUI required. Run with lua5.4.
local source = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
local root = (source:match("^(.*)bin/activelook_alerts/") or "./") .. "src/rfsuite/"
local config = assert(loadfile(root .. "lib/activelook_config.lua"))()
local alerts = assert(loadfile(root .. "lib/activelook_alerts.lua"))()
local checks = 0
local function check(label, condition)
  checks = checks + 1
  assert(condition, label)
end
local function near(a, b) return math.abs(a - b) < 0.00001 end
local function fixture(options)
  options = options or {}
  options.enabled = true
  options.low_fuel_seconds = options.low_fuel_seconds or 8 -- Explicit duration for the timing scenarios below.
  local settings = config.withDefaults(options)
  local engine = alerts.new(settings)
  local data = {connected = true, isArmed = true, fuelPercent = 70, tempEsc = 30, escTempLimit = 90, governorState = 4}
  local function sample(now, changes, phase)
    if changes then for k, v in pairs(changes) do data[k] = v end end
    alerts.update(engine, data, phase or "inflight", now)
    return alerts.current(engine, now)
  end
  return engine, data, sample, settings
end

-- Low Fuel: same zero threshold, first-reading seed, duration, repeat gap and cap.
do
  local e, data, sample = fixture({low_fuel_warning = true, low_fuel_repeats = 2})
  check("first zero seeds without alert", sample(0, {fuelPercent = 0}) == nil)
  check("next zero starts low fuel", sample(0.5).kind == "low_fuel")
  check("warning icon starts visible", alerts.current(e, 0.5).blinkOn)
  check("warning icon blinks after one second", not alerts.current(e, 1.5).blinkOn)
  check("warning ends after eight display seconds", alerts.current(e, 8.5) == nil)
  check("repeat gap preserved", alerts.current(e, 16.4) == nil)
  check("second show", alerts.current(e, 16.5).kind == "low_fuel" and e.fuel.count == 2)
  check("repeat cap", alerts.current(e, 24.5) == nil and alerts.current(e, 40) == nil)
  sample(41, {fuelPercent = 20})
  check("recovery rearms low fuel", sample(42, {fuelPercent = 0}).kind == "low_fuel")
end

do
  local settings = config.withDefaults({low_fuel_use_audio_limit = true, low_fuel_repeats = 7})
  check("Fuel inherits audio repeat budget", config.alertRepeats(settings, {smartfuelrepeats = 4}, "low_fuel") == 4)
  check("ESC zero preserves unlimited audio repeats", config.alertRepeats(settings, {temp_esc_repeats = 0}, "esc_temp") == 0)
  check("ESC inherits finite audio repeat budget", config.alertRepeats(settings, {temp_esc_repeats = 3}, "esc_temp") == 3)
  settings.esc_temp_use_audio_limit = false
  check("ESC own repeat budget remains independent", config.alertRepeats(settings, {temp_esc_repeats = 0}, "esc_temp") == 2)
  local e, data, sample = fixture({esc_temp_warning = true, esc_temp_seconds = 3})
  sample(0, {tempEsc = 100, escTempRepeats = 0})
  check("unlimited ESC starts after debounce", sample(2).kind == "esc_temp")
  for i = 1, 12 do
    check("unlimited ESC gap " .. i, sample(2 + i * 6 - 3) == nil)
    check("unlimited ESC repeat " .. i, sample(2 + i * 6).kind == "esc_temp")
  end
  sample(75, {tempEsc = 80})
  sample(90)
  check("recovery cancels unlimited repeats", e.temp.nextAt == nil and e.temp.condition == false)
end

-- Every manual preview works without enabling the automatic warning.
do
  local e, data, sample = fixture()
  sample(0)
  for _, kind in ipairs({"low_fuel", "esc_temp", "governor_lost", "governor_status"}) do
    alerts.setPreview(e, kind, 1)
    check("manual preview " .. kind, alerts.current(e, 1).kind == kind)
  end
  check("governor preview starts with autorotation", alerts.current(e, 1).governorState == 7)
  check("governor preview cycles bailout", alerts.current(e, 3).governorState == 8)
  check("governor preview cycles autorotation", alerts.current(e, 5).governorState == 7)
  check("governor preview cycles back", alerts.current(e, 7).governorState == 8)
  alerts.setPreview(e, nil, 8)
  check("closing preview restores automatic state", alerts.current(e, 8) == nil)
end

-- Preemption: only visible time counts; no FIFO queue of obsolete governor statuses.
do
  local e, data, sample = fixture({low_fuel_warning = true, low_fuel_repeats = 2,
    esc_temp_warning = true, esc_temp_seconds = 3, esc_temp_repeats = 1,
    governor_lost_warning = true, governor_lost_seconds = 3, governor_status_overlays = true})
  sample(0)
  sample(1, {fuelPercent = 0})
  check("temperature debounce starts without interruption", sample(2, {tempEsc = 95}).kind == "low_fuel")
  check("temperature preempts after debounce", sample(4).kind == "esc_temp")
  check("fuel remaining retained", near(e.fuel.remaining, 5))
  check("lost HS preempts temperature", sample(5, {governorState = 6}).kind == "governor_lost")
  check("temperature remaining retained", near(e.temp.remaining, 2))
  check("status cannot cover critical alert", sample(6, {governorState = 8}).kind == "governor_lost")
  check("temperature resumes", alerts.current(e, 8).kind == "esc_temp")
  check("fuel resumes without losing its budget", alerts.current(e, 10).kind == "low_fuel" and near(e.fuel.remaining, 5))
  check("no stale governor status after alarms", alerts.current(e, 15) == nil)
  check("fuel repeats only after resumed display completes", alerts.current(e, 23).kind == "low_fuel" and e.fuel.count == 2)
end

-- Temperature: Celsius threshold, 2s persistence, 5C hysteresis and finite data.
do
  local e, data, sample = fixture({esc_temp_warning = true, esc_temp_seconds = 3, esc_temp_repeats = 1})
  check("temperature starts pending", sample(0, {tempEsc = 95}) == nil)
  check("brief spike does not alert", sample(1, {tempEsc = 89}) == nil)
  sample(2, {tempEsc = 95})
  check("not before delay", sample(3.9) == nil)
  check("threshold delay elapsed", sample(4).kind == "esc_temp")
  check("duration ends", alerts.current(e, 7) == nil)
  check("unchanged high value does not retrigger", sample(8) == nil)
  check("inside hysteresis does not rearm", sample(9, {tempEsc = 89}) == nil and sample(12, {tempEsc = 95}) == nil)
  sample(13, {tempEsc = 85}); sample(14, {tempEsc = 95})
  check("hysteresis recovery permits new episode", sample(16).kind == "esc_temp")
  data.tempEsc = nil; sample(17); check("missing temperature cancels repeats", e.temp.nextAt == nil)
  sample(20, {tempEsc = 0/0}); sample(23, {tempEsc = math.huge})
  check("invalid temperature is not a new alarm", alerts.current(e, 30) == nil)
end

-- Governor: first sample seeds, real edges only, bounded display and repeatable new loss.
do
  local e, data, sample = fixture({governor_lost_warning = true, governor_lost_seconds = 3, governor_status_overlays = true})
  check("first lost state is a baseline", sample(0, {governorState = 6}) == nil)
  sample(1, {governorState = 4})
  check("new lost state triggers", sample(2, {governorState = 6}).kind == "governor_lost")
  sample(3); check("same state does not restart duration", sample(5) == nil)
  check("same state stays quiet", sample(6) == nil)
  sample(7, {governorState = 4}); check("re-entry triggers again", sample(8, {governorState = 6}).kind == "governor_lost")
  check("disarm clears critical", sample(9, {isArmed = false}, "postflight") == nil)
  check("missing governor cannot trigger", sample(10, {isArmed = true, governorState = 0/0}) == nil)
end

do
  local e, data, sample = fixture({governor_status_overlays = true})
  check("first spoolup does not invent a transition", sample(0, {governorState = 2}, "armed") == nil)
  sample(1, {governorState = 4})
  check("spoolup edge does not display status", sample(2, {governorState = 2}, "armed") == nil)
  check("autorotation edge displays status", sample(2.1, {governorState = 7}).governorState == 7)
  sample(3, nil, "armed")
  check("same-state status expires", sample(4.2, nil, "armed") == nil)
  sample(4.5, {governorState = 4})
  check("autorotation edge", sample(5, {governorState = 7}).governorState == 7)
  check("latest status replaces previous", sample(5.5, {governorState = 8}).governorState == 8)
  check("flight end clears status", sample(6, {isArmed = false}, "postflight") == nil)
end

do
  local e, data, sample, settings = fixture({low_fuel_warning = true})
  sample(0); sample(1, {fuelPercent = 0})
  alerts.setPreview(e, "low_fuel", 2)
  check("low-fuel settings preview is unlimited", alerts.current(e, 100).kind == "low_fuel")
  alerts.setPreview(e, nil, 100)
  check("preview did not consume automatic budget", alerts.current(e, 100).kind == "low_fuel" and near(e.fuel.remaining, 7))
  check("link loss clears automatic display", sample(101, {connected = false}) == nil)
  check("reconnect zero seeds again", sample(102, {connected = true}) == nil)
  data.fuelPercent = nil
  check("missing fuel cannot trigger", sample(103) == nil)
  data.fuelPercent = 0
  sample(104)
  settings.low_fuel_warning = false; alerts.configure(e, settings)
  check("disabling a warning cancels it", alerts.current(e, 105) == nil)
  alerts.setPreview(e, "low_fuel", 106)
  check("manual preview works while warning disabled", alerts.current(e, 106).kind == "low_fuel")
end

-- RF link: native positive RSSI dB, delay/hysteresis, missing data, highest priority.
do
  local e, data, sample = fixture({rf_link_warning = true, rf_link_repeats = 1,
    low_fuel_warning = true, governor_status_overlays = true})
  sample(0, {linkQuality = 70})
  sample(1, {fuelPercent = 0})
  sample(2, {linkQuality = 40})
  check("RF debounce keeps lower warning visible", sample(3).kind == "low_fuel")
  check("RF link preempts after two seconds", sample(4).kind == "rf_link")
  check("RF preemption preserves fuel time", near(e.fuel.remaining, 5))
  sample(5, {governorState = 8})
  check("RF warning suppresses stale governor status", e.status.remaining == 0)
  check("fuel resumes after link display", sample(9).kind == "low_fuel" and near(e.fuel.remaining, 5))
  check("RF episode stays bounded", sample(14) == nil and sample(15) == nil)
  sample(16, {linkQuality = 44}); sample(17, {linkQuality = 40})
  check("RF hysteresis prevents retrigger", sample(19) == nil)
  sample(20, {linkQuality = 47}); sample(21, {linkQuality = 42})
  check("RF recovery rearms warning", sample(23).kind == "rf_link")
  check("disarm clears RF warning", sample(24, {isArmed = false}, "postflight") == nil)
end
do
  local e, data, sample = fixture({rf_link_warning = true, rf_link_repeats = 1, governor_lost_warning = true, governor_lost_seconds = 3})
  sample(0, {linkQuality = 40}); sample(2)
  check("RF takes priority over headspeed loss", sample(3, {governorState = 6}).kind == "rf_link")
  check("headspeed warning resumes afterwards", sample(7).kind == "governor_lost")
  check("disconnect clears RF and critical warnings", sample(8, {connected = false}) == nil and e.link.remaining == 0)
  local defaults = config.withDefaults({})
  check("RF warning is opt-in", not defaults.rf_link_warning and defaults.rf_link_limit == 42 and defaults.rf_link_seconds == 5)
end
do
  local e, data, sample = fixture({rf_link_warning = true})
  for _, value in ipairs({-1, 101, math.huge, 0/0}) do
    sample(0, {linkQuality = value}); check("invalid RSSI cannot trigger", sample(3) == nil)
  end
  data.linkQuality = nil; check("missing RSSI cannot trigger", sample(4) == nil)
  sample(5, {linkQuality = 40}); data.linkQuality = nil; sample(6)
  sample(7, {linkQuality = 40}); check("missing RSSI resets pending delay", sample(8) == nil)
  check("valid low RSSI can trigger afterwards", sample(9).kind == "rf_link")
  alerts.setPreview(e, "rf_link", 10)
  check("RF manual preview is supported", alerts.current(e, 100).kind == "rf_link")
end

-- Percentage telemetry uses its own threshold, never the RSSI limit.
do
  local e, data, sample = fixture({rf_link_warning = true, rf_link_repeats = 1})
  sample(0, {linkQuality = 90, linkQualityIsPercent = true})
  check("healthy percentage does not trigger", sample(3) == nil)
  sample(4, {linkQuality = 79})
  check("VFR uses 80 percent limit rather than 42 dB", sample(6).kind == "rf_link")
  sample(7, {linkQuality = 83}); sample(11)
  check("percentage hysteresis prevents restart", sample(12, {linkQuality = 79}) == nil)
  sample(13, {linkQuality = 85}); sample(14, {linkQuality = 80})
  check("percentage recovery rearms alarm", sample(16).kind == "rf_link")
end

-- No heap churn in the engine's unchanged telemetry/timer path.
do
  local e, data, sample = fixture()
  sample(0)
  collectgarbage("collect"); collectgarbage("stop")
  local before = collectgarbage("count")
  for i = 1, 1000 do alerts.update(e, data, "inflight", i); alerts.current(e, i) end
  local growth = collectgarbage("count") - before
  collectgarbage("restart")
  check("unchanged engine updates allocate no growing structures", growth < 2)
end

-- Settings compatibility and limit source.
do
  local warningDefaults = config.withDefaults({})
  check("all warning durations default to five seconds", warningDefaults.low_fuel_seconds == 5
    and warningDefaults.esc_temp_seconds == 5 and warningDefaults.governor_lost_seconds == 5
    and config.clampAlertSeconds(nil) == 5)
  local defaults = config.withDefaults({inflight_fuel_icon = "true", low_fuel_seconds = 12})
  check("existing settings preserved", defaults.inflight_fuel_icon and defaults.low_fuel_seconds == 12)
  check("all new automatic functions default off", not defaults.esc_temp_warning and not defaults.governor_lost_warning and not defaults.governor_status_overlays)
  check("reuse audio Celsius threshold", config.escTempLimit(defaults, {escalertvalue = 100}) == 100)
  defaults.esc_temp_use_audio_limit = false; defaults.esc_temp_limit = 95
  check("own Celsius threshold", config.escTempLimit(defaults, {escalertvalue = 100}) == 95)
  local clamped = config.withDefaults({esc_temp_limit = 900, governor_status_seconds = 100, governor_lost_seconds = 0})
  check("new settings clamped", clamped.esc_temp_limit == 300 and clamped.governor_status_seconds == 5 and clamped.governor_lost_seconds == 3)
end

-- Integrate the actual widget and actual flight-phase tracker against fake glasses.
local oldClock = os.clock
local now, draws, bitmaps = 0, 0, 0
local frame
local settings = {general = {temperature_unit = 0}, events = {escalertvalue = 90},
  activelook = config.withDefaults({enabled = true, esc_temp_use_audio_limit = false, low_fuel_warning = true, low_fuel_seconds = 8, inflight_fuel_icon = true,
    esc_temp_warning = true, esc_temp_seconds = 3, governor_lost_warning = true, governor_lost_seconds = 3})}
local handlers = {}
local store = {load = function() return settings end,
  activelook = function(s) return config.withDefaults(s.activelook) end,
  temperatureUnit = function(s) return s.general.temperature_unit end}
local modules = {
  ["lib/bus.lua"] = {subscribe = function(k, f) handlers[k] = f; return f end, unsubscribe = function(k) handlers[k] = nil end},
  ["lib/settings_store.lua"] = store, ["lib/activelook_config.lua"] = config,
  ["lib/activelook_alerts.lua"] = alerts,
  ["lib/engine_type.lua"] = assert(loadfile(root .. "lib/engine_type.lua"))(),
  ["widgets/dashboard/flightmode.lua"] = assert(loadfile(root .. "widgets/dashboard/flightmode.lua"))(),
}
package.loaded["rfsuite.lib.require"] = function(path) return assert(modules[path], path) end
local definition
system = {registerGlassesWidget = function(d) definition = d end}
glasses = {getWindowSize = function() return 304, 256 end,
  createLayout = function() return {clearAndDisplayExtended = function(self, args) frame = args; draws = draws + 1 end} end,
  bitmap = function() bitmaps = bitmaps + 1 end}
os.clock = function() return now end
local widgetSource
do
  local file = assert(io.open(root .. "widgets/activelook.lua", "rb"))
  widgetSource = file:read("a"); file:close()
  file = assert(io.open(root .. "../../bin/i18n/json/en.json", "rb"))
  local locale = file:read("a"); file:close()
  local english = {}
  for key, value in locale:gmatch('"(alert_[%w_]+)": {%s*"english": "(.-)"') do english[key] = value end
  widgetSource = widgetSource:gsub("@i18n%(widgets%.activelook%.([%w_]+)%)@", function(key)
    return assert(english[key], key)
  end)
end
assert(load(widgetSource, "@" .. root .. "widgets/activelook.lua"))().init()
local widget = definition.create()
local data = {connected = true, isArmed = true, governorState = 4, fuelPercent = 70,
  voltage = 24.8, current = 18, consumption = 1500, tempEsc = 30, rpm = 1800,
  batteryConfig = {cellCount = 6}, smartfuelModelType = 1}
local function render(time)
  now = time; handlers["session.update"](data); definition.wakeup(widget)
end
local function title() return frame.commands[1].text.text end
render(1); render(2)
check("inflight indicator shares the layout frame", bitmaps == 0 and widget.lastFuelIcon == 5
  and frame.commands[#frame.commands].bitmap.id == 5)
check("inflight indicator retains position", frame.commands[#frame.commands].bitmap.x == 0
  and frame.commands[#frame.commands].bitmap.y == 144)
local n = draws; render(2.1)
check("unchanged wakeup sends no frame", draws == n)
data.fuelPercent = 0; render(3)
check("widget renders real low-fuel overlay", title() == "BATTERY EMPTY" and widget.lastFuelIcon == nil)
local symbol
for _, c in ipairs(frame.commands) do if c.bitmap then symbol = c.bitmap.id end end
check("electric warning icon remains 21", symbol == 21)
render(4); symbol = nil
for _, c in ipairs(frame.commands) do if c.bitmap then symbol = c.bitmap.id end end
check("low-fuel icon blinks off", symbol == nil)
data.tempEsc = 95; render(5); render(7)
check("widget renders temperature warning", title() == "ESC TEMP HIGH" and frame.commands[2].text.text == "95°C")
check("automatic ESC warning includes thermometer", frame.commands[3].bitmap and frame.commands[3].bitmap.id == 18)
settings.general.temperature_unit = 1; handlers["settings.update"](settings); render(7.1)
check("Fahrenheit rendering, Celsius trigger", frame.commands[2].text.text == "203°F" and frame.commands[#frame.commands].text.text == "LIMIT 194°F")
data.governorState = 6; render(8)
check("widget renders critical lost HS", title() == "WARNING!" and frame.commands[3].text.text == "RPM 1800")
render(11); check("widget resumes interrupted temperature", title() == "ESC TEMP HIGH")
render(13.1); check("widget resumes interrupted low fuel", title() == "BATTERY EMPTY")
data.fuelPercent = 50; data.tempEsc = 70; data.governorState = 4; render(14); render(30)
check("widget returns to normal layout and fuel indicator", title() ~= "BATTERY EMPTY" and title() ~= "ESC TEMP HIGH" and widget.lastFuelIcon == 4)
handlers["activelook.control"]({previewMode = "low_fuel"}); render(31)
check("settings preview retained", title() == "BATTERY EMPTY")
handlers["activelook.control"]({reset = true}); render(32)
check("save/reset keeps settings preview", title() == "BATTERY EMPTY")
handlers["activelook.control"]({previewMode = nil}); render(33)
check("leaving preview restores normal layout", title() ~= "BATTERY EMPTY")
data.isArmed = false; render(34)
check("disarm clears engine alert", widget.alertState.active == nil)
now = 35
handlers["activelook.control"]({previewMode = "esc_temp"}); render(35)
check("ESC preview works disarmed with live temperature", title() == "ESC TEMP HIGH" and frame.commands[2].text.text == "158°F")
local temperatureX = frame.commands[2].text.x
check("ESC preview draws thermometer ID 18", frame.commands[3].bitmap and frame.commands[3].bitmap.id == 18)
local beforeBlink = draws
render(35.3); check("unchanged ESC preview sends no frame", draws == beforeBlink)
render(36)
check("ESC thermometer blinks off after one second", #frame.commands == 3 and frame.commands[2].text.x == temperatureX)
render(37)
check("ESC thermometer blinks on without shifting text", frame.commands[3].bitmap and frame.commands[3].bitmap.id == 18
  and frame.commands[2].text.x == temperatureX)
settings.activelook.esc_temp_icon = false
handlers["settings.update"](settings); render(37.2)
check("ESC symbol can be disabled in preview", #frame.commands == 3)
local withoutSymbol = draws
render(38.2); check("disabled ESC icon does not cause blink redraws", draws == withoutSymbol)
settings.activelook.esc_temp_icon = true
handlers["settings.update"](settings); render(39.2)
check("ESC icon can be re-enabled", frame.commands[3].bitmap and frame.commands[3].bitmap.id == 18)
handlers["activelook.control"]({previewMode = "governor_lost"}); render(40)
check("LOST HS preview shows live RPM without thermometer", title() == "WARNING!" and #frame.commands == 3 and frame.commands[3].text.text == "RPM 1800")
handlers["activelook.control"]({previewMode = "governor_status"}); render(41)
check("status preview starts with autorotation", frame.commands[2].text.text == "AUTOROTATION")
render(43); check("status preview renders bailout", frame.commands[2].text.text == "BAILOUT")
render(45); check("status preview cycles back to autorotation", frame.commands[2].text.text == "AUTOROTATION")
handlers["activelook.control"]({previewMode = nil}); render(46)
check("all preview types return to phase layout", title() ~= "GOVERNOR" and title() ~= "WARNING!")

now = 47; data.linkQuality = 38
handlers["activelook.control"]({previewMode = "rf_link"}); render(47)
check("RF preview renders native dB telemetry and threshold", title() == "RF LINK LOW"
  and frame.commands[2].text.text == "38dB" and frame.commands[#frame.commands].text.text == "LIMIT 42dB")
data.linkQualityIsPercent = true; data.linkQuality = 76; render(47.2)
check("RF preview uses percent value and matching limit", frame.commands[2].text.text == "76%" and frame.commands[#frame.commands].text.text == "LIMIT 80%")
check("RF preview includes symbol 16", frame.commands[3].bitmap and frame.commands[3].bitmap.id == 16)
local linkX = frame.commands[2].text.x
local linkFrames = draws; render(47.4)
check("RF preview without changes does not redraw", draws == linkFrames)
render(48)
check("RF symbol blinks off after one second without moving text", #frame.commands == 3 and frame.commands[2].text.x == linkX)
render(49)
check("RF symbol blinks on after two seconds", frame.commands[3].bitmap and frame.commands[3].bitmap.id == 16)

settings.activelook.rf_link_icon = false; handlers["settings.update"](settings); render(49.1)
check("RF symbol can be disabled without hiding warning", title() == "RF LINK LOW" and #frame.commands == 3
  and widget.alertSlots[2].reserveIconSpace == false)
settings.activelook.rf_link_icon = true; handlers["settings.update"](settings); render(49.2)
check("RF symbol can be enabled again", frame.commands[3].bitmap and frame.commands[3].bitmap.id == 16)
handlers["activelook.control"]({previewMode = nil}); render(50)
check("RF preview closes normally", title() ~= "RF LINK LOW")

definition.close(widget)
check("close unsubscribes and releases caches", next(handlers) == nil and widget.overlayCache == nil and widget.layout == nil)
os.clock = oldClock

-- The new page uses the same persisted settings and converts C/F only at its boundary.
do
  local pageSettings = {general = {temperature_unit = 1}, events = {escalertvalue = 100}, activelook = {}}
  local fields, ordered, panels, changes, line, preview = {}, {}, {}, 0, nil, nil
  modules["lib/bus.lua"].publish = function(topic, action) preview = action.previewMode end
  modules["app/pages/settings_activelook_common.lua"] = {openPage = function(title, opts, build)
    build(pageSettings, function() changes = changes + 1 end)
  end}
  local function field(get, set)
    local f = {get = get, set = set, enableCalls = 0,
      enable = function(self, value) self.enabled = value; self.enableCalls = self.enableCalls + 1 end,
      suffix = function(self, value) self.unit = value end}
    fields[line] = f
    ordered[#ordered + 1] = f
    return f
  end
  form = {addLine = function(label) line = label:gsub("^%s+", ""); return label end,
    addBooleanField = function(l, slot, get, set) return field(get, set) end,
    addNumberField = function(l, slot, minimum, maximum, get, set) return field(get, set) end}
  EVT_OPEN, EVT_CLOSE = 1001, 1002
  form.addExpansionPanel = function(title)
    local panel = {title = title, event = function(self, handler) self.handler = handler end,
      open = function(self, value) self.expanded = value; if self.handler then self.handler(value and EVT_OPEN or EVT_CLOSE) end end,
      addLine = function(self, label) return form.addLine(label) end}
    panels[#panels + 1] = panel
    return panel
  end
  assert(loadfile(root .. "app/pages/settings_activelook_alerts.lua"))().open({})
  check("five independently expandable alert groups", #panels == 5)
  check("Low Fuel initially open, other groups collapsed", panels[1].expanded
    and not panels[2].expanded and not panels[3].expanded and not panels[4].expanded and not panels[5].expanded)

  local function f(key) return assert(fields["@i18n(app.modules.settings." .. key .. ")@"], key) end
  check("Low Fuel is the first settings group", ordered[1] == f("activelook_low_fuel_warning"))
  check("merged page retains unlimited Low Fuel preview", preview == "low_fuel")
  check("Low Fuel dependents start disabled", not ordered[2].enabled and not ordered[4].enabled and not ordered[3].enabled and not ordered[5].enabled)
  ordered[1].set(true)
  check("Low Fuel enables only its own dependents", ordered[2].enabled and ordered[4].enabled and ordered[3].enabled and ordered[5].enabled)
  ordered[4].set(12); ordered[3].set(3); ordered[5].set(false)
  ordered[2].set(true)
  check("Fuel audio locks repeats and displays audio default", not ordered[3].enabled and ordered[3].get() == 1)
  pageSettings.events.smartfuelrepeats = 4
  check("locked Fuel repeats follow changed audio settings", not ordered[3].enabled and ordered[3].get() == 4)
  ordered[2].set(false)
  check("Fuel own repeat budget is preserved", ordered[3].enabled and ordered[3].get() == 3)
  check("merged Low Fuel settings retain persisted keys", pageSettings.activelook.low_fuel_seconds == 12
    and pageSettings.activelook.low_fuel_repeats == 3 and pageSettings.activelook.low_fuel_icon == false)
  changes = 0
  panels[2]:open(true)
  check("opening ESC selects its preview and closes Low Fuel", preview == "esc_temp" and not panels[1].expanded)
  panels[3]:open(true)
  check("opening LOST HS switches preview exclusively", preview == "governor_lost" and not panels[2].expanded)
  panels[4]:open(true)
  check("RF link group previews its alert", preview == "rf_link" and not panels[3].expanded)
  panels[5]:open(true)
  check("opening governor selects status preview", preview == "governor_status" and not panels[4].expanded)
  panels[5]:open(false)
  check("closing last panel restores automatic display", preview == nil)
  local linkToggle = f("activelook_rf_link_warning")
  local linkLimit = f("activelook_rf_link_limit")
  check("link warning defaults off with 42 dB threshold", not linkToggle.get() and linkLimit.get() == 42 and linkLimit.unit == "dB" and not linkLimit.enabled)
  local linkIcon = ordered[19]
  check("RF symbol defaults on but disabled with warning", linkIcon.get() and not linkIcon.enabled)
  linkToggle.set(true); linkLimit.set(45)
  check("RF symbol becomes editable with warning", linkIcon.enabled)
  linkIcon.set(false)
  check("RF symbol setting is stored", pageSettings.activelook.rf_link_icon == false)
  check("RF threshold is enabled and stored", linkLimit.enabled and pageSettings.activelook.rf_link_limit == 45)
  changes = 0
  local esc = f("activelook_esc_temp_warning")
  local audio = f("activelook_use_audio_limit")
  local limit = f("activelook_esc_temp_limit")
  local escIcon = ordered[11]
  check("ESC symbol defaults on but disabled with warning", escIcon.get() and not escIcon.enabled)
  check("ESC warning defaults off in settings", not esc.get() and not limit.enabled)
  check("audio limit shown in Fahrenheit", limit.get() == 212 and limit.unit == "°F")
  esc.set(true)
  check("shared threshold stays read-only and symbol becomes editable", audio.enabled and not limit.enabled and not ordered[9].enabled and ordered[9].get() == 0 and escIcon.enabled)
  pageSettings.events.escalertvalue = 110
  pageSettings.events.temp_esc_repeats = 4
  check("locked ESC fields follow changed audio settings", not limit.enabled and not ordered[9].enabled
    and limit.get() == 230 and ordered[9].get() == 4)
  audio.set(false)
  check("ESC own repeat budget survives inheritance", ordered[9].get() == 2)
  check("own limit and repeats editable", limit.enabled and ordered[9].enabled)
  limit.set(203)
  check("Fahrenheit input saved as Celsius", pageSettings.activelook.esc_temp_limit == 95)
  check("edited own limit display", limit.get() == 203)
  local count = limit.enableCalls
  esc.set(true)
  check("unchanged enabled state is not sent twice", limit.enableCalls == count)
  check("field changes activate existing save mechanism", changes == 4)
  ordered[9].set(0)
  check("ESC independent repeats accepts zero", pageSettings.activelook.esc_temp_repeats == 0)
  local normalized = config.withDefaults(pageSettings.activelook)
  check("ESC independent zero survives normalization", normalized.esc_temp_repeats == 0
    and config.alertRepeats(normalized, pageSettings.events, "esc_temp") == 0)

end
-- Shared chrome compares only ActiveLook, without repeatedly normalizing the entire suite.
do
  local chrome, dirty, refresh, cleanup, dialog
  local saves, publishes = 0, 0
  local originalLoad, originalClone, originalSave, originalSame = store.load, store.clone, store.save, store.same
  local pageSettings = {general = {temperature_unit = 0}, events = {escalertvalue = 90}, activelook = config.withDefaults({})}
  store.load = function() return pageSettings end
  store.clone = function(s)
    local out = {}
    for section, values in pairs(s) do
      out[section] = {}
      for k, v in pairs(values) do out[section][k] = v end
    end
    return out
  end
  store.same = function() error("full-suite normalization must not run in the ActiveLook dirty check") end
  store.save = function(s) saves = saves + 1; return true end
  modules["lib/bus.lua"].publish = function() publishes = publishes + 1 end
  modules["app/close_key.lua"] = {shouldHandleClose = function() return false end}
  modules["app/header.lua"] = {build = function(title, opts)
    chrome = opts
    return {setSaveEnabled = function(value) dirty = value end}
  end}
  modules["app/settings_save.lua"] = {reportFailure = function() error("unexpected save failure") end}
  modules["app/leave_confirm.lua"] = {args = function(opts) return opts end}
  form.clear = function() end
  form.openDialog = function(args) dialog = args end
  local common = assert(loadfile(root .. "app/pages/settings_activelook_common.lua"))()
  common.openPage("Alerts", {setCleanupHandler = function(f) if f then cleanup = f end end}, function(s, update)
    refresh = update
  end)
  check("shared page starts clean", dirty == false)
  pageSettings.activelook.governor_lost_warning = true; refresh()
  check("ActiveLook edit enables Save", dirty == true)
  chrome.onSave(); dialog.buttons[1].action()
  check("save resets dirty state", saves == 1 and dirty == false)
  check("save publishes settings/reset", publishes == 2)
  cleanup(); cleanup()
  check("shared cleanup is idempotent", publishes == 3)
  store.load, store.clone, store.save, store.same = originalLoad, originalClone, originalSave, originalSame
end

print(string.format("ActiveLook alerts: %d checks passed", checks))
