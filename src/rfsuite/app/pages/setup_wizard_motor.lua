-- Setup Wizard step: Motor & ESC. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepMotor.svelte:
--
--   prepare   the safety card: servos unplugged, blades off
--   protocol  the ESC protocol (MSP_MOTOR_CONFIG motor_pwm_protocol) in one
--             drop-down: PWM, DShot150 and DShot300 first, then every other
--             protocol (DShot600, Castle, OneShot, ProShot, DISABLED, ...).
--             DShot600 is not among the first: on long ESC leads it picks up
--             noise, so only a pilot who knows that should choose it.
--   rpm       the RPM source, only while a governor runs
--   poles     the main motor's pole count, the bell with its magnets beside it
--   main      the main gear ratio. One stage: the pinion and the main gear teeth.
--             Two stages (a drop-down), as with an intermediate shaft such as a
--             SAB Goblin's: the pinion, the intermediate gear that meshes with the
--             pinion, the intermediate gear that meshes with the main gear, and the
--             main gear. The firmware keeps two numbers only: pinion x the gear on
--             the main side, and the gear on the pinion side x main gear. The ratio
--             is their quotient, and the four counts are kept for the session.
--   tail      the tail gear ratio: the tail drive gear in and the tail rotor gear
--             out, for a pitch tail only (a motor tail has no gears to the main rotor)
--   done      the protocol, the poles and the gear ratios
--
-- Every change goes to the FC straight away and only applies after a
-- restart (at the Connect step). As the configurator's fixConfig(), a
-- change to or from Castle Link sets ESC telemetry on save: Castle uses its
-- own telemetry, so the ESC_SENSOR feature goes on and the serial ESC
-- telemetry protocol off; leaving Castle turns ESC_SENSOR off when no serial
-- ESC telemetry protocol is set. (The configurator also keeps ESC_SENSOR on
-- for a serial telemetry port; with Castle that protocol is 0, so the same.)
--
-- DShot150 has no bidirectional DShot, so it gives the FC no RPM: the
-- governor and the RPM filter need a fast RPM source, bidirectional DShot
-- (DShot300 and up) or an RPM sensor (isMotorFastRpmSourceActive() in the
-- firmware). While DShot150 is set the protocol screen says so, and choosing
-- it turns bidirectional DShot (use_dshot_telemetry) off in the same write:
-- an ESC that does not answer bidirectional requests may not arm.

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
  dshot150Note = "@i18n(app.modules.setup_wizard.mot_dshot150_note)@",
  poles = "@i18n(app.modules.setup_wizard.mot_poles)@",
  polesText = "@i18n(app.modules.setup_wizard.mot_poles_text)@",
  mainTitle = "@i18n(app.modules.setup_wizard.mot_main_title)@",
  mainText = "@i18n(app.modules.setup_wizard.mot_main_text)@",
  tailTitle = "@i18n(app.modules.setup_wizard.mot_tail_title)@",
  tailText = "@i18n(app.modules.setup_wizard.mot_tail_text)@",
  stage = "@i18n(app.modules.setup_wizard.mot_stage)@",
  stageOne = "@i18n(app.modules.setup_wizard.mot_stage_one)@",
  stageTwo = "@i18n(app.modules.setup_wizard.mot_stage_two)@",
  interPinion = "@i18n(app.modules.setup_wizard.mot_inter_pinion)@",
  interMain = "@i18n(app.modules.setup_wizard.mot_inter_main)@",
  pinion = "@i18n(app.modules.setup_wizard.mot_pinion)@",
  mainGear = "@i18n(app.modules.setup_wizard.mot_main_gear)@",
  tailIn = "@i18n(app.modules.setup_wizard.mot_tail_in)@",
  tailOut = "@i18n(app.modules.setup_wizard.mot_tail_out)@",
  tailFrom = "@i18n(app.modules.setup_wizard.mot_stage)@",
  tailFromMain = "@i18n(app.modules.setup_wizard.mot_stage_one)@",
  tailFromInter = "@i18n(app.modules.setup_wizard.mot_stage_two)@",
  tailDrivePulley = "@i18n(app.modules.setup_wizard.mot_tail_drive_pulley)@",
  tailRotorPulley = "@i18n(app.modules.setup_wizard.mot_tail_rotor_pulley)@",
  tailNeedsTwo = "@i18n(app.modules.setup_wizard.mot_tail_needs_two)@",
  pairSingle = "@i18n(app.modules.setup_wizard.mot_pair_single)@",
  pairStage1 = "@i18n(app.modules.setup_wizard.mot_pair_stage1)@",
  pairStage2 = "@i18n(app.modules.setup_wizard.mot_pair_stage2)@",
  pairTail = "@i18n(app.modules.setup_wizard.mot_pair_tail)@",
  pairTailShaft = "@i18n(app.modules.setup_wizard.mot_pair_tail_shaft)@",
  stageDirect = "@i18n(app.modules.setup_wizard.mot_stage_direct)@",
  ratioDirect = "@i18n(app.modules.setup_wizard.mot_ratio_direct)@",
  pairMainMesh = "@i18n(app.modules.setup_wizard.mot_pair_main_mesh)@",
  ratio = "@i18n(app.modules.setup_wizard.mot_ratio_fmt)@",
  mainRatio = "@i18n(app.modules.setup_wizard.mot_main_ratio)@",
  tailRatio = "@i18n(app.modules.setup_wizard.mot_tail_ratio)@",
  restartNote = "@i18n(app.modules.setup_wizard.mot_restart_note)@",
  protocol = "@i18n(app.modules.setup_wizard.mot_protocol)@",
  doneTitle = "@i18n(app.modules.setup_wizard.mot_done_title)@",
  restart = "@i18n(app.modules.setup_wizard.swa_restart)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
  prepareTitle = "@i18n(app.modules.setup_wizard.rcv_prepare_title)@",
  prepareText = "@i18n(app.modules.setup_wizard.mot_prepare_text)@",
  unplugged = "@i18n(app.modules.setup_wizard.sen_servos_unplugged)@",
  blades = "@i18n(app.modules.setup_wizard.sen_blades_removed)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  rpmRow = "@i18n(app.modules.setup_wizard.rpm_row_source)@",
  rpmIntro = "@i18n(app.modules.setup_wizard.rpm_intro)@",
  rpmWire = "@i18n(app.modules.setup_wizard.rpm_wire)@",
  rpmDshot = "@i18n(app.modules.setup_wizard.rpm_dshot)@",
}

