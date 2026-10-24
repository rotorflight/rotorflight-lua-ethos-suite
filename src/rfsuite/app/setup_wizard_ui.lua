-- Setup Wizard screens: what every step's screen is made of. A title, a few
-- lines of text, an optional picture (app/setup_wizard_art.lua) or other
-- drawing, rows of values, and one row of buttons along the bottom in the
-- same order on every screen: Back on the left, the screen's own buttons
-- (answers, Start, nudges), the way forward on the right.
-- The buttons are form fields (touch and the rotary encoder both work); the
-- rest is drawn from the page's paint handler, below the header.
--
--   local screen = ui.new(wiz)
--   -- in step.build():
--   screen:begin()
--   screen:text(title, body, accentLine)
--   screen:picture(art.layout(...), caption)   -- or screen:draw(fn)
--   screen:checks({{label =, answer =, press =}, ...}, focus) -- Yes/No beside it
--   screen:status("Step 1 of 4")              -- in the row, before row()
--   return screen:row(backFn, {{text =, press =, primary =, needsMotion =, small =, weight =}, ...}, forwardSpec)
--   -- in step.paint():
--   screen:paint()
--
-- begin() is called from build() only (it reads form.height()); paint()
-- does not allocate.

if package.loaded["rfsuite.app.setup_wizard_ui"] then
  return package.loaded["rfsuite.app.setup_wizard_ui"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local art = requireModule("app/setup_wizard_art.lua")

local floor = math.floor
local BUTTON_GAP = 6
local MARGIN = 8
local GRID_MIN_H = 30
local GRID_MAX_H = 56
local NEXT = "@i18n(app.modules.setup_wizard.btn_next)@"
local STEP_OF = "@i18n(app.modules.setup_wizard.step_progress_fmt)@"

-- The row's Back and plain Next are small icon-only buttons (as the
-- header's): chevrons, not the header's arrow, which leaves the wizard.
-- Loaded with the module, which the wizard frees when it closes.
local PREV_ICON = lcd.loadMask("app/gfx/nav/prev.png")
local NEXT_ICON = lcd.loadMask("app/gfx/nav/next.png")
-- Row geometry: nav buttons are square-ish, a forward button with words
-- (Save and continue, Save and restart, ...) a fixed width; NAV_GAP keeps
-- the screen's own buttons clear of them; ACTION_MAX stops a lone Start
-- stretching across the screen.
local NAV_W = 48
local FORWARD_TEXT_SHARE = 0.36
local NAV_GAP = 16
local ACTION_MAX_SHARE = 0.4

local Screen = {}
Screen.__index = Screen

local ui = {}

-- Ethos may retain a form callback after form.clear(). Give it a bounded
-- set of dispatchers, never a step closure (which captures its whole screen).
-- Keep slots across visits, but detach their targets before rebuilding/leaving.
local actions = {}
function ui.action(key, target)
  local slot = actions[key]
  if not slot then
    slot = {}
    slot.press = function()
      if slot.target then return slot.target() end
    end
    actions[key] = slot
  end
  slot.target = target
  return slot.press
end

-- The same for a number field's getter and setter.
local values = {}
function ui.value(key, get, set)
  local slot = values[key]
  if not slot then
    slot = {}
    slot.get = function()
      if slot.getTarget then return slot.getTarget() end
      return 0
    end
    slot.set = function(value)
      if slot.setTarget then slot.setTarget(value) end
    end
    values[key] = slot
  end
  slot.getTarget, slot.setTarget = get, set
  return slot.get, slot.set
end

function ui.releaseActions()
  for _, slot in pairs(actions) do slot.target = nil end
  for _, slot in pairs(values) do slot.getTarget, slot.setTarget = nil, nil end
end

-- Modules a step loads only for itself are freed when the step closes, as
-- app/page_runtime.lua's unloadPackageKeys does for other pages; otherwise
-- every step visited leaves its codecs in package.loaded for the rest of the
-- session. A step calls notLoaded() before requiring them and returns the
-- result as `owned`; the shell passes it to unload(). A module that another
-- page or the background task had loaded first is not in the list, so it
-- stays loaded.
function ui.notLoaded(keys)
  local out = {}
  for i = 1, #keys do
    if package.loaded[keys[i]] == nil then out[#out + 1] = keys[i] end
  end
  return out
end

function ui.unload(keys)
  for i = 1, #keys do package.loaded[keys[i]] = nil end
end

function ui.new(wiz)
  return setmetatable({wiz = wiz, view = {lines = {}, rows = {}}, buttonList = {}}, Screen)
end

function Screen:begin()
  local v = self.view
  v.top = form.height() + 4
  v.bottom = nil
  v.title = nil
  v.lines = {}
  v.accentFrom = nil
  v.picture, v.caption, v.drawFn = nil, nil, nil
  v.rows = {}
  v.textStop = nil
  v.pictureStop = nil
  v.checks, v.checksX = nil, nil
  v.status, v.statusX, v.statusY, v.statusH = nil, nil, nil, nil
  self.buttonList = {}
end

-- title (FONT_STD), body (wrapped, FONT_S), accent (wrapped, FONT_S, in the
-- accent colour: a status or warning line), progress ("4 of 4", or true).
-- Any may be nil. With progress the title is the thing being worked on now
-- (a servo, an axis, a check, a mode): it is drawn in the accent colour, and
-- a progress string muted after it. A step's fixed titles stay plain.
function Screen:text(title, body, accent, progress)
  local v = self.view
  local width = lcd.getWindowSize()
  v.title = title
  v.progress = progress
  v.lines = body and self.wiz.wrapLines(body, width - 2 * MARGIN, FONT_S) or {}
  v.accentFrom = nil
  if accent and accent ~= "" then
    v.accentFrom = #v.lines + 1
    local extra = self.wiz.wrapLines(accent, width - 2 * MARGIN, FONT_S)
    for i = 1, #extra do v.lines[#v.lines + 1] = extra[i] end
  end
end

function Screen:picture(layout, caption)
  self.view.picture = layout
  self.view.caption = caption
end

-- fn(x, y, w, h, colors) draws in the space below the text.
function Screen:draw(fn, caption)
  self.view.drawFn = fn
  self.view.caption = caption
end

-- Rows of "label  value" below the text: {{label, value, accent}, ...}.
-- Values may be changed in place later (screen:setRow) without a rebuild.
function Screen:rows(list)
  self.view.rows = list
end

function Screen:setRow(i, value, accent)
  local row = self.view.rows[i]
  if not row or (row[2] == value and row[3] == accent) then return false end
  row[2], row[3] = value, accent
  return true
end

local function addButton(self, rect, key, s, font)
  local field
  if s.icon then
    field = form.addButton(nil, rect, {icon = s.icon, press = ui.action(key, s.press)})
  else
    field = form.addButton(nil, rect, {
      text = s.text,
      options = font + CENTERED,
      press = ui.action(key, s.press),
    })
  end
  -- The field is Ethos userdata: the flags live beside it.
  self.buttonList[#self.buttonList + 1] = {field = field, needsMotion = s.needsMotion, disabled = s.disabled}
  return field
end

-- Where the screen is within its step ("Step 1 of 4"), in the row of buttons:
-- centred on the screen, or in the gap between the buttons when one covers
-- the middle; left out when it does not fit. Call before row().
function Screen:status(text)
  self.view.status = text
end

-- The screen's place in its step: step(2, 5) reads "Schritt 2 von 5" (the
-- wording of the locale). Every step with more than one screen calls it on
-- each screen; a step with one screen does not. Items inside a screen (a
-- servo, a check) keep their own count beside the title.
function Screen:step(i, n)
  self.view.status = string.format(STEP_OF, i, n)
end

-- The right half beside the picture, as the EdgeTX suite's cards. Each entry
-- is one row:
--   {label =, answer =, press =}   a question: the label, its answer a button
--                                  on the right ("Yes" / "No")
--   {answer =, press =, disabled =, needsMotion =}
--                                  an action: a button across the whole half
--   {label =, value =}             a fact: the label, its value where the
--                                  answers sit ("Accelerometer  Available")
--   {label =, number = {min, max, get, set, suffix}, disabled =}
--                                  a value to edit: the label, a number field
--                                  where the answers sit
--   {note =}                       a result in the accent colour, wrapped to
--                                  the half (last, so it moves nothing else)
--   focus  index of the button to return (the one just pressed), or nil
-- The picture moves to the left half. Call after text() (the rows start below
-- it). Returns the field at `focus`.
local CHECK_ROW_GAP = 8
local CHECK_BUTTON_SHARE = 0.2
local CHECK_BUTTON_MIN = 64

function Screen:checks(list, focus)
  local v = self.view
  local width, height = lcd.getWindowSize()
  local room = width - self.wiz.FORM_RIGHT_PADDING
  local x = floor(width / 2)
  lcd.font(FONT_STD)
  local _, titleH = lcd.getTextSize("Ag")
  lcd.font(FONT_S)
  local _, lineH = lcd.getTextSize("Ag")
  local y = v.top + (v.title and (titleH + 2) or 0) + #v.lines * lineH + 8
  local h = math.max(30, floor(height * 0.09))
  local bw = math.max(CHECK_BUTTON_MIN, floor(room * CHECK_BUTTON_SHARE))
  local labelW = room - bw - x - 8
  v.checks, v.checksX = {}, x
  local field
  for i = 1, #list do
    local c = list[i]
    local row = {}
    local rowTop = y
    if c.label then
      -- A label wraps onto two lines when it does not fit beside the answer;
      -- anything beyond the second line is cut short.
      lcd.font(FONT_S)
      local lines = self.wiz.wrapLines(c.label, labelW, FONT_S)
      if #lines > 2 then lines = {lines[1], ui.fit(table.concat(lines, " ", 2), labelW)} end
      row.labelLines = lines
    end
    if c.press then
      local bx = c.label and (room - bw) or x
      local w = room - bx
      -- A long action drops to the small font rather than lose its end.
      lcd.font(FONT_STD)
      local font = (lcd.getTextSize(c.answer) > w - 16) and FONT_S or FONT_STD
      local f = addButton(self, {x = bx, y = y, w = w, h = h}, "check_" .. i,
        {text = c.answer, press = c.press, disabled = c.disabled, needsMotion = c.needsMotion}, font)
      if i == focus then field = f end
      row.y = y + floor((h - lineH) / 2)
      y = y + h + CHECK_ROW_GAP
    elseif c.number then
      -- A number to edit: {min, max, get, set, suffix}.
      local n = c.number
      local get, set = ui.value("check_" .. i, n[3], n[4])
      local f = form.addNumberField(nil, {x = room - bw, y = y, w = bw, h = h}, n[1], n[2], get, set)
      if n[5] and f.suffix then f:suffix(n[5]) end
      self.buttonList[#self.buttonList + 1] = {field = f, needsMotion = c.needsMotion, disabled = c.disabled}
      if i == focus then field = f end
      row.y = y + floor((h - lineH) / 2)
      y = y + h + CHECK_ROW_GAP
    elseif c.note then
      row.lines = self.wiz.wrapLines(c.note, room - x, FONT_S)
      row.y = y
      y = y + #row.lines * lineH + CHECK_ROW_GAP
    else
      row.value, row.valueX = c.value, room - bw
      row.y = y
      y = y + lineH + CHECK_ROW_GAP
    end
    if row.labelLines then
      -- Beside a button the label is centred on it; a plain fact sits on its line.
      local centred = c.press or c.number
      row.labelY = centred and (rowTop + floor((h - #row.labelLines * lineH) / 2)) or rowTop
    end
    v.checks[i] = row
  end
  return field
end

-- One row of buttons along the bottom, always in the same order: Back on the
-- left, the screen's own buttons, the way forward on the right.
--   back     function; nil goes to the previous step (no Back on the first)
--   specs    the screen's own buttons, or nil:
--            {{text =, press =, weight =, primary =, needsMotion =, small =}, ...}
--   forward  {text =, press =, disabled =, needsMotion =}; nil for the
--            default, wiz.forward() (Next, Save and continue, or Save and
--            finish on the last step); false for none, on a question whose
--            answers are the way forward
-- Back and a plain Next are small chevron buttons at the two ends; a way
-- forward that saves, restarts or confirms keeps its words. The screen's own
-- buttons sit between them, NAV_GAP clear. Returns the field to focus: a
-- spec with primary =, else the way forward.
function Screen:row(back, specs, forward)
  specs = specs or {}
  if back == nil and not self.wiz.isFirstStep() then back = self.wiz.previousStep end
  if forward == nil then forward = self.wiz.forward() end

  local width, height = lcd.getWindowSize()
  local h = math.max(36, floor(height * 0.15))
  local y = height - h - 4
  local room = width - self.wiz.FORM_RIGHT_PADDING
  -- The back slot is kept free even where there is no Back (the first screen
  -- of the first step), so the screen's own buttons and the step counter sit
  -- at the same place on every start screen.
  local left, right = NAV_W + NAV_GAP, room
  local focus, forwardField

  if back then
    addButton(self, {x = 0, y = y, w = NAV_W, h = h}, "nav_back", {icon = PREV_ICON, press = back}, FONT_S)
    left = NAV_W + NAV_GAP
  end
  if forward then
    local plain = forward.text == NEXT
    local w = plain and NAV_W or floor(room * FORWARD_TEXT_SHARE)
    local spec = {text = forward.text, icon = plain and NEXT_ICON or nil, press = forward.press,
      disabled = forward.disabled, needsMotion = forward.needsMotion}
    local field = addButton(self, {x = room - w, y = y, w = w, h = h}, "nav_next", spec, FONT_S)
    if not forward.disabled then forwardField = field end
    right = room - w - NAV_GAP
  end

  local specsEnd = left   -- right edge of the screen's own buttons
  if #specs > 0 then
    local total = 0
    for i = 1, #specs do total = total + (specs[i].weight or 1) end
    local free = right - left - BUTTON_GAP * (#specs - 1)
    local most = floor(room * ACTION_MAX_SHARE)
    local x = left
    for i = 1, #specs do
      local s = specs[i]
      local w = math.min(most, floor(free * (s.weight or 1) / total))
      local field = addButton(self, {x = x, y = y, w = w, h = h}, i, s, s.small and FONT_S or FONT_STD)
      if s.primary then focus = field end
      x = x + w + BUTTON_GAP
    end
    specsEnd = x - BUTTON_GAP
  end

  local v = self.view
  if v.status then
    lcd.font(FONT_S)
    local tw = lcd.getTextSize(v.status)
    local gapL = specsEnd + 8
    local gapR = (forward and (right + NAV_GAP) or room) - 8
    local cx = floor(width / 2)
    if cx - floor(tw / 2) < gapL or cx + floor(tw / 2) > gapR then cx = floor((gapL + gapR) / 2) end
    if gapR - gapL >= tw then
      v.statusX, v.statusY, v.statusH = cx, y, h
    else
      v.statusX = nil
    end
  end
  self.view.bottom = y - 4
  self:refresh()
  return focus or forwardField
end

-- Many choices: a grid of buttons filling the space between the text and
-- the row (call row() first). A grid screen has no picture. Returns the
-- field to focus (a spec with primary =), or nil.
function Screen:grid(specs, cols)
  local focus
  local width, height = lcd.getWindowSize()
  local v = self.view
  lcd.font(FONT_S)
  local _, th = lcd.getTextSize("Ag")
  local stop = (v.bottom or (height - 4)) - 4
  local rows = math.ceil(#specs / cols)
  -- The grid sits on the row, its height set by the screen alone, so a status
  -- line that comes or goes in the text above never moves it. Text that runs
  -- into it is cut short (paint(), which keeps the status line).
  local titleBottom = v.top + (v.title and (th + 8) or 0) + 4
  local h = math.max(GRID_MIN_H, math.min(GRID_MAX_H, floor(height * 0.12)))
  h = math.min(h, floor((stop - titleBottom - BUTTON_GAP * (rows - 1)) / rows))
  local top = stop - (rows * h + BUTTON_GAP * (rows - 1))
  -- A picture on a grid screen ends above the grid.
  v.pictureStop = top - 4
  local textBottom = titleBottom + #v.lines * th
  if textBottom > top then v.textStop = top - 2 end
  local w = math.floor((width - self.wiz.FORM_RIGHT_PADDING - BUTTON_GAP * (cols - 1)) / cols)
  for i, s in ipairs(specs) do
    local col, r = (i - 1) % cols, math.floor((i - 1) / cols)
    local field = addButton(self, {x = col * (w + BUTTON_GAP), y = top + r * (h + BUTTON_GAP), w = w, h = h},
      "grid_" .. i, s, FONT_S)
    if s.primary then focus = field end
  end
  v.gridUsed = true
  self:refresh()
  return focus
end

-- Grey out the buttons that move something while the wizard can't.
function Screen:refresh()
  local canMove = self.wiz.canMove()
  for i = 1, #self.buttonList do
    local b = self.buttonList[i]
    if b.field and b.field.enable then
      local enabled = not b.disabled and (not b.needsMotion or canMove)
      if b.enabled ~= enabled then
        b.enabled = enabled
        b.field:enable(enabled)
      end
    end
  end
end

function Screen:paint()
  local v = self.view
  local colors = art.colors()
  local width, height = lcd.getWindowSize()
  local y = v.top
  if v.title then
    lcd.font(FONT_STD)
    lcd.color(v.progress and colors.active or colors.text)
    lcd.drawText(MARGIN, y, v.title, LEFT)
    local tw, th = lcd.getTextSize(v.title)
    if type(v.progress) == "string" then
      lcd.color(colors.muted)
      lcd.drawText(MARGIN + tw + 12, y, v.progress, LEFT)
    end
    y = y + th + 2
  end
  lcd.font(FONT_S)
  -- Cut short by a grid (textStop): the body loses lines from its end, the
  -- accent lines (a status or warning) are kept.
  local _, lineH = lcd.getTextSize("Ag")
  local skipFrom, skipTo = nil, nil
  if v.textStop then
    local fit = math.max(0, floor((v.textStop - y) / lineH))
    local excess = #v.lines - fit
    if excess > 0 then
      local bodyEnd = (v.accentFrom or (#v.lines + 1)) - 1
      skipTo = bodyEnd
      skipFrom = math.max(1, bodyEnd - excess + 1)
    end
  end
  for i = 1, #v.lines do
    if not (skipFrom and i >= skipFrom and i <= skipTo) then
      if v.textStop and y + lineH > v.textStop then break end
      lcd.color((v.accentFrom and i >= v.accentFrom) and colors.active or colors.text)
      lcd.drawText(MARGIN, y, v.lines[i], LEFT)
      y = y + lineH
    end
  end
  if #v.rows > 0 then
    y = y + 4
    local _, th = lcd.getTextSize("Ag")
    local room = width - 2 * MARGIN - 8
    local stop = (v.bottom or height) - th
    for i = 1, #v.rows do
      if y > stop then break end
      local row = v.rows[i]
      local value = row[2] or ""
      lcd.color(colors.muted)
      lcd.drawText(MARGIN, y, row[1], LEFT)
      local lw = lcd.getTextSize(row[1])
      local vw = lcd.getTextSize(value)
      lcd.color(row[3] and colors.active or colors.text)
      if lw + vw + 16 <= room then
        lcd.drawText(width - MARGIN - 8, y, value, RIGHT)
      else
        -- No room beside the label: on its own line, shortened to fit.
        y = y + th
        if vw > room - 16 then value = ui.fit(value, room - 16) end
        lcd.drawText(MARGIN + 16, y, value, LEFT)
      end
      y = y + th + 2
    end
  end
  local bottom = v.bottom or (height - 4)
  if v.pictureStop and v.pictureStop < bottom then bottom = v.pictureStop end
  if v.caption then
    lcd.font(FONT_XS)
    local _, ch = lcd.getTextSize(v.caption)
    lcd.color(colors.muted)
    lcd.drawText(MARGIN, bottom - ch, v.caption, LEFT)
    bottom = bottom - ch
  end
  if v.status and v.statusX then
    lcd.font(FONT_S)
    local _, sh = lcd.getTextSize(v.status)
    lcd.color(colors.muted)
    lcd.drawText(v.statusX, v.statusY + floor((v.statusH - sh) / 2), v.status, CENTERED)
  end
  -- checks(): labels and values in the right half, the picture in the left.
  local pictureW = width
  if v.checks then
    lcd.font(FONT_S)
    lcd.color(colors.text)
    local _, labelH = lcd.getTextSize("Ag")
    for i = 1, #v.checks do
      local c = v.checks[i]
      if c.labelLines then
        for j = 1, #c.labelLines do lcd.drawText(v.checksX, c.labelY + (j - 1) * labelH, c.labelLines[j], LEFT) end
      end
      if c.value then lcd.drawText(c.valueX, c.y, c.value, LEFT) end
      if c.lines then
        lcd.color(colors.active)
        local _, lineH = lcd.getTextSize("Ag")
        for j = 1, #c.lines do lcd.drawText(v.checksX, c.y + (j - 1) * lineH, c.lines[j], LEFT) end
        lcd.color(colors.text)
      end
    end
    pictureW = v.checksX - MARGIN
  end
  if v.picture then
    art.draw(v.picture, 0, y + 4, pictureW, bottom - y - 6, colors)
  elseif v.drawFn then
    -- Beside a list of checks the drawing keeps to the left of them.
    v.drawFn(MARGIN, y + 4, pictureW - 2 * MARGIN, bottom - y - 6, colors)
  end
end

-- text cut to fit maxW in the current font, with "..." at the end. Only
-- reached when a row is too long, so the allocation is rare.
function ui.fit(text, maxW)
  local n = #text
  while n > 1 and lcd.getTextSize(text:sub(1, n) .. "...") > maxW do n = n - 1 end
  return text:sub(1, n) .. "..."
end

-- A horizontal gauge, for live values: a track from x to x + w, a mark at
-- `fraction` (0..1 along it), and optional zone marks (also 0..1).
function ui.gauge(x, y, w, h, fraction, colors, zoneFrom, zoneTo)
  lcd.color(colors.body)
  lcd.drawFilledRectangle(x, y + floor(h / 2) - 2, w, 4)
  if zoneFrom and zoneTo then
    lcd.color(colors.surface)
    local zw = math.max(2, floor(w * (zoneTo - zoneFrom)))
    lcd.drawFilledRectangle(x + floor(w * zoneFrom), y + floor(h / 2) - 3, zw, 6)
  end
  if fraction then
    if fraction < 0 then fraction = 0 elseif fraction > 1 then fraction = 1 end
    lcd.color(colors.active)
    local mx = x + floor(w * fraction)
    lcd.drawFilledRectangle(mx - 3, y, 6, h)
  end
end

package.loaded["rfsuite.app.setup_wizard_ui"] = ui
return ui
