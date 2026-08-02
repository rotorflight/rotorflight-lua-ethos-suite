-- PID editor page. Loaded on demand (plain loadfile) only
-- when the user opens "PIDs" from the system tool's main menu -- see
-- app/tool.lua.
--
-- Grid layout (row = axis, column = P/I/D/F/O/B) matches the original
-- suite's app/modules/pids/pids.lua, built with form.getFieldSlots()
-- rather than that file's manual absolute-pixel math (which depends on
-- per-radio template constants this rebuild doesn't have).
--
-- Everything else -- dialog/busy/save/reload/confirm state, long-press-
-- save, profile-switch-reload -- comes from app/page_runtime.lua, shared
-- with app/pages/pid_controller.lua. See that file's own header comment
-- for the full story of what it owns and why (several live-caught bugs
-- baked into its behavior); this file only owns the MSP_PID_TUNING codec
-- (lib/msp_pid_tuning.lua) and the P/I/D/F/O/B grid below.
--
-- Known limitation: this reads/writes whatever PID profile is currently
-- active on the flight controller -- there is no profile-switcher UI yet
-- (MSP_PID_TUNING itself is scoped to the active profile; switching
-- profiles is a separate MSP command for a future page). There is also no
-- "armed" safety check yet, since this lite rebuild has no connection/
-- telemetry-state subsystem to check against.

local pageRuntime = assert(loadfile("app/page_runtime.lua"))()
local pidTuning = assert(loadfile("lib/msp_pid_tuning.lua"))()

local PAGE_TITLE = "@i18n(app.modules.pids.name)@"

-- COLUMNS is display text only (i18n tags, resolved at build time --
-- see .vscode/scripts/resolve_i18n_tags.py); COLUMN_SUFFIXES is the
-- separate, never-translated internal array fieldKeyFor() uses to build
-- MSP field names ("roll_p" etc.) -- the two are intentionally decoupled
-- so a translation can never change what key a field reads/writes.
local COLUMNS = {
  "@i18n(app.modules.pids.p)@", "@i18n(app.modules.pids.i)@", "@i18n(app.modules.pids.d)@",
  "@i18n(app.modules.pids.f)@", "@i18n(app.modules.pids.o)@", "@i18n(app.modules.pids.b)@",
}
local COLUMN_SUFFIXES = {"p", "i", "d", "f", "o", "b"}
local PID_STEP = 5
local ROWS = {
  {label = "@i18n(app.modules.pids.roll)@", axis = "roll"},
  {label = "@i18n(app.modules.pids.pitch)@", axis = "pitch"},
  {label = "@i18n(app.modules.pids.yaw)@", axis = "yaw"},
}

-- Not every axis has every column: yaw has no "O" (offset) term.
local function fieldKeyFor(axis, colIndex)
  local suffix = COLUMN_SUFFIXES[colIndex]
  if suffix == "o" and axis == "yaw" then
    return nil
  end
  return axis .. "_" .. suffix
end

-- opts.onBack: called to return to the menu (the header's Menu button or
-- the physical Back key -- see app/page_runtime.lua's buildChrome()).
-- opts.setEventHandler/opts.setWakeupHandler: see app/menu_container.lua
-- and app/tool.lua for how Ethos's event()/wakeup() reach a page.
local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "pids",
    mspModule = pidTuning,
    opts = opts,
    unloadPackageKeys = {"rfsuite.lib.msp_pid_tuning"},
  })

  form.clear()
  runtime:buildChrome()
  local dataRef = runtime.dataRef
  -- Captured instead of `runtime` itself in every field setter below --
  -- same "small indirection table, not the full runtime" convention this
  -- file already uses for dataRef (see its own comment above): Ethos
  -- retains some closures past this page's own lifetime, and controlRef.
  -- runtime gets nilled on dispose (app/page_runtime.lua's own
  -- PageRuntime:dispose()), so whatever gets retained here stays small
  -- instead of pinning the whole disposed PageRuntime.
  local controlRef = runtime.controlRef
  local function markDirty()
    local rt = controlRef.runtime
    if rt then rt:markDirty() end
  end

  -- A blank-but-non-empty label (" ", not "") so this line reserves the
  -- same row-label gutter width as the "Roll"/"Pitch"/"Yaw" lines below --
  -- an empty "" label reserves none, which threw the 6-slot column math
  -- out of alignment with the data rows (confirmed on a live render).
  local headerLine = form.addLine(" ")
  -- RIGHT here is a best-effort guess, not a confirmed API: no example in
  -- either reference codebase passes a 4th/alignment argument to
  -- form.addStaticText (only lcd.drawText's RIGHT/CENTERED usage is
  -- confirmed). Without it, the label renders left/centered in its
  -- (wide, equal-width) slot while the number field below is
  -- right-aligned, which is the mismatch this is meant to fix. If this
  -- errors or does nothing on-device, say so and it comes back out.
  local headerSlots = form.getFieldSlots(headerLine, {0, 0, 0, 0, 0, 0})
  for i, label in ipairs(COLUMNS) do
    form.addStaticText(headerLine, headerSlots[i], label, RIGHT)
  end

  for _, row in ipairs(ROWS) do
    local line = form.addLine(row.label)
    local slots = form.getFieldSlots(line, {0, 0, 0, 0, 0, 0})
    for colIndex = 1, #COLUMNS do
      local key = fieldKeyFor(row.axis, colIndex)
      if key then
        local meta = pidTuning.FIELD_META[key]
        local field = form.addNumberField(line, slots[colIndex], meta.min, meta.max,
          function() return dataRef.data[key] end,
          function(value) markDirty(); dataRef.data[key] = value end)
        if field.step then field:step(PID_STEP) end
        -- Ethos's own "reset to default" long-press gesture (added
        -- alpha14) resets to whatever :default() was last given -- 0 if
        -- never called -- so this is unconditional, same as
        -- app/field_layout.lua's buildField() (see its own comment for
        -- why: matches the original suite's app/lib/fields/number.lua).
        -- Defaults differ per axis/column here (e.g. roll_d defaults to
        -- 0, pitch_d to 40), hence the per-field FIELD_META lookup rather
        -- than one shared constant.
        field:default(meta.default)
        runtime:registerField(key, field)
      end
    end
  end

  runtime:loadInitial()
end

return {open = open}
