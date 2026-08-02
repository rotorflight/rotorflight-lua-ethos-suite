-- Telemetry page. Loaded on demand from Setup -> Telemetry.
--
-- Ports the original suite's Setup/Telemetry module into this rebuild's
-- page_runtime pattern. The original page owns a bespoke lifecycle because
-- it predates this lite app's shared runtime; here the core behavior is
-- expressed as ordinary multi-source page data:
--   FEATURE_CONFIG: ensure the Telemetry feature bit is enabled on save.
--   TELEMETRY_CONFIG: edit the 40 sensor slot assignments, and force
--   crsf_telemetry_mode to CUSTOM so a CRSF receiver actually sends them.
--
-- The page shows the original grouped boolean sensor list, preserves the
-- FC's telemetry header bytes, writes up to 40 selected sensor IDs back to
-- telem_sensor_slot_1..40, then lets page_runtime perform the common
-- EEPROM write and reboot-after-save path. The header Tool button applies
-- the original default sensor set.

local pageRuntime = assert(loadfile("app/page_runtime.lua"))()
local featureConfig = assert(loadfile("lib/msp_feature_config.lua"))()
local telemetryConfig = assert(loadfile("lib/msp_telemetry_config.lua"))()
local catalog = assert(loadfile("lib/telemetry_sensor_catalog.lua"))()

local PAGE_TITLE = "@i18n(app.modules.telemetry.name)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"

-- Firmware's CRSF_TELEMETRY_MODE_CUSTOM (src/main/pg/telemetry.h): with
-- crsf_telemetry_mode left at its default NATIVE (0), the FC ignores
-- telem_sensor_slot_1..40 entirely and sends its fixed built-in CRSF sensor
-- set instead -- the slots this page writes below would silently have no
-- effect over CRSF. Forcing CUSTOM here is harmless for non-CRSF receivers
-- (crsf_telemetry_mode is only consulted by the CRSF telemetry driver).
local CRSF_TELEMETRY_MODE_CUSTOM = 1

local telemetryConfigPage = {
  buildReadMessage = telemetryConfig.buildReadConfigMessage,
  buildWriteMessage = telemetryConfig.buildWriteMessage,
}

local function clearTable(t)
  for k in pairs(t) do t[k] = nil end
end

local function selectedFromSlots(slots, selected)
  clearTable(selected)
  if type(slots) ~= "table" then return end
  for i = 1, #slots do
    local id = slots[i]
    if id and id ~= 0 then
      selected[id] = true
    end
  end
end

local function countSelected(selected)
  local count = 0
  for _, id in ipairs(catalog.SENSOR_IDS) do
    if selected[id] == true then count = count + 1 end
  end
  return count
end

local function selectedToSlots(selected, slots)
  slots = slots or {}
  local slotIndex = 1
  for _, id in ipairs(catalog.SENSOR_IDS) do
    if selected[id] == true and slotIndex <= telemetryConfig.SLOT_COUNT then
      slots[slotIndex] = id
      slotIndex = slotIndex + 1
    end
  end
  for i = slotIndex, telemetryConfig.SLOT_COUNT do
    slots[i] = 0
  end
  return slots
end

local function applyDefaultSelection(selected)
  clearTable(selected)
  for _, id in ipairs(catalog.DEFAULT_IDS) do
    selected[id] = true
  end
end

local function openTooManyDialog()
  form.openDialog({
    title = PAGE_TITLE,
    message = "@i18n(app.modules.telemetry.no_more_than_40)@",
    buttons = {
      {label = BTN_OK, action = function() return true end},
    },
    wakeup = function() end,
    paint = function() end,
  })
end

