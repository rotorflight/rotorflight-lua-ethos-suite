"""Serve the ActiveLook preview and the active Ethos simulator sensor profiles."""

from __future__ import annotations

import argparse
import json
import os
import random
import re
import tempfile
import webbrowser
from datetime import datetime, timezone
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[2]
PREVIEW_DIR = Path(__file__).resolve().parent
NUMBER = r"[+-]?(?:\d+(?:\.\d*)?|\.\d+)"
RANDOM_RETURN = re.compile(rf"return\s+math\.random\(\s*({NUMBER})\s*,\s*({NUMBER})\s*\)", re.S)
NUMBER_RETURN = re.compile(rf"return\s+({NUMBER})\b", re.S)
SENSOR_FILES = {
    "current": "current",
    "voltage": "voltage",
    "becVoltage": "bec_voltage",
    "fuel": "fuel",
    "timer": None,
    "rpm": "rpm",
    "tempEsc": "temp_esc",
    "tempMcu": "temp_mcu",
    "consumption": "consumption",
    "cellCount": "cell_count",
    "governorState": "governor",
    "throttlePercent": "throttle_percent",
    "armflags": "armflags",
    "pidProfile": "pid_profile",
    "rateProfile": "rate_profile",
    "batteryProfile": "battery_profile",
    "altitude": "altitude",
}
LAYOUT_KEYS = {
    "two_top_one_bottom",
    "two_top_two_bottom",
    "one_centered",
    "one_top_two_bottom",
    "stacked_three",
}
SENSOR_KEYS = {
    "off", "flightmode", "timer", "governor", "armed", "temp_esc", "temp_mcu", "link", "fuel",
    "current", "voltage", "cell_voltage", "headspeed", "consumption", "temp_esc_max", "temp_mcu_max",
    "link_min", "link_max", "fuel_min", "fuel_max", "current_min", "current_max", "voltage_min",
    "voltage_max", "headspeed_min", "headspeed_max",
}
PHASES = ("preflight", "inflight", "postflight")


class SimulatorConfigError(Exception):
    """The workspace cannot identify a usable Ethos simulator target."""


def parse_jsonc(source: str) -> dict:
    """Parse VS Code JSONC settings without changing comment-like string values."""
    output = []
    index = 0
    in_string = False
    escaped = False
    while index < len(source):
        char = source[index]
        if in_string:
            output.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue

        if char == '"':
            in_string = True
            output.append(char)
            index += 1
            continue
        if char == "/" and index + 1 < len(source) and source[index + 1] in ("/", "*"):
            if source[index + 1] == "/":
                index += 2
                while index < len(source) and source[index] not in "\r\n":
                    index += 1
                continue
            index += 2
            while index + 1 < len(source) and source[index:index + 2] != "*/":
                if source[index] in "\r\n":
                    output.append(source[index])
                index += 1
            if index + 1 >= len(source):
                raise ValueError("unterminated block comment in .vscode/settings.json")
            index += 2
            continue
        if char == ",":
            lookahead = index + 1
            while lookahead < len(source) and source[lookahead].isspace():
                lookahead += 1
            if lookahead < len(source) and source[lookahead] in "]}":
                index += 1
                continue

        output.append(char)
        index += 1

    settings = json.loads("".join(output))
    if not isinstance(settings, dict):
        raise ValueError(".vscode/settings.json must contain a JSON object")
    return settings


