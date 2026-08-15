-- MSP_FLIGHT_STATS helper (cmd 14 read / 15 write).

if package.loaded["rfsuite.lib.msp_flight_stats"] then
  return package.loaded["rfsuite.lib.msp_flight_stats"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 14
local WRITE_COMMAND = 15

local SIMULATOR_RESPONSE = {
  123, 1, 0, 0, -- flightcount
  0, 1, 2, 0, -- totalflighttime
  0, 0, 0, 0, -- totaldistance
  15, -- minarmedtime
}

local msp_flight_stats = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
}

function msp_flight_stats.defaultStats()
  return {
    flightcount = 0,
    totalflighttime = 0,
    totaldistance = 0,
    minarmedtime = 0,
  }
end

function msp_flight_stats.clone(stats)
  stats = stats or {}
  return {
    flightcount = tonumber(stats.flightcount or 0) or 0,
    totalflighttime = tonumber(stats.totalflighttime or 0) or 0,
    totaldistance = tonumber(stats.totaldistance or 0) or 0,
    minarmedtime = tonumber(stats.minarmedtime or 0) or 0,
  }
end

function msp_flight_stats.decode(buf)
  buf.offset = 1
  return {
    flightcount = mspcodec.readU32(buf),
    totalflighttime = mspcodec.readU32(buf),
    totaldistance = mspcodec.readU32(buf),
    minarmedtime = mspcodec.readS8(buf),
  }
end

function msp_flight_stats.same(a, b)
  a = a or {}
  b = b or {}
  return (a.flightcount or 0) == (b.flightcount or 0)
    and (a.totalflighttime or 0) == (b.totalflighttime or 0)
end

function msp_flight_stats.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_flight_stats.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_flight_stats.buildWriteMessage(stats, onWritten, onError)
  stats = msp_flight_stats.clone(stats)
  local payload = {}
  mspcodec.writeU32(payload, stats.flightcount)
  mspcodec.writeU32(payload, stats.totalflighttime)
  mspcodec.writeU32(payload, stats.totaldistance)
  mspcodec.writeS8(payload, stats.minarmedtime)
  return {
    command = WRITE_COMMAND,
    payload = payload,
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_flight_stats"] = msp_flight_stats
return msp_flight_stats