local function open(opts)
  local selected = {}
  local previousConflictState = {}
  local fieldsBySensor = {}

  local function refreshConflictFields()
    for _, field in pairs(fieldsBySensor) do
      field:enable(true)
    end
    for id, conflicts in pairs(catalog.NOT_AT_SAME_TIME) do
      if selected[id] == true then
        for _, conflictId in ipairs(conflicts) do
          previousConflictState[conflictId] = selected[conflictId]
          selected[conflictId] = false
          if fieldsBySensor[conflictId] then
            fieldsBySensor[conflictId]:enable(false)
          end
        end
      end
    end
  end

  local runtime
  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "telemetry",
    sources = {
      {key = "feature", mspModule = featureConfig},
      {key = "telemetry", mspModule = telemetryConfigPage},
    },
    opts = opts,
    profileField = "none",
    rebootAfterSave = true,
    unloadPackageKeys = {
      "rfsuite.lib.msp_feature_config",
      "rfsuite.lib.msp_telemetry_config",
      "rfsuite.lib.telemetry_sensor_catalog",
    },
    onLoaded = function()
      local telemetry = runtime.data.telemetry or {}
      selectedFromSlots(telemetry.slots, selected)
      previousConflictState = {}
      refreshConflictFields()
      if form.invalidate then form.invalidate() end
    end,
    beforeSave = function(rt)
      local feature = rt.data.feature
      if feature then
        feature.enabledFeatures = featureConfig.setBit(
          feature.enabledFeatures,
          featureConfig.FEATURE_BIT_TELEMETRY,
          true)
      end
      local telemetry = rt.data.telemetry
      if telemetry then
        telemetry.slots = selectedToSlots(selected, telemetry.slots)
        telemetry.crsf_telemetry_mode = CRSF_TELEMETRY_MODE_CUSTOM
      end
    end,
    onTool = function(focusFn)
      if not runtime.loaded then return end
      -- Captured here, not closed over directly in the dialog button's
      -- own action below -- matching app/page_runtime.lua's own
      -- confirmSave()/confirmReload() dialogs (see their comments): a
      -- dialog button's action is handed straight to Ethos same as a
      -- field setter is, so it gets the same small-indirection-table
      -- treatment.
      local controlRef = runtime.controlRef
      form.openDialog({
        title = PAGE_TITLE,
        message = "@i18n(app.modules.telemetry.msg_set_defaults)@",
        buttons = {
          {label = BTN_OK, action = function()
            local rt = controlRef and controlRef.runtime
            if rt then rt:markDirty() end
            applyDefaultSelection(selected)
            previousConflictState = {}
            refreshConflictFields()
            if form.invalidate then form.invalidate() end
            if focusFn then focusFn() end
            return true
          end},
          {label = BTN_CANCEL, action = function()
            if focusFn then focusFn() end
            return true
          end},
        },
        wakeup = function() end,
        paint = function() end,
      })
    end,
  })

  form.clear()
  runtime:buildChrome()
  -- Captured instead of closing over `runtime` directly in the checkbox
  -- setter below -- matching app/pages/pids.lua's own dataRef convention
  -- (see its comment): Ethos retains some form callback closures past
  -- this page's own lifetime, and controlRef.runtime gets nilled on
  -- dispose (app/page_runtime.lua's own PageRuntime:dispose()), so
  -- whatever gets retained here stays small instead of pinning the whole
  -- disposed PageRuntime.
  local controlRef = runtime.controlRef
  local function markDirty()
    local rt = controlRef.runtime
    if rt then rt:markDirty() end
  end

  for _, groupKey in ipairs(catalog.GROUP_ORDER) do
    local group = catalog.SENSOR_GROUPS[groupKey]
    if group and group.ids and #group.ids > 0 then
      local panel = form.addExpansionPanel(group.title)
      panel:open(false)
      for _, id in ipairs(group.ids) do
        local sensor = catalog.SENSOR_LIST[id]
        local sensorId = id
        local line = panel:addLine(sensor.name)
        local field = form.addBooleanField(line, nil,
          function()
            return selected[sensorId] == true
          end,
          function(value)
            if value == true and selected[sensorId] ~= true
                and countSelected(selected) >= telemetryConfig.SLOT_COUNT then
              openTooManyDialog()
              return false
            end

            local conflicts = catalog.NOT_AT_SAME_TIME[sensorId]
            if conflicts then
              if value == true then
                for _, conflictId in ipairs(conflicts) do
                  previousConflictState[conflictId] = selected[conflictId]
                  selected[conflictId] = false
                  if fieldsBySensor[conflictId] then
                    fieldsBySensor[conflictId]:enable(false)
                  end
                end
              else
                for _, conflictId in ipairs(conflicts) do
                  if fieldsBySensor[conflictId] then
                    fieldsBySensor[conflictId]:enable(true)
                  end
                  if previousConflictState[conflictId] ~= nil then
                    selected[conflictId] = previousConflictState[conflictId]
                    previousConflictState[conflictId] = nil
                  end
                end
              end
            end

            markDirty()
            selected[sensorId] = value == true
            if form.invalidate then form.invalidate() end
          end)
        fieldsBySensor[sensorId] = field
        runtime:registerField("telemetry:" .. sensorId, field)
      end
    end
  end

  runtime:loadInitial()
end

return {open = open}
