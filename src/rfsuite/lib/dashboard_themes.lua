-- Dashboard theme registry.
--
-- Two places hold themes: the ones shipped with the suite, under
-- widgets/dashboard/themes/<folder>/, and the pilot's own, under
-- SCRIPTS:/rfsuite.user/dashboard/<folder>/. The user folder survives a suite
-- update, so a copied or hand-written theme is not lost when the suite is
-- reinstalled.
--
-- A stored theme choice names its source: "system/<folder>" or
-- "user/<folder>". A bare "<folder>" (older settings files) means a shipped
-- theme. The key used for a theme's settings section ("dashboard.<key>") and
-- for the widget's caches is "<folder>" for a shipped theme, as it always was,
-- and "user/<folder>" for a user theme, so a user copy named like a shipped
-- theme keeps settings of its own.
--
-- parse()/key()/path()/dir() do no file I/O: settings_store calls them from
-- withDefaults(), which runs on the dashboard's paint path. Whether a user
-- theme still exists is only checked when it is listed (theme pages) or
-- loaded (the widget falls back to Default when it cannot be loaded).

if package.loaded["rfsuite.lib.dashboard_themes"] then
  return package.loaded["rfsuite.lib.dashboard_themes"]
end

local SHIPPED_DIR = "widgets/dashboard/themes"
local USER_DIR = "SCRIPTS:/rfsuite.user/dashboard"
local DEFAULT_FOLDER = "default"

local SHIPPED = {
  bastion = true,
  ["aerc-n"] = true,
  aerc = true,
  claude = true,
  danielrc = true,
  default = true,
  gismo = true,
  helihud = true,
  kevd = true,
  kse4 = true,
  kse5 = true,
  rfstatus = true,
  ["rt-rc-n"] = true,
  ["rt-rc"] = true,
  ["srb-rc"] = true,
  timer = true,
}

local dashboard_themes = {
  USER_DIR = USER_DIR,
  DEFAULT_PATH = "system/" .. DEFAULT_FOLDER,
  DEFAULT_KEY = DEFAULT_FOLDER,
}

-- One path segment, no spaces: the folder name ends up in an INI section
-- heading ("[dashboard.user/<folder>]"), which settings_store only accepts
-- without whitespace.
local function validUserFolder(folder)
  return type(folder) == "string" and folder:match("^[%w_%-%.]+$") ~= nil and folder ~= "." and folder ~= ".."
end

--- Returns source ("system" or "user") and folder, or nil for an unknown or
--- malformed value.
function dashboard_themes.parse(value)
  if type(value) ~= "string" or value == "" then return nil end
  local source, folder = value:match("^([^/]+)/(.+)$")
  if not source then source, folder = "system", value end
  if folder:sub(1, 1) == "@" then folder = folder:sub(2) end
  if source == "system" then
    if SHIPPED[folder] then return "system", folder end
  elseif source == "user" then
    if validUserFolder(folder) then return "user", folder end
  end
  return nil
end

-- path() and key() run from settings_store.withDefaults() and from the
-- widget's theme selection on every paint, always on the same handful of
-- stored strings, so each answer is kept per input. false marks a value that
-- is not a theme. The inputs come from settings.ini and model files, so the
-- tables stay as small as the number of distinct theme values ever stored.
local pathCache = {}
local keyCache = {}

--- Canonical stored value ("system/<folder>" or "user/<folder>"), or nil.
function dashboard_themes.path(value)
  if type(value) ~= "string" then return nil end
  local cached = pathCache[value]
  if cached ~= nil then return cached or nil end
  local source, folder = dashboard_themes.parse(value)
  cached = source and (source .. "/" .. folder) or false
  pathCache[value] = cached
  return cached or nil
end

--- Settings/cache key ("<folder>" or "user/<folder>"), or nil.
function dashboard_themes.key(value)
  if type(value) ~= "string" then return nil end
  local cached = keyCache[value]
  if cached ~= nil then return cached or nil end
  local source, folder = dashboard_themes.parse(value)
  if source == "system" then
    cached = folder
  elseif source == "user" then
    cached = "user/" .. folder
  else
    cached = false
  end
  keyCache[value] = cached
  return cached or nil
end

--- Folder the theme's files load from, and whether it is a user theme.
function dashboard_themes.dir(value)
  local source, folder = dashboard_themes.parse(value)
  if source == "user" then return USER_DIR .. "/" .. folder, true end
  if source == "system" then return SHIPPED_DIR .. "/" .. folder, false end
  return SHIPPED_DIR .. "/" .. DEFAULT_FOLDER, false
end

local function fileExists(path)
  local f = io.open(path, "rb")
  if f then
    f:close()
    return true
  end
  return false
end

local userCache = nil

--- The user themes found in USER_DIR: a list of
--- {folder, path, key, dir, label}, sorted by folder name. A folder counts
--- when it holds an init.lua. The list is kept for the Lua session; pass
--- refresh = true to read the folder again (the theme pages do on open, so a
--- theme copied in over USB shows without restarting).
function dashboard_themes.listUser(refresh)
  if userCache and not refresh then return userCache end
  local themes = {}
  if system and system.listFiles then
    local ok, names = pcall(system.listFiles, USER_DIR)
    if ok and type(names) == "table" then
      for i = 1, #names do
        local folder = tostring(names[i] or ""):gsub("/$", "")
        if validUserFolder(folder) and not folder:match("%.lua$") then
          local dir = USER_DIR .. "/" .. folder
          if fileExists(dir .. "/init.lua") then
            themes[#themes + 1] = {
              folder = folder,
              path = "user/" .. folder,
              key = "user/" .. folder,
              dir = dir,
              label = folder,
            }
          end
        end
      end
    end
  end
  table.sort(themes, function(a, b) return a.folder:lower() < b.folder:lower() end)
  userCache = themes
  return themes
end

package.loaded["rfsuite.lib.dashboard_themes"] = dashboard_themes
return dashboard_themes
