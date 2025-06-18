--[[

 * Copyright (C) Rotorflight Project
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html

]] --

local utils = rfsuite.utils
local compiler = rfsuite.compiler.loadfile

if not utils.ethosVersionAtLeast() then
    return
end

local arg = {...}
local config = arg[1]
local currentTelemetrySensor

local tasks = {}
tasks.heartbeat = nil
tasks.init = false
tasks.wasOn = false

local tasksList = {}

local taskIndex = 1
local taskSchedulerPercentage = 0.2
local tasksPerCycle = nil

rfsuite.session.telemetryTypeChanged = true

local ethosVersionGood = nil  
local telemetryCheckScheduler = rfsuite.clock
local lastTelemetrySensorName = nil

local sportSensor 
local elrsSensor

local tlm = system.getSource({category = CATEGORY_SYSTEM_EVENT, member = TELEMETRY_ACTIVE})

if rfsuite.app.moduleList == nil then rfsuite.app.moduleList = utils.findModules() end

function tasks.findTasks()
    local taskdir = "tasks"
    local tasks_path = "tasks/"
    local taskMetadata = {}

    for _, v in pairs(system.listFiles(tasks_path)) do
        if v ~= ".." and v ~= "." and not v:match("%.%a+$") then
            local init_path = tasks_path .. v .. '/init.lua'
            local func, err = compiler(init_path)

            if err then
                utils.log("Error loading " .. init_path .. ": " .. err, "info")
            end

            if func then
                local tconfig = func()
                if type(tconfig) ~= "table" or not tconfig.intmax or not tconfig.script then
                    utils.log("Invalid configuration in " .. init_path, "debug")
                else
                    local task = {
                        name = v,
                        intmax = tconfig.intmax or 1,
                        intmin = tconfig.intmin or 0,
                        priority = tconfig.priority or 1,
                        script = tconfig.script,
                        msp = tconfig.msp or false,
                        no_link = tconfig.no_link or false,
                        always_run = tconfig.always_run or false,
                        last_run = rfsuite.clock
                    }
                    table.insert(tasksList, task)

                    taskMetadata[v] = {
                        intmax = tconfig.intmax or 1,
                        intmin = tconfig.intmin or 0,
                        script = tconfig.script,
                        priority = tconfig.priority or 1,
                        msp = tconfig.msp or false,
                        always_run = tconfig.always_run or false,
                        no_link = tconfig.no_link or false
                    }

                    local script = tasks_path .. v .. '/' .. tconfig.script
                    local fn, loadErr = compiler(script)
                    if fn then
                        tasks[v] = fn(config)
                    else
                        utils.log("Failed to load task script " .. script .. ": " .. loadErr, "warn")
                    end
                end
            end
        end    
    end

    return taskMetadata
end

function tasks.active()
    if tasks.heartbeat == nil then return false end
    if (rfsuite.clock - tasks.heartbeat) >= 2 then
        tasks.wasOn = true
    else
        tasks.wasOn = false
    end
    if rfsuite.app.triggers.mspBusy == true then return true end
    if (rfsuite.clock - tasks.heartbeat) <= 2 then return true end
    return false
end

local function setOffline()
    rfsuite.session.telemetryState = false
    rfsuite.session.telemetryType = nil
    rfsuite.session.telemetryTypeChanged = false
    rfsuite.session.telemetrySensor = nil
    rfsuite.session.timer = {}
    rfsuite.session.onConnect.high = false
    rfsuite.session.onConnect.low = false
    rfsuite.session.onConnect.medium = false
    rfsuite.session.toolbox = nil
    rfsuite.session.modelPreferences = nil
    rfsuite.session.modelPreferencesFile = nil
    rfsuite.session.rx.map = {}
    rfsuite.session.rx.values = {}   
    lastTelemetrySensorName = nil
    sportSensor = nil
    elrsSensor = nil 
    telemetryCheckScheduler = now    
    rfsuite.session.isConnected = false
    rfsuite.tasks.msp.reset()
