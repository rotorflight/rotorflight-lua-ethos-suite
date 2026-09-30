-- Small INI reader/writer shared by pages and tasks.

if package.loaded["rfsuite.lib.ini"] then
  return package.loaded["rfsuite.lib.ini"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local atomicWrite = requireModule("lib/atomic_write.lua")

local ini = {}

function ini.load_file_as_string(path)
  local file = io.open(path, "rb")
  if not file then return nil, "Cannot open file: " .. tostring(path) end

  local chunks = {}
  while true do
    local chunk = io.read(file, "L")
    if not chunk then break end
    chunks[#chunks + 1] = chunk
  end

  io.close(file)
  return table.concat(chunks)
end

local function parseLine(data, section, line)
  line = line:match("^%s*(.-)%s*$")

  if line == "" or line:sub(1, 1) == ";" then
    return section
  end

  if line:match("^%[.+%]$") then
    section = line:match("^%[(.+)%]$")
    if section then
      section = section:match("^%s*(.-)%s*$")
      section = tonumber(section) or section
      data[section] = data[section] or {}
    end
    return section
  end

  local param, value = line:match("^([%w_]+)%s-=%s-(.*)$")
  if param and value and section then
    param = tonumber(param) or param
    if value == "true" then
      value = true
    elseif value == "false" then
      value = false
    elseif tonumber(value) then
      value = tonumber(value)
    end
    data[section][param] = value
  end

  return section
end

function ini.load_ini_file(fileName)
  assert(type(fileName) == "string", 'Parameter "fileName" must be a string.')

  local file = io.open(fileName, "rb")
  if not file then return nil end

  local data = {}
  local section = nil

  while true do
    local line = io.read(file, "L")
    if not line then break end
    section = parseLine(data, section, line)
  end

  io.close(file)
  return data
end

function ini.save_ini_file(fileName, data)
  assert(type(fileName) == "string", 'Parameter "fileName" must be a string.')
  assert(type(data) == "table", 'Parameter "data" must be a table.')

  -- Staged into a temp file and swapped in on commit, so a write interrupted
  -- by power-off, sleep or a flat battery leaves the previous file intact
  -- rather than truncated. See lib/atomic_write.lua.
  local file = atomicWrite.stage(fileName)
  if not file then return false end

  local ok, err = pcall(function()
    for section, params in pairs(data) do
      file:write("[", tostring(section), "]\n")
      for key, value in pairs(params) do
        if type(value) == "boolean" then value = value and "true" or "false" end
        file:write(("%s=%s\n"):format(tostring(key), tostring(value)))
      end
      file:write("\n")
    end
  end)
  if not ok then
    atomicWrite.abort(file, fileName)
    return false, err
  end

  return atomicWrite.commit(file, fileName)
end

function ini.merge_ini_tables(master, slave)
  assert(type(master) == "table", "master must be a table")
  assert(type(slave) == "table", "slave must be a table")

  local merged = {}

  for section, slaveSection in pairs(slave) do
    merged[section] = {}
    for key, value in pairs(slaveSection) do merged[section][key] = value end
    if master[section] then
      for key, value in pairs(master[section]) do merged[section][key] = value end
    end
  end

  for section, masterSection in pairs(master) do
    if not merged[section] then
      merged[section] = {}
      for key, value in pairs(masterSection) do merged[section][key] = value end
    end
  end

  return merged
end

function ini.ini_tables_equal(a, b)
  for section, bVals in pairs(b) do
    local aVals = a[section] or {}
    for key in pairs(bVals) do
      if aVals[key] == nil then return false end
    end
  end
  return true
end

function ini.getvalue(data, section, key)
  if data and section and key and data[section] and data[section][key] ~= nil then
    return data[section][key]
  end
  return nil
end

function ini.section_exists(data, section)
  return data and data[section] ~= nil
end

function ini.setvalue(data, section, key, value)
  if not data then return end
  if not data[section] then data[section] = {} end
  data[section][key] = value
end

package.loaded["rfsuite.lib.ini"] = ini
return ini
