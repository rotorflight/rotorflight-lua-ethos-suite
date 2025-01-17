local rTableName = "NONE"
local rows = {"Roll", "Pitch", "Yaw", "Col"}
local cols = {"RC Rate", "Rate", "Expo"}
local fields = {}

-- rc rate
fields[#fields + 1] = {disable = true, row = 1, col = 1, min = 0, max = 0, vals = {2}, default = 0}
fields[#fields + 1] = {disable = true, row = 2, col = 1, min = 0, max = 0, vals = {8}, default = 0}
fields[#fields + 1] = {disable = true, row = 3, col = 1, min = 0, max = 0, vals = {14}, default = 0}
fields[#fields + 1] = {disable = true, row = 4, col = 1, min = 0, max = 0, vals = {20}, default = 0}
-- fc rate
fields[#fields + 1] = {disable = true, row = 1, col = 2, min = 0, max = 0, vals = {4}, default = 0}
fields[#fields + 1] = {disable = true, row = 2, col = 2, min = 0, max = 0, vals = {10}, default = 0}
fields[#fields + 1] = {disable = true, row = 3, col = 2, min = 0, max = 0, vals = {16}, default = 0}
fields[#fields + 1] = {disable = true, row = 4, col = 2, min = 0, max = 0, vals = {22}, default = 0}
--  expo
fields[#fields + 1] = {disable = true, row = 1, col = 3, min = 0, max = 0, vals = {3}, default = 0}
fields[#fields + 1] = {disable = true, row = 2, col = 3, min = 0, max = 0, vals = {9}, default = 0}
fields[#fields + 1] = {disable = true, row = 3, col = 3, min = 0, max = 0, vals = {15}, default = 0}
fields[#fields + 1] = {disable = true, row = 4, col = 3, min = 0, max = 0, vals = {21}, default = 0}

return {rTableName = rTableName, rows = rows, cols = cols, fields = fields}
