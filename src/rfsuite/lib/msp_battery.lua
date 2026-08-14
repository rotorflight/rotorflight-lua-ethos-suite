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

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local msp_battery = {}

msp_battery.BATTERY_CONFIG_READ_COMMAND = 32

function msp_battery.buildBatteryConfigReadMessage(onData, onError)
  return {
    command = msp_battery.BATTERY_CONFIG_READ_COMMAND,
    processReply = function(_, buf)
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
      onData({
        batteryCapacity = batteryCapacity,
        cellCount = cellCount,
        vbatMinCell = vbatMinCell,
        vbatMaxCell = vbatMaxCell,
        vbatFullCell = vbatFullCell,
        vbatWarningCell = vbatWarningCell,
        consumptionWarningPercentage = consumptionWarningPercentage,
        profiles = profiles,
      })
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

-- mode: 0 = off (FC doesn't compute/broadcast it -- run the local
-- fallback, see lib/smartfuel_calc.lua), 1/2/3 = voltage/current/combined
-- (FC computes it on-board and broadcasts it -- just mirror the sensor,
-- see tasks/session.lua).
function msp_battery.buildSmartfuelConfigReadMessage(onData, onError)
  return {
    command = msp_battery.SMARTFUEL_CONFIG_READ_COMMAND,
    processReply = function(_, buf)
      local mode = mspcodec.readU8(buf)
      local voltageDropRate = mspcodec.readU8(buf)
      local chargeDropRate = mspcodec.readU8(buf)
      mspcodec.readU8(buf) -- sag_gain (unused -- no sag compensation, see lib/smartfuel_calc.lua)
      onData({
        mode = mode,
        voltageFallPerSecond = voltageDropRate / 1000, -- mV/s -> V/s
        chargeDropPerSecond = chargeDropRate / 10000,  -- raw -> fraction/s
      })
    end,
    errorHandler = onError,
    simulatorResponse = {0, 10, 50, 40},
  }
end

return msp_battery
