-- Setup Wizard step: Blade pitch. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepPitch.svelte, without
-- the collective-at-full-stick setting (that belongs to Rates):
--
--   coll_measure  collective held at 9 degrees (mixer override, roll and
--                 pitch at 0); the pilot measures the blade pitch with a
--                 gauge and enters it, and Calibrate scales the collective
--                 input's rate so 9 degrees comes out as 9 degrees
--                 (lib/setup_wizard_heli.lua's calibratedRate())
--   coll_fine     the rate itself, +-0.1 / +-1 %, for fine adjustment
--   cyc_measure   blades turned to point left and right, pitch held at 9
--                 degrees; Calibrate scales roll and pitch together
--   cyc_fine      both rates, +-0.1 / +-1 %
--   lim_cyc       cyclic limit 0..20 degrees (roll and pitch input min/max)
--   lim_coll      collective limit 0..20 degrees (collective input min/max)
--   lim_total     total blade pitch limit 0..36 degrees (swash_pitch_limit)
--
-- Every change is sent straight away; each input keeps its sign (its
-- direction, set in the Control directions step).

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")
local heli = requireModule("lib/setup_wizard_heli.lua")

local T = {
  title = "@i18n(app.modules.setup_wizard.pit_title)@",
  intro = "@i18n(app.modules.setup_wizard.pit_intro)@",
  collTitle = "@i18n(app.modules.setup_wizard.pit_coll_title)@",
  collText = "@i18n(app.modules.setup_wizard.pit_coll_text)@",
  cycTitle = "@i18n(app.modules.setup_wizard.pit_cyc_title)@",
  cycText = "@i18n(app.modules.setup_wizard.pit_cyc_text)@",
  fineText = "@i18n(app.modules.setup_wizard.pit_fine_text)@",
  measured = "@i18n(app.modules.setup_wizard.pit_measured)@",
  rate = "@i18n(app.modules.setup_wizard.pit_rate)@",
  calibrate = "@i18n(app.modules.setup_wizard.pit_calibrate)@",
  calibrated = "@i18n(app.modules.setup_wizard.pit_calibrated)@",
  limCycTitle = "@i18n(app.modules.setup_wizard.pit_lim_cyc_title)@",
  limCollTitle = "@i18n(app.modules.setup_wizard.pit_lim_coll_title)@",
  limTotalTitle = "@i18n(app.modules.setup_wizard.pit_lim_total_title)@",
  limText = "@i18n(app.modules.setup_wizard.pit_lim_text)@",
  limTotalText = "@i18n(app.modules.setup_wizard.pit_lim_total_text)@",
  limit = "@i18n(app.modules.setup_wizard.pit_limit)@",
  suggest = "@i18n(app.modules.setup_wizard.pit_suggest_fmt)@",
  progress = "@i18n(app.modules.setup_wizard.progress_fmt)@",
  doneTitle = "@i18n(app.modules.setup_wizard.pit_done_title)@",
  done = "@i18n(app.modules.setup_wizard.pit_done)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
}

local TEST_DEGREES = 9
local DEG = "\194\176"
local TEST_RAW = heli.swashRaw(TEST_DEGREES)
local HOLD_COLL = {roll = 0, pitch = 0, collective = TEST_RAW}
local HOLD_CYC = {roll = 0, pitch = TEST_RAW, collective = 0}

-- Screens in order; `group` says which inputs a calibration screen works on.
local SCREENS = {"coll_measure", "coll_fine", "cyc_measure", "cyc_fine", "lim_cyc", "lim_coll", "lim_total"}
local GROUP = {
  coll_measure = {"collective"}, coll_fine = {"collective"},
  cyc_measure = {"roll", "pitch"}, cyc_fine = {"roll", "pitch"},
  lim_cyc = {"roll", "pitch"}, lim_coll = {"collective"},
}
local HOLDS = {coll_measure = HOLD_COLL, coll_fine = HOLD_COLL, cyc_measure = HOLD_CYC, cyc_fine = HOLD_CYC}

-- Limits in tenths of a degree: maximum and suggested value.
local LIMIT_MAX = {lim_cyc = 200, lim_coll = 200, lim_total = 360}
local LIMIT_SUGGEST = {lim_cyc = 100, lim_coll = 120}

local MEASURE_NUDGES = {-10, -1, 1, 10}   -- tenths of a degree
local RATE_NUDGES = {-10, -1, 1, 10}      -- 0.1 %
local LIMIT_NUDGES = {-10, -1, 1, 10}     -- tenths of a degree

local function signedTenths(d)
  return string.format("%+.1f", d / 10)
end

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  -- The blade at the test angle, for the measure and fine screens.
  local layoutTest = art.blade(TEST_DEGREES, string.format("%.1f" .. DEG, TEST_DEGREES))
  local layoutLevel = art.tilt("rear", "level")

  local screen = "intro"
  local measured = TEST_DEGREES * 10   -- tenths of a degree
  local calibratedNote = false
  local holding = nil                  -- the HOLDS table sent, or nil

  local function indexOf(name)
    for i, s in ipairs(SCREENS) do
      if s == name then return i end
    end
    return nil
  end

  local function hold()
    local want = HOLDS[screen]
    if not want then
      if holding then wiz.releaseAxes() end
      holding = nil
      return
    end
    if holding ~= want then
      holding = wiz.holdAxes(want) and want or nil
    end
  end

  local function go(name)
    screen = name
    calibratedNote = false
    measured = TEST_DEGREES * 10
    hold()
    wiz.rebuild()
  end

  local function forward()
    local i = indexOf(screen)
    if i and i < #SCREENS then go(SCREENS[i + 1]) else go("done") end
  end

  local function backward()
    local i = indexOf(screen)
    if screen == "done" then
      go(SCREENS[#SCREENS])
    elseif i and i > 1 then
      go(SCREENS[i - 1])
    elseif i == 1 then
      go("intro")
    else
      wiz.previousStep()
    end
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

  local function nudgeRate(d)
    for _, axis in ipairs(GROUP[screen]) do
      wiz.editInput(axis, function(input)
        local sign = input.rate < 0 and -1 or 1
        input.rate = sign * heli.clamp(math.abs(input.rate) + d, 200, 2000)
      end)
    end
    wiz.rebuild()
  end

  -- Current limit, tenths of a degree.
  local function limitTenths()
    if screen == "lim_total" then
      local mix = wiz.mixConfig()
      return heli.round(heli.limitDegrees(mix and mix.swash_pitch_limit or 0) * 10)
    end
    local input = wiz.inputs[GROUP[screen][1]]
    return heli.round(heli.limitDegrees(input and input.max or 0) * 10)
  end

  local function setLimit(tenths)
    tenths = heli.clamp(tenths, 0, LIMIT_MAX[screen])
    local raw = heli.limitRaw(tenths / 10)
    if screen == "lim_total" then
      wiz.editMix(function(m) m.swash_pitch_limit = raw end)
    else
      for _, axis in ipairs(GROUP[screen]) do
        wiz.editInput(axis, function(input)
          input.min = -raw
          input.max = raw
        end)
      end
    end
    wiz.rebuild()
  end

  local function rateText(axis)
    local input = wiz.inputs[axis]
    return string.format("%.1f%%", math.abs(input and input.rate or 0) / 10)
  end

  local function rateRows()
    local rows = {}
    for _, axis in ipairs(GROUP[screen]) do
      rows[#rows + 1] = {T.rate .. " " .. wiz.roleName(axis), rateText(axis)}
    end
    return rows
  end

  local function nudgeSpecs(list, fn)
    local specs = {}
    for _, d in ipairs(list) do
      specs[#specs + 1] = {text = signedTenths(d), small = true, weight = 0.8, press = function() fn(d) end}
    end
    return specs
  end

  function self.build()
    scr:begin()
    hold()
    local progress = indexOf(screen) and string.format(T.progress, indexOf(screen), #SCREENS) or nil

    if screen == "intro" then
      scr:text(T.title, T.intro)
      scr:picture(layoutLevel)
      return scr:row(nil, {
        {text = T.start, primary = true, needsMotion = true, press = function() go(SCREENS[1]) end},
      })

    elseif screen == "coll_measure" or screen == "cyc_measure" then
      local coll = screen == "coll_measure"
      scr:text(coll and T.collTitle or T.cycTitle, coll and T.collText or T.cycText,
        calibratedNote and T.calibrated or nil, progress)
      local rows = rateRows()
      table.insert(rows, 1, {T.measured, string.format("%.1f\194\176", measured / 10), true})
      scr:rows(rows)
      scr:picture(layoutTest)
      local specs = nudgeSpecs(MEASURE_NUDGES, function(d)
        measured = heli.clamp(measured + d, 10, 300)
        wiz.rebuild()
      end)
      specs[#specs + 1] = {text = T.calibrate, small = true, weight = 1.2, primary = true, needsMotion = true,
        press = calibrate}
      return scr:row(backward, specs, {text = T.next, press = forward})

    elseif screen == "coll_fine" or screen == "cyc_fine" then
      local coll = screen == "coll_fine"
      scr:text(coll and T.collTitle or T.cycTitle, T.fineText, nil, progress)
      scr:rows(rateRows())
      scr:picture(layoutTest)
      local specs = nudgeSpecs(RATE_NUDGES, nudgeRate)
      for i = 1, #specs do specs[i].needsMotion = true end
      return scr:row(backward, specs, {text = T.next, press = forward})

    elseif LIMIT_MAX[screen] then
      local total = screen == "lim_total"
      local title = (screen == "lim_cyc" and T.limCycTitle) or (screen == "lim_coll" and T.limCollTitle) or T.limTotalTitle
      local tenths = limitTenths()
      scr:text(title, total and T.limTotalText or T.limText, nil, progress)
      scr:rows({{T.limit, string.format("%.1f\194\176", tenths / 10), true}})
      -- A cyclic or collective limit works both ways; the total is one angle.
      local deg = tenths / 10
      scr:picture(art.blade(deg, string.format("%.1f" .. DEG, deg), not total,
        string.format("-%.1f" .. DEG, deg)))
      local specs = nudgeSpecs(LIMIT_NUDGES, function(d) setLimit(limitTenths() + d) end)
      local suggest = LIMIT_SUGGEST[screen]
      if suggest then
        specs[#specs + 1] = {text = string.format(T.suggest, suggest / 10), small = true, weight = 1.1,
          press = function() setLimit(suggest) end}
      end
      return scr:row(backward, specs, {text = T.next, press = forward})
    end

    -- done
    scr:text(T.doneTitle, T.done)
    local mix = wiz.mixConfig()
    -- The three limits as bars against their maximum.
    local cyc = heli.limitDegrees(wiz.inputs.pitch and wiz.inputs.pitch.max or 0)
    local coll = heli.limitDegrees(wiz.inputs.collective and wiz.inputs.collective.max or 0)
    local total = heli.limitDegrees(mix and mix.swash_pitch_limit or 0)
    scr:picture(art.bars({
      {label = T.limCycTitle, frac = cyc * 10 / LIMIT_MAX.lim_cyc, text = string.format("%.1f" .. DEG, cyc)},
      {label = T.limCollTitle, frac = coll * 10 / LIMIT_MAX.lim_coll, text = string.format("%.1f" .. DEG, coll)},
      {label = T.limTotalTitle, frac = total * 10 / LIMIT_MAX.lim_total, text = string.format("%.1f" .. DEG, total)},
    }))
    return scr:row(backward)
  end

  function self.paint() scr:paint() end

  local lastCanMove = nil
  function self.wakeup()
    local canMove = wiz.canMove()
    if canMove ~= lastCanMove then
      lastCanMove = canMove
      if canMove and HOLDS[screen] and not holding then hold() end
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

return {new = new}
