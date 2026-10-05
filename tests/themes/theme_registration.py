"""Theme-scoped registration and persistence checks against real Suite modules.

Run the sibling test_<folder>_registration.py wrapper through unittest.
Requires Lupa 2.8 (Lua 5.4). RFSUITE_TEST_ROOT optionally selects another checkout.
Each wrapper supplies its own <folder>_registration.json to the factory.
The helper is identical across theme PRs and has no cross-theme dependency. English tags are resolved from the
checkout's generated locale, as in a built package.

Production loader, metadata, settings normalization, pages and configure code
execute here. Radio form/LCD, persistent storage and the paint engine are test
doubles. The three phase files are checked for selection, not executed by this
UI fixture; desktop previews separately execute the actual engine and layouts.
"""
import importlib.util
from functools import lru_cache
import json
import os
from pathlib import Path
import struct
import sys
import unittest

HERE_ROOT = Path(__file__).resolve().parents[2]
ROOT = Path(os.environ.get("RFSUITE_TEST_ROOT", HERE_ROOT)).resolve()
SOURCE = ROOT / "src/rfsuite"
sys.path.insert(0, str(HERE_ROOT / "build/test-deps"))
from lupa.lua54 import LuaRuntime


@lru_cache(maxsize=1)
def package_english_catalog():
    path = ROOT / ".vscode/scripts/resolve_i18n_tags.py"
    spec = importlib.util.spec_from_file_location("theme_package_resolver", path)
    resolver = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(resolver)
    return resolver, resolver.load_translations(SOURCE / "i18n/en.json")


def translate_tags(source):
    resolver, catalog = package_english_catalog()
    return resolver.replace_tags_in_text(source, catalog, {})[0]


