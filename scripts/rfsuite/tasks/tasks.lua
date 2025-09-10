-- Simplified Task Scheduler with single `interval`

local utils = rfsuite.utils
local compiler = rfsuite.compiler.loadfile

local currentTelemetrySensor
local tasksPerCycle = 1
local taskSchedulerPercentage = 0.5

local schedulerTick = 0

local tasks, tasksList = {}, {}
tasks.heartbeat, tasks.init, tasks.wasOn = nil, true, false
rfsuite.session.telemetryTypeChanged = true

tasks._justInitialized = false
tasks._initState = "start"
tasks._initMetadata = nil
tasks._initKeys = nil
tasks._initIndex = 1

local ethosVersionGood = nil
local telemetryCheckScheduler = os.clock()
local lastTelemetrySensorName, sportSensor, elrsSensor = nil, nil, nil
local lastModuleId = 0

local usingSimulator = system.getVersion().simulation

local tlm = system.getSource({ category = CATEGORY_SYSTEM_EVENT, member = TELEMETRY_ACTIVE })

-- track cpu
local CPU_TICK_HZ     = 20

-- Track the start time of the previous wakeup for accurate utilization
local last_wakeup_start = nil
local CPU_TICK_BUDGET = 1 / CPU_TICK_HZ
local CPU_ALPHA       = 0.2
local cpu_avg         = 0

-- track memory
local MEM_ALPHA   = 0.2
local mem_avg_kb  = 0
local last_mem_t  = 0
local MEM_PERIOD  = 2.0   -- seconds between samples


-- =========================
-- Profiler config & helpers
-- =========================
-- Zero-overhead when disabled (just a few conditionals).
tasks.profile = {
  enabled = false,         -- master switch
  dumpInterval = 5,        -- seconds between dumps at end of wakeup()
  minDuration = 0,         -- only record runs >= this many seconds
  include = nil,           -- optional set: { taskname = true, ... }
  exclude = nil,           -- optional set: { taskname = true, ... }
  onDump = nil             -- optional function(snapshot) -> true to suppress default logging
}

local function profWanted(name)
  if not tasks.profile.enabled then return false end
  local inc, exc = tasks.profile.include, tasks.profile.exclude
  if inc and not inc[name] then return false end
  if exc and exc[name] then return false end
  return true
end

local function profRecord(task, dur)
  if dur < (tasks.profile.minDuration or 0) then return end
  task.duration = dur
  task.totalDuration = (task.totalDuration or 0) + dur
  task.runs = (task.runs or 0) + 1
  task.maxDuration = math.max(task.maxDuration or 0, dur)
end

-- Returns true if the task is active (based on recent run time or triggers)
function tasks.isTaskActive(name)
    for _, t in ipairs(tasksList) do
        if t.name == name then
            local age = os.clock() - t.last_run
            if name == "msp" then
                return rfsuite.app.triggers.mspBusy
            elseif name == "callback" then
                return age <= 2
            else
                return age <= t.interval
            end
        end
    end
    return false
end

local function taskOffset(name, interval)
    local hash = 0
    for i = 1, #name do
        hash = (hash * 31 + name:byte(i)) % 100000
    end
    local base = (hash % (interval * 1000)) / 1000  -- base hash offset
    local jitter = math.random() * interval
    return (base + jitter) % interval
end

-- Print a human-readable schedule of all tasks
function tasks.dumpSchedule()
  local now = os.clock()
  utils.log("====== Task Schedule Dump ======", "info")
  for _, t in ipairs(tasksList) do
    local next_run = t.last_run + t.interval
    local in_secs  = next_run - now
    utils.log(
      string.format(
        "%-15s | interval: %4.1fs | last_run: %8.2f | next in: %6.2fs",
        t.name, t.interval, t.last_run, in_secs
      ),
      "info"
    )
  end
  utils.log("================================", "info")
end