def simulator_config() -> tuple[dict, Path, Path, Path]:
    settings_path = ROOT / ".vscode" / "settings.json"
    try:
        settings = parse_jsonc(settings_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as error:
        raise SimulatorConfigError(f"Cannot read simulator settings from {settings_path}: {error}") from error

    board = settings.get("ethos.board")
    protocol = settings.get("ethos.protocol")
    release = settings.get("ethos.release")
    if not board or not protocol:
        raise SimulatorConfigError(f"ethos.board and ethos.protocol must be set in {settings_path}")
    simulators_dir = Path(settings.get("ethos.simulatorsFolder", "simulators"))
    if not simulators_dir.is_absolute():
        simulators_dir = ROOT / simulators_dir

    prefix = f"{board}_{protocol}"
    candidates = sorted(
        (path for path in simulators_dir.glob(f"{prefix}@*") if path.is_dir()),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    exact = simulators_dir / f"{prefix}@{release}"
    simulator_dir = exact if exact.is_dir() else (candidates[0] if candidates else exact)
    sensor_dir = simulator_dir / "scripts" / "rfsuite" / "sim" / "sensors"
    settings_file = simulator_dir / "scripts" / "rfsuite.user" / "settings.ini"
    return settings, simulator_dir, sensor_dir, settings_file


def read_lua_number(path: Path) -> tuple[float | None, bool]:
    try:
        source = path.read_text(encoding="utf-8")
    except OSError:
        return None, False

    match = RANDOM_RETURN.search(source)
    if match:
        low, high = (float(match.group(1)), float(match.group(2)))
        if low.is_integer() and high.is_integer():
            return float(random.randint(int(low), int(high))), True
        return random.uniform(low, high), True

    match = NUMBER_RETURN.search(source)
    if match:
        return float(match.group(1)), False
    return None, False


def telemetry_payload() -> dict:
    _, simulator_dir, sensor_dir, _ = simulator_config()
    if not sensor_dir.is_dir():
        return {
            "ok": False,
            "target": simulator_dir.name,
            "error": "Simulator sensor profile folder not found. Deploy the suite and save values in sensors.exe.",
            "values": {},
        }

    raw = {}
    random_fields = []
    for field, sensor_name in SENSOR_FILES.items():
        if sensor_name is None:
            continue
        value, sampled = read_lua_number(sensor_dir / f"{sensor_name}.lua")
        if value is not None:
            raw[field] = value
            if sampled:
                random_fields.append(field)

    values = {}
    for field in (
        "current", "becVoltage", "fuel", "rpm", "tempEsc", "tempMcu",
        "consumption", "cellCount", "governorState", "throttlePercent",
        "pidProfile", "rateProfile", "batteryProfile", "altitude",
    ):
        if field in raw:
            values[field] = raw[field]
    if "voltage" in raw:
        values["voltage"] = raw["voltage"] / 100
    if "becVoltage" in raw:
        values["becVoltage"] = raw["becVoltage"] / 100
    if "armflags" in raw:
        values["armed"] = (int(raw["armflags"]) & 1) == 1

    return {
        "ok": bool(values),
        "target": simulator_dir.name,
        "updatedAt": datetime.now(timezone.utc).isoformat(),
        "randomFields": random_fields,
        "values": values,
    }


def activelook_config_payload() -> dict:
    _, simulator_dir, _, settings_file = simulator_config()
    try:
        file_stat = settings_file.stat()
        contents = settings_file.read_text(encoding="utf-8")
    except OSError:
        return {
            "ok": False,
            "target": simulator_dir.name,
            "error": "Simulator settings file not found. Save ActiveLook settings in the simulator first.",
            "settings": {},
        }

    section = None
    values = {}
    for line in contents.splitlines():
        line = line.strip()
        if not line or line.startswith((";", "#")):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].strip()
            continue
        if section != "activelook" or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()

    return {
        "ok": bool(values),
        "target": simulator_dir.name,
        "revision": str(file_stat.st_mtime_ns),
        "settings": values,
    }


def update_activelook_config(request: dict) -> tuple[int, dict]:
    _, _, _, settings_file = simulator_config()
    current = activelook_config_payload()
    if not current.get("ok"):
        return 404, current
    if str(request.get("revision", "")) != current["revision"]:
        return 409, current

    requested = request.get("settings")
    if not isinstance(requested, dict):
        return 400, {"ok": False, "error": "settings must be an object"}

    updates = {}
    for phase in PHASES:
        layout = requested.get(f"layout_{phase}")
        slots = requested.get(phase)
        if layout not in LAYOUT_KEYS or not isinstance(slots, list) or len(slots) != 4:
            return 400, {"ok": False, "error": f"invalid ActiveLook configuration for {phase}"}
        if any(slot not in SENSOR_KEYS for slot in slots):
            return 400, {"ok": False, "error": f"invalid ActiveLook slot for {phase}"}
        updates[f"layout_{phase}"] = layout
        for index, slot in enumerate(slots, start=1):
            updates[f"{phase}_{index}"] = slot

    text = settings_file.read_text(encoding="utf-8")
    if str(settings_file.stat().st_mtime_ns) != current["revision"]:
        return 409, activelook_config_payload()
    lines = text.splitlines(keepends=True)
    section_start = None
    section_end = len(lines)
    current_section = None
    for index, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            if current_section == "activelook":
                section_end = index
                break
            current_section = stripped[1:-1].strip()
            if current_section == "activelook":
                section_start = index

    if section_start is None:
        if text and not text.endswith(("\n", "\r")):
            lines.append("\n")
        if lines and lines[-1].strip():
            lines.append("\n")
        lines.append("[activelook]\n")
        section_start = len(lines) - 1
        section_end = len(lines)

    seen = set()
    for index in range(section_start + 1, section_end):
        line = lines[index]
        match = re.match(r"^(\s*)([\w_]+)(\s*=\s*)(.*?)(\r?\n)?$", line)
        if match and match.group(2) in updates:
            key = match.group(2)
            newline = match.group(5) or ""
            lines[index] = f"{match.group(1)}{key}{match.group(3)}{updates[key]}{newline}"
            seen.add(key)

    missing = [f"{key}={value}\n" for key, value in updates.items() if key not in seen]
    if missing and section_end > 0 and not lines[section_end - 1].endswith(("\n", "\r")):
        lines[section_end - 1] += "\n"
    lines[section_end:section_end] = missing
    settings_file.parent.mkdir(parents=True, exist_ok=True)
    temp_path = None
    try:
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", newline="", dir=settings_file.parent, delete=False) as temp:
            temp_path = Path(temp.name)
            temp.writelines(lines)
            temp.flush()
            os.fsync(temp.fileno())
        if str(settings_file.stat().st_mtime_ns) != current["revision"]:
            temp_path.unlink(missing_ok=True)
            return 409, activelook_config_payload()
        os.replace(temp_path, settings_file)
    except OSError as error:
        if temp_path:
            temp_path.unlink(missing_ok=True)
        return 500, {"ok": False, "error": f"could not save simulator settings: {error}"}

    return 200, activelook_config_payload()


class PreviewHandler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".otf": "font/otf"}

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(PREVIEW_DIR), **kwargs)

    def send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def loopback_host_allowed(self) -> bool:
        return self.headers.get("Host", "") == f"127.0.0.1:{self.server.server_port}"

    def do_GET(self):
        endpoint = urlparse(self.path).path
        if endpoint in ("/api/telemetry", "/api/activelook-config"):
            if not self.loopback_host_allowed():
                self.send_json(403, {"ok": False, "error": "invalid Host header"})
                return
            try:
                payload = telemetry_payload() if endpoint == "/api/telemetry" else activelook_config_payload()
            except SimulatorConfigError as error:
                self.send_json(503, {"ok": False, "error": str(error), "values": {}, "settings": {}})
                return
            self.send_json(200, payload)
            return
        super().do_GET()

    def do_POST(self):
        if urlparse(self.path).path != "/api/activelook-config":
            self.send_error(404)
            return
        if not self.loopback_host_allowed():
            self.send_json(403, {"ok": False, "error": "invalid Host header"})
            return
        if self.headers.get_content_type() != "application/json":
            self.send_json(415, {"ok": False, "error": "Content-Type must be application/json"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > 16384:
                raise ValueError("invalid request size")
            request = json.loads(self.rfile.read(length).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as error:
            self.send_json(400, {"ok": False, "error": str(error)})
            return
        try:
            status, payload = update_activelook_config(request)
        except SimulatorConfigError as error:
            self.send_json(503, {"ok": False, "error": str(error)})
            return
        self.send_json(status, payload)

    def log_message(self, format, *args):
        print(f"[{self.log_date_time_string()}] {format % args}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run the ActiveLook simulator preview.")
    parser.add_argument("--open", action="store_true", help="Open the preview URL in the default browser")
    args = parser.parse_args()

    server = None
    for port in range(8765, 8776):
        try:
            server = ThreadingHTTPServer(("127.0.0.1", port), PreviewHandler)
            break
        except OSError:
            continue
    if server is None:
        raise OSError("No available preview port in range 8765-8775")
    url = f"http://127.0.0.1:{server.server_port}"
    print(f"ActiveLook preview: {url}")
    print("Reads sensor profiles from the Ethos simulator folder in .vscode/settings.json.")
    if args.open:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Stopping ActiveLook preview server.")
    finally:
        server.server_close()