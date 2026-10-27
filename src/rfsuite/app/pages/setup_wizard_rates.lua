-- Setup Wizard step: Rates. Opened by app/pages/setup_wizard.lua.
--
-- The radio's version of rotorflight-configurator's StepRates.svelte, as the
-- EdgeTX and Ethos rates pages do it: one page per rate profile the profile switch
-- picks (only those; without a switch, the active one). Each page shows the rate
-- curve, and the flying style to give it: Trainer, Sport or 3D. The row Custom is
-- ticked when the rates match none of the styles.
--
--   prepare   blades off and servos unplugged, both on before Start
--   profile   one page per rate profile (the curve, the styles)
--   done      what each profile is set to, and whether Next or Save and continue
--
-- The rates are read per profile on entry: each is selected (MSP_SELECT_SETTING
-- with the rate profile mask), read (MSP_RC_TUNING), and the active one selected
-- again. A chosen style is written the same way, registered with wiz.change() for
-- Discard. Writes run one after another in the background task.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")
-- Freed when the step closes.
local OWNED = ui.notLoaded({"rfsuite.lib.msp_rc_tuning", "rfsuite.lib.msp_adjustments",
  "rfsuite.lib.msp_status", "rfsuite.lib.setup_wizard_rates"})
local adjMsp = requireModule("lib/msp_adjustments.lua")
local rcTuning = requireModule("lib/msp_rc_tuning.lua")
local status = requireModule("lib/msp_status.lua")
local selectMsp = requireModule("lib/msp_select_profile.lua")
local R = requireModule("lib/setup_wizard_rates.lua")
local A = requireModule("lib/setup_wizard_adjust.lua")

local floor = math.floor

local T = {
  title = "@i18n(app.modules.setup_wizard.step_rates)@",
  prepareTitle = "@i18n(app.modules.setup_wizard.rcv_prepare_title)@",
  intro = "@i18n(app.modules.setup_wizard.rates_intro)@",
  unplugged = "@i18n(app.modules.setup_wizard.sen_servos_unplugged)@",
  blades = "@i18n(app.modules.setup_wizard.sen_blades_removed)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
  pageTitle = "@i18n(app.modules.setup_wizard.rates_page_fmt)@",
  pagePos = "@i18n(app.modules.setup_wizard.rates_position_fmt)@",
  pageText = "@i18n(app.modules.setup_wizard.rates_page_text)@",
  custom = "@i18n(app.modules.setup_wizard.rates_custom)@",
  noneMatches = "@i18n(app.modules.setup_wizard.rates_none_matches)@",
  actualNote = "@i18n(app.modules.setup_wizard.rates_actual_note)@",
  values = "@i18n(app.modules.setup_wizard.rates_values_fmt)@",
  collective = "@i18n(app.modules.setup_wizard.rates_collective_fmt)@",
  cyclic = "@i18n(app.modules.setup_wizard.rates_cyclic_fmt)@",
  yaw = "@i18n(app.modules.setup_wizard.rates_yaw_fmt)@",
  typeShape = "@i18n(app.modules.setup_wizard.rates_type_fmt)@",
  typeRotorflight = "@i18n(app.modules.setup_wizard.rates_type_rotorflight)@",
  typeActual = "@i18n(app.modules.setup_wizard.rates_type_actual)@",
  axisCyclic = "@i18n(app.modules.setup_wizard.rates_axis_cyclic)@",
  axisYaw = "@i18n(app.modules.setup_wizard.rates_axis_yaw)@",
  axisCollective = "@i18n(app.modules.setup_wizard.rates_axis_collective)@",
  legendValue = "@i18n(app.modules.setup_wizard.rates_legend_value)@",
  legendShape = "@i18n(app.modules.setup_wizard.rates_legend_shape)@",
  legendCollective = "@i18n(app.modules.setup_wizard.rates_legend_collective)@",
  busy = "@i18n(app.modules.setup_wizard.rates_busy)@",
  doneTitle = "@i18n(app.modules.setup_wizard.rates_done_title)@",
  doneKeep = "@i18n(app.modules.setup_wizard.rates_done_keep)@",
  doneSave = "@i18n(app.modules.setup_wizard.rates_done_save)@",
  rowFmt = "@i18n(app.modules.setup_wizard.rates_row_fmt)@",
  loading = "@i18n(app.msg_loading)@",
  loadFailed = "@i18n(app.msg_load_failed_body)@",
}

