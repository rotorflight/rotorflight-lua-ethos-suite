# Creating a New API for MSP

## Overview
This project uses the **Multiwii Serial Protocol (MSP)** for data communication. Each API module is responsible for handling a specific MSP command by implementing `read()` and/or `write()` functions.

To create a new API module, follow the guidelines below.

---

## File Structure
API modules are stored in:
```
api/
  MSP_<NAME>.lua  # Individual API modules
api/templates/
  TEMPLATE_READ.lua   # Template for read-only APIs
  TEMPLATE_WRITE.lua  # Template for write-enabled APIs
```

Each API module should have:
- **A license header** (copy from an existing API file).
- **A `read()` function** (for reading MSP data).
- **A `write()` function** (if modifying MSP data is needed).
- **Clear documentation inside the file**.

---

## Creating a New API

1. **Choose a Template**
   - Use `TEMPLATE_READ.lua` if the API only retrieves data.
   - Use `TEMPLATE_WRITE.lua` if the API also modifies settings.

2. **Copy and Rename**
   ```sh
   cp api/templates/TEMPLATE_READ.lua api/MSP_NEWFEATURE.lua
   ```
   Replace `NEWFEATURE` with the actual MSP feature name.

3. **Modify the File**
   - Update the **header comments**.
   - Implement the `read()` function:
     ```lua
     function read()
         -- Send an MSP request and process the response
     end
     ```
   - If needed, implement the `write()` function:
     ```lua
     function write(data)
         -- Send an MSP command with `data` to modify settings
     end
     ```
   - Define **MSP command codes** for your feature.

4. **Register the New API**
   - Ensure it is properly included in the system where APIs are loaded.

5. **Test Your API**
   - Call `read()` and `write()` with expected inputs.
   - Debug any errors in MSP communication.

---

## Example API Implementation
### Read-Only API (`MSP_EXAMPLE.lua`)
```lua
-- Example API for MSP
function read()
    local response = sendMSP(MSP_CODE_EXAMPLE)
    return parseResponse(response)
end
```

### Write API (`MSP_SET_EXAMPLE.lua`)
```lua
function write(data)
    sendMSP(MSP_CODE_EXAMPLE_SET, data)
end
```

---

## Additional Notes
- **Ensure API names follow `MSP_<NAME>.lua` convention.**
- **Check MSP command definitions** in the system documentation.
- **Use debug logs** to verify MSP request/response flow.

For more details, refer to the existing API files in `api/`.
