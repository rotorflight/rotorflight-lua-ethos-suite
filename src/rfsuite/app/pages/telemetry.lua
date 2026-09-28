-- Telemetry page. Loaded on demand from Setup -> Telemetry.
--
-- Ports the original suite's Setup/Telemetry module into this rebuild's
-- page_runtime pattern. The original page owns a bespoke lifecycle because
-- it predates this lite app's shared runtime; here the core behavior is
-- expressed as ordinary multi-source page data:
--   FEATURE_CONFIG: ensure the Telemetry feature bit is enabled on save.
--   TELEMETRY_CONFIG: edit the 40 sensor slot assignments, force
--   crsf_telemetry_mode to CUSTOM so a CRSF receiver actually sends them
--   (see the note on CRSF_TELEMETRY_MODE_CUSTOM below), preserve slots this
--   catalog does not manage, and refuse to switch off sensors the flight
--   controller is sending in NATIVE mode.
--
-- The page shows the original grouped boolean sensor list, preserves the
-- FC's telemetry header bytes, writes up to 40 selected sensor IDs back to
-- telem_sensor_slot_1..40, then lets page_runtime perform the common
-- EEPROM write and reboot-after-save path. The header Tool button applies
-- the original default sensor set.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local featureConfig = requireModule("lib/msp_feature_config.lua")
local telemetryConfig = requireModule("lib/msp_telemetry_config.lua")
local catalog = requireModule("lib/telemetry_sensor_catalog.lua")

local PAGE_TITLE = "@i18n(app.modules.telemetry.name)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"

-- Firmware's CRSF_TELEMETRY_MODE_* (src/main/pg/telemetry.h, 0 = NATIVE).
local CRSF_TELEMETRY_MODE_NATIVE = 0
local CRSF_TELEMETRY_MODE_CUSTOM = 1

-- Why this page still forces CUSTOM -- and what it does NOT do.
--
-- The previous comment here claimed that in NATIVE mode "the FC ignores
-- telem_sensor_slot_1..40 entirely and sends its fixed built-in CRSF sensor
-- set instead". The first half is wrong: crsfInitNativeTelemetry()
-- (src/main/telemetry/crsf.c) walks crsfNativeTelemetrySensors and adds each
-- one whose sensor_id is found in telemetryConfig()->telemetry_sensors[j],
-- so NATIVE *also* filters by the 40 slots. The mode chooses which sensor
-- table the slots filter -- crsfNativeTelemetrySensors (7 entries, appId 0,
-- sent as whole CRSF frames) or crsfCustomTelemetrySensors (appId 0x10xx /
-- 0x12xx, sent as custom telemetry).
--
-- Forcing CUSTOM is still required, for a different reason: this suite has no
-- parser for those whole frames. lib/frsky_sensors.lua turns the 40 slots
-- into appIds via lib/frsky_sid_lookup.lua and creates one sensor per appId,
-- and tasks/elrs_sensors.lua decodes exactly the crsfCustomTelemetrySensors
-- appIds (see lib/elrs_sensor_table.lua). In NATIVE mode the flight
-- controller sends none of those appIds, so the suite would show no sensors
-- at all. That is why the write below sets the mode -- not because the slots
-- need it.
--
-- It is a real overwrite of a pilot-visible setting, so it is stated in
-- docs/pages/setup/telemetry.md rather than left for the pilot to discover
-- on the radio. This page cannot show the mode inline: the mode is only known
-- after the MSP read, and this form API has no way to set the text of a control
-- that already exists (there is no setText anywhere in the tree, and
-- app/pages/configuration.lua is the only page that builds its fields after
-- the read). The mode itself is on screen under Diagnostics -> ELRS Link.
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

-- Sensors the FC sends in NATIVE mode regardless of what a slot says cannot be
-- switched off from here. Mirrors the EdgeTX page's isNativeLocked() and is
-- only active while the mode actually is NATIVE -- once the page has saved
-- once the mode is CUSTOM, these are ordinary custom sensors again
-- (ALTITUDE 0x10B2, ATTITUDE 0x1100, FLIGHT_MODE 0x1201 in
-- crsfCustomTelemetrySensors) and the pilot regains control of them.
local function isNativeLocked(crsfMode, id)
  return crsfMode == CRSF_TELEMETRY_MODE_NATIVE
    and catalog.NATIVE_LOCKED_IDS[id] == true
