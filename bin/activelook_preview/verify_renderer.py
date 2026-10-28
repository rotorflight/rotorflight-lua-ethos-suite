"""Run: python -m unittest discover -s bin/activelook_preview -p 'verify_*.py'."""
import copy
import io
import json
import runpy
import threading
import tempfile
from pathlib import Path
import unittest
from http.client import HTTPConnection
from unittest.mock import patch

from renderer import WidgetRenderer, RenderSessions
from server import PreviewHandler, PreviewServer, main


def request(preview=None, **settings):
    return {"preview": preview, "settings": {"activelook": {"enabled": True, **settings},
            "general": {}, "events": {}}, "sensors": {"armed": True, "fuel": 70, "governorState": 4,
            "throttlePercent": 70, "tempEsc": 95, "voltage": 24.8, "rpm": 1840,
            "consumption": 428, "cellCount": 6, "modelType": 1}}


def texts(frame):
    return [c["text"]["text"] for c in frame["commands"] if "text" in c]


def icons(frame):
    return [c["bitmap"]["id"] for c in frame["commands"] if "bitmap" in c]


class WidgetTests(unittest.TestCase):
    def setUp(self):
        self.renderer = WidgetRenderer()

    def test_suite_defaults(self):
        defaults = self.renderer.defaults
        self.assertEqual([defaults[k] for k in ("low_fuel_seconds", "esc_temp_seconds", "governor_lost_seconds")], [5, 5, 5])
        self.assertFalse(defaults["governor_status_overlays"])

    def test_low_fuel_live_values_and_nitro_electric(self):
        data = request("low_fuel")
        data["sensors"]["fuel"] = 17
        frame = self.renderer.render(data, 1)
        self.assertEqual(texts(frame), ["BATTERY EMPTY", "17%", "24.8V", "428mAh"])
        self.assertEqual(icons(frame), [21])
        data["sensors"]["modelType"] = 2
        nitro = self.renderer.render(data, 1.2)
        self.assertEqual(icons(nitro), [11])
        self.assertEqual(texts(nitro)[0], "LOW FUEL")
        self.assertEqual(frame["commands"][0]["text"]["font"], 1)
        self.assertEqual(nitro["commands"][0]["text"]["font"], 1)

    def test_german_alerts_match_locale_source(self):
        data = request("low_fuel")
        data["language"] = "de"
        self.assertEqual(texts(self.renderer.render(data, 1))[0], "AKKU LEER")
        data["sensors"]["modelType"] = 2
        self.assertEqual(texts(self.renderer.render(data, 2))[0], "KRAFTSTOFF NIEDRIG")
        data["preview"] = "esc_temp"
        self.assertEqual(texts(self.renderer.render(data, 3)), ["ESC TEMP HOCH", "95\N{DEGREE SIGN}C", "GRENZE 90\N{DEGREE SIGN}C"])
        data["preview"] = "rf_link"
        self.assertEqual(texts(self.renderer.render(data, 4))[0], "RF LINK SCHWACH")
        data["preview"] = "governor_lost"
        self.assertEqual(texts(self.renderer.render(data, 5))[:2], ["WARNUNG!", "DREHZAHL VERLOREN"])
        data["language"] = "en"
        self.assertEqual(texts(self.renderer.render(data, 6))[:2], ["WARNING!", "HEADSPEED LOST"])

    def test_unsupported_language_rejected(self):
        data = request("low_fuel")
        for language in ("../de", "zz", None):
            with self.subTest(language=language), self.assertRaises(ValueError):
                self.renderer.render({**data, "language": language}, 1)
        self.assertEqual(texts(self.renderer.render(data, 2))[0], "BATTERY EMPTY")

    def test_all_alert_translations_fit_glasses_geometry(self):
        locales = Path(__file__).resolve().parents[2] / "bin/i18n/json"
        for locale in locales.glob("*.json"):
            renderer = WidgetRenderer(locale.stem)
            for kind in ("low_fuel", "esc_temp", "rf_link", "governor_lost", "governor_status"):
                data = request(kind)
                data["language"] = locale.stem
                for model in (1, 2):
                    data["sensors"]["modelType"] = model
                    frame = renderer.render(data, 1)
                    for command in frame["commands"]:
                        if "text" in command:
                            t = command["text"]
                            with self.subTest(locale=locale.stem, kind=kind, text=t["text"]):
                                self.assertNotIn("@i18n", t["text"])
                                self.assertLessEqual(t["x"] + len(t["text"]) * frame["fonts"][t["font"] - 1] * 0.6, 289)

    def test_low_fuel_blink_and_stable_position(self):
        data = request("low_fuel")
        first = self.renderer.render(data, 1)
        steady = self.renderer.render(data, 1.4)
        off = self.renderer.render(data, 2)
        self.assertEqual(first["generation"], steady["generation"])
        self.assertEqual(icons(off), [])
        self.assertEqual(first["commands"][1]["text"], off["commands"][1]["text"])
        self.assertEqual(icons(self.renderer.render(data, 3)), [21])

    def test_esc_geometry_is_real_suite_commands(self):
        frame = self.renderer.render(request("esc_temp"), 1)
        self.assertEqual(texts(frame), ["ESC TEMP HIGH", "95\N{DEGREE SIGN}C", "LIMIT 90\N{DEGREE SIGN}C"])
        self.assertEqual(frame["commands"][0]["text"], {"text": "ESC TEMP HIGH", "x": 50, "y": 14, "font": 1})
        self.assertEqual(frame["commands"][2]["bitmap"], {"id": 18, "x": 74, "y": 89})

    def test_esc_blink_and_symbol_disabled(self):
        data = request("esc_temp")
        first = self.renderer.render(data, 1)
        off = self.renderer.render(data, 2)
        self.assertEqual(icons(off), [])
        self.assertEqual(first["commands"][1]["text"], off["commands"][1]["text"])
        data["settings"]["activelook"]["esc_temp_icon"] = False
        disabled = self.renderer.render(data, 3)
        self.assertEqual(icons(disabled), [])
        self.assertEqual(disabled["generation"], self.renderer.render(data, 4)["generation"])

    def test_fahrenheit_and_audio_limit(self):
        data = request("esc_temp")
        data["settings"]["general"]["temperature_unit"] = 1
        data["settings"]["events"]["escalertvalue"] = 100
        self.assertEqual(texts(self.renderer.render(data, 1)), ["ESC TEMP HIGH", "203\N{DEGREE SIGN}F", "LIMIT 212\N{DEGREE SIGN}F"])
        data["settings"]["activelook"].update(esc_temp_use_audio_limit=False, esc_temp_limit=80)
        self.assertEqual(texts(self.renderer.render(data, 2))[-1], "LIMIT 176\N{DEGREE SIGN}F")

    def test_rf_link_preview(self):
        data = request("rf_link")
        data["sensors"]["link"] = 38
        first = self.renderer.render(data, 1)
        self.assertEqual(texts(first), ["RF LINK LOW", "38dB", "LIMIT 42dB"])
        self.assertEqual(icons(first), [16])
        self.assertEqual(icons(self.renderer.render(data, 2)), [])
        data["sensors"].update(link=76, linkPercent=True)
        on = self.renderer.render(data, 3)
        self.assertEqual(texts(on), ["RF LINK LOW", "76%", "LIMIT 80%"])
        self.assertEqual(icons(on), [16])

    def test_rf_symbol_disabled(self):
        data = request("rf_link", rf_link_icon=False)
        first = self.renderer.render(data, 1)
        self.assertEqual(texts(first)[0], "RF LINK LOW")
        self.assertEqual(icons(first), [])
        self.assertEqual(icons(self.renderer.render(data, 3)), [])
        data["settings"]["activelook"]["rf_link_icon"] = True
        self.assertEqual(icons(self.renderer.render(data, 3.2)), [16])

    def test_lost_hs(self):
        frame = self.renderer.render(request("governor_lost"), 1)
        self.assertEqual(texts(frame), ["WARNING!", "HEADSPEED LOST", "RPM 1840"])
        self.assertEqual(frame["commands"][1]["text"]["font"], 1)
        self.assertEqual(icons(frame), [])

    def test_status_preview_cycles_only_in_preview(self):
        data = request("governor_status")
        for now, label in [(1, "AUTOROTATION"), (3, "BAILOUT"), (5, "AUTOROTATION"), (7, "BAILOUT")]:
            self.assertEqual(texts(self.renderer.render(data, now))[1], label)

    def test_real_status_is_telemetry_driven(self):
        data = request(governor_status_overlays=True)
        self.renderer.render(data, 1)
        data["sensors"]["governorState"] = 2
        self.assertIsNone(self.renderer.render(data, 1.5).get("overlay"))
        data["sensors"]["governorState"] = 8
        self.assertEqual(texts(self.renderer.render(data, 2))[1], "BAILOUT")
        self.assertIsNone(self.renderer.render(data, 4).get("overlay"))
        self.assertIsNone(self.renderer.render(data, 6).get("overlay"))

    def test_first_zero_does_not_trigger(self):
        data = request(low_fuel_warning=True)
        data["sensors"]["fuel"] = 0
        self.assertIsNone(self.renderer.render(data, 1).get("overlay"))
        self.assertEqual(self.renderer.render(data, 2)["overlay"], "low_fuel")

    def test_priority_and_resume(self):
        data = request(low_fuel_warning=True, low_fuel_seconds=8, esc_temp_warning=True,
                       esc_temp_seconds=3, esc_temp_repeats=1, esc_temp_use_audio_limit=False,
                       governor_lost_warning=True, governor_lost_seconds=3)
        data["sensors"]["tempEsc"] = 30
        self.renderer.render(data, 1)
        data["sensors"]["fuel"] = 0
        self.assertEqual(self.renderer.render(data, 2)["overlay"], "low_fuel")
        data["sensors"]["tempEsc"] = 95
        self.renderer.render(data, 3)
        self.assertEqual(self.renderer.render(data, 5)["overlay"], "esc_temp")
        data["sensors"]["governorState"] = 6
        self.assertEqual(self.renderer.render(data, 6)["overlay"], "governor_lost")
        self.assertEqual(self.renderer.render(data, 9)["overlay"], "esc_temp")
        self.assertEqual(self.renderer.render(data, 11)["overlay"], "low_fuel")
        self.assertIsNone(self.renderer.render(data, 16).get("overlay"))

    def test_audio_repeat_budget_overrides_own_count(self):
        data = request(esc_temp_warning=True, esc_temp_seconds=3, esc_temp_repeats=1,
                       esc_temp_use_audio_limit=True)
        data["settings"]["events"].update(escalertvalue=90, temp_esc_repeats=0)
        data["sensors"]["tempEsc"] = 30
        self.renderer.render(data, 1)
        data["sensors"]["tempEsc"] = 95
        self.renderer.render(data, 2)
        self.assertEqual(self.renderer.render(data, 4)["overlay"], "esc_temp")
        self.assertIsNone(self.renderer.render(data, 7).get("overlay"))
        self.assertEqual(self.renderer.render(data, 10)["overlay"], "esc_temp")

    def test_disable_clears_display_and_reenable_restores_it(self):
        data = request("low_fuel", inflight_fuel_icon=True)
        first = self.renderer.render(data, 1)
        self.assertTrue(texts(first))
        data["settings"]["activelook"]["enabled"] = False
        cleared = self.renderer.render(data, 2)
        self.assertGreater(cleared["generation"], first["generation"])
        self.assertEqual(cleared["commands"], [])
        self.assertIsNone(cleared.get("bitmap"))
        self.assertEqual(self.renderer.render(data, 3)["generation"], cleared["generation"])
        data["settings"]["activelook"]["enabled"] = True
        self.assertEqual(texts(self.renderer.render(data, 4))[0], "BATTERY EMPTY")

    def test_normal_link_slots_and_extremes_use_source_unit(self):
        for percent, suffix in [(True, "%"), (False, "dB")]:
            with self.subTest(percent=percent):
                renderer = WidgetRenderer()
                data = request("inflight", layout_inflight="stacked_three",
                               inflight_1="link", inflight_2="link_min", inflight_3="link_max")
                data["sensors"].update(link=76, linkPercent=percent)
                renderer.render(data, 1)
                renderer.render(data, 2)
                data["sensors"]["link"] = 60
                frame = renderer.render(data, 3)
                self.assertEqual(texts(frame), ["60" + suffix, "60" + suffix, "76" + suffix])

    def test_independent_esc_zero_repeats_remains_unlimited(self):
        data = request(esc_temp_warning=True, esc_temp_use_audio_limit=False,
                       esc_temp_seconds=3, esc_temp_repeats=0)
        data["sensors"]["tempEsc"] = 30
        self.renderer.render(data, 1)
        data["sensors"]["tempEsc"] = 95
        self.renderer.render(data, 2)
        self.assertEqual(self.renderer.render(data, 4)["overlay"], "esc_temp")
        self.assertIsNone(self.renderer.render(data, 7).get("overlay"))
        self.assertEqual(self.renderer.render(data, 10)["overlay"], "esc_temp")

    def test_normal_fuel_indicator_returns(self):
        data = request("low_fuel", inflight_fuel_icon=True)
        self.assertNotIn("bitmap", self.renderer.render(data, 1))
        data["preview"] = None
        frame = self.renderer.render(data, 2)
        self.assertNotIn("bitmap", frame)
        self.assertEqual(icons(frame), [5])
        self.assertEqual(frame["commands"][-1]["bitmap"], {"id": 5, "x": 0, "y": 144})
        self.assertIsNone(frame.get("overlay"))

    def test_fuel_indicator_is_in_text_frame_on_updates_and_phase_changes(self):
        data = request("inflight", inflight_fuel_icon=True)
        first = self.renderer.render(data, 1)
        data["sensors"]["current"] = 23
        changed = self.renderer.render(data, 2)
        self.assertGreater(changed["generation"], first["generation"])
        self.assertEqual(icons(changed), [5])
        self.assertNotIn("bitmap", changed)
        self.assertEqual(first["commands"][-1]["bitmap"], changed["commands"][-1]["bitmap"])
        data["sensors"]["fuel"] = 40
        self.assertEqual(icons(self.renderer.render(data, 3)), [4])
        data["preview"] = "preflight"
        self.assertEqual(icons(self.renderer.render(data, 4)), [])
        data["preview"] = "postflight"
        self.assertEqual(icons(self.renderer.render(data, 5)), [])

    def test_preflight_preview_suppresses_automatic_overlays(self):
        data = request("preflight", esc_temp_warning=True)
        self.renderer.render(data, 1)
        frame = self.renderer.render(data, 10)
        self.assertIsNone(frame.get("overlay"))
        self.assertIn("PRE", texts(frame))

    def test_missing_and_invalid_telemetry(self):
        data = request("esc_temp")
        data["sensors"]["tempEsc"] = float("nan")
        self.assertEqual(texts(self.renderer.render(data, 1))[1], "-")
        data["preview"] = "governor_lost"
        del data["sensors"]["rpm"]
        self.assertEqual(texts(self.renderer.render(data, 2))[-1], "RPM -")

    def test_disabled_display_is_blank(self):
        data = request("esc_temp", enabled=False)
        self.assertEqual(self.renderer.render(data, 1)["commands"], [])

    def test_validation(self):
        with self.assertRaises(ValueError):
            self.renderer.render(request("not-a-preview"), 1)
        data = request("low_fuel")
        data["settings"]["activelook"]["bad"] = {}
        with self.assertRaises(ValueError):
            self.renderer.render(data, 1)

    def test_clients_are_bounded_and_isolated(self):
        pool = RenderSessions()
        first = request("esc_temp"); first["client"] = "first"
        second = request("governor_lost"); second["client"] = "second"
        self.assertEqual(pool.render(first)["overlay"], "esc_temp")
        self.assertEqual(pool.render(second)["overlay"], "governor_lost")
        self.assertEqual(pool.render(first)["overlay"], "esc_temp")
        for i in range(9):
            data = copy.deepcopy(first); data["client"] = str(i); pool.render(data)
        self.assertEqual(len(pool.sessions), 8)
        with self.assertRaises(ValueError):
            pool.render({"client": "../bad"})


