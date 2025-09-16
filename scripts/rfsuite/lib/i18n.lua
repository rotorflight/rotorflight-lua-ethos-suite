-- i18n.lua (no upvalue caches; safe for hot-reload)
local i18n = {}

-- Config
i18n.defaultLocale   = "en"
i18n.folder          = "i18n"
i18n.HOT_SIZE        = 50
i18n.EVICT_THRESHOLD = 5

-- State (kept on the module table, not upvalues)
i18n.translations   = nil
i18n.langfile_path  = nil
i18n.keyCache       = setmetatable({}, { __mode = "v" }) -- never nil
i18n.hot_list       = {}
i18n.hot_index      = {}
i18n.last_load_time = nil

-- Logging helper (safe no-op if unavailable)
local function log(msg, level)
  if rfsuite and rfsuite.utils and rfsuite.tasks and rfsuite.tasks.logger then
    rfsuite.utils.log(msg, level or "info")
  end
end

local function loadLangFile(filepath)
  log("i18n: loading language file "..tostring(filepath), "info")
  local chunk = assert(rfsuite.compiler.loadfile(filepath), "i18n: loadfile error")
  local ok, result = pcall(chunk)
  return (ok and type(result) == "table") and result or {}
end

local function resolve(t, key)
  if not key then return nil end
  for part in key:gmatch("[^%.]+") do
    if type(t) ~= "table" then return nil end
    t = t[part]
  end
  return t
end

local function load_translations()
  assert(i18n.langfile_path, "i18n: langfile_path not set before load")
  i18n.translations   = loadLangFile(i18n.langfile_path)
  i18n.last_load_time = os.time()
end

local function ensure_initialized()
  if not i18n.langfile_path then
    local locale = (system and system.getLocale and system.getLocale()) or i18n.defaultLocale
    i18n.langfile_path = i18n.folder .. "/" .. locale .. ".lua"
  end
  if not i18n.translations then
    load_translations()
  end
  -- if someone nil'ed caches elsewhere, recreate them
  if type(i18n.keyCache) ~= "table" then
    i18n.keyCache = setmetatable({}, { __mode = "v" })
  end
  if type(i18n.hot_list) ~= "table" then i18n.hot_list = {} end
  if type(i18n.hot_index) ~= "table" then i18n.hot_index = {} end
end

local function mark_hot(key)
  local hot_list  = i18n.hot_list
  local hot_index = i18n.hot_index
  local keyCache  = i18n.keyCache

  local idx = hot_index[key]
  if idx then
    table.remove(hot_list, idx)
  elseif #hot_list >= i18n.HOT_SIZE then
    local old = table.remove(hot_list, 1)
    hot_index[old] = nil
    keyCache[old] = nil
  end
  table.insert(hot_list, key)
  hot_index[key] = #hot_list
end

-- Optional explicit load (switch locale)
function i18n.load(locale)
  local lc = locale or (system and system.getLocale and system.getLocale()) or i18n.defaultLocale
  i18n.langfile_path = i18n.folder .. "/" .. lc .. ".lua"
  -- reset caches (never set to nil)
  i18n.keyCache      = setmetatable({}, { __mode = "v" })
  i18n.hot_list      = {}
  i18n.hot_index     = {}
  i18n.last_load_time = nil
  load_translations()
end

function i18n.evict()
  if i18n.translations then
    log("i18n: evicting language file to save memory", "info")
    i18n.translations = nil
    collectgarbage("collect")
  end
end

-- Auto-load on first use
function i18n.get(key)
  ensure_initialized()

  local keyCache = i18n.keyCache
  local v = keyCache[key]
  if v ~= nil then
    mark_hot(key)
    return v
  end

  local resolved = resolve(i18n.translations, key) or key
  keyCache[key] = resolved
  mark_hot(key)
  return resolved
end

function i18n.seconds_since_load()
  if not i18n.last_load_time then return nil end
  return os.time() - i18n.last_load_time
end

function i18n.wakeup()
  local idle = i18n.seconds_since_load()
  if idle and idle > i18n.EVICT_THRESHOLD then
    i18n.evict()
  end
end

function i18n._debug_stats()
  local sz = 0
  for _ in pairs(i18n.keyCache) do sz = sz + 1 end
  return {
    cache_size = sz,
    hot_len = #i18n.hot_list,
    last_load_time = i18n.last_load_time,
    langfile_path = i18n.langfile_path
  }
end

return i18n
