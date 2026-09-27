-- Battery profile index bases.
--
-- Two different bases meet in this suite for the *same* number, and mixing
-- them up is an off-by-one in both directions -- so this file exists to keep
-- the two apart at the type level instead of letting one helper "accept
-- either base".
--
-- 0-based is the canonical internal representation, and everything the suite
-- itself stores or hands to the flight controller is in it:
--   - lib/msp_battery_profile.lua's PROFILE_CHOICES maps the labels
--     "1".."6" onto the values 0..5.
--   - lib/msp_battery.lua decodes the six capacities into profiles[0]..[5].
--   - MSP 175 (MSP_BATTERY_PROFILE) replies with the raw 0-based
--     `batteryConfig()->batteryProfile`, and MSP 176
--     (MSP_SET_BATTERY_PROFILE) takes a 0-based index and rejects anything
--     >= BATTERY_PROFILE_COUNT.
--     (rotorflight-firmware src/main/msp/msp.c:911 and :3977,
--     src/main/msp/msp_protocol.h:223-224, src/main/pg/battery.h:75 --
--     `uint8_t batteryProfile; // battery profile index`.)
--   - session.batteryProfile, widget.batteryProfile and the dashboard
--     selector's own profile.idx are all in this base too.
--
-- 1-based exists in exactly one place: the `battery_profile` telemetry
-- sensor (appId 0x1214 on CRSF, S.Port sensor 97), which the firmware
-- reports as `getCurrentBatteryProfileIndex() + 1`
-- (rotorflight-firmware src/main/telemetry/sensors.c:358-359,
-- src/main/telemetry/sensors.h:151) -- the same `+ 1` convention as
-- TELEM_PID_PROFILE / TELEM_RATES_PROFILE. That conversion is done once,
-- at the sensor's single ingress point (tasks/session.lua's
-- updateProfiles()), via fromTelemetrySensor() below, and nowhere else.
--
-- Why the separation is load-bearing: the old normalizeBatteryProfile() was
-- a single "accept either base" helper that checked `>= 1 and <= 6` first and
-- decremented. Applied to an already-0-based 1..5 it subtracted one, so
-- selecting pack 5 wrote pack 4's index to the FC and announced pack 3's
-- capacity. It was also not injective -- normalize(0) == normalize(1) == 0
-- -- so a real 1 -> 2 pack change collapsed to "no change" and was silently
-- dropped by the widget's already-selected guard. A validator that only ever
-- accepts one known base cannot fail either way.

if package.loaded["rfsuite.lib.battery_profile_index"] then
  return package.loaded["rfsuite.lib.battery_profile_index"]
end

local battery_profile_index = {}

local PROFILE_COUNT = 6

-- Validates an internal 0-based profile index. Returns the index as an
-- integer, or nil for anything out of range / non-numeric -- never a
-- silently adjusted value. Use this for every value that is already in the
-- 0-based base (see the header for the full list).
function battery_profile_index.index0(value)
  local index = tonumber(value)
  if index == nil then return nil end
  index = math.floor(index)
  if index >= 0 and index < PROFILE_COUNT then return index end
  return nil
end

-- The one 1-based -> 0-based conversion, for the raw `battery_profile`
-- telemetry sensor reading only. The firmware's `+ 1` means a valid reading
-- is always 1..6, so 0 is *not* accepted here: seeing a 0 would mean the
-- sender is not speaking the base this function converts from, and quietly
-- passing it through would reintroduce exactly the off-by-one this file
-- exists to prevent. Returns nil in that case, and the caller keeps its last
-- known good value.
function battery_profile_index.fromTelemetrySensor(value)
  local index = tonumber(value)
  if index == nil then return nil end
  index = math.floor(index)
  if index >= 1 and index <= PROFILE_COUNT then return index - 1 end
  return nil
end

-- 1-based label for a 0-based index -- what the pilot is shown and what the
-- spoken announcement refers to ("battery 6", not "battery 5").
function battery_profile_index.label(index)
  index = battery_profile_index.index0(index)
  if index == nil then return nil end
  return index + 1
end

package.loaded["rfsuite.lib.battery_profile_index"] = battery_profile_index
return battery_profile_index
