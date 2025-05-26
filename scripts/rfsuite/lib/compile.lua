--[[

 * Copyright (C) Rotorflight Project
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 * compile.lua - Deferred/Throttled Lua Script Compilation and Caching with LRU in-memory cache

* Usage:
*   local compile = require("rfsuite.lib.compile")
*   local chunk = compile.loadfile("myscript.lua")
*   chunk() -- executes the loaded script
*   -- Or use compile.dofile / compile.require as drop-in replacements

]] --
local compile = {}
local arg = {...}

compile._startTime = os.clock()
compile._startupDelay = 5 -- seconds before starting any compiles

-- Configuration: expects rfsuite.config to be globally available
local logTimings = true
if rfsuite and rfsuite.config then
  if type(rfsuite.preferences.developer.compilerTiming) == "boolean" then
    logTimings = rfsuite.preferences.developer.compilerTiming or false
  end
end

local baseDir     = "./"
local compiledDir = baseDir .. "cache/"
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

local function strip_prefix(name)
  if name:sub(1, #SCRIPT_PREFIX) == SCRIPT_PREFIX then
    return name:sub(#SCRIPT_PREFIX + 1)
  end
  return name
end

--------------------------------------------------
-- LRU Cache (in-memory loaders)
--------------------------------------------------
local function LRUCache(max_size)
  local self = {
    max_size = max_size or 10,
    cache = {},
    order = {},
  }

  function self:get(key)
    local value = self.cache[key]
    if value then
      -- Move key to end (MRU)
      for i, k in ipairs(self.order) do
        if k == key then
          table.remove(self.order, i)
          break
        end
      end
      table.insert(self.order, key)
    end
    return value
  end

  function self:set(key, value)
    if not self.cache[key] then
      table.insert(self.order, key)
      if #self.order > self.max_size then
        local oldest = table.remove(self.order, 1)
        self.cache[oldest] = nil
      end
    else
      for i, k in ipairs(self.order) do
        if k == key then
          table.remove(self.order, i)
          break
        end
      end
      table.insert(self.order, key)
    end
    self.cache[key] = value
  end

  return self
end

local lru_cache = LRUCache(20)

--------------------------------------------------
-- Throttled Compile Queue System
--------------------------------------------------
compile._queue = {}
compile._queued_map = {}
compile._lastCompile = 0
compile._compileInterval = 2 -- seconds

function compile._enqueue(script, cache_path, cache_fname)
  if not compile._queued_map[cache_fname] then
    table.insert(compile._queue, {script = script, cache_path = cache_path, cache_fname = cache_fname})
    compile._queued_map[cache_fname] = true
  end
end

function compile.tick()
  local now = os.clock()
  if (now - compile._startTime) < compile._startupDelay then
    return
  end
  if #compile._queue > 0 and (now - compile._lastCompile) >= compile._compileInterval then
    local entry = table.remove(compile._queue, 1)
    compile._queued_map[entry.cache_fname] = nil
    local ok, err = pcall(function()
      system.compile(entry.script)
      os.rename(entry.script .. "c", entry.cache_path)
      disk_cache[entry.cache_fname] = true
    end)
    compile._lastCompile = now
    if rfsuite and rfsuite.utils and rfsuite.utils.log then
      if ok then
        rfsuite.utils.log("Deferred-compiled (throttled): " .. entry.script, "debug")
      else
        rfsuite.utils.log("Deferred-compile error: " .. tostring(err), "debug")
      end
    end
  end
end

function compile.loadfile(script)
  compile.tick()
  local startTime
  if logTimings then
    startTime = os.clock()
  end

  local loader, which, cache_fname
  -- Prepare cache filename
  local name_for_cache = strip_prefix(script)
  local sanitized      = name_for_cache:gsub("/", "_")
  cache_fname          = sanitized .. "c"
  local cache_key      = cache_fname

  -- 1. Try LRU in-memory cache
  loader = lru_cache:get(cache_key)
  if loader then
    which = "in-memory"
  else
    -- 2. Fallback: disk compiled, or raw
    if not rfsuite.preferences.developer.compile then
      loader = loadfile(script)
      which = "raw"
    else
      local cache_path = compiledDir .. cache_fname
      if disk_cache[cache_fname] then
        loader = loadfile(cache_path)
        which = "compiled"
      else
        compile._enqueue(script, cache_path, cache_fname)
        loader = loadfile(script)
        which = "raw (queued for deferred compile)"
      end
    end
    -- If successfully loaded, store in LRU
    if loader then
      lru_cache:set(cache_key, loader)
    end
  end

  if not loader then
    return nil, ("Failed to load script '%s' (%s)"):format(script, which or "unknown")
  end

  return loader
end

function compile.dofile(script, ...)
  local chunk = compile.loadfile(script)
  return chunk(...)
end

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
