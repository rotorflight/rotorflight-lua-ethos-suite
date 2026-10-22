-- Setup Wizard step: Level the swash. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepLevel.svelte. Roll,
-- pitch and collective are held at 0 (mixer override), so the swash sits at
-- its middle with nothing from the sticks or the gyro. One screen per trim
-- (swash_trim_0/1/2: roll, pitch, collective, in 0.1 % steps, +-100 %):
-- nudge it until the swash is level and the blades sit at zero pitch. The
-- mixer config is sent straight away.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")
local heli = requireModule("lib/setup_wizard_heli.lua")

local T = {
  title = "@i18n(app.modules.setup_wizard.lvl_title)@",
  intro = "@i18n(app.modules.setup_wizard.lvl_intro)@",
  trim = "@i18n(app.modules.setup_wizard.lvl_trim)@",
  value = "@i18n(app.modules.setup_wizard.lvl_value_fmt)@",
  reset = "@i18n(app.modules.setup_wizard.lvl_reset)@",
  progress = "@i18n(app.modules.setup_wizard.progress_fmt)@",
  doneTitle = "@i18n(app.modules.setup_wizard.lvl_done_title)@",
  done = "@i18n(app.modules.setup_wizard.lvl_done)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
}

local TRIMS = {
  {field = "swash_trim_0", axis = "roll", title = "@i18n(app.modules.setup_wizard.lvl_roll_title)@",
    text = "@i18n(app.modules.setup_wizard.lvl_roll)@"},
  {field = "swash_trim_1", axis = "pitch", title = "@i18n(app.modules.setup_wizard.lvl_pitch_title)@",
    text = "@i18n(app.modules.setup_wizard.lvl_pitch)@"},
  {field = "swash_trim_2", axis = "collective", title = "@i18n(app.modules.setup_wizard.lvl_coll_title)@",
    text = "@i18n(app.modules.setup_wizard.lvl_coll)@"},
}

local TRIM_LIMIT = 1000
local NUDGES = {-10, -1, 1, 10}
local HOLD = {roll = 0, pitch = 0, collective = 0}

local function trimText(raw)
  return string.format("%+.1f%%", raw / 10)
end

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  -- The swash as the trims tilt it: from behind (roll, collective) and from
  -- the left (pitch). Built on every rebuild, which every nudge asks for.
  local function levelLayout(focus)
    local mix = wiz.mixConfig() or {}
    local roll = heli.signed16(mix.swash_trim_0 or 0)
    local pitch = heli.signed16(mix.swash_trim_1 or 0)
    local coll = heli.signed16(mix.swash_trim_2 or 0)
    return art.level(roll, pitch, coll, focus,
      wiz.roleName("roll") .. " " .. trimText(roll) .. "  " .. wiz.roleName("collective") .. " " .. trimText(coll),
      wiz.roleName("pitch") .. " " .. trimText(pitch))
  end

  local screen = "intro"
  local ti = 1
  local holding = false

  local function hold()
    holding = wiz.holdAxes(HOLD)
  end

  local function go(name)
    screen = name
    if name == "trim" then
      if not holding then hold() end
    end
    wiz.rebuild()
  end

  local function setTrim(fn)
    local field = TRIMS[ti].field
    wiz.editMix(function(m)
      m[field] = heli.clamp(fn(heli.signed16(m[field] or 0)), -TRIM_LIMIT, TRIM_LIMIT)
    end)
    wiz.rebuild()
  end

  function self.build()
    scr:begin()
    local mix = wiz.mixConfig()
    if screen == "intro" then
      scr:text(T.title, T.intro)
      scr:picture(levelLayout(nil))
      return scr:row(nil, {
        {text = T.start, primary = true, needsMotion = true, press = function() ti = 1; go("trim") end},
      })
    elseif screen == "trim" then
      local t = TRIMS[ti]
      local raw = heli.signed16(mix and mix[t.field] or 0)
      scr:text(t.title, t.text, nil, string.format(T.progress, ti, #TRIMS))
      scr:rows({{T.trim, string.format(T.value, trimText(raw)), raw ~= 0}})
      scr:picture(levelLayout(t.axis))
      local specs = {}
      for _, d in ipairs(NUDGES) do
        specs[#specs + 1] = {text = string.format("%+.1f", d / 10), small = true, weight = 0.8, needsMotion = true,
          press = function() setTrim(function(v) return v + d end) end}
      end
      specs[#specs + 1] = {text = T.reset, small = true, weight = 0.9, needsMotion = true,
        press = function() setTrim(function() return 0 end) end}
      return scr:row(function()
        if ti > 1 then ti = ti - 1; go("trim") else go("intro") end
      end, specs, {text = T.next, press = function()
        if ti < #TRIMS then ti = ti + 1; go("trim") else go("done") end
      end})
    end
    scr:text(T.doneTitle, T.done)
    scr:picture(levelLayout(nil))
    return scr:row(function() ti = #TRIMS; go("trim") end)
  end

  function self.paint() scr:paint() end

  local lastCanMove = nil
  function self.wakeup()
    local canMove = wiz.canMove()
    if canMove ~= lastCanMove then
      lastCanMove = canMove
      if canMove and screen ~= "intro" and not holding then hold() end
      scr:refresh()
    end
  end

  function self.released()
    holding = false
    lastCanMove = nil
    scr:refresh()
  end

  return self
end

return {new = new}
