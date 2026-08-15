-- Tools -> Diagnostics -> Status page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local common = requireModule("app/diagnostics_common.lua")

local PAGE_TITLE = "@i18n(app.modules.diagnostics.name)@ / @i18n(app.modules.rfstatus.name)@"

local function moduleEnabled()
  if not model or not model.getModule then return nil end
  local m0 = model.getModule(0)
  local m1 = model.getModule(1)
  return (m0 and m0.enable and m0:enable()) or (m1 and m1.enable and m1:enable()) or false
end

local function haveMspSensor()
  if not system or not system.getSource then return nil end
  local sportSensor = system.getSource({appId = 0xF101})
  local elrsSensor = system.getSource({crsfId = 0x14, subIdStart = 0, subIdEnd = 1})
  return sportSensor ~= nil or elrsSensor ~= nil
end

local function memoryText()
  if not system or not system.getMemoryUsage then return "-" end
  local mem = system.getMemoryUsage() or {}
  return common.formatBytes(mem.ramAvailable or 0)
end

local function luaMemoryText()
  return string.format("%.1f kB", collectgarbage("count"))
end

local function open(opts)
  common.openReadOnlyPage(opts, PAGE_TITLE, function(ctx)
    local fields = {
      memory = common.addValueLine("@i18n(app.modules.diagnostics.memory_free)@", memoryText()),
      luaMemory = common.addValueLine("@i18n(app.modules.diagnostics.lua_memory)@", luaMemoryText()),
      rfModule = common.addValueLine("@i18n(app.modules.rfstatus.rfmodule)@", "-"),
      mspSensor = common.addValueLine("@i18n(app.modules.rfstatus.mspsensor)@", "-"),
      connected = common.addValueLine("@i18n(app.modules.rfstatus.fblconnected)@", "-"),
      api = common.addValueLine("@i18n(app.modules.rfstatus.apiversion)@", "@i18n(app.modules.rfstatus.ok)@"),
    }

    local function update(session)
      common.updateField(fields.memory, memoryText())
      common.updateField(fields.luaMemory, luaMemoryText())
      common.updateStatus(fields.rfModule, moduleEnabled())
      common.updateStatus(fields.mspSensor, haveMspSensor())
      common.updateStatus(fields.connected, session.connected)
      common.updateStatus(fields.api, true)
    end

    update(ctx.session)
    return {
      onSession = update,
      wakeup = function() update(ctx.session) end,
    }
  end)
end

return {open = open}
