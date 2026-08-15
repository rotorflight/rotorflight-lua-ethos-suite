-- ELRS TX-module <-> Rotorflight CRSF-telemetry-config probe/sync.
--
-- Ported from rotorflight-lua-ethos-suite's master branch
-- (app/modules/diagnostics/tools/elrslink_task.lua). Talks to the ELRS TX
-- module directly over CRSF's *extended* parameter protocol (device
-- ping/info, parameter read/write -- frame types 0x28/0x29/0x2B/0x2C/0x2D),
-- which is a completely different frame family from the MSP req/resp and
-- custom-telemetry (0x88) frames tasks/msp/transport_crsf.lua handles --
-- so, like the original, this owns its own crsf.getSensor() handle rather
-- than going through that transport (which is private to tasks/msp/
-- anyway, and doesn't expose these frame types).
--
-- Adapted to this rebuild's architecture:
--   - No rfsuite.tasks.msp.api "named page" system. FC-side reads/writes
--     go through lib/bus.lua's "msp.request" topic using
--     lib/msp_telemetry_config.lua's buildReadConfigMessage/
--     buildWriteMessage, which round-trip the *whole* decoded struct --
--     so writing back the ELRS-derived rate/ratio means mutating the two
--     numeric fields on the struct already read and re-encoding all of
--     it, not manually patching byte offsets in a raw buffer copy like
--     the original.
--   - No rfsuite.session table access -- subscribes to "session.update"
--     itself for connected/isArmed/mspTransport, same as every other
--     self-contained lib/ module here.
--   - No separate "in flight" concept exists in this rebuild -- gates
--     writes on isArmed only (matches lib/msp_reboot.lua's precedent).
--   - rfsuite.utils.log(msg, level) -> lib/debug_log.lua's single
--     debug-gated print (no severity levels here).
--   - session.elrsLinkConfig/session.crsfTelemetryConfig (shared session
--     fields in the original) become plain accessor functions on this
--     module instead, since nothing outside tasks/ may read this
--     rebuild's session table -- the page calls elrslink.getFcSummary()/
--     getLinkSummary() directly.
--
-- Self-caches via package.loaded (same mechanism lib/bus.lua/lib/
-- debug_log.lua use): the page loads this fresh via loadfile() on every
-- navigation to it, but this module subscribes to "session.update" at
-- load time -- without caching, every visit would register a new
-- duplicate subscriber that's never cleaned up, since nothing here ever
-- unsubscribes.
if package.loaded["rfsuite.lib.elrslink_task"] then
  return package.loaded["rfsuite.lib.elrslink_task"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local telemetryConfig = requireModule("lib/msp_telemetry_config.lua")
local eeprom = requireModule("lib/msp_eeprom.lua")
local debugLog = requireModule("lib/debug_log.lua")

local elrslink = {}

local os_clock = os.clock
local string_find = string.find
local string_gmatch = string.gmatch
local string_lower = string.lower
local tonumber = tonumber
local tostring = tostring
local type = type

local CRSF_FRAMETYPE_DEVICE_PING = 0x28
local CRSF_FRAMETYPE_DEVICE_INFO = 0x29
local CRSF_FRAMETYPE_PARAMETER_SETTINGS_ENTRY = 0x2B
local CRSF_FRAMETYPE_PARAMETER_READ = 0x2C
local CRSF_FRAMETYPE_PARAMETER_WRITE = 0x2D

local CRSF_ADDRESS_BROADCAST = 0x00
local CRSF_ADDRESS_RADIO_TRANSMITTER = 0xEA
local CRSF_ADDRESS_CRSF_TRANSMITTER = 0xEE
local CRSF_ADDRESS_ELRS_LUA = 0xEF

local ELRS_SERIAL_ID = 0x454C5253
local TYPE_TEXT_SELECTION = 9

local DISCOVERY_TIMEOUT_SECONDS = 4.0
local READ_TIMEOUT_MAX_SECONDS = 8.0
local READ_TIMEOUT_SECONDS = 0.5
local PING_RETRY_SECONDS = 1.0
local WRITE_DELAY_SECONDS = 0.25
local SYNC_MODE_OFF = 0
local SYNC_MODE_ROTORFLIGHT_TO_ELRS = 1
local SYNC_MODE_ELRS_TO_ROTORFLIGHT = 2
local STD_TLM_RATIO_BY_PACKET_RATE = {
  [25] = 8,
  [50] = 16,
  [100] = 32,
  [150] = 32,
  [200] = 64,
  [250] = 64,
  [333] = 128,
  [500] = 128,
  [1000] = 128,
}

local taskComplete = false
local probeStartedAt = 0
local nextActionAt = 0
local state = "idle"

local sensor = nil
local deviceId = CRSF_ADDRESS_CRSF_TRANSMITTER
local fieldCount = 0
local currentField = 1
local currentChunk = 0
local expectedChunksRemain = -1
local fieldData = {}
local rateField = nil
local ratioField = nil
local moduleRateLabel = nil
local moduleRatioLabel = nil
local pendingWrites = {}
local pendingWriteCount = 0
local pendingWriteIndex = 1
local manualSyncMode = SYNC_MODE_OFF
local statusText = "Idle"

-- Populated by ensureFcConfig() below (this rebuild's own read of
-- MSP_TELEMETRY_CONFIG, not an ambient session field). fcConfigData is the
-- full decoded struct (all 40 slots included) -- kept around so a write
-- back only mutates the two numeric fields this tool owns, never
-- reconstructing the other 38+ header/slot fields from scratch. fcConfig
-- is the {mode, linkRate, linkRatio} summary the sync/compare logic reads.
local fcConfigData = nil
local fcConfig = nil
local fcConfigRequested = false

-- The {packetRateLabel, packetRate, telemetryRatioLabel, ...} summary the
-- page displays -- this rebuild's local stand-in for the original's
-- session.elrsLinkConfig.
local linkConfig = nil

local T = {
  actionProbeOnly = "@i18n(app.modules.elrs_telemetry.action_probe_only)@",
  actionRfToElrs = "@i18n(app.modules.elrs_telemetry.action_rf_to_elrs)@",
  actionElrsToRf = "@i18n(app.modules.elrs_telemetry.action_elrs_to_rf)@",
  idle = "@i18n(app.modules.elrs_telemetry.status_idle)@",
  writingElrs = "@i18n(app.modules.elrs_telemetry.status_writing_elrs)@",
  elrsMatchesRf = "@i18n(app.modules.elrs_telemetry.status_elrs_matches_rf)@",
  elrsProbeComplete = "@i18n(app.modules.elrs_telemetry.status_elrs_probe_complete)@",
  rfMatchesElrs = "@i18n(app.modules.elrs_telemetry.status_rf_matches_elrs)@",
  writingRotorflight = "@i18n(app.modules.elrs_telemetry.status_writing_rotorflight)@",
  savingRotorflight = "@i18n(app.modules.elrs_telemetry.status_saving_rotorflight)@",
  rotorflightUpdated = "@i18n(app.modules.elrs_telemetry.status_rotorflight_updated)@",
  rotorflightSaveFailed = "@i18n(app.modules.elrs_telemetry.status_rotorflight_save_failed)@",
  rotorflightWriteFailed = "@i18n(app.modules.elrs_telemetry.status_rotorflight_write_failed)@",
  probeComplete = "@i18n(app.modules.elrs_telemetry.status_probe_complete)@",
  readingModule = "@i18n(app.modules.elrs_telemetry.status_reading_module)@",
  requiresActiveLink = "@i18n(app.modules.elrs_telemetry.status_requires_active_link)@",
  waitingRotorflightConfig = "@i18n(app.modules.elrs_telemetry.status_waiting_rotorflight_config)@",
  rotorflightConfigNotReady = "@i18n(app.modules.elrs_telemetry.status_rotorflight_config_not_ready)@",
  pingingModule = "@i18n(app.modules.elrs_telemetry.status_pinging_module)@",
  noModule = "@i18n(app.modules.elrs_telemetry.status_no_module)@",
  readTimeout = "@i18n(app.modules.elrs_telemetry.status_read_timeout)@",
  sensorUnavailable = "@i18n(app.modules.elrs_telemetry.status_sensor_unavailable)@",
  writingPrefix = "@i18n(app.modules.elrs_telemetry.status_writing_prefix)@",
  elrsUpdated = "@i18n(app.modules.elrs_telemetry.status_elrs_updated)@",
  unavailableSimulation = "@i18n(app.modules.elrs_telemetry.status_unavailable_simulation)@",
  connectFirst = "@i18n(app.modules.elrs_telemetry.status_connect_first)@",
  requiresCrsf = "@i18n(app.modules.elrs_telemetry.status_requires_crsf)@",
  unavailableArmed = "@i18n(app.modules.elrs_telemetry.status_unavailable_armed)@",
  probeRequested = "@i18n(app.modules.elrs_telemetry.status_probe_requested)@",
  syncRequested = "@i18n(app.modules.elrs_telemetry.status_sync_requested)@",
}

-- Local session snapshot -- see file header. Only the three fields this
-- tool actually needs.
local session = {connected = false, isArmed = nil, mspTransport = nil}
bus.subscribe("session.update", function(snapshot)
  local wasConnected = session.connected
  session.connected = snapshot and snapshot.connected == true
  session.isArmed = snapshot and snapshot.isArmed
  session.mspTransport = snapshot and snapshot.mspTransport

  -- A disconnect (or a fresh connect right after one -- same edge) must
  -- not leave a previous aircraft's FC telemetry config cached; see
  -- ensureFcConfig() below for why this is normally only fetched once
  -- per connection rather than on every wakeup.
  if wasConnected and not session.connected then
    fcConfigData = nil
    fcConfig = nil
    fcConfigRequested = false
    linkConfig = nil
  end
end)

local function log(msg)
  debugLog.print("[elrslink] " .. msg)
end

local function clearFieldData()
  for i = #fieldData, 1, -1 do
    fieldData[i] = nil
  end
end

local function clearPendingWrites()
  for i = pendingWriteCount, 1, -1 do
    pendingWrites[i] = nil
  end
  pendingWriteCount = 0
  pendingWriteIndex = 1
end

local function getSyncMode()
  return manualSyncMode
end

local function syncModeLabel(mode)
  if mode == SYNC_MODE_ROTORFLIGHT_TO_ELRS then return T.actionRfToElrs end
  if mode == SYNC_MODE_ELRS_TO_ROTORFLIGHT then return T.actionElrsToRf end
  return T.actionProbeOnly
end

local function normalizeSyncMode(mode)
  if mode == SYNC_MODE_ROTORFLIGHT_TO_ELRS or mode == SYNC_MODE_ELRS_TO_ROTORFLIGHT then
    return mode
  end
  return SYNC_MODE_OFF
end

local function setStatus(text)
  statusText = text or T.idle
end

local function getSensor()
  if sensor ~= nil then return sensor end
  if crsf and crsf.getSensor then
    sensor = crsf.getSensor()
  elseif crsf then
    sensor = {
      popFrame = function(_, ...) return crsf.popFrame(...) end,
      pushFrame = function(_, command, payload) return crsf.pushFrame(command, payload) end,
    }
  end
  return sensor
end

local function readString(data, offset)
  local parts = {}
  while data[offset] and data[offset] ~= 0 do
    parts[#parts + 1] = string.char(data[offset])
    offset = offset + 1
  end
  return table.concat(parts), offset + 1
end

local function readU32Be(data, offset)
  local value = 0
  for i = 0, 3 do
    value = value * 256 + (data[offset + i] or 0)
  end
  return value
end

local function parseChoiceField(data, offset)
  local options = {}
  local selectedIndex = 0
  local selectedLabel = nil
  local idx = 0

  local optionsStr
  optionsStr, offset = readString(data, offset)
  selectedIndex = data[offset] or 0

  for part in string_gmatch(optionsStr .. ";", "([^;]*);") do
    options[#options + 1] = part
    if idx == selectedIndex then selectedLabel = part end
    idx = idx + 1
  end

  return options, selectedIndex, selectedLabel
end

local function optionLooksLikeRatio(text)
  local lowerText = string_lower(text or "")
  if string_find(lowerText, "std", 1, true) then return true end
  if string_find(lowerText, "race", 1, true) then return true end
  if string_find(lowerText, "1:", 1, true) then return true end
  return false
end

local function optionLooksLikeRate(text)
  local lowerText = string_lower(text or "")
  if string_find(lowerText, "hz", 1, true) then return true end
  if string_find(lowerText, "dbm", 1, true) then return true end
  if lowerText:match("^%s*[a-z]+%d") then return true end
  return false
end

local function classifyChoiceField(lowerName, options)
  if string_find(lowerName, "packet rate", 1, true)
    or string_find(lowerName, "pkt rate", 1, true)
    or string_find(lowerName, "air rate", 1, true)
    or string_find(lowerName, "rf mode", 1, true) then
    return "rate"
  end

  if string_find(lowerName, "telem ratio", 1, true)
    or string_find(lowerName, "telemetry ratio", 1, true) then
    return "ratio"
  end

  local hasRateOptions = false
  local hasRatioOptions = false
  for i = 1, #options do
    if optionLooksLikeRate(options[i]) then hasRateOptions = true end
    if optionLooksLikeRatio(options[i]) then hasRatioOptions = true end
  end

  if hasRateOptions and not hasRatioOptions then return "rate" end
  if hasRatioOptions and not hasRateOptions then return "ratio" end
  return nil
end

local function recordChoiceField(kind, fieldId, name, options, selectedIndex, selectedLabel)
  local field = {id = fieldId, name = name, options = options, selectedIndex = selectedIndex, selectedLabel = selectedLabel}
  if kind == "rate" then
    rateField = field
    moduleRateLabel = selectedLabel
  elseif kind == "ratio" then
    ratioField = field
    moduleRatioLabel = selectedLabel
  end
end

local function parseTelemetryField()
  if #fieldData < 3 then return end

  local fieldTypeByte = fieldData[2] or 0
  local fieldType = fieldTypeByte % 128
  local hidden = fieldTypeByte >= 128
  if hidden or fieldType ~= TYPE_TEXT_SELECTION then return end

  local name, offset = readString(fieldData, 3)
  local options, selectedIndex, selectedLabel = parseChoiceField(fieldData, offset)
  local lowerName = string_lower(name)
  local fieldKind = classifyChoiceField(lowerName, options)
  if selectedLabel == nil or fieldKind == nil then return end

  if fieldKind == "rate" and rateField == nil then
    recordChoiceField("rate", currentField, name, options, selectedIndex, selectedLabel)
    return
  end

  if fieldKind == "ratio" and ratioField == nil then
    recordChoiceField("ratio", currentField, name, options, selectedIndex, selectedLabel)
  end
end

local function extractFirstInteger(text)
  if type(text) ~= "string" then return nil end
  for digits in string_gmatch(text, "(%d+)") do
    return tonumber(digits)
  end
  return nil
end

local function parseRatioLabel(label)
  if type(label) ~= "string" or label == "" then return nil, "unknown" end

  local lowerLabel = string_lower(label)
  if string_find(lowerLabel, "std", 1, true) then return nil, "std" end
  if string_find(lowerLabel, "race", 1, true) then return nil, "race" end
  if string_find(lowerLabel, "off", 1, true) then return nil, "off" end

  local digits = string_gmatch(lowerLabel, "1%s*:%s*(%d+)")()
  if digits then return tonumber(digits), "explicit" end

  return nil, "unknown"
end

local function resolveStdRatioForRate(packetRate)
  if type(packetRate) ~= "number" then return nil end
  return STD_TLM_RATIO_BY_PACKET_RATE[packetRate]
end

local function resolveEffectiveRatio(packetRate, ratioKind, explicitRatio)
  if ratioKind == "explicit" then return explicitRatio end
  if ratioKind == "std" or ratioKind == "race" then return resolveStdRatioForRate(packetRate) end
  return nil
end

local function formatRatioSummary(ratioLabel, ratioKind, effectiveRatio)
  if type(ratioLabel) ~= "string" or ratioLabel == "" then return "unknown" end
  if ratioKind == "std" and effectiveRatio then
    return ratioLabel .. " (effective 1:" .. tostring(effectiveRatio) .. ")"
  end
  if ratioKind == "race" and effectiveRatio then
    return ratioLabel .. " (disarmed 1:" .. tostring(effectiveRatio) .. ", armed Off)"
  end
  return ratioLabel
end

local function getRateLabelStyle(label)
  local lowerLabel = string_lower(label or "")
  local prefix = lowerLabel:match("^%s*([a-z]+)%d") or ""
  local isFull = string_find(lowerLabel, "full", 1, true) ~= nil
  return prefix, isFull
end

local function findRateTarget(field, targetRate)
  if type(field) ~= "table" or type(field.options) ~= "table" then return nil, nil end

  local currentPrefix, currentIsFull = getRateLabelStyle(field.selectedLabel)
  local haveCurrentStyle = type(field.selectedLabel) == "string" and field.selectedLabel ~= ""
  local bestIndex, bestLabel, bestScore = nil, nil, nil

  for i = 1, #field.options do
    local label = field.options[i]
    if extractFirstInteger(label) == targetRate then
      local prefix, isFull = getRateLabelStyle(label)
      local score = 0
      if haveCurrentStyle then
        if prefix == currentPrefix then score = score + 4 end
        if isFull == currentIsFull then score = score + 2 end
      else
        if prefix == "" then score = score + 2 end
        if not isFull then score = score + 1 end
      end
      if string_find(string_lower(label), "dbm", 1, true) then score = score + 1 end

      if bestScore == nil or score > bestScore then
        bestScore = score
        bestIndex = i - 1
        bestLabel = label
      end
    end
  end

  return bestIndex, bestLabel
end

local function findRatioTarget(field, targetRatio)
  if type(field) ~= "table" or type(field.options) ~= "table" then return nil, nil end
  for i = 1, #field.options do
    local label = field.options[i]
    local explicitRatio, ratioKind = parseRatioLabel(label)
    if ratioKind == "explicit" and explicitRatio == targetRatio then
      return i - 1, label
    end
  end
  return nil, nil
end

local function enqueueWrite(fieldKind, field, targetIndex, targetLabel)
  pendingWriteCount = pendingWriteCount + 1
  pendingWrites[pendingWriteCount] = {
    fieldKind = fieldKind,
    fieldId = field.id,
    fieldName = field.name,
    value = targetIndex,
    label = targetLabel,
  }
end

local function completeTask()
  state = "done"
  taskComplete = true
end

local function telemetryModeLabel(mode)
  if mode == 0 then return "native" end
  if mode == 1 then return "custom" end
  return tostring(mode)
end

local function syncRotorflightToElrs(fc)
  clearPendingWrites()

  local ratioTargetIndex, ratioTargetLabel = findRatioTarget(ratioField, fc.linkRatio)
  local rateTargetIndex, rateTargetLabel = findRateTarget(rateField, fc.linkRate)

  if ratioField and ratioTargetIndex ~= nil and ratioField.selectedIndex ~= ratioTargetIndex then
    enqueueWrite("ratio", ratioField, ratioTargetIndex, ratioTargetLabel)
  end

  -- Write rate last: changing the air rate can briefly drop and re-establish the link.
  if rateField and rateTargetIndex ~= nil and rateField.selectedIndex ~= rateTargetIndex then
    enqueueWrite("rate", rateField, rateTargetIndex, rateTargetLabel)
  end

  if pendingWriteCount > 0 then
    local actions = {}
    for i = 1, pendingWriteCount do
      local action = pendingWrites[i]
      actions[#actions + 1] = tostring(action.fieldName) .. " -> " .. tostring(action.label)
    end
    log("Syncing ELRS module to Rotorflight: " .. table.concat(actions, ", "))
    setStatus(T.writingElrs)
    state = "write"
    nextActionAt = 0
    return
  end

  if rateField == nil then
    log("ELRS sync could not find the module packet-rate field")
  elseif rateTargetIndex == nil then
    log("ELRS sync could not map Rotorflight rate " .. tostring(fc.linkRate) .. "Hz to a module option")
  end

  if ratioField == nil then
    log("ELRS sync could not find the module telemetry-ratio field")
  elseif ratioTargetIndex == nil then
    log("ELRS sync could not map Rotorflight ratio 1:" .. tostring(fc.linkRatio) .. " to a module option")
  end

  if rateField and ratioField and rateTargetIndex == rateField.selectedIndex and ratioTargetIndex == ratioField.selectedIndex then
    log("ELRS module already follows Rotorflight")
    setStatus(T.elrsMatchesRf)
  else
    setStatus(T.elrsProbeComplete)
  end

  completeTask()
end

local function syncElrsToRotorflight(fc, moduleRate, moduleRateText, moduleRatioText, ratioKind, effectiveRatio)
  if type(moduleRate) ~= "number" then
    log("ELRS sync could not determine a numeric packet rate from " .. tostring(moduleRateText or "?"))
    completeTask()
    return
  end

  if type(effectiveRatio) ~= "number" then
    log("ELRS sync could not resolve telemetry ratio " .. tostring(moduleRatioText or "?") .. " to a numeric 1:n value")
    completeTask()
    return
  end

  if type(fcConfigData) ~= "table" then
    log("ELRS sync could not update Rotorflight because the telemetry config was not read")
    completeTask()
    return
  end

  if fc.linkRate == moduleRate and fc.linkRatio == effectiveRatio then
    log("Rotorflight already follows ELRS numerically")
    setStatus(T.rfMatchesElrs)
    completeTask()
    return
  end

  fcConfigData.crsf_telemetry_link_rate = moduleRate
  fcConfigData.crsf_telemetry_link_ratio = effectiveRatio

  log("Syncing Rotorflight telemetry to match ELRS: rate=" .. tostring(moduleRateText) .. ", ratio=1:" .. tostring(effectiveRatio))
  setStatus(T.writingRotorflight)

  bus.publish("msp.request", telemetryConfig.buildWriteMessage(fcConfigData, function()
    fc.linkRate = moduleRate
    fc.linkRatio = effectiveRatio
    log("Rotorflight telemetry now matches ELRS: mode=" .. telemetryModeLabel(fc.mode) .. ", rate=" .. tostring(moduleRate) .. ", ratio=1:" .. tostring(effectiveRatio))
    setStatus(T.savingRotorflight)

    bus.publish("msp.request", eeprom.buildWriteMessage(function()
      log("Saved Rotorflight telemetry sync to EEPROM")
      setStatus(T.rotorflightUpdated)
      completeTask()
    end, function()
      log("EEPROM write failed after ELRS telemetry sync")
      setStatus(T.rotorflightSaveFailed)
      completeTask()
    end))
  end, function(reason)
    log("Failed to sync Rotorflight telemetry from ELRS (" .. tostring(reason) .. ")")
    setStatus(T.rotorflightWriteFailed)
    completeTask()
  end))
end

local function finalize()
  local syncMode = getSyncMode()

  if rateField then moduleRateLabel = rateField.selectedLabel end
  if ratioField then moduleRatioLabel = ratioField.selectedLabel end

  local moduleRate = extractFirstInteger(moduleRateLabel)
  local explicitRatio, ratioKind = parseRatioLabel(moduleRatioLabel)
  local effectiveRatio = resolveEffectiveRatio(moduleRate, ratioKind, explicitRatio)
  local ratioSummary = formatRatioSummary(moduleRatioLabel, ratioKind, effectiveRatio)

  linkConfig = {
    packetRateLabel = moduleRateLabel,
    packetRate = moduleRate,
    telemetryRatioLabel = moduleRatioLabel,
    telemetryRatio = effectiveRatio,
    telemetryRatioEffective = effectiveRatio,
    telemetryRatioDisarmed = ratioKind == "race" and effectiveRatio or nil,
    telemetryRatioExplicit = explicitRatio,
    telemetryRatioKind = ratioKind,
  }

  if moduleRateLabel and moduleRatioLabel then
    log("ELRS module link: rate=" .. tostring(moduleRateLabel) .. ", ratio=" .. ratioSummary)
  else
    log("ELRS module link settings were not fully discovered (rate=" .. tostring(moduleRateLabel or "?") .. ", ratio=" .. tostring(moduleRatioLabel or "?") .. ")")
  end

  if fcConfig then
    log("Rotorflight CRSF telemetry: mode=" .. telemetryModeLabel(fcConfig.mode) .. ", rate=" .. tostring(fcConfig.linkRate) .. ", ratio=1:" .. tostring(fcConfig.linkRatio))
  end

  if syncMode == SYNC_MODE_OFF then
    log("ELRS telemetry sync is Off; leaving both sides unchanged")
    setStatus(T.probeComplete)
    completeTask()
    return
  end

  log("ELRS telemetry sync mode: " .. syncModeLabel(syncMode))

  if syncMode == SYNC_MODE_ELRS_TO_ROTORFLIGHT then
    syncElrsToRotorflight(fcConfig, moduleRate, moduleRateLabel, moduleRatioLabel, ratioKind, effectiveRatio)
    return
  end

  syncRotorflightToElrs(fcConfig)
end

local function shouldSkip()
  if system and system.getVersion and system.getVersion().simulation == true then return true end
  if session.mspTransport ~= "crsf" then return true end
  if not (crsf and (crsf.getSensor or crsf.popFrame)) then return true end
  return false
end

-- Deliberately does NOT touch fcConfigData/fcConfig/fcConfigRequested --
-- unlike the module-side probe state below (re-probed fresh on every
-- start(), since the module itself could have changed), the Rotorflight
-- telemetry-config read is cheap to keep warm across repeated probe/sync
-- presses within the same connection (see ensureFcConfig() below); it's
-- only invalidated on an actual disconnect (see the session.update
-- subscriber above).
local function resetState()
  taskComplete = false
  probeStartedAt = 0
  nextActionAt = 0
  state = "idle"
  sensor = nil
  deviceId = CRSF_ADDRESS_CRSF_TRANSMITTER
  fieldCount = 0
  currentField = 1
  currentChunk = 0
  expectedChunksRemain = -1
  rateField = nil
  ratioField = nil
  moduleRateLabel = nil
  moduleRatioLabel = nil
  clearFieldData()
  clearPendingWrites()
end

-- Fetches Rotorflight's own CRSF telemetry config (mode/rate/ratio) once
-- per connection and caches it -- `onReady()` fires immediately if already
-- cached, or once the read completes; `onError()` (optional) only fires
-- on an actual read failure, never for an already-cached hit.
local function ensureFcConfig(onReady, onError)
  if fcConfig then
    onReady()
    return
  end
  if fcConfigRequested then return end
  fcConfigRequested = true

  bus.publish("msp.request", telemetryConfig.buildReadConfigMessage(function(data)
    fcConfigRequested = false
    fcConfigData = data
    fcConfig = {mode = data.crsf_telemetry_mode, linkRate = data.crsf_telemetry_link_rate, linkRatio = data.crsf_telemetry_link_ratio}
    onReady()
  end, function()
    fcConfigRequested = false
    if onError then onError() end
  end))
end

-- Safe to call any time (e.g. the page's own onSession/open handler) to
-- warm the Rotorflight summary before a probe/sync is ever started --
-- silently does nothing if not connected via CRSF, already cached, or
-- already in flight.
function elrslink.refreshFcConfig()
  if not session.connected or session.mspTransport ~= "crsf" then return end
  ensureFcConfig(function() end, function() end)
end

local function handleDeviceInfo(data)
  if data[2] ~= CRSF_ADDRESS_CRSF_TRANSMITTER then return end

  local _, offset = readString(data, 3)
  local serial = readU32Be(data, offset)
  if serial ~= ELRS_SERIAL_ID then return end

  deviceId = data[2]
  fieldCount = data[offset + 12] or 0
  currentField = 1
  currentChunk = 0
  expectedChunksRemain = -1
  clearFieldData()
  state = "read"
  nextActionAt = 0
  setStatus(T.readingModule)

  if fieldCount <= 0 then finalize() end
end

local function handleParameterEntry(data)
  if state ~= "read" then return end
  if data[2] ~= deviceId or data[3] ~= currentField then
    currentChunk = 0
    expectedChunksRemain = -1
    clearFieldData()
    return
  end

  local chunksRemain = data[4] or 0
  if expectedChunksRemain >= 0 and #fieldData > 0 and chunksRemain ~= expectedChunksRemain then
    currentChunk = 0
    expectedChunksRemain = -1
    clearFieldData()
    nextActionAt = 0
    return
  end
  expectedChunksRemain = chunksRemain - 1

  for i = 5, #data do
    fieldData[#fieldData + 1] = data[i]
  end

  if chunksRemain > 0 then
    currentChunk = currentChunk + 1
    nextActionAt = 0
    return
  end

  parseTelemetryField()

  currentField = currentField + 1
  currentChunk = 0
  expectedChunksRemain = -1
  clearFieldData()
  nextActionAt = 0

  if (moduleRateLabel and moduleRatioLabel) or currentField > fieldCount then
    finalize()
  end
end

local function processIncomingFrames()
  local crsfSensor = getSensor()
  if not crsfSensor then return end

  while true do
    local command, data = crsfSensor:popFrame(CRSF_FRAMETYPE_DEVICE_INFO, CRSF_FRAMETYPE_PARAMETER_SETTINGS_ENTRY)
    if command == nil then break end

    if command == CRSF_FRAMETYPE_DEVICE_INFO then
      handleDeviceInfo(data)
    elseif command == CRSF_FRAMETYPE_PARAMETER_SETTINGS_ENTRY then
      handleParameterEntry(data)
    end
  end
end

function elrslink.wakeup()
  local now = os_clock()

  if taskComplete then return end

  if shouldSkip() then
    setStatus(T.requiresActiveLink)
    taskComplete = true
    return
  end

  if state == "idle" then
    setStatus(T.waitingRotorflightConfig)
    ensureFcConfig(function()
      probeStartedAt = os_clock()
      state = "ping"
      nextActionAt = 0
      log("Starting ELRS link probe")
      setStatus(T.pingingModule)
    end, function()
      log("Skipping ELRS link probe because Rotorflight telemetry config could not be read")
      setStatus(T.rotorflightConfigNotReady)
      taskComplete = true
    end)
    return
  end

  if not fcConfig then return end

  processIncomingFrames()
  if taskComplete then return end

  if state == "ping" and probeStartedAt > 0 and (now - probeStartedAt) >= DISCOVERY_TIMEOUT_SECONDS then
    log("No ELRS TX module responded to the CRSF parameter probe")
    setStatus(T.noModule)
    taskComplete = true
    return
  end

  if state == "read" and probeStartedAt > 0 and (now - probeStartedAt) >= READ_TIMEOUT_MAX_SECONDS then
    log("ELRS link probe timed out while reading module parameters")
    setStatus(T.readTimeout)
    finalize()
    return
  end

  local crsfSensor = getSensor()
  if not crsfSensor then
    log("CRSF sensor unavailable for ELRS link probe")
    setStatus(T.sensorUnavailable)
    taskComplete = true
    return
  end

  if now < nextActionAt then return end

  if state == "ping" then
    crsfSensor:pushFrame(CRSF_FRAMETYPE_DEVICE_PING, {CRSF_ADDRESS_BROADCAST, CRSF_ADDRESS_RADIO_TRANSMITTER})
    nextActionAt = now + PING_RETRY_SECONDS
    return
  end

  if state == "read" then
    crsfSensor:pushFrame(CRSF_FRAMETYPE_PARAMETER_READ, {deviceId, CRSF_ADDRESS_ELRS_LUA, currentField, currentChunk})
    nextActionAt = now + READ_TIMEOUT_SECONDS
    return
  end

  if state == "write" then
    local action = pendingWrites[pendingWriteIndex]
    if not action then
      completeTask()
      return
    end

    crsfSensor:pushFrame(CRSF_FRAMETYPE_PARAMETER_WRITE, {deviceId, CRSF_ADDRESS_ELRS_LUA, action.fieldId, action.value})
    log("ELRS sync: set " .. tostring(action.fieldName) .. " to " .. tostring(action.label))
    setStatus(T.writingPrefix .. tostring(action.fieldName))

    if action.fieldKind == "rate" and rateField then
      rateField.selectedIndex = action.value
      rateField.selectedLabel = action.label
      moduleRateLabel = action.label
    elseif action.fieldKind == "ratio" and ratioField then
      ratioField.selectedIndex = action.value
      ratioField.selectedLabel = action.label
      moduleRatioLabel = action.label
    end

    pendingWriteIndex = pendingWriteIndex + 1
    if pendingWriteIndex > pendingWriteCount then
      if action.fieldKind == "rate" then
        log("ELRS sync requested a packet-rate change; the link may reconnect briefly")
      end
      setStatus(T.elrsUpdated)
      completeTask()
    else
      nextActionAt = now + WRITE_DELAY_SECONDS
    end
  end
end

function elrslink.start(mode)
  manualSyncMode = normalizeSyncMode(mode)
  resetState()

  if system and system.getVersion and system.getVersion().simulation == true then
    setStatus(T.unavailableSimulation)
    taskComplete = true
    return false
  end

  if not session.connected then
    setStatus(T.connectFirst)
    taskComplete = true
    return false
  end

  if session.mspTransport ~= "crsf" then
    setStatus(T.requiresCrsf)
    taskComplete = true
    return false
  end

  if session.isArmed == true then
    setStatus(T.unavailableArmed)
    taskComplete = true
    return false
  end

  if manualSyncMode == SYNC_MODE_OFF then
    setStatus(T.probeRequested)
  else
    setStatus(T.syncRequested .. syncModeLabel(manualSyncMode))
  end

  return true
end

function elrslink.reset()
  manualSyncMode = SYNC_MODE_OFF
  resetState()
  taskComplete = true
  setStatus(T.idle)
  linkConfig = nil
end

function elrslink.isRunning()
  return not taskComplete
end

function elrslink.getStatus()
  return statusText
end

function elrslink.getMode()
  return manualSyncMode
end

function elrslink.getModeLabel()
  return syncModeLabel(manualSyncMode)
end

-- {mode, linkRate, linkRatio} from the last successful Rotorflight
-- telemetry-config read this session, or nil if none has completed yet.
function elrslink.getFcSummary()
  return fcConfig
end

-- {packetRateLabel, packetRate, telemetryRatioLabel, telemetryRatio,
-- telemetryRatioEffective, telemetryRatioDisarmed, telemetryRatioExplicit,
-- telemetryRatioKind} from the last completed probe, or nil if none has
-- completed yet.
function elrslink.getLinkSummary()
  return linkConfig
end

elrslink.MODE_PROBE = SYNC_MODE_OFF
elrslink.MODE_ROTORFLIGHT_TO_ELRS = SYNC_MODE_ROTORFLIGHT_TO_ELRS
elrslink.MODE_ELRS_TO_ROTORFLIGHT = SYNC_MODE_ELRS_TO_ROTORFLIGHT

resetState()
taskComplete = true
setStatus(T.idle)

package.loaded["rfsuite.lib.elrslink_task"] = elrslink
return elrslink
