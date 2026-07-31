-- ZTW forward-programming payload (MSP 217 read / 218 write).

if package.loaded["rfsuite.lib.msp_esc_parameters_ztw"] then
  return package.loaded["rfsuite.lib.msp_esc_parameters_ztw"]
end

local base = assert(loadfile("lib/msp_esc_parameters_xdfly.lua"))()

local msp = {}
for key, value in pairs(base) do msp[key] = value end

msp.TITLE = "ZTW"
msp.EXPECTED_SIGNATURE = 221

function msp.buildReadMessage(onData, onError)
  local msg = base.buildReadMessage(onData, onError)
  msg.simulatorResponse = {
    221, 0, 23, 3,
    0, 0, -- governor
    0, 0, -- cell_cutoff
    0, 0, -- timing
    0, 0, -- lv_bec_voltage
    0, 0, -- motor_direction
    4, 0, -- gov_p
    3, 0, -- gov_i
    0, 0, -- acceleration
    0, 0, -- auto_restart_time
    0, 0, -- hv_bec_voltage
    0, 0, -- startup_power
    0, 0, -- brake_type
    0, 0, -- brake_force
    0, 0, -- sr_function
    0, 0, -- capacity_correction
    9, 0, -- motor_poles
    0, 0, -- led_color
    0, 0, -- smart_fan
    238, 255, 1, 0 -- activefields
  }
  return msg
end

function msp.buildWriteMessage(data, onWritten, onError)
  if data then data.esc_signature = data.esc_signature or 221 end
  return base.buildWriteMessage(data, onWritten, onError)
end

package.loaded["rfsuite.lib.msp_esc_parameters_ztw"] = msp
return msp
