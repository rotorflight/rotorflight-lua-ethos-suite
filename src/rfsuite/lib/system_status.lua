-- Decoder for the FC's two packed status telemetry sensors:
--
--   system_status  (sensor 120; S.Port 0x5140, CRSF 0x1230) -- live state
--   system_config  (sensor 121; S.Port 0x5141, CRSF 0x1231) -- profiles and config state
--
-- Bit positions mirror rotorflight-firmware's src/main/telemetry/status.h and
-- change together with it. This file is the one place on the radio side that
-- knows the layout; everything else reads the decoded tables
-- tasks/session.lua publishes.
--
-- Firmware before MSP API 12.10 does not send these sensors. tasks/session.lua
-- then falls back to the individual armflags/profile/governor sensors.
--
-- Stateless, like lib/telemetry_sensors.lua.

if package.loaded["rfsuite.lib.system_status"] then
  return package.loaded["rfsuite.lib.system_status"]
end

local systemStatus = {}

-- Enumerations carried in multi-bit fields. Values match the firmware enums
-- named alongside each one.
systemStatus.FAILSAFE = { -- failsafePhase_e
  IDLE = 0,
  RX_LOSS_DETECTED = 1,
  LANDING = 2,
  LANDED = 3,
  RX_LOSS_MONITORING = 4,
  RX_LOSS_RECOVERED = 5,
  GPS_RESCUE = 6,
}

systemStatus.GPS_FIX = { -- telemetryGpsFix_e
  NONE = 0,
  OK = 1,
  HOME = 2, -- fix, and home position captured
}

systemStatus.BATTERY = { -- batteryState_e
  OK = 0,
  WARNING = 1,
  CRITICAL = 2,
  NOT_PRESENT = 3,
  INIT = 4,
}

systemStatus.RESCUE = { -- rescueState_e
  OFF = 0,
  PULLUP = 1,
  FLIP = 2,
  CLIMB = 3,
  HOVER = 4,
  EXIT = 5,
}

systemStatus.GOVERNOR = { -- govState_e
  THROTTLE_OFF = 0,
  THROTTLE_IDLE = 1,
  SPOOLUP = 2,
  RECOVERY = 3,
  ACTIVE = 4,
  THROTTLE_HOLD = 5,
  FALLBACK = 6,
  AUTOROTATION = 7,
  BAILOUT = 8,
  BYPASS = 9,
}

systemStatus.GOVERNOR_MODE = { -- govMode_e
  NONE = 0,
  LIMIT = 1,
  DIRECT = 2,
  ELECTRIC = 3,
  NITRO = 4,
}

-- The sensor reading as a plain integer word, or nil when there is none.
-- Callers compare this against the last decoded .raw and only decode on a
-- change, so the per-tick path allocates nothing.
function systemStatus.toRaw(raw)
  local value = tonumber(raw)
  if value == nil then return nil end
  value = math.floor(value)
  -- S.Port carries the word as a signed int; bit 31 is never set, but mask
  -- anyway so a sign-extended reading can't leak into the fields.
  return value & 0x7FFFFFFF
end

local toInt = systemStatus.toRaw

local function flag(value, bit)
  return (value >> bit) & 1 == 1
end

local function field(value, shift, mask)
  return (value >> shift) & mask
end

-- Returns nil for a missing reading, so callers keep their last known state.
function systemStatus.decodeStatus(raw)
  local value = toInt(raw)
  if value == nil then return nil end

  return {
    raw = value,
    armed = flag(value, 0),
    airborne = flag(value, 1),
    motorsRunning = flag(value, 2),
    rxLinkUp = flag(value, 3),
    failsafePhase = field(value, 6, 0x7),
    gpsFix = field(value, 9, 0x3),
    gpsHealthy = flag(value, 11),
    spooledUp = flag(value, 12),
    batteryState = field(value, 14, 0x7),
    controlSaturated = flag(value, 17),
    gyroOverflow = flag(value, 18),
    accNotCalibrated = flag(value, 19),
    overrideActive = flag(value, 20),
    rescueState = field(value, 21, 0x7),
    blackboxLogging = flag(value, 24),
    governorState = field(value, 25, 0xF),
  }
end

-- Profile numbers are 1-based, as the FC's own UI shows them.
function systemStatus.decodeConfig(raw)
  local value = toInt(raw)
  if value == nil then return nil end

  return {
    raw = value,
    pidProfile = field(value, 0, 0x7),
    rateProfile = field(value, 3, 0x7),
    batteryProfile = field(value, 6, 0x7),
    configDirty = flag(value, 12),
    saving = flag(value, 13),
    rebootRequired = flag(value, 14),
    beeperOn = flag(value, 15),
    accPresent = flag(value, 16),
    baroPresent = flag(value, 17),
    magPresent = flag(value, 18),
    gpsPresent = flag(value, 19),
    blackboxFull = flag(value, 21),
    rpmSourceActive = flag(value, 22),
    governorMode = field(value, 23, 0x7),
  }
end

package.loaded["rfsuite.lib.system_status"] = systemStatus
return systemStatus
