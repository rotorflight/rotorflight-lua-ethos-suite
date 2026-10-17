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

local BOM = "\239\187\191" -- the UTF-8 byte order mark, as it appears at the start of a file

-- Splits one CSV record into its fields. A field that starts with a double quote
-- runs to its closing quote: a comma inside it is data, and a doubled quote is one
-- literal quote. The surrounding quotes are removed and what follows a closing
-- quote is kept. A quoted field that spans more than one line is not supported --
-- a record is one line here, which is what a log written by this suite is.
local function fields(line)
  local out = {}
  local buf = {}
  local inQuotes = false
  local i = 1
  while i <= #line do
    local ch = line:sub(i, i)
    if inQuotes then
      if ch == '"' then
        if line:sub(i + 1, i + 1) == '"' then
          buf[#buf + 1] = '"'
          i = i + 1
        else
          inQuotes = false
        end
      else
        buf[#buf + 1] = ch
      end
    elseif ch == "," then
      out[#out + 1] = table.concat(buf)
      buf = {}
    elseif ch == '"' and #buf == 0 then
      inQuotes = true
    else
      buf[#buf + 1] = ch
    end
    i = i + 1
  end
  out[#out + 1] = table.concat(buf)
  return out
end

-- Maps each column name in the header row to its 1-based column index.
-- A name that appears twice keeps its first column. No header gives an empty map.
-- A leading byte order mark is not part of the first name.
function M.headerIndex(csvText)
  local firstLine = csvText:match("^([^\r\n]*)") or ""
  if firstLine:sub(1, #BOM) == BOM then firstLine = firstLine:sub(#BOM + 1) end
  local map = {}
  local names = fields(firstLine)
  for index = 1, #names do
    local name = trim(names[index])
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
      out[#out + 1] = tonumber(fields(line)[colIndex] or "") or 0
    end
  end
  return out
end

return M
