-- Tools -> Diagnostics -> Serial Rx (Backup) page.
--
-- Live link/channel readout for the backup-RX input (see app/pages/ports.lua's
-- RX_INPUT_BACKUP function and lib/msp_rx_input_backup_status.lua), for
-- bench-testing that a backup satellite is wired/bound correctly and to watch
-- it take over when the main RX link is pulled. Provider-selectable in
-- firmware (rx_input_backup_provider) - NONE/SBUS/FBUS/FPORT/FPORT2/EXBUS/
-- CRSF - the Protocol line below is already generic.
--
-- Read-only, so this uses app/diagnostics_common.lua's openReadOnlyPage()
-- helper like diagnostics_fblstatus.lua does. Refreshed faster than that
-- page (0.3s vs 2s) since the whole point here is watching values change
-- live during a bench test -- with the setFieldValue-style change-detection
-- cache diagnostics_elrs_link.lua uses for its own 0.2s refresh, so a
-- steady/unchanged value doesn't re-touch the widget every tick.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local common = requireModule("app/diagnostics_common.lua")
local rxInputBackupStatus = requireModule("lib/msp_rx_input_backup_status.lua")

local PAGE_TITLE = "@i18n(app.modules.diagnostics.name)@ / @i18n(app.modules.rx_input_backup_status.name)@"

local T = {
  protocol = "@i18n(app.modules.rx_input_backup_status.protocol)@",
  link = "@i18n(app.modules.rx_input_backup_status.link)@",
  linkUp = "@i18n(app.modules.rx_input_backup_status.link_up)@",
  linkDown = "@i18n(app.modules.rx_input_backup_status.link_down)@",
  activeSource = "@i18n(app.modules.rx_input_backup_status.active_source)@",
  activeMain = "@i18n(app.modules.rx_input_backup_status.active_main)@",
  activeBackup = "@i18n(app.modules.rx_input_backup_status.active_backup)@",
  notConfigured = "@i18n(app.modules.rx_input_backup_status.not_configured)@",
  channel = "@i18n(app.modules.rx_input_backup_status.channel)@",
}

-- Keep in sync with rotorflight-firmware's cli/settings.c
-- lookupTableRxInputBackupProvider[] (same order, NONE=0 first).
local PROVIDER_NAMES = {
  [0] = "NONE",
  [1] = "SBUS",
  [2] = "FBUS",
  [3] = "FPORT",
  [4] = "FPORT2",
  [5] = "EXBUS",
  [6] = "CRSF",
}

local REFRESH_INTERVAL_SECONDS = 0.3

-- RX_INPUT_BACKUP_MAX_CHANNEL (drivers/rx_input_backup.h) -- the channel row
-- count is fixed at page-build time, so pre-build the maximum and only as
-- many rows as the firmware actually reports get real values; the rest stay "-".
local MAX_CHANNELS = 18

local function open(opts)
  common.openReadOnlyPage(opts, PAGE_TITLE, function(ctx)
    local fieldCache = {}

    local function setFieldValue(field, value)
      if not field or fieldCache[field] == value then return end
      fieldCache[field] = value
      common.updateField(field, value)
    end

    local protocolField = common.addValueLine(T.protocol, "-")
    local linkField = common.addValueLine(T.link, "-")
    local activeField = common.addValueLine(T.activeSource, "-")

    local channelFields = {}
    for i = 1, MAX_CHANNELS do
      channelFields[i] = common.addValueLine(T.channel .. " " .. i, "-")
    end

    local pending = false

    local function applyStatus(data)
      if not data.enabled then
        setFieldValue(protocolField, "-")
        setFieldValue(linkField, T.notConfigured)
        if linkField.color then linkField:color(nil) end
        setFieldValue(activeField, "-")
      else
        setFieldValue(protocolField, PROVIDER_NAMES[data.provider] or tostring(data.provider))

        setFieldValue(linkField, data.linkUp and T.linkUp or T.linkDown)
        if linkField.color then linkField:color(data.linkUp and GREEN or RED) end

        local isBackup = data.activeSource == "backup"
        setFieldValue(activeField, isBackup and T.activeBackup or T.activeMain)
        if activeField.color then activeField:color(isBackup and RED or GREEN) end
      end

      for i = 1, MAX_CHANNELS do
        local value = data.channels and data.channels[i]
        setFieldValue(channelFields[i], value ~= nil and tostring(value) or "-")
      end
    end

    local function finish()
      pending = false
      if ctx.header then ctx.header.setReloadEnabled(true) end
    end

    local function poll()
      if ctx.isDisposed() or pending then return end
      pending = true
      if ctx.header then ctx.header.setReloadEnabled(false) end
      bus.publish("msp.request", rxInputBackupStatus.buildReadMessage(function(data)
        if not ctx.isDisposed() then applyStatus(data) end
        finish()
      end, finish))
    end

    if ctx.header then
      ctx.header.setReloadEnabled(true)
    end
    poll()

    local lastPoll = 0

    return {
      onReload = poll,
      wakeup = function()
        local now = os.clock()
        if now - lastPoll < REFRESH_INTERVAL_SECONDS then return end
        lastPoll = now
        poll()
      end,
    }
  end)
end

return {open = open}
