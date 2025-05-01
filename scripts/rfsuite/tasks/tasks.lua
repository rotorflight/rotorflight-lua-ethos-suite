--[[

 * Copyright (C) Rotorflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]] --

if not rfsuite.utils.ethosVersionAtLeast() then
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
local taskMode = rfsuite.preferences.spreadScheduling or true
local taskSchedulerPercentage = 0.2  -- 0.5 = 50%
local tasksPerCycle = nil

rfsuite.session.telemetryTypeChanged = true

local ethosVersionGood = nil  
local telemetryCheckScheduler = os.clock()
local lastTelemetrySensorName = nil

local sportSensor 
local elrsSensor

local telemetryLostTime = nil  



local tlm = system.getSource({category = CATEGORY_SYSTEM_EVENT, member = TELEMETRY_ACTIVE})

if rfsuite.app.moduleList == nil then rfsuite.app.moduleList = rfsuite.utils.findModules() end

-- Modified findTasks to return metadata for caching
function tasks.findTasks()
    local taskdir = "tasks"
    local tasks_path = "tasks/"
    local taskMetadata = {}

    for _, v in pairs(system.listFiles(tasks_path)) do
        if v ~= ".." and v ~= "tasks.lua" then
            local init_path = tasks_path .. v .. '/init.lua'
            local func, err = loadfile(init_path)

            if err then
                rfsuite.utils.log("Error loading " .. init_path .. ": " .. err, "info")
            end

            if func then
                local tconfig = func()
                if type(tconfig) ~= "table" or not tconfig.interval or not tconfig.script then
                    rfsuite.utils.log("Invalid configuration in " .. init_path, "debug")
                else
                    local task = {
                        name = v,
                        interval = tconfig.interval,
                        script = tconfig.script,
                        msp = tconfig.msp,
                        no_link = tconfig.no_link or false,
                        always_run = tconfig.always_run or false,
                        last_run = os.clock()
                    }
                    table.insert(tasksList, task)

                    taskMetadata[v] = {
                        interval = tconfig.interval,
                        script = tconfig.script,
                        msp = tconfig.msp,
                        always_run = tconfig.always_run or false,
                        no_link = tconfig.no_link or false
                    }

                    local script = tasks_path .. v .. '/' .. tconfig.script
                    local fs = io.open(script, "r")
                    if fs then
                        io.close(fs)
                        tasks[v] = assert(loadfile(script))(config)
                    end
                end
            end
        end    
    end

    return taskMetadata
end

function tasks.active()
    if tasks.heartbeat == nil then return false end
    if (os.clock() - tasks.heartbeat) >= 2 then
        tasks.wasOn = true
    else
        tasks.wasOn = false
    end
    if rfsuite.app.triggers.mspBusy == true then return true end
    if (os.clock() - tasks.heartbeat) <= 2 then return true end
    return false
end

