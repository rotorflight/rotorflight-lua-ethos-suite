-- Setup Wizard step: Blade pitch. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepPitch.svelte, with the EdgeTX suite's blade picture
-- (9 degrees). The pages:
--
--   safety     the motor is unplugged, the blades are measured in this step
--   coll_measure  collective held at 9 degrees (mixer override, roll and pitch at 0); the pilot measures
--              the blade pitch with a gauge and enters it, and Calibrate scales the collective input's
--              rate so 9 degrees comes out as 9 degrees (lib/setup_wizard_heli.lua's calibratedRate()).
--              A hold angle stepper sets the held angle (#2708); Calibrate is only offered at 9 degrees
--   coll_fine  the collective rate itself, in 0.1 %
--   cyc_measure  blades along the boom as for the collective, roll held at 9 degrees; Calibrate scales roll
--              and pitch together (#2709: roll is held, so the head does not have to be turned)
--   cyc_fine   both rates, in 0.1 %
--   lim_cyc, lim_coll, lim_total  the hard limits of the mixer (the same for every profile): the most
--              blade pitch the FC will ever command, in 0.1 degree
--   full       the collective pitch at full stick: one row per rate profile the profile switch picks
--              (or the active one), each profile has its own (lib/setup_wizard_rates.lua)
--
-- The values are typed in their fields. Each change is sent straight away; the rate profiles are
-- selected and read as the Rates step does it, and written back one at a time (Discard puts the
-- originals back). Each input keeps its sign (its direction, set in the Control directions step).

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")
local heli = requireModule("lib/setup_wizard_heli.lua")
-- Freed when the step closes.
local OWNED = ui.notLoaded({"rfsuite.lib.msp_rc_tuning", "rfsuite.lib.msp_adjustments", "rfsuite.lib.msp_status",
  "rfsuite.lib.msp_select_profile", "rfsuite.lib.setup_wizard_rates", "rfsuite.lib.setup_wizard_adjust"})
local adjMsp = requireModule("lib/msp_adjustments.lua")
local rcTuning = requireModule("lib/msp_rc_tuning.lua")
local status = requireModule("lib/msp_status.lua")
local selectMsp = requireModule("lib/msp_select_profile.lua")
local R = requireModule("lib/setup_wizard_rates.lua")
local A = requireModule("lib/setup_wizard_adjust.lua")

local T = {
  title = "@i18n(app.modules.setup_wizard.pit_title)@",
  intro = "@i18n(app.modules.setup_wizard.pit_intro)@",
  safety = "@i18n(app.modules.setup_wizard.lvl_safety)@",
  motorOff = "@i18n(app.modules.setup_wizard.lvl_motor_off)@",
  collTitle = "@i18n(app.modules.setup_wizard.pit_coll_title)@",
  collText = "@i18n(app.modules.setup_wizard.pit_coll_text)@",
  cycTitle = "@i18n(app.modules.setup_wizard.pit_cyc_title)@",
  cycText = "@i18n(app.modules.setup_wizard.pit_cyc_text)@",
  fineText = "@i18n(app.modules.setup_wizard.pit_fine_text)@",
  measured = "@i18n(app.modules.setup_wizard.pit_measured)@",
  rate = "@i18n(app.modules.setup_wizard.pit_rate)@",
  calibrate = "@i18n(app.modules.setup_wizard.pit_calibrate)@",
  calibrated = "@i18n(app.modules.setup_wizard.pit_calibrated)@",
  checkZero = "@i18n(app.modules.setup_wizard.pit_check_zero)@",
  backNine = "@i18n(app.modules.setup_wizard.pit_back_nine)@",
  holdAngle = "@i18n(app.modules.setup_wizard.pit_hold_angle)@",
  limCycTitle = "@i18n(app.modules.setup_wizard.pit_lim_cyc_title)@",
  limCollTitle = "@i18n(app.modules.setup_wizard.pit_lim_coll_title)@",
  limTotalTitle = "@i18n(app.modules.setup_wizard.pit_lim_total_title)@",
  limText = "@i18n(app.modules.setup_wizard.pit_lim_text)@",
  limTotalText = "@i18n(app.modules.setup_wizard.pit_lim_total_text)@",
  limit = "@i18n(app.modules.setup_wizard.pit_limit)@",
  suggest = "@i18n(app.modules.setup_wizard.pit_suggest_fmt)@",
  fullTitle = "@i18n(app.modules.setup_wizard.pit_full_title)@",
  fullText = "@i18n(app.modules.setup_wizard.pit_full_text)@",
  actualNote = "@i18n(app.modules.setup_wizard.rates_actual_note)@",
  profileFmt = "@i18n(app.modules.setup_wizard.pit_profile_fmt)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
  loading = "@i18n(app.msg_loading)@",
  loadFailed = "@i18n(app.msg_load_failed_body)@",
}

local PICTURE_W, PICTURE_H = 220, 160
local TEST_DEGREES = 9
local DEG = "\194\176"
local TEST_RAW = heli.swashRaw(TEST_DEGREES)
-- The pages that hold an axis, and the axis each holds at the angle asked for. The measure pages
-- hold the angle on their stepper (#2708), which can be 0 to check the gauge there (#2706); the fine
-- pages always hold at 9.
local HOLD_PAGES = {coll_measure = true, coll_fine = true, cyc_measure = true, cyc_fine = true}
local CHECK_DEGREES = 0
-- The most the stepper holds, tenths of a degree: the full range of the swash override (1000 = 12 degrees).
local HOLD_MAX = 120

local function holdAt(name, degrees)
  local raw = heli.swashRaw(degrees)
  if name == "coll_measure" or name == "coll_fine" then return {roll = 0, pitch = 0, collective = raw} end
  -- Cyclic: roll is held at the angle, so the blades stay along the boom (#2709).
  return {roll = raw, pitch = 0, collective = 0}
end

local function sameHold(a, b)
  return a ~= nil and b ~= nil and a.roll == b.roll and a.pitch == b.pitch and a.collective == b.collective
end

-- The pages before the rate profiles, in order; `group` says which inputs a page works on.
local BASE_PAGES = {"coll_measure", "coll_fine", "cyc_measure", "cyc_fine", "lim_cyc", "lim_coll", "lim_total"}
local GROUP = {
  coll_measure = {"collective"}, coll_fine = {"collective"},
  cyc_measure = {"roll", "pitch"}, cyc_fine = {"roll", "pitch"},
  lim_cyc = {"roll", "pitch"}, lim_coll = {"collective"},
}
local MEASURE_MIN, MEASURE_MAX = 10, 300   -- tenths of a degree
local RATE_MIN, RATE_MAX = 200, 2000       -- 0.1 %
-- Limits in tenths of a degree: maximum and suggested value.
local LIMIT_MAX = {lim_cyc = 200, lim_coll = 200, lim_total = 360}
local LIMIT_SUGGEST = {lim_cyc = 100, lim_coll = 120}
-- The collective at full stick: rcRates_4 is one byte, 12.5 degrees per 100 (see R.collectiveFullStick).
local FULL_MAX = 319                       -- tenths of a degree
local FULL_TENTHS_PER_RAW = 1.25

local SLOT_COUNT = adjMsp.RANGE_COUNT
local RATE_FUNCTION = A.ADJ.RATE_PROFILE

-- Runs the steps one after another: each one sends a message and calls its `next` from the reply.
-- `done(ok)` runs at the end.
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
  -- The first page: the blades at zero pitch, the EdgeTX suite picture (not a swash picture).
  local safetyPicture = art.image("pitch-0", PICTURE_W, PICTURE_H)
  local pitchPicture = art.image("pitch-9", PICTURE_W, PICTURE_H)

  local screen = "safety"
  local answers = {motor = false}
  local measured = TEST_DEGREES * 10   -- tenths of a degree
  local calibratedNote = false
  local holding = nil                  -- the hold table sent, or nil
  local heldDeg = TEST_DEGREES         -- the angle the measure page holds: 9, or 0 to check the gauge (#2706)

  -- The rate profiles of the FC (0-based indexes), read as the Rates step reads them.
  local activeIndex = nil
  local indexes = {}                   -- the profiles this step sets
  local tunings = {}                   -- index -> RC_TUNING as read or written
  local originals = {}                 -- index -> RC_TUNING as read, for Discard
  local ranges = {}
  local loaded, loadFailed = false, false
  local writing = false
  local queued = {}                    -- index -> the tuning to write next

  -- Writes and reads of the FC's rate profiles -----------------------------

  local function selectStep(index)
    return function(next)
      bus.publish("msp.request", selectMsp.buildWriteMessage(index + R.RATE_PROFILE_MASK,
        function() next(true) end, function() next(false) end))
    end
  end

  local function readStep(index)
    return function(next)
      bus.publish("msp.request", rcTuning.buildReadMessage(function(t)
        tunings[index] = t
        originals[index] = R.copy(t)
        next(true)
      end, function() next(false) end))
    end
  end

  local function writeStep(index, tuning)
    return function(next)
      bus.publish("msp.request", rcTuning.buildWriteMessage(tuning,
        function() next(true) end, function() next(false) end))
    end
  end

  -- Selects the active profile again, whatever happened before.
  local function backToActive()
    if activeIndex == nil then return end
    bus.publish("msp.request", selectMsp.buildWriteMessage(activeIndex + R.RATE_PROFILE_MASK))
  end

  -- One write at a time: the newest tuning of each profile goes out after the one before it.
  local flush
  flush = function()
    if writing then return end
    local index = nil
    for k in pairs(queued) do index = k break end
    if index == nil then return end
    local tuning = queued[index]
    queued[index] = nil
    writing = true
    local steps = {}
    if activeIndex ~= index then steps[#steps + 1] = selectStep(index) end
    steps[#steps + 1] = writeStep(index, tuning)
    if activeIndex ~= index then steps[#steps + 1] = selectStep(activeIndex) end
    chain(steps, function(ok)
      writing = false
      if ok == false then backToActive() end
      flush()
    end)
  end

  -- Reads the status and the adjustment slots, then the rates of each profile the switch picks.
  local function startLoad()
    local steps = {}
    steps[#steps + 1] = function(next)
      bus.publish("msp.request", status.buildReadMessage(function(d)
        activeIndex = tonumber(d and d.current_control_rate_profile_index) or 0
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
      indexes = {}
      if A.profileMode(ranges) == "both" then
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
        loaded = read == true
        wiz.rebuild()
      end)
    end)
  end
  startLoad()

  -- The pages ----------------------------------------------------------------

  local function pageList()
    local list = {}
    for _, name in ipairs(BASE_PAGES) do list[#list + 1] = name end
    if #indexes > 0 then list[#list + 1] = "full" end
    return list
  end

  local function pageIndex(name)
    for i, s in ipairs(pageList()) do
      if s == name then return i end
    end
    return nil
  end

  local function hold()
    if not HOLD_PAGES[screen] then
      if holding then wiz.releaseAxes() end
      holding = nil
      return
    end
    local deg = (screen == "coll_measure" or screen == "cyc_measure") and heldDeg or TEST_DEGREES
    local want = holdAt(screen, deg)
    if not sameHold(holding, want) then
      holding = wiz.holdAxes(want) and want or nil
    end
  end

  local function go(name)
    screen = name
    calibratedNote = false
    measured = TEST_DEGREES * 10
    heldDeg = TEST_DEGREES
    hold()
    wiz.rebuild()
  end

  local function forward()
    local list = pageList()
    local i = pageIndex(screen)
    if i and i < #list then go(list[i + 1]) end
  end

  local function backward()
    local list = pageList()
    local i = pageIndex(screen)
    if i == nil or i <= 1 then go("safety") else go(list[i - 1]) end
  end

  local function calibrate()
    for _, axis in ipairs(GROUP[screen]) do
      wiz.editInput(axis, function(input)
        input.rate = heli.calibratedRate(input.rate, TEST_DEGREES, measured / 10)
      end)
    end
    measured = TEST_DEGREES * 10
    calibratedNote = true
    wiz.rebuild()
  end

  -- A rate as a number field in 0.1 %, its sign kept (the direction the Control directions step set).
  local function rateRow(axis)
    return {label = T.rate .. " " .. wiz.roleName(axis), number = {RATE_MIN, RATE_MAX,
      function()
        local input = wiz.inputs[axis]
        return math.abs(input and input.rate or 0)
      end,
      function(value)
        wiz.editInput(axis, function(input)
          local sign = (input.rate or 0) < 0 and -1 or 1
          input.rate = sign * heli.clamp(math.floor(value + 0.5), RATE_MIN, RATE_MAX)
        end)
      end,
      "%", 1}}
  end

  -- Current limit, tenths of a degree.
  local function limitTenths(name)
    if name == "lim_total" then
      local mix = wiz.mixConfig()
      return heli.round(heli.limitDegrees(mix and mix.swash_pitch_limit or 0) * 10)
    end
    local input = wiz.inputs[GROUP[name][1]]
    return heli.round(heli.limitDegrees(input and input.max or 0) * 10)
  end

  local function setLimit(name, tenths)
    tenths = heli.clamp(tenths, 0, LIMIT_MAX[name])
    local raw = heli.limitRaw(tenths / 10)
    if name == "lim_total" then
      wiz.editMix(function(m) m.swash_pitch_limit = raw end)
    else
      for _, axis in ipairs(GROUP[name]) do
        wiz.editInput(axis, function(input)
          input.min = -raw
          input.max = raw
        end)
      end
    end
  end

  -- The collective at full stick of one rate profile, tenths of a degree.
  local function fullTenths(index)
    local t = tunings[index]
    if not t then return 0 end
    return math.floor(R.collectiveFullStick(t) * 10 + 0.5)
  end

  local function setFullStick(index, tenths)
    local current = tunings[index]
    if not current or not originals[index] or not R.collectiveSettable(current) then return end
    local raw = heli.clamp(math.floor(tenths / FULL_TENTHS_PER_RAW + 0.5), 0, 255)
    if math.floor(current.rcRates_4 or 0) == raw then return end
    local written = R.copy(current)
    written.rcRates_4 = raw
    tunings[index] = written
    wiz.change("pitch_rates_" .. index, R.copy(originals[index]), function(o)
      tunings[index] = R.copy(o)
      queued[index] = o
      flush()
    end)
    queued[index] = written
    flush()
  end

  -- Each page ends with the same row: Back, the way forward (the footer's Save and continue on the last).
  local function finish(field, back, forwardSpec)
    local rowField = scr:row(back, nil, forwardSpec)
    return field or rowField
  end

  local function buildSafety()
    scr:text(T.title, T.safety)
    scr:step(1, #pageList() + 1)
    scr:picture(safetyPicture)
    return scr:safety(answers, {{key = "motor", label = T.motorOff}}, T.start, function()
      go(pageList()[1])
    end, {
      {note = T.intro, plain = true},
    })
  end

  -- The most the stepper holds on this page, tenths of a degree: the stored limit of the page's
  -- first axis, but at least 9 degrees (so the calibration angle is always reachable) and at most the
  -- swash's full range.
  local function holdMaxTenths(name)
    return math.min(HOLD_MAX, math.max(limitTenths(name), TEST_DEGREES * 10))
  end

  -- Holds the angle the stepper sets, either side of zero: the negative side checks the collective
  -- geometry (-10 after +10). Calibrate counts from 9 degrees, so any other angle is only held
  -- to look at the gauge (#2708).
  local function setHeld(tenths)
    local limit = holdMaxTenths(screen)
    heldDeg = heli.clamp(math.floor(tenths + 0.5), -limit, limit) / 10
    hold()
    wiz.rebuild()
  end

  -- Between 9 degrees and 0 degrees (to check the gauge there), on the measure page (#2706).
  local function toggleCheck()
    heldDeg = heldDeg == TEST_DEGREES and CHECK_DEGREES or TEST_DEGREES
    hold()
    wiz.rebuild()
  end

  local function buildMeasure(name, back, forwardSpec)
    local coll = name == "coll_measure"
    scr:text(coll and T.collTitle or T.cycTitle, coll and T.collText or T.cycText)
    scr:picture(pitchPicture)
    local rows = {}
    rows[#rows + 1] = {label = T.holdAngle, number = {-holdMaxTenths(name), holdMaxTenths(name),
      function() return heli.round(heldDeg * 10) end,
      function(value) setHeld(value) end,
      DEG, 1}}
    -- Away from 9 degrees the page only holds the angle: nothing is measured or calibrated there,
    -- since the calibration counts from 9 degrees (#2706).
    if heldDeg == TEST_DEGREES then
      rows[#rows + 1] = {label = T.measured, number = {MEASURE_MIN, MEASURE_MAX,
        function() return measured end,
        function(value) measured = heli.clamp(math.floor(value + 0.5), MEASURE_MIN, MEASURE_MAX) end,
        DEG, 1}}
      for _, axis in ipairs(GROUP[name]) do rows[#rows + 1] = rateRow(axis) end
      rows[#rows + 1] = {answer = T.calibrate, press = calibrate, needsMotion = true}
      -- The result sits under the button, so the header does not move when it appears.
      if calibratedNote then rows[#rows + 1] = {note = T.calibrated} end
    end
    local checkAnswer = heldDeg == TEST_DEGREES and T.checkZero or T.backNine
    rows[#rows + 1] = {answer = checkAnswer, press = toggleCheck, needsMotion = true}
    return finish(scr:checks(rows), back, forwardSpec)
  end

  local function buildFine(name, back, forwardSpec)
    local coll = name == "coll_fine"
    scr:text(coll and T.collTitle or T.cycTitle, T.fineText)
    scr:picture(pitchPicture)
    local rows = {}
    for _, axis in ipairs(GROUP[name]) do rows[#rows + 1] = rateRow(axis) end
    return finish(scr:checks(rows), back, forwardSpec)
  end

  local function buildLimit(name, back, forwardSpec)
    local total = name == "lim_total"
    local title = (name == "lim_cyc" and T.limCycTitle) or (name == "lim_coll" and T.limCollTitle) or T.limTotalTitle
    scr:text(title, total and T.limTotalText or T.limText)
    scr:picture(pitchPicture)
    local rows = {
      {label = T.limit, number = {0, LIMIT_MAX[name],
        function() return limitTenths(name) end,
        function(value) setLimit(name, math.floor(value + 0.5)) end,
        DEG, 1}},
    }
    local suggest = LIMIT_SUGGEST[name]
    if suggest then
      rows[#rows + 1] = {answer = string.format(T.suggest, suggest / 10), press = function()
        setLimit(name, suggest)
        wiz.rebuild()
      end}
    end
    return finish(scr:checks(rows), back, forwardSpec)
  end

  -- One page for all rate profiles the switch picks: a row each for its collective at full stick.
  local function buildFull(back, forwardSpec)
    local rows = {}
    local actual = false
    for _, index in ipairs(indexes) do
      if tunings[index] and R.collectiveSettable(tunings[index]) then
        rows[#rows + 1] = {label = string.format(T.profileFmt, index + 1), number = {0, FULL_MAX,
          function() return fullTenths(index) end,
          function(value) setFullStick(index, math.floor(value + 0.5)) end,
          DEG, 1}}
      elseif tunings[index] then
        actual = true
      end
    end
    local ready = #rows > 0
    local body = (ready or actual) and T.fullText or (loadFailed and T.loadFailed or T.loading)
    scr:text(T.fullTitle, body, actual and T.actualNote or nil)
    scr:picture(pitchPicture)
    return finish(ready and scr:checks(rows) or nil, back, forwardSpec)
  end

  function self.build()
    scr:begin()
    hold()
    if screen == "safety" then return buildSafety() end
    local list = pageList()
    local i = pageIndex(screen) or 1
    scr:step(i + 1, #list + 1)
    -- The way forward: Next, and on the last page the footer's Save and continue (or Save and finish).
    local forwardSpec = i < #list and {text = T.next, press = forward} or wiz.forward()
    local back = backward
    if screen == "coll_measure" or screen == "cyc_measure" then return buildMeasure(screen, back, forwardSpec) end
    if screen == "coll_fine" or screen == "cyc_fine" then return buildFine(screen, back, forwardSpec) end
    if LIMIT_MAX[screen] then return buildLimit(screen, back, forwardSpec) end
    if screen == "full" then return buildFull(back, forwardSpec) end
    return finish(nil, back, forwardSpec)
  end

  function self.paint() scr:paint() end

  local lastCanMove = nil
  function self.wakeup()
    local canMove = wiz.canMove()
    if canMove ~= lastCanMove then
      lastCanMove = canMove
      if canMove and HOLD_PAGES[screen] and not holding then hold() end
      scr:refresh()
    end
  end

  function self.released()
    holding = nil
    lastCanMove = nil
    scr:refresh()
  end

  return self
end

return {new = new, owned = OWNED}
