-- Tools -> Diagnostics -> FBL Status page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local common = requireModule("app/diagnostics_common.lua")
local mspStatus = requireModule("lib/msp_status.lua")
local dataflashSummary = requireModule("lib/msp_dataflash_summary.lua")
local armingFlags = requireModule("lib/arming_flags.lua")

local PAGE_TITLE = "@i18n(app.modules.diagnostics.name)@ / @i18n(app.modules.fblstatus.name)@"

-- Heading above the per-flag lines. The names themselves need no prefix: the
-- indent and the heading carry the hierarchy, and a bullet glyph would be a
-- font gamble -- U+26A0 and the U+25xx triangles were measured blank on this
-- platform (see #2391), and U+2022 was never swept.
local ARMING_DETAIL_HEADING = "@i18n(app.modules.fblstatus.arming_flags_active_list)@"
local ARMING_DETAIL_INDENT = 12

local function percentTenths(value)
  if value == nil then return "-" end
  return string.format("%.1f%%", (tonumber(value) or 0) / 10)
end

local function dataflashText(summary)
  if not summary then return "-" end
  if not armingFlags.hasBit(summary.flags, 1) then return "@i18n(app.modules.fblstatus.unsupported)@" end
  local free = math.max((summary.total or 0) - (summary.used or 0), 0)
  return common.formatBytes(free)
end

local function open(opts)
  common.openReadOnlyPage(opts, PAGE_TITLE, function(ctx)
    local fields = {
      arming = common.addValueLine("@i18n(app.modules.fblstatus.arming_flags)@", "-"),
      dataflash = common.addValueLine("@i18n(app.modules.fblstatus.dataflash_free_space)@", "-"),
      realTimeLoad = common.addValueLine("@i18n(app.modules.fblstatus.real_time_load)@", "-"),
      cpuLoad = common.addValueLine("@i18n(app.modules.fblstatus.cpu_load)@", "-"),
      pidProfile = common.addValueLine("@i18n(app.modules.profile_select.pid_profile)@", "-"),
      rateProfile = common.addValueLine("@i18n(app.modules.profile_select.rate_profile)@", "-"),
      motors = common.addValueLine("@i18n(app.modules.diagnostics.motor_count)@", "-"),
      servos = common.addValueLine("@i18n(app.modules.diagnostics.servo_count)@", "-"),
      reboot = common.addValueLine("@i18n(app.modules.diagnostics.reboot_required)@", "-"),
      config = common.addValueLine("@i18n(app.modules.diagnostics.configuration_state)@", "-"),
    }
    local pending = 0
    local lastPoll = 0

    -- One static text per detail row, index 1 being the heading. Built on
    -- demand and kept afterwards, because form.addStaticText is the one
    -- control whose text can change at runtime -- re-creating the rows per
    -- poll would rebuild the page twice a second.
    --
    -- Rows are never destroyed, only emptied: this form API has no way to
    -- remove a line, and a row whose text is "" costs one line of height for
    -- as long as the page stays open. That is the price of not rebuilding,
    -- and it is paid only when the pilot clears a flag while sitting on this
    -- page -- re-opening it starts from an empty pool again.
    local armingRows = {}
    local armingSignature = nil

    local function renderArmingDetails(active)
      local signature = table.concat(active, "\1")
      if signature == armingSignature then return end
      armingSignature = signature

      if #active == 0 then
        for i = 1, #armingRows do armingRows[i]:value("") end
        return
      end

      if armingRows[1] == nil then
        armingRows[1] = common.addTextLine(ARMING_DETAIL_HEADING)
      else
        armingRows[1]:value(ARMING_DETAIL_HEADING)
      end
      for i = 1, #active do
        local row = armingRows[i + 1]
        if row == nil then
          row = common.addTextLine("", ARMING_DETAIL_INDENT)
          armingRows[i + 1] = row
        end
        row:value(active[i])
      end
      for i = #active + 2, #armingRows do
        armingRows[i]:value("")
      end
    end

    local function finish()
      if ctx.isDisposed() then
        pending = 0
        return
      end
      pending = pending - 1
      if pending < 0 then pending = 0 end
      if ctx.header then ctx.header.setReloadEnabled(pending == 0) end
    end

    local function applyStatus(data)
      local active = armingFlags.active(data.arming_disable_flags)
      local summary, count = armingFlags.summary(data.arming_disable_flags, active)
      common.updateField(fields.arming, summary)
      -- GREEN and RED are the only colour globals used anywhere in this
      -- suite, both in diagnostics_common.updateStatus(). An "amber" for
      -- "blocked but not broken" would be a new assumption about the API.
      common.setFieldColor(fields.arming, count == 0 and GREEN or RED)
      renderArmingDetails(active)
      common.updateField(fields.realTimeLoad, percentTenths(data.max_real_time_load))
      common.updateField(fields.cpuLoad, percentTenths(data.average_cpu_load))
      common.updateField(fields.pidProfile, string.format("%d / %d", (data.current_pid_profile_index or 0) + 1, data.pid_profile_count or 0))
      common.updateField(fields.rateProfile, string.format("%d / %d", (data.current_control_rate_profile_index or 0) + 1, data.control_rate_profile_count or 0))
      common.updateField(fields.motors, data.motor_count)
      common.updateField(fields.servos, data.servo_count)
      common.updateField(fields.reboot, data.reboot_required == 0 and "@i18n(app.modules.rfstatus.ok)@" or "@i18n(app.modules.rfstatus.error)@")
      common.updateField(fields.config, data.configuration_state)
    end

    local function poll()
      if ctx.isDisposed() or pending > 0 then return end
      pending = 2
      if ctx.header then ctx.header.setReloadEnabled(false) end
      bus.publish("msp.request", mspStatus.buildReadMessage(function(data)
        if not ctx.isDisposed() then applyStatus(data) end
        finish()
      end, finish))
      bus.publish("msp.request", dataflashSummary.buildReadMessage(function(data)
        if not ctx.isDisposed() then common.updateField(fields.dataflash, dataflashText(data)) end
        finish()
      end, finish))
    end

    if ctx.header then
      ctx.header.setReloadEnabled(true)
    end
    poll()

    return {
      onReload = poll,
      wakeup = function()
        local now = os.clock()
        if now - lastPoll < 2 then return end
        lastPoll = now
        poll()
      end,
    }
  end)
end

return {open = open}
