--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    ["smartfuel_mode"] = "Choose whether firmware SmartFuel is disabled, voltage-estimated, current consumption based, or combined. Combined uses the more pessimistic of voltage and current consumption.",
    ["voltage_drop_rate"] = "Limits how fast the measured per-cell voltage can fall (mV/s). Only applies in Voltage and Combined modes. Lower values produce a smoother but slower-responding estimate; higher values allow faster tracking.",
    ["charge_drop_rate"] = "Limits how fast the fuel percentage can drop per second on the voltage track. Only applies in Voltage and Combined modes once the model has been armed. Lower values give a more stable gauge during aggressive flying; higher values allow faster discharge tracking.",
    ["sag_gain"] = "Compensates for voltage sag under collective and cyclic load while airborne. Only applies in Voltage and Combined modes. Higher values apply more compensation; set to 0 to disable.",
}