function tasks.initialize()
    local cacheFile, cachePath = "tasks.lua", "cache/tasks.lua"
    if io.open(cachePath, "r") then
        local ok, cached = pcall(rfsuite.compiler.dofile, cachePath)
        if ok and type(cached) == "table" then
            tasks._initMetadata = cached
            utils.log("[cache] Loaded task metadata from cache", "info")
        else
            utils.log("[cache] Failed to load tasks cache", "info")
        end
    end
    if not tasks._initMetadata then
        local taskPath, taskMetadata = "tasks/", {}
        for _, dir in pairs(system.listFiles(taskPath)) do
            if dir ~= "." and dir ~= ".." and not dir:match("%.%a+$") then
                local initPath = taskPath .. dir .. "/init.lua"
                local func, err = compiler(initPath)
                if err then
                    utils.log("Error loading " .. initPath .. ": " .. err, "info")
                elseif func then
                    local tconfig = func()
                    if type(tconfig) == "table" and tconfig.interval and tconfig.script then
                        taskMetadata[dir] = {
                            interval = tconfig.interval,
                            script = tconfig.script,
                            linkrequired = tconfig.linkrequired or false,
                            connected = tconfig.connected or false,
                            simulatoronly = tconfig.simulatoronly or false,
                            spreadschedule = tconfig.spreadschedule or false,
                            init = initPath
                        }
                    end
                end
            end
        end
        tasks._initMetadata = taskMetadata
        utils.createCacheFile(taskMetadata, cacheFile)
        utils.log("[cache] Created new tasks cache file", "info")
    end
    tasks._initKeys = utils.keys(tasks._initMetadata)
    tasks._initState = "loadNextTask"
end

function tasks.findTasks()
    local taskPath, taskMetadata = "tasks/", {}

    for _, dir in pairs(system.listFiles(taskPath)) do
        if dir ~= "." and dir ~= ".." and not dir:match("%.%a+$") then
            local initPath = taskPath .. dir .. "/init.lua"
            local func, err = compiler(initPath)
            if err then
                utils.log("Error loading " .. initPath .. ": " .. err, "info")
            elseif func then
                local tconfig = func()
                if type(tconfig) ~= "table" or not tconfig.interval or not tconfig.script then
                    utils.log("Invalid configuration in " .. initPath, "debug")
                else
                    local scriptPath = taskPath .. dir .. "/" .. tconfig.script
                    local fn, loadErr = compiler(scriptPath)
                    if fn then
                        tasks[dir] = fn(config)
                    else
                        utils.log("Failed to load task script " .. scriptPath .. ": " .. loadErr, "warn")
                    end

                    -- add a small drift to de-synchronize fixed intervals
                    local baseInterval = tconfig.interval or 1
                    local interval     = baseInterval + (math.random() * 0.1)
                    local offset = taskOffset(dir, interval)

                    local task = {
                        name = dir,
                        interval = interval,
                        script = tconfig.script,
                        linkrequired = tconfig.linkrequired or false,
                        connected = tconfig.connected or false,
                        spreadschedule = tconfig.spreadschedule or false,
                        simulatoronly = tconfig.simulatoronly or false,
                        last_run = os.clock() - offset,
                        -- profiling fields
                        duration = 0,
                        totalDuration = 0,
                        runs = 0,
                        maxDuration = 0
                    }
                    table.insert(tasksList, task)

                    taskMetadata[dir] = {
                        interval = task.interval,
                        script = task.script,
                        linkrequired = task.linkrequired,
                        connected = task.connected,
                        simulatoronly = task.simulatoronly,
                        spreadschedule = task.spreadschedule
                    }
                end
            end
        end
    end
    return taskMetadata
end

