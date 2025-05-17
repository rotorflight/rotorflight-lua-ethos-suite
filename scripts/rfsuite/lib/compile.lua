-- compile.lua (disk-cached only, respects useCompiler flag, optional load timings, filters sim/sensors logs)

local compile = {}
local arg = {...}

-- Configuration: expects rfsuite.config to be globally available
local logTimings = true
if rfsuite and rfsuite.config then
  if type(rfsuite.preferences.developer.compilerTiming) == "boolean" then
    logTimings = rfsuite.preferences.developer.compilerTiming or false
  end
end

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

-- On-disk compiled files index
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

-- Core loadfile replacement
function compile.loadfile(script)
  local startTime
  if logTimings then
    startTime = os.clock()
  end

  local loader, which, cache_fname
  if not rfsuite.preferences.developer.compile then
    loader = loadfile
    which = "raw"
    loader = loader(script)
  else
    -- Prepare cache filename
    local name_for_cache = strip_prefix(script)
    local sanitized      = name_for_cache:gsub("/", "_")
    cache_fname          = sanitized .. "c"
    local cache_path     = compiledDir .. cache_fname

    if disk_cache[cache_fname] then
      loader = loadfile(cache_path)
      which = "compiled"
    else
      system.compile(script)
      os.rename(script .. "c", cache_path)
      disk_cache[cache_fname] = true
      loader = loadfile(cache_path)
      which = "not compiled"
    end
  end

  -- Return the chunk or error
  if not loader then
    return nil, ("Failed to load script '%s' (%s)"):format(script, which or "unknown")
  end

  local chunk = loader
  if logTimings then
    local elapsed = os.clock() - startTime
    if not script:find("sim/sensors/", 1, true) then
      local msg = ("loadfile '%s' (%s) took %.4f sec"):format(script, which, elapsed)
      if which == "compiled" and cache_fname then
        msg = msg .. (" [cache: %s]"):format(cache_fname)
      end
      if rfsuite.utils and rfsuite.utils.log then
        rfsuite.utils.log(msg, "info")
      else
        print(msg)
      end
    end
  end

  return chunk
end


-- Wrapper for dofile
function compile.dofile(script, ...)
  return compile.loadfile(script)(...)
end

-- Custom require that compiles modules via cache
function compile.require(modname)
  if package.loaded[modname] then
    return package.loaded[modname]
  end

  local raw_path = modname:gsub("%%.", "/") .. ".lua"
  local path     = strip_prefix(raw_path)
  local chunk

  if not rfsuite.preferences.developer.compile then
    chunk = assert(loadfile(path))
  else
    chunk = compile.loadfile(path)
  end

  local result = chunk()
  package.loaded[modname] = (result == nil) and true or result
  return package.loaded[modname]
end

return compile