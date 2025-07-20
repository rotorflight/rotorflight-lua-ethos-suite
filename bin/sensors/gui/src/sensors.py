import os
import xml.etree.ElementTree as ET
import tkinter as tk
import sys
from tkinter import ttk
from pathlib import Path

SENSOR_FILE_EXT = ".lua"

class SensorApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Sensor Editor")

        # Try to load icon from current directory or ./src
        possible_icons = [
            Path(sys.executable).with_name("sensors.ico"),
            Path(__file__).parent / "sensors.ico"
        ]
        for icon_path in possible_icons:
            if icon_path.exists():
                try:
                    self.root.iconbitmap(default=icon_path)
                    break
                except Exception as e:
                    print(f"[DEBUG] Could not set icon from {icon_path}: {e}")
        self.controls = {}

        self.rf_src = os.environ.get("FRSKY_RFSUITE_GIT_SRC")
        self.sim_src = os.environ.get("FRSKY_SIM_SRC")

        if not self.rf_src or not Path(self.rf_src).exists():
            raise EnvironmentError("FRSKY_RFSUITE_GIT_SRC is not set or invalid.")
        if not self.sim_src:
            raise EnvironmentError("FRSKY_SIM_SRC is not set.")

        self.sim_paths = [Path(p.strip()) for p in self.sim_src.split(',') if Path(p.strip()).exists()]
        if not self.sim_paths:
            raise FileNotFoundError("No valid paths found in FRSKY_SIM_SRC.")

        self.load_config()

    def load_config(self):
        config_path = Path(self.rf_src) / "bin" / "sensors" / "gui" / "sensors.xml"
        if not config_path.exists():
            raise FileNotFoundError(f"Missing XML config: {config_path}")

        tree = ET.parse(config_path)
        root = tree.getroot()

        for group in root.findall("Group"):
            frame = ttk.LabelFrame(self.root, text=group.get("name"))
            frame.pack(fill="x", padx=10, pady=5)

            for sensor in group.findall("Sensor"):
                self.add_sensor_control(frame, sensor)

        ttk.Button(self.root, text="Save All", command=self.save_all).pack(pady=10)

    def add_sensor_control(self, parent, sensor_elem):
        name = sensor_elem.get("name")
        label = sensor_elem.get("label", name)
        sensor_type = sensor_elem.get("type", "number")
        multiplier = float(sensor_elem.get("multiplier", 1))
        unit = sensor_elem.get("unit", "")
        default = float(sensor_elem.get("default", 0))

        row = ttk.Frame(parent)
        row.pack(fill="x", padx=5, pady=2)

        ttk.Label(row, text=label, width=20).pack(side="left")
        value_var = tk.StringVar()
        value_var.set(str(default))

        lua_path = self.sim_paths[0] / "rfsuite" / "sim" / "sensors" / (name + SENSOR_FILE_EXT)
        control = None

        if sensor_type == "range":
            min_val = float(sensor_elem.get("min", 0))
            max_val = float(sensor_elem.get("max", 100))
            step = float(sensor_elem.get("step", 1))
            rounding = sensor_elem.get("round") == "true"
            control = ttk.Scale(row, from_=min_val, to=max_val, orient="horizontal",
                                command=lambda v, var=value_var: var.set(f"{int(float(v))}" if rounding else f"{float(v):.2f}"))
            control.set(default)
            control.pack(side="left", fill="x", expand=True)
            entry = ttk.Entry(row, textvariable=value_var, width=6)
            entry.pack(side="left", padx=5)

        elif sensor_type == "bool":
            control = ttk.Checkbutton(row, variable=value_var, onvalue="1", offvalue="0")
            value_var.set("1" if default else "0")
            control.pack(side="left")

        elif sensor_type == "select":
            control = ttk.Combobox(row, textvariable=value_var, state="readonly")
            options = [opt.get("label") for opt in sensor_elem.findall("Option")]
            values = [opt.get("value") for opt in sensor_elem.findall("Option")]
            control["values"] = options
            value_map = dict(zip(options, values))
            reverse_map = dict(zip(values, options))
            display_val = reverse_map.get(str(default), options[0] if options else "")
            value_var.set(display_val)
            control.pack(side="left")
            self.controls[name] = (value_var, multiplier, lua_path, sensor_type, value_map)
            return

        else:
            rounding = sensor_elem.get("round") == "true"
            if rounding:
                value_var.set(str(int(default)))
            control = ttk.Entry(row, textvariable=value_var)
            control.pack(side="left", fill="x", expand=True)

        if unit:
            ttk.Label(row, text=unit).pack(side="left")

        self.controls[name] = (value_var, multiplier, lua_path, sensor_type, None)

    def save_all(self):
        for name, (var, mult, _, sensor_type, val_map) in self.controls.items():
            value = var.get()
            try:
                if sensor_type == "select" and val_map:
                    value = val_map.get(value, "0")
                numeric = float(value) * mult

                config_path = Path(self.rf_src) / "bin" / "sensors" / "gui" / "sensors.xml"
                tree = ET.parse(config_path)
                sensor_elem = None
                for group in tree.getroot().findall("Group"):
                    for sensor in group.findall("Sensor"):
                        if sensor.get("name") == name:
                            sensor_elem = sensor
                            break
                    if sensor_elem:
                        break

                rand_attr = sensor_elem.get("rand") if sensor_elem is not None else None

                for sim_path in self.sim_paths:
                    path = sim_path / "rfsuite" / "sim" / "sensors" / (name + SENSOR_FILE_EXT)
                    print(f"[DEBUG] Saving {name} to {path} with value {numeric}")
                    with open(path, "w") as f:
                        if rand_attr:
                            try:
                                percent = float(rand_attr)
                                delta = numeric * percent / 100.0
                                low = int(numeric - delta)
                                high = int(numeric + delta)
                                f.write(f"return math.random({low}, {high})")
                            except Exception as e:
                                print(f"[DEBUG] Invalid rand for {name}: {rand_attr} -> {e}")
                                f.write(f"return {numeric}")
                        else:
                            f.write(f"return {numeric}")
            except Exception as e:
                print(f"Error saving {name}: {e}")


if __name__ == "__main__":
    root = tk.Tk()
    app = SensorApp(root)
    root.mainloop()
