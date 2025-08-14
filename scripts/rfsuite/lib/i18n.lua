-- i18n.lua

-- Implements LRU caching with manual eviction, on-demand reload, automatic idle eviction via wakeup

local i18n = {}

-- Config
local defaultLocale      = "en"    -- fallback locale
local folder             = "i18n"  -- directory holding locale files
local HOT_SIZE           = 50       -- max LRU hot cache entries
local EVICT_THRESHOLD    = 5        -- seconds of idle before auto-evict

-- State
local translations       -- full translations table (nil if evicted)
local langfile_path      -- path to current locale file
local keyCache           -- weak-value cache of resolved values
local hot_list, hot_index-- LRU list and index
local last_load_time     -- os.time() when file last loaded

-- Helper: load translation file
local function loadLangFile(filepath)
  if rfsuite.utils and rfsuite.tasks and rfsuite.tasks.logger then
    rfsuite.utils.log("i18n: loading language file " .. filepath,"info")
  end
  local chunk = assert(rfsuite.compiler.loadfile(filepath), "i18n: loadfile error")
  local ok, result = pcall(chunk)
  return (ok and type(result)=="table") and result or {}
end

-- Helper: deep-key resolver
local function resolve(t, key)
  if not key then return nil end
  for part in key:gmatch("[^%.]+") do
    if type(t)~="table" then return nil end
    t = t[part]
  end
  return t
end

-- Internal: actually load into memory
local function load_translations()
  translations   = loadLangFile(langfile_path)
  last_load_time = os.time()
end

-- Internal: LRU maintenance
local function mark_hot(key)
  local idx = hot_index[key]
  if idx then
    table.remove(hot_list, idx)
  elseif #hot_list >= HOT_SIZE then
    local old = table.remove(hot_list, 1)
    hot_index[old] = nil
    keyCache[old] = nil
  end
  table.insert(hot_list, key)
  hot_index[key] = #hot_list
end

-- API: initialize and load locale
function i18n.load(locale)
  locale          = locale or system.getLocale() or defaultLocale
  langfile_path   = folder .. "/" .. locale .. ".lua"
  keyCache        = setmetatable({}, {__mode="v"})
  hot_list, hot_index = {}, {}
  last_load_time  = nil
  load_translations()
end

-- API: manual eviction
function i18n.evict()
  if translations then
    if rfsuite.utils and rfsuite.tasks and rfsuite.tasks.logger then
      rfsuite.utils.log("i18n: evicting language file to save memory","info")
    end
    translations = nil
    collectgarbage("collect")
  end
end

-- API: get translation, reload on miss
function i18n.get(key)
  local v = keyCache[key]
  if v ~= nil then
    mark_hot(key)
    return v
  end
  if not translations then load_translations() end
  local resolved = resolve(translations, key) or key
  if key then
    keyCache[key] = resolved
    mark_hot(key)
    return resolved
  end
  return nil
end

-- API: seconds since load, or nil
function i18n.seconds_since_load()
  if not last_load_time then return nil end
  return os.time() - last_load_time
end

-- API: wakeup to auto-evict if idle
function i18n.wakeup()
  local idle = i18n.seconds_since_load()
  if idle and idle > EVICT_THRESHOLD then
    i18n.evict()
  end
end

-- API: debug info
function i18n._debug_stats()
  local sz = 0 for _ in pairs(keyCache) do sz=sz+1 end
  return { cache_size=sz, hot_list=hot_list, last_load_time=last_load_time }
end

return i18n
