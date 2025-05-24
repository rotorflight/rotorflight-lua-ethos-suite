import os
import sys
import re
import json
import tkinter as tk
from pathlib import Path
from tkinter import ttk

# --- Constants from environment variables ---
FRSKY_RFSUITE_GIT_SRC = os.environ.get('FRSKY_RFSUITE_GIT_SRC')
FRSKY_SIM_SRC = os.environ.get('FRSKY_SIM_SRC')

sensor_map = {}
sensor_names = {}
sensor_name_map = {}  # Maps sensor keys to language keys

def validate_paths():
    if not FRSKY_RFSUITE_GIT_SRC or not Path(FRSKY_RFSUITE_GIT_SRC).exists():
        raise ValueError(f"FRSKY_RFSUITE_GIT_SRC not set or invalid: {FRSKY_RFSUITE_GIT_SRC}")
    if not FRSKY_SIM_SRC:
        raise ValueError("FRSKY_SIM_SRC not set.")
    sim_paths = [p.strip() for p in FRSKY_SIM_SRC.split(',')]
    for path in sim_paths:
        if not Path(path).exists():
            raise ValueError(f"FRSKY_SIM_SRC path invalid: {path}")
    return sim_paths

def load_sensor_names():
    global sensor_names
    json_path = Path(FRSKY_RFSUITE_GIT_SRC) / 'bin' / 'i18n' / 'json' / 'telemetry' / 'en.json'
    if not json_path.exists():
        raise FileNotFoundError(f"en.json not found at {json_path}")
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        sensor_names = {
            key: value['english']
            for key, value in data.get('sensors', {}).items()
            if 'english' in value
        }

def parse_telemetry_lua():
    global sensor_name_map
    sensor_map.clear()
    sensor_name_map.clear()
    telemetry_file = Path(FRSKY_RFSUITE_GIT_SRC) / 'scripts' / 'rfsuite' / 'tasks' / 'telemetry' / 'telemetry.lua'
    if not telemetry_file.exists():
        raise FileNotFoundError(f"telemetry.lua not found at {telemetry_file}")
    with telemetry_file.open('r', encoding='utf-8') as f:
        content = f.read()
    pattern = re.compile(r'(?m)^\s*(\w+)\s*=\s*{(.*?)}', re.DOTALL)
    for match in pattern.finditer(content):
        sensor_key, block = match.groups()
        if sensor_key == "rssi":
            continue  # Skip rssi sensor
        name_match = re.search(r'rfsuite\.i18n\.get\(["\']telemetry\.sensors\.(\w+)["\']\)', block)
        if name_match:
            lang_key = name_match.group(1)
            sensor_name_map[sensor_key] = lang_key
    sensors = sorted(sensor_name_map.keys())
    for sensor in sensors:
        sensor_map[sensor] = []
    return sensors

def build_sensor_paths(sim_paths):
    for sensor in sensor_map:
        for sim_base in sim_paths:
            sensor_file = Path(sim_base) / 'rfsuite' / 'sim' / 'sensors' / f"{sensor}.lua"
            sensor_map[sensor].append(sensor_file)

def update_sensor(sensor, content):
    for filepath in sensor_map[sensor]:
        filepath.parent.mkdir(parents=True, exist_ok=True)
        with filepath.open('w', encoding='utf-8') as f:
            f.write(content + "\n")

def read_current_value(sensor):
    for filepath in sensor_map[sensor]:
        if filepath.exists():
            with filepath.open('r', encoding='utf-8') as f:
                return f.read().strip()
    return ""

def parse_value_content(content):
    match_val = re.match(r"return (\d+(\.\d+)?)", content)
    if match_val:
        return match_val.group(1), ""
    match_rng = re.match(r"return math\.random\((\d+),\s*(\d+)\)", content)
    if match_rng:
        return match_rng.group(1), match_rng.group(2)
    return "", ""

def update_status_message(sensor_key, val1, val2):
    if val1 and val2:
        return f"Updating sensor key '{sensor_key}' to range {val1}-{val2}"
    elif val1:
        return f"Updating sensor key '{sensor_key}' to value {val1}"
    else:
        return "Enter a value"

# --- GUI Application ---
class SensorApp:
    def __init__(self, root):
        self.root = root
        root.title("Rotorflight RFSUITE Sensor Updater")
        self.main_frame = tk.Frame(root)
        self.main_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        self.refresh_sensors()

    def refresh_sensors(self):
        for widget in self.main_frame.winfo_children():
            widget.destroy()
        tk.Label(self.main_frame, text="Name", font="bold").grid(row=0, column=0, sticky="w", padx=5)
        tk.Label(self.main_frame, text="Min", font="bold").grid(row=0, column=1, padx=5)
        tk.Label(self.main_frame, text="Max", font="bold").grid(row=0, column=2, padx=5)
        tk.Label(self.main_frame, text="", width=10).grid(row=0, column=3)
        tk.Label(self.main_frame, text="Status", font="bold").grid(row=0, column=4, sticky="w", padx=5)

        try:
            sim_paths = validate_paths()
            load_sensor_names()
            sensors = parse_telemetry_lua()
            build_sensor_paths(sim_paths)
        except Exception as e:
            tk.Label(self.main_frame, text=f"Error: {str(e)}", fg="red").grid(row=1, column=0, columnspan=5, sticky="w")
            return

        for idx, sensor in enumerate(sensor_map, start=1):
            current = read_current_value(sensor)
            val1, val2 = parse_value_content(current)
            lang_key = sensor_name_map.get(sensor, sensor)
            display_name = sensor_names.get(lang_key, sensor)

            tk.Label(self.main_frame, text=display_name, width=30, anchor='w').grid(row=idx, column=0, sticky="w", padx=5)
            val1_entry = tk.Entry(self.main_frame, width=10)
            val1_entry.insert(0, val1)
            val1_entry.grid(row=idx, column=1, padx=5)
            val2_entry = tk.Entry(self.main_frame, width=10)
            val2_entry.insert(0, val2)
            val2_entry.grid(row=idx, column=2, padx=5)
            status_label = tk.Label(self.main_frame, text="", width=50, anchor='w', fg="green")
            status_label.grid(row=idx, column=4, sticky="w", padx=5)
            submit_button = tk.Button(
                self.main_frame,
                text="Submit",
                command=lambda s=sensor, e1=val1_entry, e2=val2_entry, sl=status_label: self.submit_values(s, e1.get(), e2.get(), sl)
            )
            submit_button.grid(row=idx, column=3, padx=5)

    def submit_values(self, sensor, val1, val2, status_label):
        try:
            val1 = val1.strip()
            val2 = val2.strip()
            if val1 and val2:
                min_val = int(val1)
                max_val = int(val2)
                update_sensor(sensor, f"return math.random({min_val}, {max_val})")
                self.set_inline_status(status_label, update_status_message(sensor, val1, val2), error=False)
            elif val1:
                value = float(val1)
                value_msg = int(value) if value.is_integer() else value
                update_sensor(sensor, f"return {value}")
                self.set_inline_status(status_label, update_status_message(sensor, str(value_msg), ""), error=False)
            else:
                self.set_inline_status(status_label, update_status_message(sensor, "", ""), error=True)

            self.root.bell()  # Play audio beep on update

        except Exception as e:
            self.set_inline_status(status_label, f"Error: {str(e)}", error=True)

    def set_inline_status(self, label_widget, message, error=False):
        label_widget.config(text=message, fg="red" if error else "green")
        self.root.after(5000, lambda: label_widget.config(text=""))

if __name__ == "__main__":
    root = tk.Tk()
    app = SensorApp(root)
    root.mainloop()