local STYLE_TEXT = {
  trainer = "@i18n(app.modules.setup_wizard.rates_trainer)@",
  sport = "@i18n(app.modules.setup_wizard.rates_sport)@",
  ["3d"] = "@i18n(app.modules.setup_wizard.rates_3d)@",
}

local SLOT_COUNT = adjMsp.RANGE_COUNT
local RATE_FUNCTION = A.ADJ.RATE_PROFILE

-- Runs the steps one after another: each one sends a message and calls its
-- `next` from the reply. `done(ok)` runs at the end.
local function chain(steps, done)
  local i = 0
  local function nextStep(ok)
    if ok == false then
      if done then done(false) end
      return
    end
    i = i + 1
    local step = steps[i]
    if not step then
      if done then done(true) end
      return
    end
    step(nextStep)
  end
  nextStep(true)
end

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  self.liveRc = nil

  local screen = "prepare"
  local answers = {blades = false, unplugged = false}
  local answered = nil
  local loadFailed = false
  local busy = false
  local failedWrite = false

  local activeIndex = nil       -- the rate profile the FC is on (0-based)
  local profileCount = nil      -- the rate profiles the FC has
  local ranges = {}             -- the adjustment ranges (for the switch)
  local indexes = {}            -- the rate profiles this step sets (0-based)
  local onSwitch = false
  local tunings = {}            -- index -> RC_TUNING as read or written
  local pages = {}              -- "p1".. -> index
  local summaryTable = {heads = {}, rows = {}}  -- the done page's table, from its build

  local picture = art.image("rates-inv", 140, 140, true)
  local screens = {"prepare"}

  -- Writes and reads of the FC's rate profiles -------------------------------

  local function selectStep(index)
    return function(next)
      bus.publish("msp.request", selectMsp.buildWriteMessage(index + R.RATE_PROFILE_MASK,
        function() next(true) end, function() failedWrite = true; next(false) end))
    end
  end

  local function readStep(index)
    return function(next)
      bus.publish("msp.request", rcTuning.buildReadMessage(function(t)
        tunings[index] = t
        next(true)
      end, function() next(false) end))
    end
  end

  local function writeStep(index, tuning)
    return function(next)
      bus.publish("msp.request", rcTuning.buildWriteMessage(tuning,
        function() next(true) end, function() failedWrite = true; next(false) end))
    end
  end

  -- Selects the active profile again, whatever happened before.
  local function backToActive()
    if activeIndex == nil then return end
    bus.publish("msp.request", selectMsp.buildWriteMessage(activeIndex + R.RATE_PROFILE_MASK))
  end

  local function finishBusy(ok)
    busy = false
    if ok == false then
      failedWrite = true
      backToActive()
    end
    wiz.rebuild()
  end

  -- Reads the status and the adjustment slots, then the rates of each profile.
  local function startLoad()
    local steps = {}
    steps[#steps + 1] = function(next)
      bus.publish("msp.request", status.buildReadMessage(function(d)
        activeIndex = tonumber(d and d.current_control_rate_profile_index) or 0
        profileCount = tonumber(d and d.control_rate_profile_count) or 1
        next(true)
      end, function() next(false) end))
    end
    for slot = 1, SLOT_COUNT do
      steps[#steps + 1] = function(next)
        bus.publish("msp.request", adjMsp.buildReadSlotMessage(slot, function(range)
          ranges[slot] = range
          next(true)
        end, function() next(false) end))
      end
    end
    chain(steps, function(ok)
      if not ok then
        loadFailed = true
        wiz.rebuild()
        return
      end
      -- The profiles on the switch: the rate range's positions; else the active one.
      indexes = {}
      onSwitch = A.profileMode(ranges) == "both"
      if onSwitch then
        local rate = A.rangeOf(ranges, RATE_FUNCTION)
        for i = rate.adjMin, rate.adjMax do indexes[#indexes + 1] = i - 1 end
      else
        indexes[1] = activeIndex
      end
      local reads = {}
      for _, index in ipairs(indexes) do
        if index ~= activeIndex then reads[#reads + 1] = selectStep(index) end
        reads[#reads + 1] = readStep(index)
      end
      reads[#reads + 1] = selectStep(activeIndex)
      chain(reads, function(read)
        if not read then
          loadFailed = true
          backToActive()
        end
        for k, index in ipairs(indexes) do pages["p" .. k] = index end
        for k = 1, #indexes do screens[#screens + 1] = "p" .. k end
        screens[#screens + 1] = "done"
        wiz.rebuild()
      end)
    end)
  end
  startLoad()

  -- Choosing a style: the profile's rates change on the FC (and the Discard
  -- puts the originals back), one profile at a time.
  local function chooseStyle(index, styleKey)
    if busy then return end
    local style = R.styleByKey(styleKey)
    local current = tunings[index]
    if not style or not current then return end
    if R.matchingStyle(current) == styleKey then return end
    busy = true
    local original = R.copy(current)
    local written = R.applyStyle(current, style)
    wiz.change("rates_" .. index, original, function(o)
      local steps = {}
      if activeIndex ~= index then steps[#steps + 1] = selectStep(index) end
      steps[#steps + 1] = writeStep(index, o)
      if activeIndex ~= index then steps[#steps + 1] = selectStep(activeIndex) end
      chain(steps)
    end)
    local steps = {}
    if activeIndex ~= index then steps[#steps + 1] = selectStep(index) end
    steps[#steps + 1] = writeStep(index, written)
    if activeIndex ~= index then steps[#steps + 1] = selectStep(activeIndex) end
    chain(steps, function(ok)
      if ok then tunings[index] = written end
      finishBusy(ok)
    end)
  end

  -- Screens -----------------------------------------------------------------

  local function screenIndex(name)
    for i, s in ipairs(screens) do if s == name then return i end end
    return 1
  end

  local function neighbour(delta)
    return screens[screenIndex(screen) + delta]
  end

  local function go(name)
    screen, answered = name, nil
    wiz.rebuild()
  end

  -- The curve of one profile in the area the page leaves on the left: from the
  -- centre to full stick, on a scale of 0 to MAX_DEG deg/s, with one dividing line at
  -- 200 deg/s; the rate at full stick written on the curve; the values under it.
  local curveIndex = nil
  local function drawCurve(x, y, w, h, colors)
    local t = curveIndex ~= nil and tunings[curveIndex]
    if not t then return end
    lcd.font(FONT_S)
    local _, lh = lcd.getTextSize("Ag")
    lcd.font(FONT_STD)
    local _, bh = lcd.getTextSize("Ag")
    local textH = 4 * lh + 6
    local gx, gy = x + 4, y + bh / 2 + 4
    local gw = w - 12
    local gh = h - textH - (gy - y) - 8
    local top = R.MAX_DEG
    local function yOf(deg)
      if deg > top then deg = top end
      return gy + gh - floor(deg / top * gh + 0.5)
    end
    -- The dividing line at 200 deg/s, the only grid line.
    lcd.color(colors.muted)
    local y200 = yOf(200)
    lcd.drawLine(gx, y200, gx + gw, y200)
    -- The axes: the rate along the left, the stick along the bottom.
    lcd.color(colors.text)
    lcd.drawLine(gx, gy, gx, gy + gh)
    lcd.drawLine(gx, gy + gh, gx + gw, gy + gh)
    -- The curve, from the centre (0) to full stick (1).
    lcd.color(colors.active)
    local steps = 40
    local px, py
    for i = 0, steps do
      local r = i / steps
      local deg = R.degPerSecond(t, 1, r)
      local cx = gx + floor(r * gw + 0.5)
      local cy = yOf(deg)
      if px then lcd.drawLine(px, py, cx, cy) end
      px, py = cx, cy
    end
    -- The rate at full stick, large, beside the end of the curve.
    local full = R.fullStick(t)
    local label = string.format("%d°/s", full)
    lcd.font(FONT_STD)
    local lw = lcd.getTextSize(label)
    lcd.color(colors.text)
    -- Just under the end of the curve, right-aligned to it.
    lcd.drawText(gx + gw - lw - 2, yOf(full) + 4, label, LEFT)
    -- The values under the chart, one short line each.
    local roll, yaw = R.fullStick(t)
    lcd.font(FONT_S)
    local ty = y + h - textH
    local typeName = t.rates_type == R.ROTORFLIGHT and T.typeRotorflight or T.typeActual
    local lines = {
      string.format(T.cyclic, roll, t.rcExpo_1 or 0),
      string.format(T.yaw, yaw, t.rcExpo_3 or 0),
      string.format(T.collective, R.collectiveFullStick(t)),
      string.format(T.typeShape, typeName, t.rates_1 or 0),
    }
    lcd.color(colors.text)
    for i, line in ipairs(lines) do
      local tw = lcd.getTextSize(line)
      if tw > w - 6 then line = ui.fit(line, w - 6) end
      lcd.drawText(x + 4, ty + (i - 1) * lh + 3, line, LEFT)
    end
  end

  local function pageScreen(k)
    local index = pages["p" .. k]
    local t = tunings[index]
    scr:step(k + 1, #screens)
    local title = string.format(T.pageTitle, index + 1)
    local body = (onSwitch and (string.format(T.pagePos, k) .. " ") or "") .. T.pageText
    local key = t and R.matchingStyle(t) or nil
    local accent = nil
    if t and t.rates_type ~= R.ROTORFLIGHT then
      accent = T.actualNote
    elseif t and not key then
      accent = T.noneMatches
    end
    scr:text(title, body, accent)
    curveIndex = index
    scr:draw(drawCurve)
    local rows = {}
    -- Custom is ticked when the rates match no style; it is not a choice, only the state.
    rows[#rows + 1] = {answer = T.custom, marked = key == nil and not busy and t ~= nil,
      press = function() end, disabled = busy}
    for _, style in ipairs(R.STYLES) do
      rows[#rows + 1] = {answer = STYLE_TEXT[style.key], marked = key == style.key,
        press = function() chooseStyle(index, style.key) end,
        disabled = busy or not t or t.rates_type ~= R.ROTORFLIGHT}
    end
    if busy then rows[#rows + 1] = {note = T.busy, muted = true} end
    local field = scr:checks(rows)
    local rowField = scr:row(function() go(neighbour(-1)) end, nil,
      {text = T.next, disabled = busy, press = function() go(neighbour(1)) end})
    return field or rowField
  end

  -- The summary as a table: a column per rate profile, a row per axis; each cell is
  -- the rate, the shape and the expo. Under the table, a legend of the three values.
  local function drawTable(x, y, w, h, colors)
    local cols = #summaryTable.heads
    if cols == 0 then return end
    lcd.font(FONT_S)
    local _, lh = lcd.getTextSize("Ag")
    local legend = {T.legendValue, T.legendShape, T.legendCollective}
    local legendH = #legend * lh + 6
    h = h - legendH
    local labelW = floor(w * 0.3)
    local colW = floor((w - labelW) / cols)
    local headH = lh + 8
    lcd.color(colors.muted)
    for c, head in ipairs(summaryTable.heads) do
      local hw = lcd.getTextSize(head)
      lcd.drawText(x + labelW + (c - 1) * colW + floor((colW - hw) / 2), y, head, LEFT)
    end
    local rowsN = math.max(#summaryTable.rows, 1)
    local rowH = math.min(lh * 2 + 10, floor((h - headH) / rowsN))
    for r, row in ipairs(summaryTable.rows) do
      local ry = y + headH + (r - 1) * rowH
      lcd.color(colors.muted)
      lcd.drawLine(x, ry, x + w, ry)
      local ty = ry + floor((rowH - lh) / 2)
      lcd.color(colors.text)
      lcd.drawText(x + 4, ty, row.label, LEFT)
      for c, cell in ipairs(row.cells) do
        local text = cell
        if lcd.getTextSize(text) > colW - 6 then text = ui.fit(text, colW - 6) end
        local cw = lcd.getTextSize(text)
        lcd.drawText(x + labelW + (c - 1) * colW + floor((colW - cw) / 2), ty, text, LEFT)
      end
    end
    lcd.color(colors.muted)
    local ly = y + h + 6
    for i, line in ipairs(legend) do
      if lcd.getTextSize(line) > w - 4 then line = ui.fit(line, w - 4) end
      lcd.drawText(x + 2, ly + (i - 1) * lh, line, LEFT)
    end
  end

  local function doneScreen()
    local rows = {
      {label = T.axisCyclic, cells = {}},
      {label = T.axisYaw, cells = {}},
      {label = T.axisCollective, cells = {}},
    }
    local heads = {}
    for _, index in ipairs(indexes) do
      local t = tunings[index]
      heads[#heads + 1] = string.format(T.rowFmt, index + 1)
      local cyc, yaw, coll = "-", "-", "-"
      if t then
        local roll, yawDeg = R.fullStick(t)
        cyc = string.format("%d° · %d · %d %%", roll, t.rates_1 or 0, t.rcExpo_1 or 0)
        yaw = string.format("%d° · %d · %d %%", yawDeg, t.rates_3 or 0, t.rcExpo_3 or 0)
        coll = string.format("%.1f · %d · %d %%", R.collectiveFullStick(t), t.rates_4 or 0, t.rcExpo_4 or 0)
      end
      rows[1].cells[#rows[1].cells + 1] = cyc
      rows[2].cells[#rows[2].cells + 1] = yaw
      rows[3].cells[#rows[3].cells + 1] = coll
    end
    summaryTable = {heads = heads, rows = rows}
    scr:text(T.doneTitle, wiz.hasPending() and T.doneSave or T.doneKeep)
    scr:step(#screens, #screens)
    scr:draw(drawTable)
    return scr:row(function() go(neighbour(-1)) end)
  end

  function self.build()
    scr:begin()
    if loadFailed then
      scr:text(T.title, T.loadFailed)
      return scr:row(nil)
    end
    if #screens == 1 then
      scr:text(T.title, T.loading)
      return nil
    end
    if screen == "prepare" then
      scr:text(T.prepareTitle, T.intro)
      scr:picture(picture)
      scr:step(1, #screens)
      -- Safety confirmation toggles: 1-click toggle buttons (No/Yes). Start follows once both are Yes.
      local function toggle(key, index)
        return {function() return answers[key] == true end, function(v)
          answers[key], answered = v and true or false, index
          wiz.rebuild()
        end}
      end
      local ready = answers.unplugged and answers.blades
      local answerField = scr:checks({
        {label = T.unplugged, toggle = toggle("unplugged", 1)},
        {label = T.blades, toggle = toggle("blades", 2)},
      }, (not ready) and (answered or (not answers.unplugged and 1) or 2) or nil)
      answered = nil
      local rowField = scr:row(nil, {{text = T.start, primary = ready, disabled = not ready,
        press = function() go(screens[2]) end}})
      return answerField or rowField
    elseif screen == "done" then
      return doneScreen()
    end
    local k = tonumber(screen:match("^p(%d+)$"))
    if k then return pageScreen(k) end
    return nil
  end

  function self.paint() scr:paint() end

  function self.wakeup(now)
    if busy then wiz.invalidate() end
  end

  function self.released() scr:refresh() end
  function self.leave() end

  return self
end

return {new = new, owned = OWNED}
