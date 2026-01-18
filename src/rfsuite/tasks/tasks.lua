--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local utils = rfsuite.utils

local currentTelemetrySensor
local tasksPerCycle
local taskSchedulerPercentage

local schedulerTick
local lastSensorName
local tasks, tasksList = {}, {}
-- Split scheduled tasks into two lists so the scheduler doesn't have to scan
-- the full task list on every cycle.
local tasksListNonSpread, tasksListSpread = {}, {}
local nonSpreadCount = 0
tasks.heartbeat, tasks.begin = nil, nil

local currentSensor, currentModuleId, currentTelemetryType, currentModuleNumber
local internalModule, externalModule

local CPU_TICK_HZ = 20
local SCHED_DT = 1 / CPU_TICK_HZ
local OVERDUE_TOL = SCHED_DT * 0.25

tasks.rateMultiplier = tasks.rateMultiplier or 1.0

local LOG_OVERDUE_TASKS = false

tasks._justInitialized = false
tasks._initState = "start"
tasks._initMetadata = nil
tasks._initKeys = nil
tasks._initIndex = 1

local ethosVersionGood
local telemetryCheckScheduler = os.clock

local lastCheckAt
local lastTelemetryType

local lastModelPath = model.path()
local lastModelPathCheckAt = 0
local PATH_CHECK_INTERVAL = 2.0

local lastNameCheckAt = 0
local NAME_CHECK_INTERVAL = 2.0

local usingSimulator = system.getVersion().simulation

local tlm

-- Reuse source descriptor tables to avoid allocations in hot paths
local SRC_SPORT = {appId = 0xF101}
local SRC_CRSF  = {crsfId = 0x14, subIdStart = 0, subIdEnd = 1}
local SRC_TLM_ACTIVE = {category = CATEGORY_SYSTEM_EVENT, member = TELEMETRY_ACTIVE}

tasks.profile = {enabled = false, dumpInterval = 5, minDuration = 0, include = nil, exclude = nil, onDump = nil}

-- Reused tables to avoid per-cycle allocations (reduces GC churn)
local normalEligibleTasks = {}
local mustRunTasks = {}

-- Hoist comparator (avoid allocating closure each cycle)
local SORT_BY_LAST_RUN_ASC = function(a, b) return a.last_run < b.last_run end

local function profWanted(name)
    if not tasks.profile.enabled then return end
    if not tasks.profile.enabled then return false end
    local inc, exc = tasks.profile.include, tasks.profile.exclude
    if inc and not inc[name] then return false end
    if exc and exc[name] then return false end
    return true
end

local function profRecord(task, dur)
    if not tasks.profile.enabled then return end
    if dur < (tasks.profile.minDuration or 0) then return end
    task.duration = dur
    task.totalDuration = (task.totalDuration or 0) + dur
    task.runs = (task.runs or 0) + 1
    task.maxDuration = math.max(task.maxDuration or 0, dur)
end

function tasks.isTaskActive(name)
    for _, t in ipairs(tasksList) do
        if t.name == name then
            local age = os.clock() - t.last_run
            if name == "msp" then
                return rfsuite.session.mspBusy
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
    for i = 1, #name do hash = (hash * 31 + name:byte(i)) % 100000 end
    local base = (hash % (interval * 1000)) / 1000
    local jitter = math.random() * interval
    return (base + jitter) % interval
end

function tasks.dumpSchedule()
    local now = os.clock()
    utils.log("====== Task Schedule Dump ======", "info")
    for _, t in ipairs(tasksList) do
        local next_run = t.last_run + t.interval
        local in_secs = next_run - now
        utils.log(string.format("%-15s | interval: %4.3fs | last_run: %8.3f | next in: %6.3fs", t.name, t.interval, t.last_run, in_secs), "info")
    end

    function tasks.setRateMultiplier(mult)
        mult = tonumber(mult) or 1.0
        if mult <= 0 then mult = 0.0001 end
        tasks.rateMultiplier = mult
        for _, task in ipairs(tasksList) do
            local base = task.baseInterval or task.interval or 1
            local j = task.jitter or 0
            task.interval = (base * mult) + j
        end
        utils.log(string.format("[scheduler] Global rate multiplier set to %.3f", tasks.rateMultiplier), "info")
    end

    utils.log("================================", "info")
