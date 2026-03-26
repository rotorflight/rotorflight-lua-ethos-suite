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
    hooksScript = "app/modules/mixer/menu_hooks.lua",
    iconPrefix = "app/modules/mixer/gfx/",
    loaderSpeed = "DEFAULT",
    navButtons = {
        help = false,
        menu = true,
        reload = false,
        save = false,
        tool = false,
    },
    navOptions = {
        defaultSection = "setup",
        showProgress = true,
    },
    pages = {
        {
            apiversion = { 12, 0, 9 },
            image = "swash.png",
            name = "@i18n(app.modules.mixer.swash)@",
            script = "swash.lua",
            shortcutId = "s_mixer_swash_lua_219836e7bb",
        },
        {
            apiversionlt = { 12, 0, 9 },
            image = "swash.png",
            name = "@i18n(app.modules.mixer.swash)@",
            script = "swash_legacy.lua",
            shortcutId = "s_mixer_swash_legacy_lua_c1fdc218f2",
        },
        {
            apiversion = { 12, 0, 9 },
            image = "geometry.png",
            name = "@i18n(app.modules.mixer.geometry)@",
            script = "swashgeometry.lua",
            shortcutId = "s_mixer_swashgeometry_lua_2b19036cb9",
        },
        {
            apiversion = { 12, 0, 9 },
            image = "tail.png",
            name = "@i18n(app.modules.mixer.tail)@",
            script = "tail.lua",
            shortcutId = "s_mixer_tail_lua_4dae4bbc4e",
        },
        {
            apiversionlt = { 12, 0, 9 },
            image = "tail.png",
            name = "@i18n(app.modules.mixer.tail)@",
            script = "tail_legacy.lua",
            shortcutId = "s_mixer_tail_legacy_lua_af252b8ccf",
        },
        {
            image = "trims.png",
            name = "@i18n(app.modules.mixer.trims)@",
            script = "trims.lua",
            shortcutId = "s_mixer_trims_lua_89bbcb71cc",
        },
    },
    scriptPrefix = "mixer/tools/",
    title = "@i18n(app.modules.mixer.name)@",
}
