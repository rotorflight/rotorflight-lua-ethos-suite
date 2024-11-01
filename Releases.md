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
