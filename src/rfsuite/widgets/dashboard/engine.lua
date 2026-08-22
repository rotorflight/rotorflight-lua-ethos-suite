-- Old dashboard render flow adapted to Lite's isolated widget.

local engine = {}
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local context = requireModule("widgets/dashboard/context.lua")

local floor = math.floor
local ceil = math.ceil
local max = math.max
local sort = table.sort

local objectsByType = {}
local boxRects = {}
local typeScratch = {}
local preparedConfig = nil
local preparedW = nil
local preparedH = nil
local preparedObjectsLoaded = false
local wakeCursor = 1
local wakePassCount = 0
local wakeCursorFailCount = 0
-- Hybrid safety cap on the very first wake pass (see wakeObjects()'s own
-- comment on why that pass is otherwise a full, unpaced sweep of every
-- box): still backstopped by wakeOne()'s own instruction-budget catch
-- below for whatever this doesn't already prevent, but proactively caps
-- the attempt so a dense theme's first tick isn't the one place that
-- catch actually has to fire. Deliberately higher than any per-tick
-- steady-state pace would be (this is a one-off, not a recurring cost),
-- and only ever a ceiling -- a theme with fewer boxes than this still
-- completes its first pass in one tick exactly as before (see
-- wakeObjects()'s own maxCount >= count clamp). Reinstated (previously
-- landed in #2277, then reverted whole-PR in #2278 along with an
-- unrelated cold-start placeholder attempt that didn't pan out -- see
-- that revert's own commit message. The pacing itself was already live-
-- tested clean on RT-RC's theme; only the placeholder half of that PR was
-- the actual problem). Reinstated now because starvation on dense custom
-- themes (aerc, kevd) turned out to be a much worse symptom than the
-- placeholder was trying to fix in the first place: a stuck/wrong reading
-- that can persist for the rest of a flight, not just a few rough cold-
-- start ticks.
local FIRST_WAKE_PASS_MAX = 4
-- Turned out NOT to be the dominant cost -- see FIRST_TYPE_LOAD_MAX below,
-- which is. Left in place regardless: it's still correct pacing for
-- wakeOne()'s own per-box work, just not what was actually tripping
-- paintObjects() on RT-RC's theme.
--
-- The real cost: prepareLayout() below drains pendingTypeQueue (one real
-- loadfile()+pcall() per distinct object TYPE the theme uses -- e.g.
-- "image/model", "gauge/bar" -- not per box instance) fully unpaced on
-- engine.paint()'s own first call, *before* wakeObjects()/paintObjects()
-- ever get a turn. Each individual loadObjectType() call is small enough
-- that none of them trips the instruction-budget guard on its own, but
-- Ethos's per-tick budget is spent across the whole paint() callback, not
-- reset per statement -- so a theme with enough distinct types can burn
-- most of that budget in this one drain alone, leaving paintObjects()
-- starting box 1 with almost nothing left.
local FIRST_TYPE_LOAD_MAX = 2
-- New (not part of the original #2277 pacing, not device-tested yet):
-- guards against a single box wedging every box behind it in boxRects
-- forever. Without this, a box whose own wakeup() is *itself* too
-- expensive to ever complete inside one tick's remaining budget -- not
-- just unlucky timing, but consistently, every single tick -- leaves
-- wakeCursor parked on that exact index permanently: wakeOne() fails at
-- the same box every tick, wakeObjects() returns false before wakeCursor
-- ever advances, and everything after it in the list (whatever box
-- happens to be laid out later, e.g. kevd's/aerc's own smart-fuel readout)
-- never gets its wakeup() called again -- which reads as a value frozen
-- at whatever it last managed to read, for as long as the theme stays on
-- screen. WAKE_CURSOR_MAX_CONSECUTIVE_FAILS caps how many times in a row
-- the *same* index is allowed to fail before wakeOne() just skips it for
-- this pass (advances the cursor anyway) instead of blocking forever --
-- that one box keeps showing its last-known value (same as any other
-- momentary sensor gap already tolerated throughout this codebase), but
-- everything behind it in the list is freed to keep updating.
local WAKE_CURSOR_MAX_CONSECUTIVE_FAILS = 3
-- Self-caught bug: dashboard.lua's STARTUP_PREP_OBJECTS_PER_TICK exists
-- specifically to pace "each box's object-type/subtype module load" across
-- many wakeup ticks (see its own comment) -- but that pacing only ever
-- reached wakeObjects() below, which paces *wakeOne()* (a box's own
-- object.wakeup(), mostly first sensor-source resolution). The actual
-- loadfile() of every distinct object type on screen happened synchronously,
-- all at once, inside prepareLayout() (via loadObjects()/loadPreparedObjects()
-- below) on whichever single tick first needed real objects -- for a theme
-- with a dozen-plus distinct box types, that's a dozen-plus loadfile+pcall
-- calls back to back in one frame, which is exactly the "radio hangs for a
-- moment" feel right after the very first connect of a session (later
-- reconnects don't show it, since objectsByType below never gets cleared,
-- so almost every type is already cached by then). pendingTypeQueue/
-- pendingTypeCursor let that loadfile burst itself be paced the same
-- maxCount-per-call way wakeObjects() already paces per-box wakeup.
local pendingTypeQueue = {}
local pendingTypeCursor = 1
local INSTRUCTION_BUDGET_ERROR = "Max instructions count reached"

