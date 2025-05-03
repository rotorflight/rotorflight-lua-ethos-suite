# 2.2.0-RC4

Release candidate version for 2.2.0-RC4 Rotorflight

- prevent msp sensors when armed
- improve cpu load of bgtask (spread scheduling)

# 2.2.0-RC3

Release candidate version for 2.2.0-RC3 Rotorflight

- Various minor bug fixes
- Improved i18n functions
- blackbox status widget
- arm status widget
- disarm flags widget
- msp sensor framework
- small fixes to improve speed of connect/reconnect
- added italian translation & audio

# 2.2.0-RC2

No changes as not released with firmware

# 2.2.0-RC1

Release candidate version for 2.2.0-RC1 Rotorflight

 - Total rewrite of framework to use an API driven model.
    - Ability to easily build modules/pages with data from multiple msp calls.
    - Dynamic detection and creation of modules, tasks and widgets.
    - VSCode integration for easier development/debugging.

 - Dropped support of ethos less than version 1.6.2  
    - This was done to remove legacy code bloat and generally improve performance.

 - New features
    - Improved messaging and detection of RF module state.
        - Alert if RF module not enabled.
        - Alert if sensors not discovered.
    - ESC / Motor Config Tool
    - Log Tool
    - Battery Config Tool
    - Radio Config Tool
    - Sensor Check and Reset 
    - New ESC FWD Programing
        - XDFly 
    - SBUS Out configuration
    - Added framework to handle MSP Sensors for slow async msp queries
    - Automatic Sensor Creation for 'custom sensors'
    - ADJ Function fixes for ELRS protocol
    - New Widgets
        - Governor
        - Craftname
        - Craftimage
    - i18n support
        - English
        - German
        - Dutch
        - Spanish
    - Additional Radio support
        - Kavan V20
        - X18RS
        - X20RS
    - FBL Support
        - RF2.1 -> RF2.2 (RF2.0 will work; but is not as well tested)
    - Improved Debug Logging

## Instructions

