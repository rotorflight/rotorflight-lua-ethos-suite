-- Tools -> Diagnostics -> Info page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local common = requireModule("app/diagnostics_common.lua")
local buildInfo = requireModule("lib/build_info.lua")
local bgtaskStatus = requireModule("lib/bgtask_status.lua")

local PAGE_TITLE = "@i18n(app.modules.diagnostics.name)@ / @i18n(app.modules.info.name)@"
local SUPPORTED_MSP = "12.09+"
local REFRESH_INTERVAL = 1.0
local STATE_TEXT = {
  running = "@i18n(app.modules.info.bgtask_running)@",
  stale = "@i18n(app.modules.info.bgtask_stale)@",
  none = "-",
}

local function ethosVersion()
  if not system or not system.getVersion then return "-" end
  local v = system.getVersion() or {}
  if v.version then return tostring(v.version) end
  local major = v.major or v.majorVersion
  local minor = v.minor or v.minorVersion
  local rev = v.revision or v.patch or v.revisionNumber
  if major and minor and rev then
    return string.format("%s.%s.%s", major, minor, rev)
  end
  return "-"
end

local function simulationText()
  if not system or not system.getVersion then return "-" end
  local v = system.getVersion() or {}
  if v.simulation == nil then return "-" end
  return v.simulation and "ON" or "OFF"
end

local function open(opts)
  common.openReadOnlyPage(opts, PAGE_TITLE, function(ctx)
    local fields = {
      suite = common.addValueLine("@i18n(app.modules.info.version)@", buildInfo.versionString()),
      ethos = common.addValueLine("@i18n(app.modules.info.ethos_version)@", ethosVersion()),
      rf = common.addValueLine("@i18n(app.modules.info.rf_version)@", "-"),
      fc = common.addValueLine("@i18n(app.modules.info.fc_version)@", "-"),
      msp = common.addValueLine("@i18n(app.modules.info.msp_version)@", SUPPORTED_MSP),
      transport = common.addValueLine("@i18n(app.modules.info.msp_transport)@", "-"),
      supported = common.addValueLine("@i18n(app.modules.info.supported_versions)@", SUPPORTED_MSP),
      simulation = common.addValueLine("@i18n(app.modules.info.simulation)@", simulationText()),
      craft = common.addValueLine("@i18n(app.modules.diagnostics.craft_name)@", "-"),
      mcu = common.addValueLine("@i18n(app.modules.diagnostics.mcu_id)@", "-"),
      bgtask = common.addValueLine("@i18n(app.modules.info.bgtask_name)@", STATE_TEXT.none),
      heartbeat = common.addValueLine("@i18n(app.modules.info.bgtask_heartbeat)@", "-"),
      revivals = common.addValueLine("@i18n(app.modules.info.bgtask_revivals)@", "-"),
    }

    local function update(session)
      common.updateField(fields.rf, session.rfVersion)
      common.updateField(fields.fc, session.fcVersion)
      common.updateField(fields.transport, session.mspTransport and string.upper(session.mspTransport) or nil)
      common.updateField(fields.craft, session.craftName)
      common.updateField(fields.mcu, session.mcuId)
    end

    -- The background task's heartbeat. The last text written to each field is
    -- kept, so a field is only retexted when its value changes.
    local status = nil
    local lastRefresh = nil
    local shown = {}

    local function setText(key, field, text)
      if shown[key] == text then return end
      shown[key] = text
      common.updateField(field, text)
    end

    local function refreshStatus(force)
      local now = os.clock()
      if not force and lastRefresh and (now - lastRefresh) < REFRESH_INTERVAL then return end
      lastRefresh = now
      setText("bgtask", fields.bgtask, STATE_TEXT[bgtaskStatus.state(status, now)])
      setText("heartbeat", fields.heartbeat, bgtaskStatus.heartbeatText(status, now))
      setText("revivals", fields.revivals, bgtaskStatus.revivalsText(status))
    end

    update(ctx.session)
    refreshStatus(true)
    return {
      onSession = update,
      onReload = function()
        update(ctx.session)
        refreshStatus(true)
      end,
      -- Ethos only calls this on its own schedule, so the age of the heartbeat
      -- keeps counting up, and a stalled task turns stale, even with no event.
      wakeup = function() refreshStatus(false) end,
      topics = {
        ["task.status"] = function(snapshot)
          status = snapshot
          refreshStatus(true)
        end,
      },
    }
  end)
end

return {open = open}
