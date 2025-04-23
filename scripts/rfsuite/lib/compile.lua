--[[
 * Copyright (C) Rotorflight Project
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
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]]--

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

-- In-memory cache for loaded chunks
local chunk_cache = {}

-- Helper to strip SCRIPT_PREFIX
local function strip_prefix(name)
  if name:sub(1, #SCRIPT_PREFIX) == SCRIPT_PREFIX then
    return name:sub(#SCRIPT_PREFIX + 1)
  end
  return name
end

-- Core loadfile replacement
function compile.loadfile(script)
  -- Return already-loaded chunk
  if chunk_cache[script] then
    return chunk_cache[script]
  end

  -- Prepare name for cache: strip prefix and sanitize path
  local name_for_cache = strip_prefix(script)
  local sanitized      = name_for_cache:gsub("/", "_")
  local cache_fname    = sanitized .. "c"
  local cache_path     = compiledDir .. cache_fname

  -- Compile if missing
  if not disk_cache[cache_fname] then
    system.compile(script)
    os.rename(script .. "c", cache_path)
    disk_cache[cache_fname] = true
  end

  -- Load, cache, and return the chunk
  local chunk = assert(loadfile(cache_path))
  chunk_cache[script] = chunk
  return chunk
end

-- Wrapper for dofile: loads via compile.loadfile and executes it with args
function compile.dofile(script, ...)
  return compile.loadfile(script)(...)
end

-- Custom require that compiles and loads modules via our cache
function compile.require(modname)
  if package.loaded[modname] then
    return package.loaded[modname]
  end
  -- Convert module name to path and strip prefix
  local raw_path = modname:gsub("%.", "/") .. ".lua"
  local path     = strip_prefix(raw_path)

  local chunk = compile.loadfile(path)
  local result = chunk()
  -- Per Lua convention, module returns value or true
  package.loaded[modname] = (result == nil) and true or result
  return package.loaded[modname]
end

return compile