end

function tasks.initialize()
    local cacheFile, cachePath = "tasks.lua", "cache/tasks.lua"
    if io.open(cachePath, "r") then
        local ok, cached = pcall(dofile, cachePath)
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
                local func, err = loadfile(initPath)
                if err then
                    utils.log("Error loading " .. initPath .. ": " .. err, "info")
                elseif func then
                    local tconfig = func()
                    if type(tconfig) == "table" and tconfig.interval and tconfig.script then taskMetadata[dir] = {interval = tconfig.interval, script = tconfig.script, linkrequired = tconfig.linkrequired or false, connected = tconfig.connected or false, simulatoronly = tconfig.simulatoronly or false, spreadschedule = tconfig.spreadschedule or false, init = initPath} end
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
            local func, err = loadfile(initPath)
            if err then
                utils.log("Error loading " .. initPath .. ": " .. err, "info")
            elseif func then
                local tconfig = func()
                if type(tconfig) ~= "table" or not tconfig.interval or not tconfig.script then
                    utils.log("Invalid configuration in " .. initPath, "debug")
                else
                    local scriptPath = taskPath .. dir .. "/" .. tconfig.script
                    local fn, loadErr = loadfile(scriptPath)
                    if fn then
                        tasks[dir] = fn(config)
                    else
                        utils.log("Failed to load task script " .. scriptPath .. ": " .. loadErr, "warn")
                    end

                    local baseInterval = tconfig.interval or 1
                    local jitter = (math.random() * 0.1)
                    local interval = (baseInterval * (tasks.rateMultiplier or 1.0)) + jitter
                    local offset = taskOffset(dir, interval)

                    local task = {name = dir, interval = interval, baseInterval = baseInterval, jitter = jitter, script = tconfig.script, linkrequired = tconfig.linkrequired or false, connected = tconfig.connected or false, spreadschedule = tconfig.spreadschedule or false, simulatoronly = tconfig.simulatoronly or false, last_run = os.clock() - offset, duration = 0, totalDuration = 0, runs = 0, maxDuration = 0}
                    table.insert(tasksList, task)
                    if task.spreadschedule then
                        table.insert(tasksListSpread, task)
                    else
                        table.insert(tasksListNonSpread, task)
                        nonSpreadCount = nonSpreadCount + 1
                    end

                    taskMetadata[dir] = {interval = task.interval, script = task.script, linkrequired = task.linkrequired, connected = task.connected, simulatoronly = task.simulatoronly, spreadschedule = task.spreadschedule}
                end
            end
        end
    end
    return taskMetadata
end

local function clearSessionAndQueue()
    tasks.setTelemetryTypeChanged()
    utils.session()
    local q = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue
    if q then q:clear() end

    internalModule = nil
    externalModule = nil
    currentSensor = nil
    currentModuleId = nil
    currentTelemetryType = nil
    currentModuleNumber = nil

    if rfsuite.tasks.msp and rfsuite.tasks.msp.common and rfsuite.tasks.msp.common.setProtocolVersion then pcall(rfsuite.tasks.msp.common.setProtocolVersion, 1) end
    if rfsuite.config and rfsuite.session then
        rfsuite.config.mspProtocolVersion = 1
        rfsuite.session.mspProtocolVersion = 1
    end

end

