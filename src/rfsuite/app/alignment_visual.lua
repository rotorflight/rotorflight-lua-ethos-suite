-- Custom Alignment 3D visualizer.
--
-- Stateless renderer for app/pages/alignment.lua. It keeps the original
-- module's important behavior: live attitude text, configured offset text,
-- nose-direction cue, and a 3D helicopter (lib/heli3d.lua, the Rotorflight
-- Configurator's model) whose orientation follows MSP_ATTITUDE plus any *unsaved*
-- edits to the board offset fields (see state.baseline in
-- app/pages/alignment.lua -- the offsets already saved on the FC are
-- subtracted back out, since MSP_ATTITUDE already includes them).

if package.loaded["rfsuite.app.alignment_visual"] then
  return package.loaded["rfsuite.app.alignment_visual"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local heli3d = requireModule("lib/heli3d.lua")

local floor = math.floor
local max = math.max

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local alignment_visual = {}

-- The 3D helicopter's background work: call from the page's wakeup.
alignment_visual.service = heli3d.service

function alignment_visual.recenterYaw(state)
  local baseline = state.baseline or {}
  state.viewYawOffset = (tonumber(state.live.yaw) or 0) + (tonumber(state.display.yaw_degrees) or 0) - (tonumber(baseline.yaw_degrees) or 0)
end

function alignment_visual.draw(state)
  local w, h = lcd.getWindowSize()
  local y = floor(form.height() + 2)
  local vw = w - 1
  local vh = h - y - 2
  if vh < 40 then return end

  local isDark = lcd.darkMode()
  local bg = isDark and lcd.RGB(18, 18, 18) or lcd.RGB(245, 245, 245)
  local grid = isDark and lcd.GREY(70) or lcd.GREY(210)
  local mainColor = isDark and lcd.RGB(248, 248, 248) or lcd.RGB(8, 8, 8)
  local accent = isDark and lcd.RGB(255, 220, 110) or lcd.RGB(0, 110, 235)

  local panelX = 4
  local panelY = y + 2
  local panelW = vw - 8
  local panelH = vh - 4

  lcd.color(bg)
  lcd.drawFilledRectangle(panelX, panelY, panelW, panelH)
  lcd.color(grid)
  lcd.drawRectangle(panelX, panelY, panelW, panelH)

  -- MSP_ATTITUDE already reflects the board-alignment offsets currently
  -- saved on the FC (alignment is applied to the sensor data before
  -- attitude is computed), so state.baseline -- the offsets in effect
  -- when this page opened -- must be subtracted back out before adding
  -- state.display (the, possibly still unsaved, offsets shown in the
  -- fields). Adding state.display on its own double-counts whatever was
  -- already saved, e.g. a correctly-configured upside-down mount (board
  -- roll 180) renders upside down here even though live attitude is
  -- already level.
  local baseline = state.baseline or {}
  local roll = (state.live.roll or 0) + (state.display.roll_degrees or 0) - (baseline.roll_degrees or 0)
  local pitch = (state.live.pitch or 0) + (state.display.pitch_degrees or 0) - (baseline.pitch_degrees or 0)
  local yaw = (state.live.yaw or 0) + (state.display.yaw_degrees or 0) - (baseline.yaw_degrees or 0) - (state.viewYawOffset or 0)

  local leftPanelW = clamp(floor(panelW * 0.40), 150, floor(panelW * 0.70))
  local infoX = panelX + 1
  local infoY = panelY + 1
  local infoW = leftPanelW
  local infoH = panelH - 2
  local gx0 = infoX + infoW + 1
  local gy0 = panelY + 1
  local gw0 = panelW - infoW - 3
  local gh0 = panelH - 2
  if gh0 < 40 then return end

  lcd.color(grid)
  lcd.drawRectangle(infoX, infoY, infoW, infoH)
  lcd.drawLine(gx0 - 1, panelY + 1, gx0 - 1, panelY + panelH - 2)

  lcd.font(FONT_XS)
  local liveText = string.format("@i18n(app.modules.alignment.live_fmt)@", state.live.roll or 0, state.live.pitch or 0, state.live.yaw or 0)
  local offsText = string.format("@i18n(app.modules.alignment.offset_fmt)@", state.display.roll_degrees or 0, state.display.pitch_degrees or 0, state.display.yaw_degrees or 0, state.display.mag_alignment or 0)
  local _, th1 = lcd.getTextSize(liveText)
  local _, th2 = lcd.getTextSize(offsText)
  local textX = infoX + 8
  local textY = infoY + 6
  lcd.color(mainColor)
  lcd.drawText(textX, textY, liveText, LEFT)
  lcd.drawText(textX, textY + th1 + 2, offsText, LEFT)
  lcd.drawText(textX, textY + th1 + th2 + 14, string.format("@i18n(app.modules.alignment.view_yaw_fmt)@", state.viewYawOffset or 0), LEFT)

  local miniX = infoX + 8
  local miniY = textY + th1 + th2 + 46
  local miniW = max(40, infoW - 16)
  local miniH = max(40, infoH - (miniY - infoY) - 8)
  if miniH >= 56 then
    lcd.color(grid)
    lcd.drawRectangle(miniX, miniY, miniW, miniH)
    lcd.color(mainColor)
    lcd.drawText(miniX + 4, miniY + 2, "@i18n(app.modules.alignment.nose_direction)@", LEFT)

    local ux, uy = heli3d.noseDirection(roll, pitch, yaw)
    if ux then
      local htxt, vtxt = "center", "center"
      if ux > 0.35 then htxt = "left" elseif ux < -0.35 then htxt = "right" end
      if uy > 0.35 then vtxt = "up" elseif uy < -0.35 then vtxt = "down" end
      local primary = "@i18n(app.modules.alignment.nose_level)@"
      if vtxt == "up" then primary = "@i18n(app.modules.alignment.nose_up)@" end
      if vtxt == "down" then primary = "@i18n(app.modules.alignment.nose_down)@" end
      local secondary = ""
      if htxt == "left" then secondary = "@i18n(app.modules.alignment.leaning_left)@" end
      if htxt == "right" then secondary = "@i18n(app.modules.alignment.leaning_right)@" end

      lcd.font(FONT_STD)
      lcd.color(accent)
      lcd.drawText(miniX + 6, miniY + floor(miniH * 0.42), primary, LEFT)
      lcd.font(FONT_XS)
      lcd.color(mainColor)
      if secondary ~= "" then
        lcd.drawText(miniX + 6, miniY + floor(miniH * 0.42) + 22, secondary, LEFT)
      end
    end
  end

  heli3d.setup(nil)
  heli3d.pose(nil)
  heli3d.draw(gx0, gy0, gw0, gh0, roll, pitch, yaw)
end

package.loaded["rfsuite.app.alignment_visual"] = alignment_visual
return alignment_visual
