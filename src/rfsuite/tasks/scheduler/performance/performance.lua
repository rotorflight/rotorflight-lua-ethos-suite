--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}

local performance = {}

-- Localize globals for performance
local os_clock = os.clock
local math_exp = math.exp
local math_min = math.min
local collectgarbage = collectgarbage
local system_getMemoryUsage = system.getMemoryUsage

local PROF_PERIOD_S = 0.05
local SCHED_DT = PROF_PERIOD_S
local CPU_TAU = 5.0
local MEM_ALPHA = 0.8
local MEM_PERIOD = 0.50

local usingSimulator = (system.getVersion and system.getVersion().simulation) or false

local SIM_TARGET_UTIL = 0.80
local SIM_MAX_UTIL = 1.00
local SIM_BLEND = 0.90

local last_wakeup_start = nil
local cpu_avg = 0

local last_mem_t = 0
local mem_avg_kb = nil
local usedram_avg_kb = nil
local bitmap_pool_est_kb = 0
local win_sum_ms, win_budget_ms, win_t = 0, 0, 0

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end


function performance.wakeup()
    local t_now = os_clock()

    local dt
    if last_wakeup_start ~= nil then
        dt = t_now - last_wakeup_start
    else
        dt = SCHED_DT
    end

    if dt < (0.25 * SCHED_DT) then dt = SCHED_DT end

    -- Cache table reference
    local perf = rfsuite.performance
    if not perf then
        perf = {}
        rfsuite.performance = perf
    end

    if (t_now - last_mem_t) >= MEM_PERIOD then
        last_mem_t = t_now

        local m
        if system_getMemoryUsage then m = system_getMemoryUsage() end
        if type(m) == "table" then
            local free_lua_kb = clamp(((m.luaRamAvailable or 0) / 1024), 0, 1e12)
            local free_bmp_kb = clamp(((m.luaBitmapsRamAvailable or 0) / 1024), 0, 1e12)

            if mem_avg_kb == nil then
                mem_avg_kb = free_lua_kb
            else
                mem_avg_kb = clamp(MEM_ALPHA * free_lua_kb + (1 - MEM_ALPHA) * mem_avg_kb, 0, 1e12)
            end
            perf.freeram = mem_avg_kb

            local gc_total_kb = clamp(collectgarbage("count") or 0, 0, 1e12)
            if usedram_avg_kb == nil then
                usedram_avg_kb = gc_total_kb
            else
                usedram_avg_kb = clamp(MEM_ALPHA * gc_total_kb + (1 - MEM_ALPHA) * usedram_avg_kb, 0, 1e12)
            end
            perf.usedram = usedram_avg_kb

            if free_bmp_kb > bitmap_pool_est_kb then bitmap_pool_est_kb = free_bmp_kb end
            perf.luaBitmapsRamKB = free_bmp_kb

            perf.mainStackKB = (m.mainStackAvailable or 0) / 1024
            perf.ramKB = (m.ramAvailable or 0) / 1024
            perf.luaRamKB = (m.luaRamAvailable or 0) / 1024
            perf.luaBitmapsRamKB = (m.luaBitmapsRamAvailable or 0) / 1024
        end
    end

    local loop_ms = tonumber(perf.taskLoopCpuMs) or tonumber(perf.taskLoopTime) or 0
    local budget_ms = SCHED_DT * 1000.0

    local instant_util = 0

    win_sum_ms = win_sum_ms + (loop_ms or 0)
    win_budget_ms = win_budget_ms + (budget_ms or 50)
    win_t = win_t + (SCHED_DT or 0.05)

    if win_t >= 0.10 then
        local window_util = 0
        if win_budget_ms > 0 then window_util = win_sum_ms / win_budget_ms end

        if window_util < 0 then window_util = 0 end
        if window_util > 1 then window_util = 1 end
        perf.cpuload_window100 = window_util * 100

        win_sum_ms, win_budget_ms, win_t = 0, 0, 0
    end

    if budget_ms > 0 then instant_util = loop_ms / budget_ms end

    if instant_util < 0 then instant_util = 0 end
    if instant_util > 1 then instant_util = 1 end

    if usingSimulator and instant_util < SIM_TARGET_UTIL then 
        instant_util = math_min(SIM_MAX_UTIL, instant_util + (SIM_TARGET_UTIL - instant_util) * SIM_BLEND) 
    end

    local alpha = 1 - math_exp(-dt / CPU_TAU)
    cpu_avg = alpha * instant_util + (1 - alpha) * cpu_avg

    -- Inline clamp for high frequency path
    local load = cpu_avg * 100
    if load < 0 then load = 0 elseif load > 100 then load = 100 end
    perf.cpuload = load

    perf.loop_ms = loop_ms
    perf.budget_ms = budget_ms
    perf.util_raw = instant_util * 100
    perf.tick_ms = dt * 1000.0

    last_wakeup_start = t_now
end

function performance.reset()
    last_wakeup_start = nil
    cpu_avg = 0
    last_mem_t = 0
    mem_avg_kb = nil
    usedram_avg_kb = nil
    bitmap_pool_est_kb = 0
end

return performance
