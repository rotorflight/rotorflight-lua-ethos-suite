local labels = {}
local fields = {}

local folder = "escape32"
local ESC = assert(loadfile("app/modules/esc/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature


local bool = {"ON","OFF"}
local throttleMode = {"FORWARD"}
local ledMode = {"FORWARD"}


fields[#fields + 1] = {t = "Arm (wait for zero throttle)", min = 0, max = 1, vals = {mspHeaderBytes + 24}, table = bool}    -- Wait for 250ms zero throttle on startup:
fields[#fields + 1] = {t = "Active Freewheeling", min = 0, max = 1, vals = {mspHeaderBytes + 24}, table = bool}             -- Damped mode (complementary PWM, active freewheeling): (needs to be on for sine_range to work)
fields[#fields + 1] = {t = "Motor Reverse", min = 0, max = 1, vals = {mspHeaderBytes + 24}, table = bool}                   --  Reversed motor direction:
fields[#fields + 1] = {t = "Brushed Motor", min = 0, max = 1, vals = {mspHeaderBytes + 24}, table = bool}                   --  Brushed mode: -- need to disable dome fields: In this mode, the ESC can be used with brushed motors connected to phases A and B (or C and B). The following settings have no effect: timing, sine_range, sine_power, freq_min, duty_spup, duty_ramp, duty_lock, prot_stall
fields[#fields + 1] = {t = "Motor Timing", min = 1, max = 31, vals = {mspHeaderBytes + 24}}                                  -- Motor Timing
fields[#fields + 1] = {t = "Slow Startup", min = 0, max = 1, vals = {mspHeaderBytes + 24}}                                  -- Sine startup range (%) [0 - off, 5..25]. This value sets the portion of throttle range dedicated to sine startup mode (crawler mode). Damped mode must be enabled before this setting can be activated. Stall protection can be used for seamless transition between sine startup and normal drive.
fields[#fields + 1] = {t = "Minimum PWM Frequency", min = 16, max = 48, vals = {mspHeaderBytes + 24}}                       -- Minimum PWM frequency (kHz) [16..48].
fields[#fields + 1] = {t = "Maximum PWM Frequency", min = 16, max = 96, vals = {mspHeaderBytes + 24}}                       -- Maximum PWM frequency (kHz) [16..96]. Smooth transition from minimum to maximum PWM frequency happens across [30..60] kERPM range.
fields[#fields + 1] = {t = "Minimum Thottle Power", min = 0, max = 1, vals = {mspHeaderBytes + 24}}
fields[#fields + 1] = {t = "Maximum Thottle Power", min = 0, max = 1, vals = {mspHeaderBytes + 24}}
fields[#fields + 1] = {t = "Maximum Spinup Power", min = 0, max = 1, vals = {mspHeaderBytes + 24}}
fields[#fields + 1] = {t = "Maximum Power @ kERPM", min = 0, max = 1, vals = {mspHeaderBytes + 24}}
fields[#fields + 1] = {t = "Acceleration Slew Rate", min = 0, max = 1, vals = {mspHeaderBytes + 24}}
fields[#fields + 1] = {t = "Drag Brake Amount", min = 0, max = 1, vals = {mspHeaderBytes + 24}}
fields[#fields + 1] = {t = "Throttle Mode", min = 0, max = 1, vals = {mspHeaderBytes + 24}, table=throttleMode}
fields[#fields + 1] = {t = "Preset Throttle", min = 0, max = 1, vals = {mspHeaderBytes + 24}}
fields[#fields + 1] = {t = "Bec Voltage", min = 0, max = 1, vals = {mspHeaderBytes + 24}}
fields[#fields + 1] = {t = "LED", min = 0, max = 1, vals = {mspHeaderBytes + 24}, table=ledMode}

function postLoad()
    rfsuite.app.triggers.isReady = true
end

local function onNavMenu(self)
    rfsuite.app.triggers.escToolEnableButtons = true
    rfsuite.app.ui.openPage(pidx, folder , "esc/esc_tool.lua")
end

local function event(widget, category, value, x, y)

    -- print("Event received:" .. ", " .. category .. "," .. value .. "," .. x .. "," .. y)

    if category == 5 or value == 35 then
        rfsuite.app.ui.openPage(pidx, folder , "esc/esc_tool.lua")
        return true
    end

    return false
end

local foundEsc = false
local foundEscDone = false
return {
    read = 217, -- msp_ESC_PARAMETERS
    write = 218, -- msp_SET_ESC_PARAMETERS
    eepromWrite = false,
    reboot = false,
    title = "Basic Setup",
    minBytes = mspBytes,
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    simulatorResponse = {115, 0, 0, 0, 150, 231, 79, 190, 216, 78, 29, 169, 244, 1, 0, 0, 1, 0, 2, 0, 4, 76, 7, 148, 0, 6, 30, 125, 0, 15, 0, 3, 15, 1, 20, 0, 10, 0, 0, 0, 0, 0, 0, 2, 73, 240},
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / ESCape32 / Basic",
    headerLine = rfsuite.escHeaderLineText
}

