import os
import sys
import re
import json

# Define the directories
API_DIR = "scripts/rfsuite/tasks/msp/api"
MODULE_DIR = "scripts/rfsuite/app/modules"

# ✅ Configurable list of parameters to transfer from module to API
TRANSFERRED_PARAMS = ["default", "decimals", "scale", "unit","min","max","step"]  # Modify this as needed

def find_module_file(module_folder, api_name):
    """Find the module file that contains the specified API name, allowing for varied spacing."""
    module_path = os.path.join(MODULE_DIR, module_folder)
    api_pattern = re.compile(r'mspapi\s*=\s*"?{}"?'.format(re.escape(api_name)))  # Allow variations

    for root, _, files in os.walk(module_path):
        for file in files:
            if file.endswith(".lua"):
                file_path = os.path.join(root, file)
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()
                    if api_pattern.search(content):  # Use regex to match regardless of spaces
                        return file_path
    return None

def extract_fields(module_file):
    """Extract fields with apikey from the module file."""
    fields = []
    field_pattern = re.compile(r'fields\[#fields \+ 1\] = \{([^}]+)\}')
    key_value_pattern = re.compile(r'(\w+)\s*=\s*(?:(\d+\.\d+|\d+)|"(.*?)")')

    with open(module_file, "r", encoding="utf-8") as f:
        content = f.read()

    matches = field_pattern.findall(content)
    for match in matches:
        field_data = {}
        key_values = key_value_pattern.findall(match)
        for key, num_value, str_value in key_values:
            if str_value:
                field_data[key] = str_value  # Keep strings unchanged
            elif num_value:
                field_data[key] = float(num_value) if "." in num_value else int(num_value)  # Convert numbers properly
        if "apikey" in field_data:
            fields.append(field_data)

    return fields

def update_api_file(api_file, fields_data):
    """Update API file by adding new field parameters based on apikey while keeping existing ones."""
    with open(api_file, "r", encoding="utf-8") as f:
        content = f.readlines()

    updated_content = []
    field_pattern = re.compile(r'(\{field\s*=\s*"([^"]+)",\s*type\s*=\s*"([^"]+)"[^}]*})')

    for line in content:
        match = field_pattern.search(line)
        if match:
            field_dict = match.group(1)
            field_name = match.group(2)

            for field in fields_data:
                if field.get("apikey") == field_name:
                    extra_params = {k: v for k, v in field.items() if k in TRANSFERRED_PARAMS}

                    # Preserve simResponse if it exists
                    sim_response_match = re.search(r'simResponse\s*=\s*\{([^}]*)\}', field_dict)
                    if sim_response_match:
                        sim_response_content = sim_response_match.group(0)  # Keep it unchanged
                        new_field_dict = field_dict.replace(sim_response_content, f"{sim_response_content}, " + 
                                                            ", ".join(f'{k} = {json.dumps(v)}' for k, v in extra_params.items()))
                    else:
                        new_field_dict = field_dict[:-1] + f", " + ", ".join(f'{k} = {json.dumps(v)}' for k, v in extra_params.items()) + " }"

                    line = line.replace(field_dict, new_field_dict)
                    break

        updated_content.append(line)

    with open(api_file, "w", encoding="utf-8") as f:
        f.writelines(updated_content)

def remove_transferred_params(module_file, fields_data):
    """Remove only the transferred parameters from the module file while keeping the rest of the field intact."""
    with open(module_file, "r", encoding="utf-8") as f:
        content = f.readlines()

    updated_content = []
    field_pattern = re.compile(r'fields\[#fields \+ 1\] = \{([^}]+)\}')

    for line in content:
        match = field_pattern.search(line)
        if match:
            field_content = match.group(1)
            key_value_pattern = re.compile(r'(\w+)\s*=\s*(?:(\d+\.\d+|\d+)|"(.*?)")')

            # Extract key-value pairs
            key_values = key_value_pattern.findall(field_content)
            field_data = {k: v for k, v1, v2 in key_values for v in (v1, v2) if v}

            # Check if this field has an apikey that was transferred
            if "apikey" in field_data:
                for f in fields_data:
                    if field_data["apikey"] == f["apikey"]:
                        # Remove only the specified parameters
                        for param in TRANSFERRED_PARAMS:
                            field_data.pop(param, None)

                        # Rebuild the line without removed parameters
                        new_field_content = ", ".join(f'{k} = {json.dumps(v)}' for k, v in field_data.items())

                        # Remove quotes from numbers
                        new_field_content = re.sub(r'"(\d+)"', r'\1', new_field_content)

                        line = f'fields[#fields + 1] = {{{new_field_content}}}\n'
                        break

        updated_content.append(line)

    with open(module_file, "w", encoding="utf-8") as f:
        f.writelines(updated_content)

def main():
    if len(sys.argv) != 3:
        print("Usage: python bin/process_fields.py <API> <Module>")
        sys.exit(1)

    api_name = sys.argv[1]
    module_name = sys.argv[2]

    api_file = os.path.join(API_DIR, f"{api_name}.lua")
    if not os.path.exists(api_file):
        print(f"API file {api_file} not found!")
        sys.exit(1)

    module_file = find_module_file(module_name, api_name)
    if not module_file:
        print(f"No module file found for API {api_name} in {module_name}!")
        sys.exit(1)

    fields = extract_fields(module_file)
    if not fields:
        print("No matching fields found in module file.")
        sys.exit(0)

    update_api_file(api_file, fields)
    remove_transferred_params(module_file, fields)

    print(f"Fields ({TRANSFERRED_PARAMS}) successfully transferred while preserving existing data.")

if __name__ == "__main__":
    main()