function tasks.wakeup()
    if ethosVersionGood == nil then
        ethosVersionGood = rfsuite.utils.ethosVersionAtLeast()
    end

    if not ethosVersionGood then
        return
    end

    if tasks.init == false then
        local cacheFile = "tasks.cache"
        local cachePath = "cache/" .. cacheFile
        local taskMetadata

        if io.open(cachePath, "r") then
            local ok, cached = pcall(dofile, cachePath)
            if ok and type(cached) == "table" then
                taskMetadata = cached
                rfsuite.utils.log("[cache] Loaded task metadata from cache","info")
            else
                rfsuite.utils.log("[cache] Failed to load tasks cache","info")
            end
        end

        if not taskMetadata then
            taskMetadata = tasks.findTasks()
            rfsuite.utils.createCacheFile(taskMetadata, cacheFile)
            rfsuite.utils.log("[cache] Created new tasks cache file","info")
        else
            for name, meta in pairs(taskMetadata) do
                local script = "tasks/" .. name .. "/" .. meta.script
                local module = assert(loadfile(script))(config)

                tasks[name] = module
                table.insert(tasksList, {
                    name = name,
                    interval = meta.interval,
                    script = meta.script,
                    msp = meta.msp,
                    no_link = meta.no_link,
                    always_run = meta.always_run,
                    last_run = os.clock()
                })
            end
        end

        tasks.init = true
        return
    end

    tasks.heartbeat = os.clock()

    local now = os.clock()
    if now - (telemetryCheckScheduler or 0) >= 1 then

        telemetryState = tlm and tlm:state() or false

        if not telemetryState then
            if not telemetryLostTime then
                telemetryLostTime = now  -- Record when telemetry was first lost
            end

            if now - telemetryLostTime >= 2 then  -- Wait for 2 seconds before acting
                rfsuite.utils.log("Telemetry not active for 2 seconds", "info")
                rfsuite.session.telemetryState = false
                rfsuite.session.telemetryType = nil
                rfsuite.session.telemetryTypeChanged = false
                rfsuite.session.telemetrySensor = nil
                lastTelemetrySensorName = nil
                sportSensor = nil
                elrsSensor = nil 
                telemetryCheckScheduler = now    
                rfsuite.tasks.msp.reset()
            end

        else
            telemetryLostTime = nil  -- Reset timer when telemetry returns

            -- always do a lookup.  we cannot cache this
            sportSensor = system.getSource({appId = 0xF101}) 
            elrsSensor = system.getSource({crsfId=0x14, subIdStart=0, subIdEnd=1}) 

            currentTelemetrySensor = sportSensor or elrsSensor or nil
            rfsuite.session.telemetrySensor = currentTelemetrySensor

            if currentTelemetrySensor == nil  then
                rfsuite.session.telemetryState = false
                rfsuite.session.telemetryType = nil
                rfsuite.session.telemetryTypeChanged = false
                rfsuite.session.telemetrySensor = nil
                lastTelemetrySensorName = nil
                sportSensor = nil
                elrsSensor = nil 
                telemetryCheckScheduler = now
            else
                rfsuite.session.telemetryState = true
                rfsuite.session.telemetryType = sportSensor and "sport" or elrsSensor and "crsf" or nil
                rfsuite.session.telemetryTypeChanged = currentTelemetrySensor and (lastTelemetrySensorName ~= currentTelemetrySensor:name()) or false
                lastTelemetrySensorName = currentTelemetrySensor and currentTelemetrySensor:name() or nil    
                telemetryCheckScheduler = now
            end
        end
    end


    -- run all tasks on all cycles
    if taskMode == false then
        for _, task in ipairs(tasksList) do
            if now - task.last_run >= task.interval then
                if tasks[task.name].wakeup then
                    if task.no_link or telemetryState then
                        if task.msp == true then
                            tasks[task.name].wakeup()
                        else
                            if not rfsuite.app.triggers.mspBusy then
                                tasks[task.name].wakeup() 
                            end
                        end
                    end
                    task.last_run = now
                end
            end
        end
    
    else
        
        -- Calculate how many tasks to run per cycle, if not already set
        if not tasksPerCycle then
            local count = 0
            for _, task in ipairs(tasksList) do
                if not task.always_run then
                    count = count + 1
                end
            end
            tasksPerCycle = math.ceil(count * taskSchedulerPercentage)
            rfsuite.utils.log("Tasks per cycle (excluding always_run): " .. tasksPerCycle, "debug")
        end

        -- Helper function to determine if a task can run
        local function canRunTask(task)
            return (task.no_link or telemetryState) and (task.msp == true or not rfsuite.app.triggers.mspBusy)
        end

        -- Run always_run tasks
        for _, task in ipairs(tasksList) do
            if task.always_run and tasks[task.name].wakeup and canRunTask(task) then
                tasks[task.name].wakeup()
                task.last_run = now
            end
        end

        -- Run scheduled tasks
        for i = 1, tasksPerCycle do
            local task = tasksList[taskIndex]
            if task then
                if not task.always_run and now - task.last_run >= task.interval then
                    if tasks[task.name].wakeup and canRunTask(task) then
                        tasks[task.name].wakeup()
                        task.last_run = now
                    end
                end
                taskIndex = (taskIndex % #tasksList) + 1
            end
        end



    end  

end

-- call a reset function on all tasks if it exists
function tasks.reset()
    rfsuite.utils.log("Reset all tasks", "info")
    for _, task in ipairs(tasksList) do
        if tasks[task.name].reset then
            tasks[task.name].reset()
        end
    end    
end

function tasks.event(widget, category, value)
    -- currently does nothing.
    print("Event: " .. widget .. " " .. category .. " " .. value)
end

return tasks