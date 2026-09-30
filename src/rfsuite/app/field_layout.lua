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
-- adding fresh retained Lua closures on every repeat visit. That pooling
-- property is load-bearing and is why the pool is never shrunk on the way
-- out -- see releaseRuntime()'s own comment for the measurement behind that.
-- The pool is instead kept small per entry (two closures, not three; see the
-- bitGet/numberGet family) and is sized off a fixed set of field shapes
-- rather than the number of pages visited, so it reaches a steady size on
-- the first tour of the app and stays there. One of several such caches
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

-- The key is exactly the set of inputs a pooled slot's behaviour depends on:
-- the page, the field/bit/source registry key, the kind, and scale/decimals.
--
-- Concatenated directly rather than assembled into a throwaway table first:
-- this runs once per buildField() call, i.e. once per field per page visit,
-- and the table form spends a 5-element table plus four intermediate
-- tostring() results to build one string that is itself garbage the moment
-- the pool lookup below completes. Measured A/B, one form per process with
-- the collector stopped so the number is allocation rather than GC timing
-- (200k calls over a spread of real shapes, the key consumed by the pool
-- lookup as it is in the real code): 162.4 B/call for the table form against
-- 26.4 B/call for this one, so ~136 B/call saved, ~84% of what the key
-- costs to build. Both forms produce a byte-identical key, so no existing
-- pool entry is orphaned by the change.
--
-- This is churn, not residency: every byte of it is collectable the moment
-- the lookup completes, so it does not show up in the pool's steady-state
-- footprint (poolStats() below). It matters because buildField() runs once
-- per field per page visit -- the full 74-page sweep builds 478 fields, so a
-- tour costs roughly 65 KB of this -- and because churn is what makes a
-- collect expensive later.
local function slotId(runtime, spec, kind, scale, decimals)
  return tostring(runtime.logTag or runtime.pageTitle or "?") .. "|"
    .. registryKey(spec) .. "|" .. kind .. "|"
    .. tostring(scale or "") .. "|" .. tostring(decimals or "")
end

local function rememberRuntimeSlot(runtime, id)
  local list = runtime._fieldLayoutSlotIds
  if not list then
    list = {}
    runtime._fieldLayoutSlotIds = list
  end
  list[#list + 1] = id
end

-- One getter/setter body per field *kind*, at module level, rather than one
-- closure each per slot. Only two of them have to be closures at all: the
-- `form` API hands the getter and the setter straight to the widget as
-- zero-/one-argument callables, so those two must capture `slot` and are
-- pooled per slot below. The plain setter does not -- it is only ever
-- called from inside the pooled dirty-marking wrapper, so it takes the slot
-- as a parameter instead and is shared by every slot in the pool.
--
-- slot.set was never reachable from outside this file: buildField() hands
-- the widget access.get and access.setWithDirty, and nothing else in the
-- codebase reads a slot. So dropping it loses no capability -- it just means
-- one less closure to keep alive per pooled field, which is worth doing
-- because a closure is a real per-entry cost. Measured on Lua 5.4 by
-- replaying every page's real field inventory (356 field shapes across 33
-- pages) through this module, full collect either side of the tour: the pool
-- holds 195 entries and costs 101.7 KB with the three closures against
-- 99.0 KB with two, i.e. ~2.7 KB off the pool, ~14 B per entry, 2.7% of the
-- pool's footprint. Identical to the last decimal across five runs.
--
-- Worth stating plainly because 2.7% is much smaller than a standalone
-- closure benchmark suggests. Built in isolation, the same slot with three
-- closures against two costs 341.3 B against 309.3 B, i.e. 32 B for the one
-- closure -- so the isolated figure is a ceiling, and the real module comes
-- in well under it at 14 B. The gap is the table: dropping slot.set as a
-- key does not shrink the table's node array, and the real pool's per-entry
-- cost is dominated by the long key string, not by anything this change
-- removes. Most of a pooled entry is not the closures.
--
-- The split is therefore a saving, not a restructuring: see the accessorSlots
-- note above for why the two closures that remain must stay pooled rather
-- than be rebuilt per visit.
local function bitGet(slot)
  if not slot.dataRef then return 0 end
  return getBit(refDataTable(slot.dataRef, slot.source)[slot.key], slot.bit)
end

local function bitSet(slot, value)
  if not slot.dataRef then return end
  local t = refDataTable(slot.dataRef, slot.source)
  t[slot.key] = setBit(t[slot.key], slot.bit, value)
