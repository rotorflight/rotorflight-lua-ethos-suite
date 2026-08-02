-- Small field/row builder shared by this app's MSP editor pages, sitting
-- on top of app/page_runtime.lua (which owns everything except the field
-- widgets and their layout). Extracted from app/pages/pid_controller.lua
-- once app/pages/tail_rotor.lua needed the identical helpers.
--
-- Deliberately NOT a full declarative schema engine (see AGENTS.md's
-- "Shared page machinery" note for why: the original suite's own such
-- engine, app/lib/ui.lua + app/lib/fields/*, is thousands of lines,
-- built to support far more field types/conditions -- choice/switch/
-- slider/source/color, per-field version gates, cross-field enable
-- rules -- than the two shapes this rebuild's pages have actually needed
-- so far). Just those two shapes, promoted here once a second page
-- needed them: a single field on its own line, and several related
-- fields sharing one line with an inline mini-label beside each.

-- Self-caches via package.loaded (same mechanism lib/bus.lua uses) --
-- every field-using page reloads this file fresh via loadfile() on every
-- open. Most state still comes from `runtime`/`spec` call arguments; the one
-- deliberate module-level mutable table below pools field getter/setter
-- closures by page+field shape, because live testing showed Ethos retains
-- some form callback/widget allocations after `form.clear()`. Reusing the
-- same callback objects cannot fix retained widget objects, but should avoid
-- adding fresh retained Lua closures on every repeat visit. One of several such caches
-- added after a live memory investigation confirmed the *bulk* of this
-- rebuild's observed RAM growth is an Ethos platform trait (the `form`
-- widget system itself retaining something per created field, outside
-- Lua's own GC reachability -- confirmed by checking that
-- rotorflight-lua-ethos-suite shows the same symptom) that no
-- script-side change can eliminate -- but redundant reloading of
-- stateless shared modules like this one is a separate, real, avoidable
-- cost. See AGENTS.md's "Memory stats printing" section.
if package.loaded["rfsuite.app.field_layout"] then
  return package.loaded["rfsuite.app.field_layout"]
end

local field_layout = {}

-- Content-fit sizing hint for a mini inline label -- same idiom as
-- app/header.lua's own sizingHint() for its nav buttons (there, real
-- padding is wanted, since MENU/SAVE/RELOAD are actual pressable
-- buttons that need comfortable hit targets; a plain inline label here
-- has no such need). No padding at all -- a live screenshot of
-- app/pages/rates_advanced.lua's 4-per-line groups (now using single-
-- letter R/P/Y/C labels, see their own i18n entries) still showed the
-- number fields cramped enough to abut their own suffix ("ms"/"°/s")
-- even after a first trim (leading-space-only); each widget's own
-- built-in margin already separates it from its neighbours without any
-- extra characters reserving width for it, so the bare label string is
-- the whole hint. Reclaimed width goes to the field slot instead --
-- multiplied by 4 label/field pairs per line, on every page using
-- buildGroup() below, not just rates_advanced.lua.
local function sizingHint(label)
  return label
end
field_layout.sizingHint = sizingHint

-- spec: {key, min, max, decimals, suffix, default, choices, source, bit}.
-- `source` (optional) selects `runtime.data[source][key]` instead of the
-- flat `runtime.data[key]` -- only meaningful on multi-source pages, see
-- app/page_runtime.lua's PageRuntime.new() comment on single- vs
-- multi-source data shape (app/pages/tail_rotor.lua is the first page
-- using this; app/pages/pids.lua and app/pages/pid_controller.lua are
-- both single-source and never set `source`).
-- `bit` (optional, 0-indexed from the LSB) turns `spec.key` from a plain
-- field into a single bit read/written within a *shared* packed integer
-- field -- e.g. app/pages/governor_flags.lua's four flags all live in
-- one `governor_flags` U16, at different bits. Only meaningful alongside
-- `choices` (a bit is inherently a 2-state value); `min`/`max`/`decimals`/
-- `suffix`/`default` are meaningless with `bit` set and ignored.
--
-- `min`/`max`/`decimals`/`suffix`/`default` are all optional overrides --
-- when a spec omits any of them, buildField() falls back to that field's
-- entry in its MSP codec module's own `FIELD_META` table (e.g.
-- lib/msp_pid_profile.lua's FIELD_META), keyed by `spec.key`. Pages should
-- only set these explicitly when deliberately deviating from the codec's
-- own firmware-defined range/default; every page built so far just omits
-- them and takes the codec's values as-is (see metaFor() below for which
-- codec a multi-source page's `spec.source` picks).
local function dataTable(runtime, spec)
  if spec.source then
    return runtime.data[spec.source]
  end
  return runtime.data
end

-- Finds the MSP codec module backing `spec.key`, to look up its
-- FIELD_META. app/page_runtime.lua's PageRuntime.new() always populates
-- runtime.sources (single-source pages wrap their one mspModule into
-- sources = {{key = "default", mspModule = ...}}), so this needs no
-- separate single- vs multi-source branch of its own -- just find the
-- source whose key matches spec.source, or fall back to the page's only
-- source when spec.source is unset (true for every single-source page).
local function moduleFor(runtime, spec)
  if spec.source then
    for _, source in ipairs(runtime.sources) do
      if source.key == spec.source then
        return source.mspModule
      end
    end
    return nil
  end
  return runtime.sources[1].mspModule
end

local function metaFor(runtime, spec)
  local mspModule = moduleFor(runtime, spec)
  return mspModule and mspModule.FIELD_META and mspModule.FIELD_META[spec.key]
end

-- Arithmetic bit ops, not native bitwise operators -- same convention as
-- lib/mspcodec.lua (see its own comment: works unmodified regardless of
-- the Lua version's bitwise-operator support).
local function getBit(value, bit)
  return math.floor((value or 0) / (2 ^ bit)) % 2
end

local function setBit(value, bit, bitValue)
  value = value or 0
  local mask = 2 ^ bit
  local currentlySet = getBit(value, bit) == 1
  if bitValue ~= 0 and not currentlySet then
    return value + mask
  elseif bitValue == 0 and currentlySet then
    return value - mask
  end
  return value
end

local function decimalFactor(decimals)
  if not decimals then return 1 end
  return 10 ^ decimals
end

local function scaledValue(value, scale, decimals)
  if not scale then return value end
  return math.floor(((value or 0) * decimalFactor(decimals) / scale) + 0.5)
end

local function unscaledValue(value, scale, decimals)
  if not scale then return value end
  return math.floor(((value or 0) * scale / decimalFactor(decimals)) + 0.5)
end

-- registerField() keys must be unique across the whole page (see
-- app/page_runtime.lua:registerField -- it's a flat table keyed for
-- enable/disable tracking during load/save). Namespaced by source so two
-- different MSP commands on the same multi-source page can never
-- silently collide even if they happen to share a field name; a
-- single-source page's key is unchanged (no source = no prefix).
-- Namespaced by bit too -- several bit specs legitimately share the same
-- underlying `key` (that's the whole point of `bit`), so the key alone
-- would collide and only the last-registered field would ever get
-- enabled/disabled correctly.
local function registryKey(spec)
  local key = spec.key
  if spec.bit then
    key = key .. ":bit" .. spec.bit
  end
  if spec.source then
    key = spec.source .. ":" .. key
  end
  return key
end

local EMPTY_TABLE = {}

local function refDataTable(dataRef, source)
  local data = dataRef.data
  if not data then
    if source then
      data = {}
      dataRef.data = data
    else
      return EMPTY_TABLE
    end
  end
  if not source then
    return data
  end
  local t = data[source]
  if not t then
    t = {}
    data[source] = t
  end
  return t
end

local accessorSlots = {}

local function slotId(runtime, spec, kind, scale, decimals)
  return table.concat({
    tostring(runtime.logTag or runtime.pageTitle or "?"),
    registryKey(spec),
    kind,
    tostring(scale or ""),
    tostring(decimals or ""),
  }, "|")
end

local function rememberRuntimeSlot(runtime, id)
  local list = runtime._fieldLayoutSlotIds
  if not list then
    list = {}
    runtime._fieldLayoutSlotIds = list
  end
  list[#list + 1] = id
end

-- Pools a slot's dirty-marking setter wrapper the same way slot.get/
-- slot.set themselves are pooled -- created once per slot, not once per
-- buildField() call, and reads slot.controlRef dynamically (updated below
-- on every claim, same lifecycle as slot.dataRef) rather than closing over
-- `runtime` directly. `controlRef` -- not the full runtime -- is what's
-- safe to hold indefinitely in this permanently-pooled table: page_runtime.
-- lua's own PageRuntime:dispose() nils controlRef.runtime specifically so
-- closures like this one that outlive the page still only pin a tiny
-- emptied indirection table, never the disposed runtime (and everything
-- it references) itself. See this file's own module comment for why
-- fresh-per-visit closures matter here at all.
local function makeSetWithDirty(slot)
  return function(value)
    local runtime = slot.controlRef and slot.controlRef.runtime
    if runtime then runtime:markDirty() end
    slot.set(value)
  end
end

local function configureChoiceSlot(runtime, spec)
  local id = slotId(runtime, spec, spec.bit and "bit" or "choice")
  local slot = accessorSlots[id]
  if not slot then
    slot = {}
    if spec.bit then
      slot.get = function()
        if not slot.dataRef then return 0 end
        return getBit(refDataTable(slot.dataRef, slot.source)[slot.key], slot.bit)
      end
      slot.set = function(value)
        if not slot.dataRef then return end
        local t = refDataTable(slot.dataRef, slot.source)
        t[slot.key] = setBit(t[slot.key], slot.bit, value)
      end
    else
      slot.get = function()
        if not slot.dataRef then return nil end
        return refDataTable(slot.dataRef, slot.source)[slot.key]
      end
      slot.set = function(value)
        if not slot.dataRef then return end
        refDataTable(slot.dataRef, slot.source)[slot.key] = value
      end
    end
    slot.setWithDirty = makeSetWithDirty(slot)
    accessorSlots[id] = slot
  end
  slot.dataRef = runtime.dataRef
  slot.controlRef = runtime.controlRef
  slot.source = spec.source
  slot.key = spec.key
  slot.bit = spec.bit
  rememberRuntimeSlot(runtime, id)
  return slot
end

local function configureNumberSlot(runtime, spec, scale, decimals)
  local id = slotId(runtime, spec, "number", scale, decimals)
  local slot = accessorSlots[id]
  if not slot then
    slot = {}
    slot.get = function()
      if not slot.dataRef then return 0 end
      return scaledValue(refDataTable(slot.dataRef, slot.source)[slot.key], slot.scale, slot.decimals)
    end
    slot.set = function(value)
      if not slot.dataRef then return end
      refDataTable(slot.dataRef, slot.source)[slot.key] = unscaledValue(value, slot.scale, slot.decimals)
    end
    slot.setWithDirty = makeSetWithDirty(slot)
    accessorSlots[id] = slot
  end
  slot.dataRef = runtime.dataRef
  slot.controlRef = runtime.controlRef
  slot.source = spec.source
  slot.key = spec.key
  slot.scale = scale
  slot.decimals = decimals
  rememberRuntimeSlot(runtime, id)
  return slot
end

function field_layout.releaseRuntime(runtime)
  local list = runtime and runtime._fieldLayoutSlotIds
  if not list then return end
  for i = 1, #list do
    local slot = accessorSlots[list[i]]
    if slot and slot.dataRef == runtime.dataRef then
      slot.dataRef = nil
    end
    if slot and slot.controlRef == runtime.controlRef then
      slot.controlRef = nil
    end
    list[i] = nil
  end
  runtime._fieldLayoutSlotIds = nil
end

-- Builds one editable field (number or choice) for `spec.key`, wires its
-- get/set against the right data table, applies min/max/decimals/suffix
-- (spec override, else the codec's own FIELD_META -- see metaFor() above),
-- and registers it with the runtime for enable/disable tracking.
--
-- Number fields always get a `:default()` call (Ethos alpha14+; sets the
-- value its own "reset to default" long-press gesture resets to) -- real
-- firmware default from FIELD_META when known, else an explicit 0
-- fallback, never skipped. Matches the original suite's own
-- app/lib/fields/number.lua exactly. Choice fields deliberately never get
-- one -- app/lib/fields/choice.lua doesn't either -- since a choice's
-- "default" is really just its first table entry, not a meaningful
-- firmware-defined reset target the way a number range's is.

function field_layout.buildField(runtime, line, slot, spec)
  local field
  if spec.choices then
    local access = configureChoiceSlot(runtime, spec)
    field = form.addChoiceField(line, slot, spec.choices, access.get, access.setWithDirty)
  else
    local meta = metaFor(runtime, spec)
    local min = spec.min or (meta and meta.min)
    local max = spec.max or (meta and meta.max)
    local decimals = spec.decimals or (meta and meta.decimals)
    local scale = spec.scale or (meta and meta.scale)
    assert(min and max, "field_layout.buildField: no min/max for '" .. tostring(spec.key)
      .. "' -- set spec.min/spec.max, or add a FIELD_META entry to its MSP codec module")
    local access = configureNumberSlot(runtime, spec, scale, decimals)
    field = form.addNumberField(line, slot,
      scaledValue(min, scale, decimals),
      scaledValue(max, scale, decimals),
      access.get,
      access.setWithDirty)
    local suffix = spec.suffix or (meta and meta.suffix)
    local step = spec.step or (meta and meta.step)
    if decimals then field:decimals(decimals) end
    if suffix then field:suffix(suffix) end
    if step and field.step then
      local displayStep = scaledValue(step, scale, decimals)
      field:step(displayStep > 0 and displayStep or 1)
    end
    field:default(scaledValue(spec.default or (meta and meta.default) or 0, scale, decimals))
  end
  runtime:registerField(registryKey(spec), field)
end

-- A single field on its own line, e.g. "Ground Error Decay".
local function addLine(label, parent)
  if parent and parent.addLine then
    return parent:addLine(label)
  end
  return form.addLine(label)
end

function field_layout.buildSingle(runtime, label, spec, parent)
  local line = addLine(label, parent)
  field_layout.buildField(runtime, line, nil, spec)
end

-- Several related fields sharing one line, each with its own inline
-- mini-label immediately beside it, e.g. "Error Limit: R [45] P [45]
-- Y [60]" -- matching the original suite's own compact grouping.
-- `columns` is a list of {title, spec} pairs, left to right.
--
-- **Unverified**: this mixes content-fit string hints (each mini-label)
-- with `0` (flex) hints (each field), several label/field pairs in one
-- form.getFieldSlots() call -- not yet confirmed live. See AGENTS.md's
-- "PID Controller page" section for the full reasoning: content-fit
-- string sizing is the same mechanism app/header.lua's nav buttons
-- already use successfully, and form.getFieldSlots()'s own documentation
-- says multiple `0` cells split whatever's left evenly between
-- themselves -- but app/header.lua's title bug came from a *different*
-- mixed-hint shape and was worked around rather than confirmed correct,
-- so this specific combination still needs its own live check.
function field_layout.buildGroup(runtime, groupLabel, columns, parent)
  local hints = {}
  for _, column in ipairs(columns) do
    hints[#hints + 1] = sizingHint(column.title)
    hints[#hints + 1] = 0
  end

  local line = addLine(groupLabel, parent)
  local slots = form.getFieldSlots(line, hints)
  for i, column in ipairs(columns) do
    local labelSlot = slots[(i - 1) * 2 + 1]
    local fieldSlot = slots[(i - 1) * 2 + 2]
    form.addStaticText(line, labelSlot, column.title)
    field_layout.buildField(runtime, line, fieldSlot, column.spec)
  end
end

package.loaded["rfsuite.app.field_layout"] = field_layout
return field_layout
