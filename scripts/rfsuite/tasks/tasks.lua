-- Simplified Task Scheduler with single `interval`

local utils = rfsuite.utils
local compiler = rfsuite.compiler.loadfile

local currentTelemetrySensor
local tasksPerCycle = 1
local taskSchedulerPercentage = 0.2

local tasks, tasksList = {}, {}
tasks.heartbeat, tasks.init, tasks.wasOn = nil, true, false
rfsuite.session.telemetryTypeChanged = true

local ethosVersionGood = nil
local telemetryCheckScheduler = rfsuite.clock
local lastTelemetrySensorName, sportSensor, elrsSensor = nil, nil, nil

local usingSimulator = system.getVersion().simulation

local tlm = system.getSource({ category = CATEGORY_SYSTEM_EVENT, member = TELEMETRY_ACTIVE })

function tasks.initialize()
    local cacheFile, cachePath = "tasks.lua", "cache/tasks.lua"
    local taskMetadata

    if io.open(cachePath, "r") then
        local ok, cached = pcall(rfsuite.compiler.dofile, cachePath)
        if ok and type(cached) == "table" then
            taskMetadata = cached
            utils.log("[cache] Loaded task metadata from cache", "info")
        else
            utils.log("[cache] Failed to load tasks cache", "info")
        end
    end

    if not taskMetadata then
        taskMetadata = tasks.findTasks()
        utils.createCacheFile(taskMetadata, cacheFile)
        utils.log("[cache] Created new tasks cache file", "info")
    else
        for name, meta in pairs(taskMetadata) do
            local script = "tasks/" .. name .. "/" .. meta.script
            local module = assert(compiler(script))(config)
            tasks[name] = module
            table.insert(tasksList, {
                name = name,
                interval = meta.interval or 1,
                script = meta.script,
                spreadschedule = meta.spreadschedule,
                linkrequired = meta.linkrequired or false,
                simulatoronly = meta.simulatoronly or false,
                last_run = rfsuite.clock,
                duration = 0
            })
        end
    end
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

                    local task = {
                        name = dir,
                        interval = tconfig.interval or 1,
                        script = tconfig.script,
                        linkrequired = tconfig.linkrequired or false,
                        spreadschedule = tconfig.spreadschedule or false,
                        simulatoronly = tconfig.simulatoronly or false,                        
                        last_run = rfsuite.clock,
                        duration = 0
                    }
                    table.insert(tasksList, task)

                    taskMetadata[dir] = {
                        interval = task.interval,
                        script = task.script,
                        linkrequired = task.linkrequired,
                        simulatoronly = tconfig.simulatoronly or false,  
                        spreadschedule = task.spreadschedule
                    }
                end
            end
        end
    end
    return taskMetadata
end

function tasks.telemetryCheckScheduler()
    local now = rfsuite.clock

    if now - (telemetryCheckScheduler or 0) >= 0.5 then
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

    local age = rfsuite.clock - tasks.heartbeat
    tasks.wasOn = age >= 2
    if rfsuite.app.triggers.mspBusy or age <= 2 then return true end

    return false
end

function tasks.wakeup()
    rfsuite.clock = os.clock()
    tasks.heartbeat = rfsuite.clock

    if ethosVersionGood == nil then
        ethosVersionGood = utils.ethosVersionAtLeast()
    end
    if not ethosVersionGood then return end

    if tasks.init then
        tasks.init = false
        tasks.initialize()
    end

    tasks.telemetryCheckScheduler()

    local now = rfsuite.clock

    local function canRunTask(task)
        local intervalTicks = task.interval * 20
        local isHighFrequency = intervalTicks < 20  -- Less than 1 second

        local clockDelta = rfsuite.clock - task.last_run
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
                tasks[task.name].wakeup()
                task.last_run = now
            end
        end
    end

    -- Collect eligible tasks
    local eligibleTasks = {}
    for _, task in ipairs(tasksList) do
        if task.spreadschedule and canRunTask(task) then
            local elapsed = now - task.last_run
            if elapsed >= task.interval then
                table.insert(eligibleTasks, task)
            end
        end
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
            tasks[task.name].wakeup()
            task.last_run = now
        end
        table.remove(eligibleTasks, index)
    end
end

function tasks.reset()
    utils.log("Reset all tasks", "info")
    for _, task in ipairs(tasksList) do
        if tasks[task.name].reset then
            tasks[task.name].reset()
        end
    end
end

return tasks
