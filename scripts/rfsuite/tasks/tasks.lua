-- Optimized Task Scheduler (same functionality, lower CPU/RAM)

local utils              = rfsuite.utils
local compiler           = rfsuite.compiler.loadfile
local dofile_cached      = rfsuite.compiler.dofile
local ethosVersionAtLeast= utils.ethosVersionAtLeast
local createCacheFile    = utils.createCacheFile
local keys               = utils.keys
local session            = utils.session

local system_getVersion  = system.getVersion
local system_listFiles   = system.listFiles
local system_getSource   = system.getSource

local R                  = math.random
local clock              = os.clock
local fmt                = string.format

local CATEGORY_SYSTEM_EVENT = CATEGORY_SYSTEM_EVENT
local TELEMETRY_ACTIVE      = TELEMETRY_ACTIVE

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
local telemetryCheckAt = clock()
local lastTelemetrySensorName, sportSensor, elrsSensor = nil, nil, nil

local usingSimulator = system_getVersion().simulation

local tlm = system_getSource({ category = CATEGORY_SYSTEM_EVENT, member = TELEMETRY_ACTIVE })

-- scratch tables reused every tick to avoid allocations
local scratchMustRun, scratchNormal = {}, {}

-- cached counts updated only when tasksList mutates
local nonSpreadCount = 0

local function recountNonSpread()
  local n = 0
  for i = 1, #tasksList do
    if not tasksList[i].spreadschedule then n = n + 1 end
  end
  nonSpreadCount = n
end

-- Returns true if the task is active (based on recent run time or triggers)
function tasks.isTaskActive(name)
  for i = 1, #tasksList do
    local t = tasksList[i]
    if t.name == name then
      local age = clock() - t.last_run
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
  local base = (hash % (interval * 1000)) / 1000
  local jitter = R() * interval
  return (base + jitter) % interval
end

-- Print a human-readable schedule of all tasks
function tasks.dumpSchedule()
  local now = clock()
  utils.log("====== Task Schedule Dump ======", "info")
  for i = 1, #tasksList do
    local t = tasksList[i]
    local next_run = t.last_run + t.interval
    local in_secs  = next_run - now
    utils.log(fmt("%-15s | interval: %4.1fs | last_run: %8.2f | next in: %6.2fs",
      t.name, t.interval, t.last_run, in_secs), "info")
  end
  utils.log("================================", "info")
end

function tasks.initialize()
  local cacheFile, cachePath = "tasks.lua", "cache/tasks.lua"
  local f = io.open(cachePath, "r")
  if f then f:close() end
  if f then
    local ok, cached = pcall(dofile_cached, cachePath)
    if ok and type(cached) == "table" then
      tasks._initMetadata = cached
      utils.log("[cache] Loaded task metadata from cache", "info")
    else
      utils.log("[cache] Failed to load tasks cache", "info")
    end
  end
  if not tasks._initMetadata then
    local taskPath, taskMetadata = "tasks/", {}
    for _, dir in pairs(system_listFiles(taskPath)) do
      if dir ~= "." and dir ~= ".." and not dir:match("%.%a+$") then
        local initPath = taskPath .. dir .. "/init.lua"
        local func, err = compiler(initPath)
        if err then
          utils.log("Error loading " .. initPath .. ": " .. err, "info")
        elseif func then
          local tconfig = func()
          if type(tconfig) == "table" and tconfig.interval and tconfig.script then
            taskMetadata[dir] = {
              interval      = tconfig.interval,
              script        = tconfig.script,
              linkrequired  = tconfig.linkrequired or false,
              connected     = tconfig.connected or false,
              simulatoronly = tconfig.simulatoronly or false,
              spreadschedule= tconfig.spreadschedule or false,
              init          = initPath
            }
          end
        end
      end
    end
    tasks._initMetadata = taskMetadata
    createCacheFile(taskMetadata, cacheFile)
    utils.log("[cache] Created new tasks cache file", "info")
  end
  tasks._initKeys  = keys(tasks._initMetadata)
  tasks._initState = "loadNextTask"
end

