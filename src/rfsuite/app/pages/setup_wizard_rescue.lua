-- Setup Wizard step: Rescue. Opened by app/pages/setup_wizard.lua, after Profiles.
--
-- Rescue on or off, and whether it flips the helicopter upright (MSP_RESCUE_PROFILE,
-- see lib/msp_rescue_profile.lua). The rescue profile is kept per PID profile on the
-- FC, and the step sets every profile the same way: each profile is selected, written,
-- and the active one is selected again. Rescue needs a rescue switch: the Modes step
-- assigns it, so the step reads the mode ranges and asks for one when none is set.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")
local rescueMsp = requireModule("lib/msp_rescue_profile.lua")
local selectMsp = requireModule("lib/msp_select_profile.lua")
local statusMsp = requireModule("lib/msp_status.lua")
local modesMsp = requireModule("lib/msp_modes.lua")

local OWNED = {}

local MAX_PROFILES = 6
-- The Rescue box in the mode list (the Modes step's "rescue", id 53).
local RESCUE_BOX = 53

local T = {
  title = "@i18n(app.modules.rescue.name)@",
  intro = "@i18n(app.modules.setup_wizard.resc_intro)@",
  noSwitch = "@i18n(app.modules.setup_wizard.resc_no_switch)@",
  enable = "@i18n(app.modules.rescue.mode_enable)@",
  flip = "@i18n(app.modules.rescue.flip_upright)@",
  off = "@i18n(app.modules.rescue.tbl_off)@",
  on = "@i18n(app.modules.rescue.tbl_on)@",
  noflip = "@i18n(app.modules.rescue.tbl_noflip)@",
  flipOn = "@i18n(app.modules.rescue.tbl_flip)@",
  loading = "@i18n(app.msg_loading)@",
  loadFailed = "@i18n(app.msg_load_failed_body)@",
}

local function chain(steps, done)
  local i = 0
  local function nextStep(ok)
    if ok == false then
      if done then done(false) end
      return
    end
    i = i + 1
    local step = steps[i]
    if not step then
      if done then done(true) end
      return
    end
    step(nextStep)
  end
  nextStep(true)
end

local function copy(t)
  local r = {}
  for k, v in pairs(t) do r[k] = v end
  return r
end

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  -- The picture follows the flip setting: upside down with a turn arrow when the helicopter
  -- flips upright, else an arrow up.
  local flipPicture = art.image("rescue-flip", 220, 160)
  local upPicture = art.image("rescue-up", 220, 160)

  -- The profiles' rescue data by PID profile index, the mode ranges and the active profile,
  -- read once per visit.
  local profiles = {}
  local profileCount = 0
  local activeProfile = 0
  local ranges = {}
  local loaded, loading, busy, failed = false, false, false, false

  -- Selects a PID profile on the FC (PID profiles have no rate profile mask).
  local function select(index)
    return function(next)
      wiz.send(selectMsp.buildWriteMessage(index, function() next(true) end, function() next(false) end))
    end
  end

  local function readRescue(index)
    return function(next)
      wiz.send(rescueMsp.buildReadMessage(function(d)
        profiles[index] = {data = d}
        next(true)
      end, function() next(false) end))
    end
  end

  local function writeRescue(index, data)
    return function(next)
      wiz.send(rescueMsp.buildWriteMessage(data, function()
        profiles[index] = {data = data}
        next(true)
      end, function() next(false) end))
    end
  end

  local statusKnown = false   -- the active profile has been read

  -- Selects the active PID profile again, whatever happened before (a failed step stops the chain).
  local function backToActive()
    if statusKnown then wiz.send(selectMsp.buildWriteMessage(activeProfile)) end
  end

  -- The mode ranges, the status (active profile, count), then every profile, and the
  -- active one selected again.
  local function loadAll()
    if loaded or loading then return end
    loading = true
    local steps = {
      function(next)
        wiz.send(modesMsp.buildModeRangesReadMessage(function(list)
          ranges = list or {}
          next(true)
        end, function() next(false) end))
      end,
      function(next)
        wiz.send(statusMsp.buildReadMessage(function(d)
          activeProfile = tonumber(d and d.current_pid_profile_index) or 0
          profileCount = math.min(tonumber(d and d.pid_profile_count) or 1, MAX_PROFILES)
          statusKnown = true
          next(true)
        end, function() next(false) end))
      end,
    }
    for i = 0, MAX_PROFILES - 1 do
      steps[#steps + 1] = function(next)
        if i >= profileCount then return next(true) end
        chain({select(i), readRescue(i)}, next)
      end
    end
    -- The active profile is known only once the status has been read: select it then.
    steps[#steps + 1] = function(next) select(activeProfile)(next) end
    chain(steps, function(ok)
      loading = false
      loaded = ok == true
      failed = not loaded
      if failed then backToActive() end
      wiz.rebuild()
    end)
  end

  -- The rescue data shown: the active profile's (all profiles are set the same).
  local function current()
    local p = profiles[activeProfile] or profiles[0]
    return p and p.data or {}
  end

  local function switchAssigned()
    for _, r in ipairs(ranges) do
      if r.id == RESCUE_BOX and r.range and r.range.start < r.range["end"] then return true end
    end
    return false
  end

  -- Writes the original data of every profile back (Discard).
  local function restoreAll(originals)
    local steps = {}
    for i = 0, profileCount - 1 do
      if originals[i] then
        steps[#steps + 1] = function(next)
          chain({select(i), writeRescue(i, originals[i])}, next)
        end
      end
    end
    steps[#steps + 1] = function(next) select(activeProfile)(next) end
    chain(steps, function(ok)
      if ok == false then backToActive() end
      wiz.rebuild()
    end)
  end

  -- One setting on every profile: each is selected, written with the value, and the
  -- active profile selected again. The original data is kept for Discard.
  local function setAll(field, value)
    if busy or not loaded then return end
    local originals = {}
    for i = 0, profileCount - 1 do
      if profiles[i] then originals[i] = copy(profiles[i].data) end
    end
    busy = true
    wiz.change("rescue_profiles", originals, function(o) restoreAll(o) end)
    local steps = {}
    for i = 0, profileCount - 1 do
      steps[#steps + 1] = function(next)
        if not profiles[i] then return next(true) end
        local data = copy(profiles[i].data)
        data[field] = value
        chain({select(i), writeRescue(i, data)}, next)
      end
    end
    steps[#steps + 1] = function(next) select(activeProfile)(next) end
    chain(steps, function(ok)
      busy = false
      if ok == false then backToActive() end
      wiz.rebuild()
    end)
  end

  function self.build()
    scr:begin()
    loadAll()
    if failed then
      scr:text(T.title, T.loadFailed)
      return scr:row()
    end
    if not loaded then
      scr:text(T.title, T.loading)
      return scr:row()
    end

    local assigned = switchAssigned()
    scr:text(T.title, T.intro)
    scr:picture(current().rescue_flip_mode == 1 and flipPicture or upPicture)
    local rows = {
      {label = T.enable, choice = {
        values = {{text = T.off, value = 0}, {text = T.on, value = 1}},
        get = function() return current().rescue_mode or 0 end,
        set = function(v) setAll("rescue_mode", tonumber(v)) end,
        disabled = not assigned}},
      {label = T.flip, choice = {
        values = {{text = T.noflip, value = 0}, {text = T.flipOn, value = 1}},
        get = function() return current().rescue_flip_mode or 0 end,
        set = function(v) setAll("rescue_flip_mode", tonumber(v)) end,
        disabled = not assigned}},
    }
    if not assigned then rows[#rows + 1] = {note = T.noSwitch, muted = true} end
    local field = scr:checks(rows)
    local rowField = scr:row()
    return field or rowField
  end

  function self.paint() scr:paint() end

  function self.released() scr:refresh() end

  return self
end

return {new = new, owned = OWNED}
