-- Message-builders for the small set of MSP reads/writes that establish
-- "who am I talking to" once a connection is detected: FC version, MCU
-- UID, craft name, and an RTC clock sync. Stateless: every function
-- takes/returns plain tables, nothing is cached here.
--
-- Used by tasks/session.lua, which enqueues these directly on the mspQueue
-- it already holds (it's part of the same background-task subsystem, see
-- tasks/background.lua) -- it does not need to go through lib/bus.lua's
-- "msp.request" topic for its own internal MSP traffic; that topic is for
-- other subsystems (system tool, dashboard widget) to reach the queue.
--
-- This mirrors a slim subset of rotorflight-lua-ethos-suite's onconnect/
-- postconnect task manifests: fcversion, uid, craftname (postconnect), and
-- clocksync (postconnect). Deliberately excludes rxmap and syncstats,
-- which depend on rx-channel-consuming features and a model-preferences
-- file subsystem this lite rebuild doesn't have yet -- and excludes
-- flightmode/modelpreferences/sensorstats/timer/rateprofile, which in the
-- original are local bookkeeping with no MSP traffic at all.

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local msp_handshake = {}

-- FC_VERSION (cmd 3): version_major/minor/patch, each U8.
msp_handshake.FC_VERSION_READ_COMMAND = 3

function msp_handshake.buildFcVersionReadMessage(onData, onError)
  return {
    command = msp_handshake.FC_VERSION_READ_COMMAND,
    processReply = function(_, buf)
      local major = mspcodec.readU8(buf)
      local minor = mspcodec.readU8(buf)
      local patch = mspcodec.readU8(buf)
      -- Rotorflight encodes its own version on top of the Betaflight-style
      -- FC_VERSION fields, offset by {2, 3, 0} -- see the original suite's
      -- tasks/events/onconnect/tasks/fcversion.lua (readRfVersion).
      local rfMajor, rfMinor = major - 2, minor - 3
      local rfVersion
      if rfMajor >= 0 and rfMinor >= 0 then
        rfVersion = string.format("%d.%d.%d", rfMajor, rfMinor, patch)
      end
      onData({
        fcVersion = string.format("%d.%d.%d", major, minor, patch),
        rfVersion = rfVersion,
      })
    end,
    errorHandler = onError,
    simulatorResponse = {4, 5, 1},
  }
end

-- UID (cmd 160): three U32s, rendered as a 24-hex-char MCU id (each word
-- little-endian, matching the original suite's u32_to_hex_le).
msp_handshake.UID_READ_COMMAND = 160

local function u32ToHexLE(value)
  local b1 = value % 256
  local b2 = math.floor(value / 256) % 256
  local b3 = math.floor(value / 65536) % 256
  local b4 = math.floor(value / 16777216) % 256
  return string.format("%02x%02x%02x%02x", b1, b2, b3, b4)
end

function msp_handshake.buildUidReadMessage(onData, onError)
  return {
    command = msp_handshake.UID_READ_COMMAND,
    processReply = function(_, buf)
      local id0 = mspcodec.readU32(buf)
      local id1 = mspcodec.readU32(buf)
      local id2 = mspcodec.readU32(buf)
      onData(u32ToHexLE(id0) .. u32ToHexLE(id1) .. u32ToHexLE(id2))
    end,
    errorHandler = onError,
    simulatorResponse = {43, 0, 34, 0, 9, 81, 51, 52, 52, 56, 53, 49},
  }
end

-- NAME (cmd 10): a short ASCII string, NUL-terminated or up to 16 chars.
msp_handshake.NAME_READ_COMMAND = 10
local NAME_MAX_LENGTH = 16

function msp_handshake.buildNameReadMessage(onData, onError)
  return {
    command = msp_handshake.NAME_READ_COMMAND,
    processReply = function(_, buf)
      local name = ""
      for i = 1, NAME_MAX_LENGTH do
        local ch = buf[i]
        if ch == nil or ch == 0 then break end
        name = name .. string.char(ch)
      end
      onData(name)
    end,
    errorHandler = onError,
    simulatorResponse = {80, 105, 108, 111, 116}, -- "Pilot"
  }
end

-- RTC (cmd 246, write): sync the FC's clock to the radio's current time.
msp_handshake.RTC_WRITE_COMMAND = 246

function msp_handshake.buildRtcSyncMessage(onSynced, onError)
  local payload = {}
  mspcodec.writeU32(payload, os.time())
  mspcodec.writeU16(payload, 0)
  return {
    command = msp_handshake.RTC_WRITE_COMMAND,
    payload = payload,
    isWrite = true,
    processReply = function()
      if onSynced then onSynced() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

return msp_handshake
