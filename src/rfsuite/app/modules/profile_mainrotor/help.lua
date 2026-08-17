--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --


local data = {}

data['help'] = {}

data['help']['default'] = {"Collective Pitch Compensation: Increasing will compensate for the pitching motion caused by tail drag when climbing.", "Cross Coupling Gain: Removes roll coupling when only elevator is applied.", "Cross Coupling Ratio: Amount of compensation (pitch vs roll) to apply.", "Cross Coupling Freq. Limit: Frequency limit for the compensation, higher value will make the compensation action faster."}

data['fields'] = {}

return data
