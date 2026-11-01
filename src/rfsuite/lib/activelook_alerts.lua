-- Per-widget ActiveLook alert state. No glasses, form, bus or formatting dependencies.
if package.loaded["rfsuite.lib.activelook_alerts"] then
  return package.loaded["rfsuite.lib.activelook_alerts"]
end
local alerts = {}
local floor = math.floor
local huge = math.huge
local ESC_DELAY = 2
local ESC_HYSTERESIS = 5
local PREVIEW_GOVERNOR_STATES = {7, 8}

local function number(value)
  value = tonumber(value)
  if value and value == value and value > -huge and value < huge then return value end
end

local function clear(entry)
  entry.remaining = 0
  entry.nextAt = nil
  entry.condition = false
  entry.latched = false
  entry.count = 0
  entry.since = nil
end

function alerts.new(settings)
  return {settings = settings, lastAt = nil,
    link = {kind = "rf_link", remaining = 0},
    lost = {kind = "governor_lost", remaining = 0},
    temp = {kind = "esc_temp", remaining = 0},
    fuel = {kind = "low_fuel", remaining = 0},
    status = {kind = "governor_status", remaining = 0},
    preview = {kind = "low_fuel", blinkOn = true}}
end

function alerts.reset(state)
  clear(state.link)
  clear(state.lost)
  clear(state.temp)
  clear(state.fuel)
  clear(state.status)
  state.active = nil
  state.fuelSeeded = false
  state.previousGovernor = nil
  state.lastAt = nil
end

local function advance(state, now)
  local previous = state.lastAt
  state.lastAt = now
  if state.paused or not previous then return end
  local active = state.active
  if not active then return end
  local delta = math.max(0, now - previous)
  local remaining = active.remaining - delta
  if remaining > 0 then
    active.remaining = remaining
  else
    active.remaining = 0
    if active.condition and (active.repeats == 0 or active.count < active.repeats) then
      active.nextAt = now + remaining + active.duration
    end
    state.active = nil
  end
end

local function start(entry, seconds, repeats)
  entry.duration = seconds
  entry.repeats = repeats or 1
  entry.remaining = seconds
  entry.count = 1
  entry.nextAt = nil
  entry.latched = true
end

local function cancel(state, entry)
  if state.active == entry then state.active = nil end
  clear(entry)
end

function alerts.configure(state, settings)
  state.settings = settings
  if not settings.rf_link_warning then cancel(state, state.link) end
  if not settings.low_fuel_warning then cancel(state, state.fuel) end
  if not settings.esc_temp_warning then cancel(state, state.temp) end
  if not settings.governor_lost_warning then cancel(state, state.lost) end
  if not settings.governor_status_overlays then cancel(state, state.status) end
end

-- Manual layout previews pause automatic display budgets, not telemetry detection.
function alerts.setPreview(state, mode, now)
  advance(state, now)
  state.paused = mode ~= nil
  if mode == "low_fuel" or mode == "esc_temp" or mode == "governor_lost" or mode == "governor_status" or mode == "rf_link" then
    state.previewStart = now
    state.previewMode = mode
    state.preview.kind = mode
  else
    state.previewMode = nil
  end
  cancel(state, state.status)
end