end

-- NOT_AT_SAME_TIME maps a parent to its children, so "is my parent
-- native-locked?" reads catalog.CONFLICTING_WITH, the reverse map derived in
-- that file. A child of a native-locked parent is out of the pilot's reach for
-- the same reason the parent is: the firmware will not send the combined and
-- the per-axis value at the same time, and in NATIVE mode it is sending the
-- parent.
--
-- Without this the switch accepts a tick, shows as on, and then collectSelected()
-- drops the id -- the page would promise a sensor the FC never sends. Mirrors
-- the CONFLICTING_WITH lookup in the EdgeTX page's getBoolGetter/getBoolSetter.
local function hasNativeLockedParent(crsfMode, id)
  local parentId = catalog.CONFLICTING_WITH[id]
  return parentId ~= nil and isNativeLocked(crsfMode, parentId)
end

-- Either the id itself or its parent is being sent by the FC whatever the page
-- does, so the page must not offer to change it.
local function isFixedByFc(crsfMode, id)
  return isNativeLocked(crsfMode, id) or hasNativeLockedParent(crsfMode, id)
end

local function countSelected(selected)
  local count = 0
  for _, id in ipairs(catalog.SENSOR_IDS) do
    if selected[id] == true then count = count + 1 end
  end
  return count
end