class RadioUI:
    def __init__(self, width=800, height=480):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.g = self.lua.globals()
        self.g.readSource = self.read
        self.g.width, self.g.height = width, height
        self.lua.execute(r'''
            now, phaseStubs = 0, false
            loads, settingsFile, modelFiles, choices, booleans, numbers, buttons = {}, {}, {}, {}, {}, {}, {}
            activeSubscriptions = 0
            os.clock = function() return now end
            os.mkdir = function() end
            function loadfile(path)
                loads[path] = (loads[path] or 0) + 1
                local source = readSource(path)
                if not source then return nil, "missing fixture source: " .. path end
                local phase = path:match("/([a-z]+)%.lua$")
                if phaseStubs and path:match("^widgets/dashboard/themes/")
                    and (phase == "preflight" or phase == "inflight" or phase == "postflight") then
                    return function() return {fixturePhase=phase} end
                end
                return load(source, "@" .. path, "t", _G)
            end
            local function noop() end
            CATEGORY_CHANNEL, TEXT_LEFT, CENTERED, FONT_S, FONT_XS = 1, 0, 0, 20, 16
            lcd = {
                RGB = function(r,g,b) return r*65536 + g*256 + b end,
                color=noop, font=noop, drawText=noop, drawRectangle=noop, drawFilledRectangle=noop,
                getWindowSize=function() return width,height end,
                getTextSize=function(text) return #text*6,12 end,
                darkMode=function() return true end, invalidate=noop,
                loadMask=function() return nil end, isVisible=function() return true end,
            }
            system = {
                getSource=function() return {value=function() return 0 end} end,
                getMemoryUsage=function() return {mainStackAvailable=9000} end,
                registerWidget=function(value) registeredWidget=value end,
            }
            model = {name=function() return "Fixture craft" end}
            local function field(line, getter, setter)
                return {line=line, getter=getter, setter=setter,
                    enable=function(self,value) self.enabled=value end,
                    focus=noop, step=noop, decimals=noop,
                    suffix=function(self,value) self.unit=value end}
            end
            form = {
                clear=function() choices,booleans,numbers,buttons={},{},{},{} end,
                height=function() return 40 end,
                addExpansionPanel=function(label)
                    return {open=noop, addLine=function(self,text) return {panel=label,label=text} end}
                end,
                addChoiceField=function(line,rect,values,getter,setter)
                    local f=field(line,getter,setter); f.choices=values
                    choices[#choices+1]=f; return f
                end,
                addBooleanField=function(line,rect,getter,setter)
                    local f=field(line,getter,setter); booleans[#booleans+1]=f; return f
                end,
                addNumberField=function(line,rect,low,high,getter,setter)
                    local f=field(line,getter,setter); numbers[#numbers+1]=f; return f
                end,
                addButton=function(line,rect,options)
                    options.focus=noop; buttons[#buttons+1]=options; return options
                end,
                addStaticText=noop,
                openDialog=function(options) options.buttons[1].action(); return {} end,
            }
            local activePreferences
            context={session={},preferences={general={temperature_unit=0}},widgets={dashboard={
                setPreferences=function(value) activePreferences=value end,
                preferences=function() return activePreferences end,
                getPreference=function(key) return activePreferences and activePreferences[key] end,
                savePreference=function(key,value) activePreferences[key]=value end,
                clearCaches=noop,
            }}}
            local stubs = {
                ["lib/ini.lua"]={
                    load_ini_file=function() return settingsFile end,
                    save_ini_file=function(path,value) settingsFile=value; return true end,
                },
                ["lib/model_preferences.lua"]={
                    load=function(id) modelFiles[id]=modelFiles[id] or {}; return modelFiles[id],id end,
                    save=function(id,value) modelFiles[id]=value; return true end,
                },
                ["app/close_key.lua"]={shouldHandleClose=function() return false end},
                ["app/header.lua"]={build=function(title,callbacks)
                    headerTitle,headerCallbacks=title,callbacks
                    return {setSaveEnabled=noop,setReloadEnabled=noop,focusSave=noop,focusReload=noop,focusMenu=noop}
                end},
                ["app/tile_grid.lua"]={metrics=function() return 4,180,70,10,FONT_S end,
                    fitLabel=function(text) return text end},
                ["widgets/dashboard/context.lua"]=context,
                ["widgets/dashboard/engine.lua"]={
                    paint=function(widget,definition,state,phase)
                        paintedKey=definition.key or definition.dir:match("/([^/]+)$")
                        paintedPhase,paintedState=phase,state.fixturePhase
                        return true
                    end,
                    wakeup=function() return true end, reset=noop,
                },
                ["lib/stack_probe.lua"]={notePaint=noop},
                ["lib/msp_dataflash_erase.lua"]={}, ["lib/msp_dataflash_summary.lua"]={},
                ["lib/msp_battery_profile.lua"]={}, ["lib/battery_profile_index.lua"]={},
            }
            local cache={}
            function requireModule(path)
                if stubs[path] then return stubs[path] end
                if cache[path] then return cache[path] end
                cache[path]=assert(loadfile(path))()
                return cache[path]
            end
            package.loaded["rfsuite.lib.require"]=requireModule
            bus=requireModule("lib/bus.lua")
            local subscribe,unsubscribe=bus.subscribe,bus.unsubscribe
            bus.subscribe=function(topic,handler)
                activeSubscriptions=activeSubscriptions+1; return subscribe(topic,handler)
            end
            bus.unsubscribe=function(topic,handler)
                activeSubscriptions=activeSubscriptions-1; return unsubscribe(topic,handler)
            end
            store=requireModule("lib/settings_store.lua")
            function openPage(path)
                requireModule(path).open({
                    setWakeupHandler=function(fn) pageWakeup=fn end,
                    setCleanupHandler=function(fn) pageCleanup=fn end,
                    setPaintHandler=noop,setEventHandler=noop,
                })
            end
            function choiceId(field,label)
                for _,choice in ipairs(field.choices) do if choice[1]==label then return choice[2] end end
                error("missing choice: " .. label)
            end
            function findButton(label)
                for _,button in ipairs(buttons) do if button.text==label then return button end end
                error("missing tile: " .. label)
            end
        ''')

    @staticmethod
    def read(path):
        target = SOURCE / path
        return translate_tags(target.read_text(encoding="utf-8")) if target.is_file() else None

    def run(self, source):
        return self.lua.execute(source)


