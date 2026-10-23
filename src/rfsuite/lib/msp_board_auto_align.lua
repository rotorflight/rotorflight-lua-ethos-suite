-- Codec/message-builders for rotorflight-firmware's board auto-align
-- helper: MSP2_BOARD_AUTO_ALIGN (cmd 0x5F13).
--
-- Wire shape verified against rotorflight-firmware src/main/msp/msp.c:
-- optional request payload action U8 (1 starts auto-align), reply status
-- is state U8, roll/pitch/yaw S16 degrees, matchedSamples U8. Status enum
-- comes from src/main/sensors/boardalignment_auto.h (API 12.10).

if package.loaded["rfsuite.lib.msp_board_auto_align"] then
  return package.loaded["rfsuite.lib.msp_board_auto_align"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local COMMAND = 0x5F13
local ACTION_START = 1

local STATE = {
  IDLE = 0,
  WAITING_FOR_TAIL_LIFT = 1,
  SUCCESS = 2,
  REJECTED_ARMED = 3,
  TIMEOUT = 4,
  NO_MATCH = 5,
  REJECTED_UNCALIBRATED = 6,
}

local SIMULATOR_RESPONSE_IDLE = {
  STATE.IDLE,
  0, 0, -- roll_degrees
  0, 0, -- pitch_degrees
  0, 0, -- yaw_degrees
  0,    -- matched_samples
}

local SIMULATOR_RESPONSE_START = {
  STATE.WAITING_FOR_TAIL_LIFT,
  0, 0, -- roll_degrees
  0, 0, -- pitch_degrees
  0, 0, -- yaw_degrees
  0,    -- matched_samples
}

local msp_board_auto_align = {
  COMMAND = COMMAND,
  ACTION_START = ACTION_START,
  STATE = STATE,
}

function msp_board_auto_align.decode(buf)
  buf.offset = 1
  return {
    state = mspcodec.readU8(buf),
    roll_degrees = mspcodec.readS16(buf),
    pitch_degrees = mspcodec.readS16(buf),
    yaw_degrees = mspcodec.readS16(buf),
    matched_samples = mspcodec.readU8(buf),
  }
end

local function buildMessage(payload, simulatorResponse, onData, onError, isWrite)
  return {
    command = COMMAND,
    payload = payload,
    isWrite = isWrite,
    processReply = function(_, buf)
      if onData then onData(msp_board_auto_align.decode(buf)) end
    end,
    errorHandler = onError,
    simulatorResponse = simulatorResponse,
  }
end

function msp_board_auto_align.buildReadMessage(onData, onError)
  return buildMessage(nil, SIMULATOR_RESPONSE_IDLE, onData, onError, false)
end

function msp_board_auto_align.buildStartMessage(onData, onError)
  return buildMessage({ACTION_START}, SIMULATOR_RESPONSE_START, onData, onError, true)
end

package.loaded["rfsuite.lib.msp_board_auto_align"] = msp_board_auto_align
return msp_board_auto_align