For instructions and other details, please read the [README]
(https://github.com/rotorflight/rotorflight-lua-ethos-suite/tree/release/2.2.0-RC1).

## Downloads

The download locations are:

- [Rotorflight Configurator](https://github.com/rotorflight/rotorflight-configurator/releases/tag/release/2.2.0-RC1)
- [Rotorflight Blackbox](https://github.com/rotorflight/rotorflight-blackbox/releases/tag/release/2.2.0-RC1)
- [Lua Scripts for EdgeTx and OpenTx](https://github.com/rotorflight/rotorflight-lua-scripts/releases/tag/release/2.2.0-RC1)
- [Lua Scripts for FrSky Ethos](https://github.com/rotorflight/rotorflight-lua-ethos/releases/tag/release/2.2.0-RC1)
- [Lua Suite for FrSky Ethos](https://github.com/rotorflight/rotorflight-lua-ethos-suite/releases/tag/release/2.2.0-RC1)

***

# 2.1.1

Release version for 2.1.1 Rotorflight

- Ethos 1.6 version detection fix

## Instructions

For instructions and other details, please read the [README]
(https://github.com/rotorflight/rotorflight-lua-ethos-suite/tree/release/2.1.1).

## Downloads

The download locations are:

- [Rotorflight Configurator](https://github.com/rotorflight/rotorflight-configurator/releases/tag/release/2.1.1)
- [Rotorflight Blackbox](https://github.com/rotorflight/rotorflight-blackbox/releases/tag/release/2.1.1)
- [Lua Scripts for EdgeTx and OpenTx](https://github.com/rotorflight/rotorflight-lua-scripts/releases/tag/release/2.1.1)
- [Lua Scripts for FrSky Ethos](https://github.com/rotorflight/rotorflight-lua-ethos/releases/tag/release/2.1.1)
- [Lua Suite for FrSky Ethos](https://github.com/rotorflight/rotorflight-lua-ethos-suite/releases/tag/release/2.1.1)

***

# 2.1.0

Release version for 2.1.0 Rotorflight

- Ethos 1.6 support
- X18RS support
- Various minor bug fixes

## Instructions

For instructions and other details, please read the [README]
(https://github.com/rotorflight/rotorflight-lua-ethos-suite/tree/release/2.1.0).

## Downloads

The download locations are:

- [Rotorflight Configurator](https://github.com/rotorflight/rotorflight-configurator/releases/tag/release/2.1.0)
- [Rotorflight Blackbox](https://github.com/rotorflight/rotorflight-blackbox/releases/tag/release/2.1.0)
- [Lua Scripts for EdgeTx and OpenTx](https://github.com/rotorflight/rotorflight-lua-scripts/releases/tag/release/2.1.0)
- [Lua Scripts for FrSky Ethos](https://github.com/rotorflight/rotorflight-lua-ethos/releases/tag/release/2.1.0)
- [Lua Suite for FrSky Ethos](https://github.com/rotorflight/rotorflight-lua-ethos-suite/releases/tag/release/2.1.0)

***

# 2.1.0-RC2

This is the _second Release Candidate_ of the Rotorflight 2.1 RFSUITE LUA Scripts for FrSky Ethos.

- Improved ELRS GPS Sensor Support
- Add Governor Min Throttle
- Adjust Cyclic Cross coupling display based on version of RF in use on fbl
- Fixed bug in progress dialog when switching profiles

***

# 2.1.0-RC1

This is the _first Release Candidate_ of the Rotorflight 2.1 RFSUITE LUA Scripts for FrSky Ethos.

## Instructions

For instructions and other details, please read the [README]
(https://github.com/rotorflight/rotorflight-lua-ethos-suite/tree/release/2.1.0-RC1).

## Downloads

The download locations are:

- [Rotorflight Configurator](https://github.com/rotorflight/rotorflight-configurator/releases/tag/release/2.1.0-RC1)
- [Rotorflight Blackbox](https://github.com/rotorflight/rotorflight-blackbox/releases/tag/release/2.1.0-RC1)
- [Lua Scripts for EdgeTx and OpenTx](https://github.com/rotorflight/rotorflight-lua-scripts/releases/tag/release/2.1.0-RC1)
- [Lua Scripts for FrSky Ethos](https://github.com/rotorflight/rotorflight-lua-ethos/releases/tag/release/2.1.0-RC1)
- [Lua Suite for FrSky Ethos](https://github.com/rotorflight/rotorflight-lua-ethos-suite/releases/tag/release/2.1.0-RC1)

## Notes

RFSUITE is a fully integrated single package install.

You get:

- RF2ETHOS (a touch screen enabled configuration tool to manage your fbl)
- RF2ELRSTELEMETRY (detects if you are running elrs and handles creation of custom elrs sensors)
- RF2FRSKYTELEMETRY (creates custom sensors and renames sensors to more usefull names to suite rotorflight)
- RF2ADJFUC (handles calling out the values set when using adjustment functions)
- RF2GOV (a simple widget that is able to display the governor status regardless of the telemetry source)
- RF2STATUS (a full featured widget that is customisable and enables end users to display and alert on all RF telemetry values that matter)

The system uses a single background service to handle all telemetry and MSP processing.

This service acts an orchestrator - and essentially handles MSP, TELEMETRY, SENSORS, ADJFUNCTIONS on a relatively light weight service.  It auto detects the protocol in use and then does
the rest to enable the APP and WIDGETS to talk to a simple interface per service that its platform agnostic. Essentially..  erls or fport.. its the same call to the service.

This has significant benifits in simplying code - and reducing the amount of duplicate code used between the various systems.


## Support

The main source of Rotorflight information and instructions is now the [website](https://www.rotorflight.org/).
Rotorflight has a strong presence on the Discord platform - you can join us [here](https://discord.gg/FyfMF4RwSA/).

Discord is the primary location for support, questions and discussions. The developers are all active there,
and so are the manufacturers of RF Flight Controllers. Many pro pilots are also there.

This is a great place to ask for advice or discuss any complicated problems or even new ideas.
There is also a [Rotorflight Facebook Group](https://www.facebook.com/groups/876445460825093) for hanging out with other Rotorflight pilots.