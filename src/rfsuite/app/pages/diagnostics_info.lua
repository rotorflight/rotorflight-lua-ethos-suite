-- Tools -> Diagnostics -> Info page.

local requireModule = assert(loadfile("lib/require.lua"))()
local common = requireModule("app/diagnostics_common.lua")
local buildInfo = requireModule("lib/build_info.lua")

local PAGE_TITLE = "@i18n(app.modules.diagnostics.name)@ / @i18n(app.modules.info.name)@"
local SUPPORTED_MSP = "12.09+"

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
    }

    local function update(session)
      common.updateField(fields.rf, session.rfVersion)
      common.updateField(fields.fc, session.fcVersion)
      common.updateField(fields.transport, session.mspTransport and string.upper(session.mspTransport) or nil)
      common.updateField(fields.craft, session.craftName)
      common.updateField(fields.mcu, session.mcuId)
    end

    update(ctx.session)
    return {
      onSession = update,
      onReload = function() update(ctx.session) end,
    }
  end)
end

return {open = open}
