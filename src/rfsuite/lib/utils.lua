--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local utils = {}

local arg = {...}
local config = arg[1]

function utils.session()
    
     if rfsuite.session.originalModelName and model.name then
        rfsuite.utils.log("Restoring model name to: " .. rfsuite.session.originalModelName, "info")
        model.name(rfsuite.session.originalModelName)
    end

    rfsuite.session = {

        escDetails = nil,
        tailMode = nil,
        swashMode = nil,
        rateProfile = nil,
        governorMode = nil,

        activeProfile = nil,
        activeRateProfile = nil,
        activeProfileLast = nil,
        activeRateProfileLast = nil,

        servoCount = nil,
        servoOverride = nil,
        servoBusEnabled = nil,

        apiVersion = nil,
        apiVersionInvalid = nil,
        fcVersion = nil,
        rfVersion = nil,
        ethosRunningVersion = nil,
        mspSignature = nil,
        mcu_id = nil,

        isConnected = false,
        postConnectComplete = false,
        isArmed = false,

        telemetryState = nil,
        telemetryType = nil,
        telemetryTypeChanged = nil,
        telemetrySensor = nil,
        telemetryModule = nil,
        telemetryModelChanged = nil,
        telemetryConfig = nil,
        telemetryModuleNumber = nil,

        mspBusy = false,
        mspStatusMessage = nil,
        mspStatusUpdatedAt = nil,
        mspStatusLast = nil,
        mspStatusClearAt = nil,
        mspCrcErrors = 0,
        progressDialog = nil,

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

        originalModelName = nil,

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
    local tbl = rfsuite.config.supportedMspApiVersion or {"12.07", "12.08", "12.09", "12.10"}
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

    if rfsuite.session and rfsuite.session.apiVersion and rfsuite.utils.apiVersionCompare(">", {12, 0, 7}) then
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

local directoryExistenceCache = {}
local fileExistenceCache = {}

local function countTable(t)
    if type(t) ~= "table" then return 0 end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

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

function utils.file_size(path)
    if not path then return nil end

    local stat = os.stat(path)
    if not stat then return nil end

    local size = stat.size or stat.length or stat.fileSize or stat.filesize
    if type(size) ~= "number" then return nil end

    return size
end

function utils.isImageTooLarge(path, maxBytes)
    if type(path) ~= "string" or path == "" then return false end
    local limit = maxBytes
    if type(limit) ~= "number" then
        limit = (rfsuite.config and rfsuite.config.maxModelImageBytes) or 350 * 1024
    end
    if type(limit) ~= "number" or limit <= 0 then return false end

    local size = utils.file_size(path)
    if not size then return false end

    return size > limit
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

function utils.getCacheStats()
    return {
        fileExists = countTable(fileExistenceCache),
        dirExists = countTable(directoryExistenceCache),
        imageBitmap = countTable(utils._imageBitmapCache),
        imagePath = countTable(utils._imagePathCache)
    }
end

function utils.playFile(pkg, file)

    local av = system.getAudioVoice():gsub("SD:", ""):gsub("RADIO:", ""):gsub("AUDIO:", ""):gsub("VOICE[1-4]:", ""):gsub("audio/", "")

    if av:sub(1, 1) == "/" then av = av:sub(2) end

    local wavUser = "SCRIPTS:/rfsuite.user/audio/user/" .. pkg .. "/" .. file
    local wavLocale = "SCRIPTS:/rfsuite/audio/" .. av .. "/" .. pkg .. "/" .. file
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

function utils.joinTableItems(tbl, delimiter, maxItems)
    if type(tbl) ~= "table" then
        if tbl == nil then return "" end
        return tostring(tbl)
    end

    delimiter = delimiter or ""
    local sIdx = (tbl[0] ~= nil) and 0 or 1
    local hardLimit = maxItems or 2048

    local parts = {}
    local i = sIdx
    local count = 0
    while count < hardLimit do
        local v = tbl[i]
        if v == nil then break end
        parts[#parts + 1] = tostring(v)
        i = i + 1
        count = count + 1
    end

    local joined = table.concat(parts, delimiter)
    local truncated = tbl[i] ~= nil

    if maxItems ~= nil then
        return joined, count, truncated
    end
    return joined
end

function utils.log(msg, level) 
    if rfsuite.tasks and rfsuite.tasks.logger then rfsuite.tasks.logger.add(msg, level or "debug") end 
end

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
    local modules_path = "app/modules/"

    for _, v in pairs(system.listFiles(modules_path)) do
        if v ~= ".." and v ~= "." and not v:match("%.%a+$") then
            local init_path = modules_path .. v .. "/init.lua"

            local func, err = loadfile(init_path)
            if not func then
                rfsuite.utils.log("Failed to load module init " .. init_path .. ": " .. err, "info")
            else
                local mconfig = func()

                if type(mconfig) ~= "table" or not mconfig.script then
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

    if id == nil then
        return 0
    end

    local filepath = "sim/sensors/" .. id .. ".lua"

    local chunk, err = loadfile(filepath)
    if not chunk then
        print("Error loading telemetry file: " .. err)
        return 0
    end

    local result = chunk()

    return result or 0
end


function utils.logMsp(cmd, rwState, buf, err)
    local dev = rfsuite.preferences and rfsuite.preferences.developer
    if dev and dev.logmsp then
        local function emit()
            local payload, shown, truncated = rfsuite.utils.joinTableItems(buf, ", ", 96)
            if truncated then payload = payload .. " ... (" .. tostring(shown) .. "+ items)" end
            rfsuite.utils.log(rwState .. " [" .. cmd .. "]{" .. payload .. "}", "info")
            if err then rfsuite.utils.log("Error: " .. tostring(err), "info") end
        end

        local callback = rfsuite.tasks and rfsuite.tasks.callback
        if callback and callback.now then
            callback.now(emit)
        else
            emit()
        end
    end
end

utils._memProfile = utils._memProfile or {}

local function safeCollectGarbage(command, arg)
    if type(collectgarbage) ~= "function" then return nil end
    local ok, value
    if arg == nil then
        ok, value = pcall(collectgarbage, command)
    else
        ok, value = pcall(collectgarbage, command, arg)
    end
    if ok then return value end
    return nil
end

local function sortedKeys(t)
    local keys = {}
    if type(t) ~= "table" then return keys end
    for key in pairs(t) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

local function formatCoreBytes(coreBytes)
    local keys = sortedKeys(coreBytes)
    if #keys == 0 then return "none" end

    local parts = {}
    for _, key in ipairs(keys) do
        local raw = tonumber(coreBytes[key]) or 0
        parts[#parts + 1] = string.format("%s=%.2fKB", tostring(key), raw / 1024)
    end
    return table.concat(parts, " | ")
end

local function formatCoreBytesDelta(startCore, endCore)
    local all = {}
    if type(startCore) == "table" then
        for key in pairs(startCore) do
            all[key] = true
        end
    end
    if type(endCore) == "table" then
        for key in pairs(endCore) do
            all[key] = true
        end
    end

    local keys = sortedKeys(all)
    if #keys == 0 then return "none" end

    local parts = {}
    for _, key in ipairs(keys) do
        local startBytes = (type(startCore) == "table" and tonumber(startCore[key])) or 0
        local endBytes = (type(endCore) == "table" and tonumber(endCore[key])) or 0
        local deltaKB = (endBytes - startBytes) / 1024
        if deltaKB ~= 0 then
            parts[#parts + 1] = string.format("%s=%+.2fKB", tostring(key), deltaKB)
        end
    end

    if #parts == 0 then return "no changes" end
    return table.concat(parts, " | ")
end

local function formatCacheStats(cache)
    cache = cache or {}
    return string.format(
        "utils[file=%d dir=%d imgBmp=%d imgPath=%d] msp[file=%d chunk=%d helpChunk=%d helpData=%d delta=%d] apidata[v=%d s=%d b=%d bc=%d p=%d o=%d] cbq=%d telemetry[h=%d m=%d hot=%d]",
        cache.fileExists or 0,
        cache.dirExists or 0,
        cache.imageBitmap or 0,
        cache.imagePath or 0,
        cache.mspFile or 0,
        cache.mspChunk or 0,
        cache.mspHelpChunk or 0,
        cache.mspHelpData or 0,
        cache.mspDelta or 0,
        cache.apidataValues or 0,
        cache.apidataStructure or 0,
        cache.apidataBytes or 0,
        cache.apidataBytesCount or 0,
        cache.apidataPos or 0,
        cache.apidataOther or 0,
        cache.callbackQueue or 0,
        cache.telemetryHits or 0,
        cache.telemetryMisses or 0,
        cache.telemetryHot or 0
    )
end

local function formatCacheDelta(startCache, endCache)
    startCache = startCache or {}
    endCache = endCache or {}

    local function d(key)
        return (tonumber(endCache[key]) or 0) - (tonumber(startCache[key]) or 0)
    end

    return string.format(
        "utils[file=%+d dir=%+d imgBmp=%+d imgPath=%+d] msp[file=%+d chunk=%+d helpChunk=%+d helpData=%+d delta=%+d] apidata[v=%+d s=%+d b=%+d bc=%+d p=%+d o=%+d] cbq=%+d telemetry[h=%+d m=%+d hot=%+d]",
        d("fileExists"),
        d("dirExists"),
        d("imageBitmap"),
        d("imagePath"),
        d("mspFile"),
        d("mspChunk"),
        d("mspHelpChunk"),
        d("mspHelpData"),
        d("mspDelta"),
        d("apidataValues"),
        d("apidataStructure"),
        d("apidataBytes"),
        d("apidataBytesCount"),
        d("apidataPos"),
        d("apidataOther"),
        d("callbackQueue"),
        d("telemetryHits"),
        d("telemetryMisses"),
        d("telemetryHot")
    )
end

local function takeMemorySnapshot()
    local perf = rfsuite.performance or {}
    local memInfo = (system and system.getMemoryUsage and system.getMemoryUsage()) or {}
    if type(memInfo) ~= "table" then memInfo = {} end

    local tasks = rfsuite.tasks
    local mspApi = tasks and tasks.msp and tasks.msp.api
    local apidata = mspApi and mspApi.apidata
    local callbackQueue = tasks and tasks.callback and tasks.callback._queue
    local telemetryStats = tasks and tasks.telemetry and tasks.telemetry._debugStats and tasks.telemetry._debugStats() or nil

    local coreBytes = {}
    for key, value in pairs(memInfo) do
        if type(value) == "number" then coreBytes[key] = value end
    end

    return {
        cpu = tonumber(perf.cpuload) or 0,
        free = tonumber(perf.freeram) or 0,
        used = tonumber(perf.usedram) or 0,
        gc = tonumber(safeCollectGarbage("count")) or 0,
        gcRunning = safeCollectGarbage("isrunning"),
        main = (tonumber(memInfo.mainStackAvailable) or 0) / 1024,
        ram = (tonumber(memInfo.ramAvailable) or 0) / 1024,
        lua = (tonumber(memInfo.luaRamAvailable) or 0) / 1024,
        bmp = (tonumber(memInfo.luaBitmapsRamAvailable) or 0) / 1024,
        perfMain = tonumber(perf.mainStackKB) or 0,
        perfRam = tonumber(perf.ramKB) or 0,
        perfLua = tonumber(perf.luaRamKB) or 0,
        perfBmp = tonumber(perf.luaBitmapsRamKB) or 0,
        coreBytes = coreBytes,
        cache = {
            fileExists = countTable(fileExistenceCache),
            dirExists = countTable(directoryExistenceCache),
            imageBitmap = countTable(utils._imageBitmapCache),
            imagePath = countTable(utils._imagePathCache),
            mspFile = countTable(mspApi and mspApi._fileExistsCache),
            mspChunk = countTable(mspApi and mspApi._chunkCache),
            mspHelpChunk = countTable(mspApi and mspApi._helpChunkCache),
            mspHelpData = countTable(mspApi and mspApi._helpDataCache),
            mspDelta = countTable(mspApi and mspApi._deltaCacheByApi),
            apidataValues = countTable(apidata and apidata.values),
            apidataStructure = countTable(apidata and apidata.structure),
            apidataBytes = countTable(apidata and apidata.receivedBytes),
            apidataBytesCount = countTable(apidata and apidata.receivedBytesCount),
            apidataPos = countTable(apidata and apidata.positionmap),
            apidataOther = countTable(apidata and apidata.other),
            callbackQueue = countTable(callbackQueue),
            telemetryHits = (type(telemetryStats) == "table" and tonumber(telemetryStats.hits)) or 0,
            telemetryMisses = (type(telemetryStats) == "table" and tonumber(telemetryStats.misses)) or 0,
            telemetryHot = (type(telemetryStats) == "table" and tonumber(telemetryStats.hot_size)) or 0
        },
        time = os.clock()
    }
end

local function logMemorySnapshot(location, label, snapshot)
    utils.log(string.format("[mem][%s] %s cpu=%.0f%% gc=%.2fKB gcAvg=%.2fKB gcRunning=%s", location, label, snapshot.cpu, snapshot.gc, snapshot.used, tostring(snapshot.gcRunning)), "info")
    utils.log(string.format("[mem][%s] %s luaFree=%.2fKB sysFree=%.2fKB mainStack=%.2fKB bmpFree=%.2fKB", location, label, snapshot.lua, snapshot.ram, snapshot.main, snapshot.bmp), "info")
    utils.log(string.format("[mem][%s] %s perfLua=%.2fKB perfSys=%.2fKB perfMain=%.2fKB perfBmp=%.2fKB", location, label, snapshot.perfLua, snapshot.perfRam, snapshot.perfMain, snapshot.perfBmp), "info")
    utils.log(string.format("[mem][%s] %s core=%s", location, label, formatCoreBytes(snapshot.coreBytes)), "info")
    utils.log(string.format("[mem][%s] %s cache=%s", location, label, formatCacheStats(snapshot.cache)), "info")
end

function utils.reportMemoryUsage(location, phase)
    local dev = rfsuite.preferences and rfsuite.preferences.developer
    if not (dev and dev.memstats) then return end
    location = location or "Unknown"

    local snapshot = takeMemorySnapshot()

    if phase == "start" then
        utils._memProfile[location] = snapshot
        rfsuite.utils.log(string.format("[%s] Profiling started", location), "info")
        logMemorySnapshot(location, "start", snapshot)
        return
    elseif phase == "end" then
        local startSnap = utils._memProfile[location]
        if startSnap then
            local dt = snapshot.time - startSnap.time
            utils.log(string.format("[%s] Profiling ended (%.3fs)", location, dt), "info")
            utils.log(string.format("[%s] CPU diff: %.0f -> %.0f", location, startSnap.cpu, snapshot.cpu), "info")
            utils.log(string.format("[%s] RAM Used diff: %.0f -> %.0f kB", location, startSnap.used, snapshot.used), "info")
            utils.log(string.format("[%s] Lua RAM diff: %.2f -> %.2f KB", location, startSnap.lua, snapshot.lua), "info")
            utils.log(string.format("[%s] GC Heap diff: %.2f -> %.2f KB", location, startSnap.gc, snapshot.gc), "info")
            utils.log(string.format("[%s] System RAM diff: %.2f -> %.2f KB", location, startSnap.ram, snapshot.ram), "info")
            utils.log(string.format("[%s] Main stack diff: %.2f -> %.2f KB", location, startSnap.main, snapshot.main), "info")
            utils.log(string.format("[%s] Bitmap RAM diff: %.2f -> %.2f KB", location, startSnap.bmp, snapshot.bmp), "info")
            utils.log(string.format("[mem][%s] Delta core: %s", location, formatCoreBytesDelta(startSnap.coreBytes, snapshot.coreBytes)), "info")
            utils.log(string.format("[mem][%s] Delta cache: %s", location, formatCacheDelta(startSnap.cache, snapshot.cache)), "info")
            logMemorySnapshot(location, "end", snapshot)

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
    rfsuite.utils.log(string.format("[%s] GC Heap Used: %.2f KB", location, snapshot.gc), "info")
    if snapshot.gcRunning ~= nil then
        rfsuite.utils.log(string.format("[%s] GC Running: %s", location, tostring(snapshot.gcRunning)), "info")
    end
    rfsuite.utils.log(string.format("[%s] Core memory: %s", location, formatCoreBytes(snapshot.coreBytes)), "info")
    rfsuite.utils.log(string.format("[%s] Cache stats: %s", location, formatCacheStats(snapshot.cache)), "info")
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

local function appendVersionParts(parts, value)
    if value == nil then return end

    local valueType = type(value)

    if valueType == "table" then
        local arrayValues = {}
        for _, token in ipairs(value) do arrayValues[#arrayValues + 1] = token end

        -- Accept {major, 0, minor} as an explicit form for two-digit minor
        -- versions, e.g. {12, 0, 9} => 12.09.
        if #arrayValues == 3 then
            local major = tonumber(arrayValues[1])
            local middle = tonumber(arrayValues[2])
            local minor = tonumber(arrayValues[3])
            if major and middle == 0 and minor then
                parts[#parts + 1] = major
                parts[#parts + 1] = minor
                return
            end
        end

        if #arrayValues > 0 then
            for i = 1, #arrayValues do appendVersionParts(parts, arrayValues[i]) end
        elseif value[0] ~= nil then
            appendVersionParts(parts, value[0])
        end
        return
    end

    for n in tostring(value):gmatch("(%d+)") do parts[#parts + 1] = tonumber(n) end
end

local function versionParts(value)
    local parts = {}
    appendVersionParts(parts, value)
    return parts
end

function utils.apiVersionCompare(op, req)
    local a, b = versionParts(rfsuite.session.apiVersion or "12.06"), versionParts(req)
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

local uuidCounter = 0

function utils.uuid(prefix)
    uuidCounter = uuidCounter + 1
    if uuidCounter > 2147483647 then uuidCounter = 1 end

    local now = os.clock()
    local seconds = math.floor(now)
    local millis = math.floor((now - seconds) * 1000)

    if prefix and prefix ~= "" then
        return string.format("%s-%d-%03d-%d", prefix, seconds, millis, uuidCounter)
    end

    return string.format("%d-%03d-%d", seconds, millis, uuidCounter)
end

return utils
