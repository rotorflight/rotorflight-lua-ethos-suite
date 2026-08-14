-- Schema + message-builders for the MSP_ACC_TRIM /
-- MSP_SET_ACC_TRIM command pair (cmd 240 read / 239 write) -- used by
-- app/pages/accelerometer.lua.

if package.loaded["rfsuite.lib.msp_acc_trim"] then
  return package.loaded["rfsuite.lib.msp_acc_trim"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 240
local WRITE_COMMAND = 239

-- {name, wireType}, in exact wire order -- matches the original suite's
-- tasks/scheduler/msp/api/ACC_TRIM.lua FIELD_SPEC.
local FIELDS = {
  {"pitch", "S16"},
  {"roll", "S16"},
}

local SIMULATOR_RESPONSE = {
  0, 0, -- pitch
  0, 0, -- roll
}

local FIELD_META = {
  pitch = {min = -300, max = 300, default = 0, suffix = "°"},
  roll = {min = -300, max = 300, default = 0, suffix = "°"},
}

local msp_acc_trim = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FIELDS = FIELDS,
  FIELD_META = FIELD_META,
}

function msp_acc_trim.decode(buf)
  buf.offset = 1
  return {
    pitch = mspcodec.readS16(buf),
    roll = mspcodec.readS16(buf),
  }
end

function msp_acc_trim.encode(data)
  local payload = {}
  mspcodec.writeS16(payload, (data and data.pitch) or 0)
  mspcodec.writeS16(payload, (data and data.roll) or 0)
  return payload
end

function msp_acc_trim.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_acc_trim.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_acc_trim.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_acc_trim.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_acc_trim"] = msp_acc_trim
return msp_acc_trim
