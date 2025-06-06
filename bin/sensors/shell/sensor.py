import os
import sys
import argparse
import re
from pathlib import Path

# --- Constants from environment variables ---
FRSKY_RFSUITE_GIT_SRC = os.environ.get('FRSKY_RFSUITE_GIT_SRC')
FRSKY_SIM_SRC = os.environ.get('FRSKY_SIM_SRC')

# --- Global sensor map ---
sensor_map = {}

# --- Helper functions ---

def validate_paths():
    if not FRSKY_RFSUITE_GIT_SRC or not Path(FRSKY_RFSUITE_GIT_SRC).exists():
        print(f"[ERROR] FRSKY_RFSUITE_GIT_SRC not set or invalid: {FRSKY_RFSUITE_GIT_SRC}")
        sys.exit(1)

    if not FRSKY_SIM_SRC:
        print(f"[ERROR] FRSKY_SIM_SRC not set.")
        sys.exit(1)

    # Handle CSV paths
    sim_paths = [p.strip() for p in FRSKY_SIM_SRC.split(',')]
    for path in sim_paths:
        if not Path(path).exists():
            print(f"[ERROR] FRSKY_SIM_SRC path invalid: {path}")
            sys.exit(1)

    return sim_paths

def parse_telemetry_lua():
    telemetry_file = Path(FRSKY_RFSUITE_GIT_SRC) / 'scripts' / 'rfsuite' / 'tasks' / 'telemetry' / 'telemetry.lua'
    if not telemetry_file.exists():
        print(f"[ERROR] telemetry.lua not found at {telemetry_file}")
        sys.exit(1)

    with telemetry_file.open('r', encoding='utf-8') as f:
        content = f.read()

    # Find all occurrences of simSensors('<sensorname>')
    matches = re.findall(r"simSensors\(['\"](.*?)['\"]\)", content)
    sensors = sorted(set(matches))
    for sensor in sensors:
        sensor_map[sensor] = []

    return sensors

def build_sensor_paths(sim_paths):
    for sensor in sensor_map.keys():
        for sim_base in sim_paths:
            sensor_file = Path(sim_base) / 'rfsuite' / 'sim' / 'sensors' / f"{sensor}.lua"
            sensor_map[sensor].append(sensor_file)


def list_sensors():
    print("Sensors found:")
    for sensor in sensor_map:
        print(f"- {sensor}")

def update_sensor(sensor, content):
    if sensor not in sensor_map:
        print(f"[ERROR] Sensor '{sensor}' not found.")
        sys.exit(1)

    for filepath in sensor_map[sensor]:
        filepath.parent.mkdir(parents=True, exist_ok=True)
        with filepath.open('w', encoding='utf-8') as f:
            f.write(content + "\n")
        print(f"[OK] Updated {filepath}")


def main():
    parser = argparse.ArgumentParser(description="Sensor updater CLI tool.")
    subparsers = parser.add_subparsers(dest='command')

    subparsers.add_parser('list', help='List available sensors.')

    value_parser = subparsers.add_parser('value', help='Set fixed value for a sensor.')
    value_parser.add_argument('sensor', type=str)
    value_parser.add_argument('value', type=float)

    range_parser = subparsers.add_parser('range', help='Set random range for a sensor.')
    range_parser.add_argument('sensor', type=str)
    range_parser.add_argument('min', type=float)
    range_parser.add_argument('max', type=float)

    subparsers.add_parser('help', help='Show help message.')

    args = parser.parse_args()

    if args.command == 'help' or args.command is None:
        parser.print_help()
        sys.exit(0)

    sim_paths = validate_paths()
    parse_telemetry_lua()
    build_sensor_paths(sim_paths)

    if args.command == 'list':
        list_sensors()

    elif args.command == 'value':
        content = f"return {args.value}"
        update_sensor(args.sensor, content)

    elif args.command == 'range':
        content = f"return math.random({int(args.min)}, {int(args.max)})"
        update_sensor(args.sensor, content)

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
