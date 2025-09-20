--[[
 * Copyright (C) Rotorflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]] --
-- Short aliases


-- State
local enableWakeup = false
local lastWakeup   = 0 -- seconds

-- Layout
local w, h   = lcd.getWindowSize()
local btnW   = 100
local btnWs  = btnW - (btnW * 20) / 100
local xRight = w - 15

local x,y

local displayPos = {
  x = xRight - btnW - btnWs - 5 - btnWs,
  y = rfsuite.app.radio.linePaddingTop,
  w = 150,
  h = rfsuite.app.radio.navbuttonHeight
}

-- Indices into rfsuite.app.formFields (intentionally 0-based)
local IDX_CPULOAD     = 0
local IDX_FREERAM     = 1
local IDX_BG_TASK     = 2
local IDX_RF_MODULE   = 3
local IDX_MSP         = 4
local IDX_TELEM       = 5
local IDX_FBLCONNECTED= 6
local IDX_APIVERSION  = 7

-- Helpers
local function setStatus(field, ok, dashIfNil)
  if not field then return end
  if dashIfNil and ok == nil then
    field:value("-")
    return
  end
  if ok then
    field:value("@i18n(app.modules.rfstatus.ok)@")
    field:color(GREEN)
  else
    field:value("@i18n(app.modules.rfstatus.error)@")
    field:color(RED)
  end
end

local function addStatusLine(captionText, initialText)
  -- captionText should already be a literal string or an @i18n(...)@ tag
  rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine(captionText)
  rfsuite.app.formFields[rfsuite.app.formFieldCount] = form.addStaticText(
    rfsuite.app.formLines[rfsuite.app.formLineCnt],
    displayPos,
    initialText
  )
  rfsuite.app.formLineCnt     = rfsuite.app.formLineCnt + 1
  rfsuite.app.formFieldCount  = rfsuite.app.formFieldCount + 1
end

local function moduleEnabled()
  local m0 = model.getModule(0)
  local m1 = model.getModule(1)
  return (m0 and m0:enable()) or (m1 and m1:enable()) or false
end

local function haveMspSensor()
  local sportSensor = system.getSource({ appId = 0xF101 })
  local elrsSensor  = system.getSource({ crsfId = 0x14, subIdStart = 0, subIdEnd = 1 })
  return sportSensor or elrsSensor
end

-- Page open
local function openPage(pidx, title, script)
  enableWakeup = false
  rfsuite.app.triggers.closeProgressLoader = true
  form.clear()

  -- track page
  rfsuite.app.lastIdx    = pidx
  rfsuite.app.lastTitle  = title
  rfsuite.app.lastScript = script

  -- header
  rfsuite.app.ui.fieldHeader(
    "@i18n(app.modules.diagnostics.name)@" .. " / " .. "@i18n(app.modules.rfstatus.name)@"
  )

  -- fresh tables so lookups are never stale/nil
  rfsuite.app.formLineCnt    = 0
  rfsuite.app.formFields     = {}
  rfsuite.app.formLines      = {}
  rfsuite.app.formFieldCount = 0

  -- CPU Load %
  addStatusLine("@i18n(app.modules.fblstatus.cpu_load)@", string.format("%.1f%%", rfsuite.performance.cpuload or 0))

  -- Free RAM
  addStatusLine("@i18n(app.modules.msp_speed.memory_free)@", string.format("%.1f kB", rfsuite.performance.freeram or 0))

  -- Background Task status
  addStatusLine("@i18n(app.modules.rfstatus.bgtask)@",
    rfsuite.tasks.active() and "@i18n(app.modules.rfstatus.ok)@" or "@i18n(app.modules.rfstatus.error)@"
  )

  -- RF Module Status
  addStatusLine("@i18n(app.modules.rfstatus.rfmodule)@",
    moduleEnabled() and "@i18n(app.modules.rfstatus.ok)@" or "@i18n(app.modules.rfstatus.error)@"
  )

  -- MSP Sensor Status
  addStatusLine("@i18n(app.modules.rfstatus.mspsensor)@",
    haveMspSensor() and "@i18n(app.modules.rfstatus.ok)@" or "@i18n(app.modules.rfstatus.error)@"
  )

  -- Telemetry Sensor Status
  addStatusLine("@i18n(app.modules.rfstatus.telemetrysensors)@", "-")

  -- FBL Connected
  addStatusLine("@i18n(app.modules.rfstatus.fblconnected)@", "-")

  -- API Version
  addStatusLine("@i18n(app.modules.rfstatus.apiversion)@", "-")

  enableWakeup = true