function tasks.telemetryCheckScheduler()

    if rfsuite.app and rfsuite.app.triggers and rfsuite.app.escPowerCycleLoader then return end

    local now = os.clock()

    local telemetryState = (tlm and tlm:state()) or false
    if system.getVersion().simulation and rfsuite.simevent.telemetry_state == false then telemetryState = false end

    if not telemetryState then
        if not rfsuite.session.isConnected then
            if (not lastCheckAt) or (now - lastCheckAt) >= 1.0 then
                lastCheckAt = now
                utils.log("Waiting for connection", "connect")
            end
        end
        return clearSessionAndQueue()
    end

    if now - lastModelPathCheckAt >= PATH_CHECK_INTERVAL then
        lastModelPathCheckAt = now
        local newModelPath = model.path()
        if newModelPath ~= lastModelPath then
            utils.log("Model changed, resetting session", "info")
            utils.log("Model changed, resetting session", "connect")
            lastModelPath = newModelPath
            clearSessionAndQueue()
        end
    end

    if currentSensor then
        rfsuite.session.telemetryState = true
        rfsuite.session.telemetrySensor = currentSensor
        rfsuite.session.telemetryModule = currentModuleId
        rfsuite.session.telemetryType = currentTelemetryType
        rfsuite.session.telemetryModuleNumber = currentModuleNumber

        if now - lastNameCheckAt >= NAME_CHECK_INTERVAL then
            lastNameCheckAt = now
            if currentSensor:name() ~= lastSensorName then
                utils.log("Telemetry sensor changed to " .. tostring(currentSensor:name()), "info")
                utils.log("Telem. sensor changed to " .. tostring(currentSensor:name()), "connect")
                lastSensorName = currentSensor:name()
                currentSensor = nil
            end
        end

        return
    end

    if not internalModule or not externalModule then
        internalModule = model.getModule(0)
        externalModule = model.getModule(1)
    end

    if internalModule and internalModule:enable() then
        currentSensor = system.getSource(SRC_SPORT)
        currentModuleId = internalModule
        currentModuleNumber = 0
        currentTelemetryType = "sport"
    elseif externalModule and externalModule:enable() then
        currentSensor = system.getSource(SRC_CRSF)
        currentModuleId = externalModule
        currentTelemetryType = "crsf"
        currentModuleNumber = 1
        if not currentSensor then
            currentSensor = system.getSource(SRC_SPORT)
            currentTelemetryType = "sport"
        end
    end

    if not currentSensor then return clearSessionAndQueue() end

    rfsuite.session.telemetryState = true
    rfsuite.session.telemetrySensor = currentSensor
    rfsuite.session.telemetryModule = currentModuleId
    rfsuite.session.telemetryType = currentTelemetryType
    rfsuite.session.telemetryModuleNumber = currentModuleNumber

    if currentTelemetryType ~= lastTelemetryType then
        rfsuite.utils.log("Telemetry type changed to " .. tostring(currentTelemetryType), "info")
        rfsuite.utils.log("Telem. type changed to " .. tostring(currentTelemetryType), "connect")
        tasks.setTelemetryTypeChanged()
        lastTelemetryType = currentTelemetryType
        clearSessionAndQueue()
    end

end

function tasks.active()

    if tasks.heartbeat and (os.clock() - tasks.heartbeat) < 5 then return true end

    return false
end

local function overdue_seconds(task, now, grace_s) return (now - task.last_run) - (task.interval + (grace_s or 0)) end

local function canRunTask(task, now)
    local hf = task.interval < SCHED_DT
    local grace = hf and OVERDUE_TOL or (task.interval * 0.25)

    local od = overdue_seconds(task, now, grace)

    local priorityTask = task.name == "msp" or task.name == "callback"

    local linkOK = not task.linkrequired or rfsuite.session.telemetryState
    local connOK = not task.connected or rfsuite.session.isConnected

    local ok = linkOK and connOK and (priorityTask or od >= 0 or not rfsuite.session.mspBusy) and (not task.simulatoronly or usingSimulator)

    return ok, od
end



-- Hoisted runners (avoid allocating closures on every wakeup)
local function runNonSpreadTasks(now)

    local loopCpu = 0

    for _, task in ipairs(tasksListNonSpread) do
        if tasks[task.name].wakeup then
            local okToRun, od = canRunTask(task, now)
            if okToRun then
                local elapsed = now - task.last_run
                if elapsed + OVERDUE_TOL >= task.interval then
                    if (od or 0) > 0 then
                        if LOG_OVERDUE_TASKS then utils.log(string.format("[scheduler] %s overdue by %.3fs", task.name, od), "info") end
                    end

                    local fn = tasks[task.name].wakeup
                    if fn then
                        local c0 = os.clock()
                        local ok, err = pcall(fn, tasks[task.name])
                        local c1 = os.clock()
                        local dur = c1 - c0
                        loopCpu = loopCpu + dur

                        if profWanted(task.name) then
                            profRecord(task, dur)
                            if not ok then print(("Error in task %q wakeup: %s"):format(task.name, err)) end
                        elseif not ok then
                            print(("Error in task %q wakeup: %s"):format(task.name, err))
                        end
                    end

                    task.last_run = now
                end
            end
        end
    end

    return loopCpu
