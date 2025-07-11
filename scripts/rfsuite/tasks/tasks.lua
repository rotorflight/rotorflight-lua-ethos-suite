-- Simplified Task Scheduler with single `interval`

local utils = rfsuite.utils
local compiler = rfsuite.compiler.loadfile

local currentTelemetrySensor
local tasksPerCycle = 1
local taskSchedulerPercentage = 0.2

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

local usingSimulator = system.getVersion().simulation

local tlm = system.getSource({ category = CATEGORY_SYSTEM_EVENT, member = TELEMETRY_ACTIVE })

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
    -- string.format: TaskName | interval | offset = last_run offset | next in
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
                        spreadschedule = tconfig.spreadschedule or false,
                        simulatoronly = tconfig.simulatoronly or false,
                        last_run = os.clock() - offset,
                        duration = 0
                    }
                    table.insert(tasksList, task)

                    taskMetadata[dir] = {
                        interval = task.interval,
                        script = task.script,
                        linkrequired = task.linkrequired,
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

    if now - (telemetryCheckScheduler or 0) >= 0.25 then
        local telemetryState = tlm and tlm:state() or false
        if rfsuite.simevent.telemetry_state == false and system.getVersion().simulation then
            telemetryState = false
        end

        if not telemetryState then
            utils.session()
        else
            sportSensor = system.getSource({ appId = 0xF101 })
            elrsSensor = system.getSource({ crsfId = 0x14, subIdStart = 0, subIdEnd = 1 })
            currentTelemetrySensor = sportSensor or elrsSensor

            if not currentTelemetrySensor then
                utils.session()
            else
                rfsuite.session.telemetryState = true
                rfsuite.session.telemetrySensor = currentTelemetrySensor
                rfsuite.session.telemetryType = sportSensor and "sport" or elrsSensor and "crsf" or nil
                rfsuite.session.telemetryTypeChanged = currentTelemetrySensor:name() ~= lastTelemetrySensorName
                lastTelemetrySensorName = currentTelemetrySensor:name()
                telemetryCheckScheduler = now
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

    tasks.heartbeat = os.clock()

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
                    pcall(initFn)  -- run task's init.lua
                else
                    utils.log("Failed to load init for " .. key .. ": " .. (err or "unknown error"), "info")
                end
            end

            local script = "tasks/" .. key .. "/" .. meta.script
            local module = assert(compiler(script))(config)
            tasks[key] = module

            -- we dont insert any tasks that have a interval less than 0
            if meta.interval >= 0 then

                -- add a small drift to de-synchronize fixed intervals
                local baseInterval = meta.interval or 1
                local interval     = baseInterval + (math.random() * 0.1)
                local offset = 0
    
                local jitter = math.random() * interval
                offset = jitter % interval


                table.insert(tasksList, {
                    name = key,
                    interval = interval,
                    script = meta.script,
                    spreadschedule = meta.spreadschedule,
                    linkrequired = meta.linkrequired or false,
                    simulatoronly = meta.simulatoronly or false,
                    last_run = os.clock() - offset,
                    duration = 0
                })
            end

            tasks._initIndex = tasks._initIndex + 1
            return  -- only one task initialized per frame
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

    local function canRunTask(task)
        local intervalTicks = task.interval * 20
        local isHighFrequency = intervalTicks < 20  -- Less than 1 second

        local clockDelta = os.clock() - task.last_run
        local graceFactor = 0.25  -- 25% of the interval as grace for low-frequency tasks

        local overdue
        if isHighFrequency then
            overdue = clockDelta >= intervalTicks
        else
            local graceTicks = intervalTicks * graceFactor
            overdue = clockDelta >= (intervalTicks + graceTicks)
        end

        local priorityTask = task.name == "msp" or task.name == "callback"

        return (not task.linkrequired or rfsuite.session.telemetryState) and
            (priorityTask or overdue or not rfsuite.app.triggers.mspBusy) and
            (not task.simulatoronly or usingSimulator)
    end



    -- Run always-run tasks
    for _, task in ipairs(tasksList) do
        if not task.spreadschedule and tasks[task.name].wakeup and canRunTask(task) then
            local elapsed = now - task.last_run
            if elapsed >= task.interval then
                local fn = tasks[task.name].wakeup
                if fn then
                local ok, err = pcall(fn, tasks[task.name])
                    if not ok then
                        print(("Error in task %q wakeup: %s"):format(task.name, err))
                    end
                end              
                task.last_run = now
            end
        end
    end

    -- Collect eligible spread tasks
    local eligibleTasks = {}
    if not skipSpread then
        for _, task in ipairs(tasksList) do
            if task.spreadschedule and canRunTask(task) then
                local elapsed = now - task.last_run
                if elapsed >= task.interval then
                    table.insert(eligibleTasks, task)
                end
            end
        end
    else
        utils.log("Spread-scheduled tasks skipped due to active MSP or callback", "info")
    end

    -- Determine how many tasks to run
    local count = 0
    for _, task in ipairs(tasksList) do
        if not task.spreadschedule then count = count + 1 end
    end
    tasksPerCycle = math.ceil(count * taskSchedulerPercentage)

    -- Run a random selection of eligible tasks
    for i = 1, math.min(tasksPerCycle, #eligibleTasks) do
        local index = math.random(1, #eligibleTasks)
        local task = eligibleTasks[index]
        if tasks[task.name].wakeup then
            local fn = tasks[task.name].wakeup
            if fn then
            local ok, err = pcall(fn, tasks[task.name])
                if not ok then
                    print(("Error in task %q wakeup: %s"):format(task.name, err))
                end
            end
            -- schedule next run with per-run jitter on spread-scheduled tasks
            local jitterScale = 0.2
            -- ±20% of the interval
            local jitter = (math.random() * 2 - 1) * task.interval * jitterScale
            task.last_run = now + jitter

        end
        table.remove(eligibleTasks, index)
    end
end

function tasks.reset()
    --utils.log("Reset all tasks", "info")
    for _, task in ipairs(tasksList) do
        if tasks[task.name].reset then
            tasks[task.name].reset()
        end
    end
end

return tasks
