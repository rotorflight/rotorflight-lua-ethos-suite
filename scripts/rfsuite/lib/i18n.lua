-- i18n.lua

local i18n = {}

-- Config
local defaultLocale = "en"
local folder        = "i18n"     -- where en.lua, fr.lua etc. live
local HOT_SIZE      = 50       -- adjust to your RAM budget

-- State
local translations, keyCache, hot_list, hot_index

-- Helper: load a single Lua translation file (returns a table)
local function loadLangFile(filepath)
  local chunk, err = rfsuite.compiler.loadfile(filepath)
  if not chunk then return nil end
  local ok, result = pcall(chunk)
  if not ok or type(result) ~= "table" then return nil end
  return result
end

-- (Re-)initialize everything for a locale
function i18n.load(locale)
  locale      = locale or system.getLocale() or defaultLocale
  keyCache    = setmetatable({}, { __mode = "v" })   -- weak-value cache
  hot_list    = {}
  hot_index   = {}

  -- load primary locale
  translations = loadLangFile(folder .. "/" .. locale .. ".lua")
  if not translations then
    rfsuite.utils.log(
      "i18n: Locale '"..locale.."' not found, falling back to '"..defaultLocale.."'", 
      "info"
    )
    translations = loadLangFile(folder .. "/" .. defaultLocale .. ".lua")
            or {}
  end
end

-- LRU helpers
local function mark_hot(key)
  local idx = hot_index[key]
  if idx then
    table.remove(hot_list, idx)
  elseif #hot_list >= HOT_SIZE then
    local old = table.remove(hot_list, 1)
    hot_index[old] = nil
  end
  table.insert(hot_list, key)
  hot_index[key] = #hot_list
end

-- Walk a nested table by dot-split key
local function resolve(t, key)
  for part in key:gmatch("[^%.]+") do
    if type(t) ~= "table" then return nil end
    t = t[part]
  end
  return t
end

-- Main lookup
function i18n.get(key)
  -- 1) Hit in cache?
  local v = keyCache[key]
  if v ~= nil then
    --rfsuite.utils.log("i18n: Cache hit for key: " .. key, "info")
    mark_hot(key)
    return v
  end

  -- 2) Resolve nested
  v = resolve(translations, key) or key

  -- 3) Store & mark
  keyCache[key] = v
  mark_hot(key)

  --rfsuite.utils.log("i18n: Cache miss for key: " .. key, "info")
  return v
end

-- Optional debug hooks
function i18n._debug_stats()
  local cache_size = 0
  for _ in pairs(keyCache) do cache_size = cache_size + 1 end
  return {
    cache_size = cache_size,
    hot_list   = hot_list,
  }
end

return i18n
