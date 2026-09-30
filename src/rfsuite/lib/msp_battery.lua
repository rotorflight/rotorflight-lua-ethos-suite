-- Message-builders + decoders for BATTERY_CONFIG (cmd 32) and
-- SMARTFUEL_CONFIG (cmd 0x4000). Stateless. Used by tasks/session.lua.
--
-- Field order/scale transcribed from rotorflight-lua-ethos-suite's
-- tasks/scheduler/msp/api/{BATTERY_CONFIG,SMARTFUEL_CONFIG}.lua. This
-- rebuild's floor (Rotorflight 2.3 / MSP API >= 12.09) always includes the
-- six per-profile batteryCapacity_0..5 fields the original only reads on
-- newer firmware -- no version gating needed. Those values are kept in
-- `profiles[0]..profiles[5]` so the dashboard can offer the same battery
-- profile selector without loading the heavier app page.
--
-- Both decoders below check the payload length before reading a single byte.
-- tasks/msp/queue.lua calls processReply unprotected, so a decoder that ran
-- off the end of a short payload raised a hard Lua error inside the
-- background task (SMARTFUEL_CONFIG: `nil / 1000`), and a decoder that
-- substituted zeros field by field produced a config that still passed
-- session.lua's `if not session.batteryConfig` handshake guard and only
-- failed much later -- in announceVoltage() or a dashboard gauge, far from
-- the cause. Refusing the payload and reporting it through errorHandler
-- keeps both cases visible at the one place they belong.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local msp_battery = {}

msp_battery.BATTERY_CONFIG_READ_COMMAND = 32

-- Wire size of a BATTERY_CONFIG reply, verified against the firmware's
-- handler (rotorflight-firmware src/main/msp/msp.c, case MSP_BATTERY_CONFIG):
-- u16 batteryCapacity + u8 cellCount + u8 voltageMeterSource + u8
-- currentMeterSource + 4x u16 cell voltages + u8 lvcPercentage + u8
-- consumptionWarningPercentage = 15 bytes, then BATTERY_PROFILE_COUNT (6,
-- src/main/pg/battery.h) u16 capacities = 12 bytes. The profile loop is not
-- version-gated in the firmware, so 27 is the one size to expect.
msp_battery.BATTERY_CONFIG_SIZE = 27

local function decodeBatteryConfig(buf)
  if type(buf) ~= "table" or #buf < msp_battery.BATTERY_CONFIG_SIZE then
    return nil, "short_payload"
  end

  local batteryCapacity = mspcodec.readU16(buf)
  local cellCount = mspcodec.readU8(buf)
  mspcodec.readU8(buf) -- voltageMeterSource (unused)
  mspcodec.readU8(buf) -- currentMeterSource (unused)
  local vbatMinCell = mspcodec.readU16(buf) / 100
  local vbatMaxCell = mspcodec.readU16(buf) / 100
  local vbatFullCell = mspcodec.readU16(buf) / 100
  local vbatWarningCell = mspcodec.readU16(buf) / 100
  mspcodec.readU8(buf) -- lvcPercentage (unused)
  local consumptionWarningPercentage = mspcodec.readU8(buf)
  local profiles = {}
  for i = 0, 5 do
    profiles[i] = mspcodec.readU16(buf)
  end
  return {
    batteryCapacity = batteryCapacity,
    cellCount = cellCount,
    vbatMinCell = vbatMinCell,
    vbatMaxCell = vbatMaxCell,
    vbatFullCell = vbatFullCell,
    vbatWarningCell = vbatWarningCell,
    consumptionWarningPercentage = consumptionWarningPercentage,
    profiles = profiles,
  }
end

function msp_battery.buildBatteryConfigReadMessage(onData, onError)
  return {
    command = msp_battery.BATTERY_CONFIG_READ_COMMAND,
    processReply = function(_, buf)
      local config, reason = decodeBatteryConfig(buf)
      if not config then
        if onError then onError(reason) end
        return
      end
      onData(config)
    end,
    errorHandler = onError,
    simulatorResponse = {
      136, 19, -- batteryCapacity = 5000 mAh
      6,       -- batteryCellCount
      1,       -- voltageMeterSource
      1,       -- currentMeterSource
      74, 1,   -- vbatmincellvoltage = 330 -> 3.30V
      164, 1,  -- vbatmaxcellvoltage = 420 -> 4.20V
      154, 1,  -- vbatfullcellvoltage = 410 -> 4.10V
      94, 1,   -- vbatwarningcellvoltage = 350 -> 3.50V
      100,     -- lvcPercentage
      30,      -- consumptionWarningPercentage
      232, 3, 20, 5, 64, 6, 108, 7, 152, 8, 196, 9, -- batteryCapacity_0..5
    },
  }
end

msp_battery.SMARTFUEL_CONFIG_READ_COMMAND = 0x4000

-- Same handler, case MSP2_GET_SMARTFUEL_CONFIG (guarded by USE_SMARTFUEL):
-- four u8 fields -- smartfuel_mode, voltage_drop_rate, charge_drop_rate,
-- sag_gain.
msp_battery.SMARTFUEL_CONFIG_SIZE = 4

local function decodeSmartfuelConfig(buf)
  if type(buf) ~= "table" or #buf < msp_battery.SMARTFUEL_CONFIG_SIZE then
    return nil, "short_payload"
  end

  local mode = mspcodec.readU8(buf)
  local voltageDropRate = mspcodec.readU8(buf)
  local chargeDropRate = mspcodec.readU8(buf)
  mspcodec.readU8(buf) -- sag_gain (unused -- no sag compensation, see lib/smartfuel_calc.lua)
  return {
    mode = mode,
    voltageFallPerSecond = voltageDropRate / 1000, -- mV/s -> V/s
    chargeDropPerSecond = chargeDropRate / 10000,  -- raw -> fraction/s
  }
end

-- mode: 0 = off (FC doesn't compute/broadcast it -- run the local
-- fallback, see lib/smartfuel_calc.lua), 1/2/3 = voltage/current/combined
-- (FC computes it on-board and broadcasts it -- just mirror the sensor,
-- see tasks/session.lua).
function msp_battery.buildSmartfuelConfigReadMessage(onData, onError)
  return {
    command = msp_battery.SMARTFUEL_CONFIG_READ_COMMAND,
    processReply = function(_, buf)
      local config, reason = decodeSmartfuelConfig(buf)
      if not config then
        if onError then onError(reason) end
        return
      end
      onData(config)
    end,
    errorHandler = onError,
    simulatorResponse = {0, 10, 50, 40},
  }
end

return msp_battery
