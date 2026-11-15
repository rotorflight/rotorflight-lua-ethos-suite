-- Setup Wizard step: Level the swash. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepLevel.svelte, with the EdgeTX suite's pictures.
-- Two pages:
--
--   1. The safety card: the motor is unplugged, the blades are fitted in this step. Start is greyed
--      out until it is answered. Under the answer, what the level page does: the swash is held at its
--      centre and is trimmed until it is level with the blades at zero pitch.
--   2. The level page: roll, pitch and collective are held at 0 (mixer override), so the swash sits
--      at its middle with nothing from the sticks or the gyro. On the left the two EdgeTX pictures side
--      by side (from behind, and the side view at 0 degrees), each with its description under it. On
--      the right the three trims as number fields (0.1 %, +-100 %) and Reset. The mixer config is sent
--      as the trims change.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")
local heli = requireModule("lib/setup_wizard_heli.lua")

local T = {
  title = "@i18n(app.modules.setup_wizard.lvl_title)@",
  intro = "@i18n(app.modules.setup_wizard.lvl_intro)@",
  safety = "@i18n(app.modules.setup_wizard.lvl_safety)@",
  motorOff = "@i18n(app.modules.setup_wizard.lvl_motor_off)@",
  rearView = "@i18n(app.modules.setup_wizard.lvl_view_rear)@",
  sideView = "@i18n(app.modules.setup_wizard.lvl_view_side)@",
  rearText = "@i18n(app.modules.setup_wizard.lvl_rear_text)@",
  sideText = "@i18n(app.modules.setup_wizard.lvl_side_text)@",
  reset = "@i18n(app.modules.setup_wizard.lvl_reset)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
}

local PICTURE_W, PICTURE_H = 220, 160
local PAIR_GAP = 8
local TEXT_GAP = 4
-- The pictures take this share of the column; the descriptions sit under them.
local PICTURE_SHARE = 0.5
local TRIM_LIMIT = 1000
local HOLD = {roll = 0, pitch = 0, collective = 0}

-- The trims: the mixer field, and the axis (for its name).
local TRIMS = {
  {field = "swash_trim_0", axis = "roll"},
  {field = "swash_trim_1", axis = "pitch"},
  {field = "swash_trim_2", axis = "collective"},
}

local SAFETY, LEVEL = "safety", "level"

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  local safetyPicture = art.image("swash-motion-level", PICTURE_W, PICTURE_H)
  local rearPicture = art.image("swash-motion-level", PICTURE_W, PICTURE_H)
  local sidePicture = art.image("pitch-0", PICTURE_W, PICTURE_H)

  local screen = SAFETY
  local answers = {motor = false}
  local holding = false

  local function hold()
    holding = wiz.holdAxes(HOLD)
  end

  local function go(name)
    screen = name
    if name == LEVEL then
      if not holding then hold() end
    elseif holding then
      wiz.releaseAxes()
      holding = false
    end
    wiz.rebuild()
  end

  -- A trim as a cell: its name to the left of a number field in 0.1 %, the field showing one decimal;
  -- the value is the raw trim.
  local function trimCell(t)
    return {label = wiz.roleName(t.axis), number = {-TRIM_LIMIT, TRIM_LIMIT,
      function()
        local mix = wiz.mixConfig() or {}
        return heli.signed16(mix[t.field] or 0)
      end,
      function(value)
        wiz.editMix(function(m)
          m[t.field] = heli.clamp(math.floor(value + 0.5), -TRIM_LIMIT, TRIM_LIMIT)
        end)
      end,
      "%", 1}}
  end

  local function resetTrims()
    wiz.editMix(function(m)
      for _, t in ipairs(TRIMS) do m[t.field] = 0 end
    end)
    wiz.rebuild()
  end

  -- The two pictures side by side, each with its description under it, the view named at its start.
  -- The pictures share one box of PICTURE_SHARE of the column; the descriptions sit right under it.
  local function drawLevelPictures(x, y, w, h, colors)
    local half = math.floor((w - PAIR_GAP) / 2)
    local rightX = x + half + PAIR_GAP
    local rightW = w - half - PAIR_GAP
    lcd.font(FONT_S)
    local _, lineH = lcd.getTextSize("Ag")
    local rear = wiz.wrapLines(T.rearView .. ": " .. T.rearText, half, FONT_S)
    local side = wiz.wrapLines(T.sideView .. ": " .. T.sideText, rightW, FONT_S)
    local picH = math.floor(h * PICTURE_SHARE)
    local textTop = y + picH + TEXT_GAP
    art.draw(rearPicture, x, y, half, picH, colors)
    art.draw(sidePicture, rightX, y, rightW, picH, colors)
    lcd.color(colors.text)
    for j, line in ipairs(rear) do lcd.drawText(x, textTop + (j - 1) * lineH, line, LEFT) end
    for j, line in ipairs(side) do lcd.drawText(rightX, textTop + (j - 1) * lineH, line, LEFT) end
  end

  -- The safety card: the motor must be unplugged before the blades go on. Under the answer, what
  -- the level page does.
  local function buildSafety()
    scr:text(T.title, T.safety)
    scr:step(1, 2)
    scr:picture(safetyPicture)
    return scr:safety(answers, {{key = "motor", label = T.motorOff}}, T.start, function()
      go(LEVEL)
    end, {
      {note = T.intro, plain = true},
    })
  end

  local function buildLevel()
    scr:text(T.title, nil)
    scr:step(2, 2)
    -- Two pictures and the controls, in three equal parts of the width.
    scr:split(2 / 3)
    scr:draw(drawLevelPictures)
    local rows = {}
    for _, t in ipairs(TRIMS) do rows[#rows + 1] = {cells = {trimCell(t)}} end
    rows[#rows + 1] = {answer = T.reset, press = resetTrims, needsMotion = true}
    local field = scr:checks(rows)
    local rowField = scr:row(function() go(SAFETY) end, nil)
    return field or rowField
  end

  function self.build()
    scr:begin()
    if screen == SAFETY then return buildSafety() end
    return buildLevel()
  end

  function self.paint() scr:paint() end

  local lastCanMove = nil
  function self.wakeup()
    local canMove = wiz.canMove()
    if canMove ~= lastCanMove then
      lastCanMove = canMove
      if canMove and screen == LEVEL and not holding then hold() end
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
