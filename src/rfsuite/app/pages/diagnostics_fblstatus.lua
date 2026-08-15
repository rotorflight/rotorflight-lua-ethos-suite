-- Tools -> Diagnostics -> FBL Status page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local common = requireModule("app/diagnostics_common.lua")
local mspStatus = requireModule("lib/msp_status.lua")
local dataflashSummary = requireModule("lib/msp_dataflash_summary.lua")

local PAGE_TITLE = "@i18n(app.modules.diagnostics.name)@ / @i18n(app.modules.fblstatus.name)@"

local ARMING_FLAGS = {
  [0] = "@i18n(app.modules.fblstatus.arming_disable_flag_0)@",
  [1] = "@i18n(app.modules.fblstatus.arming_disable_flag_1)@",
  [2] = "@i18n(app.modules.fblstatus.arming_disable_flag_2)@",
  [3] = "@i18n(app.modules.fblstatus.arming_disable_flag_3)@",
  [4] = "@i18n(app.modules.fblstatus.arming_disable_flag_4)@",
  [5] = "@i18n(app.modules.fblstatus.arming_disable_flag_5)@",
  [6] = "@i18n(app.modules.fblstatus.arming_disable_flag_6)@",
  [7] = "@i18n(app.modules.fblstatus.arming_disable_flag_7)@",
  [8] = "@i18n(app.modules.fblstatus.arming_disable_flag_8)@",
  [9] = "@i18n(app.modules.fblstatus.arming_disable_flag_9)@",
  [10] = "@i18n(app.modules.fblstatus.arming_disable_flag_10)@",
  [11] = "@i18n(app.modules.fblstatus.arming_disable_flag_11)@",
  [12] = "@i18n(app.modules.fblstatus.arming_disable_flag_12)@",
  [13] = "@i18n(app.modules.fblstatus.arming_disable_flag_13)@",
  [14] = "@i18n(app.modules.fblstatus.arming_disable_flag_14)@",
  [15] = "@i18n(app.modules.fblstatus.arming_disable_flag_15)@",
  [16] = "@i18n(app.modules.fblstatus.arming_disable_flag_16)@",
  [17] = "@i18n(app.modules.fblstatus.arming_disable_flag_17)@",
  [18] = "@i18n(app.modules.fblstatus.arming_disable_flag_18)@",
  [19] = "@i18n(app.modules.fblstatus.arming_disable_flag_19)@",
  [20] = "@i18n(app.modules.fblstatus.arming_disable_flag_20)@",
  [21] = "@i18n(app.modules.fblstatus.arming_disable_flag_21)@",
  [22] = "@i18n(app.modules.fblstatus.arming_disable_flag_22)@",
  [23] = "@i18n(app.modules.fblstatus.arming_disable_flag_23)@",
  [24] = "@i18n(app.modules.fblstatus.arming_disable_flag_24)@",
  [25] = "@i18n(app.modules.fblstatus.arming_disable_flag_25)@",
}

local function hasBit(mask, bit)
  return math.floor((tonumber(mask or 0) or 0) / (2 ^ bit)) % 2 >= 1
end

local function percentTenths(value)
  if value == nil then return "-" end
  return string.format("%.1f%%", (tonumber(value) or 0) / 10)
end

local function armingFlagsText(mask)
  mask = tonumber(mask or 0) or 0
  if mask == 0 then return "@i18n(app.modules.fblstatus.ok)@" end
  local parts = {}
  for bit = 0, 25 do
    if hasBit(mask, bit) then
      parts[#parts + 1] = ARMING_FLAGS[bit] or tostring(bit)
    end
  end
  if #parts == 0 then return tostring(mask) end
  local text = parts[1]
  for i = 2, #parts do
    text = text .. ", " .. parts[i]
  end
  return text
end

local function dataflashText(summary)
  if not summary then return "-" end
  if not hasBit(summary.flags, 1) then return "@i18n(app.modules.fblstatus.unsupported)@" end
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
      common.updateField(fields.arming, armingFlagsText(data.arming_disable_flags))
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