local CASTLE = motorConfig.CASTLE_PROTOCOL
-- No bidirectional DShot, so no RPM (see the header).
local DSHOT150 = 5
-- The tiles.
local COMMON = {
  {value = 0, name = "PWM"},
  {value = DSHOT150, name = "DShot150"},
  {value = 6, name = "DShot300"},
}
-- Names for the protocols in the Other drop-down; the rest keep the codec's.
local NAMES = {
  [7] = "DShot600",
  [CASTLE] = "Castle",
}
-- The Other drop-down's first entry, shown while a tile's protocol is set;
-- choosing it writes nothing.
local OTHER_NONE = -1

local ESC_SENSOR_BIT = 27
-- The RPM source: bidirectional DShot telemetry (feature bit 28), as the governor needs it.
local RPM_BIT = 28
-- DShot300 and DShot600: the protocols that carry the RPM back on the signal.
local DSHOT_RPM = {[6] = true, [7] = true}

-- The largest gear count the firmware takes (a product of two counts must fit too).
local TRAIN_MAX = 50000
-- The two-stage train's counts in drawing order, and the fields they make up.
local TRAIN_KEYS = {"pinion", "pinionSide", "mainSide", "main"}

-- Whether the FC has Castle saved, across visits to this step in one wizard
-- session (see setup_wizard_swash.lua's `bases`): a protocol change left
-- unsaved and changed again must still be compared with what is stored.
-- The same table keeps the gear stage and its counts for the session.
local bases = package.loaded["rfsuite.setup_wizard.motor"] or setmetatable({}, {__mode = "k"})
package.loaded["rfsuite.setup_wizard.motor"] = bases

local function protocolName(value)
  for _, c in ipairs(COMMON) do
    if c.value == value then return c.name end
  end
  if NAMES[value] then return NAMES[value] end
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

-- A whole number within [min, max].
local function inRange(v, min, max)
  return type(v) == "number" and v % 1 == 0 and v >= min and v <= max
end

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  -- A gear count that is not set (missing or 0) reads as 1: the 1:1 default.
  local function gearOr1(v)
    if v == nil or v < 1 then return 1 end
    return v
  end

  local screen = "prepare"
  local answers = {unplugged = false, blades = false}   -- the safety answers, kept across rebuilds
  local picture = art.image("motor-esc", 220, 160)
  local cfg = nil
  local loadFailed = false
  local base = bases[wiz]
  if not base then
    base = {}
    bases[wiz] = base
  end

  local poleNumber = {field = "motor_pole_count_0", min = 2, max = 254}
  -- The gear last set, as {screen = "main" | "tail", pos = its place in the picture}:
  -- the picture shows it in blue. Ethos tells a script nothing about which field has
  -- the focus, so the picture follows the value being turned instead.
  local lastGear = nil

  -- The Other drop-down: "Other", then every protocol this FC takes that has
  -- no tile (SRXL2 only from the API version that has it), by name.
  local otherValues = {{T.other, OTHER_NONE}}
  local isTile = {}
  for _, c in ipairs(COMMON) do isTile[c.value] = true end
  local function addOther(value)
    if not isTile[value] then otherValues[#otherValues + 1] = {protocolName(value), value} end
  end
  for _, entry in ipairs(motorConfig.BASE_PROTOCOL_CHOICES) do
    if entry[2] == motorConfig.DISABLED_PROTOCOL and wiz.apiAtLeast(motorConfig.SRXL2_MIN_API_MINOR) then
      addOther(motorConfig.SRXL2_PROTOCOL)
    end
    addOther(entry[2])
  end
  local function inOther(value)
    for i = 2, #otherValues do
      if otherValues[i][2] == value then return true end
    end
    return false
  end

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

  -- The RPM source: bidirectional DShot telemetry (the motor config) and the RPM
  -- feature bit beside the ESC telemetry bit, read fresh so neither is overwritten.
  -- Not with DShot150, which sends no RPM back.
  local function rpmDshot() return cfg.use_dshot_telemetry == 1 end
  local function setRpmSource(dshot)
    if dshot and cfg.motor_pwm_protocol == DSHOT150 then return end
    if rpmDshot() == dshot then return end
    wiz.send(featureConfig.buildReadMessage(function(f)
      local want = withBit(f.enabledFeatures, RPM_BIT, dshot)
      wiz.send(featureConfig.buildWriteMessage({enabledFeatures = want}))
    end))
    edit(function(c) c.use_dshot_telemetry = dshot and 1 or 0 end)
  end

  local function setProtocol(value)
    if cfg.motor_pwm_protocol == value then return end
    edit(function(c)
      c.motor_pwm_protocol = value
      if value == DSHOT150 then c.use_dshot_telemetry = 0 end
    end)
    stageEscTelemetry()
    -- With a governor the RPM source follows the protocol: DShot300 and DShot600 carry it.
    if wiz.governorMode() > 0 then setRpmSource(DSHOT_RPM[value] == true) end
  end

  local function ratioText(a, b)
    a, b = gearOr1(a), gearOr1(b)
    return string.format(T.ratio, b / a)
  end

  -- The RPM source is asked only when a governor runs.
  local function rpmActive() return wiz.governorMode() > 0 end

  -- The screens after the safety card, in order. The tail only for a pitch tail.
  local function sequence()
    local list = {"protocol"}
    if rpmActive() then list[#list + 1] = "rpm" end
    list[#list + 1] = "poles"
    list[#list + 1] = "main"
    if not wiz.motorised() then list[#list + 1] = "tail" end
    list[#list + 1] = "done"
    return list
  end
  local function indexOf(name)
    local list = sequence()
    for i = 1, #list do
      if list[i] == name then return i end
    end
    return nil
  end
  -- The screen's place in the step: the safety card is 1.
  local function stepOf(name)
    if name == "prepare" then return 1 end
    return (indexOf(name) or #sequence()) + 1
  end
  local function total() return #sequence() + 1 end
  local function goTo(name)
    screen = name
    wiz.rebuild()
  end
  local function nextScreen()
    local i = indexOf(screen)
    return i and sequence()[i + 1] or screen
  end
  local function prevScreen()
    local i = indexOf(screen)
    if i == nil or i == 1 then return "prepare" end
    return sequence()[i - 1]
  end

  -- Gear stage: one stage, or two with an intermediate gear. The two-stage counts
  -- are kept in base.train; they are rebuilt from the FC's two products when they
  -- do not match them (a Discard, or the FC changed elsewhere).
  local function stageCount() return base.stages == 2 and 2 or 1 end
  local function ensureTrain()
    if stageCount() ~= 2 or not cfg then return end
    local p0 = gearOr1(cfg.main_rotor_gear_ratio_0)
    local p1 = gearOr1(cfg.main_rotor_gear_ratio_1)
    local t = base.train
    if t == nil or t.pinion * t.mainSide ~= p0 or t.pinionSide * t.main ~= p1 then
      -- Starting from the FC's values: the intermediate gear 1:1, so the products stay.
      base.train = {pinion = p0, pinionSide = 1, mainSide = 1, main = p1}
    end
  end

  -- Sets several motor config fields in one write; the change is kept for Discard.
  -- Returns true when a value changed. No rebuild: a number field being edited stays open.
  local function setFields(changes)
    local changed = false
    for field, value in pairs(changes) do
      if cfg[field] ~= value then changed = true end
    end
    if not changed then return false end
    wiz.change("motor_config", cfg, function(o)
      cfg = wiz.copy(o)
      wiz.send(motorConfig.buildWriteMessage(cfg))
    end)
    for field, value in pairs(changes) do cfg[field] = value end
    wiz.send(motorConfig.buildWriteMessage(cfg))
    wiz.requestReboot()
    return true
  end

  local function setValue(field, value)
    return setFields({[field] = value})
  end

  -- A ratio (in hundredths) as whole counts: the smallest k that makes ratio x k whole, so
  -- the first count is k and the second is ratio x k.
  local function ratioProducts(ratio)
    for k = 1, 100 do
      if (ratio * k) % 100 == 0 then return k, k, ratio * k / 100 end
    end
    return 1, 1, ratio / 100
  end

  -- The tail drive. From the main shaft: the tail drive gear and the tail rotor gear as
  -- they are (base.tail.a, b). From the intermediate shaft (a pulley on it, as the SAB
  -- Goblin's, or a T-Rex): the drive pulley a and the tail rotor pulley b, driven by the
  -- intermediate shaft. The main gear drives that shaft through the intermediate gear on
  -- the main side (base.tail.mesh, or the two-stage train's main-side gear). The FC keeps
  -- two products: field 0 = mesh x b (the tail side), field 1 = main gear x a (the drive
  -- side), so the ratio is drive : tail, as the RS7's 100 : 21 = 4.76. A ratio only (from 3) is stored as whole counts at that ratio. Kept for the
  -- session, as the train.
  local function ensureTail()
    if base.tail == nil then
      base.tail = {from = 1, a = gearOr1(cfg.tail_rotor_gear_ratio_1), b = gearOr1(cfg.tail_rotor_gear_ratio_0), mesh = 1}
    end
    return base.tail
  end
  -- The main gear and the intermediate gear meshing with it: the two-stage train's counts
  -- when there is one, else the one-stage main gear and the tail's own mesh count.
  local function mainTooth()
    if stageCount() == 2 and base.train then return base.train.main end
    return gearOr1(cfg.main_rotor_gear_ratio_1)
  end
  local function meshTooth(t)
    if stageCount() == 2 and base.train then return base.train.mainSide end
    return gearOr1(t.mesh)
  end
  local function tailProducts(t)
    if t.from == 3 then
      local _, p0, p1 = ratioProducts(t.ratio or 100)
      return {tail_rotor_gear_ratio_0 = p0, tail_rotor_gear_ratio_1 = p1}
    end
    -- Field 0 is the tail side, field 1 the drive side: field 1 / field 0 = drive : tail.
    if t.from == 2 then
      return {tail_rotor_gear_ratio_0 = meshTooth(t) * t.b, tail_rotor_gear_ratio_1 = mainTooth() * t.a}
    end
    return {tail_rotor_gear_ratio_0 = t.b, tail_rotor_gear_ratio_1 = t.a}
  end
  local function applyTail()
    return setFields(tailProducts(ensureTail()))
  end

  -- The intermediate gears of a two-stage train start at 1:1: the values as they were stay
  -- as the pinion and main gear teeth, and the intermediate teeth are entered after.
  local INTERMEDIATE_DEFAULT = 1
  local function gcd(a, b)
    while b ~= 0 do a, b = b, a % b end
    return a
  end
  -- The ratio only: the overall ratio in hundredths, as whole counts (see ratioProducts).
  local function applyDirect()
    local _, p0, p1 = ratioProducts(base.direct.ratio)
    local changed = setFields({main_rotor_gear_ratio_0 = p0, main_rotor_gear_ratio_1 = p1})
    applyTail()
    return changed
  end
  local function stageChoice()
    if base.direct then return 3 end
    return stageCount()
  end

  local function setStages(v)
    v = (v == 2 or v == 3) and v or 1
    if v == stageChoice() then return end
    if v == 3 then
      if not base.direct then
        local ratio = math.floor(gearOr1(cfg.main_rotor_gear_ratio_1) * 100 / gearOr1(cfg.main_rotor_gear_ratio_0) + 0.5)
        base.direct = {ratio = math.max(100, math.min(10000, ratio))}
      end
      base.stages = 1
      base.train = nil
      applyDirect()
      wiz.rebuild()
      return
    end
    local d = base.direct
    base.direct = nil
    if v == 2 and d then
      -- The ratio as a two-stage train: the pinion's count k, a 1:1 intermediate, the main gear.
      local k, _, p1 = ratioProducts(d.ratio)
      base.stages = 2
      base.train = {pinion = k, pinionSide = INTERMEDIATE_DEFAULT, mainSide = 1, main = p1}
      applyTail()
      wiz.rebuild()
      return
    end
    if v == 2 then
      local pinion, main = gearOr1(cfg.main_rotor_gear_ratio_0), gearOr1(cfg.main_rotor_gear_ratio_1)
      -- Both intermediate gears take the main gear's count: a 1:1 pair to the main gear, which
      -- keeps the main ratio and a tail drive from the intermediate shaft. Too large for the
      -- counts: 1:1 with 1.
      local x = main
      if pinion * x > TRAIN_MAX or x * main > TRAIN_MAX then x = INTERMEDIATE_DEFAULT end
      if pinion * x > TRAIN_MAX or x * main > TRAIN_MAX then return end
      base.stages = 2
      base.train = {pinion = pinion, pinionSide = x, mainSide = x, main = main}
      setFields({main_rotor_gear_ratio_0 = pinion * x, main_rotor_gear_ratio_1 = x * main})
      applyTail()
    else
      local t = base.train
      if t then
        -- The tail keeps the main-side gear for a drive from the intermediate shaft.
        ensureTail().mesh = t.mainSide
        local p0, p1 = t.pinion * t.mainSide, t.pinionSide * t.main
        -- The pinion keeps its teeth when the main gear comes out in whole teeth at the
        -- same ratio; otherwise the smallest whole pair with that ratio.
        local main = (t.pinion * p1) / p0
        if main == math.floor(main) and main <= TRAIN_MAX then
          setFields({main_rotor_gear_ratio_0 = t.pinion, main_rotor_gear_ratio_1 = main})
        else
          local g = gcd(p0, p1)
          setFields({main_rotor_gear_ratio_0 = p0 / g, main_rotor_gear_ratio_1 = p1 / g})
        end
      end
      base.stages = 1
      base.train = nil
      applyTail()
    end
    wiz.rebuild()
  end

  local function focusOf(name)
    if lastGear and lastGear.screen == name then return lastGear.pos end
    return nil
  end

  -- The picture's caption: its own line, then the restart note once a value has been
  -- changed. The note is in the caption, not the text above, so a change redraws it
  -- in place (a rebuild would drop the field being edited).
  local function caption(text, restart)
    if restart and wiz.rebootPending() then
      return text and (text .. "\n" .. T.restartNote) or T.restartNote
    end
    return text
  end

  -- The poles screen's picture: the bell with its magnets.
  local function polesPicture()
    local poles = cfg.motor_pole_count_0 or 0
    scr:picture(art.poles(poles, tostring(poles)), caption(nil, true))
  end

  -- The main gear picture: the pair (one stage) or the gear train (two stages), with
  -- the gear at `focus` in blue, its ratio above and the caption below.
  local function mainPicture(focus, restart)
    if base.direct then
      -- A fixed picture of a one-stage pair, with no counts: the ratio alone has no teeth to show.
      scr:picture(art.gears(8, 32, nil, nil, nil, string.format(T.ratio, base.direct.ratio / 100)),
        caption(T.mainRatio, restart))
      return
    end
    local ratio = ratioText(cfg.main_rotor_gear_ratio_0, cfg.main_rotor_gear_ratio_1)
    if stageCount() == 2 and base.train then
      local t = base.train
      scr:picture(art.gearTrain({t.pinion, t.pinionSide, t.mainSide, t.main}, focus, ratio), caption(T.mainRatio, restart))
    else
      local a, b = gearOr1(cfg.main_rotor_gear_ratio_0), gearOr1(cfg.main_rotor_gear_ratio_1)
      scr:picture(art.gears(a, b, focus, tostring(a), tostring(b), ratio), caption(T.mainRatio, restart))
    end
  end

  -- The tail picture: the drive from the main shaft as one pair; from the intermediate
  -- shaft, the chain from the main gear through the intermediate shaft to the tail rotor
  -- pulley (the belt drawn as a mesh). Focus: pos 1 is the drive pulley, pos 2 the tail
  -- rotor pulley, pos 3 the intermediate gear on the main side.
  local function tailPicture(focus)
    local t = ensureTail()
    if t.from == 3 then
      -- A fixed picture: the ratio alone has no teeth to show.
      scr:picture(art.gears(3, 5, nil, nil, nil, string.format(T.ratio, (t.ratio or 100) / 100)), caption(T.tailRatio, true))
      return
    end
    local ratio = ratioText(cfg.tail_rotor_gear_ratio_0, cfg.tail_rotor_gear_ratio_1)
    if t.from == 2 then
      -- Drawn left to right: tail rotor pulley, drive pulley on the intermediate shaft,
      -- main-side intermediate gear on the same shaft, main gear.
      local f = nil
      f = ({[1] = 2, [2] = 1, [3] = 3, [4] = 4})[focus]
      scr:picture(art.gearTrain({t.b, t.a, meshTooth(t), mainTooth()}, f, ratio), caption(T.tailRatio, true))
    else
      scr:picture(art.gears(t.a, t.b, focus, tostring(t.a), tostring(t.b), ratio), caption(T.tailRatio, true))
    end
  end

  -- The ratio only, turned: refused when the counts would not fit, else kept and sent.
  local function setDirectRatio(v)
    if not inRange(v, 100, 10000) then return end
    local _, p0, p1 = ratioProducts(v)
    if p0 > TRAIN_MAX or p1 > TRAIN_MAX then return end
    base.direct = {ratio = v}
    applyDirect()
    lastGear = {screen = "main", pos = 2}
    mainPicture(focusOf("main"), true)
    wiz.invalidate()
  end
  local function setTailRatio(v)
    if not inRange(v, 100, 10000) then return end
    local _, p0, p1 = ratioProducts(v)
    if p0 > TRAIN_MAX or p1 > TRAIN_MAX then return end
    ensureTail().ratio = v
    applyTail()
    tailPicture(nil)
    wiz.invalidate()
  end

  local function setPoles(v)
    if inRange(v, poleNumber.min, poleNumber.max) and setValue(poleNumber.field, v) then
      polesPicture()
      wiz.invalidate()
    end
  end

  -- A main gear turned to a new count (pos 1 to 4 for two stages, 1 or 2 for one).
  local function setMainGear(pos, v)
    if not inRange(v, 1, TRAIN_MAX) then return end
    lastGear = {screen = "main", pos = pos}
    if stageCount() == 2 then
      local t = {}
      for k, val in pairs(base.train) do t[k] = val end
      t[TRAIN_KEYS[pos]] = v
      if t.pinion * t.mainSide <= TRAIN_MAX and t.pinionSide * t.main <= TRAIN_MAX then
        base.train = t
        setFields({main_rotor_gear_ratio_0 = t.pinion * t.mainSide, main_rotor_gear_ratio_1 = t.pinionSide * t.main})
      end
    else
      setValue(pos == 1 and "main_rotor_gear_ratio_0" or "main_rotor_gear_ratio_1", v)
    end
    applyTail()
    mainPicture(focusOf("main"), true)
    wiz.invalidate()
  end

  -- A tail value turned: refused when a product would not fit, else kept and sent.
  -- Position 3 is the intermediate gear on the main side: in a two-stage train it is the
  -- train's own count.
  local function setTailGear(pos, v)
    if not inRange(v, 1, TRAIN_MAX) then return end
    if pos == 3 and stageCount() == 2 then
      setMainGear(3, v)
    else
      local t = ensureTail()
      local candidate = {from = t.from, a = t.a, b = t.b, mesh = t.mesh, ratio = t.ratio}
      if pos == 1 then candidate.a = v elseif pos == 2 then candidate.b = v else candidate.mesh = v end
      local p = tailProducts(candidate)
      if p.tail_rotor_gear_ratio_0 <= TRAIN_MAX and p.tail_rotor_gear_ratio_1 <= TRAIN_MAX then
        base.tail = candidate
        applyTail()
      end
    end
    lastGear = {screen = "tail", pos = pos}
    tailPicture(focusOf("tail"))
    wiz.invalidate()
  end

  -- The tail drive's source: the main shaft, or the intermediate shaft.
  local function setTailFrom(v)
    local from = (v == 2 or v == 3) and v or 1
    local t = ensureTail()
    if t.from == from then return end
    if from == 3 and t.ratio == nil then
      local ratio = math.floor(gearOr1(cfg.tail_rotor_gear_ratio_1) * 100 / gearOr1(cfg.tail_rotor_gear_ratio_0) + 0.5)
      t.ratio = math.max(100, math.min(10000, ratio))
    end
    -- Onto the intermediate shaft: its main-side gear takes the main gear's count (1:1), so
    -- the tail keeps its ratio.
    if from == 2 and t.from == 1 then t.mesh = mainTooth() end
    t.from = from
    applyTail()
    wiz.rebuild()
  end

  -- The main gear, set from the tail screen: the same stored value as on the main screen.
  local function setTailMain(v)
    if not inRange(v, 1, TRAIN_MAX) then return end
    setMainGear(stageCount() == 2 and 4 or 2, v)
    lastGear = {screen = "tail", pos = 4}
    tailPicture(focusOf("tail"))
    wiz.invalidate()
  end

  function self.build()
    scr:begin()
    if screen == "prepare" then
      scr:text(T.prepareTitle, T.prepareText)
      scr:picture(picture)
      scr:step(1, total())
      return scr:safety(answers, {
        {key = "unplugged", label = T.unplugged},
        {key = "blades", label = T.blades},
      }, T.start, function()
        goTo("protocol")
      end)
    end
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
      local status = string.format(T.current, protocolName(current))
      -- The note goes in the accent lines, which the layout keeps under the title.
      if current == DSHOT150 then status = T.dshot150Note .. " " .. status end
      scr:text(T.title, T.intro, status)
      scr:picture(picture)
      scr:step(stepOf("protocol"), total())
      -- A protocol the drop-down does not list yet (a newer FC's) is added, so it is shown and kept.
      if not isTile[current] and current ~= nil and not inOther(current) then addOther(current) end
      local values = {}
      for _, c in ipairs(COMMON) do values[#values + 1] = {text = c.name, value = c.value} end
      for i = 2, #otherValues do values[#values + 1] = {text = otherValues[i][1], value = otherValues[i][2]} end
      local field = scr:checks({
        {label = T.protocol, choice = {values = values,
          get = function() return cfg.motor_pwm_protocol end,
          set = function(v)
            v = tonumber(v)
            if v ~= nil and v ~= OTHER_NONE then setProtocol(v) end
          end}},
      })
      local rowField = scr:row(function() goTo("prepare") end, nil,
        {text = T.next, press = function() goTo(nextScreen()) end})
      return field or rowField

    elseif screen == "rpm" then
      scr:text(T.rpmRow, T.rpmIntro)
      scr:step(stepOf("rpm"), total())
      scr:picture(picture)
      local dshotOk = cfg.motor_pwm_protocol ~= DSHOT150
      local field = scr:checks({
        {label = T.rpmRow, choice = {
          values = {{text = T.rpmWire, value = 0}, {text = T.rpmDshot, value = 1}},
          get = function() return rpmDshot() and 1 or 0 end,
          set = function(v) setRpmSource(v == 1) end,
          disabled = not dshotOk}},
        {note = T.dshot150Note, muted = true},
      })
      local rowField = scr:row(function() goTo(prevScreen()) end, nil,
        {text = T.next, press = function() goTo(nextScreen()) end})
      return field or rowField

    elseif screen == "poles" then
      scr:text(T.poles, T.polesText)
      scr:step(stepOf("poles"), total())
      polesPicture()
      local field = scr:checks({
        {label = T.poles, number = {poleNumber.min, poleNumber.max,
          function() return cfg.motor_pole_count_0 or poleNumber.min end,
          setPoles}},
      })
      local rowField = scr:row(function() goTo(prevScreen()) end, nil,
        {text = T.next, press = function() goTo(nextScreen()) end})
      return field or rowField

    elseif screen == "main" then
      ensureTrain()
      local two = stageCount() == 2
      -- Two stages carry more rows: the title alone, so the rows fit on the X18.
      scr:text(T.mainTitle, (not two) and T.mainText or nil)
      scr:step(stepOf("main"), total())
      mainPicture(focusOf("main"), true)
      local rows = {
        {label = T.stage, choice = {
          values = {{text = T.stageOne, value = 1}, {text = T.stageTwo, value = 2}, {text = T.stageDirect, value = 3}},
          get = function() return stageChoice() end,
          set = function(v) setStages(tonumber(v)) end}},
      }
      -- Each stage's two counts side by side, "a : b".
      local function pairOf(from, to)
        return {{1, TRAIN_MAX, function() return base.train[TRAIN_KEYS[from]] end, function(v) setMainGear(from, v) end},
          {1, TRAIN_MAX, function() return base.train[TRAIN_KEYS[to]] end, function(v) setMainGear(to, v) end}}
      end
      if base.direct then
        rows[#rows + 1] = {label = T.ratioDirect, number = {100, 10000,
          function() return base.direct.ratio end, setDirectRatio, ":1", 2}}
      elseif two then
        rows[#rows + 1] = {label = T.pairStage1, pair = pairOf(1, 2)}
        rows[#rows + 1] = {label = T.pairStage2, pair = pairOf(3, 4)}
      else
        rows[#rows + 1] = {label = T.pairSingle, pair = {
          {1, TRAIN_MAX, function() return gearOr1(cfg.main_rotor_gear_ratio_0) end, function(v) setMainGear(1, v) end},
          {1, TRAIN_MAX, function() return gearOr1(cfg.main_rotor_gear_ratio_1) end, function(v) setMainGear(2, v) end}}}
      end
      local field = scr:checks(rows)
      local rowField = scr:row(function() goTo(prevScreen()) end, nil,
        {text = T.next, press = function() goTo(nextScreen()) end})
      return field or rowField

    elseif screen == "tail" then
      local t = ensureTail()
      local viaShaft = t.from == 2
      scr:text(T.tailTitle, T.tailText)
      scr:step(stepOf("tail"), total())
      tailPicture(focusOf("tail"))
      local rows = {
        {label = T.tailFrom, choice = {
          values = {{text = T.tailFromMain, value = 1}, {text = T.tailFromInter, value = 2}, {text = T.stageDirect, value = 3}},
          get = function() return ensureTail().from end,
          set = function(v) setTailFrom(tonumber(v)) end}},
      }
      if t.from == 3 then
        rows[#rows + 1] = {label = T.ratioDirect, number = {100, 10000,
          function() return ensureTail().ratio or 100 end, setTailRatio, ":1", 2}}
      elseif viaShaft then
        rows[#rows + 1] = {label = T.pairMainMesh, pair = {
          {1, TRAIN_MAX, function() return meshTooth(ensureTail()) end, function(v) setTailGear(3, v) end},
          {1, TRAIN_MAX, function() return mainTooth() end, setTailMain}}}
        rows[#rows + 1] = {label = T.pairTailShaft, pair = {
          {1, TRAIN_MAX, function() return ensureTail().a end, function(v) setTailGear(1, v) end},
          {1, TRAIN_MAX, function() return ensureTail().b end, function(v) setTailGear(2, v) end}}}
      else
        rows[#rows + 1] = {label = T.pairTail, pair = {
          {1, TRAIN_MAX, function() return ensureTail().a end, function(v) setTailGear(1, v) end},
          {1, TRAIN_MAX, function() return ensureTail().b end, function(v) setTailGear(2, v) end}}}
      end
      local field = scr:checks(rows)
      local rowField = scr:row(function() goTo(prevScreen()) end, nil,
        {text = T.next, press = function() goTo(nextScreen()) end})
      return field or rowField
    end

    -- done
    scr:text(T.doneTitle, nil, wiz.rebootPending() and T.restart or nil)
    scr:step(total(), total())
    mainPicture(nil, false)
    local rows = {
      {label = T.protocol, value = protocolName(cfg.motor_pwm_protocol)},
      {label = T.poles, value = tostring(cfg.motor_pole_count_0 or 0)},
      {label = T.stage, value = base.direct and T.stageDirect or (stageCount() == 2 and T.stageTwo or T.stageOne)},
      {label = T.mainRatio, value = ratioText(cfg.main_rotor_gear_ratio_0, cfg.main_rotor_gear_ratio_1)},
    }
    if not wiz.motorised() then
      rows[#rows + 1] = {label = T.tailRatio, value = ratioText(cfg.tail_rotor_gear_ratio_0, cfg.tail_rotor_gear_ratio_1)}
    end
    local field = scr:checks(rows)
    local rowField = scr:row(function() goTo(prevScreen()) end)
    return field or rowField
  end

  -- Changes redraw their picture in place, so the step needs no rebuild on a change
  -- (setup_wizard.lua's markChanged()).
  self.liveEdits = true

  function self.paint() scr:paint() end

  function self.released() scr:refresh() end

  return self
end

return {new = new, owned = OWNED}
