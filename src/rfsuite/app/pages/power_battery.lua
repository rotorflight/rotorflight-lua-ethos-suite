-- Setup -> Power -> Battery page.

local pageRuntime = assert(loadfile("app/page_runtime.lua"))()
local fieldLayout = assert(loadfile("app/field_layout.lua"))()
local batteryConfig = assert(loadfile("lib/msp_battery_config.lua"))()
local batteryProfile = assert(loadfile("lib/msp_battery_profile.lua"))()

local PAGE_TITLE = "@i18n(app.modules.power.battery_name)@"

local function normalizeProfile(value)
  local n = tonumber(value)
  if not n then return nil end
  n = math.floor(n)
  if n >= 1 and n <= 6 then return n - 1 end
  if n >= 0 and n <= 5 then return n end
  return nil
end

local function profileKey(profile)
  profile = normalizeProfile(profile) or 0
  return "batteryCapacity_" .. tostring(profile)
end

local function clampCapacity(value)
  value = tonumber(value or 0) or 0
  if value < 0 then return 0 end
  if value > 40000 then return 40000 end
  return math.floor(value + 0.5)
end

local function open(opts)
  local lastActiveProfile = nil
  local capacityField = nil
  local profileField = nil

  local runtime
  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "power_battery",
    sources = {
      {key = "battery", mspModule = batteryConfig},
      {key = "profile", mspModule = batteryProfile},
    },
    opts = opts,
    profileField = "batteryProfile",
    unloadPackageKeys = {
      "rfsuite.lib.msp_battery_config",
      "rfsuite.lib.msp_battery_profile",
    },
    onLoaded = function()
      local active = normalizeProfile(runtime.lastProfile)
      if active ~= nil then
        runtime.data.profile.batteryProfile = active
      else
        runtime.data.profile.batteryProfile = normalizeProfile(runtime.data.profile.batteryProfile) or 0
      end
      lastActiveProfile = active
      if form.invalidate then form.invalidate() end
    end,
    beforeSave = function(rt)
      local selected = normalizeProfile(rt.data.profile and rt.data.profile.batteryProfile) or 0
      if rt.data.profile then rt.data.profile.batteryProfile = selected end
      if rt.data.battery then
        local key = profileKey(selected)
        rt.data.battery[key] = clampCapacity(rt.data.battery[key])
      end
    end,
    onWakeup = function(rt)
      local active = normalizeProfile(rt.lastProfile)
      if active ~= lastActiveProfile then
        lastActiveProfile = active
        if active ~= nil and rt.data.profile then
          rt.data.profile.batteryProfile = active
          if profileField and profileField.value then profileField:value(active) end
          if capacityField and form.invalidate then form.invalidate() end
        end
      end
      if rt.headerHandle then
        if active ~= nil then
          rt.headerHandle.setTitle(PAGE_TITLE .. " #" .. tostring(active + 1))
        else
          rt.headerHandle.setTitle(PAGE_TITLE)
        end
      end
    end,
  })

  form.clear()
  runtime:buildChrome()
  -- Captured instead of closing over `runtime` directly in the field
  -- getters/setters below -- matching app/pages/pids.lua's own dataRef/
  -- controlRef convention (see its comment): Ethos retains some form
  -- callback closures past this page's own lifetime, and dataRef.data/
  -- controlRef.runtime both get cleared on dispose (app/page_runtime.lua's
  -- own PageRuntime:dispose()), so whatever gets retained here stays small
  -- instead of pinning the whole disposed PageRuntime.
  local dataRef = runtime.dataRef
  local controlRef = runtime.controlRef
  local function markDirty()
    local rt = controlRef.runtime
    if rt then rt:markDirty() end
  end

  form.addLine("@i18n(telemetry.group_profiles)@")
  local line = form.addLine("    @i18n(app.modules.power.selected)@")
  profileField = form.addChoiceField(line, nil, batteryProfile.PROFILE_CHOICES,
    function()
      return normalizeProfile(dataRef.data.profile and dataRef.data.profile.batteryProfile) or 0
    end,
    function(value)
      markDirty()
      if dataRef.data.profile then dataRef.data.profile.batteryProfile = normalizeProfile(value) or 0 end
      if form.invalidate then form.invalidate() end
    end)
  runtime:registerField("profile:batteryProfile", profileField)

  line = form.addLine("    @i18n(app.modules.power.capacity)@")
  capacityField = form.addNumberField(line, nil, 0, 40000,
    function()
      local selected = normalizeProfile(dataRef.data.profile and dataRef.data.profile.batteryProfile) or 0
      local battery = dataRef.data.battery or {}
      return battery[profileKey(selected)] or 0
    end,
    function(value)
      markDirty()
      local selected = normalizeProfile(dataRef.data.profile and dataRef.data.profile.batteryProfile) or 0
      dataRef.data.battery[profileKey(selected)] = clampCapacity(value)
    end)
  capacityField:suffix("mAh")
  capacityField:default(0)
  runtime:registerField("battery:capacityActive", capacityField)

  form.addLine("@i18n(telemetry.group_battery)@")
  fieldLayout.buildSingle(runtime, "    @i18n(app.modules.power.max_cell_voltage)@", {source = "battery", key = "vbatmaxcellvoltage"})
  fieldLayout.buildSingle(runtime, "    @i18n(app.modules.power.full_cell_voltage)@", {source = "battery", key = "vbatfullcellvoltage"})
  fieldLayout.buildSingle(runtime, "    @i18n(app.modules.power.warn_cell_voltage)@", {source = "battery", key = "vbatwarningcellvoltage"})
  fieldLayout.buildSingle(runtime, "    @i18n(app.modules.power.min_cell_voltage)@", {source = "battery", key = "vbatmincellvoltage"})
  fieldLayout.buildSingle(runtime, "    @i18n(app.modules.power.cell_count)@", {source = "battery", key = "batteryCellCount"})
  fieldLayout.buildSingle(runtime, "    @i18n(app.modules.power.consumption_warning_percentage)@", {
    source = "battery",
    key = "consumptionWarningPercentage",
    min = 15,
    max = 60,
  })

  runtime:loadInitial()
end

return {open = open}
