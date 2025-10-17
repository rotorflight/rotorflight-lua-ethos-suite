--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local utils = {}

local arg = {...}
local config = arg[1]

function utils.session()
    rfsuite.session = {

        tailMode = nil,
        swashMode = nil,
        rateProfile = nil,
        governorMode = nil,

        activeProfile = nil,
        activeRateProfile = nil,
        activeProfileLast = nil,
        activeRateLast = nil,

        servoCount = nil,
        servoOverride = nil,

        apiVersion = nil,
        apiVersionInvalid = nil,
        fcVersion = nil,
        rfVersion = nil,
        ethosRunningVersion = nil,
        mspSignature = nil,
        mcu_id = nil,

        isConnected = false,
        isConnectedHigh = false,
        isConnectedMedium = false,
        isConnectedLow = false,
        isArmed = false,

        telemetryState = nil,
        telemetryType = nil,
        telemetryTypeChanged = nil,
        telemetrySensor = nil,
        telemetryModule = nil,
        telemetryModelChanged = nil,
        telemetryConfig = nil,

        mspBusy = false,

        repairSensors = false,

        batteryConfig = nil,

        locale = system.getLocale(),
        lastMemoryUsage = nil,
        bblSize = nil,
        bblUsed = nil,

        timer = {start = nil, live = nil, lifetime = nil, session = 0},
        flightCounted = false,

        onConnect = {tasks = {}, high = false, medium = false, low = false},

        rx = {map = {}, values = {}},

        modelPreferences = nil,
        modelPreferencesFile = nil,

        clockSet = nil,
        resetMSP = nil
    }

end

function utils.rxmapReady()
    if rfsuite.session.rx and rfsuite.session.rx.map and (rfsuite.session.rx.map.collective or rfsuite.session.rx.map.elevator or rfsuite.session.rx.map.throttle or rfsuite.session.rx.map.rudder) then return true end
    return false
end

function utils.inFlight()
    if rfsuite.flightmode.current == "inflight" then return true end
    return false
end