end

local function choiceGet(slot)
  if not slot.dataRef then return nil end
  return refDataTable(slot.dataRef, slot.source)[slot.key]
end

local function choiceSet(slot, value)
  if not slot.dataRef then return end
  refDataTable(slot.dataRef, slot.source)[slot.key] = value
end

local function numberGet(slot)
  if not slot.dataRef then return 0 end
  return scaledValue(refDataTable(slot.dataRef, slot.source)[slot.key], slot.scale, slot.decimals)
end

local function numberSet(slot, value)
  if not slot.dataRef then return end
  refDataTable(slot.dataRef, slot.source)[slot.key] = unscaledValue(value, slot.scale, slot.decimals)
end

-- Pools a slot's dirty-marking setter wrapper the same way slot.get itself
-- is pooled -- created once per slot, not once per buildField() call, and
-- reads slot.controlRef dynamically (re-assigned below on every claim, same
-- lifecycle as slot.dataRef) rather than closing over `runtime` directly.
-- `controlRef` -- not the full runtime -- is what's safe to hold
-- indefinitely in this permanently-pooled table: page_runtime.lua's own
-- PageRuntime:dispose() nils controlRef.runtime specifically so closures
-- like this one that outlive the page still only pin a tiny emptied
-- indirection table, never the disposed runtime (and everything it
-- references) itself. See this file's own module comment for why
-- fresh-per-visit closures matter here at all.
local function makeSetWithDirty(slot, setter)
  return function(value)
    local runtime = slot.controlRef and slot.controlRef.runtime
    setter(slot, value)
    if runtime and runtime.refreshDirty then
      runtime:refreshDirty()
    elseif runtime then
      runtime:markDirty()
    end
  end
end

local function configureChoiceSlot(runtime, spec)
  local id = slotId(runtime, spec, spec.bit and "bit" or "choice")
  local slot = accessorSlots[id]
  if not slot then
    slot = {}
    if spec.bit then
      slot.get = function() return bitGet(slot) end
      slot.setWithDirty = makeSetWithDirty(slot, bitSet)
    else
      slot.get = function() return choiceGet(slot) end
      slot.setWithDirty = makeSetWithDirty(slot, choiceSet)
    end
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
    slot.get = function() return numberGet(slot) end
    slot.setWithDirty = makeSetWithDirty(slot, numberSet)
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

-- Detaches a leaving page's slots: drops the page's dataRef/controlRef
-- references so a pooled closure can never keep the disposed runtime (and
-- everything it transitively references) alive. The slots themselves stay in
-- the pool on purpose.
--
-- Evicting them here looks like the obvious completion of this loop, and was
-- proposed as such, but it is a measured regression rather than a saving.
-- §8 of docs/memory-and-module-lifecycle.md is explicit that Ethos retains
-- some `form` callback/widget allocations after `form.clear()`, which is the
-- entire reason this pool exists: the retained widget keeps the closure
-- alive, so evicting the pool entry does not free the closures, it only
-- guarantees the *next* visit builds a fresh set. Replaying every page's real
-- field inventory through this module (see poolStats() below) shows exactly
-- that -- one closure set per field per visit, growing without bound, versus
-- a pool that reaches a fixed size on the first tour and then stops. A slot
-- whose dataRef/controlRef are both nil is already down to its two closures
-- and its shape fields; the only thing left to reclaim is the table header,
-- and Lua reclaims that as soon as the retained widget lets go.
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

-- Read-only view of the pool, for measuring this module's actual footprint
-- on a radio instead of guessing at it -- `collectgarbage("count")` reports
-- live heap *plus* uncollected garbage (see lib/memstats.lua), so a heap
-- reading around a page tour cannot separate this pool's contribution from
-- anything else. Prints nothing and frees nothing on its own:
--   local n, live = field_layout.poolStats()
-- `count` is the whole pool, `live` the subset currently claimed by an open
-- page (dataRef/controlRef set). The difference is the retained-but-detached
-- tail, which is what a full collect would have to reclaim and cannot while a
-- widget still holds a closure.
function field_layout.poolStats()
  local count, live = 0, 0
  for _, slot in pairs(accessorSlots) do
    count = count + 1
    if slot.dataRef ~= nil or slot.controlRef ~= nil then
      live = live + 1
    end
  end
  return count, live
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
