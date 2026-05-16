# SmartFuel Telemetry

This document describes how RF Suite handles SmartFuel telemetry, how the real
receiver telemetry sensors map into the suite's virtual sensors, and when values
come from firmware versus local calculations.

## Sensor Summary

RF Suite exposes two suite-owned virtual sensors:

| Suite sensor | App ID | Unit | Purpose |
| --- | ---: | --- | --- |
| Smart Fuel | `0x5FE1` | `%` | Normalized usable fuel/charge percentage for dashboard widgets, callouts, and stats. |
| Smart Consumption | `0x5FE0` | `mAh` | Normalized consumed capacity value paired with Smart Fuel. |

These are local Ethos DIY sensors created by RF Suite. They are not FC telemetry
configuration slots. The FC still needs to transmit the underlying real battery
sensors that RF Suite mirrors or uses as calculation inputs.

## Protocol Mappings

### CRSF / ELRS

| Real sensor seen by Ethos | Meaning | RF Suite virtual output |
| --- | --- | --- |
| `[0x1014] Charge Level` | Firmware charge/fuel percentage | `[0x5FE1] Smart Fuel` |
| `[0x1013] Consumption` | Firmware consumed mAh | `[0x5FE0] Smart Consumption` |

### FBus / S.Port

| Real sensor seen by Ethos | Meaning | RF Suite virtual output |
| --- | --- | --- |
| `[0x0600] Fuel` | Firmware charge/fuel percentage | `[0x5FE1] Smart Fuel` |
| `[0x5250] Consumption` | Firmware consumed mAh | `[0x5FE0] Smart Consumption` |

On CRSF/ELRS the percentage sensor is named `Charge Level`. On FBus/S.Port the
same semantic value is exposed as `Fuel`. RF Suite normalizes both into
`Smart Fuel`.

`0x5250` is a FrSky custom/DIY S.Port app ID in the `0x5100..0x5FFE`
range. It is still a real FC-emitted telemetry value: Rotorflight sends
`BATTERY_CONSUMPTION` on `0x5250`, and RF Suite creates/discovers the Ethos
sensor named `Consumption` for that app ID. RF Suite's own `0x5FE0`
`Smart Consumption` sensor is the virtual wrapper that mirrors or derives from
that source.

Because `0x5250` is not a built-in FrSky sensor, RF Suite provisions it from the
FC telemetry configuration. Telemetry slot `5` maps to S.Port app ID `0x5250`;
when that slot is enabled, RF Suite creates an Ethos S.Port sensor with app ID
`0x5250` and the name `Consumption`. Once the sensor exists, Ethos can populate
it from incoming Rotorflight S.Port frames, and RF Suite can read it with
`system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5250})`.

## Telemetry Defaults

The telemetry configuration app applies defaults from sensors marked
`mandatory = true` or `default_telemetry_sensor = true`.

The SmartFuel source sensors are covered by defaults:

| Suite source | Telemetry slot | Default reason |
| --- | ---: | --- |
| Voltage | `3` | Mandatory |
| Current | `4` | Mandatory |
| Consumption | `5` | Mandatory |
| Fuel / Charge Level | `6` | Default telemetry sensor |

Protocol lookup tables map those FC telemetry slots to receiver IDs:

| Telemetry slot | CRSF / ELRS ID | FBus / S.Port ID |
| ---: | ---: | ---: |
| `5` Consumption | `0x1013` | `0x5250` |
| `6` Fuel / Charge Level | `0x1014` | `0x0600` |

`Smart Fuel` and `Smart Consumption` do not need to be selected in the FC
telemetry configuration. They are created locally by RF Suite after the source
sensors exist.

## Firmware SmartFuel Flow

Firmware SmartFuel is used when all of these are true:

- The connected firmware API is at least `12.09`.
- RF Suite can read `SMARTFUEL_CONFIG`.
- The firmware SmartFuel mode is not `OFF`.

Data flow:

