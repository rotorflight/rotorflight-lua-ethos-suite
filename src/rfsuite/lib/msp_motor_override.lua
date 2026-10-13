-- MSP_MOTOR_OVERRIDE (194, read) and MSP_SET_MOTOR_OVERRIDE (195, write).
--
-- The write is what makes the flight controller drive a motor directly, so the
-- constants below are transcribed from the firmware rather than invented:
-- src/main/flight/motors.h:22-27 defines MOTOR_OVERRIDE_OFF/MIN/MAX and
-- MOTOR_OVERRIDE_TIMEOUT (1000000 us), and src/main/msp/msp.c:2966-2974 reads
-- the write as `i = sbufReadU8(src)` followed by `setMotorOverride(i,
-- sbufReadU16(src), MOTOR_OVERRIDE_TIMEOUT)`. That timeout is why the page needs
-- a keep-alive: motors.c:301-303 calls resetMotorOverride() once it passes, so
-- a single write holds a motor for one second and no longer.

if package.loaded["rfsuite.lib.msp_motor_override"] then
  return package.loaded["rfsuite.lib.msp_motor_override"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 194
local WRITE_COMMAND = 195

local OVERRIDE_OFF = 0
local OVERRIDE_MIN = -1000
local OVERRIDE_MAX = 1000

-- How many motors MSP_MOTOR_OVERRIDE answers for. msp.c:1292-1300 writes
-- MAX_SUPPORTED_MOTORS values, one int16 each, and zero for a motor the board
-- does not have. common_defaults_post.h:697-699 defines MAX_SUPPORTED_MOTORS
-- as 4 unless the target overrides it, so 8 bytes is the full answer.
local MOTOR_SLOTS = 4

local msp_motor_override = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  OVERRIDE_OFF = OVERRIDE_OFF,
  OVERRIDE_MIN = OVERRIDE_MIN,
  OVERRIDE_MAX = OVERRIDE_MAX,
  MOTOR_SLOTS = MOTOR_SLOTS,
}

--- Read the override the board currently holds for every motor.
---
--- The values are int16_t and a reverse override is negative, so they are read
--- signed: read unsigned, -100 comes back as 65436.
function msp_motor_override.parse(buf)
  if type(buf) ~= "table" then return nil end
  if #buf < MOTOR_SLOTS * 2 then return nil end
  buf.offset = 1
  local out = {}
  for idx = 1, MOTOR_SLOTS do
    out["motor_" .. idx] = mspcodec.readS16(buf)
  end
  return out
end

--- Build the write for ONE motor. `index` is 0-based, as the wire numbers them.
---
--- This is deliberately not the mirror image of the read: the read answers for
--- every motor, the write carries a single index/value pair, which is also what
--- the Configurator sends.
function msp_motor_override.buildWriteMessage(index, value, onWritten, onError)
  local payload = {}
  mspcodec.writeU8(payload, index or 0)
  mspcodec.writeS16(payload, value or OVERRIDE_OFF)
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

--- Build a read for the override state, so a page can show what the board
--- already holds instead of claiming nothing is overridden.
function msp_motor_override.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    payload = {},
    isWrite = false,
    processReply = function(_, buf)
      if onData then onData(msp_motor_override.parse(buf)) end
    end,
    errorHandler = onError,
    simulatorResponse = {0, 0, 0, 0, 0, 0, 0, 0},
  }
end

package.loaded["rfsuite.lib.msp_motor_override"] = msp_motor_override
return msp_motor_override