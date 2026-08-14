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

local requireModule = assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local pidTuning = requireModule("lib/msp_pid_tuning.lua")

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
local ROWS = {
  {label = "@i18n(app.modules.pids.roll)@", axis = "roll"},
  {label = "@i18n(app.modules.pids.pitch)@", axis = "pitch"},
  {label = "@i18n(app.modules.pids.yaw)@", axis = "yaw"},
}

local LOW_RES_WIDTH = 640
local GRID_RATIO = 0.70
local GRID_RATIO_LOW_RES = 0.74
local FIELD_GAP = 8
local FIELD_GAP_LOW_RES = 5
local RIGHT_PADDING = 20
local RIGHT_PADDING_LOW_RES = 8
local LABEL_GUTTER_MIN = 150
local LABEL_GUTTER_MIN_LOW_RES = 112
local FIELD_MIN_W = 40

-- Not every axis has every column: yaw has no "O" (offset) term.
local function fieldKeyFor(axis, colIndex)
  local suffix = COLUMN_SUFFIXES[colIndex]
  if suffix == "o" and axis == "yaw" then
    return nil
  end
  return axis .. "_" .. suffix
end

local function windowWidth()
  local w = 800
  if lcd and lcd.getWindowSize then
    local gotW = lcd.getWindowSize()
    if type(gotW) == "number" and gotW > 0 then w = gotW end
  end
  return w
end

local function lineMetrics(line)
  local slots = form.getFieldSlots(line, {0})
  local slot = slots and slots[1] or nil
  return (slot and slot.y) or 0, (slot and slot.h) or 38
end

local function pidColumnSlots(line)
  local width = windowWidth()
  local lowRes = width <= LOW_RES_WIDTH
  local numCols = #COLUMNS
  local gap = lowRes and FIELD_GAP_LOW_RES or FIELD_GAP
  local rightPadding = lowRes and RIGHT_PADDING_LOW_RES or RIGHT_PADDING
  local labelMin = lowRes and LABEL_GUTTER_MIN_LOW_RES or LABEL_GUTTER_MIN
  local gridRatio = lowRes and GRID_RATIO_LOW_RES or GRID_RATIO
  local y, h = lineMetrics(line)
  local gridW = math.floor(width * gridRatio + 0.5)
  local maxGridW = width - rightPadding - labelMin

  if gridW > maxGridW then gridW = maxGridW end
  local fieldW = math.floor((gridW - gap * (numCols - 1)) / numCols)
  if fieldW < FIELD_MIN_W then fieldW = FIELD_MIN_W end

  local totalW = fieldW * numCols + gap * (numCols - 1)
  local x = width - rightPadding - totalW
  local slots = {}
  for i = 1, numCols do
    slots[i] = {x = x + (i - 1) * (fieldW + gap), y = y, w = fieldW, h = h}
  end
  return slots
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
  local headerSlots = pidColumnSlots(headerLine)
  for i, label in ipairs(COLUMNS) do
    form.addStaticText(headerLine, headerSlots[i], label, RIGHT)
  end

  for _, row in ipairs(ROWS) do
    local line = form.addLine(row.label)
    local slots = pidColumnSlots(line)
    for colIndex = 1, #COLUMNS do
      local key = fieldKeyFor(row.axis, colIndex)
      if key then
        local meta = pidTuning.FIELD_META[key]
        local field = form.addNumberField(line, slots[colIndex], meta.min, meta.max,
          function() return dataRef.data[key] end,
          function(value) markDirty(); dataRef.data[key] = value end)
        -- No :step() call -- self-caught bug, found live: this used to
        -- hardcode :step(5) for every P/I/D/F/O/B cell on every axis.
        -- Cross-checked against both master's own tasks/scheduler/msp/
        -- api/PID_TUNING.lua (no per-field step override on any of the
        -- 17 pid_N_X fields) and rotorflight-configurator's own
        -- src/tabs/profiles.html (every PID grid cell is step="1") --
        -- the correct step for all of these is Ethos's own implicit
        -- default (1), not a shared constant.
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
