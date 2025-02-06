local rTableName = "BETAFLIGHT"
local rows = {"Roll", "Pitch", "Yaw", "Col"}
local cols = {"RC Rate", "SuperRate", "Expo"}
local fields = {}

-- rc rate
fields[#fields + 1] = {row = 1, col = 1, min = 0, max = 255, default = 180, decimals = 2, scale = 100, apikey = "rcRates_1"}
fields[#fields + 1] = {row = 2, col = 1, min = 0, max = 255, default = 180, decimals = 2, scale = 100, apikey = "rcRates_2"}
fields[#fields + 1] = {row = 3, col = 1, min = 0, max = 255, default = 180, decimals = 2, scale = 100, apikey = "rcRates_3"}
fields[#fields + 1] = {row = 4, col = 1, min = 0, max = 255, default = 203, decimals = 2, scale = 100, apikey = "rcRates_4"}
-- fc rate
fields[#fields + 1] = {row = 1, col = 2, min = 0, max = 100, default = 0, decimals = 2, scale = 100, apikey = "rates_1"}
fields[#fields + 1] = {row = 2, col = 2, min = 0, max = 100, default = 0, decimals = 2, scale = 100, apikey = "rates_2"}
fields[#fields + 1] = {row = 3, col = 2, min = 0, max = 100, default = 0, decimals = 2, scale = 100, apikey = "rates_3"}
fields[#fields + 1] = {row = 4, col = 2, min = 0, max = 100, default = 1, decimals = 2, scale = 100, apikey = "rates_4"}
--  expo
fields[#fields + 1] = {row = 1, col = 3, min = 0, max = 100, decimals = 2, scale = 100, default = 0, apikey = "rcExpo_1"}
fields[#fields + 1] = {row = 2, col = 3, min = 0, max = 100, decimals = 2, scale = 100, default = 0, apikey = "rcExpo_2"}
fields[#fields + 1] = {row = 3, col = 3, min = 0, max = 100, decimals = 2, scale = 100, default = 0, apikey = "rcExpo_3"}
fields[#fields + 1] = {row = 4, col = 3, min = 0, max = 100, decimals = 2, scale = 100, default = 0, apikey = "rcExpo_4"}

return {rTableName = rTableName, rows = rows, cols = cols, fields = fields}
