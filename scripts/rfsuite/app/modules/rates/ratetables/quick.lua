local rTableName = "QUICK"
local rows = {"Roll", "Pitch", "Yaw", "Col"}
local cols = {"RC Rate", "Max Rate", "Expo"}
local fields = {}

-- rc rate
fields[#fields + 1] = {row = 1, col = 1, min = 0, max = 255, vals = {2}, default = 180, decimals = 2, scale = 100}
fields[#fields + 1] = {row = 2, col = 1, min = 0, max = 255, vals = {8}, default = 180, decimals = 2, scale = 100}
fields[#fields + 1] = {row = 3, col = 1, min = 0, max = 255, vals = {14}, default = 180, decimals = 2, scale = 100}
fields[#fields + 1] = {row = 4, col = 1, min = 0, max = 255, vals = {20}, default = 205, decimals = 2, scale = 100}
-- fc rate
fields[#fields + 1] = {row = 1, col = 2, min = 0, max = 100, vals = {4}, default = 36, mult = 10, step = 10}
fields[#fields + 1] = {row = 2, col = 2, min = 0, max = 100, vals = {10}, default = 36, mult = 10, step = 10}
fields[#fields + 1] = {row = 3, col = 2, min = 0, max = 100, vals = {16}, default = 36, mult = 10, step = 10}
fields[#fields + 1] = {row = 4, col = 2, min = 0, max = 208.2, vals = {22}, default = 104.16, mult = 4.807, step = 10}
--  expo
fields[#fields + 1] = {row = 1, col = 3, min = 0, max = 100, vals = {3}, decimals = 2, scale = 100, default = 0}
fields[#fields + 1] = {row = 2, col = 3, min = 0, max = 100, vals = {9}, decimals = 2, scale = 100, default = 0}
fields[#fields + 1] = {row = 3, col = 3, min = 0, max = 100, vals = {15}, decimals = 2, scale = 100, default = 0}
fields[#fields + 1] = {row = 4, col = 3, min = 0, max = 100, vals = {21}, decimals = 2, scale = 100, default = 0}

return {rTableName = rTableName, rows = rows, cols = cols, fields = fields}
