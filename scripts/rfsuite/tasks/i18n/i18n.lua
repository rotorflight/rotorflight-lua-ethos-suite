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
]] --

local i18n = {}

-- Config
local defaultLocale   = "en"
local folder          = "i18n"
local HOT_SIZE        = 100
local EVICT_THRESHOLD = 20   -- seconds

-- State
local translations        -- full translations table (nil if evicted)
local langfile_path
local cache               -- key -> value
local nodes               -- key -> {key=..., prev=..., next=...}
local head, tail          -- LRU list pointers (head=LRU, tail=MRU)
local size                -- number of cached entries
local last_load_time

-- Utilities --------------------------------------------------------------

local function log(msg)
  if rfsuite and rfsuite.utils and rfsuite.utils.log then
    rfsuite.utils.log(msg, "info")
  end
end

local function loadLangFile(filepath)
  log("i18n: loading language file " .. filepath)
  local chunk = assert(rfsuite.compiler.loadfile(filepath), "i18n: loadfile error")
  local ok, result = pcall(chunk)
  return (ok and type(result) == "table") and result or {}
end

-- Slightly cheaper resolver than gmatch
local function resolve(t, key)
  local s, e = 1, 0
  while true do
    e = string.find(key, ".", s, true)
    local part = e and string.sub(key, s, e - 1) or string.sub(key, s)
    if type(t) ~= "table" then return nil end
    t = t[part]
    if not e then return t end
    s = e + 1
  end
end

local function load_translations()
  translations   = loadLangFile(langfile_path)
  last_load_time = os.time()
end

-- O(1) LRU ---------------------------------------------------------------

local function unlink(node)
  local p, n = node.prev, node.next
  if p then p.next = n else head = n end
  if n then n.prev = p else tail = p end
  node.prev, node.next = nil, nil
end

local function link_at_tail(node)
  node.prev, node.next = tail, nil
  if tail then tail.next = node else head = node end
  tail = node
end

local function touch(key)
  local node = nodes[key]
  if node then
    -- move to MRU
    unlink(node); link_at_tail(node)
    return
  end
  -- insert new node
  node = { key = key }
  nodes[key] = node
  link_at_tail(node)
  size = size + 1
  if size > HOT_SIZE then
    -- evict LRU
    local old = head
    unlink(old)
    nodes[old.key] = nil
    cache[old.key] = nil
    size = size - 1
  end
end

-- Public API -------------------------------------------------------------

function i18n.load(locale)
  locale        = locale or (system and system.getLocale and system.getLocale()) or defaultLocale
  langfile_path = folder .. "/" .. locale .. ".lua"
  cache, nodes  = {}, {}
  head, tail, size = nil, nil, 0
  last_load_time = nil
  load_translations()
end

function i18n.evict()
  if translations then
    log("i18n: evicting language file to save memory")
    translations = nil
    collectgarbage("collect")
  end
end

function i18n.get(key)
  local v = cache[key]
  if v ~= nil then
    touch(key)
    return v
  end
  if not translations then load_translations() end
  local resolved = resolve(translations, key) or key
  cache[key] = resolved
  touch(key)
  return resolved
end

function i18n.seconds_since_load()
  if not last_load_time then return nil end
  return os.time() - last_load_time
end

function i18n.wakeup()
  local idle = i18n.seconds_since_load()
  if idle and idle > EVICT_THRESHOLD then
    i18n.evict()
  end
end

function i18n._debug_stats()
  -- gather keys for inspection without exposing internals
  local keys = {}
  local n = head
  while n do
    keys[#keys+1] = n.key
    n = n.next
  end
  return { cache_size = size, order = keys, last_load_time = last_load_time }
end

return i18n