end

function tasks.wakeup()
    rfsuite.clock = os.clock()
    if ethosVersionGood == nil then
        ethosVersionGood = utils.ethosVersionAtLeast()
    end
    if not ethosVersionGood then return end

    if tasks.init == false then
        local cacheFile = "tasks.lua"
        local cachePath = "cache/" .. cacheFile
        local taskMetadata

        if io.open(cachePath, "r") then
            local ok, cached = pcall(rfsuite.compiler.dofile, cachePath)
            if ok and type(cached) == "table" then
                taskMetadata = cached
                utils.log("[cache] Loaded task metadata from cache","info")
            else
                utils.log("[cache] Failed to load tasks cache","info")
            end
        end

        if not taskMetadata then
            taskMetadata = tasks.findTasks()
            utils.createCacheFile(taskMetadata, cacheFile)
            utils.log("[cache] Created new tasks cache file","info")
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
                    last_run = rfsuite.clock
                })
            end
        end

        tasks.init = true
        return
    end

    tasks.heartbeat = rfsuite.clock
    local now = rfsuite.clock

    if now - (telemetryCheckScheduler or 0) >= 0.5 then
        telemetryState = tlm and tlm:state() or false    
        if (rfsuite.simevent.telemetry_state == false and system.getVersion().simulation) then
            telemetryState = false 
        end
        if not telemetryState  then
            setOffline()
        else
            telemetryLostTime = nil
            sportSensor = system.getSource({appId = 0xF101}) 
            elrsSensor = system.getSource({crsfId=0x14, subIdStart=0, subIdEnd=1}) 
            currentTelemetrySensor = sportSensor or elrsSensor or nil
            rfsuite.session.telemetrySensor = currentTelemetrySensor
            if currentTelemetrySensor == nil  then
                setOffline()
            else
                rfsuite.session.telemetryState = true
                rfsuite.session.telemetryType = sportSensor and "sport" or elrsSensor and "crsf" or nil
                rfsuite.session.telemetryTypeChanged = currentTelemetrySensor and (lastTelemetrySensorName ~= currentTelemetrySensor:name()) or false
                lastTelemetrySensorName = currentTelemetrySensor and currentTelemetrySensor:name() or nil    
                telemetryCheckScheduler = now
            end
        end
    end

    if not tasksPerCycle then
        local count = 0
        for _, task in ipairs(tasksList) do
            if not task.always_run then count = count + 1 end
        end
        tasksPerCycle = math.ceil(count * taskSchedulerPercentage)
    end

    local function canRunTask(task)
        return (task.no_link or telemetryState) and (task.msp == true or not rfsuite.app.triggers.mspBusy)
    end

    for _, task in ipairs(tasksList) do
        if task.always_run and tasks[task.name].wakeup and canRunTask(task) then
            tasks[task.name].wakeup()
            task.last_run = now
        end
    end

    local overdueTasks = {}
    local eligibleWeighted = {}

    for _, task in ipairs(tasksList) do
        if not task.always_run and canRunTask(task) then
            local elapsed = now - task.last_run
            if elapsed >= (task.intmax or 1e9) then
                table.insert(overdueTasks, task)
            elseif elapsed >= (task.intmin or 0) then
                for _ = 1, (task.priority or 1) do
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

    local remainingSlots = tasksPerCycle - #overdueTasks
    for i = 1, math.max(0, remainingSlots) do
        if #eligibleWeighted == 0 then break end
        local index = math.random(1, #eligibleWeighted)
        local task = eligibleWeighted[index]
        if tasks[task.name].wakeup then
            tasks[task.name].wakeup()
            task.last_run = now
        end
        for j = #eligibleWeighted, 1, -1 do
            if eligibleWeighted[j].name == task.name then
                table.remove(eligibleWeighted, j)
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
    print("Event: " .. widget .. " " .. category .. " " .. value)
end

return tasks