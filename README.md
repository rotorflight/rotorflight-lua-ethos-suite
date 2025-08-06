
![Rotorflight](https://github.com/rotorflight/rotorflight/blob/master/images/rotorflight2.png?raw=true)

# RFSuite Lua Scripts for Ethos

**Rotorflight** is a powerful flight control software suite built specifically for **single-rotor RC helicopters**. It is not designed for multirotors or airplanes. The software includes:

-   **Rotorflight Flight Controller Firmware**
    
-   **Rotorflight Configurator** – used for flashing and configuring the flight controller
    
-   **Rotorflight Blackbox Explorer** – for analyzing flight logs
    
-   **Rotorflight Lua Scripts** – used to configure the flight controller directly from your transmitter
    

These scripts support the following transmitter operating systems:

-   **EdgeTX / OpenTX**
    
-   **Ethos** (this repository)
    

Rotorflight is based on **Betaflight 4.3**, but includes a wide range of advanced features optimized for helicopter flight. This version of Rotorflight is also referred to as **Rotorflight 2 (RF2)**.

----------

## What is RFSuite?

**RFSuite** is a touch-based, Lua-scripted GUI suite for the Ethos platform. It enables easy setup, tuning, and diagnostics of Rotorflight-based helicopters using supported FrSky transmitters. It offers:

-   Full touchscreen interface
    
-   FrSky and ELRS receiver compatibility
    
-   Multiple embedded tools and widgets
    

You can preview the experience using the interactive simulator:

👉 [**Launch Web Simulator**](https://ethos.studio1247.com/nightly16/X20PRO_FCC?backup=https://github.com/rotorflight/rotorflight-lua-ethos-suite/raw/refs/heads/master/demo/DEMO.zip&reset=all&language=en)

This opens the RFSuite in your browser, showcasing its functionality within the Ethos UI.

### Key UI Screens

**Status Widget**  
![Status](https://raw.githubusercontent.com/rotorflight/rotorflight-lua-ethos-suite/master/.github/gfx/status.png)

**Flight Logs**  
![Flight Logs](https://raw.githubusercontent.com/rotorflight/rotorflight-lua-ethos-suite/master/.github/gfx/logs.png)

**FBL Configuration (Home)**  
![FBL Config](https://raw.githubusercontent.com/rotorflight/rotorflight-lua-ethos-suite/master/.github/gfx/home.png)

**Governor Configuration**  
![Governor Config](https://raw.githubusercontent.com/rotorflight/rotorflight-lua-ethos-suite/master/.github/gfx/gov.png)

----------

## Rotorflight Features

Rotorflight includes a rich feature set, including:

### Protocol Support

-   Receiver: CRSF, S.BUS, F.Port, DSM, IBUS, XBUS, EXBUS, GHOST, CPPM
    
-   Telemetry: CRSF, S.Port, HoTT, and more
    
-   ESC telemetry: BLHeli32, Hobbywing, Scorpion, Kontronik, OMP Hobby, ZTW, APD, YGE
    

### Helicopter-Specific Features

-   Advanced PID control tuned for helicopters
    
-   Rotor speed governor
    
-   Stabilization modes (6D)
    
-   Tail Torque Assist (TTA or TALY)
    
-   Motorized tail support
    

### Remote Tuning & Configuration

-   Via transmitter knobs/switches
    
-   Lua script interface on EdgeTX/OpenTX/Ethos
    

### Additional Capabilities

-   AUX outputs for custom motor/servo functions
    
-   Fully customizable mixer
    
-   Sensor support: voltage, current, BEC, etc.
    
-   Advanced filtering: Dynamic RPM notch, FFT-based notch, and LPF
    
-   High-speed Blackbox logging
    

### Plus Betaflight-Inherited Features:

-   Multiple configuration and rate profiles
    
-   DSHOT, PWM, Multishot ESC protocols
    
-   RGB LEDs and buzzers
    
-   GPS integration
    

----------

## Lua Script Requirements

To use RFSuite, you'll need:

-   **Ethos 1.6.2 or later**
    
-   A compatible FrSky transmitter:
    
    -   X10, X12, X14, X18, X20, or Twin X Lite
        
-   A supported receiver:
    
    -   FrSky (Smartport or F.Port over ACCESS, ACCST, TD, TW)
        
    -   ExpressLRS (ELRS) modules supported by Ethos
        

----------

## Verified Compatible Receivers

RFSuite has been successfully tested on the following receiver models (with X10, X14, X18, X20, XLite):

-   TWMX
    
-   TD MX
    
-   R9 MX ACCESS
    
-   R9 Mini ACCESS
    
-   Archer RS / Archer Plus RS / RS Mini (ACCESS / F.Port)
    
-   RX6R ACCESS
    
-   R-XSR ACCESS / ACCST F.Port
    
-   ELRS (all versions)
    

----------

## Development Guide

To build and deploy RFSuite locally:

### Requirements

-   FrSky Simulator (Ethos)
    
-   Visual Studio Code (VS Code)
    
-   Python 3
    
-   Install tqdm and serial:
    
    ```bash
    pip install tqdm
    pip install serial
    ```

-- Install luamin

   ```bash
   npm install luamin
   ```

If you do not have npm command, you will need to install NodeJS   

### Config file

Copy the file bin/config-example.json to a folder outside of github and name to suite your preference.

Setup en env var of RFSUITE_CONFIG=C:\GitHub\rotorflight-lua-ethos-suite.json  (the path to the file)

Suggested:
Repo:  C:\GitHub\rotorflight-lua-ethos-suite\<files>
Config: C:\GitHub\rotorflight-lua-ethos-suite.json


### VS Code Tasks

-   **Deploy & Launch** – Pushes scripts to the default simulator

-   **Deploy & Launch [minify]** – Pushes scripts to the default simulator and minifies the files using luamin

-   **Deploy & Choose** – Pushes scripts to the selected simulator 

-   **Deploy & Choose [minify]** – Pushes scripts to the selected simulator and minifies the files using luamin
    
-   **Deploy Radio** – Pushes scripts to the radio

-   **Deploy Radio [minify]** – Pushes scripts to the radio and minifies the files using luamin
    

----------

## Installation Instructions

1.  Download the latest files:
    
    -   Click **Code** > **Download ZIP**
        
2.  Install using the Ethos Suite Lua Tools on your transmitter.
    

----------

## Contributing

Rotorflight is a community-driven open-source project. You can contribute by:

-   Helping users on [Rotorflight Discord](https://discord.com/) or forums
    
-   Reporting issues or requesting features via [GitHub](https://github.com/rotorflight)
    
-   Testing and giving feedback on new versions
    
-   Updating documentation and tutorials on the [Rotorflight Website](https://www.rotorflight.org/)
    
-   Translating the configurator to other languages
    
-   Contributing code (fixes, features, enhancements)
    

🔧 See the full [Contributing Guide](https://www.rotorflight.org/docs/Contributing/intro)

----------

## Project Origins

Rotorflight is **open source** and available free of charge, with no warranties.

-   Forked from [Betaflight](https://github.com/betaflight)
    
-   Which was forked from [Cleanflight](https://github.com/cleanflight)
    
-   Also draws inspiration and code from [HeliFlight3D](https://github.com/heliflight3d/)
    

🙏 A big thank you to everyone who has contributed along the way!

----------

## Contact

📧 Reach out to the Rotorflight team at:  
**[rotorflightfc@gmail.com](mailto:rotorflightfc@gmail.com)**


## Donate

If you find Rotorflight useful, please consider [supporting the development by donating](https://www.paypal.com/donate/?hosted_button_id=LLP4MT8C8TPVJ) to the Rotorflight Project.