function tasks.telemetryCheckScheduler()
    local now = os.clock()

    if now - (telemetryCheckScheduler or 0) >= 2 then
        local telemetryState = tlm and tlm:state() or false
        if rfsuite.simevent.telemetry_state == false and system.getVersion().simulation then
            telemetryState = false
        end

        if not telemetryState then
            utils.session()
            if rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue  then
                rfsuite.tasks.msp.mspQueue:clear()
            end     
        else
            sportSensor = system.getSource({ appId = 0xF101 })
            elrsSensor = system.getSource({ crsfId = 0x14, subIdStart = 0, subIdEnd = 1 })
            currentTelemetrySensor = sportSensor or elrsSensor

            if not currentTelemetrySensor then
                utils.session()
                if rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue  then
                    rfsuite.tasks.msp.mspQueue:clear()
                end                
            else
                rfsuite.session.telemetryState = true
                rfsuite.session.telemetrySensor = currentTelemetrySensor

                local sensorModule = rfsuite.session.telemetrySensor:module()
                local module = model.getModule(sensorModule)
                rfsuite.session.telemetryModule = module
                rfsuite.session.telemetryType = sportSensor and "sport" or elrsSensor and "crsf" or nil
                rfsuite.session.telemetryTypeChanged = currentTelemetrySensor:name() ~= lastTelemetrySensorName
                lastTelemetrySensorName = currentTelemetrySensor:name()
                telemetryCheckScheduler = now

                if lastModuleId ~= sensorModule then
                    lastModuleId = sensorModule
                    rfsuite.utils.log("Module ID changed, resetting session","info")
                    rfsuite.session.telemetryTypeChanged = true
                end

            end
        end
    end
end

function tasks.active()
    if not tasks.heartbeat then return false end

    local age = os.clock() - tasks.heartbeat
    tasks.wasOn = age >= 2
    if rfsuite.app.triggers.mspBusy or age <= 2 then return true end

    return false
end

