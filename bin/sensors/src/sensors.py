import sys
import json
import xml.etree.ElementTree as ET
import tkinter as tk
from tkinter import ttk
from pathlib import Path

SENSOR_FILE_EXT = ".lua"

# Determine config path based on execution context
# Config.json resides at <repo_root>/bin/config.json
if getattr(sys, 'frozen', False):
    # Running as bundled executable: repo_root is two levels up from the exe
    base_dir = Path(sys.executable).resolve().parents[2]
else:
    # Running as script: repo_root is three levels up from this file
    base_dir = Path(__file__).resolve().parents[3]
CONFIG_PATH = base_dir / 'bin' / 'config.json'

class SensorApp:
    def __init__(self, root, config_path=CONFIG_PATH):
        self.root = root
        self.root.title("Sensor Editor")

        # Load configuration
        try:
            with open(config_path) as f:
                config = json.load(f)
        except Exception as e:
            raise FileNotFoundError(f"Could not load config.json at {config_path}: {e}")

        # Target script name
        tgt_name = config.get('tgt_name')
        if not tgt_name:
            raise KeyError("'tgt_name' must be defined in config.json")
        self.tgt_name = tgt_name  # store for path resolution

        # Compute repository scripts path
        config_dir = Path(config_path).parent
        project_root = config_dir.parent
        candidate_roots = [project_root, project_root.parent]
        self.rf_src = None
        for root in candidate_roots:
            candidate = root / 'scripts' / tgt_name
            if candidate.exists():
                self.rf_src = candidate
                break
        if self.rf_src is None:
            raise FileNotFoundError(f"Could not locate scripts/{tgt_name} in expected locations: {candidate_roots}")

        # Determine deployment target paths
        deploy_targets = config.get('deploy_targets', [])
        self.dest_paths = []  # Only update deployment targets, not the git source
        for target in deploy_targets:
            dest = target.get('dest')
            if dest:
                path = Path(dest)
                if path.exists():
                    self.dest_paths.append(path)
        if not self.dest_paths:
            raise FileNotFoundError("No valid 'dest' paths found in config.json deploy_targets")

        # Load icon
        possible_icons = []
        if getattr(sys, 'frozen', False):
            possible_icons.append(Path(sys.executable).with_name("sensors.ico"))
        else:
            possible_icons.append(Path(__file__).parent / "sensors.ico")
        for icon in possible_icons:
            if icon.exists():
                try:
                    self.root.iconbitmap(default=icon)
                    break
                except Exception as e:
                    print(f"[DEBUG] Could not set icon: {e}")

        self.controls = {}
        self.load_config()

    def load_config(self):
        possible_xml = [
            Path.cwd() / 'sensors.xml',
            Path.cwd().parent / 'sensors.xml'
        ]
        for xml_path in possible_xml:
            if xml_path.exists():
                break
        else:
            raise FileNotFoundError(f"Missing XML config; looked in: {possible_xml}")

        tree = ET.parse(xml_path)
        for group in tree.getroot().findall('Group'):
            frame = ttk.LabelFrame(self.root, text=group.get('name'))
            frame.pack(fill='x', padx=10, pady=5)
            for sensor in group.findall('Sensor'):
                self.add_sensor_control(frame, sensor)

        ttk.Button(self.root, text='Save All', command=self.save_all).pack(pady=10)

    def add_sensor_control(self, parent, sensor_elem):
        name = sensor_elem.get('name')
        label = sensor_elem.get('label', name)
        sensor_type = sensor_elem.get('type', 'number')
        multiplier = float(sensor_elem.get('multiplier', 1))
        unit = sensor_elem.get('unit', '')
        default = float(sensor_elem.get('default', 0))

        row = ttk.Frame(parent)
        row.pack(fill='x', padx=5, pady=2)
        ttk.Label(row, text=label, width=20).pack(side='left')

        value_var = tk.StringVar(value=str(default))

        if sensor_type == 'range':
            min_val = float(sensor_elem.get('min', 0))
            max_val = float(sensor_elem.get('max', 100))
            rounding = sensor_elem.get('round') == 'true'
            control = ttk.Scale(
                row,
                from_=min_val,
                to=max_val,
                orient='horizontal',
                command=lambda v, var=value_var, rnd=rounding: var.set(
                    f"{int(float(v))}" if rnd else f"{float(v):.2f}"))
            control.set(default)
            control.pack(side='left', fill='x', expand=True)
            ttk.Entry(row, textvariable=value_var, width=6).pack(side='left', padx=5)
        elif sensor_type == 'bool':
            control = ttk.Checkbutton(row, variable=value_var, onvalue='1', offvalue='0')
            value_var.set('1' if default else '0')
            control.pack(side='left')
        elif sensor_type == 'select':
            control = ttk.Combobox(row, textvariable=value_var, state='readonly')
            options = [opt.get('label') for opt in sensor_elem.findall('Option')]
            values = [opt.get('value') for opt in sensor_elem.findall('Option')]
            control['values'] = options
            value_map = dict(zip(options, values))
            reverse_map = dict(zip(values, options))
            display = reverse_map.get(str(default), options[0] if options else '')
            value_var.set(display)
            control.pack(side='left')
            self.controls[name] = (value_var, multiplier, sensor_type, value_map)
            return
        else:
            rounding = sensor_elem.get('round') == 'true'
            if rounding:
                value_var.set(str(int(default)))
            ttk.Entry(row, textvariable=value_var).pack(side='left', fill='x', expand=True)

        if unit:
            ttk.Label(row, text=unit).pack(side='left')

        self.controls[name] = (value_var, multiplier, sensor_type, None)

    def save_all(self):
        possible_xml = [
            Path.cwd() / 'sensors.xml',
            Path.cwd().parent / 'sensors.xml'
        ]
        for xml_path in possible_xml:
            if xml_path.exists():
                break
        else:
            raise FileNotFoundError(f"Missing XML config; looked in: {possible_xml}")

        tree = ET.parse(xml_path)
        rand_map = {sensor.get('name'): sensor.get('rand')
                    for group in tree.getroot().findall('Group')
                    for sensor in group.findall('Sensor')}

        for name, (var, mult, sensor_type, val_map) in self.controls.items():
            raw = var.get()
            try:
                if sensor_type == 'select' and val_map:
                    raw = val_map.get(raw, '0')
                numeric = float(raw) * mult

                rand_attr = rand_map.get(name)

                for dest in self.dest_paths:
                    # Include repository target as subfolder before sim/sensors
                    out_dir = dest / self.tgt_name / 'sim' / 'sensors'
                    out_dir.mkdir(parents=True, exist_ok=True)
                    out_path = out_dir / (name + SENSOR_FILE_EXT)
                    print(f"[DEBUG] Updating sensor '{name}' at path: {out_path}")
                    try:
                        with open(out_path, 'w') as f:
                            if rand_attr:
                                delta = numeric * float(rand_attr) / 100.0
                                low = int(numeric - delta)
                                high = int(numeric + delta)
                                f.write(f"return math.random({low}, {high})")
                            else:
                                f.write(f"return {numeric}")
                    except Exception as e:
                        print(f"[DEBUG] Failed to write {out_path}: {e}")
            except Exception as e:
                print(f"Error saving {name}: {e}")

if __name__ == '__main__':
    root = tk.Tk()
    app = SensorApp(root)
    root.mainloop()
