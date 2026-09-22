-- Setup -> Power -> Battery page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local batteryConfig = requireModule("lib/msp_battery_config.lua")
local batteryProfile = requireModule("lib/msp_battery_profile.lua")
local bus = requireModule("lib/bus.lua")

local PAGE_TITLE = "@i18n(app.modules.power.battery_name)@"

-- All values flowing through this file are already 0-based (choice field
-- values from PROFILE_CHOICES, session.batteryProfile from tasks/session.lua,
-- and the raw MSP_BATTERY_PROFILE decode) -- unlike
-- tasks/session.lua's own normalizeBatteryProfile(), which additionally
-- has to cope with a possibly-1-based raw telemetry sensor reading, this
-- just validates/clamps rather than guessing at a base. Self-caught bug,
-- found live: this used to also accept 1-6 and subtract 1, which silently
-- collapsed an already-0-based selection of "2" (value 1) back down to
-- "1" (value 0) -- profile 3-6 selections were corrupted the same way.
local function normalizeProfile(value)
  local n = tonumber(value)
  if not n then return nil end
  n = math.floor(n)
  if n >= 0 and n <= 5 then return n end
  return nil
end

local function profileKey(profile)
  profile = normalizeProfile(profile) or 0
  return "batteryCapacity_" .. tostring(profile)
end

-- Firmware with per-profile cell settings (rotorflight-firmware #508) reports
-- cell count and the four cell voltages once per battery profile
-- (<base>_0..5, see lib/msp_battery_config.lua); the un-suffixed legacy
-- fields just mirror the active profile. Older firmware only has the legacy
-- fields, which then apply to every profile.
local CELL_FIELDS = {
  "batteryCellCount",
  "vbatmincellvoltage",
  "vbatmaxcellvoltage",
  "vbatfullcellvoltage",
  "vbatwarningcellvoltage",
}

local CELL_KEYS = {}
for _, base in ipairs(CELL_FIELDS) do
  local keys = {}
  for profile = 0, 5 do keys[profile] = base .. "_" .. profile end
  CELL_KEYS[base] = keys
end

local function cellKey(battery, base, profile)
  if battery and battery.hasProfileCells then
    return CELL_KEYS[base][normalizeProfile(profile) or 0]
  end
  return base
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
        -- Legacy fields carry the active profile's values; the firmware
        -- applies the per-profile arrays after them, so this is only for
        -- consistency with what the configurator writes.
        if rt.data.battery.hasProfileCells then
          for _, base in ipairs(CELL_FIELDS) do
            rt.data.battery[base] = rt.data.battery[CELL_KEYS[base][selected]]
          end
        end
      end
    end,
    -- tasks/session.lua reads BATTERY_CONFIG once at connect and caches it
    -- (session.batteryConfig) for the rest of the connection -- SmartFuel's
    -- local estimator and other consumers were still seeing pre-edit
    -- min/max/full cell voltage, capacity, and reserve % after a save here
    -- until reconnect. This tells session.lua to refetch immediately.
    onSaved = function()
      bus.publish("battery.config.saved")
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
  -- Cell count / cell voltages follow the selected profile (same as capacity
  -- above), so they can't go through fieldLayout's fixed-key buildSingle().
  local function addCellField(label, base)
    local meta = batteryConfig.FIELD_META[base]
    line = form.addLine(label)
    local field = form.addNumberField(line, nil, meta.min, meta.max,
      function()
        local selected = normalizeProfile(dataRef.data.profile and dataRef.data.profile.batteryProfile) or 0
        local battery = dataRef.data.battery or {}
        return battery[cellKey(battery, base, selected)] or 0
      end,
      function(value)
        markDirty()
        local selected = normalizeProfile(dataRef.data.profile and dataRef.data.profile.batteryProfile) or 0
        local battery = dataRef.data.battery
        battery[cellKey(battery, base, selected)] = value
      end)
    if meta.decimals then field:decimals(meta.decimals) end
    if meta.suffix then field:suffix(meta.suffix) end
    field:default(meta.default or 0)
    runtime:registerField("battery:" .. base, field)
  end
  addCellField("    @i18n(app.modules.power.max_cell_voltage)@", "vbatmaxcellvoltage")
  addCellField("    @i18n(app.modules.power.full_cell_voltage)@", "vbatfullcellvoltage")
  addCellField("    @i18n(app.modules.power.warn_cell_voltage)@", "vbatwarningcellvoltage")
  addCellField("    @i18n(app.modules.power.min_cell_voltage)@", "vbatmincellvoltage")
  addCellField("    @i18n(app.modules.power.cell_count)@", "batteryCellCount")
  fieldLayout.buildSingle(runtime, "    @i18n(app.modules.power.consumption_warning_percentage)@", {
    source = "battery",
    key = "consumptionWarningPercentage",
    min = 15,
    max = 60,
  })

  runtime:loadInitial()
end

return {open = open}