def make_theme_test_case(manifest_path, module_name):
    """Bind each wrapper to its own immutable declaration, without global swaps."""
    MANIFEST = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
    THEMES = (MANIFEST["folder"],)

    class ThemeRegistrationTests(unittest.TestCase):
        def test_metadata_matches_declared_identity_and_local_phase_files(self):
            ui=RadioUI()
            theme=MANIFEST["folder"]
            definition=ui.run('return requireModule("widgets/dashboard/themes/'+theme+'/init.lua")')
            self.assertEqual(definition.name, MANIFEST.get("metadataName", MANIFEST["name"]))
            self.assertEqual((definition.minResolution.x, definition.minResolution.y), (784,294))
            for phase in ("preflight", "inflight", "postflight", "configure"):
                filename=definition[phase]
                self.assertEqual(filename, phase+".lua")
                self.assertTrue((SOURCE / "widgets/dashboard/themes" / theme / filename).is_file())

        def test_gallery_contains_three_native_size_desktop_previews(self):
            gallery=HERE_ROOT / "docs/dashboard-themes" / MANIFEST["name"]
            for phase in ("preflight", "inflight", "postflight"):
                data=(gallery / (phase+".png")).read_bytes()
                self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
                self.assertEqual(struct.unpack(">II", data[16:24]), (800,480))
            self.assertIn("Desktop preview, not radio capture", (gallery / "README.md").read_text(encoding="utf-8"))

        def test_settings_normalization_retains_ids_aliases_and_distinct_phases(self):
            ui=RadioUI()
            for theme in THEMES:
                with self.subTest(theme=theme):
                    ui.g.theme=theme
                    ui.run('''
                        for _,value in ipairs({theme,"system/"..theme,"system/@"..theme}) do
                            local settings=store.withDefaults({dashboard={use_same_theme=false,
                                theme_preflight=value,theme_inflight="system/default",theme_postflight=value}})
                            assert(settings.dashboard.theme==theme)
                            assert(settings.dashboard.theme_preflight=="system/"..theme)
                            assert(settings.dashboard.theme_inflight=="system/default")
                            assert(settings.dashboard.theme_postflight=="system/"..theme)
                        end
                        local settings=store.withDefaults({dashboard={theme_preflight=theme,use_same_theme=true}})
                        assert(settings.dashboard.theme_inflight=="system/"..theme)
                        assert(settings.dashboard.theme_postflight=="system/"..theme)
                        assert(store.withDefaults({dashboard={theme="does-not-exist"}}).dashboard.theme=="default")
                    ''')

        def test_picker_and_tiles_apply_names_and_minimum_resolution(self):
            for size,visible in (((800,480),True),((784,294),True),((783,294),False),((784,293),False)):
                with self.subTest(size=size):
                    ui=RadioUI(*size)
                    ui.run('openPage("app/pages/settings_dashboard_theme.lua")')
                    self.assertEqual(len(ui.g.choices),6)
                    for field in ui.g.choices.values():
                        labels=[choice[1] for choice in field.choices.values()]
                        for theme in THEMES:
                            self.assertEqual(labels.count(MANIFEST['name']),int(visible))
                    ui.run('pageCleanup(); openPage("app/pages/settings_dashboard_settings.lua")')
                    labels=[button.text for button in ui.g.buttons.values()]
                    for theme in THEMES:
                        self.assertEqual(labels.count(MANIFEST['name']),int(visible))

        def test_picker_saves_global_and_model_phase_choices_and_same_theme(self):
            for theme in THEMES:
                with self.subTest(theme=theme):
                    ui=RadioUI(); ui.g.theme,ui.g.label=theme,MANIFEST['name']; ui.g.becPanel=MANIFEST.get('becPanel'); ui.g.becLabel=MANIFEST['becLabel']
                    ui.run('''
                        bus.publish("session.update",{connected=true,mcuId="craft"})
                        openPage("app/pages/settings_dashboard_theme.lua")
                        local id=choiceId(choices[1],label)
                        booleans[1].setter(false); booleans[2].setter(false)
                        choices[1].setter(id); choices[3].setter(id)
                        choices[5].setter(id)
                        assert(choices[5].getter()==id and choices[5].enabled)
                        headerCallbacks.onSave()
                        assert(settingsFile.dashboard.theme_preflight=="system/"..theme)
                        assert(settingsFile.dashboard.theme_inflight=="system/default")
                        assert(settingsFile.dashboard.theme_postflight=="system/"..theme)
                        assert(modelFiles.craft.dashboard.theme_preflight=="nil")
                        assert(modelFiles.craft.dashboard.theme_inflight=="system/"..theme)
                        assert(modelFiles.craft.dashboard.theme_postflight=="nil")
                        pageCleanup(); assert(activeSubscriptions==0)
                        openPage("app/pages/settings_dashboard_theme.lua")
                        id=choiceId(choices[1],label)
                        assert(choices[1].getter()==id and choices[3].getter()==id)
                        assert(choices[5].getter()==id,"saved model phase was not restored")
                        choices[4].setter(id); booleans[2].setter(true); booleans[1].setter(true)
                        headerCallbacks.onSave()
                        for _,phase in ipairs({"preflight","inflight","postflight"}) do
                            assert(settingsFile.dashboard["theme_"..phase]=="system/"..theme)
                            assert(modelFiles.craft.dashboard["theme_"..phase]=="system/"..theme)
                        end
                        choices[4].setter(0); headerCallbacks.onSave()
                        assert(modelFiles.craft.dashboard==nil,"disabled model override was retained")
                        pageCleanup(); assert(activeSubscriptions==0)
                    ''')

        def test_configuration_tiles_save_only_the_active_theme_section(self):
            for theme in THEMES:
                with self.subTest(theme=theme):
                    ui=RadioUI(); ui.g.theme,ui.g.label=theme,MANIFEST['name']; ui.g.becPanel=MANIFEST.get('becPanel'); ui.g.becLabel=MANIFEST['becLabel']
                    ui.run('''
                        settingsFile["dashboard."..theme]={bec_warn=7,marker="keep"}
                        settingsFile["dashboard.unrelated"]={bec_warn=9,marker="untouched"}
                        openPage("app/pages/settings_dashboard_settings.lua")
                        findButton(label).press()
                        local field
                        for _,value in ipairs(numbers) do
                            if value.line.label==becLabel and (not becPanel or value.line.panel==becPanel) then field=value end
                        end
                        assert(field and field.getter()==70)
                        field.setter(80)
                        assert(settingsFile["dashboard."..theme].bec_warn==7,"saved before Save")
                        headerCallbacks.onSave()
                        assert(settingsFile["dashboard."..theme].bec_warn==8)
                        assert(settingsFile["dashboard."..theme].marker=="keep")
                        assert(settingsFile["dashboard.unrelated"].bec_warn==9)
                        assert(settingsFile["dashboard.unrelated"].marker=="untouched")
                        headerCallbacks.onBack()
                        assert(context.widgets.dashboard.preferences()==nil,"theme preferences leaked into grid")
                        findButton(label).press()
                        for _,value in ipairs(numbers) do
                            if value.line.label==becLabel and (not becPanel or value.line.panel==becPanel) then assert(value.getter()==80) end
                        end
                        pageCleanup()
                        assert(context.widgets.dashboard.preferences()==nil,"cleanup retained active preferences")
                    ''')

        def test_dashboard_loader_selects_global_model_and_phase_paths(self):
            for theme in THEMES:
                with self.subTest(theme=theme):
                    ui=RadioUI(); ui.g.theme=theme
                    ui.run('''
                        phaseStubs=true
                        requireModule("widgets/dashboard.lua").init()
                        local widget=registeredWidget.create()
                        widget.settingsSnapshot=store.withDefaults({dashboard={use_same_theme=false,
                            theme_preflight="system/"..theme,theme_inflight="system/default",theme_postflight="system/"..theme}})
                        widget.settingsSnapshot["dashboard."..theme]={marker=theme}
                        widget.dashboardSettings=store.dashboard(widget.settingsSnapshot)
                        for _,phase in ipairs({"preflight","inflight","postflight"}) do
                            widget.flightmodeState=phase; registeredWidget.paint(widget)
                            local expected=phase=="inflight" and "default" or theme
                            assert(paintedKey==expected and paintedPhase==phase and paintedState==phase)
                            assert(loads["widgets/dashboard/themes/"..expected.."/"..phase..".lua"])
                        end
                        widget.modelDashboard={use_same_theme=true,theme_preflight="system/"..theme}
                        for _,phase in ipairs({"preflight","inflight","postflight"}) do
                            widget.flightmodeState=phase; registeredWidget.paint(widget)
                            assert(paintedKey==theme and paintedPhase==phase)
                            assert(context.widgets.dashboard.getPreference("marker")==theme)
                        end
                        widget.modelDashboard={use_same_theme=false,theme_inflight="nil"}
                        widget.flightmodeState="inflight"; registeredWidget.paint(widget)
                        assert(paintedKey=="default","disabled model phase did not use global choice")
                        registeredWidget.close(widget)
                    ''')

        def test_model_controls_require_connection_and_known_controller(self):
            ui=RadioUI()
            ui.run('''
                openPage("app/pages/settings_dashboard_theme.lua")
                for i=4,6 do assert(choices[i].enabled==false) end
                bus.publish("session.update",{connected=true})
                pageWakeup()
                for i=4,6 do assert(choices[i].enabled==false) end
                bus.publish("session.update",{connected=true,mcuId="craft"})
                pageWakeup()
                assert(choices[4].enabled==true)
                pageCleanup(); assert(activeSubscriptions==0)
            ''')

    ThemeRegistrationTests.__module__ = module_name
    ThemeRegistrationTests.__qualname__ = ThemeRegistrationTests.__name__
    return ThemeRegistrationTests
