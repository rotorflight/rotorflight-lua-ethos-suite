-- Setup Wizard step: Servo type. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepServoType.svelte. One
-- screen per group: the swash servos, then the tail servo (pitch tail only).
-- Each picks a type (lib/setup_wizard_heli.lua's SERVO_TYPES):
--
--   Analog   50 Hz,  wide band  (centre 1520 us)
--   Digital  333 Hz, wide band
--   Narrow   560 Hz, narrow band (centre 760 us)
--
-- A type sets every servo in the group: its update rate, and when the band
-- changes its centre, limits and scale. A servo that matches none of them
-- (custom) is left alone until a type is picked. A new update rate only
-- applies after a restart; the servos stay unplugged until the Connect step,
-- so a wrong rate cannot reach them.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local heli = requireModule("lib/setup_wizard_heli.lua")
local art = requireModule("app/setup_wizard_art.lua")

local OWNED = {}

local T = {
  intro = "@i18n(app.modules.setup_wizard.sty_intro)@",
  unplugged = "@i18n(app.modules.setup_wizard.sty_unplugged)@",
  swashTitle = "@i18n(app.modules.setup_wizard.sty_swash_title)@",
  tailTitle = "@i18n(app.modules.setup_wizard.sty_tail_title)@",
  custom = "@i18n(app.modules.setup_wizard.sty_custom)@",
  mixed = "@i18n(app.modules.setup_wizard.sty_mixed)@",
  rowType = "@i18n(app.modules.setup_wizard.sty_row_type)@",
  hz = "@i18n(app.modules.setup_wizard.sty_hz_fmt)@",
  us = "@i18n(app.modules.setup_wizard.sty_us_fmt)@",
  restart = "@i18n(app.modules.setup_wizard.swa_restart)@",
  progress = "@i18n(app.modules.setup_wizard.progress_fmt)@",
}

local TYPE_NAMES = {
  analog = "@i18n(app.modules.setup_wizard.sty_analog)@",
  digital = "@i18n(app.modules.setup_wizard.sty_digital)@",
  narrow = "@i18n(app.modules.setup_wizard.sty_narrow)@",
}

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)

  -- Groups: {title =, servos = {0-based index, ...}}; missing servos skipped.
  local groups = {}
  do
    local swash, tail = {}, {}
    for _, s in ipairs(wiz.servos()) do
      if not s.missing and wiz.configs[s.servo] then
        if s.tail then tail[#tail + 1] = s.servo else swash[#swash + 1] = s.servo end
      end
    end
    if #swash > 0 then groups[#groups + 1] = {title = T.swashTitle, servos = swash} end
    if #tail > 0 then groups[#groups + 1] = {title = T.tailTitle, servos = tail} end
  end
  local index = 1

  -- The group's type: a key, "custom" when a servo matches none, "mixed"
  -- when the servos differ.
  local function groupType(g)
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

  function self.build()
    scr:begin()
    local g = groups[index]
    if not g then
      scr:text(T.swashTitle, T.intro)
      return scr:row()
    end
    local current = groupType(g)
    local currentName = TYPE_NAMES[current] or (current == "mixed" and T.mixed or T.custom)
    local first = wiz.configs[g.servos[1]]
    scr:text(g.title, T.intro .. " " .. T.unplugged, wiz.rebootPending() and T.restart or nil)
    -- One step per group of servos, when there is more than one.
    if #groups > 1 then scr:step(index, #groups) end
    -- The rate and centre are in the picture.
    scr:rows({{T.rowType, currentName}})
    -- The pulse this type sends, with the other band ghosted behind it.
    local mid = first.mid or 1520
    local other = heli.bandOf(first) == "wide" and heli.BANDS.narrow.mid or heli.BANDS.wide.mid
    scr:picture(art.pulse(mid, other, string.format(T.us, mid), string.format(T.hz, first.rate or 0)))
    local specs = {}
    for _, t in ipairs(heli.SERVO_TYPES) do
      specs[#specs + 1] = {text = TYPE_NAMES[t.key], small = true, primary = t.key == current,
        press = function() apply(g, t.key) end}
    end
    local back = index > 1 and function() index = index - 1; wiz.rebuild() end or nil
    local forward = nil
    if index < #groups then
      forward = {text = "@i18n(app.modules.setup_wizard.btn_next)@", press = function()
        index = index + 1
        wiz.rebuild()
      end}
    end
    return scr:row(back, specs, forward)
  end

  function self.paint() scr:paint() end

  function self.released() scr:refresh() end

  return self
end

return {new = new, owned = OWNED}