```text
Firmware SmartFuel mode enabled
        |
        v
FC getBatteryChargeLevel()
        |
        v
Real telemetry percent sensor
  CRSF/ELRS:   [0x1014] Charge Level
  FBus/S.Port: [0x0600] Fuel
        |
        v
RF Suite mirrors raw percentage
        |
        v
[0x5FE1] Smart Fuel
```

For consumption in firmware mode:

```text
FC consumed mAh telemetry
  CRSF/ELRS:   [0x1013] Consumption
  FBus/S.Port: [0x5250] Consumption
        |
        v
RF Suite mirrors raw mAh
        |
        v
[0x5FE0] Smart Consumption
```

In firmware mode, RF Suite does not recalculate the source fuel percentage. It
mirrors the firmware value, then remaps the configured reserve/consumption
warning percentage to `0%` for the virtual Smart Fuel sensor.

## Local SmartFuel Flow

Local SmartFuel is used when firmware SmartFuel is unavailable or disabled and
RF Suite is configured to calculate SmartFuel locally.

Local calculations use the normal telemetry aggregator inputs, mainly:

- Pack voltage
- Cell count and battery configuration
- Current/consumption where available
- Local SmartFuel preferences

### Local Voltage Mode

In local voltage mode, RF Suite estimates remaining charge from voltage and
applies the local voltage SmartFuel model.

```text
Voltage telemetry + battery profile
        |
        v
Local SmartFuel voltage estimate
        |
        v
[0x5FE1] Smart Fuel
```

`Smart Consumption` is virtual in this mode:

```text
(initialChargeLevel - currentChargeLevel) * packCapacity
        |
        v
[0x5FE0] Smart Consumption
```

That value is derived from the local charge estimate, not from a real consumed
mAh sensor.

### Local Current Mode

In local current mode, RF Suite still anchors Smart Fuel from the local model,
but consumption is based on the real consumed mAh telemetry delta since the
local SmartFuel reset.

```text
Real Consumption - initial Consumption
        |
        v
[0x5FE0] Smart Consumption
```

So `Smart Consumption` is not a direct mirror in local current mode. It is based
on the real consumption sensor, but zeroed to the local SmartFuel session.

## Source Selection

RF Suite chooses the SmartFuel source in this order:

1. Firmware SmartFuel, when supported and enabled.
2. Local voltage SmartFuel, when the local SmartFuel source preference is
   voltage.
3. Local current SmartFuel, otherwise.

When the source mode changes, RF Suite resets SmartFuel state and republishes
the virtual sensors so widgets and callouts use the new data path cleanly.

## Alerts And Gauge Values

`Smart Fuel` is published as usable remaining percentage from the active source.
For electric models, the configured reserve/consumption warning percentage is
treated as empty and remapped to `0%`, because reaching reserve means the pilot
should land rather than continue discharging the pack.

For example, with a `30%` reserve, a raw source value of `30%` is published as
`0%` Smart Fuel, while a raw source value of `100%` is still published as
`100%`.

## Implementation Pointers

Important files:

| File | Role |
| --- | --- |
| `src/rfsuite/tasks/scheduler/sensors/smart.lua` | Creates `[0x5FE1] Smart Fuel` and `[0x5FE0] Smart Consumption`, mirrors firmware sensors, and selects local versus firmware mode. |
| `src/rfsuite/tasks/scheduler/sensors/lib/smartfuelvoltage.lua` | Local voltage/current SmartFuel calculation and virtual consumption calculation. |
| `src/rfsuite/tasks/scheduler/sensors/frsky_sid_lookup.lua` | Maps telemetry slot `5` to `0x5250` and slot `6` to `0x0600` for FBus/S.Port. |
| `src/rfsuite/tasks/scheduler/sensors/elrs_sid_lookup.lua` | Maps telemetry slot `5` to `0x1013` and slot `6` to `0x1014` for CRSF/ELRS. |
| `src/rfsuite/tasks/scheduler/telemetry/sources/sensor_table.lua` | Defines telemetry defaults and the public `fuel`, `consumption`, `smartfuel`, and `smartconsumption` source metadata. |
| `src/rfsuite/tasks/scheduler/events/tasks/telemetry.lua` | Handles SmartFuel callouts and the usable-fuel empty alert. |
