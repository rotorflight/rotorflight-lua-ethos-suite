-- Setup -> Governor -> Bypass Curve page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local governorConfig = requireModule("lib/msp_governor_config.lua")

local PAGE_TITLE = "@i18n(app.modules.governor.menu_curves_long)@"
local FIELD_COUNT = 9
local FIELD_GAP = 5

local function curveKey(index)
  return "gov_bypass_throttle_curve_" .. tostring(index)
end

local function clampPercent(value)
  value = tonumber(value or 0) or 0
  if value < 0 then return 0 end
  if value > 100 then return 100 end
  return math.floor(value + 0.5)
end

local function requestRepaint()
  if lcd and lcd.invalidate then
    lcd.invalidate()
  elseif form and form.invalidate then
    form.invalidate()
  end
end

local function windowSize()
  local w, h = 800, 480
  if lcd and lcd.getWindowSize then
    local gotW, gotH = lcd.getWindowSize()
    if type(gotW) == "number" and gotW > 0 then w = gotW end
    if type(gotH) == "number" and gotH > 0 then h = gotH end
  elseif system and system.getVersion then
    local version = system.getVersion()
    w = version.lcdWidth or w
    h = version.lcdHeight or h
  end
  return w, h
end

local function open(opts)
  local curve = {}
  local activeIndex = nil

  local runtime
  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "setgovcurv",
    mspModule = governorConfig,
    opts = opts,
    profileField = "none",
    rebootAfterSave = true,
    unloadPackageKeys = {"rfsuite.lib.msp_governor_config"},
    onLoaded = function()
      for i = 1, FIELD_COUNT do
        curve[i] = clampPercent((runtime.data[curveKey(i)] or 0) / 2)
      end
      requestRepaint()
    end,
    beforeSave = function(rt)
      for i = 1, FIELD_COUNT do
        rt.data[curveKey(i)] = clampPercent(curve[i]) * 2
      end
    end,
    onPaint = function()
      if not lcd or not lcd.drawLine then return end
      local w, h = windowSize()

      local graphMarginX = 34
      local bottomFieldY = h - 76
      local gx = graphMarginX
      local gy = 62
      local gw = w - (graphMarginX * 2)
      local gh = bottomFieldY - gy - 12
      if gw < 100 or gh < 40 then return end

      if lcd.color and lcd.GREY then lcd.color(lcd.GREY(90)) end
      for i = 0, 4 do
        local y = gy + math.floor((gh * i) / 4 + 0.5)
        lcd.drawLine(gx, y, gx + gw, y)
      end
      for i = 0, FIELD_COUNT - 1 do
        local x = gx + math.floor((gw * i) / (FIELD_COUNT - 1) + 0.5)
        lcd.drawLine(x, gy, x, gy + gh)
      end

      local lastX, lastY
      if lcd.color and lcd.RGB then lcd.color(lcd.RGB(255, 255, 255)) end
      for i = 1, FIELD_COUNT do
        local v = clampPercent(curve[i])
        local x = gx + math.floor((gw * (i - 1)) / (FIELD_COUNT - 1) + 0.5)
        local y = gy + gh - math.floor((gh * v) / 100 + 0.5)
        if lastX then lcd.drawLine(lastX, lastY, x, y) end
        if lcd.drawFilledCircle then
          if lcd.color and lcd.RGB and activeIndex == i then lcd.color(lcd.RGB(255, 190, 0)) end
          lcd.drawFilledCircle(x, y, activeIndex == i and 4 or 3)
          if lcd.color and lcd.RGB then lcd.color(lcd.RGB(255, 255, 255)) end
        end
        lastX, lastY = x, y
      end
    end,
  })

  form.clear()
  runtime:buildChrome()
  -- Captured instead of closing over `runtime` directly in each field
  -- setter below -- matching app/pages/pids.lua's own dataRef convention
  -- (see its comment): Ethos retains some form callback closures past
  -- this page's own lifetime, and controlRef.runtime gets nilled on
  -- dispose (app/page_runtime.lua's own PageRuntime:dispose()), so
  -- whatever gets retained here stays small instead of pinning the whole
  -- disposed PageRuntime.
  local controlRef = runtime.controlRef
  local function markDirty()
    local rt = controlRef.runtime
    if rt then rt:markDirty() end
  end

  local w, h = windowSize()
  local margin = 34
  local bottomY = h - 76
  local fieldH = 42
  local fieldW = math.floor((w - (margin * 2) - (FIELD_GAP * (FIELD_COUNT - 1))) / FIELD_COUNT)

  for index = 1, FIELD_COUNT do
    local x = margin + (index - 1) * (fieldW + FIELD_GAP)
    local field = form.addNumberField(nil, {x = x, y = bottomY, w = fieldW, h = fieldH}, 0, 100,
      function() return curve[index] or 0 end,
      function(value)
        markDirty()
        curve[index] = clampPercent(value)
        requestRepaint()
      end)
    field:suffix("%")
    field:default(0)
    if field.onFocus then
      field:onFocus(function(state)
        if state then
          activeIndex = index
        elseif activeIndex == index then
          activeIndex = nil
        end
        requestRepaint()
      end)
    end
    runtime:registerField("curve" .. tostring(index), field)
  end

  runtime:loadInitial()
end

return {open = open}