local function isInstructionBudgetError(err)
  return type(err) == "string" and string.find(err, INSTRUCTION_BUDGET_ERROR, 1, true) ~= nil
end

local function clearArray(t)
  for i = #t, 1, -1 do t[i] = nil end
end

local function resolveMaybe(value)
  if type(value) == "function" then return value() end
  return value
end

local function adjustDimension(dim, cells, padCount, pad)
  return dim - ((dim - padCount * pad) % cells)
end

local function getBoxSize(box, boxWidth, boxHeight, padding, widgetW, widgetH)
  if box.w_pct and box.h_pct then
    local wp = box.w_pct > 1 and box.w_pct / 100 or box.w_pct
    local hp = box.h_pct > 1 and box.h_pct / 100 or box.h_pct
    return floor(wp * widgetW), floor(hp * widgetH)
  elseif box.w and box.h then
    return tonumber(box.w) or boxWidth, tonumber(box.h) or boxHeight
  elseif box.colspan or box.rowspan then
    local colspan = box.colspan or 1
    local rowspan = box.rowspan or 1
    return floor(colspan * boxWidth + (colspan - 1) * padding),
      floor(rowspan * boxHeight + (rowspan - 1) * padding)
  end
  return boxWidth, boxHeight
end

local function getBoxPosition(box, boxW, boxH, cellW, cellH, padding, widgetW, widgetH)
  if box.x_pct and box.y_pct then
    local xp = box.x_pct > 1 and box.x_pct / 100 or box.x_pct
    local yp = box.y_pct > 1 and box.y_pct / 100 or box.y_pct
    return floor(xp * widgetW), floor(yp * widgetH)
  elseif box.x and box.y then
    return tonumber(box.x) or 0, tonumber(box.y) or 0
  end
  local col = box.col or 1
  local row = box.row or 1
  local x = floor((col - 1) * (cellW + padding)) + (box.xOffset or 0)
  local y = floor(padding + (row - 1) * (cellH + padding))
  return x, y
end

