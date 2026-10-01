"""Bastion directory migration with legacy selections and settings preserved.

Run: python -m unittest discover -s tests/themes -p test_bastion_folder.py
Requires Lupa (Lua 5.4). RFSUITE_TEST_ROOT can select a standalone checkout.
Uses real loader/settings/configure/Bridge modules, in-memory settings and UI,
and a stub paint engine; theme visual acceptance is a separate check.
"""
import os
from pathlib import Path
import sys
import unittest

HERE = Path(__file__).resolve().parents[2]
ROOT = Path(os.environ.get("RFSUITE_TEST_ROOT", HERE)).resolve()
SOURCE = ROOT / "src/rfsuite"
sys.path.insert(0, str(HERE / "build/test-deps"))
from lupa.lua54 import LuaRuntime


class Radio:
    def __init__(self):
        self.loads = []
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().readSource = self.read
        self.lua.execute(r'''
            now, stubPhases = 0, false
            os.clock=function() return now end
            os.mkdir=function() end
            function loadfile(path)
                local text=readSource(path)
                if not text then return nil,"missing source: "..path end
                local phase=path:match("/([a-z]+)%.lua$")
                if stubPhases and path:match("^widgets/dashboard/themes/") and
                    (phase=="preflight" or phase=="inflight" or phase=="postflight") then
                    return function() return {phase=phase} end
                end
                return load(text,"@"..path,"t",_G)
            end
            local function noop() end
            FONT_S,FONT_XS,CATEGORY_CHANNEL=20,16,1
            lcd={RGB=function(r,g,b) return r*65536+g*256+b end,
                color=noop,font=noop,drawText=noop,drawFilledRectangle=noop,drawRectangle=noop,
                getWindowSize=function() return 800,480 end,getTextSize=function(t) return #t*6,12 end,
                loadMask=function() return nil end,darkMode=function() return true end,invalidate=noop}
            system={getSource=function() return {value=function() return 0 end} end,
                registerWidget=function(w) widgetModule=w end,
                getMemoryUsage=function() return {mainStackAvailable=9000} end}
            settingsFile={dashboard={use_same_theme=true,theme_preflight="system/aegis"},
                ["dashboard.aegis"]={rpm_max=3450,bec_warn=7.8,marker="preserved"},
                ["dashboard.unrelated"]={marker="untouched"}}
            local prefs
            context={session={},preferences={general={temperature_unit=0}},widgets={dashboard={
                setPreferences=function(value) prefs=value end,preferences=function() return prefs end,
                getPreference=function(key) return prefs and prefs[key] end,
                savePreference=function(key,value) prefs[key]=value end,clearCaches=noop}}}
            form={clear=function() buttons,fields={},{} end,height=function() return 40 end,
                addExpansionPanel=function(label)
                    return {open=noop,addLine=function(self,text) return {label=text} end}
                end,
                addNumberField=function(line,rect,low,high,getter,setter)
                    local f={label=line.label,getter=getter,setter=setter,step=noop,decimals=noop,suffix=noop}
                    fields[#fields+1]=f; return f
                end,
                addButton=function(line,rect,options)
                    options.focus=noop; buttons[#buttons+1]=options; return options
                end,addStaticText=noop}
            local stubs={
                ["lib/ini.lua"]={load_ini_file=function() return settingsFile end,
                    save_ini_file=function(path,value) settingsFile=value; return true end},
                ["lib/model_preferences.lua"]={load=function() return {},"craft" end},
                ["app/close_key.lua"]={shouldHandleClose=function() return false end},
                ["app/header.lua"]={build=function(title,callbacks)
                    header=callbacks; return {setSaveEnabled=noop,setReloadEnabled=noop,
                        focusSave=noop,focusReload=noop,focusMenu=noop}
                end},
                ["app/tile_grid.lua"]={metrics=function() return 4,180,70,10,FONT_S end,
                    fitLabel=function(text) return text end},
                ["widgets/dashboard/context.lua"]=context,
                ["widgets/dashboard/engine.lua"]={paint=function(widget,definition,state,phase)
                    paintedDirectory,paintedPhase,paintedState=definition.dir,phase,state.phase
                    return true
                end,reset=noop},
                ["lib/stack_probe.lua"]={notePaint=noop},
                ["lib/msp_dataflash_erase.lua"]={},["lib/msp_dataflash_summary.lua"]={},
                ["lib/msp_battery_profile.lua"]={},["lib/battery_profile_index.lua"]={}}
            local cache={}
            function requireModule(path)
                if stubs[path] then return stubs[path] end
                if not cache[path] then cache[path]=assert(loadfile(path))() end
                return cache[path]
            end
            package.loaded["rfsuite.lib.require"]=requireModule
            bus=requireModule("lib/bus.lua")
            store=requireModule("lib/settings_store.lua")
            function bastionButton()
                for _,button in ipairs(buttons) do if button.text=="Bastion" then return button end end
                error("Bastion settings tile is missing")
            end
            function numberField(label)
                for _,field in ipairs(fields) do if field.label==label then return field end end
                error("Missing field: "..label)
            end
        ''')

    def read(self, path):
        self.loads.append(path)
        target = SOURCE / path
        return target.read_text(encoding="utf-8") if target.is_file() else None

    def run(self, code):
        return self.lua.execute(code)


