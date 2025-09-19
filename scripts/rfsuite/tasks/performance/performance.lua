--[[
 * CPU/Mem profiler (40 Hz) for RF Suite
 * - Runs as its own task every 0.025s
 * - CPU util = work_time / wall_time_between_wakeups
 * - Memory: Lua heap free (KB) + GC used (KB) EMA
 * - Module name: performance (to avoid clobbering system os)
]]

local arg = {...}
local config = arg and arg[1]

-- capture the real os lib
local performance = {}

----------------------------------------------------------------
-- Tuning
----------------------------------------------------------------
local PROF_PERIOD_S   = 0.05            -- 40 Hz task interval
local CPU_TICK_HZ     = 1 / PROF_PERIOD_S
local SCHED_DT        = PROF_PERIOD_S
local OVERDUE_TOL     = SCHED_DT * 0.25

local CPU_TICK_BUDGET = SCHED_DT
local CPU_ALPHA       = 0.8              -- 1.0 => instant, 0.8 => fast-follow
local MEM_ALPHA       = 0.8
local MEM_PERIOD      = 0.50             -- sample memory twice per second

-- Optional: make sim utilization less jittery
local usingSimulator  = (system.getVersion and system.getVersion().simulation) or false
local SIM_TARGET_UTIL = 0.50
local SIM_MAX_UTIL    = 0.80
local SIM_BLEND       = 0.55

----------------------------------------------------------------
-- State
----------------------------------------------------------------
local last_wakeup_start = nil
local cpu_avg           = 0

local last_mem_t        = 0
local mem_avg_kb        = nil
local usedram_avg_kb    = nil
local bitmap_pool_est_kb= 0

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function getMemoryUsageTable()
  if system.getMemoryUsage then
    local ok, m = pcall(system.getMemoryUsage)
    if ok and type(m) == "table" then return m end
  end
  return {}
end

----------------------------------------------------------------
-- Wakeup (called by your 0.025s task)
----------------------------------------------------------------
function performance.wakeup()
  local t_now = os.clock()

  -- dt since last profiler tick (seed with schedule period)
  local dt
  if last_wakeup_start ~= nil then
    dt = t_now - last_wakeup_start
  else
    dt = SCHED_DT
  end

  if dt < (0.25 * SCHED_DT) then dt = SCHED_DT end

  local tick_work_start = t_now

  ----------------------------------------------------------------
  -- Memory (rate-limited)
  ----------------------------------------------------------------
  if (t_now - last_mem_t) >= MEM_PERIOD then
    last_mem_t = t_now

    local m = getMemoryUsageTable()
    local free_lua_kb = clamp(((m.luaRamAvailable or 0)        / 1024), 0, 1e12)
    local free_bmp_kb = clamp(((m.luaBitmapsRamAvailable or 0) / 1024), 0, 1e12)

    if mem_avg_kb == nil then mem_avg_kb = free_lua_kb
    else mem_avg_kb = clamp(MEM_ALPHA * free_lua_kb + (1 - MEM_ALPHA) * mem_avg_kb, 0, 1e12) end
    rfsuite.session.performance.freeram = mem_avg_kb

    local gc_total_kb = clamp(collectgarbage("count") or 0, 0, 1e12)
    if usedram_avg_kb == nil then usedram_avg_kb = gc_total_kb
    else usedram_avg_kb = clamp(MEM_ALPHA * gc_total_kb + (1 - MEM_ALPHA) * usedram_avg_kb, 0, 1e12) end
    rfsuite.session.performance.usedram = usedram_avg_kb

    if free_bmp_kb > bitmap_pool_est_kb then bitmap_pool_est_kb = free_bmp_kb end
    rfsuite.session.performance.luaBitmapsRamKB = free_bmp_kb

    rfsuite.session.performance.mainStackKB     = (m.mainStackAvailable or 0) / 1024
    rfsuite.session.performance.ramKB           = (m.ramAvailable       or 0) / 1024
    rfsuite.session.performance.luaRamKB        = (m.luaRamAvailable    or 0) / 1024
    rfsuite.session.performance.luaBitmapsRamKB = (m.luaBitmapsRamAvailable or 0) / 1024
  end

  ----------------------------------------------------------------
  -- CPU (work_time / wall_time_between_wakeups)
  ----------------------------------------------------------------
  local work_elapsed = os.clock() - tick_work_start
  local instant_util = work_elapsed / dt

  if usingSimulator and instant_util < SIM_TARGET_UTIL then
    instant_util = math.min(
      SIM_MAX_UTIL,
      instant_util + (SIM_TARGET_UTIL - instant_util) * SIM_BLEND
    )
  end

  cpu_avg = CPU_ALPHA * instant_util + (1 - CPU_ALPHA) * cpu_avg
  rfsuite.session.performance.cpuload = clamp(cpu_avg * 100, 0, 100)

  last_wakeup_start = t_now
end

function performance.reset()
  last_wakeup_start = nil
  cpu_avg           = 0
  last_mem_t        = 0
  mem_avg_kb        = nil
  usedram_avg_kb    = nil
  bitmap_pool_est_kb= 0
end

return performance
