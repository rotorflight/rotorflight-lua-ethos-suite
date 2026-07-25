-- Schema + message-builders for MSP_TELEMETRY_CONFIG /
-- MSP_SET_TELEMETRY_CONFIG (cmd 73 read / 74 write).
--
-- The background task still uses buildReadMessage() exactly as before: it
-- returns only the 40 sensor slot values so lib/frsky_sensors.lua can
-- create/label the Ethos sensors that will appear on the wire. The Setup
-- -> Telemetry page uses the full-config read/write helpers added below,
-- preserving the header bytes while editing just the slot assignments.
--
-- Wire layout: telemetry_inverted(U8), halfDuplex(U8), enableSensors(U32),
-- pinSwap(U8), crsf_telemetry_mode(U8), crsf_telemetry_link_rate(U16),
-- crsf_telemetry_link_ratio(U16), then telem_sensor_slot_1..40 (U8 each) --
-- 12 header bytes + 40 slot bytes. Matches
-- rotorflight-lua-ethos-suite's tasks/scheduler/msp/api/TELEMETRY_CONFIG.lua
-- field order. That original only includes the pinSwap/crsf_*/slot fields
-- for API >= 12.0.8; this rebuild's floor is >= 12.09 (see AGENTS.md), so
-- they're unconditionally present here -- no version-gated field list.
--
-- telemetry_inverted/halfDuplex/enableSensors/pinSwap have no consumer yet
-- and just round-trip unchanged through the Setup -> Telemetry page's
-- load/save; crsf_telemetry_mode does have one -- see app/pages/telemetry.lua's
-- beforeSave, which forces it to CUSTOM so a CRSF receiver actually sends
-- the slots this page writes.

local mspcodec = assert(loadfile("lib/mspcodec.lua"))()

if package.loaded["rfsuite.lib.msp_telemetry_config"] then
  return package.loaded["rfsuite.lib.msp_telemetry_config"]
end

local READ_COMMAND = 73
local WRITE_COMMAND = 74
local SLOT_COUNT = 40
local HEADER_BYTES = 12 -- see wire layout above

-- Fixture reply used automatically in the Ethos simulator (see
-- tasks/msp/queue.lua): zeroed header (unused, see above) plus a handful
-- of non-zero slots (95/96/97 -> PID/Rate/Battery profile, per
-- lib/frsky_sid_lookup.lua) so the simulator exercises the create/rename
-- path without claiming to mirror any particular real setup.
local SIMULATOR_RESPONSE = {
  0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  95, 96, 97,
}
for i = #SIMULATOR_RESPONSE + 1, HEADER_BYTES + SLOT_COUNT do
  SIMULATOR_RESPONSE[i] = 0
end

local msp_telemetry_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  SLOT_COUNT = SLOT_COUNT,
}

local function decodeFull(buf)
  buf.offset = 1
  local data = {
    telemetry_inverted = mspcodec.readU8(buf),
    halfDuplex = mspcodec.readU8(buf),
    enableSensors = mspcodec.readU32(buf),
    pinSwap = mspcodec.readU8(buf),
    crsf_telemetry_mode = mspcodec.readU8(buf),
    crsf_telemetry_link_rate = mspcodec.readU16(buf),
    crsf_telemetry_link_ratio = mspcodec.readU16(buf),
    slots = {},
  }
  for i = 1, SLOT_COUNT do
    data.slots[i] = mspcodec.readU8(buf)
  end
  return data
end

local function encodeFull(data)
  local payload = {}
  data = data or {}
  mspcodec.writeU8(payload, data.telemetry_inverted or 0)
  mspcodec.writeU8(payload, data.halfDuplex or 0)
  mspcodec.writeU32(payload, data.enableSensors or 0)
  mspcodec.writeU8(payload, data.pinSwap or 0)
  mspcodec.writeU8(payload, data.crsf_telemetry_mode or 0)
  mspcodec.writeU16(payload, data.crsf_telemetry_link_rate or 0)
  mspcodec.writeU16(payload, data.crsf_telemetry_link_ratio or 0)
  local slots = data.slots or {}
  for i = 1, SLOT_COUNT do
    mspcodec.writeU8(payload, slots[i] or 0)
  end
  return payload
end

-- Returns a plain array of 40 slot values (FC-internal sensor-ID indices,
-- 0 = slot unused) -- see lib/frsky_sid_lookup.lua for how these map to
-- actual S.Port appIds.
function msp_telemetry_config.decode(buf)
  return decodeFull(buf).slots
end

msp_telemetry_config.decodeFull = decodeFull
msp_telemetry_config.encodeFull = encodeFull

function msp_telemetry_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_telemetry_config.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_telemetry_config.buildReadConfigMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(decodeFull(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_telemetry_config.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = encodeFull(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_telemetry_config"] = msp_telemetry_config
return msp_telemetry_config
