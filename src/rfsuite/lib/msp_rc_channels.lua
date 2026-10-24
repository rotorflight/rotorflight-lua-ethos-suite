-- Live RC channels, read-only:
--   MSP_RC (cmd 105)          rcInput[], by function after the RX map
--                             (roll, pitch, yaw, collective, throttle, AUX1...), us
--   MSP_RC_COMMAND (cmd 113)  rcCommand[], the stick commands the mixer gets
--                             (roll, pitch, yaw, collective, throttle), int16,
--                             +-500 at full stick
--   MSP_RX_CHANNELS (cmd 114) rcRawChannel[], as the receiver sends them, us
--
-- Wire layout from rotorflight-firmware src/main/msp/msp.c: one U16 per
-- channel and nothing else, so the count is the reply length / 2.
--
-- decode() fills a caller's table in place (out[1] is channel 0), so a page
-- polling this several times a second does not allocate a table per reply.

if package.loaded["rfsuite.lib.msp_rc_channels"] then
  return package.loaded["rfsuite.lib.msp_rc_channels"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local M = {
  RC_COMMAND = 105,
  RC_COMMAND_DATA = 113,
  RX_CHANNELS_COMMAND = 114,
}

local function simulated(values)
  local out = {}
  for i, v in ipairs(values) do
    if v < 0 then v = v + 65536 end
    out[2 * i - 1] = v % 256
    out[2 * i] = math.floor(v / 256)
  end
  return out
end

-- Sticks centred, throttle low, AUX low.
local SIM_CHANNELS = simulated({1500, 1500, 1500, 1500, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000})
local SIM_COMMAND = simulated({0, 0, 0, 0, -500})

-- Only in the simulator (read once, at load): the four sticks swing about
-- centre, the throttle sweeps low to high, each at its own slow period.
local SIMULATED = (system and system.getVersion and system.getVersion().simulation == true) or false
local SWEEP_PERIOD = {4, 5, 6, 7}
local function sweepSticks(now)
  local out = {}
  for i = 1, 4 do
    out[i] = math.floor(500 * math.sin(2 * math.pi * now / SWEEP_PERIOD[i]) + 0.5)
  end
  out[5] = math.floor(500 * (1 + math.sin(2 * math.pi * now / 8)) + 0.5)
  return out
end
local function sweepChannels(now)
  local sticks = sweepSticks(now)
  local values = {}
  for i = 1, 4 do values[i] = 1500 + sticks[i] end
  values[5] = 1000 + sticks[5]
  for i = 6, 12 do values[i] = 1000 end
  return simulated(values)
end
local function sweepCommand(now)
  local sticks = sweepSticks(now)
  return simulated({sticks[1], sticks[2], sticks[3], sticks[4], sticks[5] - 500})
end

-- Returns the channel count; entries past it are cleared.
function M.decode(buf, out, signed)
  buf.offset = 1
  local count = math.floor(#buf / 2)
  for i = 1, count do
    out[i] = signed and mspcodec.readS16(buf) or mspcodec.readU16(buf)
  end
  for i = #out, count + 1, -1 do out[i] = nil end
  return count
end

-- command: M.RC_COMMAND, M.RC_COMMAND_DATA or M.RX_CHANNELS_COMMAND.
-- onData(out, count).
function M.buildReadMessage(command, out, onData, onError)
  local signed = command == M.RC_COMMAND_DATA
  return {
    command = command,
    processReply = function(_, buf)
      local count = M.decode(buf, out, signed)
      if onData then onData(out, count) end
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATED and (signed and sweepCommand(os.clock()) or sweepChannels(os.clock()))
      or (signed and SIM_COMMAND or SIM_CHANNELS),
  }
end

package.loaded["rfsuite.lib.msp_rc_channels"] = M
return M
