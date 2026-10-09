-- The flight controllers this radio holds preferences for, found without a link.
--
-- One record per file in the models directory (lib/model_preferences.lua), sorted by id:
--
--   id        the board id the file is named after
--   name      what the board called itself, or nil where the file records none
--   path      the file
--   modified  when the file last changed, as os.stat() reports it: a table with
--             year/month/day/hour/minute/second, or nil
--
-- A nil name is the ordinary case and not an error: a store written before the name was
-- recorded has none, and a board that was never connected again never gets one. What to
-- show for such a record is the caller's.
--
-- `modified` is when the store was last written -- a rename, a synced flight count -- and
-- not when the board was last connected: a connect that changes nothing writes nothing.
-- It stays a table because os.time() on Ethos drops the minutes and seconds of the table
-- it is given (measured on the 26.1.3 simulator: 13:16:08 came back as 13:00:00), so an
-- epoch built from it would claim a precision it does not have.
--
-- COST. One directory listing, then per store one open, one parse and one stat. That is a
-- tool-session cost, the same class as opening a page, and not a call for a widget pass or
-- a wakeup. Nothing is cached: the answer is a fact about the card. It writes nothing.
--
-- Load it where it is called (`requireModule("lib/known_models.lua")` at the call site, not
-- at the top of a file the boot reaches): it is dead weight in a session that never lists.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ini = requireModule("lib/ini.lua")
local modelPreferences = requireModule("lib/model_preferences.lua")

local known_models = {}

local function modifiedOf(path)
  if not (os and os.stat) then return nil end
  local ok, info = pcall(os.stat, path)
  if not ok or type(info) ~= "table" or type(info.mtime) ~= "table" then return nil end
  local m = info.mtime
  return { year = m.year, month = m.month, day = m.day, hour = m.hour, minute = m.minute, second = m.second }
end

function known_models.list()
  local out = {}
  if not (system and system.listFiles) then return out end

  local ok, files = pcall(system.listFiles, modelPreferences.MODELS_DIR)
  if not ok or type(files) ~= "table" then return out end

  local ids = {}
  for i = 1, #files do
    -- "<id>.ini" only. The listing also carries "..", sub-directories and the ".tmp" a
    -- write in flight leaves behind (lib/atomic_write.lua), none of which end in ".ini".
    local id = type(files[i]) == "string" and files[i]:match("^(.+)%.ini$") or nil
    if id then ids[#ids + 1] = id end
  end

  -- The bare sort: the comparison happens in C, and the order must not depend on how the
  -- firmware happens to list the directory.
  table.sort(ids)

  for i = 1, #ids do
    -- The file as it is called, not as pathFor() would spell the id: a name this suite
    -- never wrote is read from where it is.
    local path = modelPreferences.MODELS_DIR .. "/" .. ids[i] .. ".ini"
    -- A store that will not parse is still a store: the record stays, without a name.
    local parsed, raw = pcall(ini.load_ini_file, path)
    out[i] = {
      id = ids[i],
      name = parsed and modelPreferences.craftNameOf(raw) or nil,
      path = path,
      modified = modifiedOf(path),
    }
  end

  return out
end

return known_models
