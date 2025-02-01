#!/bin/bash

####################################################################################
# MSP API Command Scanner
#
# This script scans two directories for specific Lua files:
#
# 1. It looks for `local MSP_API_CMD = <number>` in:
#    `../scripts/rfsuite/tasks/msp/api/*.lua`
#
# 2. It looks for `read = <number>` and `simulatorResponse = {...}` in:
#    `../scripts/rfsuite/app/modules/*/*.lua`
#
# 3. If a `read` number does not have a corresponding `MSP_API_CMD`, it reports:
#
#    - MSP Command Name (from GitHub `msp_protocol.h` file)
#    - MSP ID (read number)
#    - Folder name from `app/modules`
#    - Simulator Response array
#    - Number of elements in the Simulator Response (`MIN_BYTES`)
#    - Link to the relevant line in `msp.c`
#
# 4. The script fetches MSP command definitions from:
#    - https://github.com/rotorflight/rotorflight-firmware/blob/master/src/main/msp/msp_protocol.h
#    - https://github.com/rotorflight/rotorflight-firmware/blob/master/src/main/msp/msp.c
#
# Output Example:
#
#  MSP_COMMAND:   MSP_MIXER_CONFIG
#  MSP_ID:        42
#  FOLDER:        app/modules/trim
#  SIM RESPONSE:  {0, 1, 0, 0, 0, 2, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
#  MIN_BYTES:     19
#  COMMAND URL:   https://github.com/rotorflight/rotorflight-firmware/blob/master/src/main/msp/msp.c#L1333
#
# This script exists to identify missing READ API implementations.
#####################################################################################

# Define the directories
API_DIR="../scripts/rfsuite/tasks/msp/api"
MODULES_DIR="../scripts/rfsuite/app/modules"

# Define the URLs for MSP header and source files
MSP_PROTOCOL_URL="https://raw.githubusercontent.com/rotorflight/rotorflight-firmware/master/src/main/msp/msp_protocol.h"
MSP_SOURCE_URL="https://raw.githubusercontent.com/rotorflight/rotorflight-firmware/master/src/main/msp/msp.c"
MSP_GITHUB_URL="https://github.com/rotorflight/rotorflight-firmware/blob/master/src/main/msp/msp.c"

# Temporary files for storing extracted values
API_NUMBERS_FILE=$(mktemp)
MODULES_NUMBERS_FILE=$(mktemp)
MSP_DEFINES_FILE=$(mktemp)
MSP_SOURCE_FILE=$(mktemp)

# Fetch MSP define mappings from GitHub
echo "Fetching MSP define mappings from GitHub..."
curl -s "$MSP_PROTOCOL_URL" | grep -E "^#define MSP_[A-Z0-9_]+[[:space:]]+[0-9]+" > "$MSP_DEFINES_FILE"

# Fetch the MSP source file to find function line numbers
echo "Fetching MSP source file from GitHub..."
curl -s "$MSP_SOURCE_URL" > "$MSP_SOURCE_FILE"

# Extract MSP_API_CMD values from API files
echo "Scanning $API_DIR for MSP_API_CMD numbers..."
find "$API_DIR" -type f -name "*.lua" | while read -r file; do
    grep -E "local MSP_API_CMD *= *[0-9]+" "$file" | awk -F'=' '{print $2}' | tr -d ' ' >> "$API_NUMBERS_FILE"
done


# Extract read values and simulatorResponse lines from module files
echo "Scanning $MODULES_DIR for read numbers..."
find "$MODULES_DIR" -type f -name "*.lua" | while read -r file; do
    folder_name=$(dirname "$file" | sed "s|$MODULES_DIR/||")
    
    read_number=$(grep -Eo "read *= *[0-9]+" "$file" | awk -F'=' '{print $2}' | tr -d ' ')
    sim_response=$(grep -Eo "simulatorResponse *= *\{.*\}" "$file" | sed 's/simulatorResponse *= *//')

    if [[ -n "$read_number" ]]; then
        echo "$folder_name,$read_number,$sim_response" >> "$MODULES_NUMBERS_FILE"
    fi
done

# Check for missing matches and get MSP define name
echo "Checking for unmatched read numbers..."
while IFS=, read -r folder read_number sim_response; do
    if [[ "$folder" == *"esc/mfg/"* ]]; then
        continue  # Skip this iteration if the folder contains "esc/mfg/"
    fi

    if ! grep -q "^$read_number$" "$API_NUMBERS_FILE"; then
        # Find matching define name for the read number
        define_name=$(grep -E "[[:space:]]+$read_number$" "$MSP_DEFINES_FILE" | awk '{print $2}')
        
        if [[ -z "$define_name" ]]; then
            define_name="UNKNOWN"
            continue
        fi

        # Skip displaying output if the corresponding Lua file exists in API_DIR
        if [[ -f "$API_DIR/$define_name.lua" ]]; then
            continue
        fi

        # Count elements in the simulatorResponse array
        min_bytes=$(echo "$sim_response" | grep -oE "[0-9]+" | wc -l)

        # Find the line number in msp.c where the command is handled
        line_number=$(grep -n "$define_name" "$MSP_SOURCE_FILE" | awk -F: '{print $1}' | head -n 1)
        if [[ -n "$line_number" ]]; then
            command_url="$MSP_GITHUB_URL#L$line_number"
        else
            command_url="Not Found"
        fi

        # Display the formatted output
        echo "  MSP_COMMAND:   $define_name"
        echo "  MSP_ID:        $read_number"
        echo "  FOLDER:        app/modules/$folder"
        echo "  SIM RESPONSE:  $sim_response"
        echo "  MIN_BYTES:     $min_bytes"
        echo "  COMMAND URL:   $command_url"
        echo " "
    fi
done < "$MODULES_NUMBERS_FILE"



# Clean up temp files
rm -f "$API_NUMBERS_FILE" "$MODULES_NUMBERS_FILE" "$MSP_DEFINES_FILE" "$MSP_SOURCE_FILE"
