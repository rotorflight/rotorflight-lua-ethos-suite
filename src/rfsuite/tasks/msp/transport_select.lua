-- Picks the active MSP transport at background-task init, and lets
-- tasks/background.lua cheaply re-check afterwards (a model with a
-- different receiver protocol can get selected on the radio without the
-- background task itself ever reloading -- system.registerTask's `init`
-- runs once for the task's whole lifetime, not per model switch).
--
-- Matches rotorflight-lua-ethos's own tasks/tasks.lua: which RF module bay
-- is actually *enabled* (internal = model.getModule(0), external =
-- model.getModule(1)) decides sport vs crsf, with an external-but-not-yet-
-- linked module falling back to sport rather than committing to crsf
-- before its telemetry source exists. Deliberately not the presence of a
-- specific named telemetry source (e.g. an RSSI sensor): module :enable()
-- is a stable model-config value that only changes when the pilot actually
-- flips which bay is active, whereas a telemetry source guess can flicker
-- with ordinary link-quality noise -- and tasks/background.lua's
-- checkTransportChange() polls detect() on an interval, so a flickering
-- answer there would spuriously reset live sensor state on every flicker.
--
-- Split into detect() (just the two :enable() checks -- cheap enough to
-- poll on an interval) and load() (the actual loadfile() of the transport
-- module -- only worth paying for when detect()'s answer has actually
-- changed) so a recheck loop doesn't have to throw away and reconstruct a
-- perfectly good transport instance every time it merely confirms nothing
-- changed. select() is both, for the one-time init call.
--
-- The returned protocol name ("sport"|"crsf") is also what
-- lib/telemetry_sensors.lua uses to pick the right per-protocol appId
-- candidates for plain telemetry sensors (voltage, consumption, the
-- firmware-mirrored smartfuel channels, etc).

-- Matches rotorflight-lua-ethos's own SRC_CRSF probe (also used as-is by
-- app/pages/diagnostics_rfstatus.lua's elrsSensor check).
local SRC_CRSF = {crsfId = 0x14, subIdStart = 0, subIdEnd = 1}

local function detect()
  local internalModule = model.getModule(0)
  local externalModule = model.getModule(1)
  if internalModule and internalModule:enable() then
    return "sport"
  elseif externalModule and externalModule:enable() then
    if system.getSource(SRC_CRSF) then return "crsf" end
    return "sport"
  end
  return "sport"
end

local function load(protocol)
  if protocol == "crsf" then
    return assert(loadfile("tasks/msp/transport_crsf.lua"))()
  end
  return assert(loadfile("tasks/msp/transport_sport.lua"))()
end

local function select()
  local protocol = detect()
  return load(protocol), protocol
end

return {select = select, detect = detect, load = load}
