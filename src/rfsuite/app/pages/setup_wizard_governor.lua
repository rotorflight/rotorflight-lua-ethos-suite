-- Setup Wizard step: Governor. Opened by app/pages/setup_wizard.lua.
--
-- The EdgeTX suite's governor card, as the wizard step: the mode (off, limit,
-- direct, electric, nitro) and, for electric and nitro, the throttle type
-- (normal, switch, function). When the governor runs, the headspeed of each PID
-- profile follows (the first three profiles, as the profile switch uses them).
-- The profiles are read when the headspeed screen opens, with no button; the
-- ramp times are not part of the wizard.
--
-- First a safety card: the servos stay unplugged, and the blades off.
--
--   prepare  servos unplugged and blades off, both on before Start
--   mode     the governor mode, and the throttle type when the governor runs
--   speed    the headspeed of each profile (governor running only)

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")
local profileMsp = requireModule("lib/msp_governor_profile.lua")
local selectMsp = requireModule("lib/msp_select_profile.lua")
local statusMsp = requireModule("lib/msp_status.lua")

local OWNED = {}

local PICTURE_W, PICTURE_H = 220, 160
local MAX_PROFILES = 3
local HEADSPEED_MAX = 50000

local T = {
  prepareTitle = "@i18n(app.modules.setup_wizard.rcv_prepare_title)@",
  prepareText = "@i18n(app.modules.setup_wizard.gov_prepare_text)@",
  unplugged = "@i18n(app.modules.setup_wizard.sen_servos_unplugged)@",
  blades = "@i18n(app.modules.setup_wizard.sen_blades_removed)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
  title = "@i18n(app.modules.setup_wizard.step_governor)@",
  intro = "@i18n(app.modules.setup_wizard.gov_intro)@",
  rowMode = "@i18n(app.modules.setup_wizard.gov_row_mode)@",
  rowThrottle = "@i18n(app.modules.setup_wizard.gov_row_throttle)@",
  hint = "@i18n(app.modules.setup_wizard.gov_rpm_next)@",
  speedTitle = "@i18n(app.modules.setup_wizard.gov_speed_title)@",
  speedText = "@i18n(app.modules.setup_wizard.gov_speed_text)@",
  profileFmt = "@i18n(app.modules.setup_wizard.gov_profile_fmt)@",
  loading = "@i18n(app.msg_loading)@",
  rpm = "@i18n(app.modules.setup_wizard.gov_rpm_unit)@",
  off = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_off)@",
  limit = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_limit)@",
  direct = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_direct)@",
  electric = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_electric)@",
  nitro = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_nitro)@",
  normal = "@i18n(api.GOVERNOR_CONFIG.tbl_throttle_type_normal)@",
  switch = "@i18n(api.GOVERNOR_CONFIG.tbl_throttle_type_switch)@",
  functionMode = "@i18n(api.GOVERNOR_CONFIG.tbl_throttle_type_function)@",
}

-- The governor modes (gov_mode values), and the feature bit that turns the governor on.
local MODE_NAMES = {[0] = T.off, [1] = T.limit, [2] = T.direct, [3] = T.electric, [4] = T.nitro}
local FEATURE_GOVERNOR = 2 ^ 26

-- The throttle types (gov_throttle_type values). The switch and the function
-- type need an electric or nitro governor.
local THROTTLE_NAMES = {[0] = T.normal, [1] = T.switch, [2] = T.functionMode}

