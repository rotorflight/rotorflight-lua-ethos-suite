-- Controls -> Beepers -> Configuration page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local beepersPage = requireModule("app/pages/beepers_page.lua")

local page = beepersPage.new({
  title = "@i18n(app.modules.beepers.name)@ / @i18n(app.modules.beepers.menu_configuration)@",
  fields = {
    {bit = 0, maskField = "beeper_off_flags", label = "@i18n(app.modules.beepers.field_gyro_calibrated)@"},
    {bit = 1, maskField = "beeper_off_flags", label = "@i18n(app.modules.beepers.field_rx_lost)@"},
    {bit = 2, maskField = "beeper_off_flags", label = "@i18n(app.modules.beepers.field_rx_lost_landing)@"},
    {bit = 3, maskField = "beeper_off_flags", label = "@i18n(app.modules.beepers.field_disarming)@"},
    {bit = 4, maskField = "beeper_off_flags", label = "@i18n(app.modules.beepers.field_arming)@"},
    {bit = 5, maskField = "beeper_off_flags", label = "@i18n(app.modules.beepers.field_arming_gps_fix)@"},
    {bit = 6, maskField = "beeper_off_flags", label = "@i18n(app.modules.beepers.field_bat_crit_low)@"},
    {bit = 7, maskField = "beeper_off_flags", label = "@i18n(app.modules.beepers.field_bat_low)@"},
    {bit = 8, maskField = "beeper_off_flags", label = "@i18n(app.modules.beepers.field_gps_status)@"},
    {bit = 9, maskField = "beeper_off_flags", label = "@i18n(app.modules.beepers.field_rx_set)@"},
    {bit = 10, maskField = "beeper_off_flags", label = "@i18n(app.modules.beepers.field_acc_calibration)@"},
    {bit = 11, maskField = "beeper_off_flags", label = "@i18n(app.modules.beepers.field_acc_calibration_fail)@"},
    {bit = 12, maskField = "beeper_off_flags", label = "@i18n(app.modules.beepers.field_ready_beep)@"},
    {bit = 14, maskField = "beeper_off_flags", label = "@i18n(app.modules.beepers.field_disarm_repeat)@"},
    {bit = 15, maskField = "beeper_off_flags", label = "@i18n(app.modules.beepers.field_armed)@"},
    {bit = 16, maskField = "beeper_off_flags", label = "@i18n(app.modules.beepers.field_system_init)@"},
    {bit = 17, maskField = "beeper_off_flags", label = "@i18n(app.modules.beepers.field_usb)@"},
    {bit = 18, maskField = "beeper_off_flags", label = "@i18n(app.modules.beepers.field_blackbox_erase)@"},
    {bit = 21, maskField = "beeper_off_flags", label = "@i18n(app.modules.beepers.field_arming_gps_no_fix)@"},
  },
})

return page
