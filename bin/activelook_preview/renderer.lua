-- Desktop adapter: run the actual suite widget with a recording glasses API.
return function(root, widgetSource)
  local handlers, definition, widget, frame = {}, nil, nil, {commands = {}}
  local clock, bitmap, generation, selected = 0, nil, 0, nil
  local settings = {activelook = {}, general = {}, events = {}}
  local config = assert(loadfile(root .. "lib/activelook_config.lua"))()
  local modules = {
    ["lib/activelook_config.lua"] = config,
    ["lib/activelook_alerts.lua"] = assert(loadfile(root .. "lib/activelook_alerts.lua"))(),
    ["lib/engine_type.lua"] = assert(loadfile(root .. "lib/engine_type.lua"))(),
    ["widgets/dashboard/flightmode.lua"] = assert(loadfile(root .. "widgets/dashboard/flightmode.lua"))(),
    ["lib/bus.lua"] = {
      subscribe = function(topic, handler) handlers[topic] = handler; return handler end,
      unsubscribe = function(topic) handlers[topic] = nil end,
    },
    ["lib/settings_store.lua"] = {
      load = function() return settings end,
      activelook = function(value) return config.withDefaults(value.activelook) end,
      temperatureUnit = function(value) return tonumber(value.general.temperature_unit) or 0 end,
    },
  }
  package.loaded["rfsuite.lib.require"] = function(path) return assert(modules[path], path) end
  os.clock = function() return clock end
  system = {registerGlassesWidget = function(value) definition = value end, getSource = function() return nil end}
  glasses = {
    getWindowSize = function() return 304, 256 end,
    createLayout = function()
      return {clearAndDisplayExtended = function(self, args)
        frame = args; bitmap = nil; generation = generation + 1
      end}
    end,
    bitmap = function(x, y, id) bitmap = {x = x, y = y, id = id} end,
  }
  assert(load(widgetSource, "@" .. root .. "widgets/activelook.lua"))().init()
  widget = definition.create()
  return function(nextSettings, snapshot, preview, now, changed)
    clock = now
    if changed then settings = nextSettings; handlers["settings.update"](settings) end
    if preview ~= selected then
      selected = preview
      handlers["activelook.control"]({previewMode = preview})
    end
    handlers["session.update"](snapshot)
    definition.wakeup(widget)
    return {commands = frame.commands, bitmap = bitmap, generation = generation,
      phase = widget.flightmode.current, overlay = widget.alertState.previewMode or (widget.alertState.active and widget.alertState.active.kind),
      enabled = widget.settings.enabled, fonts = {[1] = 24, [2] = 38, [3] = 64, [4] = 75, [5] = 82}}
  end
end
