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
local ROW_PATTERN = "^([^,]*),([^,]*),([^,]*),(%-?%d+),(%-?%d+),?(%d*)$"
-- The record is started afresh once an Apply leaves it above this size (#2807): it was
-- appended forever and read whole on every page open.
local COMPACT_BYTES = 16 * 1024
local MAX_PID_PROFILES = 6

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

local function changesPath(mcuId)
  return BASE_DIR .. "/" .. mcuId .. "/changes.csv"
end

-- The record before the last restart, kept until the next one
local function backupPath(path)
  return path .. ".old"
end

local function axisOf(name)
  for n = 1, AXIS_COUNT do
    if AXIS_NAMES[n] == name then return n end
  end
  return nil
end

-- Calls fn(date, axis, key, from, to, pidProfile) for every row that parses, oldest first,
-- reading the file line by line rather than as one string. Returns the bytes read, or nil when
-- the file cannot be opened.
local function eachRow(path, fn)
  local file = io.open(path, "rb")
  if not file then return nil end
  local bytes = 0
  while true do
    local line = file:read("L")
    if not line then break end
    bytes = bytes + #line
    local date, axisName, key, from, to, pidProfile = line:gsub("[\r\n]+$", ""):match(ROW_PATTERN)
    local axis = axisOf(axisName)
    if axis and fn then fn(date, axis, key, tonumber(from), tonumber(to), tonumber(pidProfile)) end
  end
  pcall(function() file:close() end)
  return bytes
end

-- Starts the record afresh with one row per setting and PID profile: the page's newest unbroken
-- chain of its own changes, from the value it started at to the value it ended at. pilotValue()
-- follows only that chain back from the current value, so it answers the same as over the whole
-- record for every setting, PID profile and current value. A row without a profile (written
-- before the column existed) counts on every profile, as pilotValue() counts it.
-- The new record is staged beside the old one; the old one is kept as the backup.
local function compact(path)
  local chains, order = {}, {}
  local read = eachRow(path, function(date, axis, key, from, to, pidProfile)
    for p = 1, MAX_PID_PROFILES do
      if pidProfile == nil or pidProfile == p then
        local id = axis .. "|" .. key .. "|" .. p
        local c = chains[id]
        if c and c.to == from then
          c.to, c.date = to, date
        elseif c then
          c.from, c.to, c.date = from, to, date
        else
          chains[id] = {axis = axis, key = key, profile = p, from = from, to = to, date = date}
          order[#order + 1] = id
        end
      end
    end
  end)
  if not read then return false end

  local handle = atomicWrite.stage(path)
  if not handle then return false end
  local ok = pcall(function()
    handle:write(CHANGES_HEADER, "\n")
    for _, id in ipairs(order) do
      local c = chains[id]
      handle:write(string.format("%s,%s,%s,%d,%d,%d\n", c.date, AXIS_NAMES[c.axis], c.key, c.from, c.to, c.profile))
    end
  end)
  if not ok then
    atomicWrite.abort(handle, path)
    return false
  end
  local backup = backupPath(path)
  pcall(os.remove, backup)
  pcall(os.rename, path, backup)
  return atomicWrite.commit(handle, path)
end

-- changes: {key, from, to, axis} as the Tune Advisor page builds them; axis is the
-- axis the setting was written to (the Cyclic axis for roll under polar cyclic) and
-- defaults to the axis given. pidProfile is the profile they were applied to (empty
-- when the FC did not say)
function changes.logChanges(mcuId, axis, applied, pidProfile)
  local path = changesPath(mcuId)
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
      file:write(string.format("%s,%s,%s,%d,%d,%s\n", date, AXIS_NAMES[c.axis or axis], c.key, c.from, c.to, pidProfile or ""))
    end
  end)
  pcall(function() file:close() end)
  -- A restart that fails keeps the full record: the Apply above is already in it
  if written and (eachRow(path) or 0) > COMPACT_BYTES then compact(path) end
  return written
end

-- The Apply record, oldest first: {axis, key, from, to, pidProfile} per row, read line by line.
-- Every row that parses is read regardless of header. The writer upgrades only
-- the exact legacy header before appending; foreign files remain untouched.
-- Rows from before the pid_profile column read with pidProfile nil. A missing
-- file, or one with no such rows, reads as no changes.
function changes.readChanges(mcuId)
  local rows = {}
  local path = changesPath(mcuId)
  -- An interrupted restart leaves only the backup
  if not fileExists(path) then path = backupPath(path) end
  eachRow(path, function(_, axis, key, from, to, pidProfile)
    rows[#rows + 1] = {axis = axis, key = key, from = from, to = to, pidProfile = pidProfile}
  end)
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