local function buildBoxTypeList(boxes, headerBoxes)
  clearArray(typeScratch)
  for _, box in ipairs(boxes or {}) do
    if box.type then typeScratch[#typeScratch + 1] = box.type end
  end
  for _, box in ipairs(headerBoxes or {}) do
    if box.type then typeScratch[#typeScratch + 1] = box.type end
  end
  sort(typeScratch)
  return typeScratch
end

local function loadObjectType(objectType)
  if objectsByType[objectType] then return objectsByType[objectType] end
  local loader = loadfile("widgets/dashboard/objects/" .. objectType .. ".lua")
  if not loader then return nil end
  local ok, object = pcall(loader)
  if not ok then
    print("[dashboard] failed to load object " .. tostring(objectType) .. ": " .. tostring(object))
    return nil
  end
  objectsByType[objectType] = object
  return object
end

local function loadObjects(boxes, headerBoxes)
  local types = buildBoxTypeList(boxes, headerBoxes)
  for i = 1, #types do loadObjectType(types[i]) end
end

-- Rebuilds pendingTypeQueue with only the distinct, not-yet-loaded object
-- types this layout actually uses, and rewinds the drain cursor -- called
-- whenever the layout (config/screen size) changes, so a fresh set of types
-- may need loading again.
local function rebuildPendingTypeQueue(types)
  clearArray(pendingTypeQueue)
  for i = 1, #types do
    local objectType = types[i]
    if objectType and not objectsByType[objectType] then
      pendingTypeQueue[#pendingTypeQueue + 1] = objectType
    end
  end
  pendingTypeCursor = 1
end

local function buildPendingTypeQueueFromBoxes(boxes, headerBoxes)
  rebuildPendingTypeQueue(buildBoxTypeList(boxes, headerBoxes))
end

local function buildPendingTypeQueueFromRects()
  clearArray(typeScratch)
  for _, rect in ipairs(boxRects) do
    local box = rect.box
    if box and box.type then typeScratch[#typeScratch + 1] = box.type end
  end
  sort(typeScratch)
  rebuildPendingTypeQueue(typeScratch)
end

-- Loads up to maxCount not-yet-loaded object types, leaving the rest queued
-- for a later call. A nil/non-positive maxCount means "no pacing" -- drain
-- the whole queue now (matches wakeObjects()'s own nil-means-unpaced
-- convention, and preserves the original all-at-once behavior for any
-- caller that isn't the startup-warmup path). Returns true once the queue is
-- fully drained.
local function drainPendingTypes(maxCount)
  local count = #pendingTypeQueue
  if pendingTypeCursor > count then return true end

  if not maxCount or maxCount <= 0 then
    for i = pendingTypeCursor, count do loadObjectType(pendingTypeQueue[i]) end
    pendingTypeCursor = count + 1
    return true
  end

  local processed = 0
  while pendingTypeCursor <= count and processed < maxCount do
    loadObjectType(pendingTypeQueue[pendingTypeCursor])
    pendingTypeCursor = pendingTypeCursor + 1
    processed = processed + 1
  end

  return pendingTypeCursor > count
end

local function schedulerSettings(config)
  local scheduler = resolveMaybe((config or {}).scheduler)
  if type(scheduler) ~= "table" then return true, nil end
  local ratio = scheduler.spread_ratio
  if type(ratio) ~= "number" or ratio <= 0 or ratio > 1 then ratio = nil end
  return scheduler.spread_scheduling ~= false, ratio
end

local function defaultWakeRatio(count)
  if count < 0 then count = 0 end
  if count > 10 then count = 10 end
  return 1.0 - (count / 10) * 0.5
end

local function wakeupsPerCycle(count, ratio)
  if count <= 0 then return 0 end
  return max(1, ceil(count * (ratio or defaultWakeRatio(count))))
end

local function addBoxRect(rectCount, box, x, y, w, h, isHeader)
  rectCount = rectCount + 1
  local rect = boxRects[rectCount]
  if not rect then
    rect = {}
    boxRects[rectCount] = rect
  end
  rect.box = box
  rect.x = x
  rect.y = y
  rect.w = w
  rect.h = h
  rect.isHeader = isHeader == true
  return rectCount
end

local function buildRects(config, screenW, screenH)
  local layout = resolveMaybe(config.layout) or {}
  local headerLayout = resolveMaybe(config.header_layout) or {}
  local boxes = resolveMaybe(config.boxes or layout.boxes or {}) or {}
  local headerBoxes = resolveMaybe(config.header_boxes or {}) or {}

  local cols = layout.cols or 1
  local rows = layout.rows or 1
  local pad = layout.padding or 0
  local isFullScreen = context.widgets.dashboard.utils.isFullScreen(screenW, screenH)
  local headerH = isFullScreen and type(headerLayout.height) == "number" and headerLayout.height or 0
  local contentScreenH = screenH - headerH

  local w = adjustDimension(screenW, cols, cols - 1, pad)
  local h = adjustDimension(contentScreenH, rows, rows + 1, pad)
  local xOffset = floor((screenW - w) / 2)
  local contentW = w - ((cols - 1) * pad)
  local contentH = h - ((rows + 1) * pad)
  local cellW = contentW / cols
  local cellH = contentH / rows

  local rectCount = 0
  for _, box in ipairs(boxes) do
    local bw, bh = getBoxSize(box, cellW, cellH, pad, w, h)
    box.xOffset = xOffset
    local x, y = getBoxPosition(box, bw, bh, cellW, cellH, pad, w, h)
    if headerH > 0 then y = y + headerH end
    rectCount = addBoxRect(rectCount, box, x, y, bw, bh, false)
  end

  if isFullScreen and headerH > 0 and #headerBoxes > 0 then
    local hCols = headerLayout.cols or 1
    local hRows = headerLayout.rows or 1
    local hPad = headerLayout.padding or 0
    local hw = adjustDimension(screenW, hCols, hCols - 1, hPad)
    local hh = adjustDimension(headerH, hRows, hRows - 1, hPad)
    local hCellW = (hw - ((hCols - 1) * hPad)) / hCols
    local hCellH = (hh - ((hRows - 1) * hPad)) / hRows
    for _, box in ipairs(headerBoxes) do
      local bw, bh = getBoxSize(box, hCellW, hCellH, hPad, hw, hh)
      local x, y = getBoxPosition(box, bw, bh, hCellW, hCellH, hPad, hw, hh)
      rectCount = addBoxRect(rectCount, box, x, y, bw, bh, true)
    end
  end

  for i = rectCount + 1, #boxRects do boxRects[i] = nil end
  return boxes, headerBoxes
end

-- maxTypesToLoad paces the *loadfile* step the same way wakeObjects() paces
-- per-box wakeup -- nil/omitted means "load whatever's left right now" (used
-- by paint()/preload(), which need a complete frame this tick), a positive
-- number means "load at most this many not-yet-loaded types this call,
-- however many calls that takes" (used by dashboard.lua's startup warm-up).
local function prepareLayout(config, screenW, screenH, skipObjectLoad, maxTypesToLoad)
  config = config or {}
  local sameLayout = preparedConfig == config and preparedW == screenW and preparedH == screenH
  if not sameLayout then
    local boxes, headerBoxes = buildRects(config, screenW, screenH)
    -- Queued up front regardless of skipObjectLoad, so a later call that
    -- flips skipObjectLoad off (dashboard.lua's shell-only overlay phase
    -- handing off to the real startup warm-up the moment it connects) can
    -- resume draining the same queue instead of rescanning boxRects again.
    buildPendingTypeQueueFromBoxes(boxes, headerBoxes)
    preparedConfig = config
    preparedW = screenW
    preparedH = screenH
    wakeCursor = 1
    wakePassCount = 0
    wakeCursorFailCount = 0
    if skipObjectLoad then
      preparedObjectsLoaded = false
    else
      preparedObjectsLoaded = drainPendingTypes(maxTypesToLoad)
    end
    return
  end

  if not skipObjectLoad and not preparedObjectsLoaded then
    if pendingTypeCursor > #pendingTypeQueue then buildPendingTypeQueueFromRects() end
    preparedObjectsLoaded = drainPendingTypes(maxTypesToLoad)
    if preparedObjectsLoaded then
      wakeCursor = 1
      wakePassCount = 0
      wakeCursorFailCount = 0
    end
  end
end

-- Returns false (plus the error) on an instruction-budget error specifically,
-- so wakeObjects() below can pause the whole pass right there instead of
-- swallowing it and ploughing on into the next box with almost no budget
-- left -- the same distinction paintObjects() already draws via
-- isInstructionBudgetError(). Any other error is logged and treated as this
-- one box's problem only, same as before.
local function wakeOne(rect)
  local box = rect and rect.box
  local object = box and box.type and loadObjectType(box.type)
  if object and object.wakeup then
    box._dashboardRectX = rect.x
    box._dashboardRectY = rect.y
    box._dashboardRectW = rect.w
    box._dashboardRectH = rect.h
    local ok, err = pcall(object.wakeup, box)
    if not ok then
      if isInstructionBudgetError(err) then return false, err end
      print("[dashboard] object wakeup failed: " .. tostring(err))
    end
  end
  return true
end

local function finishWakePass()
  wakeCursor = 1
  wakeCursorFailCount = 0
  wakePassCount = wakePassCount + 1
  return true
end

local function wakeObjects(maxCount, config)
  local count = #boxRects
  if count == 0 then return finishWakePass() end

  -- An explicit maxCount (dashboard.lua's own STARTUP_PREP_OBJECTS_PER_TICK
  -- pacing during cold-start warm-up) is always honored, first pass or not
  -- -- that pacing exists specifically to keep the *first* pass, the most
  -- expensive one (every box's object-type module load, first sensor-
  -- source resolution), from happening as a single burst. Only a caller
  -- that passes no preference (nil) gets the default policy below: full
  -- pass on the very first call (so paint() has real content immediately
  -- once it's the one requesting wake), spread-ratio afterward.
  if maxCount == nil or maxCount <= 0 then
    local spreadScheduling, spreadRatio = schedulerSettings(config)
    if wakePassCount >= 1 and spreadScheduling ~= false then
      maxCount = wakeupsPerCycle(count, spreadRatio)
    else
      maxCount = nil
    end
  end

  -- Not a separate unpaced branch anymore: a "full pass" is just maxCount
  -- clamped to `count`, so it still runs through the same loop below and
  -- gets the same instruction-budget pause/resume behavior. A dense theme's
  -- first post-invalidate pass (every box's wakeup at once, including each
  -- box's own text-layout/geometry pre-warm) can plausibly exceed even
  -- wakeup()'s own -- looser than paint()'s, but still finite -- budget;
  -- without this, wakeOne()'s pcall silently swallowed that per-box and
  -- the *next* box in the same loop inherited an already-near-exhausted
  -- budget for the rest of the pass, cascading into most/all of the
  -- remaining boxes failing their first wakeup in one tick.
  if not maxCount or maxCount <= 0 or maxCount >= count then
    maxCount = count
  end

  local processed = 0
  while wakeCursor <= count and processed < maxCount do
    local ok, err = wakeOne(boxRects[wakeCursor])
    if not ok then
      wakeCursorFailCount = wakeCursorFailCount + 1
      if wakeCursorFailCount >= WAKE_CURSOR_MAX_CONSECUTIVE_FAILS then
        -- This exact box has now failed on its own, WAKE_CURSOR_MAX_CONSECUTIVE_FAILS
        -- ticks running -- not a one-off instruction-budget squeeze from
        -- whatever ran before it, since it's the very first thing
        -- attempted each of those ticks. Skip it for this pass rather
        -- than let it wedge wakeCursor here forever: everything after it
        -- in boxRects would otherwise never get a turn again for as long
        -- as the theme stays on screen.
        print("[dashboard] object wakeup failing repeatedly, skipping for this pass: " .. tostring(err))
        wakeCursorFailCount = 0
        wakeCursor = wakeCursor + 1
        processed = processed + 1
      else
        print("[dashboard] object wakeup budget exhausted; retrying next tick: " .. tostring(err))
        return false
      end
    else
      wakeCursorFailCount = 0
      wakeCursor = wakeCursor + 1
      processed = processed + 1
    end
  end

  if wakeCursor > count then
    return finishWakePass()
  end

  return false
end

local function drawBoxShell(rect)
  local box = rect and rect.box
  if not box then return end

  local utils = context.widgets.dashboard.utils
  local bgcolor = utils.resolveThemeColor("bgcolor", utils.getParam(box, "bgcolor"))
  if bgcolor ~= nil then utils.drawBoxBackground(rect.x, rect.y, rect.w, rect.h, bgcolor) end

  local title = utils.getParam(box, "title")
  if type(title) ~= "string" and type(title) ~= "number" then return end
  title = tostring(title)
  if title == "" then return end

  local titlefont = utils.resolveFont(utils.getParam(box, "titlefont"), FONT_XS)
  local titlepadding = utils.getParam(box, "titlepadding") or 0
  local titlepaddingleft = utils.getParam(box, "titlepaddingleft") or titlepadding
  local titlepaddingright = utils.getParam(box, "titlepaddingright") or titlepadding
  local titlepaddingtop = utils.getParam(box, "titlepaddingtop") or titlepadding
  local titlepaddingbottom = utils.getParam(box, "titlepaddingbottom") or titlepadding
  local titlepos = utils.getParam(box, "titlepos")
  local titlealign = utils.getParam(box, "titlealign")

  lcd.font(titlefont)
  local tw, th = lcd.getTextSize(title)
  tw = tw or 0
  th = th or 0

  local regionW = rect.w - titlepaddingleft - titlepaddingright
  local sx = rect.x + titlepaddingleft + (regionW - tw) / 2
  if titlealign == "left" then sx = rect.x + titlepaddingleft end
  if titlealign == "right" then sx = rect.x + titlepaddingleft + regionW - tw end
  local sy = titlepos == "bottom" and (rect.y + rect.h - titlepaddingbottom - th) or (rect.y + titlepaddingtop)

  lcd.color(utils.resolveThemeColor("titlecolor", utils.getParam(box, "titlecolor")))
  lcd.drawText(sx, sy, title)
end

local function paintShellObjects()
  for _, rect in ipairs(boxRects) do drawBoxShell(rect) end
end

local function paintObjects(widget)
  local startIndex = widget and widget.dashboardPaintRetryIndex or 1
  if startIndex < 1 then startIndex = 1 end
  if startIndex > #boxRects then
    if widget then
      widget.dashboardPaintRetryIndex = nil
      widget.dashboardInstructionBudgetRetryLogged = false
    end
    return true
  end

  for i = startIndex, #boxRects do
    local rect = boxRects[i]
    local box = rect.box
    if widget then widget.dashboardPaintRetryIndex = i end
    local object = box and box.type and loadObjectType(box.type)
    if object and object.paint then
      local ok, err = pcall(object.paint, rect.x, rect.y, rect.w, rect.h, box)
      if not ok then
        if isInstructionBudgetError(err) then
          if widget then widget.dashboardPaintRetryIndex = i end
          if not widget or widget.dashboardInstructionBudgetRetryLogged ~= true then
            print("[dashboard] object paint budget exhausted; retrying next tick: " .. tostring(err))
            if widget then widget.dashboardInstructionBudgetRetryLogged = true end
          end
          return false
        end
        print("[dashboard] object paint failed: " .. tostring(err))
      end
    end
    if widget then widget.dashboardPaintRetryIndex = i + 1 end
  end
  if widget then
    widget.dashboardPaintRetryIndex = nil
    widget.dashboardInstructionBudgetRetryLogged = false
  end
  return true
end

function engine.paint(widget, themeDef, stateDef, state, screenW, screenH)
  context.setWidget(widget)
  if context.tasks and context.tasks.telemetry and context.tasks.telemetry.collectPresentationStats then
    context.tasks.telemetry.collectPresentationStats()
  end
  prepareLayout(stateDef, screenW, screenH, false, FIRST_TYPE_LOAD_MAX)
  -- Not loaded yet (this call's cap didn't cover the whole queue): defer
  -- the rest of this frame to the next tick outright, same "false means
  -- not ready, try again" contract paintDashboard() already honors for an
  -- instruction-budget retry -- just reached here proactively instead of
  -- reactively, and before paintObjects() risks starting box 1 with an
  -- already-half-spent budget.
  if not preparedObjectsLoaded then return false end
  if wakePassCount < 1 then wakeObjects(FIRST_WAKE_PASS_MAX, stateDef) end
  local resumePaint = widget and widget.dashboardPaintRetryIndex and widget.dashboardPaintRetryIndex > 1
  if not resumePaint then context.widgets.dashboard.utils.setBackgroundColourBasedOnTheme() end
  local ok = paintObjects(widget)
  context.widgets.dashboard.utils.drawScreenBorder()
  return ok
end

function engine.paintShell(widget, stateDef, screenW, screenH)
  context.setWidget(widget)
  prepareLayout(stateDef, screenW, screenH, true)
  context.widgets.dashboard.utils.setBackgroundColourBasedOnTheme()
  paintShellObjects()
  context.widgets.dashboard.utils.drawScreenBorder()
end

function engine.preload(widget, stateDef)
  context.setWidget(widget)
  local layout = resolveMaybe((stateDef or {}).layout) or {}
  local boxes = resolveMaybe((stateDef or {}).boxes or layout.boxes or {}) or {}
  local headerBoxes = resolveMaybe((stateDef or {}).header_boxes or {}) or {}
  loadObjects(boxes, headerBoxes)
end

function engine.wakeup(widget, stateDef, screenW, screenH, options)
  context.setWidget(widget)
  -- Type-load side defaults to FIRST_TYPE_LOAD_MAX rather than "no options
  -- means unpaced" -- dashboard.lua's own wakeup() callback (see
  -- prepareDashboard()) is this function's only caller and has never
  -- actually passed options, so that old convention meant this path ran
  -- just as unpaced as engine.paint()'s first call used to. Safe to
  -- default unconditionally (every call, not just the first):
  -- prepareLayout() already no-ops once preparedObjectsLoaded is true, so
  -- this only ever matters while the type queue is still draining.
  local maxTypes = (options and options.maxTypes) or FIRST_TYPE_LOAD_MAX
  prepareLayout(stateDef, screenW, screenH, false, maxTypes)
  -- Spend this tick's budget on loading any still-pending object types
  -- before ever calling wakeObjects() -- otherwise a paced caller (dashboard.
  -- lua's startup warm-up) would still take the full loadfile burst up
  -- front via prepareLayout() and only have *wakeObjects()* paced on top of
  -- that, which is the bug this whole queue exists to close.
  if not preparedObjectsLoaded then return false, true end
  -- Wake side only defaults on the first pass (mirrors engine.paint()'s
  -- own `if wakePassCount < 1` guard around its wakeObjects() call) --
  -- past that, wakeObjects()'s own nil-means-unpaced convention needs to
  -- reach its existing ratio-based steady-state pacing (wakeupsPerCycle),
  -- which a permanent default here would silently override on every
  -- subsequent tick instead of just the cold-start one.
  local maxObjects = (options and options.maxObjects) or (wakePassCount < 1 and FIRST_WAKE_PASS_MAX or nil)
  return wakeObjects(maxObjects, stateDef), true
end

function engine.reset()
  preparedConfig = nil
  preparedW = nil
  preparedH = nil
  preparedObjectsLoaded = false
  wakeCursor = 1
  wakePassCount = 0
  wakeCursorFailCount = 0
  clearArray(pendingTypeQueue)
  pendingTypeCursor = 1
  for i = #boxRects, 1, -1 do boxRects[i] = nil end
end

return engine
