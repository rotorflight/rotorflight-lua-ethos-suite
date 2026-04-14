--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html

  AUTO-GENERATED FILE - DO NOT EDIT DIRECTLY.
  Edit menu data with: bin/menu/editor/menu_editor.cmd (Windows)
  or: python bin/menu/editor/src/menu_editor.py
  Source of truth: bin/menu/manifest.source.json
  Regenerate with: python bin/menu/generate.py
]] --

return {
    iconPrefix = "app/modules/settings/gfx/",
    moduleKey = "settings_dashboard_audio",
    navButtons = {
        help = false,
        menu = true,
        reload = false,
        save = false,
        tool = false,
    },
    navOptions = {
        defaultSection = "system",
        showProgress = true,
    },
    pages = {
        {
            image = "audio_events.png",
            name = "@i18n(app.modules.settings.txt_audio_events)@",
            offline = true,
            script = "audio_events.lua",
            shortcutId = "s_settings_dashboard_audio_audio_event_363fb08408",
        },
        {
            image = "audio_switches.png",
            name = "@i18n(app.modules.settings.txt_audio_switches)@",
            offline = true,
            script = "audio_switches.lua",
            shortcutId = "s_settings_dashboard_audio_audio_switc_79dcc8350e",
        },
        {
            image = "audio_timer.png",
            name = "@i18n(app.modules.settings.txt_audio_timer)@",
            offline = true,
            script = "audio_timer.lua",
            shortcutId = "s_settings_dashboard_audio_audio_timer_881a61d3fd",
        },
    },
    scriptPrefix = "settings/tools/",
    title = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.audio)@",
}
