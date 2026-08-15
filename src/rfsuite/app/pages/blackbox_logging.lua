-- Controls -> Blackbox -> Logging page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local blackboxPage = requireModule("app/pages/blackbox_edit_page.lua")

return blackboxPage.new({
  kind = "logging",
  title = "@i18n(app.modules.blackbox.name)@ / @i18n(app.modules.blackbox.menu_logging)@",
  fields = {
    {label = "@i18n(app.modules.blackbox.log_command)@", bit = 0},
    {label = "@i18n(app.modules.blackbox.log_setpoint)@", bit = 1},
    {label = "@i18n(app.modules.blackbox.log_mixer)@", bit = 2},
    {label = "@i18n(app.modules.blackbox.log_pid)@", bit = 3},
    {label = "@i18n(app.modules.blackbox.log_attitude)@", bit = 4},
    {label = "@i18n(app.modules.blackbox.log_gyro_raw)@", bit = 5},
    {label = "@i18n(app.modules.blackbox.log_gyro)@", bit = 6},
    {label = "@i18n(app.modules.blackbox.log_acc)@", bit = 7},
    {label = "@i18n(app.modules.blackbox.log_mag)@", bit = 8},
    {label = "@i18n(app.modules.blackbox.log_alt)@", bit = 9},
    {label = "@i18n(app.modules.blackbox.log_battery)@", bit = 10},
    {label = "@i18n(app.modules.blackbox.log_rssi)@", bit = 11},
    {label = "@i18n(app.modules.blackbox.log_gps)@", bit = 12, featureBit = blackboxPage.FEATURE_BIT_GPS},
    {label = "@i18n(app.modules.blackbox.log_rpm)@", bit = 13},
    {label = "@i18n(app.modules.blackbox.log_motors)@", bit = 14},
    {label = "@i18n(app.modules.blackbox.log_servos)@", bit = 15},
    {label = "@i18n(app.modules.blackbox.log_vbec)@", bit = 16},
    {label = "@i18n(app.modules.blackbox.log_vbus)@", bit = 17},
    {label = "@i18n(app.modules.blackbox.log_temps)@", bit = 18},
    {label = "@i18n(app.modules.blackbox.log_esc)@", bit = 19, featureBit = blackboxPage.FEATURE_BIT_ESC_SENSOR},
    {label = "@i18n(app.modules.blackbox.log_bec)@", bit = 20, featureBit = blackboxPage.FEATURE_BIT_ESC_SENSOR},
    {label = "@i18n(app.modules.blackbox.log_esc2)@", bit = 21, featureBit = blackboxPage.FEATURE_BIT_ESC_SENSOR},
    {label = "@i18n(app.modules.blackbox.log_governor)@", bit = 22, featureBit = blackboxPage.FEATURE_BIT_GOVERNOR},
  },
})
