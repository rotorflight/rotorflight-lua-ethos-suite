local rTableName = "NONE"
local rows = {"Roll", "Pitch", "Yaw", "Col"}
local cols = {"RC Rate", "Rate", "Expo"}
local fields = {}

-- rc rate
fields[#fields + 1] = {disable = true, row = 1, col = 1, min = 0, max = 0, default = 0, apikey = "rcRates_1"}
fields[#fields + 1] = {disable = true, row = 2, col = 1, min = 0, max = 0, default = 0, apikey = "rcRates_2"}
fields[#fields + 1] = {disable = true, row = 3, col = 1, min = 0, max = 0, default = 0, apikey = "rcRates_3"}
fields[#fields + 1] = {disable = true, row = 4, col = 1, min = 0, max = 0, default = 0, apikey = "rcRates_4"}
-- fc rate
fields[#fields + 1] = {disable = true, row = 1, col = 2, min = 0, max = 0, default = 0, apikey = "rates_1"}
fields[#fields + 1] = {disable = true, row = 2, col = 2, min = 0, max = 0, default = 0, apikey = "rates_2"}
fields[#fields + 1] = {disable = true, row = 3, col = 2, min = 0, max = 0, default = 0, apikey = "rates_3"}
fields[#fields + 1] = {disable = true, row = 4, col = 2, min = 0, max = 0, default = 0, apikey = "rates_4"}
--  expo
fields[#fields + 1] = {disable = true, row = 1, col = 3, min = 0, max = 0, default = 0, apikey = "rcExpo_1"}
fields[#fields + 1] = {disable = true, row = 2, col = 3, min = 0, max = 0, default = 0, apikey = "rcExpo_2"}
fields[#fields + 1] = {disable = true, row = 3, col = 3, min = 0, max = 0, default = 0, apikey = "rcExpo_3"}
fields[#fields + 1] = {disable = true, row = 4, col = 3, min = 0, max = 0, default = 0, apikey = "rcExpo_4"}

return {rTableName = rTableName, rows = rows, cols = cols, fields = fields}
