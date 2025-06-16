--[[

 * Copyright (C) Rotorflight Project
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 * compile.lua - Deferred/Throttled Lua Script Compilation and Caching with adaptive LRU in-memory cache
 * Extended: Added wakeup function for periodic memory-based eviction and scheduled deferred compilation.

* Usage:
*   local compile = require("rfsuite.lib.compile")
*   local chunk = compile.loadfile("myscript.lua")
*   chunk() -- executes the loaded script
*   -- Or use compile.dofile / compile.require as drop-in replacements
*   -- Call compile.wakeup() periodically (e.g. in a timer) to evict low-memory entries every 2s and run deferred compiles every 10s.

]] --
local compile = {}
local arg = {...}

compile._startTime = os.clock()
compile._startupDelay = 20 -- seconds before starting any compiles

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
-- Adaptive LRU Cache (in-memory loaders, eviction only on wakeup)
--------------------------------------------------
local LUA_RAM_THRESHOLD = 48 * 1024 -- 48 KB free (adjust as needed)
local LRU_HARD_LIMIT = 100          -- absolute maximum number of cached scripts (safety)

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
    self._last_evict = os.clock()
    local usage = system.getMemoryUsage and system.getMemoryUsage()
    --print(usage.luaRamAvailable, LUA_RAM_THRESHOLD)
    while #self.order > 0 do
      if usage and usage.luaRamAvailable and usage.luaRamAvailable < LUA_RAM_THRESHOLD then
        local oldest = table.remove(self.order, 1)
        self.cache[oldest] = nil
        --if rfsuite and rfsuite.utils and rfsuite.utils.log then
        --  rfsuite.utils.log("Evicted script from cache due to low Lua RAM: " .. tostring(oldest), "info")
        --end
        usage = system.getMemoryUsage()
      elseif #self.order > LRU_HARD_LIMIT then
        local oldest = table.remove(self.order, 1)
        self.cache[oldest] = nil
        --if rfsuite and rfsuite.utils and rfsuite.utils.log then
        --  rfsuite.utils.log("Evicted script from cache due to hitting hard limit: " .. tostring(oldest), "info")
        --end
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
    -- Eviction is now handled only in wakeup(), not on set
  end

  return self
end

local lru_cache = LRUCache()

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
      if not ok then
        rfsuite.utils.log("Deferred-compile error: " .. tostring(err), "debug")
      end
    end
  end
end

-- helper: compile exactly one queued item, if any
local function process_one_queued()
  local entry = table.remove(compile._queue, 1)
  if not entry then return end
  local script, cache_path, cache_fname = table.unpack(entry)
  local ok, err = pcall(system.compile, script)
  if ok then
    local tmp = script .. "c"
    if os.rename(tmp, cache_path) then
      disk_cache[cache_fname] = true
    else
      -- rename failed; leave tmp for next tick
    end
  else
    -- compile error; you can log err here if desired
  end
end

function compile.loadfile(script)
  -- Optional timing log start
  local startTime
  if logTimings then
    startTime = os.clock()
  end

  -- Prepare cache keys
  local name_for_cache = strip_prefix(script)
  local sanitized      = name_for_cache:gsub("/", "_")
  local cache_fname    = sanitized .. "c"
  local cache_key      = cache_fname
  local cache_path     = compiledDir .. cache_fname

  -- Check in-memory LRU cache first
  local loader = lru_cache:get(cache_key)
  if loader then
    which = "in-memory"
  else
    if not rfsuite.preferences.developer.compile then
      -- No compile caching requested
      loader = loadfile(script)
      which = "raw"
    else
      local now = os.clock()

      if (now - compile._startTime) >= compile._startupDelay then
        -- === Post-startup: instant on-access ===
        if disk_cache[cache_fname] then
          -- Compiled file already exists: just load it
          loader = loadfile(cache_path)
          which = "compiled (cached)"
        else
          -- No compiled cache yet: compile once, then load
          local ok, compile_err = pcall(system.compile, script)
          if ok then
            local tmp_path = script .. "c"
            local renamed, rename_err = os.rename(tmp_path, cache_path)
            if renamed then
              disk_cache[cache_fname] = true
              loader = loadfile(cache_path)
              which = "compiled (instant)"
            else
              -- rename failed: fall back to raw script, keep any existing cache untouched
              loader = loadfile(script)
              which  = ("raw (rename failed: %s)"):format(tostring(rename_err))
            end
          else
            -- compile error: fallback to raw, leave cache untouched
            loader = loadfile(script)
            which  = ("raw (compile error: %s)"):format(tostring(compile_err))
          end

          process_one_queued()

        end

      else
        -- === During startupDelay: defer compilation ===
        if disk_cache[cache_fname] then
          loader = loadfile(cache_path)
          which = "compiled"
        else
          compile._enqueue(script, cache_path, cache_fname)
          loader = loadfile(script)
          which = "raw (queued for deferred compile)"
        end
      end
    end

    -- Cache the loader in LRU for next time
    if loader then
      lru_cache:set(cache_key, loader)
    end
  end

  if not loader then
    return nil, ("Failed to load script '%s' (%s)"):format(script, which or "unknown")
  end

  -- Optional timing log end
  if logTimings and startTime then
    local elapsed = os.clock() - startTime
    if rfsuite and rfsuite.utils and rfsuite.utils.log then
      rfsuite.utils.log(
        ("Loaded '%s' [%s] in %.3f sec"):format(script, which, elapsed),
        "debug"
      )
    end
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

-- Scheduled wakeup: evict cache and run deferred compiles
compile._last_wakeup = 0
compile._wakeupInterval = 5 -- seconds between evictions
compile._last_tick = 0
compile._tickInterval = 20 -- seconds between deferred compile runs

function compile.wakeup()
  local now = os.clock()
  if (now - compile._last_wakeup) >= compile._wakeupInterval then
    compile._last_wakeup = now
    lru_cache:evict_if_low_memory()
  end
  if (now - compile._last_tick) >= compile._tickInterval then
    compile.tick()
    compile._last_tick = now
  end
end

return compile