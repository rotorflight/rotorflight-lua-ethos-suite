-- FC status alerts: which conditions in the decoded system_status /
-- system_config telemetry words (lib/system_status.lua, published by
-- tasks/session.lua) get a dashboard footer banner and/or a callout.
--
-- One table of rules so the dashboard (widgets/dashboard.lua) and the
-- callouts (tasks/audio_events.lua's announceSystemAlerts()) always agree on
-- what counts as a problem.
--
-- Rule fields:
--   id         unique key (audio edge state is tracked per id)
--   level      LEVEL.CRITICAL (red banner) or LEVEL.WARNING (amber banner)
--   text       banner text
--   active     function(status, config) -> bool; both are always tables
--              (an empty one for a word the FC is not sending)
--   word       "config" for a rule that reads only system_config; nil means
--              it reads system_status (see hasWords())
--   setting    events.<setting> switch for the callout (nil = banner only)
--   enterSound events/alerts/<file> played when the condition starts
--   debounce   seconds a change must hold before it is announced, so a
--              flickering condition doesn't chatter
--
-- Rules are in priority order: the banner shows the first active one, plus
-- a count of the others. topBanner() allocates nothing, so it is safe on the
-- paint path.
--
-- The two words are separate sensors and a model may select only one, so
-- each rule is evaluated against whichever words are present: the
-- system_config rules (reboot required, Blackbox full) still fire without
-- system_status, and the other way round.

if package.loaded["rfsuite.lib.system_alerts"] then
  return package.loaded["rfsuite.lib.system_alerts"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local codec = requireModule("lib/system_status.lua")

local FAILSAFE = codec.FAILSAFE
local BATTERY = codec.BATTERY
local GOVERNOR = codec.GOVERNOR

local LEVEL = {
  CRITICAL = 1,
  WARNING = 2,
}

local EMPTY = {}

local RULES = {
  -- Critical
  {
    -- Rarely reaches the radio (telemetry rides the same link), but shown
    -- whenever it does. The spoken "failsafe" comes from the flight-mode callout.
    id = "failsafe",
    level = LEVEL.CRITICAL,
    text = "@i18n(widgets.dashboard.alert_failsafe)@",
    active = function(s)
      local phase = s.failsafePhase
      return phase ~= nil and phase ~= FAILSAFE.IDLE and phase ~= FAILSAFE.RX_LOSS_RECOVERED
    end,
  },
  {
    id = "battery_critical",
    level = LEVEL.CRITICAL,
    text = "@i18n(widgets.dashboard.alert_battery_critical)@",
    active = function(s) return s.batteryState == BATTERY.CRITICAL end,
  },
  {
    id = "gyro_overflow",
    level = LEVEL.CRITICAL,
    text = "@i18n(widgets.dashboard.alert_gyro_overflow)@",
    active = function(s) return s.gyroOverflow == true end,
    setting = "status_gyro",
    enterSound = "gyrooverflow.wav",
  },

  -- Warnings
  {
    -- Governor lost its headspeed signal and is running on its fallback throttle.
    id = "governor_fallback",
    level = LEVEL.WARNING,
    text = "@i18n(widgets.dashboard.alert_governor_fallback)@",
    active = function(s) return s.governorState == GOVERNOR.FALLBACK end,
  },
  {
    -- gpsCommsLost is latched by tasks/session.lua: the GPS was talking to
    -- the FC earlier this connection and has stopped.
    id = "gps_lost",
    level = LEVEL.WARNING,
    text = "@i18n(widgets.dashboard.alert_gps_lost)@",
    active = function(s) return s.gpsCommsLost == true end,
    setting = "status_gps",
    enterSound = "gpsfail.wav",
    debounce = 1.0,
  },
  {
    id = "acc_uncalibrated",
    level = LEVEL.WARNING,
    text = "@i18n(widgets.dashboard.alert_acc_uncalibrated)@",
    active = function(s) return s.accNotCalibrated == true end,
  },
  {
    id = "override",
    level = LEVEL.WARNING,
    text = "@i18n(widgets.dashboard.alert_override)@",
    active = function(s) return s.overrideActive == true end,
  },
  {
    id = "reboot_required",
    level = LEVEL.WARNING,
    text = "@i18n(widgets.dashboard.alert_reboot_required)@",
    word = "config",
    active = function(_, c) return c.rebootRequired == true end,
  },
  {
    id = "blackbox_full",
    level = LEVEL.WARNING,
    text = "@i18n(widgets.dashboard.alert_blackbox_full)@",
    word = "config",
    active = function(_, c) return c.blackboxFull == true end,
    setting = "status_blackbox",
    enterSound = "bbfull.wav",
  },
}

local systemAlerts = {
  LEVEL = LEVEL,
  RULES = RULES,
}

-- Whether the word a rule reads has arrived. The callouts wait for it before
-- recording a rule's starting state: otherwise, with System Status arriving
-- first, a Blackbox that is already full would be recorded as "not full" and
-- then announced as new when System Config arrives.
function systemAlerts.hasWords(rule, status, config)
  if rule.word == "config" then return config ~= nil end
  return status ~= nil
end

function systemAlerts.isActive(rule, status, config)
  if status == nil and config == nil then return false end
  return rule.active(status or EMPTY, config or EMPTY) == true
end

-- Highest-priority active rule, and how many rules are active in total.
-- Returns nil, 0 when there is nothing to show.
function systemAlerts.topBanner(status, config)
  if status == nil and config == nil then return nil, 0 end
  status = status or EMPTY
  config = config or EMPTY
  local top, count = nil, 0
  for i = 1, #RULES do
    local rule = RULES[i]
    if rule.active(status, config) == true then
      count = count + 1
      if top == nil then top = rule end
    end
  end
  return top, count
end

package.loaded["rfsuite.lib.system_alerts"] = systemAlerts
return systemAlerts
