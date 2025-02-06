local rTableName = "ACTUAL"
local rows = {"Roll", "Pitch", "Yaw", "Col"}
local cols

if rfsuite.app.radio.text == 2 then
    cols = {"Cntr. Sens.", "Max Rate", "Expo"}
else
    cols = {"Center Sensitivity", "Max Rate", "Expo"}
end
local fields = {}

-- rc rate
fields[#fields + 1] = {row = 1, col = 1, min = 0, max = 100, default = 18, mult = 10, step = 10, apikey = "rcRates_1"}
fields[#fields + 1] = {row = 2, col = 1, min = 0, max = 100, default = 18, mult = 10, step = 10, apikey = "rcRates_2"}
fields[#fields + 1] = {row = 3, col = 1, min = 0, max = 100, default = 18, mult = 10, step = 10, apikey = "rcRates_3"}
fields[#fields + 1] = {row = 4, col = 1, min = 0, max = 100, default = 48, decimals = 1, step = 5, scale = 4, apikey = "rcRates_4"}
-- fc rate
fields[#fields + 1] = {row = 1, col = 2, min = 0, max = 100, default = 24, mult = 10, step = 10, apikey = "rates_1"}
fields[#fields + 1] = {row = 2, col = 2, min = 0, max = 100, default = 24, mult = 10, step = 10, apikey = "rates_2"}
fields[#fields + 1] = {row = 3, col = 2, min = 0, max = 100, default = 40, mult = 10, step = 10, apikey = "rates_3"}
fields[#fields + 1] = {row = 4, col = 2, min = 0, max = 100, default = 48, step = 5, decimals = 1, scale = 4, apikey = "rates_4"}
--  expo
fields[#fields + 1] = {row = 1, col = 3, min = 0, max = 100, decimals = 2, scale = 100, default = 0, apikey = "rcExpo_1"}
fields[#fields + 1] = {row = 2, col = 3, min = 0, max = 100, decimals = 2, scale = 100, default = 0, apikey = "rcExpo_2"}
fields[#fields + 1] = {row = 3, col = 3, min = 0, max = 100, decimals = 2, scale = 100, default = 0, apikey = "rcExpo_3"}
fields[#fields + 1] = {row = 4, col = 3, min = 0, max = 100, decimals = 2, scale = 100, default = 0, apikey = "rcExpo_4"}

return {rTableName = rTableName, rows = rows, cols = cols, fields = fields}
