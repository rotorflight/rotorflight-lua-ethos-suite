--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

-- Column reader for the Logs page (#2506).
--
-- The first row of a CSV file names its columns. A column is read by that name,
-- not by its position, so a log that is not written by this suite (different
-- order, extra or missing columns) is plotted from the columns it really has.
-- Pure functions over the file's text, no UI and no file access, so the same
-- code is checked by bin/log_columns/verify_log_columns.lua.

local M = {}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Maps each column name in the header row to its 1-based column index.
-- A name that appears twice keeps its first column. No header gives an empty map.
function M.headerIndex(csvText)
  local map = {}
  local firstLine = csvText:match("^([^\r\n]*)") or ""
  local index = 0
  for field in (firstLine .. ","):gmatch("([^,]*),") do
    index = index + 1
    local name = trim(field)
    if name ~= "" and map[name] == nil then map[name] = index end
  end
  return map
end

-- Number of data rows: every non-empty line after the header row.
function M.dataRowCount(csvText)
  local count = 0
  local first = true
  for _ in csvText:gmatch("[^\r\n]+") do
    if first then
      first = false
    else
      count = count + 1
    end
  end
  return count
end

-- Values of one column over the data rows. A value that is not a number is 0,
-- as before; a row too short to reach the column gives 0 as well.
function M.column(csvText, colIndex)
  local out = {}
  local first = true
  for line in csvText:gmatch("[^\r\n]+") do
    if first then
      first = false
    else
      local index = 0
      local value = ""
      for field in (line .. ","):gmatch("([^,]*),") do
        index = index + 1
        if index == colIndex then
          value = field
          break
        end
      end
      out[#out + 1] = tonumber(value) or 0
    end
  end
  return out
end

return M
