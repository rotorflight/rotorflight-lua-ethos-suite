-- Codec/message-builders for rotorflight-firmware's ESC sensor wiring trial:
-- MSP2_ESC_SENSOR_TRIAL (cmd 0x5F0C).
--
-- The flight controller tries the half-duplex and pin-swap combinations on its
-- ESC telemetry port. Request payload: action U8 (0 polls, 1 starts, 2 cancels
-- and restores the previous wiring). Reply: state U8, combo U8, half_duplex U8,
-- pin_swap U8, elapsed_ms U16; newer firmware appends diagnostics, not read here.
-- Same shape as the EdgeTX suite's tasks/msp/api/esc_sensor_trial.lua.

if package.loaded["rfsuite.lib.msp_esc_sensor_trial"] then
  return package.loaded["rfsuite.lib.msp_esc_sensor_trial"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local COMMAND = 0x5F0C
local ACTION_POLL = 0
local ACTION_START = 1
local ACTION_CANCEL = 2

local STATE = {
  IDLE = 0,
  RUNNING = 1,
  SUCCESS = 2,
  FAILED = 3,
  REJECTED = 4,
}

-- The combinations tried, as the Configurator's EscWiringDetectWizard counts them.
local COMBINATIONS = 4

local SIMULATOR_RESPONSE_IDLE = {STATE.IDLE, 0, 0, 0, 0, 0}
local SIMULATOR_RESPONSE_RUNNING = {STATE.RUNNING, 0, 0, 0, 0, 0}

local msp_esc_sensor_trial = {
  COMMAND = COMMAND,
  ACTION_POLL = ACTION_POLL,
  ACTION_START = ACTION_START,
  ACTION_CANCEL = ACTION_CANCEL,
  STATE = STATE,
  COMBINATIONS = COMBINATIONS,
}

function msp_esc_sensor_trial.decode(buf)
  buf.offset = 1
  return {
    state = mspcodec.readU8(buf),
    combo_index = mspcodec.readU8(buf),
    half_duplex = mspcodec.readU8(buf),
    pin_swap = mspcodec.readU8(buf),
    elapsed_ms = mspcodec.readU16(buf),
  }
end

local function buildMessage(action, simulatorResponse, onData, onError)
  return {
    command = COMMAND,
    payload = {action},
    isWrite = action ~= ACTION_POLL,
    processReply = function(_, buf)
      if onData then onData(msp_esc_sensor_trial.decode(buf)) end
    end,
    errorHandler = onError,
    simulatorResponse = simulatorResponse,
  }
end

function msp_esc_sensor_trial.buildStartMessage(onData, onError)
  return buildMessage(ACTION_START, SIMULATOR_RESPONSE_RUNNING, onData, onError)
end

function msp_esc_sensor_trial.buildPollMessage(onData, onError)
  return buildMessage(ACTION_POLL, SIMULATOR_RESPONSE_IDLE, onData, onError)
end

-- Cancel: no reply is read; the flight controller restores its previous wiring.
function msp_esc_sensor_trial.buildCancelMessage(onError)
  return buildMessage(ACTION_CANCEL, {}, nil, onError)
end

package.loaded["rfsuite.lib.msp_esc_sensor_trial"] = msp_esc_sensor_trial
return msp_esc_sensor_trial
