local rTableName = "QUICK"
local rows = {"Roll", "Pitch", "Yaw", "Col"}
local cols = {"RC Rate", "Max Rate", "Expo"}
local fields = {}

-- rc rate
fields[#fields + 1] = {row = 1, col = 1, min = 0, max = 255, default = 180, decimals = 2, scale = 100, apikey = "rcRates_1"}
fields[#fields + 1] = {row = 2, col = 1, min = 0, max = 255, default = 180, decimals = 2, scale = 100, apikey = "rcRates_2"}
fields[#fields + 1] = {row = 3, col = 1, min = 0, max = 255, default = 180, decimals = 2, scale = 100, apikey = "rcRates_3"}
fields[#fields + 1] = {row = 4, col = 1, min = 0, max = 255, default = 205, decimals = 2, scale = 100, apikey = "rcRates_4"}
-- fc rate
fields[#fields + 1] = {row = 1, col = 2, min = 0, max = 100, default = 36, mult = 10, step = 10, apikey = "rates_1"}
fields[#fields + 1] = {row = 2, col = 2, min = 0, max = 100, default = 36, mult = 10, step = 10, apikey = "rates_2"}
fields[#fields + 1] = {row = 3, col = 2, min = 0, max = 100, default = 36, mult = 10, step = 10, apikey = "rates_3"}
fields[#fields + 1] = {row = 4, col = 2, min = 0, max = 208.2, default = 104.16, mult = 4.807, step = 10, apikey = "rates_4"}
--  expo
fields[#fields + 1] = {row = 1, col = 3, min = 0, max = 100, decimals = 2, scale = 100, default = 0, apikey = "rcExpo_1"}
fields[#fields + 1] = {row = 2, col = 3, min = 0, max = 100, decimals = 2, scale = 100, default = 0, apikey = "rcExpo_2"}
fields[#fields + 1] = {row = 3, col = 3, min = 0, max = 100, decimals = 2, scale = 100, default = 0, apikey = "rcExpo_3"}
fields[#fields + 1] = {row = 4, col = 3, min = 0, max = 100, decimals = 2, scale = 100, default = 0, apikey = "rcExpo_4"}

return {rTableName = rTableName, rows = rows, cols = cols, fields = fields}