function alerts.update(state, data, phase, now)
  advance(state, now)
  if data.connected ~= true then
    alerts.reset(state)
    state.lastAt = now
    return
  end
  local settings = state.settings
  if not settings.enabled then alerts.reset(state); state.lastAt = now; return end
  local fuel = number(data.fuelPercent)
  local seeded = state.fuelSeeded
  if fuel then state.fuelSeeded = true end
  local governor = number(data.governorState)
  if governor and (governor % 1 ~= 0 or governor < 0 or (governor > 8 and governor ~= 100 and governor ~= 101)) then governor = nil end
  local previous = state.previousGovernor
  -- Missing samples cannot invent transitions, but a later valid sample can.
  if governor then state.previousGovernor = governor end
  local armed = data.isArmed == true
  local flying = armed and phase == "inflight"
  if not flying then
    cancel(state, state.link)
    cancel(state, state.fuel)
    cancel(state, state.temp)
    cancel(state, state.lost)
  else
    local link = state.link
    local quality = number(data.linkQuality)
    local limit = data.linkQualityIsPercent and settings.rf_link_percent_limit or settings.rf_link_limit
    if not settings.rf_link_warning then
      cancel(state, link)
    elseif not quality or quality < 0 or quality > 100 then
      link.since = nil
      link.condition = false
      link.nextAt = nil
    else
      if link.limit ~= limit then link.limit = limit; link.since = nil end
      if quality >= limit + 5 then
        link.latched = false
        link.condition = false
        link.nextAt = nil
        link.since = nil
        link.count = 0
      elseif quality <= limit then
        link.condition = true
        if not link.latched then
          if not link.since then link.since = now end
          if now - link.since >= 2 then start(link, settings.rf_link_seconds, settings.rf_link_repeats) end
        end
      else
        link.since = nil
        link.condition = link.latched == true
      end
    end
    local low = state.fuel
    if not settings.low_fuel_warning then
      cancel(state, low)
    elseif fuel then
      low.condition = fuel <= 0
      if fuel > 0 then
        low.latched = false
        low.nextAt = nil
        low.count = 0
      elseif seeded and not low.latched then
        start(low, settings.low_fuel_seconds, data.lowFuelRepeats or settings.low_fuel_repeats)
      end
    else
      low.condition = false
      low.nextAt = nil
    end

    local temp = state.temp
    local value = number(data.tempEsc)
    local limit = number(data.escTempLimit)
    if not settings.esc_temp_warning then
      cancel(state, temp)
    elseif not value or value < -50 or value > 300 or not limit then
      temp.since = nil
      temp.condition = false
      temp.nextAt = nil
    else
      if temp.limit ~= limit then
        temp.limit = limit
        temp.since = nil
      end
      if value <= limit - ESC_HYSTERESIS then
        temp.latched = false
        temp.condition = false
        temp.nextAt = nil
        temp.since = nil
        temp.count = 0
      elseif value >= limit then
        temp.condition = true
        if not temp.latched then
          if not temp.since then temp.since = now end
          if now - temp.since >= ESC_DELAY then
            start(temp, settings.esc_temp_seconds, data.escTempRepeats or settings.esc_temp_repeats)
          end
        end
      else
        temp.since = nil
        -- Once triggered, stay in this episode until the hysteresis reset.
        temp.condition = temp.latched == true
      end
    end

    local lost = state.lost
    if not settings.governor_lost_warning then
      cancel(state, lost)
    elseif governor then
      lost.condition = governor == 6
      if governor ~= 6 then
        lost.latched = false
      elseif previous ~= nil and previous ~= 6 then
        start(lost, settings.governor_lost_seconds)
      end
    end
  end

  local status = state.status
  if not armed or (phase ~= "armed" and phase ~= "inflight")
      or not settings.governor_status_overlays then
    cancel(state, status)
  elseif governor and previous ~= nil and governor ~= previous then
    -- Only the newest transition matters; never queue status notifications.
    cancel(state, status)
    if not state.paused and (governor == 7 or governor == 8)
        and state.link.remaining <= 0 and state.lost.remaining <= 0 and state.temp.remaining <= 0 and state.fuel.remaining <= 0 then
      start(status, settings.governor_status_seconds)
      status.governorState = governor
      status.expiresAt = now + settings.governor_status_seconds
    end
  end
end

local function repeatEntry(entry, now)
  if entry.nextAt and now >= entry.nextAt then
    entry.nextAt = nil
    if entry.condition and (entry.repeats == 0 or entry.count < entry.repeats) then
      entry.count = entry.count + 1
      entry.remaining = entry.duration
    end
  end
end

function alerts.current(state, now)
  advance(state, now)
  if state.paused then
    if state.previewMode then
      local elapsed = now - state.previewStart
      state.preview.blinkOn = floor(elapsed) % 2 == 0
      if state.previewMode == "governor_status" then
        state.preview.governorState = PREVIEW_GOVERNOR_STATES[floor(elapsed / 2) % #PREVIEW_GOVERNOR_STATES + 1]
      end
      return state.preview
    end
    return nil
  end
  repeatEntry(state.link, now)
  repeatEntry(state.temp, now)
  repeatEntry(state.fuel, now)
  local status = state.status
  if status.remaining > 0 and now >= status.expiresAt then cancel(state, status) end
  local nextAlert
  if state.link.remaining > 0 then nextAlert = state.link
  elseif state.lost.remaining > 0 then nextAlert = state.lost
  elseif state.temp.remaining > 0 then nextAlert = state.temp
  elseif state.fuel.remaining > 0 then nextAlert = state.fuel
  elseif status.remaining > 0 then nextAlert = status end
  if nextAlert and nextAlert ~= status then cancel(state, status) end
  state.active = nextAlert
  if nextAlert then
    nextAlert.blinkOn = floor(nextAlert.duration - nextAlert.remaining) % 2 == 0
  end
  return nextAlert
end

package.loaded["rfsuite.lib.activelook_alerts"] = alerts
return alerts
