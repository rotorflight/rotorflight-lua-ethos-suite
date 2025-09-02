--[[
 * Rotorflight Project - Enhanced Script Compilation and Caching
 *
 * Copyright (C) Rotorflight Project
 * License: GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
 *
]]

local compile = {}
local arg     = { ... }

compile._startTime    = os.clock()
compile._startupDelay = 60 -- seconds before starting any compiles

-- Configuration: expects rfsuite.config to be globally available
local logTimings = true
if rfsuite and rfsuite.config then
  if type(rfsuite.preferences.developer.compilerTiming) == "boolean" then
    logTimings = rfsuite.preferences.developer.compilerTiming or false
  end
end

local baseDir      = "./"
local compiledDir  = baseDir .. "cache/"
local SCRIPT_PREFIX = "SCRIPTS:"

local function ensure_dir(dir)
  if os.mkdir then
    local found = false
    for _, name in ipairs(system.listFiles(baseDir)) do
      if name == "cache" then
        found = true
        break
      end
    end
    if not found then os.mkdir(dir) end
  end
end
ensure_dir(compiledDir)

local disk_cache = {}
do
  for _, fname in ipairs(system.listFiles(compiledDir)) do
    disk_cache[fname] = true
  end
end

local function cachename(name)
  if name:sub(1, #SCRIPT_PREFIX) == SCRIPT_PREFIX then
    name = name:sub(#SCRIPT_PREFIX + 1)
  end
  name = name:gsub("/", "_")
  name = name:gsub("^_", "", 1)
  return name
end

-- Adaptive LRU Cache with Pinning Support
local LUA_RAM_THRESHOLD = 32 * 1024
local LRU_HARD_LIMIT    = 50
local EVICT_INTERVAL    = 5

local function LRUCache()
  local self = {
    cache       = {},
    order       = {},
    pinned      = {},
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
    self._last_evict = os.clock()
    local usage = system.getMemoryUsage and system.getMemoryUsage()
    local i     = 1
    while i <= #self.order do
      local key = self.order[i]
      if not self.pinned[key] and (
        (usage and usage.luaRamAvailable and usage.luaRamAvailable < LUA_RAM_THRESHOLD) or
        #self.order > LRU_HARD_LIMIT
      ) then
        table.remove(self.order, i)
        self.cache[key] = nil
        usage = system.getMemoryUsage and system.getMemoryUsage() or usage
      else
        i = i + 1
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

    local now = os.clock()
    if now - self._last_evict > EVICT_INTERVAL then
      self:evict_if_low_memory()
    end
  end

  function self:pin(key)
    self.pinned[key] = true
  end

  function self:unpin(key)
    self.pinned[key] = nil
  end

  return self
end

local lru_cache = LRUCache()

-- Compile Queue System
compile._queue      = {}
compile._queued_map = {}

function compile._enqueue(script, cache_path, cache_fname)
  if not compile._queued_map[cache_fname] then
    table.insert(compile._queue, {
      script      = script,
      cache_path  = cache_path,
      cache_fname = cache_fname
    })
    compile._queued_map[cache_fname] = true
  end
end

function compile.wakeup()
  local now = os.clock()
  if (now - compile._startTime) < compile._startupDelay then return end

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

-- Enhanced loadfile: supports pin = true or { pin = true }
function compile.loadfile(script, opts)
  local startTime
  if logTimings then startTime = os.clock() end

  -- Normalize options
  if type(opts) == "boolean" then
    opts = { pin = opts }
  else
    opts = opts or {}
  end

  local cache_fname = cachename(script) .. "c"
  local cache_key   = cache_fname

  local loader = lru_cache:get(cache_key)
  local which

  if loader then
    which = "in-memory"
  else
    if not rfsuite.preferences.developer.compile then
      loader = loadfile(script)
      which  = "raw"
    else
      local cache_path = compiledDir .. cache_fname
      if disk_cache[cache_fname] then
        loader = loadfile(cache_path)
        which  = "compiled"
      else
        compile._enqueue(script, cache_path, cache_fname)
        loader = loadfile(script)
        which  = "raw (queued for deferred compile)"
      end
    end

    if loader then
      lru_cache:set(cache_key, loader)
      if opts.pin then
        lru_cache:pin(cache_key)
      end
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

-- Helper to unpin script from memory cache
function compile.unpin(script)
  local cache_key = cachename(script) .. "c"
  lru_cache:unpin(cache_key)
end

-- List all currently pinned cache keys
function compile.listPinned()
  local pinnedScripts = {}
  for key in pairs(lru_cache.pinned) do
    local fname = key:gsub("%.luac?$", ""):gsub("_", "/")
    table.insert(pinnedScripts, fname)
  end
  return pinnedScripts
end

-- Force clear all in-memory cache, including pinned
function compile.clearAll()
  local total = #lru_cache.order
  lru_cache.cache  = {}
  lru_cache.order  = {}
  lru_cache.pinned = {}
  if rfsuite and rfsuite.utils then
    rfsuite.utils.log("Cleared all cached scripts (" .. total .. " evicted)", "info")
  end
end

return compile
