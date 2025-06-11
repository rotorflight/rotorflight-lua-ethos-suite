-- simevent.lua
local simevent = {}

-- adjust this to point at your sensor-script folder
local source = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/sim/sensors/"

-- map each script-name to the handler you want run on *actual* changes
local handlers = {
  simevent_telemetry_state = function(value)
    -- set your telemetry state based on the returned value
    rfsuite.simevent.telemetry_state = (value == 0)
  end,
  -- add more sensor handlers here...
}

-- keep track of the last result, per sensor
local lastValues = {}

-- call this from your own loop whenever you want to poll for changes
function simevent.wakeup()

  if not system.getVersion().simulation then
    return
  end

  for name, handler in pairs(handlers) do
    local path = source .. name .. ".lua"
    -- load and compile the file fresh each time
    local chunk, loadErr = loadfile(path)
    if not chunk then
      print(("sim: could not load %s.lua: %s"):format(name, loadErr))
    else
      -- execute the chunk and capture its returned value
      local ok, result = pcall(chunk)
      if not ok then
        print(("sim: error running %s.lua: %s"):format(name, result))
      elseif result ~= lastValues[name] then
        -- only fire when the returned value actually changes
        lastValues[name] = result
        handler(result)
      end
    end
  end
end

return simevent
