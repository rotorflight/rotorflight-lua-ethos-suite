-- Setup -> ESC & Motors -> Forward Programming -> Hobbywing V5.

local requireModule = assert(loadfile("lib/require.lua"))()
local vendorPage = requireModule("app/pages/esc_forward_vendor.lua")
local msp = requireModule("lib/msp_esc_parameters_hw5.lua")

local PAGE_TITLE = "@i18n(app.modules.esc_tools.mfg.hw5.name)@"

local function enabled(data, key)
  return msp.isFieldAvailable(data, key)
end

local FIELDS = {
  {group = "@i18n(app.modules.esc_tools.mfg.hw5.esc)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.hw5.flight_mode)@", key = "flight_mode", enabledWhen = function(data) return enabled(data, "flight_mode") end},
  {label = "@i18n(app.modules.esc_tools.mfg.hw5.rotation)@", key = "rotation", enabledWhen = function(data) return enabled(data, "rotation") end},
  {label = "@i18n(app.modules.esc_tools.mfg.hw5.bec_voltage)@", key = "bec_voltage", enabledWhen = function(data) return enabled(data, "bec_voltage") end},

  {group = "@i18n(app.modules.esc_tools.mfg.hw5.limits)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.hw5.lipo_cell_count)@", key = "lipo_cell_count", enabledWhen = function(data) return enabled(data, "lipo_cell_count") end},
  {label = "@i18n(app.modules.esc_tools.mfg.hw5.volt_cutoff_type)@", key = "volt_cutoff_type", enabledWhen = function(data) return enabled(data, "volt_cutoff_type") end},
  {label = "@i18n(app.modules.esc_tools.mfg.hw5.cutoff_voltage)@", key = "cutoff_voltage", enabledWhen = function(data) return enabled(data, "cutoff_voltage") end},

  {group = "@i18n(app.modules.esc_tools.mfg.hw5.governor)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.hw5.gov_p_gain)@", key = "gov_p_gain", enabledWhen = function(data) return enabled(data, "gov_p_gain") end},
  {label = "@i18n(app.modules.esc_tools.mfg.hw5.gov_i_gain)@", key = "gov_i_gain", enabledWhen = function(data) return enabled(data, "gov_i_gain") end},

  {group = "@i18n(app.modules.esc_tools.mfg.hw5.soft_start)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.hw5.startup_time)@", key = "startup_time", enabledWhen = function(data) return enabled(data, "startup_time") end},
  {label = "@i18n(app.modules.esc_tools.mfg.hw5.restart_time)@", key = "restart_time", enabledWhen = function(data) return enabled(data, "restart_time") end},
  {label = "@i18n(app.modules.esc_tools.mfg.hw5.auto_restart)@", key = "auto_restart", enabledWhen = function(data) return enabled(data, "auto_restart") end},

  {group = "@i18n(app.modules.esc_tools.mfg.hw5.motor)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.hw5.timing)@", key = "timing", enabledWhen = function(data) return enabled(data, "timing") end},
  {label = "@i18n(app.modules.esc_tools.mfg.hw5.startup_power)@", key = "startup_power", enabledWhen = function(data) return enabled(data, "startup_power") end},
  {label = "@i18n(app.modules.esc_tools.mfg.hw5.active_freewheel)@", key = "active_freewheel", enabledWhen = function(data) return enabled(data, "active_freewheel") end},
  {label = "@i18n(app.modules.esc_tools.mfg.hw5.response_time)@", key = "response_time", enabledWhen = function(data) return enabled(data, "response_time") end},

  {group = "@i18n(app.modules.esc_tools.mfg.hw5.brake)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.hw5.brake_type)@", key = "brake_type", enabledWhen = function(data) return enabled(data, "brake_type") end},
  {label = "@i18n(app.modules.esc_tools.mfg.hw5.brake_force)@", key = "brake_force", enabledWhen = function(data) return enabled(data, "brake_force") end},
}

local function open(opts)
  vendorPage.open(opts, {
    pageTitle = PAGE_TITLE,
    logTag = "esc_hw5",
    mspModule = msp,
    fields = FIELDS,
    unloadPackageKeys = {"rfsuite.lib.msp_esc_parameters_hw5"},
  })
end

return {open = open}