function utils.msp_version_array_to_indexed()
    local arr = {}
    local tbl = rfsuite.config.supportedMspApiVersion or {"12.06", "12.07", "12.08"}
    for i, v in ipairs(tbl) do arr[#arr + 1] = {v, i} end
    return arr
end

function utils.armingDisableFlagsToString(flags)

    local ARMING_DISABLE_FLAG_TAG = {
        [0] = "@i18n(app.modules.fblstatus.arming_disable_flag_0):upper()@",
        [1] = "@i18n(app.modules.fblstatus.arming_disable_flag_1):upper()@",
        [2] = "@i18n(app.modules.fblstatus.arming_disable_flag_2):upper()@",
        [3] = "@i18n(app.modules.fblstatus.arming_disable_flag_3):upper()@",
        [4] = "@i18n(app.modules.fblstatus.arming_disable_flag_4):upper()@",
        [5] = "@i18n(app.modules.fblstatus.arming_disable_flag_5):upper()@",
        [6] = "@i18n(app.modules.fblstatus.arming_disable_flag_6):upper()@",
        [7] = "@i18n(app.modules.fblstatus.arming_disable_flag_7):upper()@",
        [8] = "@i18n(app.modules.fblstatus.arming_disable_flag_8):upper()@",
        [9] = "@i18n(app.modules.fblstatus.arming_disable_flag_9):upper()@",
        [10] = "@i18n(app.modules.fblstatus.arming_disable_flag_10):upper()@",
        [11] = "@i18n(app.modules.fblstatus.arming_disable_flag_11):upper()@",
        [12] = "@i18n(app.modules.fblstatus.arming_disable_flag_12):upper()@",
        [13] = "@i18n(app.modules.fblstatus.arming_disable_flag_13):upper()@",
        [14] = "@i18n(app.modules.fblstatus.arming_disable_flag_14):upper()@",
        [15] = "@i18n(app.modules.fblstatus.arming_disable_flag_15):upper()@",
        [16] = "@i18n(app.modules.fblstatus.arming_disable_flag_16):upper()@",
        [17] = "@i18n(app.modules.fblstatus.arming_disable_flag_17):upper()@",
        [18] = "@i18n(app.modules.fblstatus.arming_disable_flag_18):upper()@",
        [19] = "@i18n(app.modules.fblstatus.arming_disable_flag_19):upper()@",
        [20] = "@i18n(app.modules.fblstatus.arming_disable_flag_20):upper()@",
        [21] = "@i18n(app.modules.fblstatus.arming_disable_flag_21):upper()@",
        [22] = "@i18n(app.modules.fblstatus.arming_disable_flag_22):upper()@",
        [23] = "@i18n(app.modules.fblstatus.arming_disable_flag_23):upper()@",
        [24] = "@i18n(app.modules.fblstatus.arming_disable_flag_24):upper()@",
        [25] = "@i18n(app.modules.fblstatus.arming_disable_flag_25):upper()@"
    }

    if flags == nil or flags == 0 then return "@i18n(app.modules.fblstatus.ok):upper()@" end

    local names = {}
    for i = 0, 25 do
        if (flags & (1 << i)) ~= 0 then
            local name = ARMING_DISABLE_FLAG_TAG[i]
            if name and name ~= "" then names[#names + 1] = name end
        end
    end

    if #names == 0 then return "@i18n(app.modules.fblstatus.ok):upper()@" end

    return table.concat(names, ", ")
end

function utils.getGovernorState(value)
    local returnvalue

    if not rfsuite.tasks.telemetry then return "@i18n(widgets.governor.UNKNOWN)@" end

    local map = {
        [0] = "@i18n(widgets.governor.OFF):upper()@",
        [1] = "@i18n(widgets.governor.IDLE):upper()@",
        [2] = "@i18n(widgets.governor.SPOOLUP):upper()@",
        [3] = "@i18n(widgets.governor.RECOVERY):upper()@",
        [4] = "@i18n(widgets.governor.ACTIVE):upper()@",
        [5] = "@i18n(widgets.governor.THROFF):upper()@",
        [6] = "@i18n(widgets.governor.LOSTHS):upper()@",
        [7] = "@i18n(widgets.governor.AUTOROT):upper()@",
        [8] = "@i18n(widgets.governor.BAILOUT):upper()@",
        [100] = "@i18n(widgets.governor.DISABLED):upper()@",
        [101] = "@i18n(widgets.governor.DISARMED):upper()@"
    }

    if rfsuite.session and rfsuite.session.apiVersion and rfsuite.utils.apiVersionCompare(">", "12.07") then
        local armflags = rfsuite.tasks.telemetry.getSensor("armflags")
        if armflags == 0 or armflags == 2 then value = 101 end
    end

    if map[value] then
        returnvalue = map[value]
    else
        returnvalue = "@i18n(widgets.governor.UNKNOWN):upper()@"
    end

    local armdisableflags = rfsuite.tasks.telemetry.getSensor("armdisableflags")
    if armdisableflags ~= nil then
        armdisableflags = math.floor(armdisableflags)
        local armstring = utils.armingDisableFlagsToString(armdisableflags)
        if armstring ~= "OK" then returnvalue = armstring end
    end

    return returnvalue
end

function utils.createCacheFile(tbl, path, options)
    os.mkdir("cache")

    path = "cache/" .. path

    local f, err = io.open(path, "w")
    if not f then
        rfsuite.utils.log("Error creating cache file: " .. err, "info")
        return
    end

    local function serialize(value, indent)
        indent = indent or ""
        local t = type(value)

        if t == "string" then
            return string.format("%q", value)
        elseif t == "number" or t == "boolean" then
            return tostring(value)
        elseif t == "table" then
            local result = "{\n"
            for k, v in pairs(value) do
                local keyStr
                if type(k) == "string" and k:match("^%a[%w_]*$") then
                    keyStr = k .. " = "
                else
                    keyStr = "[" .. serialize(k) .. "] = "
                end
                result = result .. indent .. "  " .. keyStr .. serialize(v, indent .. "  ") .. ",\n"
            end
            result = result .. indent .. "}"
            return result
        else
            error("Cannot serialize type: " .. t)
        end
    end

    f:write("return ", serialize(tbl), "\n")
    f:close()
end

local directoryExistenceCache = {}
local fileExistenceCache = {}

function utils.dir_exists(base, name, noCache)
    base = base or "./"
    if not name then return false end

    local targetPath = base .. name

    if not noCache and directoryExistenceCache[targetPath] then return true end

    local exists = os.stat(targetPath)
    if exists then
        if not noCache then directoryExistenceCache[targetPath] = true end
        return true
    end

    return false
end

function utils.file_exists(path, noCache)
    if not path then return false end

    if not noCache and fileExistenceCache[path] then return true end

    local stat = os.stat(path)
    if stat then
        if not noCache then fileExistenceCache[path] = true end
        return true
    end

    return false
end

function utils.playFile(pkg, file)

    local av = system.getAudioVoice():gsub("SD:", ""):gsub("RADIO:", ""):gsub("AUDIO:", ""):gsub("VOICE[1-4]:", ""):gsub("audio/", "")

    if av:sub(1, 1) == "/" then av = av:sub(2) end

    local wavUser = "SCRIPTS:/rfsuite.user/audio/user/" .. pkg .. "/" .. file
    local wavLocale = "SCRIPTS:/rfsuite.user/audio/" .. av .. "/" .. pkg .. "/" .. file
    local wavDefault = "SCRIPTS:/rfsuite/audio/en/default/" .. pkg .. "/" .. file

    local path
    if rfsuite.utils.file_exists(wavUser) then
        path = wavUser
    elseif rfsuite.utils.file_exists(wavLocale) then
        path = wavLocale
    else
        path = wavDefault
    end

    system.playFile(path)
end

function utils.playFileCommon(file) system.playFile("audio/" .. file) end

function utils.ethosVersionAtLeast(targetVersion)
    local env = system.getVersion()
    local currentVersion = {env.major, env.minor, env.revision}

    if targetVersion == nil then
        if rfsuite and rfsuite.config and rfsuite.config.ethosVersion then
            targetVersion = rfsuite.config.ethosVersion
        else

            return false
        end
    elseif type(targetVersion) == "number" then
        rfsuite.utils.log("WARNING: utils.ethosVersionAtLeast() called with a number instead of a table (" .. targetVersion .. ")", 2)
        return false
    end

    for i = 1, 3 do targetVersion[i] = targetVersion[i] or 0 end

    for i = 1, 3 do
        if currentVersion[i] > targetVersion[i] then
            return true
        elseif currentVersion[i] < targetVersion[i] then
            return false
        end
    end

    return true
end

function utils.round(num, places)
    if num == nil then return nil end

    local places = places or 2
    if places == 0 then
        return math.floor(num + 0.5)
    else
        local mult = 10 ^ places
        return math.floor(num * mult + 0.5) / mult
    end
end

function utils.joinTableItems(tbl, delimiter)
    if not tbl or #tbl == 0 then return "" end

    delimiter = delimiter or ""
    local sIdx = tbl[0] and 0 or 1

    local padded = {}
    for i = sIdx, #tbl do padded[i] = tostring(tbl[i]) .. string.rep(" ", math.max(0, 3 - #tostring(tbl[i]))) end

    return table.concat(padded, delimiter, sIdx, #tbl)
end

function utils.log(msg, level) if rfsuite.tasks and rfsuite.tasks.logger then rfsuite.tasks.logger.add(msg, level or "debug") end end

function utils.print_r(node, maxDepth, currentDepth)
    maxDepth = maxDepth or 5
    currentDepth = currentDepth or 0

    if currentDepth > maxDepth then return "{...} -- Max Depth Reached" end

    if type(node) ~= "table" then return tostring(node) .. " (" .. type(node) .. ")" end

    local result = {}
    table.insert(result, "{")

    for k, v in pairs(node) do
        local key = type(k) == "string" and ('["' .. k .. '"]') or ("[" .. tostring(k) .. "]")
        local value

        if type(v) == "table" then
            value = utils.print_r(v, maxDepth, currentDepth + 1)
        else
            value = tostring(v)
            if type(v) == "string" then value = '"' .. value .. '"' end
        end

        table.insert(result, key .. " = " .. value .. ",")
    end

    table.insert(result, "}")
    print(table.concat(result, " "))
end

function utils.findModules()
    local modulesList = {}
    local moduledir = "app/modules/"
    local modules_path = moduledir

    for _, v in pairs(system.listFiles(modules_path)) do
        if v ~= ".." and v ~= "." and not v:match("%.%a+$") then
            local init_path = modules_path .. v .. '/init.lua'

            local func, err = loadfile(init_path)
            if not func then
                rfsuite.utils.log("Failed to load module init " .. init_path .. ": " .. err, "info")
            else
                local ok, mconfig = pcall(func)
                if not ok then
                    rfsuite.utils.log("Error executing " .. init_path .. ": " .. mconfig, "info")
                elseif type(mconfig) ~= "table" or not mconfig.script then
                    rfsuite.utils.log("Invalid configuration in " .. init_path, "info")
                else
                    rfsuite.utils.log("Loading module " .. v, "debug")
                    mconfig.folder = v
                    table.insert(modulesList, mconfig)
                end
            end
        end
    end

    return modulesList
end

function utils.findWidgets()
    local widgetsList = {}
    local widgetdir = "widgets/"
    local widgets_path = widgetdir

    for _, v in pairs(system.listFiles(widgets_path)) do
        if v ~= ".." and v ~= "." and not v:match("%.%a+$") then
            local init_path = widgets_path .. v .. '/init.lua'

            local func, err = loadfile(init_path)
            if not func then
                rfsuite.utils.log("Failed to load widget init " .. init_path .. ": " .. err, "debug")
            else
                local ok, wconfig = pcall(func)
                if not ok then
                    rfsuite.utils.log("Error executing widget init " .. init_path .. ": " .. wconfig, "debug")
                elseif type(wconfig) ~= "table" or not wconfig.key then
                    rfsuite.utils.log("Invalid configuration in " .. init_path, "debug")
                else
                    wconfig.folder = v
                    table.insert(widgetsList, wconfig)
                end
            end
        end
    end

    return widgetsList
end

utils._imagePathCache = {}
utils._imageBitmapCache = {}

function utils.loadImage(image1, image2, image3)

    local function getCachedBitmap(key, tryPaths)
        if not key then return nil end
        if utils._imageBitmapCache[key] then return utils._imageBitmapCache[key] end

        local path = utils._imagePathCache[key]
        if not path then
            for _, p in ipairs(tryPaths) do
                if rfsuite.utils.file_exists(p) then
                    path = p
                    break
                end
            end
            utils._imagePathCache[key] = path
        end

        if not path then return nil end
        local bmp = lcd.loadBitmap(path)
        utils._imageBitmapCache[key] = bmp
        return bmp
    end

    local function candidates(img)
        if type(img) ~= "string" then return {} end
        local out = {img, "BITMAPS:" .. img, "SYSTEM:" .. img}
        if img:match("%.png$") then
            out[#out + 1] = img:gsub("%.png$", ".bmp")
        elseif img:match("%.bmp$") then
            out[#out + 1] = img:gsub("%.bmp$", ".png")
        end
        return out
    end

    return getCachedBitmap(image1, candidates(image1)) or getCachedBitmap(image2, candidates(image2)) or getCachedBitmap(image3, candidates(image3))
end

function utils.simSensors(id)
    os.mkdir("LOGS:")
    os.mkdir("LOGS:/rfsuite")
    os.mkdir("LOGS:/rfsuite/sensors")

    if id == nil then return 0 end

    local filepath = "sim/sensors/" .. id .. ".lua"

    local chunk, err = loadfile(filepath)
    if not chunk then
        print("Error loading telemetry file: " .. err)
        return 0
    end

    local success, result = pcall(chunk)
    if not success then
        print("Error executing telemetry file: " .. result)
        return 0
    end

    return result
end

function utils.logMsp(cmd, rwState, buf, err)
    if rfsuite.preferences.developer.logmsp then
        local payload = rfsuite.utils.joinTableItems(buf, ", ")
        rfsuite.utils.log(rwState .. " [" .. cmd .. "]{" .. payload .. "}", "info")
        if err then rfsuite.utils.log("Error: " .. err, "info") end
    end
end

utils._memProfile = utils._memProfile or {}

function utils.reportMemoryUsage(location, phase)
    if not rfsuite.preferences.developer.memstats then return end
    location = location or "Unknown"

    local cpuInfo = (rfsuite.performance and rfsuite.performance.cpuload) or 0
    local ramFree = (rfsuite.performance and rfsuite.performance.freeram) or 0
    local ramUsed = (rfsuite.performance and rfsuite.performance.usedram) or 0
    local memInfo = system.getMemoryUsage() or {}

    local snapshot = {cpu = cpuInfo, free = ramFree, used = ramUsed, main = (memInfo.mainStackAvailable or 0) / 1024, ram = (memInfo.ramAvailable or 0) / 1024, lua = (memInfo.luaRamAvailable or 0) / 1024, bmp = (memInfo.luaBitmapsRamAvailable or 0) / 1024, time = os.clock()}

    if phase == "start" then
        utils._memProfile[location] = snapshot
        rfsuite.utils.log(string.format("[%s] Profiling started", location), "info")
        return
    elseif phase == "end" then
        local startSnap = utils._memProfile[location]
        if startSnap then
            local dt = snapshot.time - startSnap.time
            utils.log(string.format("[%s] Profiling ended (%.3fs)", location, dt), "info")
            utils.log(string.format("[%s] CPU diff: %.0f -> %.0f", location, startSnap.cpu, snapshot.cpu), "info")
            utils.log(string.format("[%s] RAM Used diff: %.0f -> %.0f kB", location, startSnap.used, snapshot.used), "info")
            utils.log(string.format("[%s] Lua RAM diff: %.2f -> %.2f KB", location, startSnap.lua, snapshot.lua), "info")

            utils._memProfile[location] = nil
        else
            utils.log(string.format("[%s] Profiling 'end' without a 'start'", location), "warn")
        end
        return
    end

    rfsuite.utils.log(string.format("[%s] CPU Load: %d%%", location, rfsuite.utils.round(snapshot.cpu, 0)), "info")
    rfsuite.utils.log(string.format("[%s] RAM Free: %d kB", location, rfsuite.utils.round(snapshot.free, 0)), "info")
    rfsuite.utils.log(string.format("[%s] RAM Used: %d kB", location, rfsuite.utils.round(snapshot.used, 0)), "info")
    rfsuite.utils.log(string.format("[%s] Main stack available: %.2f KB", location, snapshot.main), "info")
    rfsuite.utils.log(string.format("[%s] System RAM available: %.2f KB", location, snapshot.ram), "info")
    rfsuite.utils.log(string.format("[%s] Lua RAM available: %.2f KB", location, snapshot.lua), "info")
    rfsuite.utils.log(string.format("[%s] Lua Bitmap RAM available: %.2f KB", location, snapshot.bmp), "info")
end

function utils.onReboot()
    rfsuite.utils.log("utils.onReboot called", "info")
    rfsuite.session.resetSensors = true
    rfsuite.session.resetTelemetry = true
    rfsuite.session.resetMSP = true
    rfsuite.session.resetMSPSensors = true
end

function utils.splitVersionStringToNumbers(versionString)
    if not versionString then return nil end

    local parts = {0}
    for num in versionString:gmatch("%d+") do table.insert(parts, tonumber(num)) end
    return parts
end

function utils.keys(tbl)
    local keys = {}
    for k in pairs(tbl) do table.insert(keys, k) end
    return keys
end

function utils.apiVersionCompare(op, req)

    local function parts(x)
        local t = {}
        for n in tostring(x):gmatch("(%d+)") do t[#t + 1] = tonumber(n) end
        return t
    end

    local a, b = parts(rfsuite.session.apiVersion or 12.06), parts(req)
    if #a == 0 or #b == 0 then return false end

    local len = math.max(#a, #b)
    local cmp = 0
    for i = 1, len do
        local ai = a[i] or 0
        local bi = b[i] or 0
        if ai ~= bi then
            cmp = (ai > bi) and 1 or -1
            break
        end
    end

    if op == ">" then return cmp == 1 end
    if op == "<" then return cmp == -1 end
    if op == ">=" then return cmp >= 0 end
    if op == "<=" then return cmp <= 0 end
    if op == "==" then return cmp == 0 end
    if op == "!=" or op == "~=" then return cmp ~= 0 end

    return false
end

function utils.muteSensorLostWarnings()
    if rfsuite.session.telemetryModule then
        local module = rfsuite.session.telemetryModule
        if module and module.muteSensorLost then module:muteSensorLost(2.0) end
    end
end

function utils.stringInArray(array, s)
    for i, value in ipairs(array) do if value == s then return true end end
    return false
end

return utils
