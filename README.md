# RFSUITE Lua Scripts for Ethos

[Rotorflight](https://github.com/rotorflight) is a Flight Control software suite designed for
single-rotor helicopters. It consists of:

- Rotorflight Flight Controller Firmware
- Rotorflight Configurator, for flashing and configuring the flight controller
- Rotorflight Blackbox Explorer, for analyzing blackbox flight logs
- Rotorflight Lua Scripts, for configuring the flight controller using a transmitter running:
  - EdgeTX/OpenTX
  - Ethos (this repository)

Built on Betaflight 4.3, Rotorflight incorporates numerous advanced features specifically
tailored for helicopters. It's important to note that Rotorflight does _not_ support multi-rotor
crafts or airplanes; it's exclusively designed for RC helicopters.

This version of Rotorflight is also known as **Rotorflight 2** or **RF2**.


## Information

Tutorials, documentation, and flight videos can be found on the [Rotorflight website](https://www.rotorflight.org/).


## Features

Rotorflight has many features:

* Many receiver protocols: CRSF, S.BUS, F.Port, DSM, IBUS, XBUS, EXBUS, GHOST, CPPM
* Support for various telemetry protocols: CSRF, S.Port, HoTT, etc.
* ESC telemetry protocols: BLHeli32, Hobbywing, Scorpion, Kontronik, OMP Hobby, ZTW, APD, YGE
* Advanced PID control tuned for helicopters
* Stabilisation modes (6D)
* Rotor speed governor
* Motorised tail support with Tail Torque Assist (TTA, also known as TALY)
* Remote configuration and tuning with the transmitter
  - With knobs / switches assigned to functions
  - With Lua scripts on EdgeTX, OpenTX and Ethos
* Extra servo/motor outputs for AUX functions
* Fully customisable servo/motor mixer
* Sensors for battery voltage, current, BEC, etc.
* Advanced gyro filtering
  - Dynamic RPM based notch filters
  - Dynamic notch filters based on FFT
  - Dynamic LPF
* High-speed Blackbox logging

Plus lots of features inherited from Betaflight:

* Configuration profiles for changing various tuning parameters
* Rates profiles for changing the stick feel and agility
* Multiple ESC protocols: PWM, DSHOT, Multishot, etc.
* Configurable buzzer sounds
* Multi-color RGB LEDs
* GPS support

And many more...


## Lua Scripts Requirements

- Ethos 1.5.16 or later
- an X10, X12, X14, X18, X20 or Twin X Lite transmitter
- a FrSky Smartport or F.Port receiver using ACCESS, ACCST, TD or TW mode
- a ELRS Module supported by Ethos


## Tested Receivers

The following receivers were correctly working with an X18 or X20, X10, XLite and X14 transmitter.
- TWMX
- TD MX
- R9 MX ACCESS 
- R9 Mini ACCESS 
- Archer RS ACCESS
- RX6R ACCESS 
- R-XSR ACCESS
- R-XSR ACCST FCC F.port 
- Archer Plus RS and Archer Plus RS Mini ACCESS F.Port 
- ELRS (all versions)


## Installation

Download the latest files (click *Code* and then *Download ZIP*.  Install the zip file using ethos suite. (lua tools)

## Telemetry Sensors
The below sensors are a good starting point when using rfsuite

```
ELRS
set crsf_telemetry_mode = CUSTOM
set crsf_telemetry_sensors = 3,4,5,61,50,51,52,60,99,93,6,95,96,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

FPORT
set telemetry_enable_voltage = ON
set telemetry_enable_current = ON
set telemetry_enable_fuel = ON
set telemetry_enable_mode = ON
set telemetry_enable_esc_current = ON
set telemetry_enable_esc_voltage = ON
set telemetry_enable_esc_rpm = ON
set telemetry_enable_esc_temperature = ON
set telemetry_enable_temperature = ON
set telemetry_enable_cap_used = ON
set telemetry_enable_adjustment = ON
set telemetry_enable_gov_mode = ON
set telemetry_enable_model_id = ON
set telemetry_enable_pid_profile = ON
set telemetry_enable_rates_profile = ON
set telemetry_enable_bec_voltage = ON
set telemetry_enable_headspeed = ON
set telemetry_enable_tailspeed = ON
set telemetry_enable_throttle_control = ON
set telemetry_enable_arming_flags = ON
```

## Contributing

Rotorflight is an open-source community project. Anybody can join in and help to make it better by:

* Helping other users on Rotorflight Discord or other online forums
* [Reporting](https://github.com/rotorflight?tab=repositories) bugs and issues, and suggesting improvements
* Testing new software versions, new features and fixes; and providing feedback
* Participating in discussions on new features
* Create or update content on the [Website](https://www.rotorflight.org)
* [Contributing](https://www.rotorflight.org/docs/Contributing/intro) to the software development - fixing bugs, implementing new features and improvements
* [Translating](https://www.rotorflight.org/docs/Contributing/intro#translations) Rotorflight Configurator into a new language, or helping to maintain an existing translation


## Origins

Rotorflight is software that is **open source** and is available free of charge without warranty.

Rotorflight is forked from [Betaflight](https://github.com/betaflight), which in turn is forked from [Cleanflight](https://github.com/cleanflight).
Rotorflight borrows ideas and code also from [HeliFlight3D](https://github.com/heliflight3d/), another Betaflight fork for helicopters.

Big thanks to everyone who has contributed along the journey!


## Contact

Team Rotorflight can be contacted by email at rotorflightfc@gmail.com.