-- Runs the steps one after another; each calls next(ok). done(ok) at the end.
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

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  local screen = "prepare"
  local answers = {unplugged = false, blades = false}   -- the safety answers, kept across rebuilds
  local picture = art.image("governor", PICTURE_W, PICTURE_H)
  local bladesPicture = art.image("governor", PICTURE_W, PICTURE_H)

  -- The PID profiles' governor data: {index = {data =, }}, read once per step visit.
  local profiles = {}
  local profileCount = 0
  local activeProfile = 0
  local loaded, loading, busy = false, false, false

  local function go(name)
    screen = name
    wiz.rebuild()
  end

  -- Selects a PID profile on the FC (no rate profile mask: PID profiles have none).
  local function select(index)
    return function(next)
      wiz.send(selectMsp.buildWriteMessage(index, function() next(true) end, function() next(false) end))
    end
  end

  local function readProfile(index)
    return function(next)
      wiz.send(profileMsp.buildReadMessage(function(d)
        profiles[index] = {data = d}
        next(true)
      end, function() next(false) end))
    end
  end

  local function writeProfile(index, data)
    return function(next)
      wiz.send(profileMsp.buildWriteMessage(data, function() next(true) end, function() next(false) end))
    end
  end

  -- Writes one profile's data: select it, write it, select the active profile again.
  local function writeOne(index, data, done)
    local steps = {select(index), writeProfile(index, data), select(activeProfile)}
    chain(steps, function(ok)
      if ok then profiles[index] = {data = data} end
      busy = false
      if done then done(ok) end
      wiz.rebuild()
    end)
  end

  -- Reads the status (which profile is active, how many there are), then every profile
  -- the governor uses, and selects the active one again. Runs once per visit.
  local function loadProfiles()
    if loaded or loading then return end
    loading = true
    local steps = {
      function(next)
        wiz.send(statusMsp.buildReadMessage(function(d)
          activeProfile = tonumber(d and d.current_pid_profile_index) or 0
          profileCount = math.min(tonumber(d and d.pid_profile_count) or 1, MAX_PROFILES)
          next(true)
        end, function() next(false) end))
      end,
    }
    for i = 0, MAX_PROFILES - 1 do
      steps[#steps + 1] = function(next)
        if i >= profileCount then return next(true) end
        chain({select(i), readProfile(i)}, function(ok) next(ok) end)
      end
    end
    -- The active profile is known only once the status has been read: select it then.
    steps[#steps + 1] = function(next) select(activeProfile)(next) end
    chain(steps, function(ok)
      loading = false
      loaded = ok == true
      wiz.rebuild()
    end)
  end

  -- The mode as the EdgeTX card sets it: the governor's mode, the feature bit that
  -- turns it on, and a throttle type the mode cannot use is reset to normal.
  local function setMode(mode)
    wiz.editGovernor(function(g) g.gov_mode = mode end)
    wiz.setFeature(FEATURE_GOVERNOR, mode > 0)
    local config = wiz.governorConfig()
    if mode < 3 and config and config.gov_throttle_type == 1 then
      wiz.editGovernor(function(g) g.gov_throttle_type = 0 end)
    end
    wiz.rebuild()
  end

  local function setThrottle(v)
    wiz.editGovernor(function(g) g.gov_throttle_type = v end)
    wiz.rebuild()
  end

  -- The headspeed of profile index: written to the FC at once, and Discard puts the
  -- original profile back. Changes wait while another write is in flight.
  local function setHeadspeed(index, v)
    local entry = profiles[index]
    if busy or not entry or not entry.data then return end
    if v < 0 or v > HEADSPEED_MAX or v == entry.data.governor_headspeed then return end
    busy = true
    local original = {}
    for k, val in pairs(entry.data) do original[k] = val end
    local data = {}
    for k, val in pairs(entry.data) do data[k] = val end
    data.governor_headspeed = v
    wiz.change("governor_profile_" .. index, original, function(o)
      writeOne(index, o)
    end)
    writeOne(index, data)
  end

  local function modeValues()
    local values = {}
    for m = 0, 4 do values[#values + 1] = {text = MODE_NAMES[m], value = m} end
    return values
  end

  -- The throttle types the mode can use: normal always; switch and function for electric and nitro.
  local function throttleValues(mode)
    local values = {{text = THROTTLE_NAMES[0], value = 0}}
    if mode >= 3 then
      values[#values + 1] = {text = THROTTLE_NAMES[1], value = 1}
      values[#values + 1] = {text = THROTTLE_NAMES[2], value = 2}
    end
    return values
  end

  function self.build()
    scr:begin()
    if screen == "prepare" then
      scr:text(T.prepareTitle, T.prepareText)
      scr:picture(bladesPicture)
      scr:step(1, 3)
      return scr:safety(answers, {
        {key = "unplugged", label = T.unplugged},
        {key = "blades", label = T.blades},
      }, T.start, function() go("mode") end)
    end

    local mode = wiz.governorMode()
    local config = wiz.governorConfig()

    if screen == "speed" then
      scr:step(3, 3)
      if not loaded then
        loadProfiles()
        scr:text(T.speedTitle, T.loading)
        return scr:row(function() go("mode") end)
      end
      scr:text(T.speedTitle, T.speedText)
      scr:picture(picture)
      local rows = {}
      for i = 0, profileCount - 1 do
        local entry = profiles[i]
        rows[#rows + 1] = {label = string.format(T.profileFmt, i + 1), number = {0, HEADSPEED_MAX,
          function() return entry and entry.data and entry.data.governor_headspeed or 0 end,
          function(v) setHeadspeed(i, v) end, T.rpm}}
      end
      local field = scr:checks(rows)
      local rowField = scr:row(function() go("mode") end)
      return field or rowField
    end

    scr:text(T.title, T.intro)
    scr:step(2, 3)
    scr:picture(picture)
    local rows = {
      {label = T.rowMode, choice = {values = modeValues(), get = function() return wiz.governorMode() end,
        set = function(v) setMode(v) end}},
    }
    if mode > 0 then
      rows[#rows + 1] = {label = T.rowThrottle, choice = {values = throttleValues(mode),
        get = function() return config and config.gov_throttle_type or 0 end,
        set = function(v) setThrottle(v) end}}
      rows[#rows + 1] = {note = T.hint, muted = true}
    end
    local field = scr:checks(rows)
    local forward = nil
    if mode > 0 then
      forward = {text = T.next, press = function() go("speed") end}
    end
    local rowField = scr:row(function() go("prepare") end, nil, forward)
    return field or rowField
  end

  function self.paint() scr:paint() end

  function self.released() scr:refresh() end

  return self
end

return {new = new, owned = OWNED}