function tasks.findTasks()
  local taskPath, taskMetadata = "tasks/", {}
  for _, dir in pairs(system_listFiles(taskPath)) do
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

          local baseInterval = tconfig.interval or 1
          local interval     = baseInterval + (R() * 0.1)
          local offset       = taskOffset(dir, interval)

          local mod = tasks[dir]
          local record = {
            name          = dir,
            interval      = interval,
            script        = tconfig.script,
            linkrequired  = tconfig.linkrequired or false,
            connected     = tconfig.connected or false,
            spreadschedule= tconfig.spreadschedule or false,
            simulatoronly = tconfig.simulatoronly or false,
            last_run      = clock() - offset,
            duration      = 0,
            mod           = mod
          }
          tasksList[#tasksList + 1] = record

          taskMetadata[dir] = {
            interval      = record.interval,
            script        = record.script,
            linkrequired  = record.linkrequired,
            connected     = record.connected,
            simulatoronly = record.simulatoronly,
            spreadschedule= record.spreadschedule
          }
        end
      end
    end
  end
  recountNonSpread()
  return taskMetadata
end

function tasks.telemetryCheckScheduler()
  local now = clock()
  if now - (telemetryCheckAt or 0) < 2 then return end

  local telemetryState = tlm and tlm:state() or false
  if rfsuite.simevent.telemetry_state == false and system_getVersion().simulation then
    telemetryState = false
  end

  if not telemetryState then
    session()
  else
    sportSensor = system_getSource({ appId = 0xF101 })
    elrsSensor  = system_getSource({ crsfId = 0x14, subIdStart = 0, subIdEnd = 1 })
    currentTelemetrySensor = sportSensor or elrsSensor

    if not currentTelemetrySensor then
      session()
    else
      rfsuite.session.telemetryState  = true
      rfsuite.session.telemetrySensor = currentTelemetrySensor
      rfsuite.session.telemetryType   = sportSensor and "sport" or (elrsSensor and "crsf" or nil)
      local nameNow = currentTelemetrySensor:name()
      rfsuite.session.telemetryTypeChanged = nameNow ~= lastTelemetrySensorName
      lastTelemetrySensorName = nameNow
      telemetryCheckAt = now
    end
  end
end

function tasks.active()
  if not tasks.heartbeat then return false end
  local age = clock() - tasks.heartbeat
  tasks.wasOn = age >= 2
  if rfsuite.app.triggers.mspBusy or age <= 2 then return true end
  return false
end

-- small helpers used in wakeup flow
local function canRunTask(task, now)
  local intervalTicks  = task.interval * 20
  local isHighFreq     = intervalTicks < 20
  local clockDelta     = now - task.last_run
  local graceFactor    = 0.25

  local overdue
  if isHighFreq then
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

local function runNonSpreadTasks(now)
  for i = 1, #tasksList do
    local task = tasksList[i]
    if not task.spreadschedule then
      local mod = task.mod
      local fn  = mod and mod.wakeup
      if fn and canRunTask(task, now) then
        local elapsed = now - task.last_run
        if elapsed >= task.interval then
          local ok, err = pcall(fn, mod)
          if not ok then
            print(("Error in task %q wakeup: %s"):format(task.name, err))
            collectgarbage("collect")
          end
          task.last_run = now
        end
      end
    end
  end
end

local function runSpreadTasks(now)
  -- clear scratch arrays without reallocating
  for i = #scratchMustRun, 1, -1 do scratchMustRun[i] = nil end
  for i = #scratchNormal , 1, -1 do scratchNormal [i] = nil end

  for i = 1, #tasksList do
    local task = tasksList[i]
    if task.spreadschedule and canRunTask(task, now) then
      local elapsed = now - task.last_run
      if elapsed >= 2 * task.interval then
        scratchMustRun[#scratchMustRun + 1] = task
      elseif elapsed >= task.interval then
        scratchNormal[#scratchNormal + 1] = task
      end
    end
  end

  table.sort(scratchMustRun,  function(a, b) return a.last_run < b.last_run end)
  table.sort(scratchNormal ,  function(a, b) return a.last_run < b.last_run end)

  -- derive tasksPerCycle from cached nonSpreadCount (no per-tick recount)
  tasksPerCycle = math.ceil(nonSpreadCount * taskSchedulerPercentage)

  for i = 1, #scratchMustRun do
    local task = scratchMustRun[i]
    local mod, fn = task.mod, task.mod and task.mod.wakeup
    if fn then
      local ok, err = pcall(fn, mod)
      if not ok then
        print(("Error in task %q wakeup (must-run): %s"):format(task.name, err))
        collectgarbage("collect")
      end
    end
    task.last_run = now
  end

  local limit = tasksPerCycle < #scratchNormal and tasksPerCycle or #scratchNormal
  for i = 1, limit do
    local task = scratchNormal[i]
    local mod, fn = task.mod, task.mod and task.mod.wakeup
    if fn then
      local ok, err = pcall(fn, mod)
      if not ok then
        print(("Error in task %q wakeup: %s"):format(task.name, err))
        collectgarbage("collect")
      end
    end
    task.last_run = now
  end
end

function tasks.wakeup()
  schedulerTick = schedulerTick + 1
  tasks.heartbeat = clock()

  if ethosVersionGood == nil then
    ethosVersionGood = ethosVersionAtLeast()
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
        local interval     = baseInterval + (R() * 0.1)
        local offset       = R() * interval
        local record = {
          name          = key,
          interval      = interval,
          script        = meta.script,
          spreadschedule= meta.spreadschedule,
          linkrequired  = meta.linkrequired or false,
          connected     = meta.connected or false,
          simulatoronly = meta.simulatoronly or false,
          last_run      = clock() - offset,
          duration      = 0,
          mod           = module
        }
        tasksList[#tasksList + 1] = record
        recountNonSpread()
      end

      tasks._initIndex = tasks._initIndex + 1
      return
    else
      tasks._initState   = nil
      tasks._initMetadata= nil
      tasks._initKeys    = nil
      tasks._initIndex   = 1
      utils.log("All tasks initialized.", "info")
      return
    end
  end

  tasks.telemetryCheckScheduler()

  local now = clock()
  if (schedulerTick % 2) == 0 then
    runNonSpreadTasks(now)
  else
    runSpreadTasks(now)
  end
end

function tasks.reset()
  -- utils.log("Reset all tasks", "info")
  for i = 1, #tasksList do
    local t = tasksList[i]
    local mod = t.mod
    if mod and mod.reset then
      mod.reset()
    end
  end
  rfsuite.utils.session()
end

return tasks
