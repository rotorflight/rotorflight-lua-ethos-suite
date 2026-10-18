-- OpenYGE: one byte, not a flag word. The low nibble is the motor state and the high nibble is a
-- warning code with a device bit (firmware: the OpenYGE protocol comment in src/main/sensors/
-- esc_sensor.c, "Motor states" and "Warning/error codes"). Three of the four warning codes are a
-- failure only in some motor states, and warning code zero means overvoltage in the one state
-- where the controller cuts power. Levels: 1 OK, 2 WARNING, 3 ERROR.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local T = requireModule("lib/esc_status_text.lua")
local ERR, WRN, INF = 3, 2, 1

local STATE_POWER_CUT = 0x01
local STATE_STARTING = 0x08

local WARN_OK = 0x00
local WARN_UNDERVOLTAGE = 0x10
local WARN_OVERTEMP = 0x20
local WARN_OVERAMP = 0x40
local WARN_DEVICE_BEC = 0x80
local WARN_SETPOINT_NOISE = 0xC0

local function read(word)
  local byte = word % 256
  local state = byte % 16
  local warn = byte - state

  if warn == WARN_SETPOINT_NOISE then
    return T.setpoint_noise, WRN
  end

  local isBec = warn >= WARN_DEVICE_BEC
  local code = isBec and (warn - WARN_DEVICE_BEC) or warn

  if code == WARN_OK then
    if state == STATE_POWER_CUT then
      return isBec and T.bec_overvoltage or T.overvoltage, ERR
    end
    return T.ok, INF
  end
  if code == WARN_UNDERVOLTAGE then
    local level = (state < STATE_STARTING) and ERR or WRN
    return isBec and T.bec_undervoltage or T.undervoltage, level
  end
  if code == WARN_OVERTEMP then
    local level = (state == STATE_POWER_CUT) and ERR or WRN
    return isBec and T.bec_overheat or T.overheat, level
  end
  if code == WARN_OVERAMP then
    local level = (state == STATE_POWER_CUT) and ERR or WRN
    return isBec and T.bec_overcurrent or T.overcurrent, level
  end

  -- A code the protocol does not assign: reported, because a controller saying something
  -- unexpected about itself is worth a look.
  return T.fault, WRN
end

return {
  name = "OpenYGE",
  reader = read,
}
