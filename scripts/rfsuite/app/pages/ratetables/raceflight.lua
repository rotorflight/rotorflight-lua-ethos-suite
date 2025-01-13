local rTableName = "RACEFLIGHT"
local rows = {"Roll", "Pitch", "Yaw", "Col"}
local cols = {"Rate", "Acro+", "Expo"}
local fields = {}

-- rc rate
fields[#fields + 1] = {row = 1, col = 1, min = 0, max = 100, vals = {2}, default = 36, mult = 10}
fields[#fields + 1] = {row = 2, col = 1, min = 0, max = 100, vals = {8}, default = 36, mult = 10}
fields[#fields + 1] = {row = 3, col = 1, min = 0, max = 100, vals = {14}, default = 36, mult = 10}
fields[#fields + 1] = {row = 4, col = 1, min = 0, max = 100, vals = {20}, default = 50, decimals = 1, scale = 4}
-- fc rate
fields[#fields + 1] = {row = 1, col = 2, min = 0, max = 255, vals = {4}, default = 0}
fields[#fields + 1] = {row = 2, col = 2, min = 0, max = 255, vals = {10}, default = 0}
fields[#fields + 1] = {row = 3, col = 2, min = 0, max = 255, vals = {16}, default = 0}
fields[#fields + 1] = {row = 4, col = 2, min = 0, max = 255, vals = {22}, default = 0}
--  expo
fields[#fields + 1] = {row = 1, col = 3, min = 0, max = 100, vals = {3}, default = 0}
fields[#fields + 1] = {row = 2, col = 3, min = 0, max = 100, vals = {9}, default = 0}
fields[#fields + 1] = {row = 3, col = 3, min = 0, max = 100, vals = {15}, default = 0}
fields[#fields + 1] = {row = 4, col = 3, min = 0, max = 100, vals = {21}, default = 0}

return {rTableName = rTableName, rows = rows, cols = cols, fields = fields}
