-- Setup Wizard step: Motor & ESC. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepMotor.svelte:
--
--   protocol  the ESC protocol (MSP_MOTOR_CONFIG motor_pwm_protocol): PWM,
--             DShot300, DShot600 or Castle as tiles; any other protocol the
--             FC already has is shown and kept (the ESC & Motors page sets
--             the rest)
--   numbers   one screen each: main motor poles, pinion and main gear teeth,
--             and for a pitch tail the tail drive's two gears, nudged with
--             buttons
--   done      the protocol and gear ratios
--
-- Every change goes to the FC straight away and only applies after a
-- restart (at the Connect step). As the configurator's fixConfig(), a
-- change to or from Castle Link sets ESC telemetry on save: Castle uses its
-- own telemetry, so the ESC_SENSOR feature goes on and the serial ESC
-- telemetry protocol off; leaving Castle turns ESC_SENSOR off when no serial
-- ESC telemetry protocol is set. (The configurator also keeps ESC_SENSOR on
-- for a serial telemetry port; with Castle that protocol is 0, so the same.)

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")
-- Freed when the step closes (app/setup_wizard_ui.lua's notLoaded()).
local OWNED = ui.notLoaded({"rfsuite.lib.msp_motor_config", "rfsuite.lib.msp_esc_sensor_config",
  "rfsuite.lib.msp_feature_config"})
local motorConfig = requireModule("lib/msp_motor_config.lua")
local escSensor = requireModule("lib/msp_esc_sensor_config.lua")
local featureConfig = requireModule("lib/msp_feature_config.lua")

local T = {
  title = "@i18n(app.modules.setup_wizard.mot_title)@",
  intro = "@i18n(app.modules.setup_wizard.mot_intro)@",
  current = "@i18n(app.modules.setup_wizard.swa_current_fmt)@",
  other = "@i18n(app.modules.setup_wizard.mot_other)@",
  poles = "@i18n(app.modules.setup_wizard.mot_poles)@",
  polesText = "@i18n(app.modules.setup_wizard.mot_poles_text)@",
  pinion = "@i18n(app.modules.setup_wizard.mot_pinion)@",
  pinionText = "@i18n(app.modules.setup_wizard.mot_pinion_text)@",
  mainGear = "@i18n(app.modules.setup_wizard.mot_main_gear)@",
  mainGearText = "@i18n(app.modules.setup_wizard.mot_main_gear_text)@",
  tailIn = "@i18n(app.modules.setup_wizard.mot_tail_in)@",
  tailInText = "@i18n(app.modules.setup_wizard.mot_tail_in_text)@",
  tailOut = "@i18n(app.modules.setup_wizard.mot_tail_out)@",
  tailOutText = "@i18n(app.modules.setup_wizard.mot_tail_out_text)@",
  ratio = "@i18n(app.modules.setup_wizard.mot_ratio_fmt)@",
  mainRatio = "@i18n(app.modules.setup_wizard.mot_main_ratio)@",
  tailRatio = "@i18n(app.modules.setup_wizard.mot_tail_ratio)@",
  protocol = "@i18n(app.modules.setup_wizard.mot_protocol)@",
  doneTitle = "@i18n(app.modules.setup_wizard.mot_done_title)@",
  restart = "@i18n(app.modules.setup_wizard.swa_restart)@",
  progress = "@i18n(app.modules.setup_wizard.progress_fmt)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
}

local CASTLE = motorConfig.CASTLE_PROTOCOL
local COMMON = {
  {value = 0, name = "PWM"},
  {value = 6, name = "DShot300"},
  {value = 7, name = "DShot600"},
  {value = CASTLE, name = "Castle"},
}

local ESC_SENSOR_BIT = 27

-- Whether the FC has Castle saved, across visits to this step in one wizard
-- session (see setup_wizard_swash.lua's `bases`): a protocol change left
-- unsaved and changed again must still be compared with what is stored.
local bases = package.loaded["rfsuite.setup_wizard.motor"] or setmetatable({}, {__mode = "k"})
package.loaded["rfsuite.setup_wizard.motor"] = bases

local function protocolName(value)
  for _, c in ipairs(COMMON) do
    if c.value == value then return c.name end
  end
  local list = motorConfig.BASE_PROTOCOL_CHOICES
  for i = 1, #list do
    if list[i][2] == value then return list[i][1] end
  end
  if value == motorConfig.SRXL2_PROTOCOL then return "SRXL2" end
  return tostring(value)
end

local function hasBit(value, bit)
  return math.floor((value or 0) / (2 ^ bit)) % 2 == 1
end

local function withBit(value, bit, on)
  value = value or 0
  local has = hasBit(value, bit)
  if on and not has then return value + 2 ^ bit end
  if not on and has then return value - 2 ^ bit end
  return value
end

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  local screen = "protocol"
  local cfg = nil
  local loadFailed = false
  local base = bases[wiz]
  if not base then
    base = {}
    bases[wiz] = base
  end

  -- The number screens, in order. The tail drive gears only for a pitch
  -- tail: a motor tail has no gears to the main rotor.
  local numbers = {
    {field = "motor_pole_count_0", title = T.poles, text = T.polesText, min = 2, max = 254, steps = {-2, 2}},
    {field = "main_rotor_gear_ratio_0", title = T.pinion, text = T.pinionText, min = 1, max = 50000,
      steps = {-10, -1, 1, 10}},
    {field = "main_rotor_gear_ratio_1", title = T.mainGear, text = T.mainGearText, min = 1, max = 50000,
      steps = {-10, -1, 1, 10}},
  }
  if not wiz.motorised() then
    numbers[#numbers + 1] = {field = "tail_rotor_gear_ratio_0", title = T.tailIn, text = T.tailInText,
      min = 1, max = 50000, steps = {-10, -1, 1, 10}}
    numbers[#numbers + 1] = {field = "tail_rotor_gear_ratio_1", title = T.tailOut, text = T.tailOutText,
      min = 1, max = 50000, steps = {-10, -1, 1, 10}}
  end
  local ni = 1

  wiz.fetch({
    motor = function(ok, err) return motorConfig.buildReadMessage(ok, err) end,
  }, function(results, failed)
    cfg = results.motor
    loadFailed = failed or cfg == nil
    if cfg and base.castle == nil then base.castle = cfg.motor_pwm_protocol == CASTLE end
    wiz.rebuild()
  end)

  -- Telemetry follows Castle on save (see the header).
  local function stageEscTelemetry()
    local castle = cfg.motor_pwm_protocol == CASTLE
    wiz.commitOnSave("motor_esc_telemetry", function(onDone, onFail)
      if castle == base.castle then
        onDone()
        return
      end
      wiz.send(escSensor.buildReadMessage(function(esc)
        local function writeFeature()
          wiz.send(featureConfig.buildReadMessage(function(f)
            local want = withBit(f.enabledFeatures, ESC_SENSOR_BIT, castle or (esc.protocol or 0) > 0)
            if want == f.enabledFeatures then
              base.castle = castle
              onDone()
              return
            end
            wiz.send(featureConfig.buildWriteMessage({enabledFeatures = want}, function()
              base.castle = castle
              onDone()
            end, onFail))
          end, onFail))
        end
        if castle and (esc.protocol or 0) ~= 0 then
          esc.protocol = 0
          wiz.send(escSensor.buildWriteMessage(esc, writeFeature, onFail))
        else
          writeFeature()
        end
      end, onFail))
    end)
  end

  local function edit(fn)
    wiz.change("motor_config", cfg, function(o)
      cfg = wiz.copy(o)
      wiz.send(motorConfig.buildWriteMessage(cfg))
    end)
    fn(cfg)
    wiz.send(motorConfig.buildWriteMessage(cfg))
    wiz.requestReboot()
    wiz.rebuild()
  end

  local function setProtocol(value)
    if cfg.motor_pwm_protocol == value then return end
    edit(function(c) c.motor_pwm_protocol = value end)
    stageEscTelemetry()
  end

  local function nudge(n, delta)
    local value = (cfg[n.field] or n.min) + delta
    if value < n.min then value = n.min elseif value > n.max then value = n.max end
    if value == cfg[n.field] then return end
    edit(function(c) c[n.field] = value end)
  end

  local function ratioText(a, b)
    if not a or a <= 0 then return "-" end
    return string.format(T.ratio, (b or 0) / a)
  end

  function self.build()
    scr:begin()
    if loadFailed then
      scr:text(T.title, "@i18n(app.msg_load_failed_body)@")
      return scr:row()
    end
    if not cfg then
      scr:text(T.title, "@i18n(app.msg_loading)@")
      return scr:row()
    end

    if screen == "protocol" then
      local current = cfg.motor_pwm_protocol
      scr:text(T.title, T.intro, string.format(T.current, protocolName(current)))
      local forward = scr:row(nil, nil, {text = T.next, press = function()
        ni = 1
        screen = "number"
        wiz.rebuild()
      end})
      local specs = {}
      local known = false
      for _, c in ipairs(COMMON) do
        if c.value == current then known = true end
        specs[#specs + 1] = {text = c.name, primary = c.value == current, press = function() setProtocol(c.value) end}
      end
      if not known then
        -- The FC's own protocol, kept: picking it again changes nothing.
        specs[#specs + 1] = {text = string.format(T.other, protocolName(current)), primary = true,
          press = function() end}
      end
      return scr:grid(specs, 2) or forward

    elseif screen == "number" then
      local n = numbers[ni]
      scr:text(n.title, n.text, wiz.rebootPending() and T.restart or nil, string.format(T.progress, ni, #numbers))
      scr:rows({{n.title, tostring(cfg[n.field] or 0), true}})
      -- The magnets, or the gear pair drawn to its tooth counts with the ratio.
      if n.field == "motor_pole_count_0" then
        scr:picture(art.poles(cfg.motor_pole_count_0 or 0, tostring(cfg.motor_pole_count_0 or 0)))
      else
        local prefix = n.field:find("main_rotor") and "main_rotor_gear_ratio_" or "tail_rotor_gear_ratio_"
        local a, b = cfg[prefix .. "0"] or 0, cfg[prefix .. "1"] or 0
        scr:picture(art.gears(a, b, n.field:sub(-1) == "0" and 1 or 2, tostring(a), tostring(b), ratioText(a, b)))
      end
      local specs = {}
      for _, d in ipairs(n.steps) do
        specs[#specs + 1] = {text = (d > 0 and "+" or "") .. d, small = true, weight = 0.7,
          press = function() nudge(n, d) end}
      end
      return scr:row(function()
        if ni > 1 then ni = ni - 1 else screen = "protocol" end
        wiz.rebuild()
      end, specs, {text = T.next, press = function()
        if ni < #numbers then ni = ni + 1 else screen = "done" end
        wiz.rebuild()
      end})
    end

    -- done
    scr:text(T.doneTitle, nil, wiz.rebootPending() and T.restart or nil)
    local rows = {
      {T.protocol, protocolName(cfg.motor_pwm_protocol)},
      {T.poles, tostring(cfg.motor_pole_count_0 or 0)},
      {T.mainRatio, ratioText(cfg.main_rotor_gear_ratio_0, cfg.main_rotor_gear_ratio_1)},
    }
    if not wiz.motorised() then
      rows[#rows + 1] = {T.tailRatio, ratioText(cfg.tail_rotor_gear_ratio_0, cfg.tail_rotor_gear_ratio_1)}
    end
    scr:rows(rows)
    local a, b = cfg.main_rotor_gear_ratio_0 or 0, cfg.main_rotor_gear_ratio_1 or 0
    scr:picture(art.gears(a, b, nil, tostring(a), tostring(b), nil))
    return scr:row(function()
      ni = #numbers
      screen = "number"
      wiz.rebuild()
    end)
  end

  function self.paint() scr:paint() end

  function self.released() scr:refresh() end

  return self
end

return {new = new, owned = OWNED}
