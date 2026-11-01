-- Setup Wizard step: Servo type. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of the EdgeTX suite's servo type card, with the same types and
-- pictures (app/gfx/setup_wizard/servo-cyclic-*.png, servo-tail-*.png), and of
-- rotorflight-configurator's StepServoType.svelte. First a safety card: the servos
-- stay unplugged, and the blades off. Then one screen per group: the cyclic servos,
-- then the tail servo (pitch tail only). Each screen has the type's picture on the
-- left, with its name and the servos' values under it, and on the right:
--
--   Servo type   the type the servos are made for (a preset of heli.SERVO_TYPES)
--   Frame rate   any rate within the type's band (heli.BAND_HZ): the custom value
--   Geometry     the geometry correction (flags bit 1), an On/Off switch; cyclic only
--
-- A type sets every servo in the group: its update rate, and when the band
-- changes its centre, limits and scale. A servo that matches none of them
-- (custom) opens on the group's first type, once. A new update rate only applies
-- after a restart; the servos stay unplugged until the Connect step, so a wrong
-- rate cannot reach them.
--
-- A frame rate typed in changes the servos without a rebuild of the screen: a
-- rebuild would close the number field being edited. Its picture and caption are
-- replaced in place instead.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local heli = requireModule("lib/setup_wizard_heli.lua")
local art = requireModule("app/setup_wizard_art.lua")

local OWNED = {}

-- Prepare, then one screen per group.
local PICTURE_W, PICTURE_H = 220, 160

local T = {
  prepareTitle = "@i18n(app.modules.setup_wizard.rcv_prepare_title)@",
  prepareText = "@i18n(app.modules.setup_wizard.sty_unplugged)@",
  unplugged = "@i18n(app.modules.setup_wizard.sen_servos_unplugged)@",
  blades = "@i18n(app.modules.setup_wizard.sen_blades_removed)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  intro = "@i18n(app.modules.setup_wizard.sty_intro)@",
  swashTitle = "@i18n(app.modules.setup_wizard.sty_swash_title)@",
  tailTitle = "@i18n(app.modules.setup_wizard.sty_tail_title)@",
  custom = "@i18n(app.modules.setup_wizard.sty_custom)@",
  mixed = "@i18n(app.modules.setup_wizard.sty_mixed)@",
  rowType = "@i18n(app.modules.setup_wizard.sty_row_type)@",
  rowRate = "@i18n(app.modules.setup_wizard.sty_row_rate)@",
  hzUnit = "@i18n(app.unit_hertz)@",
  hz = "@i18n(app.modules.setup_wizard.sty_hz_fmt)@",
  us = "@i18n(app.modules.setup_wizard.sty_us_fmt)@",
  analog = "@i18n(app.modules.setup_wizard.sty_analog)@",
  digital = "@i18n(app.modules.setup_wizard.sty_digital)@",
  narrow = "@i18n(app.modules.setup_wizard.sty_narrow)@",
  hiendDigital = "@i18n(app.modules.setup_wizard.sty_hiend_digital)@",
  specificDigital = "@i18n(app.modules.setup_wizard.sty_specific_digital)@",
  hiendSpecificDigital = "@i18n(app.modules.setup_wizard.sty_hiend_specific_digital)@",
  geoTitle = "@i18n(app.modules.setup_wizard.sty_geo_title)@",
  restart = "@i18n(app.modules.setup_wizard.swa_restart)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
}

-- The types each group offers, in the drop-down's order: the heli preset it sets, the
-- name, and the picture (app/gfx/setup_wizard/servo-<group>-<picture>.png).
local GROUP_TYPES = {
  cyclic = {
    {key = "wide50", name = T.analog, picture = "analog"},
    {key = "wide165", name = T.digital, picture = "digital"},
    {key = "wide333", name = T.hiendDigital, picture = "hiend-digital"},
    {key = "narrow560", name = T.narrow, picture = "narrow-band"},
  },
  tail = {
    {key = "wide200", name = T.digital, picture = "digital"},
    {key = "narrow333", name = T.specificDigital, picture = "specific-digital"},
    {key = "narrow560", name = T.hiendSpecificDigital, picture = "hiend-specific-digital"},
  },
}

-- The drop-down's values for the states a group can be in: custom is always listed
-- (it is what a hand-set frame rate shows); picking it changes nothing.
local CUSTOM_ID, MIXED_ID = 100, 101
local GEO_OFF, GEO_ON = 1, 2

-- The index of a group's type with this preset key, or nil.
local function typeIndex(g, key)
  for i, t in ipairs(GROUP_TYPES[g.tail and "tail" or "cyclic"]) do
    if t.key == key then return i, t end
  end
  return nil
