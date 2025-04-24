-- compile.lua (disk-cached only, no in-memory cache)

local compile = {}
local arg = {...}

-- Base and cache directories
local baseDir     = "./"
local compiledDir = baseDir .. "cache/"

-- Prefix for special script paths
local SCRIPT_PREFIX = "SCRIPTS:"

-- Ensure cache directory exists
local function ensure_dir(dir)
  if os.mkdir then
    local found = false
    for _, name in ipairs(system.listFiles(baseDir)) do
      if name == "cache" then found = true; break end
    end
    if not found then os.mkdir(dir) end
  end
end
ensure_dir(compiledDir)

-- In-memory set of on-disk compiled files
local disk_cache = {}
do
  for _, fname in ipairs(system.listFiles(compiledDir)) do
    disk_cache[fname] = true
  end
end

-- Helper to strip SCRIPT_PREFIX
local function strip_prefix(name)
  if name:sub(1, #SCRIPT_PREFIX) == SCRIPT_PREFIX then
    return name:sub(#SCRIPT_PREFIX + 1)
  end
  return name
end

-- Core loadfile replacement: always load from compiled or source disk file
function compile.loadfile(script)
  -- Prepare name for cache: strip prefix and sanitize path
  local name_for_cache = strip_prefix(script)
  local sanitized      = name_for_cache:gsub("/", "_")
  local cache_fname    = sanitized .. "c"
  local cache_path     = compiledDir .. cache_fname

  -- If compiled file exists on disk, load it
  if disk_cache[cache_fname] then
    return assert(loadfile(cache_path))
  end

  -- Otherwise, compile source and load
  system.compile(script)
  os.rename(script .. "c", cache_path)
  disk_cache[cache_fname] = true
  return assert(loadfile(cache_path))
end

-- Wrapper for dofile: loads via compile.loadfile and executes it with args
function compile.dofile(script, ...)
  return compile.loadfile(script)(...)
end

-- Custom require that compiles and loads modules via our cache
table.insert = table.insert -- ensure table.insert availability
function compile.require(modname)
  if package.loaded[modname] then
    return package.loaded[modname]
  end
  -- Convert module name to path and strip prefix
  local raw_path = modname:gsub("%.", "/") .. ".lua"
  local path     = strip_prefix(raw_path)

  local chunk = compile.loadfile(path)
  local result = chunk()
  package.loaded[modname] = (result == nil) and true or result
  return package.loaded[modname]
end

return compile
