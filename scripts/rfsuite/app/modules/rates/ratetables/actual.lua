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
fields[#fields + 1] = {row = 1, col = 1, min = 0, max = 100, vals = {2}, default = 18, mult = 10, step = 10}
fields[#fields + 1] = {row = 2, col = 1, min = 0, max = 100, vals = {8}, default = 18, mult = 10, step = 10}
fields[#fields + 1] = {row = 3, col = 1, min = 0, max = 100, vals = {14}, default = 18, mult = 10, step = 10}
fields[#fields + 1] = {row = 4, col = 1, min = 0, max = 100, vals = {20}, default = 48, decimals = 1, step = 5, scale = 4}
-- fc rate
fields[#fields + 1] = {row = 1, col = 2, min = 0, max = 100, vals = {4}, default = 24, mult = 10, step = 10}
fields[#fields + 1] = {row = 2, col = 2, min = 0, max = 100, vals = {10}, default = 24, mult = 10, step = 10}
fields[#fields + 1] = {row = 3, col = 2, min = 0, max = 100, vals = {16}, default = 40, mult = 10, step = 10}
fields[#fields + 1] = {row = 4, col = 2, min = 0, max = 100, vals = {22}, default = 48, step = 5, decimals = 1, scale = 4}
--  expo
fields[#fields + 1] = {row = 1, col = 3, min = 0, max = 100, vals = {3}, decimals = 2, scale = 100, default = 0}
fields[#fields + 1] = {row = 2, col = 3, min = 0, max = 100, vals = {9}, decimals = 2, scale = 100, default = 0}
fields[#fields + 1] = {row = 3, col = 3, min = 0, max = 100, vals = {15}, decimals = 2, scale = 100, default = 0}
fields[#fields + 1] = {row = 4, col = 3, min = 0, max = 100, vals = {21}, decimals = 2, scale = 100, default = 0}

return {rTableName = rTableName, rows = rows, cols = cols, fields = fields}
