This PR adds firmware-side SmartFuel telemetry generation so SmartFuel values can be computed directly on the FBL instead of in the app layer.

## What does SmartFuel do?

SmartFuel provides an intelligent remaining-fuel percentage for the flight pack, derived either from measured current consumption or from voltage-based estimation when no current sensor is available.

This PR also adds a native Smart Consumption telemetry value so the FBL can report consumed mAh alongside SmartFuel.

## What's included

- New internal telemetry sensor: `BATTERY_SMARTFUEL`
- New internal telemetry sensor: `BATTERY_SMARTCONSUMPTION`
- Native SmartPort custom sensor output for SmartFuel
- Native SmartPort custom sensor output for Smart Consumption
- Native CRSF custom sensor output for SmartFuel
- Native CRSF custom sensor output for Smart Consumption
- `smartfuel_source` config to choose:
  - `CURRENT`
  - `VOLTAGE`
- `smartfuel_params` config for SmartFuel tuning
- MSP read/write support for SmartFuel config
- Compile-time gating behind `USE_SMARTFUEL`

## Design notes

- SmartFuel can estimate remaining usable fuel either from pack consumption/current sensing or from voltage-only behavior when no current sensor is available.
- Both `CURRENT` and `VOLTAGE` modes now use the same sigmoid-based voltage seed to estimate initial usable fuel.
- SmartFuel is defined against usable pack capacity above reserve, so `0%` is reached at the configured reserve threshold rather than at absolute cell-empty.
- Smart Consumption is exported alongside SmartFuel:
  - In `CURRENT` mode it mirrors measured consumed mAh.
  - In `VOLTAGE` mode it tracks a virtual consumed-mAh state derived from stabilized pack voltage and configured usable pack capacity.
- In `VOLTAGE` mode, SmartFuel is seeded from stabilized preflight voltage and then drains through the tracked virtual-consumption model rather than refilling from instantaneous voltage rebound.
- Sensor naming is aligned with existing battery telemetry conventions:
  - `TLM_SENSOR(BATTERY_SMARTFUEL, ...)`
  - `TELEM_BATTERY_SMARTFUEL`
  - `TLM_SENSOR(BATTERY_SMARTCONSUMPTION, ...)`
  - `TELEM_BATTERY_SMARTCONSUMPTION`
- Protocol IDs use direct/native protocol-specific IDs:
  - SmartPort:
    - SmartFuel: `0x5251`
    - Smart Consumption: `0x5252`
  - CRSF:
    - SmartFuel: `0x1015`
    - Smart Consumption: `0x1016`

## CLI

```text
set smartfuel_source = CURRENT|VOLTAGE
set smartfuel_params = 1500,15,5,10,70
```

`smartfuel_params` order:

1. `stabilize_delay_ms`
2. `stable_window_centi_volts`
3. `voltage_fall_centi_volts_per_sec`
4. `fuel_drop_tenths_percent_per_sec`
5. `sag_multiplier_percent`

Notes:
- The first two parameters apply in both `CURRENT` and `VOLTAGE` modes.
- The remaining three parameters are only used in `VOLTAGE` mode.
- `fuel_rise_rate` has been removed. In `VOLTAGE` mode, SmartFuel no longer refills in flight from voltage rebound.
- Zero-valued SmartFuel parameters are now honored correctly instead of falling back to defaults.

## Usage

Current-sensor setups should normally use:

```text
set smartfuel_source = CURRENT
```

Voltage-only setups can use:

```text
set smartfuel_source = VOLTAGE
set smartfuel_params = 1500,15,5,10,70
```

In general:

- `CURRENT` is preferred when a calibrated current sensor is available.
- `VOLTAGE` is intended for setups without a current sensor.
- Start with the default parameters and tune gradually based on startup stabilization, response under load, and how quickly SmartFuel drains in flight.
- A fuller tuning guide is available in `docs/SmartFuel.md`.

## MSP

- `MSP2_GET_SMARTFUEL_CONFIG = 0x3006`
- `MSP2_SET_SMARTFUEL_CONFIG = 0x3007`

MSP field order:

1. `smartfuel_source`
2. `stabilize_delay`
3. `stable_window`
4. `voltage_fall_limit`
5. `fuel_drop_rate`
6. `sag_multiplier_percent`

