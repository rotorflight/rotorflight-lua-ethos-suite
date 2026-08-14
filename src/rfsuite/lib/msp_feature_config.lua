-- Schema + message-builders for the MSP_FEATURE_CONFIG /
-- MSP_SET_FEATURE_CONFIG command pair (cmd 36 read / 37 write) --
-- app/pages/configuration.lua's GPS/LED Strip/CMS feature toggles.
--
-- Confirmed directly against rotorflight-firmware's own wire handlers
-- (src/main/msp/msp.c): both directions are a single U32
-- (`enabledFeatures`), a plain bitmask -- one bit per feature, symmetric
-- read/write, no partial-write asymmetry the way lib/msp_advanced_config.lua
-- has. Cross-checked against rotorflight-lua-ethos-suite's own
-- tasks/scheduler/msp/api/FEATURE_CONFIG.lua, whose own FEATURES_BITMAP
-- lists every bit position -- only the 3 this rebuild's Configuration
-- page actually exposes are named here (GPS, LED Strip, CMS); the rest
-- of that ~30-bit table isn't ported speculatively, same "only what's
-- actually used" convention as lib/telemetry_sensors.lua's own header
-- comment.
--
-- Arithmetic bit ops (getBit/setBit), not native bitwise operators --
-- same convention as app/field_layout.lua's own getBit()/setBit() (see
-- its comment: works unmodified regardless of the Lua version's
-- bitwise-operator support). Not reusing field_layout.lua's copies
-- directly -- this is a plain data-layer codec, field_layout.lua is a UI
-- layer above app/page_runtime.lua that this module has no reason to
-- depend on.

-- Self-caches via package.loaded (same mechanism lib/bus.lua uses) --
-- app/pages/configuration.lua reloads fresh via loadfile() on every
-- open, so without caching this was rebuilt on every navigation too. See
-- lib/msp_pid_tuning.lua's own comment for the full reasoning (added
-- after a live memory investigation, see AGENTS.md's "Memory stats
-- printing" section).
if package.loaded["rfsuite.lib.msp_feature_config"] then
  return package.loaded["rfsuite.lib.msp_feature_config"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 36
local WRITE_COMMAND = 37

-- Bit positions within `enabledFeatures`, matching rotorflight-lua-ethos-
-- suite's own FEATURE_CONFIG.lua FEATURES_BITMAP (gps=7, telemetry=10,
-- led_strip=16, cms=19, freq_sensor=28) -- standard
-- Betaflight/Rotorflight feature-flag layout.
local FEATURE_BIT_GPS = 7
local FEATURE_BIT_TELEMETRY = 10
local FEATURE_BIT_LED_STRIP = 16
local FEATURE_BIT_CMS = 19
local FEATURE_BIT_FREQ_SENSOR = 28

local function getBit(value, bit)
  return math.floor((value or 0) / (2 ^ bit)) % 2 == 1
end

local function setBit(value, bit, enabled)
  value = value or 0
  local mask = 2 ^ bit
  local currentlySet = getBit(value, bit)
  if enabled and not currentlySet then
    return value + mask
  elseif not enabled and currentlySet then
    return value - mask
  end
  return value
end

local SIMULATOR_RESPONSE = {0, 0, 0, 0} -- enabledFeatures = 0

local msp_feature_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FEATURE_BIT_GPS = FEATURE_BIT_GPS,
  FEATURE_BIT_TELEMETRY = FEATURE_BIT_TELEMETRY,
  FEATURE_BIT_LED_STRIP = FEATURE_BIT_LED_STRIP,
  FEATURE_BIT_CMS = FEATURE_BIT_CMS,
  FEATURE_BIT_FREQ_SENSOR = FEATURE_BIT_FREQ_SENSOR,
  getBit = getBit,
  setBit = setBit,
}

function msp_feature_config.decode(buf)
  buf.offset = 1
  return {enabledFeatures = mspcodec.readU32(buf)}
end

function msp_feature_config.encode(data)
  local payload = {}
  mspcodec.writeU32(payload, (data and data.enabledFeatures) or 0)
  return payload
end

-- Builds a ready-to-publish message for lib/bus.lua's "msp.request" topic.
-- `onData(data)` is called with `{enabledFeatures = <U32>}` once the
-- reply arrives; `onError(reason)` (optional) on failure.
function msp_feature_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_feature_config.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

-- Builds a ready-to-publish write message. `onWritten()` (optional) is
-- called once the FC acknowledges the write; `onError(reason)` on
-- failure.
function msp_feature_config.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_feature_config.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_feature_config"] = msp_feature_config
return msp_feature_config