end

local function runSpreadTasks(now)

    local loopCpu = 0

    -- Clear reused lists (no new tables)
    for i = #normalEligibleTasks, 1, -1 do normalEligibleTasks[i] = nil end
    for i = #mustRunTasks, 1, -1 do mustRunTasks[i] = nil end

    local nN, nM = 0, 0

    for _, task in ipairs(tasksListSpread) do
        local okToRun, od = canRunTask(task, now)
        if okToRun then
            local elapsed = now - task.last_run
            if elapsed >= 2 * task.interval then
                nM = nM + 1
                mustRunTasks[nM] = task
                if LOG_OVERDUE_TASKS then utils.log(string.format("[scheduler] %s hard overdue by %.3fs", task.name, elapsed - 2 * task.interval), "info") end
            elseif elapsed + OVERDUE_TOL >= task.interval then
                nN = nN + 1
                normalEligibleTasks[nN] = task
                if elapsed - task.interval > 0 then
                    if LOG_OVERDUE_TASKS then utils.log(string.format("[scheduler] %s overdue by %.3fs", task.name, elapsed - task.interval), "info") end
                end
            end
        end
    end

    if nM > 1 then table.sort(mustRunTasks, SORT_BY_LAST_RUN_ASC) end
    if nN > 1 then table.sort(normalEligibleTasks, SORT_BY_LAST_RUN_ASC) end

    tasksPerCycle = math.ceil(nonSpreadCount * taskSchedulerPercentage)

    for i = 1, #mustRunTasks do
        local task = mustRunTasks[i]
        local fn = tasks[task.name].wakeup
        if fn then
            local c0 = os.clock()
            local ok, err = pcall(fn, tasks[task.name])
            local c1 = os.clock()
            local dur = c1 - c0
            loopCpu = loopCpu + dur
            if profWanted(task.name) then profRecord(task, dur) end
            if not ok then print(("Error in task %q wakeup (must-run): %s"):format(task.name, err)) end
        end
        task.last_run = now
    end

    local n = math.min(tasksPerCycle, #normalEligibleTasks)
    for i = 1, n do
        local task = normalEligibleTasks[i]
        local fn = tasks[task.name].wakeup
        if fn then
            local c0 = os.clock()
            local ok, err = pcall(fn, tasks[task.name])
            local c1 = os.clock()
            local dur = c1 - c0
            loopCpu = loopCpu + dur
            if profWanted(task.name) then profRecord(task, dur) end
            if not ok then print(("Error in task %q wakeup: %s"):format(task.name, err)) end
        end
        task.last_run = now
    end

    return loopCpu
end
function tasks.wakeup()

    schedulerTick = schedulerTick + 1
    tasks.heartbeat = os.clock()
    local t0 = tasks.heartbeat
    local loopCpu = 0

    tasks.profile.enabled = rfsuite.preferences and rfsuite.preferences.developer and rfsuite.preferences.developer.taskprofiler

    if ethosVersionGood == nil then ethosVersionGood = utils.ethosVersionAtLeast() end
    if not ethosVersionGood then return end

    if tasks.begin == true then
        tasks.begin = false
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

            tasks.load(key, meta)
            tasks._initIndex = tasks._initIndex + 1
            return
        else
            tasks._initState = nil
            tasks._initMetadata = nil
            tasks._initKeys = nil
            tasks._initIndex = 1
            utils.log("All tasks initialized.", "info")
            utils.log("All tasks initialized.", "connect")
            return
        end
    end

    tasks.telemetryCheckScheduler()

    local now = os.clock()


    local cycleFlip = schedulerTick % 2

    if ((rfsuite.app and rfsuite.app.guiIsRunning and not rfsuite.app.escPowerCycleLoader) or not rfsuite.session.isConnected) and rfsuite.session.mspBusy then
        if cycleFlip == 0 then
            if tasks.msp then
                local ok, err = pcall(function() tasks.msp.wakeup() end)
                if not ok then print("[ERROR][tasks.msp.wakeup]", err) end
            end
        else
            if tasks.callback then
                local ok, err = pcall(function() tasks.callback.wakeup() end)
                if not ok then print("[ERROR][tasks.callback.wakeup]", err) end
            end
        end
    else
        if cycleFlip == 0 then
            local ok, cpuOrErr = pcall(runNonSpreadTasks, now)
            if ok then loopCpu = loopCpu + (cpuOrErr or 0) else print("[ERROR][runNonSpreadTasks]", cpuOrErr) end
        else
            local ok, cpuOrErr = pcall(runSpreadTasks, now)
            if ok then loopCpu = loopCpu + (cpuOrErr or 0) else print("[ERROR][runSpreadTasks]", cpuOrErr) end
        end
    end

    if tasks.profile.enabled then
        tasks._lastProfileDump = tasks._lastProfileDump or now
        local dumpEvery = tasks.profile.dumpInterval or 5
        if (now - tasks._lastProfileDump) >= dumpEvery then
            if tasks.dumpProfile then tasks.dumpProfile() end
            tasks._lastProfileDump = now
        end
    end

    local t1 = os.clock()
    rfsuite.performance = rfsuite.performance or {}
    rfsuite.performance.taskLoopCpuMs = loopCpu * 1000.0
    rfsuite.performance.taskLoopTime = (t1 - t0) * 1000.0
end

function tasks.reset()

    for _, task in ipairs(tasksList) do if tasks[task.name].reset then tasks[task.name].reset() end end
    rfsuite.utils.session()
end

function tasks.dumpProfile(opts)
    if not tasks.profile.enabled then return end
    local sortKey = (opts and opts.sort) or "avg"
    local snapshot = {}
    for _, t in ipairs(tasksList) do
        local runs = t.runs or 0
        local avg = runs > 0 and ((t.totalDuration or 0) / runs) or 0
        snapshot[#snapshot + 1] = {name = t.name, last = t.duration or 0, max = t.maxDuration or 0, total = t.totalDuration or 0, runs = runs, avg = avg, interval = t.interval or 0}
    end
    local order = {avg = function(a, b) return a.avg > b.avg end, last = function(a, b) return a.last > b.last end, max = function(a, b) return a.max > b.max end, total = function(a, b) return a.total > b.total end, runs = function(a, b) return a.runs > b.runs end}
    table.sort(snapshot, order[sortKey] or order.avg)

    if tasks.profile.onDump and tasks.profile.onDump(snapshot) then return end

    utils.log("====== Task Profile ======", "info")
    for _, p in ipairs(snapshot) do utils.log(string.format("%-15s | avg:%8.5fs | last:%8.5fs | max:%8.5fs | total:%8.3fs | runs:%6d | int:%4.3fs", p.name, p.avg, p.last, p.max, p.total, p.runs, p.interval), "info") end
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

function tasks.event(widget, category, value, x, y) print("Event:", widget, category, value, x, y) end

function tasks.init()

    tasks.rateMultiplier = tasks.rateMultiplier or 1.0
    currentTelemetrySensor = nil
    tasksPerCycle = 1
    taskSchedulerPercentage = 0.5
    schedulerTick = 0

    ethosVersionGood = nil
    lastSensorName = nil
    lastCheckAt = nil

    tasks.heartbeat = nil
    tasks._justInitialized = false

    tasksList = {}
    tasksListNonSpread = {}
    tasksListSpread = {}
    nonSpreadCount = 0
    tasks._initState = "start"
    tasks._initMetadata = nil
    tasks._initKeys = nil
    tasks._initIndex = 1

    tasks.begin = true

    tlm = system.getSource(SRC_TLM_ACTIVE)

end

function tasks.setTelemetryTypeChanged()
    for _, task in ipairs(tasksList) do if tasks[task.name].setTelemetryTypeChanged then tasks[task.name].setTelemetryTypeChanged() end end
    rfsuite.utils.session()
end

function tasks.read() end

function tasks.write() end

function tasks.unload(name)

    local mod = tasks[name]
    if mod and mod.reset then pcall(mod.reset) end

    if name == "msp" then
        local q = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue
        if q and q.clear then pcall(function() q:clear() end) end
    end

    local removed = nil
    for i, t in ipairs(tasksList) do
        if t.name == name then
            removed = t
            table.remove(tasksList, i)
            break
        end
    end

    if removed then
        local list = removed.spreadschedule and tasksListSpread or tasksListNonSpread
        for i, t in ipairs(list) do
            if t.name == name then
                table.remove(list, i)
                break
            end
        end
        if not removed.spreadschedule then nonSpreadCount = math.max(0, nonSpreadCount - 1) end
    end

    tasks[name] = nil
    utils.log(string.format("[scheduler] Unloaded task '%s'", tostring(name)), "info")
    return true
end

function tasks.load(name, meta)

    if not meta then
        local initPath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/" .. name .. "/init.lua"
        local initFn, err = loadfile(initPath)
        if not initFn then
            utils.log("Failed to load init for " .. name .. ": " .. tostring(err), "info")
            return false
        end
        local m = initFn()
        if type(m) ~= "table" or not m.script then
            utils.log("Invalid config in " .. initPath, "info")
            return false
        end
        meta = m
        meta.init = initPath
    else

        if meta.init then
            local initFn, err = loadfile(meta.init)
            if initFn then
                pcall(initFn)
            else
                utils.log("Failed to run init for " .. name .. ": " .. (err or "unknown"), "info")
            end
        end
    end

    local scriptPath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/" .. name .. "/" .. meta.script
    local fn, loadErr = loadfile(scriptPath)
    if not fn then
        utils.log("Failed to load task script " .. scriptPath .. ": " .. tostring(loadErr), "info")
        return false
    end

    tasks[name] = fn(config)

    local baseInterval = tonumber(meta.interval or 1)
    if baseInterval and baseInterval < 0 then
        utils.log(string.format("[scheduler] Loaded task '%s' (no schedule; interval < 0)", name), "info")
        return true
    end

    local jitter = (math.random() * 0.1)
    local interval = (baseInterval * (tasks.rateMultiplier or 1.0)) + jitter
    local offset = math.random() * interval

    local task = {name = name, interval = interval, baseInterval = baseInterval, jitter = jitter, script = meta.script, linkrequired = meta.linkrequired or false, connected = meta.connected or false, simulatoronly = meta.simulatoronly or false, spreadschedule = meta.spreadschedule or false, last_run = os.clock() - offset, duration = 0, totalDuration = 0, runs = 0, maxDuration = 0}

    table.insert(tasksList, task)
    if task.spreadschedule then
        table.insert(tasksListSpread, task)
    else
        table.insert(tasksListNonSpread, task)
        nonSpreadCount = nonSpreadCount + 1
    end

    utils.log(string.format("[scheduler] Loaded task '%s' (%s)", name, meta.script), "info")
    utils.log(string.format("[scheduler] Loaded task '%s' (%s)", name, meta.script), "connect")
    return true
end

function tasks.reload(name)

    tasks.unload(name)

    local meta = tasks._initMetadata and tasks._initMetadata[name] or nil

    local ok = tasks.load(name, meta)

    if ok then
        local scheduled = false
        for _, t in ipairs(tasksList) do
            if t.name == name then
                scheduled = true;
                break
            end
        end
        if not scheduled and meta and (tonumber(meta.interval or 1) or 1) >= 0 then utils.log(string.format("[scheduler] Reloaded '%s' but it was NOT scheduled; check meta.interval, link/connected flags, or wakeup loop conditions.", name), "warn") end
    else
        utils.log(string.format("[scheduler] Reload of '%s' failed; see earlier compile/init logs.", name), "warn")
    end

    return ok
end

return tasks
