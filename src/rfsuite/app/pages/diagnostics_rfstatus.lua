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

local REFRESH_INTERVAL = 1.0

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

    local lastUpdate = 0
    local lastConnected = nil
    local lastApiSupported = nil

    local function update(session, force)
      local now = os.clock()
      local connected = session and session.connected
      local apiSupported = session and session.apiVersionSupported
      if not force and (now - lastUpdate < REFRESH_INTERVAL) and (connected == lastConnected)
        and (apiSupported == lastApiSupported) then
        return
      end
      lastUpdate = now
      lastConnected = connected
      lastApiSupported = apiSupported

      common.updateField(fields.memory, memoryText())
      common.updateField(fields.luaMemory, luaMemoryText())
      common.updateStatus(fields.rfModule, moduleEnabled())
      common.updateStatus(fields.mspSensor, haveMspSensor())
      common.updateStatus(fields.connected, connected)
      -- The API line is OK only on a live link whose MSP API version the suite supports.
      -- Without a connection it is unknown, not OK (issue #2582).
      local apiOk = connected == true and apiSupported == true
      common.updateField(fields.api, apiOk and "@i18n(app.modules.rfstatus.ok)@" or "-")
      common.setFieldColor(fields.api, apiOk and GREEN or RED)
    end

    update(ctx.session, true)
    return {
      onSession = function(session) update(session, false) end,
      wakeup = function() update(ctx.session, false) end,
    }
  end)
end

return {open = open}
