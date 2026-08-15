-- One-shot RAM usage print, for two spots the project owner specifically
-- wants visibility into: the system tool's own close() (app/tool.lua)
-- and a page module's exit (app/page_runtime.lua's goBack(), which every
-- page funnels through -- see that file's own header comment).
--
-- Deliberately NOT rotorflight-lua-ethos-suite's own
-- lib/utils.lua:reportMemoryUsage() -- that's a whole preferences-gated
-- profiling system with paired start/end snapshots, elapsed-time deltas,
-- and its own background-task-fed cpuload/freeram sampler
-- (tasks/scheduler/performance/performance.lua). This rebuild has none of
-- that scaffolding and doesn't need it just to answer "how much RAM right
-- now" -- a single print call at a spot of interest.
--
-- system.getMemoryUsage()'s fields (all bytes) and collectgarbage("count")
-- (current Lua heap, KB) are the same two sources that suite's own
-- reportMemoryUsage() and widgets/dashboard/lib/debug_log_panel.lua read
-- from -- confirmed real fields, not guessed at.
--
-- Self-caches via package.loaded (same mechanism lib/bus.lua uses) --
-- app/page_runtime.lua (which calls this) reloads fresh on every page
-- open, so without caching this tiny file re-parsed on every navigation
-- too, for zero benefit (nothing here is page-specific).
if package.loaded["rfsuite.lib.memstats"] then
  return package.loaded["rfsuite.lib.memstats"]
end

local memstats = {}
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local settingsStore = requireModule("lib/settings_store.lua")

local settings = nil

local function currentSettings()
  if not settings then settings = settingsStore.load() end
  return settings
end

local function enabled()
  return settingsStore.memoryLogsEnabled(currentSettings())
end

function memstats.print(tag)
  if not enabled() then return end
  local mem = system.getMemoryUsage and system.getMemoryUsage() or {}
  local luaKB = collectgarbage("count")
  print(string.format(
    "[mem] %s: lua=%.1fKB ramAvail=%.1fKB luaRamAvail=%.1fKB bmpRamAvail=%.1fKB stackAvail=%.1fKB",
    tag,
    luaKB,
    (mem.ramAvailable or 0) / 1024,
    (mem.luaRamAvailable or 0) / 1024,
    (mem.luaBitmapsRamAvailable or 0) / 1024,
    (mem.mainStackAvailable or 0) / 1024
  ))
end

bus.subscribe("settings.update", function(snapshot)
  settings = snapshot or {}
end)

package.loaded["rfsuite.lib.memstats"] = memstats
return memstats
