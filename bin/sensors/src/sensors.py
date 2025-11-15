import sys
import json
import xml.etree.ElementTree as ET
import tkinter as tk
from tkinter import ttk
from pathlib import Path
import os

SENSOR_FILE_EXT = ".lua"


class SensorApp:

    def __init__(self, root, config_path=None):
        self.root = root
        self.root.title("Sensor Editor")

        # The script layout is:
        #   GITREPO/bin/sensors/sensors.exe
        #   or GITREPO/bin/sensors/src/sensors.py
        # Sensors live under:
        #   GITREPO/simulator/<target>/scripts/rfsuite/sim/sensors

        # Fixed scripts subfolder name under each simulator target
        self.tgt_name = "rfsuite"

        # Auto-discover all simulator targets with a matching sensors folder
        self.dest_paths = self._discover_simulator_targets()

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

    def _discover_simulator_targets(self):
        """
        Discover all simulator targets that contain:
            ../../simulator/<target>/scripts/rfsuite/sim/sensors

        Returns a list of Path objects pointing to the 'scripts' folder
        for each matching simulator target.
        """
        if getattr(sys, "frozen", False):
            # Running as an .exe (PyInstaller)
            base_dir = Path(sys.executable).resolve().parent
        else:
            # Running as a .py script
            base_dir = Path(__file__).resolve().parent

        # From either src/ or sensors/, ../../simulator gives us GITREPO/simulator
        simulator_root = base_dir.parent.parent / "simulator"

        if not simulator_root.exists():
            raise FileNotFoundError(
                f"Simulator root not found at expected path: {simulator_root}"
            )

        dest_paths = []
        for target_dir in simulator_root.iterdir():
            if not target_dir.is_dir():
                continue

            scripts_dir = target_dir / "scripts"
            sensors_dir = scripts_dir / "rfsuite" / "sim" / "sensors"

            if sensors_dir.exists():
                print(f"[DEBUG] Found sensors dir: {sensors_dir}")
                dest_paths.append(scripts_dir)

        if not dest_paths:
            raise FileNotFoundError(
                f"No sensor folders found under: {simulator_root}/<target>/scripts/rfsuite/sim/sensors"
            )

        return dest_paths

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
            options = [opt.get('label')
                       for opt in sensor_elem.findall('Option')]
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
