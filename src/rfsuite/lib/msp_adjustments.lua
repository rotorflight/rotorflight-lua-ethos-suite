-- MSP helpers for Controls -> Adjustments.
--
-- ADJUSTMENT_RANGES reads fixed 14-byte range records. The page uses the
-- indexed read command for reliability over telemetry, then writes changed
-- slots with slot index + that same record shape.

if package.loaded["rfsuite.lib.msp_adjustments"] then
  return package.loaded["rfsuite.lib.msp_adjustments"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 52
local WRITE_COMMAND = 53
local SLOT_READ_COMMAND = 156
local RANGE_BYTES = 14
local RANGE_COUNT = 42
local SIMULATOR_RESPONSE = {
  0, -- function
  0, 216, 40, -- enable channel/range 1300..1700
  0, 216, 40, -- adjustment channel/range 1
  216, 40, -- adjustment range 2
  0, 0, -- min
  100, 0, -- max
  0, -- step
}

-- The simulator's profile switch: the PID profile (slot 1) and the rate profile
-- (slot 2) on CH7, profiles 1 to 3, 1000 to 2000 us. Other slots are empty.
local function simulatedRange(index)
  local system_sim = system and system.getVersion and system.getVersion().simulation == true
  if system_sim and (index == 1 or index == 2) then
    local function_id = index == 1 and 2 or 1
    return {
      function_id, 255,        -- function (PID profile, rate profile), always on
      0, 0,                    -- enable range 1500..1500
      1,                       -- adjustment channel: CH7
      156, 100,                -- adjustment range 1: 1000..2000 us
      0, 0,                    -- adjustment range 2
      1, 0,                    -- min 1
      3, 0,                    -- max 3
      0,                       -- step
    }
  end
  return SIMULATOR_RESPONSE
end

local function clamp(value, minValue, maxValue)
  value = tonumber(value) or minValue
  if value < minValue then return minValue end
  if value > maxValue then return maxValue end
  return value
end

local function stepToUs(step)
  return 1500 + ((tonumber(step) or 0) * 5)
end

local function usToStep(value)
  return clamp(((tonumber(value) or 1500) - 1500) / 5, -125, 125)
end

local function toS8Byte(value)
  local v = clamp(math.floor((tonumber(value) or 0) + 0.5), -128, 127)
  if v < 0 then return v + 256 end
  return v
end

local function writeRange(payload, range)
  range = range or {}
  local enaRange = range.enaRange or {}
  local adjRange1 = range.adjRange1 or {}
  local adjRange2 = range.adjRange2 or {}

  mspcodec.writeU8(payload, range.adjFunction or 0)
  mspcodec.writeU8(payload, range.enaChannel or 0)
  mspcodec.writeU8(payload, toS8Byte(usToStep(enaRange.start)))
  mspcodec.writeU8(payload, toS8Byte(usToStep(enaRange["end"])))
  mspcodec.writeU8(payload, range.adjChannel or 0)
  mspcodec.writeU8(payload, toS8Byte(usToStep(adjRange1.start)))
  mspcodec.writeU8(payload, toS8Byte(usToStep(adjRange1["end"])))
  mspcodec.writeU8(payload, toS8Byte(usToStep(adjRange2.start)))
  mspcodec.writeU8(payload, toS8Byte(usToStep(adjRange2["end"])))
  mspcodec.writeS16(payload, range.adjMin or 0)
  mspcodec.writeS16(payload, range.adjMax or 100)
  mspcodec.writeU8(payload, range.adjStep or 0)
end

local function defaultRange()
  return {
    adjFunction = 0,
    enaChannel = 0,
    enaRange = {start = 1300, ["end"] = 1700},
    adjChannel = 0,
    adjRange1 = {start = 1300, ["end"] = 1700},
    adjRange2 = {start = 1300, ["end"] = 1700},
    adjMin = 0,
    adjMax = 100,
    adjStep = 0,
  }
end

local function readRange(buf)
  return {
    adjFunction = mspcodec.readU8(buf),
    enaChannel = mspcodec.readU8(buf),
    enaRange = {start = stepToUs(mspcodec.readS8(buf)), ["end"] = stepToUs(mspcodec.readS8(buf))},
    adjChannel = mspcodec.readU8(buf),
    adjRange1 = {start = stepToUs(mspcodec.readS8(buf)), ["end"] = stepToUs(mspcodec.readS8(buf))},
    adjRange2 = {start = stepToUs(mspcodec.readS8(buf)), ["end"] = stepToUs(mspcodec.readS8(buf))},
    adjMin = mspcodec.readS16(buf),
    adjMax = mspcodec.readS16(buf),
    adjStep = mspcodec.readU8(buf),
  }
end

local msp_adjustments = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  SLOT_READ_COMMAND = SLOT_READ_COMMAND,
  RANGE_COUNT = RANGE_COUNT,
}

function msp_adjustments.defaultRange()
  return defaultRange()
end

function msp_adjustments.decode(buf)
  buf.offset = 1
  local ranges = {}
  local count = math.floor(#buf / RANGE_BYTES)
  if count > RANGE_COUNT then count = RANGE_COUNT end

  for i = 1, count do
    ranges[i] = readRange(buf)
  end

  return {ranges = ranges}
end

function msp_adjustments.decodeRange(buf)
  buf.offset = 1
  if #buf < RANGE_BYTES then return defaultRange() end
  return readRange(buf)
end

function msp_adjustments.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_adjustments.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_adjustments.buildReadSlotMessage(index, onData, onError)
  return {
    command = SLOT_READ_COMMAND,
    payload = {clamp((index or 1) - 1, 0, RANGE_COUNT - 1)},
    processReply = function(_, buf)
      onData(msp_adjustments.decodeRange(buf))
    end,
    errorHandler = onError,
    simulatorResponse = simulatedRange(index),
  }
end

function msp_adjustments.buildWriteMessage(index, range, onWritten, onError)
  local payload = {clamp((index or 1) - 1, 0, RANGE_COUNT - 1)}
  writeRange(payload, range)
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

package.loaded["rfsuite.lib.msp_adjustments"] = msp_adjustments
return msp_adjustments
