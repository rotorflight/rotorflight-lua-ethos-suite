-- Shared loadfile() memoizer.
--
-- Every lib/*.lua (and most app/*, widgets/*) module already self-caches:
-- `if package.loaded[key] then return package.loaded[key] end` at its own
-- top, keyed into the same package.loaded table require() uses. That guard
-- only saves re-running the module body, though -- every call site still
-- says `local bus = assert(loadfile("lib/bus.lua"))()`, and Ethos's own
-- loadfile() has no idea about package.loaded: it unconditionally re-reads
-- the file off the SD card and re-parses/-compiles it into a fresh chunk
-- *before* that chunk ever runs far enough to hit its own guard and bail
-- out early. A live boot-time trace confirmed this is real, not
-- theoretical: lib/bus.lua and lib/mspcodec.lua were each loadfile()'d 12
-- times, lib/settings_store.lua 10 times, in well under a second -- half
-- of all loadFile() calls logged in that window were reloading a file the
-- boot had already loaded.
--
-- This module moves the package.loaded check in front of loadfile()
-- itself, so a repeat request becomes a table lookup instead of a second
-- disk read + parse + execute. Because it reads and writes the *same*
-- package.loaded table (under the same "rfsuite.<path>" keys) every
-- module already self-registers into, this is purely an optimization of
-- *how* a module gets loaded, never a change to *whether* it's shared or
-- to its lifecycle: app/page_runtime.lua's unloadPackageKeys still frees
-- a page's modules exactly as before (nil out package.loaded[key]), and
-- the next requireModule() call for that key correctly reloads a fresh
-- copy, same as the very first load ever did.
--
-- Usage (replaces `local bus = assert(loadfile("lib/bus.lua"))()`):
--   local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
--   local bus = requireModule("lib/bus.lua")
--
-- The `package.loaded[...] or` half of that bootstrap line matters just
-- as much as requireModule() itself: a live trace after the first version
-- of this file shipped (which had every call site do the simpler
-- `local requireModule = assert(loadfile("lib/require.lua"))()`) showed
-- lib/require.lua itself as the single most-loadfile()'d file in the
-- whole boot -- the guard on lines 38-40 below skips re-running *this*
-- file's own body, but every call site's raw loadfile("lib/require.lua")
-- still paid its own disk-read+parse cost first, same blind spot this
-- module exists to fix for every *other* file. package.loaded is a real
-- Lua global (not a per-chunk-local), and the whole rest of this scheme
-- already depends on it being shared process-wide -- every module's own
-- self-cache guard only works because a module loaded from one subsystem
-- (say tasks/background.lua) is correctly seen by another (app/tool.lua,
-- widgets/dashboard.lua) -- so reading it directly, before ever calling
-- loadfile(), is safe by the same evidence that already validated this
-- file's core idea in production. Only the *first* call in the whole
-- process (main.lua's own top-level bootstrap line, guaranteed to run
-- before anything else loads) actually pays for a real loadfile() here;
-- every call after that anywhere else in the codebase is a plain table
-- lookup.
--
-- Only for static, literal paths known at the call site. A handful of
-- call sites resolve their path at runtime (dashboard theme/state
-- loaders, the app menu's MENUS table) -- those are left on plain
-- loadfile() rather than routed through here, since a runtime-computed
-- path's cache key needs the same scrutiny a hand-written one gets
-- automatically from matching an existing package.loaded convention.
if package.loaded["rfsuite.lib.require"] then
  return package.loaded["rfsuite.lib.require"]
end

local NAMESPACE = "rfsuite"

-- "lib/bus.lua" -> "rfsuite.lib.bus", matching the key every module
-- already self-registers under (see e.g. lib/table_clone.lua).
local function deriveKey(path)
  return NAMESPACE .. "." .. path:gsub("%.lua$", ""):gsub("/", ".")
end

-- cacheKey is optional -- only needed if a path ever has to be cached
-- under something other than its own derived key (no current caller
-- needs this; kept for the same reason field_layout.lua's spec tables
-- take more parameters than today's callers use, see its own history).
local function requireModule(path, cacheKey)
  cacheKey = cacheKey or deriveKey(path)
  local cached = package.loaded[cacheKey]
  if cached ~= nil then return cached end

  local result = assert(loadfile(path))()
  -- A module that returns nothing (relies purely on package.loaded's
  -- own self-guard returning it on the *next* raw loadfile(), never on
  -- this wrapper) would otherwise recompute `cached ~= nil` as false on
  -- every call and defeat its own cache -- store `true` as a sentinel,
  -- same convention the old RF-2.2.x compile.require() used.
  package.loaded[cacheKey] = (result == nil) and true or result
  return package.loaded[cacheKey]
end

package.loaded["rfsuite.lib.require"] = requireModule
return requireModule
