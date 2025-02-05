local rTableName = "RACEFLIGHT"
local rows = {"Roll", "Pitch", "Yaw", "Col"}
local cols = {"Rate", "Acro+", "Expo"}
local fields = {}

-- rc rate
fields[#fields + 1] = {row = 1, col = 1, min = 0, max = 100, default = 36, mult = 10, apikey = "rcRates_1"}
fields[#fields + 1] = {row = 2, col = 1, min = 0, max = 100, default = 36, mult = 10, apikey = "rcRates_2"}
fields[#fields + 1] = {row = 3, col = 1, min = 0, max = 100, default = 36, mult = 10, apikey = "rcRates_3"}
fields[#fields + 1] = {row = 4, col = 1, min = 0, max = 100, default = 50, decimals = 1, scale = 4, apikey = "rcRates_4"}
-- fc rate
fields[#fields + 1] = {row = 1, col = 2, min = 0, max = 255, default = 0, apikey = "rates_1"}
fields[#fields + 1] = {row = 2, col = 2, min = 0, max = 255, default = 0, apikey = "rates_2"}
fields[#fields + 1] = {row = 3, col = 2, min = 0, max = 255, default = 0, apikey = "rates_3"}
fields[#fields + 1] = {row = 4, col = 2, min = 0, max = 255, default = 0, apikey = "rates_4"}
--  expo
fields[#fields + 1] = {row = 1, col = 3, min = 0, max = 100, default = 0, apikey = "rcExpo_1"}
fields[#fields + 1] = {row = 2, col = 3, min = 0, max = 100, default = 0, apikey = "rcExpo_2"}
fields[#fields + 1] = {row = 3, col = 3, min = 0, max = 100, default = 0, apikey = "rcExpo_3"}
fields[#fields + 1] = {row = 4, col = 3, min = 0, max = 100, default = 0, apikey = "rcExpo_4"}

return {rTableName = rTableName, rows = rows, cols = cols, fields = fields}