-- The ids to write, in the catalog's own order, so that what the pilot sees
-- checked is what lands on the wire. Native-locked ids are included whether
-- or not `selected` carries them: a child of a native-locked sensor is
-- skipped, because the conflict handler has switched it off on screen and
-- writing it anyway would put a sensor on the wire that the page shows as
-- off. Same two rules as the EdgeTX page's collectSelectedSensors().
local function collectSelected(selected, crsfMode)
  local out = {}
  for _, id in ipairs(catalog.SENSOR_IDS) do
    if isNativeLocked(crsfMode, id) then
      out[#out + 1] = id
    elseif selected[id] == true and not hasNativeLockedParent(crsfMode, id) then
      out[#out + 1] = id
    end
  end
  return out
end

-- Rewrites the 40 slots in place, preserving every slot this catalog does not
-- manage at its original position.
--
-- The previous version collapsed the slots into a set on load
-- (selectedFromSlots) and re-emitted them as a dense array in catalog order
-- (selectedToSlots). That round trip lost three things at once: the position
-- of every slot, duplicate entries (two slots holding the same id collapsed
-- into one, silently freeing a slot), and -- the reported bug -- any slot
-- holding an id the catalog has no entry for, which was written back as 0.
-- A native CRSF slot is exactly such an id for most of the native sensor set,
-- so saving from this page dropped the flight controller's native feeds.
--
-- The fix walks the original array instead: a slot whose incoming id is not
-- one this catalog manages is left exactly as it was, and the pilot's
-- selection fills the remaining slots in order. Mirrors the EdgeTX page's
-- buildWritePayload().
local function slotsPreservingUnmanaged(slots, orderedSelected)
  slots = slots or {}
  local index = 1
  for i = 1, telemetryConfig.SLOT_COUNT do
    local originalId = slots[i] or 0
    if originalId ~= 0 and catalog.SENSOR_LIST[originalId] == nil then
      -- Unmanaged slot (a native CRSF id, say): preserve it where it was.
    else
      slots[i] = orderedSelected[index] or 0
      index = index + 1
    end
  end
  -- Anything past the original array is a slot this page owns, so a short read
  -- (or a pilot holding more than SLOT_COUNT selections) cannot leave stale
  -- entries behind.
  for i = #slots + 1, telemetryConfig.SLOT_COUNT do
    slots[i] = orderedSelected[index] or 0
    index = index + 1
  end
  return slots
end

-- Slots the pilot does not see, kept where the FC had them. Counted so the
-- page can still refuse a write that would not fit into 40 slots once those
-- preserved slots are counted, the way the EdgeTX page does.
local function countUnmanaged(slots)
  local count = 0
  if type(slots) ~= "table" then return 0 end
  for i = 1, #slots do
    local id = slots[i] or 0
    if id ~= 0 and catalog.SENSOR_LIST[id] == nil then
      count = count + 1
    end
  end
  return count
end

local function applyDefaultSelection(selected, crsfMode)
  clearTable(selected)
  for _, id in ipairs(catalog.DEFAULT_IDS) do
    selected[id] = true
  end
  -- The Tool button resets the pilot's selection to the default set, so it
  -- must not quietly switch off a sensor the FC is sending either -- the same
  -- reason collectSelected() adds those ids back unconditionally. Children of a
  -- fixed parent are deliberately not added: the firmware will not send the
  -- combined and the per-axis value together.
  for id in pairs(catalog.NATIVE_LOCKED_IDS) do
    if isFixedByFc(crsfMode, id) then
      selected[id] = true
    end
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
  -- The FC's crsf_telemetry_mode as read, or nil while the page is still
  -- loading. Read into a local rather than read back off runtime.data, so
  -- beforeSave/collectSelected see the mode the *page* was built against.
  local crsfMode = nil

  local function refreshConflictFields()
    for id, field in pairs(fieldsBySensor) do
      -- A sensor the FC is sending (or whose parent it is sending) stays
      -- disabled: its setter rejects a change anyway.
      if not isFixedByFc(crsfMode, id) then
        field:enable(true)
      end
    end
    for id, conflicts in pairs(catalog.NOT_AT_SAME_TIME) do
      if selected[id] == true then
        for _, conflictId in ipairs(conflicts) do
          -- A fixed-by-FC conflict is not switched off here: the FC sends it
          -- whether a slot selects it or not, so claiming it is off would be a
          -- lie the save would not keep.
          if isFixedByFc(crsfMode, conflictId) then
            selected[conflictId] = true
          else
            previousConflictState[conflictId] = selected[conflictId]
            selected[conflictId] = false
            if fieldsBySensor[conflictId] then
              fieldsBySensor[conflictId]:enable(false)
            end
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
      crsfMode = telemetry.crsf_telemetry_mode
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
        -- Preserved slots count against the 40 just as managed ones do, so
        -- the "no more than 40" refusal stays honest now that unmanaged slots
        -- are no longer overwritten with 0.
        local unmanaged = countUnmanaged(telemetry.slots)
        local ordered = collectSelected(selected, crsfMode)
        if #ordered + unmanaged > telemetryConfig.SLOT_COUNT then
          -- Refused: slots and mode are left exactly as read, so the write
          -- that follows re-sends the flight controller's current state
          -- rather than a truncated version of the pilot's wish. The pilot's
          -- switches are dropped, which is what the dialog is for. (The edgeTX
          -- page returns false and blocks the write entirely; this runtime has
          -- no veto, and re-sending the unchanged config is the safer of the
          -- two available outcomes.)
          openTooManyDialog()
          return
        end
        telemetry.slots = slotsPreservingUnmanaged(telemetry.slots, ordered)
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
            applyDefaultSelection(selected, crsfMode)
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
            -- Fixed-by-FC reads as on even if nothing put it in `selected`:
            -- the FC is sending it, so the switch must not show off.
            if isFixedByFc(crsfMode, sensorId) then return true end
            return selected[sensorId] == true
          end,
          function(value)
            -- Refuse the change outright while the FC is sending this sensor
            -- (or its parent). Returning false leaves the switch where the
            -- getter last reported it, so the pilot's tap does not make the
            -- page disagree with the FC.
            if isFixedByFc(crsfMode, sensorId) then return false end

            if value == true and selected[sensorId] ~= true
                and countSelected(selected) >= telemetryConfig.SLOT_COUNT then
              openTooManyDialog()
              return false
            end

            -- Plain conflict handling, with no native-locked special case for
            -- the children: `conflictId` here is always a child (NOT_AT_SAME_TIME
            -- maps a parent to its children), and no child id is in
            -- NATIVE_LOCKED_IDS. The case that does need guarding -- a child
            -- whose parent is native-locked -- is already refused by the
            -- isFixedByFc() check at the top of this setter.
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
