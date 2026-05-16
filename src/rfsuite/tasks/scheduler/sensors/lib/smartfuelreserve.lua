--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local reserve = {}

local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local tonumber = tonumber

function reserve.applyPercent(value, warningPercent, enabled)
    if value == nil then return nil end

    local fuel = math_min(100, math_max(0, tonumber(value) or 0))
    if enabled == false then
        return math_floor(fuel + 0.5)
    end

    local warning = math_min(99, math_max(0, tonumber(warningPercent) or 0))
    if warning > 0 then
        fuel = (fuel - warning) * 100 / (100 - warning)
    end

    return math_floor(math_min(100, math_max(0, fuel)) + 0.5)
end

return reserve
