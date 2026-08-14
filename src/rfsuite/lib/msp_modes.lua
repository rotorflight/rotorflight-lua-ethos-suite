-- MSP helpers for Controls -> Modes.
--
-- Reads BOXIDS/BOXNAMES/MODE_RANGES/MODE_RANGES_EXTRA and writes one
-- SET_MODE_RANGE slot at a time. Stateless and self-cached.

if package.loaded["rfsuite.lib.msp_modes"] then
  return package.loaded["rfsuite.lib.msp_modes"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local msp_modes = {
  BOXIDS_COMMAND = 119,
  BOXNAMES_COMMAND = 116,
  MODE_RANGES_COMMAND = 34,
  MODE_RANGES_EXTRA_COMMAND = 238,
  SET_MODE_RANGE_COMMAND = 35,
}

local function clamp(value, minValue, maxValue)
  if value < minValue then return minValue end
  if value > maxValue then return maxValue end
  return value
end

local function toS8Byte(value)
  local v = clamp(math.floor((tonumber(value) or 0) + 0.5), -128, 127)
  if v < 0 then return v + 256 end
  return v
end

local function stepToUs(step)
  return 1500 + ((tonumber(step) or 0) * 5)
end

local function usToStep(value)
  return clamp(((tonumber(value) or 1500) - 1500) / 5, -125, 125)
end

local function parseBoxNames(buf)
  local names = {}
  local chars = {}

  local function flush()
    if #chars == 0 then return end
    names[#names + 1] = table.concat(chars)
    chars = {}
  end

  buf.offset = 1
  while true do
    local byte = mspcodec.readU8(buf)
    if byte == nil then break end
    if byte == 59 or byte == 0 then
      flush()
    elseif byte >= 32 and byte <= 126 then
      chars[#chars + 1] = string.char(byte)
    end
  end
  flush()
  return names
end

local function parseBoxIds(buf)
  local ids = {}
  buf.offset = 1
  while true do
    local id = mspcodec.readU8(buf)
    if id == nil then break end
    ids[#ids + 1] = id
  end
  return ids
end

local function parseModeRanges(buf)
  local ranges = {}
  buf.offset = 1
  while true do
    local modeId = mspcodec.readU8(buf)
    if modeId == nil then break end
    local auxChannelIndex = mspcodec.readU8(buf)
    local startStep = mspcodec.readS8(buf)
    local endStep = mspcodec.readS8(buf)
    if auxChannelIndex == nil or startStep == nil or endStep == nil then break end
    ranges[#ranges + 1] = {
      id = modeId,
      auxChannelIndex = auxChannelIndex,
      range = {start = stepToUs(startStep), ["end"] = stepToUs(endStep)},
    }
  end
  return ranges
end

local function parseModeRangesExtra(buf)
  local extras = {}
  buf.offset = 1
  local count = mspcodec.readU8(buf) or 0
  for _ = 1, count do
    local modeId = mspcodec.readU8(buf)
    local modeLogic = mspcodec.readU8(buf)
    local linkedTo = mspcodec.readU8(buf)
    if modeId == nil or modeLogic == nil or linkedTo == nil then break end
    extras[#extras + 1] = {id = modeId, modeLogic = modeLogic, linkedTo = linkedTo}
  end
  return extras
end

local BOXIDS_SIM = {0, 1, 2, 53, 27, 36, 45, 13, 52, 19, 20, 26, 31, 51, 55, 56, 57}
local BOXNAMES_SIM = {
  65, 82, 77, 59, 65, 78, 71, 76, 69, 59, 72, 79, 82, 73, 90, 79, 78, 59,
}

local function buildModeRangesSim()
  local response = {1, 0, 216, 40, 0, 0, 80, 120}
  for _ = 1, 18 do
    response[#response + 1] = 0
    response[#response + 1] = 0
    response[#response + 1] = 136
    response[#response + 1] = 136
  end
  return response
end

local function buildModeRangesExtraSim()
  local response = {20, 1, 0, 0}
  for _ = 1, 19 do
    response[#response + 1] = 0
    response[#response + 1] = 0
    response[#response + 1] = 0
  end
  return response
end

function msp_modes.buildBoxIdsReadMessage(onData, onError)
  return {
    command = msp_modes.BOXIDS_COMMAND,
    processReply = function(_, buf) onData(parseBoxIds(buf)) end,
    errorHandler = onError,
    simulatorResponse = BOXIDS_SIM,
  }
end

function msp_modes.buildBoxNamesReadMessage(onData, onError)
  return {
    command = msp_modes.BOXNAMES_COMMAND,
    processReply = function(_, buf) onData(parseBoxNames(buf)) end,
    errorHandler = onError,
    simulatorResponse = BOXNAMES_SIM,
  }
end

function msp_modes.buildModeRangesReadMessage(onData, onError)
  return {
    command = msp_modes.MODE_RANGES_COMMAND,
    processReply = function(_, buf) onData(parseModeRanges(buf)) end,
    errorHandler = onError,
    simulatorResponse = buildModeRangesSim(),
  }
end

function msp_modes.buildModeRangesExtraReadMessage(onData, onError)
  return {
    command = msp_modes.MODE_RANGES_EXTRA_COMMAND,
    processReply = function(_, buf) onData(parseModeRangesExtra(buf)) end,
    errorHandler = onError,
    simulatorResponse = buildModeRangesExtraSim(),
  }
end

function msp_modes.buildSetModeRangeMessage(slotIndex, range, extra, onWritten, onError)
  range = range or {id = 0, auxChannelIndex = 0, range = {start = 900, ["end"] = 900}}
  extra = extra or {modeLogic = 0, linkedTo = 0}

  local values = range.range or {}
  local payload = {
    (slotIndex or 1) - 1,
    clamp(range.id or 0, 0, 255),
    clamp(range.auxChannelIndex or 0, 0, 255),
    toS8Byte(usToStep(values.start)),
    toS8Byte(usToStep(values["end"])),
    clamp(extra.modeLogic or 0, 0, 1),
    clamp(extra.linkedTo or 0, 0, 255),
  }

  return {
    command = msp_modes.SET_MODE_RANGE_COMMAND,
    payload = payload,
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_modes"] = msp_modes
return msp_modes
