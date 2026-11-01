"""Desktop-only Lua 5.4 adapter; all layout and alert logic comes from src/rfsuite."""
from __future__ import annotations

import json
import importlib.util
import math
import re
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
_i18n_spec = importlib.util.spec_from_file_location("activelook_i18n", ROOT / ".vscode/scripts/resolve_i18n_tags.py")
_I18N = importlib.util.module_from_spec(_i18n_spec)
_i18n_spec.loader.exec_module(_I18N)
PREVIEWS = {None, "preflight", "inflight", "postflight", "low_fuel", "esc_temp", "governor_lost", "governor_status", "rf_link"}


class WidgetRenderer:
    def __init__(self, language="en"):
        try:
            from lupa.lua54 import LuaRuntime
        except ImportError as error:
            raise RuntimeError("Install the preview dependency: python -m pip install -r bin/activelook_preview/requirements.txt") from error
        lua = LuaRuntime(unpack_returned_tuples=True, register_eval=False, register_builtins=False)
        factory = lua.execute(Path(__file__).with_suffix(".lua").read_text(encoding="utf-8"))
        locale = ROOT / "bin/i18n/json" / f"{language}.json"
        if not re.fullmatch(r"[a-z]{2}(?:-[a-z]{2})?", language) or not locale.is_file():
            raise ValueError("unknown preview language")
        translations = json.loads(locale.read_text(encoding="utf-8"))
        source = (ROOT / "src/rfsuite/widgets/activelook.lua").read_text(encoding="utf-8")
        stats = {}
        source, _ = _I18N.replace_tags_in_text(source, translations, stats)
        if stats.get("unresolved"):
            raise RuntimeError("unresolved preview translations")
        step = factory((ROOT / "src/rfsuite").as_posix() + "/", source)
        defaults = self.native(lua.eval('package.loaded["rfsuite.lib.activelook_config"].DEFAULTS'))
        self.lua, self.step, self.defaults = lua, step, defaults
        self.language = language
        self.settings_key = None
        self.last_used = time.monotonic()

    def table(self, value):
        if isinstance(value, dict):
            return self.lua.table_from({k: self.table(v) for k, v in value.items()})
        if isinstance(value, list):
            return self.lua.table_from([self.table(v) for v in value])
        return value

    def native(self, value):
        if hasattr(value, "items"):
            values = dict(value.items())
            if values and all(isinstance(k, int) for k in values):
                return [self.native(values[k]) for k in sorted(values)]
            return {k: self.native(v) for k, v in values.items()}
        return value

    def render(self, request, now=None):
        language = request.get("language", "en")
        if not isinstance(language, str):
            raise ValueError("invalid preview language")
        if language != self.language:
            self.__init__(language)
        preview = request.get("preview") or None
        if preview not in PREVIEWS:
            raise ValueError("unknown preview")
        settings = request.get("settings", {})
        sensors = request.get("sensors", {})
        if not isinstance(settings, dict) or not isinstance(sensors, dict):
            raise ValueError("settings and sensors must be objects")
        # Only telemetry numbers/booleans are admitted; strings cannot reach arithmetic paths.
        def number(key):
            value = sensors.get(key)
            return value if type(value) in (int, float) and math.isfinite(value) else None
        snapshot = {key: number(key) for key in ("voltage", "current", "consumption", "tempEsc", "tempMcu", "rpm", "governorState", "throttlePercent")}
        snapshot.update(connected=sensors.get("connected", True) is True, isArmed=sensors.get("armed") is True,
                        fuelPercent=number("fuel"), linkQuality=number("link"), linkQualityIsPercent=sensors.get("linkPercent") is True, timerLive=number("timer"), timerSession=number("timer"),
                        batteryConfig={"cellCount": number("cellCount")}, smartfuelModelType=number("modelType"))
        cfg = {"activelook": settings.get("activelook", {}), "general": settings.get("general", {}), "events": settings.get("events", {})}
        if any(not isinstance(section, dict) for section in cfg.values()):
            raise ValueError("invalid settings section")
        # Settings must remain flat scalar data, just like settings.ini.
        if any(type(v) not in (str, bool, int, float) for section in cfg.values() for v in section.values()):
            raise ValueError("settings must contain scalar values")
        key = json.dumps(cfg, sort_keys=True, allow_nan=False)
        self.last_used = time.monotonic()
        try:
            frame = self.native(self.step(self.table(cfg), self.table(snapshot), preview,
                                          self.last_used if now is None else now, key != self.settings_key))
        except Exception as error:
            raise RuntimeError(f"Suite renderer failed: {error}") from error
        self.settings_key = key
        if not frame["commands"]:
            frame["commands"] = []
        return {"ok": True, **frame}


class RenderSessions:
    """Bound desktop runtimes and serialize HTTP access to their Lua states."""
    def __init__(self):
        self.sessions = {}
        self.lock = threading.Lock()

    def render(self, request):
        client = request.get("client")
        if not isinstance(client, str) or not re.fullmatch(r"[a-zA-Z0-9_-]{1,64}", client):
            raise ValueError("invalid preview client")
        with self.lock:
            now = time.monotonic()
            for key in list(self.sessions):
                if now - self.sessions[key].last_used > 600:
                    del self.sessions[key]
            if client not in self.sessions:
                if len(self.sessions) >= 8:
                    oldest = min(self.sessions, key=lambda key: self.sessions[key].last_used)
                    del self.sessions[oldest]
                self.sessions[client] = WidgetRenderer()
            return self.sessions[client].render(request)