end

-- The heli preset with this key.
local function presetOf(key)
  for _, p in ipairs(heli.SERVO_TYPES) do
    if p.key == key then return p end
  end
  return nil
end

-- The flags bit helpers (the geometry correction is bit 1, value 2).
local function hasBit(flags, bit)
  return math.floor((flags or 0) / bit) % 2 == 1
end
local function withBit(flags, bit, on)
  flags = flags or 0
  if on and not hasBit(flags, bit) then return flags + bit end
  if not on and hasBit(flags, bit) then return flags - bit end
  return flags
end

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  local screen = "prepare"
  local answers = {unplugged = false, blades = false}   -- the safety answers, kept across rebuilds
  -- One picture layout per picture name, replaced when the picture changes (one bitmap in memory).
  local picture, pictureName = nil, nil
  local function pictureOf(name)
    if name ~= pictureName then
      picture, pictureName = art.image(name, PICTURE_W, PICTURE_H), name
    end
    return picture
  end
  local bladesPicture = art.image("servo", PICTURE_W, PICTURE_H)
  -- The pulse trace for a group that matches no type: in the Configurator's blue.
  local PULSE_BLUE = lcd.RGB(60, 168, 236)

  -- Groups: {title =, servos = {0-based index, ...}, tail = bool}; missing servos skipped.
  local groups = {}
  do
    local swash, tail = {}, {}
    for _, s in ipairs(wiz.servos()) do
      if not s.missing and wiz.configs[s.servo] then
        if s.tail then tail[#tail + 1] = s.servo else swash[#swash + 1] = s.servo end
      end
    end
    if #swash > 0 then groups[#groups + 1] = {title = T.swashTitle, servos = swash, tail = false} end
    if #tail > 0 then groups[#groups + 1] = {title = T.tailTitle, servos = tail, tail = true} end
  end
  local index = 1

  -- The group's state: a preset key, "custom" when a servo matches none, "mixed"
  -- when the servos differ.
  local function groupState(g)
    local found = nil
    for i, servo in ipairs(g.servos) do
      local t = heli.servoTypeOf(wiz.configs[servo]) or "custom"
      if i == 1 then
        found = t
      elseif t ~= found then
        return "mixed"
      end
    end
    return found
  end

  -- The drop-down's value for the group's state, read live.
  local function typeIdOf(g)
    local state = groupState(g)
    local i = typeIndex(g, state)
    if i then return i end
    if state == "mixed" then return MIXED_ID end
    return CUSTOM_ID
  end

  local function apply(g, key)
    local rateChanged = false
    for _, servo in ipairs(g.servos) do
      wiz.editServo(servo, function(config)
        if heli.applyServoType(config, key) then rateChanged = true end
      end)
    end
    if rateChanged then wiz.requestReboot() end
    wiz.rebuild()
  end

  -- A group whose servos match no type gets the group's first type once, when the
  -- step first shows it. It is an ordinary change, so Discard puts the servos back.
  local function defaultType(g)
    local key = GROUP_TYPES[g.tail and "tail" or "cyclic"][1].key
    local rateChanged = false
    for _, servo in ipairs(g.servos) do
      wiz.editServo(servo, function(config)
        if heli.applyServoType(config, key) then rateChanged = true end
      end)
    end
    if rateChanged then wiz.requestReboot() end
  end

  -- The picture and its caption for the group as the servos are now: the type's
  -- own picture, the nearest type of the band for a hand-set rate, or the plain
  -- pulse when the group has no type to show.
  local function pictureFor(g)
    local state = groupState(g)
    local first = wiz.configs[g.servos[1]]
    local _, t = typeIndex(g, state)
    if not t then
      local band = heli.bandOf(first)
      local rate = first.rate or 0
      local bestDiff = nil
      for _, candidate in ipairs(GROUP_TYPES[g.tail and "tail" or "cyclic"]) do
        local p = presetOf(candidate.key)
        if p and p.band == band then
          local diff = math.abs(p.rate - rate)
          if bestDiff == nil or diff < bestDiff then
            t, bestDiff = candidate, diff
          end
        end
      end
    end
    local name = t and t.name or (state == "mixed" and T.mixed or T.custom)
    local caption = name .. "\n" .. string.format(T.us, first.mid or 1520) .. " / " .. string.format(T.hz, first.rate or 0)
    if t then
      return pictureOf("servo-" .. (g.tail and "tail" or "cyclic") .. "-" .. t.picture), caption
    end
    local trace = art.pulse(first.mid or 1520, nil, nil, nil, PULSE_BLUE)
    trace.plain = true
    return trace, caption
  end

  -- The frame rate, within the band the group is on. Changes the servos and replaces
  -- the picture in place; no rebuild, so the number field stays open.
  local function setRate(g, v)
    local range = heli.BAND_HZ[heli.bandOf(wiz.configs[g.servos[1]])]
    if type(v) ~= "number" or v % 1 ~= 0 or v < range.min or v > range.max then return end
    local changed = false
    for _, servo in ipairs(g.servos) do
      wiz.editServo(servo, function(config)
        if config.rate ~= v then
          config.rate = v
          changed = true
        end
      end)
    end
    if changed then wiz.requestReboot() end
    local layout, caption = pictureFor(g)
    scr:picture(layout, caption)
    wiz.invalidate()
  end

  -- Geometry correction: on for all of the group's servos; a mixed group shows off
  -- until the switch is set.
  local function groupGeometryOn(g)
    for _, servo in ipairs(g.servos) do
      if not hasBit(wiz.configs[servo].flags, heli.SERVO_FLAG_GEOMETRY) then return false end
    end
    return true
  end

  local function setGeometry(g, on)
    for _, servo in ipairs(g.servos) do
      wiz.editServo(servo, function(config)
        config.flags = withBit(config.flags, heli.SERVO_FLAG_GEOMETRY, on)
      end)
    end
    wiz.rebuild()
  end

  -- The drop-down: the group's types, custom always, and mixed while the group is in it.
  local function typeValues(g)
    local values = {}
    for i, t in ipairs(GROUP_TYPES[g.tail and "tail" or "cyclic"]) do
      values[#values + 1] = {text = t.name, value = i}
    end
    values[#values + 1] = {text = T.custom, value = CUSTOM_ID}
    if groupState(g) == "mixed" then values[#values + 1] = {text = T.mixed, value = MIXED_ID} end
    return values
  end

  local function groupScreen(g)
    -- The first time the step shows a group, a group that matches no type opens on its first type.
    if not g.opened then
      g.opened = true
      if groupState(g) == "custom" then
        defaultType(g)
      end
    end
    local first_ = wiz.configs[g.servos[1]]
    -- The restart note is a line under the title, not below the buttons (small screens).
    scr:text(g.title, nil, wiz.rebootPending() and T.restart or nil)
    local layout, caption = pictureFor(g)
    scr:picture(layout, caption)
    local rows = {
      {label = T.rowType, choice = {values = typeValues(g),
        get = function() return typeIdOf(g) end,
        set = function(v)
          if v == CUSTOM_ID or v == MIXED_ID then return end
          local t = GROUP_TYPES[g.tail and "tail" or "cyclic"][v]
          if t then apply(g, t.key) end
        end}},
    }
    -- The custom frame rate, within the band.
    local range = heli.BAND_HZ[heli.bandOf(first_)]
    rows[#rows + 1] = {label = T.rowRate, number = {range.min, range.max,
      function() return wiz.configs[g.servos[1]].rate or 0 end,
      function(v) setRate(g, v) end, T.hzUnit}}
    -- The geometry correction is for the cyclic servos only: the tail's linkage needs none.
    if not g.tail then
      rows[#rows + 1] = {label = T.geoTitle, switch = {
        function() return groupGeometryOn(g) end,
        function(on) setGeometry(g, on) end}}
    end
    return rows
  end

  function self.build()
    scr:begin()
    -- The safety card is step 1; each group after it is one more step.
    local total = #groups + 1
    if screen == "prepare" then
      scr:text(T.prepareTitle, T.prepareText)
      scr:picture(bladesPicture)
      if total > 1 then scr:step(1, total) end
      return scr:safety(answers, {
        {key = "unplugged", label = T.unplugged},
        {key = "blades", label = T.blades},
      }, T.start, function()
        screen = "groups"
        index = 1
        wiz.rebuild()
      end)
    end

    local g = groups[index]
    if not g then
      scr:text(T.swashTitle, T.intro)
      return scr:row(function() screen = "prepare"; wiz.rebuild() end)
    end
    if total > 1 then scr:step(index + 1, total) end
    local rows = groupScreen(g)
    local field = scr:checks(rows)
    -- Back from the first group goes to the safety card, the others to the group before.
    local back = function()
      if index > 1 then index = index - 1 else screen = "prepare" end
      wiz.rebuild()
    end
    local forward = nil
    if index < #groups then
      forward = {text = T.next, press = function()
        index = index + 1
        wiz.rebuild()
      end}
    end
    local rowField = scr:row(back, nil, forward)
    return field or rowField
  end

  function self.paint() scr:paint() end

  function self.released() scr:refresh() end

  return self
end

return {new = new, owned = OWNED}