end

-- Lifecycle hooks
local function postLoad(self) rfsuite.utils.log("postLoad", "debug") end
local function postRead(self) rfsuite.utils.log("postRead", "debug") end

-- Periodic refresh
local function wakeup()
  if not enableWakeup then return end

  local now = os.clock()
  if (now - lastWakeup) < 2 then return end
  lastWakeup = now

  -- CPU Load
  do
    local field = rfsuite.app.formFields and rfsuite.app.formFields[IDX_CPULOAD]
    if field then
      field:value(string.format("%.1f%%", rfsuite.performance.cpuload or 0))
    end
  end

  -- Free RAM
  do
    local field = rfsuite.app.formFields and rfsuite.app.formFields[IDX_FREERAM]
    if field then
      field:value(string.format("%.1f kB", rfsuite.utils.round(rfsuite.performance.freeram or 0, 1)))
    end
  end

  -- Background Task
  do
    local field = rfsuite.app.formFields and rfsuite.app.formFields[IDX_BG_TASK]
    local ok    = rfsuite.tasks and rfsuite.tasks.active()
    setStatus(field, ok)
  end

  -- RF Module
  do
    local field = rfsuite.app.formFields and rfsuite.app.formFields[IDX_RF_MODULE]
    setStatus(field, moduleEnabled())
  end

  -- MSP Sensor
  do
    local field = rfsuite.app.formFields and rfsuite.app.formFields[IDX_MSP]
    setStatus(field, haveMspSensor())
  end

  -- Telemetry Sensors
  do
    local field = rfsuite.app.formFields and rfsuite.app.formFields[IDX_TELEM]
    if field then
      local sensors = rfsuite.tasks
                    and rfsuite.tasks.telemetry
                    and rfsuite.tasks.telemetry.validateSensors(false)
                    or false
      if type(sensors) == "table" then
        -- empty list means OK
        setStatus(field, #sensors == 0)
      else
        -- unknown status
        setStatus(field, nil, true) -- dash
      end
    end
  end

  -- FBL Connected
  do
    local field = rfsuite.app.formFields and rfsuite.app.formFields[IDX_FBLCONNECTED]
    if field then
      local isConnected = rfsuite.session and rfsuite.session.isConnected 
      if isConnected then
        setStatus(field, isConnected)
      else
        setStatus(field, nil, true) -- dash 
      end
    end
  end

  -- API Version
  do
    local field = rfsuite.app.formFields and rfsuite.app.formFields[IDX_APIVERSION]
    if field then
      local isInvalid = not rfsuite.session.apiVersionInvalid 
      setStatus(field, isInvalid)
    end
  end

end

-- Events
local function event(widget, category, value, x, y)
  -- if close event detected go to section home page
  if (category == EVT_CLOSE and value == 0) or value == 35 then
    rfsuite.app.ui.openPage(
      pageIdx,
      "@i18n(app.modules.diagnostics.name)@",
      "diagnostics/diagnostics.lua"
    )
    return true
  end
end

-- Nav menu
local function onNavMenu()
  rfsuite.app.ui.progressDisplay(nil, nil, true)
  rfsuite.app.ui.openPage(
    pageIdx,
    "@i18n(app.modules.diagnostics.name)@",
    "diagnostics/diagnostics.lua"
  )
end

return {
  reboot           = false,
  eepromWrite      = false,
  minBytes         = 0,
  wakeup           = wakeup,
  refreshswitch    = false,
  simulatorResponse= {},
  postLoad         = postLoad,
  postRead         = postRead,
  openPage         = openPage,
  onNavMenu        = onNavMenu,
  event            = event,
  navButtons = {
    menu   = true,
    save   = false,
    reload = false,
    tool   = false,
    help   = false,
  },
  API = {},
}
