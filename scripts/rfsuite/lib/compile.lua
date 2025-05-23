--[[

 * Copyright (C) Rotorflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

* compile.lua - Deferred/Throttled Lua Script Compilation and Caching for Rotorflight Suite (Ethos)
*
* This module provides a system for deferred, throttled compilation and caching of Lua scripts
* within the Rotorflight Suite for Ethos radios. It is designed to improve performance by
* compiling scripts in the background and caching the compiled bytecode, while also supporting
* developer options for raw or compiled loading.
*
* Features:
*   - Deferred compilation: Scripts are queued and compiled at a throttled interval to avoid
*     blocking the main thread or causing performance spikes.
*   - Caching: Compiled scripts are stored in a cache directory and loaded from cache when available.
*   - Startup delay: Compilation does not begin until a configurable delay after startup.
*   - Logging: Optional timing and debug logging for developer diagnostics.
*   - Compatibility: Falls back to raw script loading if compilation is disabled in preferences.
*   - Safe: Uses pcall to catch and log errors during compilation or file operations.
*   - Utility functions: Provides loadfile, dofile, and require replacements that respect the
*     deferred compilation and caching system.
*
* Configuration:
*   - Expects `rfsuite.config` and `rfsuite.preferences.developer` to be globally available.
*   - Developer options can enable/disable compilation and timing logs.
*
* Notes:
*   - The cache directory is created if it does not exist.
*   - Script paths with the "SCRIPTS:" prefix are supported and sanitized for caching.
*   - Some icons referenced in the project are sourced from https://www.flaticon.com/
*   - Licensed under GPLv3 (see https://www.gnu.org/licenses/gpl-3.0.en.html).
*
* Usage:
*   local compile = require("rfsuite.lib.compile")
*   local chunk = compile.loadfile("myscript.lua")
*   chunk() -- executes the loaded script
*
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

--------------------------------------------------
-- Throttled Compile Queue System (NEW SECTION)
--------------------------------------------------
compile._queue = {}
compile._queued_map = {}
compile._lastCompile = 0
compile._compileInterval = 2 -- seconds (adjust as needed)

function compile._enqueue(script, cache_path, cache_fname)
  if not compile._queued_map[cache_fname] then
    table.insert(compile._queue, {script = script, cache_path = cache_path, cache_fname = cache_fname})
    compile._queued_map[cache_fname] = true
  end
end

function compile.tick()
  local now = os.clock()
  -- Only start compiling after startup delay
  if (now - compile._startTime) < compile._startupDelay then
    return
  end
  if #compile._queue > 0 and (now - compile._lastCompile) >= compile._compileInterval then
    local entry = table.remove(compile._queue, 1)
    compile._queued_map[entry.cache_fname] = nil
    -- Try-catch in case compile or rename fails
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
      -- Queue compile, but return raw code for now
      compile._enqueue(script, cache_path, cache_fname)
      loader = loadfile(script)
      which = "raw (queued for deferred compile)"
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
