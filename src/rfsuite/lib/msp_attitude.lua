-- Message-builder for MSP_ATTITUDE (cmd 108), used by the Alignment
-- page's live 3D attitude preview.

if package.loaded["rfsuite.lib.msp_attitude"] then
  return package.loaded["rfsuite.lib.msp_attitude"]
end

local mspcodec = assert(loadfile("lib/mspcodec.lua"))()

local READ_COMMAND = 108

local msp_attitude = {
  READ_COMMAND = READ_COMMAND,
}

local function buildSimulatorResponse()
  local t = os.clock()
  local roll = math.floor((25.0 * math.sin(t * 1.25) * 10.0) + 0.5)
  local pitch = math.floor((18.0 * math.sin((t * 0.90) + 0.9) * 10.0) + 0.5)
  local yaw = math.floor((90.0 * math.sin((t * 0.42) + 0.2)) + 0.5)
  local payload = {}
  mspcodec.writeS16(payload, roll)
  mspcodec.writeS16(payload, pitch)
  mspcodec.writeS16(payload, yaw)
  return payload
end

function msp_attitude.decode(buf)
  buf.offset = 1
  return {
    roll = mspcodec.readS16(buf),
    pitch = mspcodec.readS16(buf),
    yaw = mspcodec.readS16(buf),
  }
end

function msp_attitude.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_attitude.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = buildSimulatorResponse(),
    -- Used to be retryDelay = -0.6 (0.2s per attempt), maxRetries = 1 (0.4s
    -- total budget) -- tuned for the alignment page's old 12.5Hz polling,
    -- where failing fast mattered because another request was coming right
    -- behind it. Live-testing on a contended link showed that budget is
    -- just too short: MSP_BOARD_ALIGNMENT_CONFIG (cmd 38, same link, same
    -- session) routinely needed a 3rd attempt at the *default* 0.8s
    -- spacing to get a reply, so attitude's 0.2s retries were giving up
    -- before a reply would have arrived at all -- every single attitude
    -- request failed via max_retries, never once succeeding after the
    -- page's first read. Now that the alignment page throttles its own
    -- request rate (attitudeSamplePeriod = 0.4s, see app/pages/alignment.lua)
    -- there's no reason to also starve each individual request of retry
    -- time: use the default 0.8s spacing, with maxRetries = 2 (3 attempts,
    -- ~1.6s worst case) to give this link the same margin cmd 38 needed.
    -- Keep app/pages/alignment.lua's pendingTimeout comfortably above that
    -- worst case so its own safety net doesn't preempt these retries and
    -- pile up duplicate in-flight requests.
    maxRetries = 2,
  }
end

package.loaded["rfsuite.lib.msp_attitude"] = msp_attitude
return msp_attitude
