--[[
 * Copyright (C) Rotorflight Project
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
]]--

local utils = rfsuite.utils
local compiler = rfsuite.compiler.loadfile

if not utils.ethosVersionAtLeast() then return end

local currentTelemetrySensor
local tasksPerCycle = 1              -- Represents the actual number of tasks to run per cycle, computed using: tasksPerCycle = math.ceil(count * taskSchedulerPercentage)
local taskSchedulerPercentage = 0.1  -- Determines how many tasks should be run per wakeup cycle, based on the total number of eligible (non-always-run) tasks.

local tasks, tasksList = {}, {}
tasks.heartbeat, tasks.init, tasks.wasOn = nil, true, false
rfsuite.session.telemetryTypeChanged = true

local ethosVersionGood = nil
local telemetryCheckScheduler = rfsuite.clock
local lastTelemetrySensorName, sportSensor, elrsSensor = nil, nil, nil

local tlm = system.getSource({ category = CATEGORY_SYSTEM_EVENT, member = TELEMETRY_ACTIVE })
if not rfsuite.app.moduleList then
    rfsuite.app.moduleList = utils.findModules()
end

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
                intmax = meta.intmax or 1,
                intmin = meta.intmin or 0,
                script = meta.script,
                priority = meta.priority or 1,
                msp = meta.msp or false,
                no_link = meta.no_link or false,
                always_run = meta.always_run,
                last_run = rfsuite.clock,
                duration = 0
            })
        end
    end
end

function tasks.findTasks()
    local taskPath, taskMetadata = "tasks/", {}

    for _, dir in pairs(system.listFiles(taskPath)) do
        if not dir:match("%.%a+$") then
            local initPath = taskPath .. dir .. "/init.lua"
            local func, err = compiler(initPath)

            if err then
                utils.log("Error loading " .. initPath .. ": " .. err, "info")
            elseif func then
                local tconfig = func()
                if type(tconfig) ~= "table" or not tconfig.intmax or not tconfig.script then
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
                        intmax = tconfig.intmax or 1,
                        intmin = tconfig.intmin or 0,
                        priority = tconfig.priority or 1,
                        script = tconfig.script,
                        msp = tconfig.msp or false,
                        no_link = tconfig.no_link or false,
                        always_run = tconfig.always_run or false,
                        last_run = rfsuite.clock,
                        duration = 0
                    }

                    table.insert(tasksList, task)

                    taskMetadata[dir] = {
                        intmax = task.intmax,
                        intmin = task.intmin,
                        script = task.script,
                        priority = task.priority,
                        msp = task.msp,
                        no_link = task.no_link,
                        always_run = task.always_run
                    }
                end
            end
        end
    end

    return taskMetadata
end

function tasks.active()
    if not tasks.heartbeat then return false end

    local age = rfsuite.clock - tasks.heartbeat
    tasks.wasOn = age >= 2
    if rfsuite.app.triggers.mspBusy or age <= 2 then return true end

    return false
end

function tasks.telemetryCheckScheduler()
    local now = rfsuite.clock

    local function setOffline()
        rfsuite.session = {
            telemetryState = false,
            telemetryType = nil,
            telemetryTypeChanged = false,
            telemetrySensor = nil,
            timer = {},
            onConnect = { high = false, medium = false, low = false },
            toolbox = nil,
            modelPreferences = nil,
            modelPreferencesFile = nil,
            rx = { map = {}, values = {} },
            isConnected = false
        }
        lastTelemetrySensorName, sportSensor, elrsSensor = nil, nil, nil
        telemetryCheckScheduler = now
        rfsuite.tasks.msp.reset()
    end

    if now - (telemetryCheckScheduler or 0) >= 0.5 then
        local telemetryState = tlm and tlm:state() or false
        if rfsuite.simevent.telemetry_state == false and system.getVersion().simulation then
            telemetryState = false
        end

        if not telemetryState then
            setOffline()
        else
            sportSensor = system.getSource({ appId = 0xF101 })
            elrsSensor = system.getSource({ crsfId = 0x14, subIdStart = 0, subIdEnd = 1 })
            currentTelemetrySensor = sportSensor or elrsSensor

            if not currentTelemetrySensor then
                setOffline()
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

function tasks.wakeup()
    rfsuite.clock = os.clock()
    if ethosVersionGood == nil then
        ethosVersionGood = utils.ethosVersionAtLeast()
    end
    if not ethosVersionGood then return end

    local now = rfsuite.clock
    tasks.heartbeat = now

    if tasks.init then
        tasks.init = false
        tasks.initialize()
    end

    tasks.telemetryCheckScheduler()

    if not tasksPerCycle then
        local count = 0
        for _, task in ipairs(tasksList) do
            if not task.always_run then count = count + 1 end
        end
        tasksPerCycle = math.ceil(count * taskSchedulerPercentage)
    end

    local function canRunTask(task)
        return (task.no_link or rfsuite.session.telemetryState) and
               (task.msp or not rfsuite.app.triggers.mspBusy)
    end

    for _, task in ipairs(tasksList) do
        if task.always_run and tasks[task.name].wakeup and canRunTask(task) then
            tasks[task.name].wakeup()
            task.last_run = now
        end
    end

    local overdueTasks, eligibleWeighted = {}, {}

    for _, task in ipairs(tasksList) do
        if not task.always_run and canRunTask(task) then
            local elapsed = now - task.last_run
            if elapsed >= task.intmax then
                table.insert(overdueTasks, task)
            elseif elapsed >= task.intmin then
                for _ = 1, task.priority do
                    table.insert(eligibleWeighted, task)
                end
            end
        end
    end

    for _, task in ipairs(overdueTasks) do
        if tasks[task.name].wakeup then
            tasks[task.name].wakeup()
            task.last_run = now
        end
    end

    local remaining = tasksPerCycle - #overdueTasks
    for _ = 1, math.max(0, remaining) do
        if #eligibleWeighted == 0 then break end
        local index = math.random(1, #eligibleWeighted)
        local task = eligibleWeighted[index]

        if tasks[task.name].wakeup then
            tasks[task.name].wakeup()
            task.last_run = now
        end

        for i = #eligibleWeighted, 1, -1 do
            if eligibleWeighted[i].name == task.name then
                table.remove(eligibleWeighted, i)
            end
        end
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

function tasks.event(widget, category, value)
end

return tasks