function tasks.wakeup()
    schedulerTick = schedulerTick + 1
    tasks.heartbeat = os.clock()

    tasks.profile.enabled = rfsuite.preferences and rfsuite.preferences.developer and rfsuite.preferences.developer.taskprofiler

    if ethosVersionGood == nil then
        ethosVersionGood = utils.ethosVersionAtLeast()
    end
    if not ethosVersionGood then return end

    if tasks.init then
        tasks.init = false
        tasks._justInitialized = true
        tasks.initialize()
        return
    end

    if tasks._justInitialized then
        tasks._justInitialized = false
        return
    end

    if tasks._initState == "loadNextTask" then
        local key = tasks._initKeys[tasks._initIndex]
        if key then
            local meta = tasks._initMetadata[key]
            if meta.init then
                local initFn, err = compiler(meta.init)
                if initFn then
                    pcall(initFn)
                else
                    utils.log("Failed to load init for " .. key .. ": " .. (err or "unknown error"), "info")
                end
            end
            local script = "tasks/" .. key .. "/" .. meta.script
            local module = assert(compiler(script))(config)
            tasks[key] = module

            if meta.interval >= 0 then
                local baseInterval = meta.interval or 1
                local interval = baseInterval + (math.random() * 0.1)
                local offset = math.random() * interval
                table.insert(tasksList, {
                    name = key,
                    interval = interval,
                    script = meta.script,
                    spreadschedule = meta.spreadschedule,
                    linkrequired = meta.linkrequired or false,
                    connected = meta.connected or false,
                    simulatoronly = meta.simulatoronly or false,
                    last_run = os.clock() - offset,
                    -- profiling fields
                    duration = 0,
                    totalDuration = 0,
                    runs = 0,
                    maxDuration = 0
                })
            end

            tasks._initIndex = tasks._initIndex + 1
            return
        else
            tasks._initState = nil
            tasks._initMetadata = nil
            tasks._initKeys = nil
            tasks._initIndex = 1
            utils.log("All tasks initialized.", "info")
            return
        end
    end

    tasks.telemetryCheckScheduler()

    local now = os.clock()
    local cycleFlip = schedulerTick % 2  -- alternate every tick

    local function canRunTask(task)
        local intervalTicks = task.interval * 20
        local isHighFrequency = intervalTicks < 20
        local clockDelta = now - task.last_run
        local graceFactor = 0.25

        local overdue
        if isHighFrequency then
            overdue = clockDelta >= intervalTicks
        else
            overdue = clockDelta >= (intervalTicks + intervalTicks * graceFactor)
        end

        local priorityTask = task.name == "msp" or task.name == "callback"

        local linkOK = not task.linkrequired or rfsuite.session.telemetryState
        local connOK = not task.connected    or rfsuite.session.isConnected

        return linkOK
            and connOK
            and (priorityTask or overdue or not rfsuite.app.triggers.mspBusy)
            and (not task.simulatoronly or usingSimulator)
    end

    local function runNonSpreadTasks()
        for _, task in ipairs(tasksList) do
            if not task.spreadschedule and tasks[task.name].wakeup and canRunTask(task) then
                local elapsed = now - task.last_run
                if elapsed >= task.interval then
                    local fn = tasks[task.name].wakeup
                    if fn then
                        if profWanted(task.name) then
                            local t0 = os.clock()
                            local ok, err = pcall(fn, tasks[task.name])
                            local t1 = os.clock()
                            profRecord(task, t1 - t0)
                            if not ok then
                                print(("Error in task %q wakeup: %s"):format(task.name, err))
                                collectgarbage("collect")
                            end
                        else
                            local ok, err = pcall(fn, tasks[task.name])
                            if not ok then
                                print(("Error in task %q wakeup: %s"):format(task.name, err))
                                collectgarbage("collect")
                            end
                        end
                    end
                    task.last_run = now
                end
            end
        end
    end

    local function runSpreadTasks()
        local normalEligibleTasks, mustRunTasks = {}, {}

        for _, task in ipairs(tasksList) do
            if task.spreadschedule and canRunTask(task) then
                local elapsed = now - task.last_run
                if elapsed >= 2 * task.interval then
                    table.insert(mustRunTasks, task)
                elseif elapsed >= task.interval then
                    table.insert(normalEligibleTasks, task)
                end
            end
        end

        table.sort(mustRunTasks, function(a, b) return a.last_run < b.last_run end)
        table.sort(normalEligibleTasks, function(a, b) return a.last_run < b.last_run end)

        local nonSpreadCount = 0
        for _, task in ipairs(tasksList) do
            if not task.spreadschedule then
                nonSpreadCount = nonSpreadCount + 1
            end
        end

        tasksPerCycle = math.ceil(nonSpreadCount * taskSchedulerPercentage)

        for _, task in ipairs(mustRunTasks) do
            local fn = tasks[task.name].wakeup
            if fn then
                if profWanted(task.name) then
                    local t0 = os.clock()
                    local ok, err = pcall(fn, tasks[task.name])
                    local t1 = os.clock()
                    profRecord(task, t1 - t0)
                    if not ok then
                        print(("Error in task %q wakeup (must-run): %s"):format(task.name, err))
                        collectgarbage("collect")
                    end
                else
                    local ok, err = pcall(fn, tasks[task.name])
                    if not ok then
                        print(("Error in task %q wakeup (must-run): %s"):format(task.name, err))
                        collectgarbage("collect")
                    end
                end
            end
            task.last_run = now
        end

        for i = 1, math.min(tasksPerCycle, #normalEligibleTasks) do
            local task = normalEligibleTasks[i]
            local fn = tasks[task.name].wakeup
            if fn then
                if profWanted(task.name) then
                    local t0 = os.clock()
                    local ok, err = pcall(fn, tasks[task.name])
                    local t1 = os.clock()
                    profRecord(task, t1 - t0)
                    if not ok then
                        print(("Error in task %q wakeup: %s"):format(task.name, err))
                        collectgarbage("collect")
                    end
                else
                    local ok, err = pcall(fn, tasks[task.name])
                    if not ok then
                        print(("Error in task %q wakeup: %s"):format(task.name, err))
                        collectgarbage("collect")
                    end
                end
            end
            task.last_run = now
        end
    end

    if cycleFlip == 0 then
        runNonSpreadTasks()
    else
        runSpreadTasks()
    end

    -- Periodic profile dump (only when profiler is on)
    if tasks.profile.enabled then
        tasks._lastProfileDump = tasks._lastProfileDump or now
        local dumpEvery = tasks.profile.dumpInterval or 5
        if (now - tasks._lastProfileDump) >= dumpEvery then
            if tasks.dumpProfile then tasks.dumpProfile() end
            tasks._lastProfileDump = now
        end
    end

    -- track average cpu load
    
  -- Accurate CPU utilization: work_time / wall_time_between_wakeups
  local t_end = os.clock()
  local work_elapsed = t_end - now

  local dt
  if last_wakeup_start ~= nil then
    dt = now - last_wakeup_start
  else
    dt = (1 / CPU_TICK_HZ)
  end

  -- Guard against pathological tiny dt (e.g., re-entrancy)
  if dt < (0.25 * (1 / CPU_TICK_HZ)) then
    dt = (1 / CPU_TICK_HZ)
  end

  local instant_util = work_elapsed / dt   -- 0..∞
  cpu_avg = CPU_ALPHA * instant_util + (1 - CPU_ALPHA) * cpu_avg
  rfsuite.session.cpuload = math.min(100, math.max(0, cpu_avg * 100))

  last_wakeup_start = now


    -- track average memory usage
    do
        local now = os.clock()
        if (now - last_mem_t) >= MEM_PERIOD then
            last_mem_t = now
            local m = system.getMemoryUsage()
            if m and m.luaRamAvailable then
                local free_now = m.luaRamAvailable / 1000
                mem_avg_kb = MEM_ALPHA * free_now + (1 - MEM_ALPHA) * mem_avg_kb
                rfsuite.session.freeram = mem_avg_kb
            end
        end
    end

end

function tasks.reset()
    --utils.log("Reset all tasks", "info")
    for _, task in ipairs(tasksList) do
        if tasks[task.name].reset then
            tasks[task.name].reset()
        end
    end
  rfsuite.utils.session()
end

-- =========================
-- Profiling utilities
-- =========================
function tasks.dumpProfile(opts)
    if not tasks.profile.enabled then return end
    local sortKey = (opts and opts.sort) or "avg"
    local snapshot = {}
    for _, t in ipairs(tasksList) do
        local runs = t.runs or 0
        local avg = runs > 0 and ((t.totalDuration or 0) / runs) or 0
        snapshot[#snapshot+1] = {
            name = t.name,
            last = t.duration or 0,
            max  = t.maxDuration or 0,
            total= t.totalDuration or 0,
            runs = runs,
            avg  = avg,
            interval = t.interval or 0
        }
    end
    local order = {
        avg   = function(a,b) return a.avg   > b.avg   end,
        last  = function(a,b) return a.last  > b.last  end,
        max   = function(a,b) return a.max   > b.max   end,
        total = function(a,b) return a.total > b.total end,
        runs  = function(a,b) return a.runs  > b.runs  end
    }
    table.sort(snapshot, order[sortKey] or order.avg)

    -- Allow consumer to intercept (e.g., UI sink) and suppress logs.
    if tasks.profile.onDump and tasks.profile.onDump(snapshot) then return end

    utils.log("====== Task Profile ======", "info")
    for _, p in ipairs(snapshot) do
        utils.log(string.format(
            "%-15s | avg:%8.5fs | last:%8.5fs | max:%8.5fs | total:%8.3fs | runs:%6d | int:%4.2fs",
            p.name, p.avg, p.last, p.max, p.total, p.runs, p.interval
        ), "info")
    end
    utils.log("================================", "info")
end

function tasks.resetProfile()
    for _, t in ipairs(tasksList) do
        t.duration = 0
        t.totalDuration = 0
        t.runs = 0
        t.maxDuration = 0
    end
    utils.log("[profile] Cleared profiling stats", "info")
end

function tasks.event(widget, category, value, x, y)
    print("Event:", widget, category, value, x, y)
end

function tasks.init()
    --print("Init:")
end

function tasks.read()
    --print("Read:")
end

function tasks.write()
    --print("Write:")
end

return tasks