class SettingsFileTests(unittest.TestCase):
    def test_read_settings_and_save_layouts_preserves_alerts(self):
        import server
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            path = folder / "settings.ini"
            path.write_text("[general]\ntemperature_unit=1\n[events]\nescalertvalue=100\n[activelook]\nenabled=true\nesc_temp_icon=false\nlow_fuel_seconds=12\n", encoding="utf-8")
            with patch("server.simulator_config", return_value=({}, folder, folder, path)):
                current = server.activelook_config_payload()
                self.assertEqual(current["general"]["temperature_unit"], "1")
                self.assertEqual(current["events"]["escalertvalue"], "100")
                edit = {"revision": current["revision"], "settings": {}}
                for phase in server.PHASES:
                    edit["settings"]["layout_" + phase] = "one_centered"
                    edit["settings"][phase] = ["fuel", "off", "off", "off"]
                status, saved = server.update_activelook_config(edit)
                self.assertEqual(status, 200)
                self.assertEqual(saved["settings"]["esc_temp_icon"], "false")
                self.assertEqual(saved["settings"]["low_fuel_seconds"], "12")
                self.assertEqual(saved["settings"]["inflight_1"], "fuel")
                self.assertEqual(saved["general"]["temperature_unit"], "1")
                edit["revision"] = "outdated"
                self.assertEqual(server.update_activelook_config(edit)[0], 409)


class HttpTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = PreviewServer(("127.0.0.1", 0), PreviewHandler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown(); cls.server.server_close(); cls.thread.join()

    def call(self, method, path, data=None, headers=None):
        connection = HTTPConnection("127.0.0.1", self.server.server_port)
        body = json.dumps(data) if data is not None else None
        connection.request(method, path, body=body, headers=headers or ({"Content-Type": "application/json"} if body else {}))
        response = connection.getresponse(); result = response.read(); status = response.status
        connection.close()
        return status, result

    def test_second_server_cannot_bind_existing_port(self):
        with self.assertRaises(OSError):
            with PreviewServer(("127.0.0.1", self.server.server_port), PreviewHandler):
                self.fail("second listener must not start")
        self.assertEqual(self.call("GET", "/api/render-defaults")[0], 200)

    def test_second_start_does_not_fall_back_or_open_browser(self):
        with patch("server.PREVIEW_PORT", self.server.server_port), \
             patch("server.PreviewServer", wraps=PreviewServer) as constructor, \
             patch("server.webbrowser.open") as browser, \
             patch("sys.stdout", new_callable=io.StringIO) as output:
            self.assertIsNone(main(["--open"]))
            constructor.assert_called_once()
            browser.assert_not_called()
            self.assertIn("No second instance was started", output.getvalue())

    def test_occupied_port_entrypoint_returns_without_system_exit(self):
        import server
        with patch("socket.socket.bind", side_effect=OSError("port already in use")), \
             patch("sys.argv", [server.__file__]), \
             patch("sys.stdout", new_callable=io.StringIO) as output:
            runpy.run_path(server.__file__, run_name="__main__")
            self.assertIn("No second instance was started", output.getvalue())

    def test_render_endpoint_and_no_simulator_write(self):
        data = request("esc_temp"); data["client"] = "http-test"
        with patch("server.update_activelook_config", side_effect=AssertionError("preview must never write settings")):
            status, body = self.call("POST", "/api/render", data)
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body)["overlay"], "esc_temp")

    def test_defaults_endpoint(self):
        status, body = self.call("GET", "/api/render-defaults")
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body)["settings"]["low_fuel_seconds"], 5)

    def test_atlas_and_background(self):
        for path in ("/api/bitmap-atlas", "/Engo-Sports-Eyewear.jpg"):
            status, body = self.call("GET", path)
            self.assertEqual(status, 200)
            self.assertGreater(len(body), 1000)

    def test_host_and_bad_requests(self):
        self.assertEqual(self.call("GET", "/api/render-defaults", headers={"Host": "example.com"})[0], 403)
        self.assertEqual(self.call("POST", "/api/render", {"client": "ok", "preview": "unknown"})[0], 400)
        self.assertEqual(self.call("POST", "/api/render", request(), {"Content-Type": "text/plain"})[0], 415)


if __name__ == "__main__":
    unittest.main()