class BastionFolderTests(unittest.TestCase):
    def assert_no_old_folder_reads(self, radio):
        self.assertFalse([p for p in radio.loads if p.startswith("widgets/dashboard/themes/aegis/")])

    def test_payload_contains_bastion_directory_only(self):
        themes = SOURCE / "widgets/dashboard/themes"
        self.assertFalse((themes / "aegis").exists(), "legacy physical folder must not remain in payload")
        for name in ("init.lua", "configure.lua", "preflight.lua", "inflight.lua", "postflight.lua"):
            self.assertTrue((themes / "bastion" / name).is_file(), name)

    def test_legacy_global_and_model_selections_load_all_phases_with_old_preferences(self):
        radio = Radio()
        radio.run('''
            stubPhases=true
            requireModule("widgets/dashboard.lua").init()
            local widget=widgetModule.create()
            widget.settingsSnapshot=store.load()
            widget.dashboardSettings=store.dashboard(widget.settingsSnapshot)
            assert(widget.dashboardSettings.theme=="aegis")
            for _,modelOverride in ipairs({false,true}) do
                if modelOverride then
                    widget.dashboardSettings=store.dashboard({dashboard={theme_preflight="system/default"}})
                    widget.modelDashboard={use_same_theme=false,theme_preflight="system/aegis",
                        theme_inflight="system/aegis",theme_postflight="system/aegis"}
                end
                for _,phase in ipairs({"preflight","inflight","postflight"}) do
                    widget.flightmodeState=phase; widgetModule.paint(widget)
                    assert(paintedDirectory=="widgets/dashboard/themes/bastion")
                    assert(paintedPhase==phase and paintedState==phase)
                    assert(context.widgets.dashboard.getPreference("rpm_max")==3450)
                    assert(context.widgets.dashboard.getPreference("bec_warn")==7.8)
                    assert(context.widgets.dashboard.getPreference("marker")=="preserved")
                end
            end
            widgetModule.close(widget)
        ''')
        self.assert_no_old_folder_reads(radio)

    def test_settings_tile_reads_saves_and_reopens_dashboard_aegis(self):
        radio = Radio()
        radio.run('''
            requireModule("app/pages/settings_dashboard_settings.lua").open({
                setCleanupHandler=function(fn) cleanup=fn end})
            bastionButton().press()
            assert(numberField("Maximum headspeed").getter()==3450)
            assert(numberField("BEC caution below").getter()==78)
            numberField("Maximum headspeed").setter(3800)
            numberField("BEC caution below").setter(80)
            assert(settingsFile["dashboard.aegis"].rpm_max==3450,"saved before Save")
            header.onSave()
            assert(settingsFile["dashboard.aegis"].rpm_max==3800)
            assert(settingsFile["dashboard.aegis"].bec_warn==8)
            assert(settingsFile["dashboard.aegis"].marker=="preserved")
            assert(settingsFile["dashboard.bastion"]==nil,"created an incompatible preference section")
            assert(settingsFile["dashboard.unrelated"].marker=="untouched")
            header.onBack(); bastionButton().press()
            assert(numberField("Maximum headspeed").getter()==3800)
            assert(numberField("BEC caution below").getter()==80)
            cleanup(); assert(context.widgets.dashboard.preferences()==nil)
        ''')
        self.assertIn("widgets/dashboard/themes/bastion/configure.lua", radio.loads)
        self.assert_no_old_folder_reads(radio)

    @unittest.skipUnless((SOURCE / "app/theme_bridge.lua").is_file(), "Standalone branch has no Theme Bridge")
    def test_bridge_resolves_new_metadata_path_preserves_id_and_releases_cache(self):
        radio = Radio()
        radio.run('''
            bridge=requireModule("app/theme_bridge.lua")
            function tick() now=now+0.6; bridge.wakeup() end
            bridge.open(store.load()); tick(); tick()
            local palette=bridge.getPalette()
            assert(palette.path=="system/aegis" and palette.name=="Bastion")
            local expected=assert(load(readSource("widgets/dashboard/themes/bastion/init.lua")))().appTheme
            assert(palette.accent==lcd.RGB(table.unpack(expected.accent)))
            for i=1,8 do bridge.paintBackground(); bridge.paintChrome(); tick() end
            assert(bridge.getPalette()==palette,"stable palette cache was replaced")
        ''')
        metadata = "widgets/dashboard/themes/bastion/init.lua"
        before = radio.loads.count(metadata)
        self.assertEqual(before, 2)  # One Bridge read plus the independent expected metadata read.
        self.assertFalse([p for p in radio.loads if "/themes/" in p and p.endswith(("/preflight.lua", "/inflight.lua", "/postflight.lua"))])
        radio.run('''
            bridge.clearCache()
            bus.publish("session.update",{connected=false}); bus.publish("settings.update",store.load())
            tick(); assert(bridge.getPalette()==nil)
            bridge.open(store.load()); tick(); tick()
            assert(bridge.getPalette().path=="system/aegis")
            bridge.clearCache()
        ''')
        self.assertEqual(radio.loads.count(metadata), before + 1)
        self.assert_no_old_folder_reads(radio)

    @unittest.skipUnless((SOURCE / "app/theme_bridge.lua").is_file(), "Standalone branch has no Theme Bridge")
    def test_bridge_accepts_legacy_install_only_when_new_metadata_file_is_missing(self):
        primary = "widgets/dashboard/themes/bastion/init.lua"
        legacy = "widgets/dashboard/themes/aegis/init.lua"
        legacy_source = 'return {appTheme={name="Legacy fixture",accent={17,81,149}}}'
        for primary_present, legacy_present, expected in (
                (True, True, "system/aegis"),
                (False, True, "system/aegis"),
                (False, False, "system/default")):
            with self.subTest(primary=primary_present, legacy=legacy_present):
                radio = Radio()
                original = radio.read

                def read_fixture(path):
                    if path == primary and not primary_present:
                        radio.loads.append(path)
                        return None
                    if path == legacy:
                        radio.loads.append(path)
                        return legacy_source if legacy_present else None
                    return original(path)

                radio.lua.globals().readSource = read_fixture
                palette = radio.run('''
                    bridge=requireModule("app/theme_bridge.lua")
                    bridge.open(store.load())
                    now=now+0.6; bridge.wakeup(); now=now+0.6; bridge.wakeup()
                    return bridge.getPalette()
                ''')
                self.assertEqual(palette.path, expected)
                if primary_present:
                    self.assertEqual(palette.name, "Bastion")
                    self.assertNotIn(legacy, radio.loads, "valid new metadata must win without legacy I/O")
                elif legacy_present:
                    self.assertEqual(palette.name, "Legacy fixture")
                    self.assertEqual(palette.accent, 17 * 65536 + 81 * 256 + 149)
                before = tuple(radio.loads)
                radio.run('''
                    for i=1,10 do
                        now=now+0.6; bridge.wakeup(); bridge.paintBackground(); bridge.paintChrome()
                    end
                    bridge.clearCache()
                ''')
                self.assertEqual(tuple(radio.loads), before, "fallback or missing metadata was repeatedly loaded")


if __name__ == "__main__":
    unittest.main()
