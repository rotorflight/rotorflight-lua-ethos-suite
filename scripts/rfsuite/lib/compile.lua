--[[

 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * compile.lua - Deferred/Throttled Lua Script Compilation and Caching for Rotorflight Suite (Ethos)

 * Usage:
 *   local compile = require("rfsuite.lib.compile")
 *   local chunk = compile.loadfile("myscript.lua")
 *   chunk() -- executes the loaded script
 *   -- Or use compile.dofile / compile.require as drop-in replacements

]] --
--[[
 * Copyright (C) Rotorflight Project
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 * compile.lua - Deferred/Throttled Lua Script Compilation and Caching for Rotorflight Suite (Ethos)

 * Usage:
 *   local compile = require("rfsuite.lib.compile")
 *   local chunk = compile.loadfile("myscript.lua")
 *   chunk() -- executes the loaded script
 *   -- Or use compile.dofile / compile.require as drop-in replacements
]]

local compile = {}
local arg = {...}

compile._startTime = rfsuite.clock
compile._startupDelay = 15 -- seconds before starting any compiles

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

-- Unified cache-safe name generator
local function cachename(name)
  if name:sub(1, #SCRIPT_PREFIX) == SCRIPT_PREFIX then
    name = name:sub(#SCRIPT_PREFIX + 1)
  end
  name = name:gsub("/", "_")
  name = name:gsub("^_", "", 1)
  return name
end

--------------------------------------------------
-- Adaptive LRU Cache (in-memory loaders, interval-based eviction)
--------------------------------------------------
local LUA_RAM_THRESHOLD = 32 * 1024 -- 32 KB free (adjust as needed)
local LRU_HARD_LIMIT = 50           -- absolute maximum (safety)
local EVICT_INTERVAL = 5            -- seconds between eviction checks

local function LRUCache()
  local self = {
    cache = {},
    order = {},
    _last_evict = 0,
  }

  function self:get(key)
    local value = self.cache[key]
    if value then
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

  function self:evict_if_low_memory()
    self._last_evict = rfsuite.clock
    local usage = system.getMemoryUsage and system.getMemoryUsage()
    while #self.order > 0 do
      if usage and usage.luaRamAvailable and usage.luaRamAvailable < LUA_RAM_THRESHOLD then
        local oldest = table.remove(self.order, 1)
        self.cache[oldest] = nil
        usage = system.getMemoryUsage()
      elseif #self.order > LRU_HARD_LIMIT then
        local oldest = table.remove(self.order, 1)
        self.cache[oldest] = nil
      else
        break
      end
    end
  end

  function self:set(key, value)
    if not self.cache[key] then
      table.insert(self.order, key)
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

    local now = rfsuite.clock
    if now - self._last_evict > EVICT_INTERVAL then
      self:evict_if_low_memory()
    end
  end

  return self
end

local lru_cache = LRUCache()

--------------------------------------------------
-- Throttled Compile Queue System
--------------------------------------------------
compile._queue = {}
compile._queued_map = {}

function compile._enqueue(script, cache_path, cache_fname)
  if not compile._queued_map[cache_fname] then
    table.insert(compile._queue, {script = script, cache_path = cache_path, cache_fname = cache_fname})
    compile._queued_map[cache_fname] = true
  end
end

function compile.wakeup()
  local now = rfsuite.clock
  if (now - compile._startTime) < compile._startupDelay then
    return
  end
  if #compile._queue > 0 then
    local entry = table.remove(compile._queue, 1)
    compile._queued_map[entry.cache_fname] = nil
    local ok, err = pcall(function()
      system.compile(entry.script)
      os.rename(entry.script .. "c", entry.cache_path)
      disk_cache[entry.cache_fname] = true
    end)
    compile._lastCompile = now
    if rfsuite and rfsuite.utils and log then
      if ok then
        rfsuite.utils.log("Deferred-compiled (throttled): " .. entry.script, "info")
      else
        rfsuite.utils.log("Deferred-compile error: " .. tostring(err), "debug")
      end
    end
  end
end

function compile.loadfile(script)
  local startTime
  if logTimings then
    startTime = rfsuite.clock
  end

  local loader, which
  local cache_fname = cachename(script) .. "c"
  local cache_key   = cache_fname

  loader = lru_cache:get(cache_key)
  if loader then
    which = "in-memory"
  else
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
  local path     = cachename(raw_path)
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
