-- MSP_MOTOR_CONFIG helper (cmd 131 read / 222 write).

if package.loaded["rfsuite.lib.msp_motor_config"] then
  return package.loaded["rfsuite.lib.msp_motor_config"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 131
local WRITE_COMMAND = 222

-- The wire values, transcribed from the firmware's own enum -- rotorflight-firmware
-- src/main/drivers/motor.h, master as of 2026-10-04:
--
--   typedef enum {
--       PWM_TYPE_STANDARD = 0,
--       PWM_TYPE_ONESHOT125,        1
--       PWM_TYPE_ONESHOT42,         2
--       PWM_TYPE_MULTISHOT,         3
--       PWM_TYPE_RESERVED,  // BRUSHED   4   <- a reserved slot, see RESERVED_BRUSHED
--       PWM_TYPE_DSHOT150,          5
--       PWM_TYPE_DSHOT300,          6
--       PWM_TYPE_DSHOT600,          7
--       PWM_TYPE_PROSHOT1000,       8
--       PWM_TYPE_CASTLE_LINK,       9
--       PWM_TYPE_SRXL2,            10
--       PWM_TYPE_DISABLED,         11
--       PWM_TYPE_MAX
--   } motorPwmProtocolTypes_e;
--
-- The list this file used to carry was missing SRXL2, which is why its DISABLED
-- entry sat on 10. Ten is SRXL2. A pilot selecting "DISABLED" therefore wrote
-- SRXL2 to the flight controller -- a configuration that arms a serial ESC link
-- instead of switching the motor output off. That was live on every FC this suite
-- speaks to, and no test here could see it, because both ends agreed on the wrong
-- number: the codec and the page's own defaults all said 10.
--
-- The values are named rather than inlined for the same reason. There were four
-- bare `10`s across this file and the two pages that read it, each one a place
-- where DISABLED was spelled as a literal and could drift from the enum again.
local DISABLED = 11
local CASTLE = 9
local SRXL2 = 10
local RESERVED_BRUSHED = 4

-- Always offered. 0..8 and CASTLE and DISABLED.
--
-- CASTLE carries no version gate here on purpose. EdgeTX gates it at API >= 12.0.8
-- (esc_motors/throttle/page.lua:394) and so does the Configurator, but this suite
-- refuses to operate below 12.09 at all -- lib/msp_api_version.lua:69-73 returns
-- false for any minor under MIN_API_MINOR = 9 -- so every FC that can reach this
-- page is already past CASTLE's floor. A gate here could never refuse anything, and
-- a gate that cannot fire is a second thing to keep true. It is noted rather than
-- written; if MIN_API_MINOR ever drops below 8, this is where the gate goes.
local BASE_CHOICES = {
  {"PWM", 0},
  {"ONESHOT125", 1},
  {"ONESHOT42", 2},
  {"MULTISHOT", 3},
  {"DSHOT150", 5},
  {"DSHOT300", 6},
  {"DSHOT600", 7},
  {"PROSHOT", 8},
  {"CASTLE", CASTLE},
  {"DISABLED", DISABLED},
}

-- SRXL2 arrived in drivers/motor.h on 2026-08-08 (e72e209d, "Add support for
-- Spektrum SRXL2 ESC", #421) and the API minor was raised to 10 nine days later
-- (ac1f1730, "Increment firmware and MSP version", #484). So 12.10 is the floor,
-- and EdgeTX's gate (esc_motors/throttle/page.lua:395, isAtLeast 12.0.10) is right.
--
-- One caveat stated rather than hidden: the firmware's own gate for this protocol is
-- a BUILD flag -- checkMotorProtocolEnabled() in src/main/drivers/motor.c:154-176
-- lists PWM_TYPE_SRXL2 under `#ifdef USE_SRXL2_ESC` -- and no MSP message reports
-- that flag to the sender. So the API version is a proxy, not the fact: a target
-- built without USE_SRXL2_ESC while reporting 12.10 would still be offered SRXL2,
-- and the firmware would refuse it at arm time. Nothing on the wire can do better,
-- and the same is true of DSHOT (USE_DSHOT) and CASTLE (USE_TELEMETRY_CASTLE).
local SRXL2_MIN_API_MINOR = 10

-- BRUSHED is not a protocol. The firmware removed it on 2022-10-19 (9d1645a8, "RTFL:
-- Remove BRUSHED_MOTORS") and kept slot 4 as a placeholder so the numbers after it
-- would not move; drivers/motor.h still carries the comment "// BRUSHED" on
-- PWM_TYPE_RESERVED. checkMotorProtocolEnabled() has no case for it, so a FC
-- configured with 4 reports the protocol as not enabled.
-- It is dropped from the menu outright. Keeping it visible for a pilot who already
-- has 4 stored would need the list rebuilt after the FC's block arrives, and that is
-- not available: app/field_layout.lua's buildSingle() calls addLine() (field_layout.lua
-- :469), so a second call would put a SECOND row on the screen, and there is no
-- re-spec path. Half a mechanism is worse than none, so the parameter that would have
-- carried "what does the FC currently report" is not here.
--
-- WHAT THAT COSTS, stated rather than discovered later: a pilot whose FC sits on the
-- reserved slot opens this page to a row whose value is not in the list. Nothing is
-- corrupted -- app/field_layout.lua's choiceGet() returns the stored value unchanged
-- and encode() writes back what the codec read, so a save with that row untouched
-- commits 4 again. Whether Ethos draws such a row blank or snaps it to the first
-- entry is NOT verified here and needs a live check; see the pull request.
local function choicesFor(apiMinor)
  local choices = {}
  -- Built by walking the base list rather than by appending, so SRXL2 lands BEFORE
  -- DISABLED. Appending put it after -- 0 1 2 3 5 6 7 8 9 11 10 -- and the harness
  -- caught the offered values as not ascending. DISABLED is the end of the enum, so
  -- anything added goes in front of it.
  for i = 1, #BASE_CHOICES do
    local entry = BASE_CHOICES[i]
    if entry[2] == DISABLED and type(apiMinor) == "number" and apiMinor >= SRXL2_MIN_API_MINOR then
      choices[#choices + 1] = {"SRXL2", SRXL2}
    end
    choices[#choices + 1] = entry
  end
  return choices
end

local ON_OFF_CHOICES = {
  {"@i18n(api.MOTOR_CONFIG.tbl_off)@", 0},
  {"@i18n(api.MOTOR_CONFIG.tbl_on)@", 1},
}

local READ_FIELDS = {
  {"minthrottle", "U16"},
  {"maxthrottle", "U16"},
  {"mincommand", "U16"},
  {"motor_count_blheli", "U8"},
  {"motor_pole_count_blheli", "U8"},
  {"use_dshot_telemetry", "U8"},
  {"motor_pwm_protocol", "U8"},
  {"motor_pwm_rate", "U16"},
  {"use_unsynced_pwm", "U8"},
  {"motor_pole_count_0", "U8"},
  {"motor_pole_count_1", "U8"},
  {"motor_pole_count_2", "U8"},
  {"motor_pole_count_3", "U8"},
  {"motor_rpm_lpf_0", "U8"},
  {"motor_rpm_lpf_1", "U8"},
  {"motor_rpm_lpf_2", "U8"},
  {"motor_rpm_lpf_3", "U8"},
  {"main_rotor_gear_ratio_0", "U16"},
  {"main_rotor_gear_ratio_1", "U16"},
  {"tail_rotor_gear_ratio_0", "U16"},
  {"tail_rotor_gear_ratio_1", "U16"},
}

local WRITE_FIELDS = {
  {"minthrottle", "U16"},
  {"maxthrottle", "U16"},
  {"mincommand", "U16"},
  {"motor_pole_count_blheli", "U8"},
  {"use_dshot_telemetry", "U8"},
  {"motor_pwm_protocol", "U8"},
  {"motor_pwm_rate", "U16"},
  {"use_unsynced_pwm", "U8"},
  {"motor_pole_count_0", "U8"},
  {"motor_pole_count_1", "U8"},
  {"motor_pole_count_2", "U8"},
  {"motor_pole_count_3", "U8"},
  {"motor_rpm_lpf_0", "U8"},
  {"motor_rpm_lpf_1", "U8"},
  {"motor_rpm_lpf_2", "U8"},
  {"motor_rpm_lpf_3", "U8"},
  {"main_rotor_gear_ratio_0", "U16"},
  {"main_rotor_gear_ratio_1", "U16"},
  {"tail_rotor_gear_ratio_0", "U16"},
  {"tail_rotor_gear_ratio_1", "U16"},
}

local FIELD_META = {
  minthrottle = {min = 50, max = 2250, default = 1070, suffix = "us"},
  maxthrottle = {min = 50, max = 2250, default = 2000, suffix = "us"},
  mincommand = {min = 50, max = 2250, default = 1000, suffix = "us"},
  use_dshot_telemetry = {choices = ON_OFF_CHOICES},
  -- The BASE list, not the full one: this is the fallback for any caller that builds
-- the field without asking for the version-filtered list, so it must be the subset
-- that is valid on every FC this suite will talk to. app/pages/esc_motors_throttle.lua
-- passes the filtered list explicitly and is the only page that builds this field.
  motor_pwm_protocol = {choices = BASE_CHOICES},
  motor_pwm_rate = {min = 50, max = 8000, default = 250, suffix = "Hz"},
  use_unsynced_pwm = {choices = ON_OFF_CHOICES},
  motor_pole_count_0 = {min = 2, max = 256, default = 10},
  main_rotor_gear_ratio_0 = {min = 1, max = 50000, default = 1},
  main_rotor_gear_ratio_1 = {min = 1, max = 50000, default = 1},
  tail_rotor_gear_ratio_0 = {min = 1, max = 50000, default = 1},
  tail_rotor_gear_ratio_1 = {min = 1, max = 50000, default = 1},
}

local SIMULATOR_RESPONSE = {
  45, 4,
  208, 7,
  232, 3,
  1,
  6,
  0,
  0,
  250, 0,
  1,
  6,
  4,
  2,
  1,
  8,
  7,
  7,
  8,
  20, 0,
  50, 0,
  9, 0,
  30, 0,
}

local msp_motor_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FIELD_META = FIELD_META,
  ON_OFF_CHOICES = ON_OFF_CHOICES,

  -- The Throttle Protocol choices for the FC that answered.
  --
  --   apiMinor -- MSP_API_VERSION's minor, or nil if it is not known yet. nil gives
  --               the SMALLER list, which is the safe direction: a pilot mid-handshake
  --               is never offered a protocol the FC may not have.
  --
  -- It is available by the time a page builds its fields: page_runtime subscribes to
  -- "session.update" in its constructor and lib/bus.lua replays the retained snapshot
  -- to a new subscriber synchronously (bus.lua:18 and :97), so the value is set before
  -- open() reaches its first buildSingle().
  --
  -- Deliberately a FUNCTION and no longer a table: a table is what let the list drift
  -- out of sync with the enum in the first place, and a caller that reaches for
  -- PROTOCOL_CHOICES should not find one. BASE is exported for the callers that want
  -- the unconditional subset on purpose.
  protocolChoices = choicesFor,
  BASE_PROTOCOL_CHOICES = BASE_CHOICES,
  DISABLED_PROTOCOL = DISABLED,
  SRXL2_PROTOCOL = SRXL2,
  CASTLE_PROTOCOL = CASTLE,
  RESERVED_BRUSHED_PROTOCOL = RESERVED_BRUSHED,
  SRXL2_MIN_API_MINOR = SRXL2_MIN_API_MINOR,
}

local function readByType(buf, wireType)
  if wireType == "U16" then return mspcodec.readU16(buf) end
  return mspcodec.readU8(buf)
end

local function writeByType(buf, wireType, value)
  if wireType == "U16" then
    mspcodec.writeU16(buf, value or 0)
  else
    mspcodec.writeU8(buf, value or 0)
  end
end

function msp_motor_config.decode(buf)
  buf.offset = 1
  local data = {}
  for i = 1, #READ_FIELDS do
    local name, wireType = READ_FIELDS[i][1], READ_FIELDS[i][2]
    data[name] = readByType(buf, wireType)
  end
  return data
end

function msp_motor_config.encode(data)
  local payload = {}
  data = data or {}
  for i = 1, #WRITE_FIELDS do
    local name, wireType = WRITE_FIELDS[i][1], WRITE_FIELDS[i][2]
    writeByType(payload, wireType, data[name])
  end
  return payload
end

function msp_motor_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_motor_config.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_motor_config.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_motor_config.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_motor_config"] = msp_motor_config
return msp_motor_config
