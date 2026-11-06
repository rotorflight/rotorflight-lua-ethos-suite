-- Tune Advisor Apply-record CSV, loaded only when the page first reads or
-- writes changes.csv. The flight-capture task needs tune_history.lua at boot,
-- but never needs this page-only functionality.
if package.loaded["rfsuite.lib.tune_history_changes"] then
  return package.loaded["rfsuite.lib.tune_history_changes"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ini = requireModule("lib/ini.lua")
local atomicWrite = requireModule("lib/atomic_write.lua")

local BASE_DIR = "LOGS:/rfsuite/tune"
local AXIS_COUNT = 3
local AXIS_NAMES = {"roll", "pitch", "yaw"}
local CHANGES_HEADER = "date,axis,setting,from,to,pid_profile"
local LEGACY_CHANGES_HEADER = "date,axis,setting,from,to"

local changes = {}

-- Keep a recognized pre-profile file usable by CSV readers after the first
-- profile-aware Apply. Preserve line endings and malformed rows; only legacy
-- five-column rows need an empty sixth field.
local function migrateLegacyChanges(path)
  local text = ini.load_file_as_string(path)
  if not text or text:match("^[^\r\n]*") ~= LEGACY_CHANGES_HEADER then return true end

  local out, lineNumber, start = {}, 0, 1
  while start <= #text do
    local ending = text:find("[\r\n]", start)
    local line, newline
    if ending then
      line = text:sub(start, ending - 1)
      newline = text:sub(ending, ending)
      if newline == "\r" and text:sub(ending + 1, ending + 1) == "\n" then
        newline = "\r\n"
      end
      start = ending + #newline
    else
      line, newline = text:sub(start), ""
      start = #text + 1
    end

    lineNumber = lineNumber + 1
    if lineNumber == 1 then
      line = CHANGES_HEADER
    elseif line ~= "" and select(2, line:gsub(",", "")) == 4 then
      line = line .. ","
    end
    out[#out + 1] = line .. newline
  end

  local migrated = table.concat(out)
  if migrated:sub(-1) ~= "\n" and migrated:sub(-1) ~= "\r" then
    migrated = migrated .. "\n"
  end
  return atomicWrite.write(path, migrated)
end

local function fileExists(path)
  local file = io.open(path, "rb")
  if not file then return false end
  pcall(function() file:close() end)
  return true
end

-- changes: {key, from, to} as the Tune Advisor page builds them; pidProfile
-- is the profile they were applied to (empty when the FC did not say)
function changes.logChanges(mcuId, axis, applied, pidProfile)
  local path = BASE_DIR .. "/" .. mcuId .. "/changes.csv"
  local isNew = not fileExists(path)
  if not isNew and not migrateLegacyChanges(path) then return false end
  local file = io.open(path, "a")
  if not file then return false end
  local date = os.date("%Y-%m-%d %H:%M:%S")
  -- Ethos' file:write/close do not report failures uniformly, so a failed
  -- write is caught by pcall, as atomic_write.lua does.
  local written = pcall(function()
    if isNew then file:write(CHANGES_HEADER, "\n") end
    for _, c in ipairs(applied) do
      file:write(string.format("%s,%s,%s,%d,%d,%s\n", date, AXIS_NAMES[axis], c.key, c.from, c.to, pidProfile or ""))
    end
  end)
  pcall(function() file:close() end)
  return written
end

-- The Apply record, oldest first: {axis, key, from, to, pidProfile} per row.
-- Every row that parses is read regardless of header. The writer upgrades only
-- the exact legacy header before appending; foreign files remain untouched.
-- Rows from before the pid_profile column read with pidProfile nil. A missing
-- file, or one with no such rows, reads as no changes.
function changes.readChanges(mcuId)
  local rows = {}
  local text = ini.load_file_as_string(BASE_DIR .. "/" .. mcuId .. "/changes.csv")
  if not text then return rows end
  local lines = {}
  for line in text:gmatch("[^\r\n]+") do lines[#lines + 1] = line end
  for i = 1, #lines do
    local axisName, key, from, to, pidProfile = lines[i]:match("^[^,]*,([^,]*),([^,]*),(%-?%d+),(%-?%d+),?(%d*)$")
    local axis = nil
    for n = 1, AXIS_COUNT do
      if AXIS_NAMES[n] == axisName then axis = n end
    end
    if axis then
      rows[#rows + 1] = {axis = axis, key = key, from = tonumber(from), to = tonumber(to), pidProfile = tonumber(pidProfile)}
    end
  end
  return rows
end

-- The value the pilot last set by hand for one setting (a TUNE_KEYS name) on
-- one PID profile, following the Apply record back through an unbroken chain.
-- Older rows without a profile are followed on any profile: they cannot say
-- which one they were made on.
function changes.pilotValue(rows, axis, key, value, pidProfile)
  for i = #rows, 1, -1 do
    local c = rows[i]
    local sameProfile = pidProfile == nil or c.pidProfile == nil or c.pidProfile == pidProfile
    if c.axis == axis and c.key == key and sameProfile then
      if c.to ~= value then break end
      value = c.from
    end
  end
  return value
end

package.loaded["rfsuite.lib.tune_history_changes"] = changes
return changes
