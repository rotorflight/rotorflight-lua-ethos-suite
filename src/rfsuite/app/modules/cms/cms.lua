--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local app = rfsuite.app
local tasks = rfsuite.tasks
local utils = rfsuite.utils

local form = form
local lcd = lcd
local mspHelper = tasks.msp.mspHelper

-- CMS-over-MSP (MSPv2) command IDs
local CMD_INFO = 0x3100
local CMD_MENU_GET = 0x3101
local CMD_VALUE_GET = 0x3102
local CMD_VALUE_SET = 0x3103
local CMD_ACTION = 0x3104
local CMD_STR_GET = 0x3105
local CMD_VALUE_META_GET = 0x3106
local CMD_SAVE = 0x3108

local CMS_CAP_READONLY_ARMED = (1 << 0)
local CMS_CAP_ACTION = (1 << 3)
local CMS_CAP_STR_GET = (1 << 4)
local CMS_CAP_VALUE_META = (1 << 5)
local CMS_CAP_SAVE = (1 << 7)

local MENU_PAGE_SIZE_DEFAULT = 6
local CMS_PENDING_DELAY = 0.05
local CMS_VALUE_RETRY_DELAY = 1.0
local CMS_VALUE_MAX_RETRIES = 3
local CMS_LOADER_TIMEOUT = 10.0
local MSP_FEATURE_CONFIG = 36
local CMS_FEATURE_BIT = 19

local cms = {
    needsRebuild = true,
    info = {
        schemaMajor = nil,
        schemaMinor = nil,
        menuGen = nil,
        rootMenuId = nil,
        caps = 0,
        maxPageItems = MENU_PAGE_SIZE_DEFAULT,
        maxLabelLen = 31,
        requested = false,
        ready = false
    },
    feature = {
        checked = false,
        cmsEnabled = nil
    },
    menus = {},
    stack = {},
    currentMenuId = nil,
    strings = {},
    values = {},
    meta = {},
    selected = {menuId = nil, index = nil},
    staged = {},
    dirty = false,
    pending = {},
    lastError = nil,
    lastStatus = nil,
    _uuidSeq = 0,
    loader = nil,
    loading = false,
    wasLoading = false,
    lastBuildAt = 0,
    lastPendingAt = 0,
    loaderStart = 0,
    loaderAllowClose = false,
    req = {
        menuPage = {},
        str = {},
        meta = {},
        value = {}
    },
    fieldRefs = {},
    focusApplied = {},
    lastFocusKey = nil
}

local function log(msg)
    if utils and utils.log then utils.log(msg, "info") end
end

local function nextUuid()
    cms._uuidSeq = cms._uuidSeq + 1
    return "cms-" .. tostring(cms._uuidSeq)
end

local function enqueue(cmd, payload, onReply, opts)
    if not cmd then
        log("CMS MSP command id not set")
        return false
    end

    local message = {
        command = cmd,
        payload = payload or {},
        processReply = onReply,
        errorHandler = function(self, why)
            cms.lastError = tostring(why)
            cms.lastStatus = "error"
        end,
        apiname = opts and opts.apiname or nil,
        uuid = (opts and opts.uuid) or nextUuid(),
        timeout = opts and opts.timeout or nil
    }

    tasks.msp.mspQueue:add(message)
    cms.lastStatus = "queued"
    return true
end

local function bufReadU16(buf)
    return mspHelper.readU16(buf)
end

local function bufReadU32(buf)
    return mspHelper.readU32(buf)
end

local function bufWriteU16(buf, v)
    mspHelper.writeU16(buf, v)
end

local function bufWriteU32(buf, v)
    mspHelper.writeU32(buf, v)
end

local function bufReadStr(buf)
    local len = mspHelper.readU8(buf)
    if not len or len == 0 then return "" end
    local start = buf.offset or 1
    local out = {}
    for i = 0, len - 1 do
        local b = buf[start + i]
        if b then out[#out + 1] = string.char(b) end
    end
    buf.offset = start + len
    return table.concat(out)
end

local function buildMenuGetPayload(menuId, startIndex, count, options)
    local payload = {}
    bufWriteU16(payload, menuId or 0)
    payload[#payload + 1] = startIndex or 0
    local maxReq = count or cms.info.maxPageItems or MENU_PAGE_SIZE_DEFAULT
    if maxReq > MENU_PAGE_SIZE_DEFAULT then maxReq = MENU_PAGE_SIZE_DEFAULT end
    payload[#payload + 1] = maxReq
    payload[#payload + 1] = options or 0
    return payload
end

local function buildStrGetPayload(menuId, itemIndex)
    local payload = {}
    bufWriteU16(payload, menuId or 0)
    payload[#payload + 1] = itemIndex or 0
    return payload
end

local function buildValueMetaGetPayload(menuId, itemIndex)
    local payload = {}
    bufWriteU16(payload, menuId or 0)
    payload[#payload + 1] = itemIndex or 0
    return payload
end

local function buildValueGetPayload(menuId, itemIndex)
    local payload = {}
    bufWriteU16(payload, menuId or 0)
    payload[#payload + 1] = itemIndex or 0
    return payload
end

local function buildValueSetPayload(menuId, itemIndex, value)
    local payload = {}
    bufWriteU16(payload, menuId or 0)
    payload[#payload + 1] = itemIndex or 0
    bufWriteU32(payload, value or 0)
    return payload
end

local function buildActionPayload(menuId, itemIndex)
    local payload = {}
    bufWriteU16(payload, menuId or 0)
    payload[#payload + 1] = itemIndex or 0
    bufWriteU16(payload, 0) -- param reserved
    return payload
end

local function resetMenuState()
    cms.menus = {}
    cms.stack = {}
    cms.currentMenuId = nil
    cms.strings = {}
    cms.values = {}
    cms.meta = {}
    cms.selected = {menuId = nil, index = nil}
    cms.staged = {}
    cms.dirty = false
    cms.req = {menuPage = {}, str = {}, meta = {}, value = {}}
    cms.fieldRefs = {}
    cms.wasLoading = false
    cms.focusApplied = {}
end

local function ensureMenu(menuId)
    if not cms.menus[menuId] then
        cms.menus[menuId] = {
            id = menuId,
            total = nil,
            items = {},
            titleShort = nil,
            titleFull = nil,
            loaded = false,
            requested = false,
            valuesRequested = false,
            nextStart = 0
        }
    end
    return cms.menus[menuId]
end

local function checkMenuGen(gen)
    if cms.info.menuGen == nil then
        cms.info.menuGen = gen
        return true
    end
    if gen ~= cms.info.menuGen then
        cms.info.ready = false
        cms.info.requested = false
        resetMenuState()
        cms.needsRebuild = true
        return false
    end
    return true
end

local function parseMenuGet(buf)
    local b = {offset = 1}
    for i = 1, #buf do b[i] = buf[i] end

    local menuGen = bufReadU16(b)
    local menuId = bufReadU16(b)
    local startIndex = mspHelper.readU8(b)
    local maxItems = mspHelper.readU8(b)
    local total = mspHelper.readU8(b)
    local returned = mspHelper.readU8(b)
    local title = bufReadStr(b)

    local items = {}
    local truncated = false
    local function remaining()
        local off = b.offset or 1
        return (#buf - off + 1)
    end

    for i = 1, (returned or 0) do
        -- fixed header per item: index(1)+itemType(1)+valType(1)+flags(2)+submenuId(2)+labelLen(1)
        if remaining() < 8 then
            truncated = true
            break
        end
        local itemIndex = mspHelper.readU8(b)
        local itemType = mspHelper.readU8(b)
        local valType = mspHelper.readU8(b)
        local flags = bufReadU16(b)
        local submenuId = bufReadU16(b)
        local labelLen = mspHelper.readU8(b)
        if not labelLen then
            truncated = true
            break
        end
        if remaining() < labelLen then
            truncated = true
            break
        end
        local label = ""
        if labelLen > 0 then
            local start = b.offset or 1
            local out = {}
            for j = 0, labelLen - 1 do
                local ch = buf[start + j]
                if ch then out[#out + 1] = string.char(ch) end
            end
            b.offset = start + labelLen
            label = table.concat(out)
        end
        items[#items + 1] = {
            index = itemIndex,
            itemType = itemType,
            valType = valType,
            flags = flags,
            submenuId = submenuId,
            short = label
        }
        -- print(string.format("[CMS MENU] mid=%s idx=%s type=%s vtype=%s flags=%s sub=%s label=%s",
        --     tostring(menuId), tostring(itemIndex), tostring(itemType), tostring(valType), tostring(flags), tostring(submenuId), tostring(label)))
    end

    return {
        menuGen = menuGen,
        menuId = menuId,
        startIndex = startIndex,
        maxItems = maxItems,
        total = total,
        returned = returned,
        title = title,
        items = items,
        truncated = truncated
    }
end

local function requestMenuPage(menuId, startIndex, options)
    local key = tostring(menuId) .. ":" .. tostring(startIndex or 0)
    local state = cms.req.menuPage[key]
    if state and state.done then return end
    if state and state.inflight then return end
    if not state then
        state = {inflight = false, done = false, retries = 0}
        cms.req.menuPage[key] = state
    end
    state.inflight = true

    local payload = buildMenuGetPayload(menuId, startIndex, cms.info.maxPageItems or MENU_PAGE_SIZE_DEFAULT, options)

    enqueue(CMD_MENU_GET, payload, function(self, buf)
        local parsed = parseMenuGet(buf or {})
        state.inflight = false
        if not parsed.menuId then return end
        if not checkMenuGen(parsed.menuGen) then return end
        if parsed.truncated then
            state.retries = (state.retries or 0) + 1
            if state.retries <= 3 then
                table.insert(cms.pending, function()
                    requestMenuPage(menuId, startIndex)
                end)
            else
                log("CMS MENU_GET truncated after retries menuId=" .. tostring(menuId) .. " start=" .. tostring(startIndex))
            end
            return
        end

        local menu = ensureMenu(parsed.menuId)
        menu.total = parsed.total
        menu.nextStart = (parsed.startIndex or 0) + (parsed.returned or 0)
        menu.loaded = (menu.nextStart >= (menu.total or 0))
        menu.titleShort = parsed.title
        if menu.loaded then
            menu.valuesRequested = false
        end
        state.done = true

        for i = 1, #parsed.items do
            local item = parsed.items[i]
            if item.index ~= nil then
                menu.items[item.index] = item
            end
        end

        if menu.titleShort and menu.titleShort ~= "" and not menu.titleFull and (cms.info.caps & CMS_CAP_STR_GET) ~= 0 then
            table.insert(cms.pending, function()
                enqueue(CMD_STR_GET, buildStrGetPayload(menu.id, 0xFF), function(self2, buf2)
                    local b2 = {offset = 1}
                    for i = 1, #buf2 do b2[i] = buf2[i] end
                    local gen = bufReadU16(b2)
                    local mid = bufReadU16(b2)
                    local idx = mspHelper.readU8(b2)
                    local str = bufReadStr(b2)
                    if checkMenuGen(gen) and mid == menu.id and idx == 0xFF then
                        menu.titleFull = str
                        cms.needsRebuild = true
                    end
                end, {apiname = "CMS:STR_GET:TITLE:" .. tostring(menu.id)})
            end)
        end

        cms.needsRebuild = true

        if menu.total and menu.nextStart < menu.total then
            table.insert(cms.pending, function()
                requestMenuPage(menu.id, menu.nextStart, 0)
            end)
        end
    end, {apiname = "CMS:MENU_GET:" .. tostring(menuId) .. ":" .. tostring(startIndex or 0)})
end

local function requestStr(menuId, itemIndex)
    local key = tostring(menuId) .. ":" .. tostring(itemIndex)
    if cms.req.str[key] then return end
    cms.req.str[key] = true

    enqueue(CMD_STR_GET, buildStrGetPayload(menuId, itemIndex), function(self, buf)
        local b = {offset = 1}
        for i = 1, #buf do b[i] = buf[i] end
        local gen = bufReadU16(b)
        local mid = bufReadU16(b)
        local idx = mspHelper.readU8(b)
        local str = bufReadStr(b)
        if checkMenuGen(gen) and mid == menuId then
            cms.strings[mid .. ":" .. tostring(idx)] = str
        end
        if cms.currentMenuId == menuId and idx == 0xFF then
            cms.needsRebuild = true
        end
    end, {apiname = "CMS:STR_GET:" .. tostring(menuId) .. ":" .. tostring(itemIndex)})
end

local function requestMeta(menuId, itemIndex)
    local key = tostring(menuId) .. ":" .. tostring(itemIndex)
    local state = cms.req.meta[key]
    if state and state.done then return end
    local now = os.clock()
    if state and state.inflight and (now - (state.ts or 0)) < CMS_VALUE_RETRY_DELAY then return end
    if not state then
        state = {inflight = false, done = false, retries = 0, ts = 0}
        cms.req.meta[key] = state
    end
    if state.retries >= CMS_VALUE_MAX_RETRIES then return end
    state.inflight = true
    state.ts = now
    state.retries = state.retries + 1

    enqueue(CMD_VALUE_META_GET, buildValueMetaGetPayload(menuId, itemIndex), function(self, buf)
        if not buf or #buf < 24 then
            log("CMS META short reply len=" .. tostring(buf and #buf))
            state.inflight = false
            return
        end
        local b = {offset = 1}
        for i = 1, #buf do b[i] = buf[i] end
        local gen = bufReadU16(b)
        local mid = bufReadU16(b)
        local idx = mspHelper.readU8(b)
        local valType = mspHelper.readU8(b)
        local vmin = bufReadU32(b)
        local vmax = bufReadU32(b)
        local vstep = bufReadU32(b)
        local vscale = bufReadU32(b)
        local flags = bufReadU16(b)
        if checkMenuGen(gen) and mid == menuId then
            cms.meta[mid .. ":" .. tostring(idx)] = {
                valType = valType,
                min = vmin,
                max = vmax,
                step = vstep,
                scale = vscale,
                flags = flags
            }
            state.done = true
        end
        state.inflight = false
        local key = menuId .. ":" .. tostring(itemIndex)
        local ref = cms.fieldRefs[key]
        if ref and ref.field and ref.field.enable and not cms.loading then
            ref.field:enable(true)
        end
    end, {apiname = "CMS:VALUE_META_GET:" .. tostring(menuId) .. ":" .. tostring(itemIndex)})
end

local function requestValue(menuId, itemIndex)
    local key = tostring(menuId) .. ":" .. tostring(itemIndex)
    local state = cms.req.value[key]
    if state and state.done then return end
    local now = os.clock()
    if state and state.inflight and (now - (state.ts or 0)) < CMS_VALUE_RETRY_DELAY then return end
    if not state then
        state = {inflight = false, done = false, retries = 0, ts = 0}
        cms.req.value[key] = state
    end
    if state.retries >= CMS_VALUE_MAX_RETRIES then return end
    state.inflight = true
    state.ts = now
    state.retries = state.retries + 1

    local payload = buildValueGetPayload(menuId, itemIndex)
    -- print(string.format("[CMS VALUE REQ] mid=%s idx=%s", tostring(menuId), tostring(itemIndex)))

    enqueue(CMD_VALUE_GET, payload, function(self, buf)
        if not buf or #buf < 11 then
            log("CMS VALUE short reply len=" .. tostring(buf and #buf))
            state.inflight = false
            return
        end
        -- do
        --     local s = {}
        --     for i = 1, #buf do s[#s + 1] = tostring(buf[i]) end
        --     print("[CMS VALUE RAW] " .. table.concat(s, ","))
        -- end
        local b = {offset = 1}
        for i = 1, #buf do b[i] = buf[i] end
        local gen = bufReadU16(b)
        local mid = bufReadU16(b)
        local idx = mspHelper.readU8(b)
        local val = bufReadU32(b)
        local flags = bufReadU16(b)
        -- print(string.format("[CMS VALUE] gen=%s mid=%s idx=%s val=%s flags=%s", tostring(gen), tostring(mid), tostring(idx), tostring(val), tostring(flags)))
        if checkMenuGen(gen) and mid == menuId then
            cms.values[mid .. ":" .. tostring(idx)] = {value = val, flags = flags}
            state.done = true
        end
        state.inflight = false
        local key = menuId .. ":" .. tostring(itemIndex)
        local ref = cms.fieldRefs[key]
        if ref and ref.field then
            if ref.isBool then
                if ref.field.value then ref.field:value((val or 0) ~= 0) end
            else
                local scale = ref.scale or 1
                if ref.field.value then ref.field:value((val or 0) / scale) end
            end
            if ref.field.enable and not cms.loading then
                ref.field:enable(true)
            end
        end
    end, {apiname = "CMS:VALUE_GET:" .. tostring(menuId) .. ":" .. tostring(itemIndex)})
end

local function sendValue(menuId, itemIndex, value)
    -- print(string.format("[CMS VALUE_SET REQ] mid=%s idx=%s val=%s", tostring(menuId), tostring(itemIndex), tostring(value)))
    enqueue(CMD_VALUE_SET, buildValueSetPayload(menuId, itemIndex, value), function(self, buf)
        local b = {offset = 1}
        for i = 1, #buf do b[i] = buf[i] end
        local gen = bufReadU16(b)
        local mid = bufReadU16(b)
        local idx = mspHelper.readU8(b)
        local applied = bufReadU32(b)
        local result = mspHelper.readU8(b)
        local flags = bufReadU16(b)
        -- print(string.format("[CMS VALUE_SET] gen=%s mid=%s idx=%s applied=%s result=%s flags=%s", tostring(gen), tostring(mid), tostring(idx), tostring(applied), tostring(result), tostring(flags)))
        if checkMenuGen(gen) and mid == menuId then
            cms.values[mid .. ":" .. tostring(idx)] = {value = applied, flags = flags, result = result}
        end
        cms.lastStatus = "saved"
        cms.needsRebuild = true
    end, {apiname = "CMS:VALUE_SET:" .. tostring(menuId) .. ":" .. tostring(itemIndex)})
end

local function sendSave(menuId)
    if (cms.info.caps & CMS_CAP_SAVE) == 0 then
        -- print("[CMS SAVE_NOEXIT] not supported")
        return
    end
    if not menuId then
        -- print("[CMS SAVE_NOEXIT] missing menuId")
        return
    end
    -- print("[CMS SAVE_NOEXIT] request")
    local payload = {}
    bufWriteU16(payload, menuId)
    enqueue(CMD_SAVE, payload, function(self, buf)
        if not buf or #buf < 3 then return end
        -- do
        --     local s = {}
        --     for i = 1, #buf do s[#s + 1] = tostring(buf[i]) end
        --     print("[CMS SAVE_NOEXIT RAW] " .. table.concat(s, ","))
        -- end
        local b = {offset = 1}
        for i = 1, #buf do b[i] = buf[i] end
        local gen = bufReadU16(b)
        local result = mspHelper.readU8(b)
        -- print(string.format("[CMS SAVE_NOEXIT] gen=%s result=%s", tostring(gen), tostring(result)))
        if checkMenuGen(gen) then
            if result == 0 then
                cms.lastStatus = "saved"
            else
                cms.lastStatus = "save_busy"
            end
        end
        cms.needsRebuild = true
    end, {apiname = "CMS:SAVE"})
end

local function sendAction(menuId, itemIndex)
    enqueue(CMD_ACTION, buildActionPayload(menuId, itemIndex), function(self, buf)
        local b = {offset = 1}
        for i = 1, #buf do b[i] = buf[i] end
        local gen = bufReadU16(b)
        local mid = bufReadU16(b)
        local idx = mspHelper.readU8(b)
        local result = mspHelper.readU8(b)
        local flags = bufReadU16(b)
        if checkMenuGen(gen) and mid == menuId then
            cms.lastStatus = "action:" .. tostring(result)
        end
        cms.needsRebuild = true
    end, {apiname = "CMS:ACTION:" .. tostring(menuId) .. ":" .. tostring(itemIndex)})
end

local function selectItem(menuId, itemIndex)
    cms.selected = {menuId = menuId, index = itemIndex}
    table.insert(cms.pending, function()
        requestStr(menuId, itemIndex)
        if (cms.info.caps & CMS_CAP_VALUE_META) ~= 0 then
            requestMeta(menuId, itemIndex)
        end
        requestValue(menuId, itemIndex)
    end)
    cms.needsRebuild = true
end

local function openMenu(menuId)
    if not menuId or menuId == 0 then return end
    cms.currentMenuId = menuId
    local menu = ensureMenu(menuId)
    menu.valuesRequested = false
    cms.needsRebuild = true
end

local function goBack()
    if #cms.stack > 0 then
        local last = table.remove(cms.stack)
        openMenu(last)
    end
end

local function requestInfo()
    enqueue(CMD_INFO, {}, function(self, buf)
        local b = {offset = 1}
        for i = 1, #buf do b[i] = buf[i] end
        cms.info.schemaMajor = mspHelper.readU8(b)
        cms.info.schemaMinor = mspHelper.readU8(b)
        cms.info.menuGen = bufReadU16(b)
        cms.info.rootMenuId = bufReadU16(b)
        cms.info.caps = bufReadU16(b)
        cms.info.maxPageItems = mspHelper.readU8(b) or MENU_PAGE_SIZE_DEFAULT
        cms.info.maxLabelLen = bufReadU16(b) or 31
        cms.info.ready = true
        resetMenuState()
        openMenu(cms.info.rootMenuId)
        cms.needsRebuild = true
    end, {apiname = "CMS:INFO"})
end

local function requestFeatureConfig()
    if cms.feature.checked then return end
    cms.feature.checked = true
    enqueue(MSP_FEATURE_CONFIG, {}, function(self, buf)
        if not buf or #buf < 4 then
            cms.feature.cmsEnabled = false
            return
        end
        local b = {offset = 1}
        for i = 1, #buf do b[i] = buf[i] end
        local features = bufReadU32(b) or 0
        cms.feature.cmsEnabled = ((features >> CMS_FEATURE_BIT) & 0x01) == 1
    end, {apiname = "FEATURE_CONFIG"})
end

local function decimalsFromScale(scale)
    if not scale or scale <= 1 then return 0 end
    local s = scale
    local d = 0
    while s > 1 and (s % 10 == 0) do
        s = s / 10
        d = d + 1
    end
    return d
end

local function updateSaveButton()
    if app.formNavigationFields and app.formNavigationFields['save'] and app.formNavigationFields['save'].enable then
        app.formNavigationFields['save']:enable(cms.dirty and not cms.loading)
    end
end

local function metaFor(menuId, itemIndex)
    return cms.meta[menuId .. ":" .. tostring(itemIndex)]
end

local function valueFor(menuId, itemIndex)
    return cms.values[menuId .. ":" .. tostring(itemIndex)]
end

local function strFor(menuId, itemIndex)
    return cms.strings[menuId .. ":" .. tostring(itemIndex)]
end

local function buildForm()
    form.clear()
    cms.fieldRefs = {}

    local w, _ = lcd.getWindowSize()
    local y = app.radio.linePaddingTop

    local menu = cms.currentMenuId and cms.menus[cms.currentMenuId] or nil
    local title = "Tools -> CMS Menu"

    app.formFields = {}
    app.formLines = {}
    app.formLineCnt = 0
    app.ui.fieldHeader(title)

    local sectionTitle = nil
    if menu then
        sectionTitle = menu.titleFull or menu.titleShort or ("Menu " .. tostring(menu.id))
    end
    if sectionTitle and sectionTitle ~= "" then
        local sectionLine = form.addLine("")
        form.addStaticText(sectionLine, {x = 0, y = y, w = w, h = app.radio.navbuttonHeight}, sectionTitle)
    end

    updateSaveButton()

    if #cms.stack > 0 then
        local backLine = form.addLine("Back")
        local backBtn = form.addButton(backLine, {x = 0, y = y, w = w, h = app.radio.navbuttonHeight}, {
            text = "Back",
            icon = nil,
            options = FONT_S,
            press = function() goBack() end
        })
    end

    if rfsuite.session and rfsuite.session.apiVersion and rfsuite.utils.apiVersionCompare and rfsuite.utils.apiVersionCompare("<", "12.09") then
        rfsuite.app.triggers.closeProgressLoader = true
        local infoLine = form.addLine("CMS")
        form.addStaticText(infoLine, {x = 0, y = y, w = w, h = app.radio.navbuttonHeight}, "CMS requires API >= 12.09")
        return
    end

    if not cms.feature.cmsEnabled then
        rfsuite.app.triggers.closeProgressLoader = true
        local infoLine = form.addLine("CMS")
        form.addStaticText(infoLine, {x = 0, y = y, w = w, h = app.radio.navbuttonHeight}, "CMS is not supported")
        return
    end

    if not cms.info.ready then
        local infoLine = form.addLine("CMS")
        form.addStaticText(infoLine, {x = 0, y = y, w = w, h = app.radio.navbuttonHeight}, "Waiting for CMS_INFO...")
        return
    end

    if not menu then
        local infoLine = form.addLine("Menu")
        form.addStaticText(infoLine, {x = 0, y = y, w = w, h = app.radio.navbuttonHeight}, "No menu loaded")
        return
    end

    if count == 0 then
        local emptyLine = form.addLine("Menu")
        form.addStaticText(emptyLine, {x = 0, y = y, w = w, h = app.radio.navbuttonHeight}, "Waiting for MENU_GET...")
        return
    end

    local maxIndex = menu.total or 0
    for idx = 0, (maxIndex - 1) do
        local item = menu.items[idx]
        if item then
            local label = item.short or ("Item " .. tostring(idx))
            local full = strFor(menu.id, idx)
            if full and full ~= "" then label = full end

            if item.itemType == 1 then
                local lineItem = form.addLine(label)
                local btn = form.addButton(lineItem, {x = 0, y = y, w = w, h = app.radio.navbuttonHeight}, {
                    text = label,
                    icon = nil,
                    options = FONT_S,
                    press = function()
                        table.insert(cms.stack, menu.id)
                        openMenu(item.submenuId)
                    end
                })
            elseif item.itemType == 0 then
                local lineItem = form.addLine(label)
                local btn = form.addButton(lineItem, {x = 0, y = y, w = w, h = app.radio.navbuttonHeight}, {
                    text = label,
                    icon = nil,
                    options = FONT_S,
                    press = function() goBack() end
                })
            elseif item.itemType == 3 then
                local lineItem = form.addLine(label)
                local btn = form.addButton(lineItem, {x = 0, y = y, w = w, h = app.radio.navbuttonHeight}, {
                    text = label,
                    icon = nil,
                    options = FONT_S,
                    press = function()
                        sendAction(menu.id, idx)
                    end
                })
            else
                local lineItem = form.addLine(label)
                local meta = metaFor(menu.id, idx)
                local valType = (meta and meta.valType) or item.valType
                local key = menu.id .. ":" .. tostring(idx)
                if valType == 3 then
                    local field = form.addBooleanField(lineItem, nil,
                        function()
                            local stagedVal = cms.staged[key]
                            if stagedVal ~= nil then return stagedVal ~= 0 end
                            local v = valueFor(menu.id, idx)
                            if v then return (v.value or 0) ~= 0 end
                            return false
                        end,
                        function(newValue)
                            cms.staged[key] = newValue and 1 or 0
                            cms.dirty = true
                            updateSaveButton()
                            cms.lastFocusKey = key
                        end
                    )
                    local v = valueFor(menu.id, idx)
                    if v and field.value then field:value((v.value or 0) ~= 0) end
                    cms.fieldRefs[key] = {field = field, isBool = true, scale = 1}
                else
                    local minValue = meta and meta.min or 0
                    local maxValue = meta and meta.max or 0
                    local stepValue = meta and meta.step or 1
                    local scale = 1
                    local decimals = 0
                    if valType == 5 and meta and meta.scale and meta.scale > 0 then
                        scale = meta.scale
                        decimals = decimalsFromScale(scale)
                    end
                    local field = form.addNumberField(lineItem, nil, minValue / scale, maxValue / scale,
                        function()
                            local stagedVal = cms.staged[key]
                            if stagedVal ~= nil then return stagedVal / scale end
                            local v = valueFor(menu.id, idx)
                            if v then return (v.value or 0) / scale end
                            return 0
                        end,
                        function(newValue)
                            local raw = math.floor((newValue or 0) * scale + 0.5)
                            cms.staged[key] = raw
                            cms.dirty = true
                            updateSaveButton()
                            cms.lastFocusKey = key
                        end,
                        stepValue / scale
                    )
                    field:decimals(decimals)
                    local v = valueFor(menu.id, idx)
                    if v and field.value then field:value((v.value or 0) / scale) end
                    cms.fieldRefs[key] = {field = field, isBool = false, scale = scale}
                end

                if not meta or not val then
                    local needMeta = (not meta) and (cms.info.caps & CMS_CAP_VALUE_META) ~= 0 and not (cms.req.meta[key] and cms.req.meta[key].done)
                    local needVal = (not val) and not (cms.req.value[key] and cms.req.value[key].done)
                    if needMeta or needVal then
                        table.insert(cms.pending, function()
                            if needMeta then requestMeta(menu.id, idx) end
                            if needVal then requestValue(menu.id, idx) end
                        end)
                    end
                    local ref = cms.fieldRefs[key]
                    if ref and ref.field and ref.field.enable then
                        ref.field:enable(false)
                    end
                end
            end
        end
    end

    if cms.loading then
        for _, ref in pairs(cms.fieldRefs) do
            if ref and ref.field and ref.field.enable then ref.field:enable(false) end
        end
    else
        for _, ref in pairs(cms.fieldRefs) do
            if ref and ref.field and ref.field.enable then ref.field:enable(true) end
        end
        if cms.lastFocusKey and cms.fieldRefs[cms.lastFocusKey] and cms.fieldRefs[cms.lastFocusKey].field and cms.fieldRefs[cms.lastFocusKey].field.focus then
            cms.fieldRefs[cms.lastFocusKey].field:focus()
        elseif menu and not cms.focusApplied[menu.id] then
            for _, ref in pairs(cms.fieldRefs) do
                if ref and ref.field and ref.field.focus then
                    ref.field:focus()
                    cms.focusApplied[menu.id] = true
                    break
                end
            end
        end
    end
end

local function openPage(pidx, title, script)
    app.lastIdx = pidx
    app.lastTitle = title
    app.lastScript = script

    rfsuite.app.triggers.closeProgressLoader = true
    cms.needsRebuild = true
    cms.lastStatus = nil
end

local function wakeup()
    rfsuite.app.triggers.closeProgressLoader = true

    if rfsuite.session and rfsuite.session.apiVersion and rfsuite.utils.apiVersionCompare and rfsuite.utils.apiVersionCompare("<", "12.09") then
        if cms.loader then
            cms.loader:close()
            cms.loader = nil
        end
        cms.loading = false
        return
    end

    local menu = cms.currentMenuId and cms.menus[cms.currentMenuId] or nil
    cms.loading = (not cms.info.ready) or (#cms.pending > 0) or (menu and not menu.loaded)

    if cms.loading and not cms.loader then
        cms.loaderStart = os.clock()
        cms.loaderAllowClose = false
        cms.loader = form.openProgressDialog({
            title = "CMS",
            message = "Loading...",
            close = function()
                if not cms.loaderAllowClose then
                    return false
                end
                cms.loader = nil
                return true
            end,
            wakeup = function() end
        })
    elseif (not cms.loading) and cms.loader then
        cms.loader:close()
        cms.loader = nil
    end
    if cms.loader then
        local pct = 0
        if cms.info.ready and menu and menu.total and menu.total > 0 then
            local count = 0
            for _, _ in pairs(menu.items) do count = count + 1 end
            pct = math.floor((count / menu.total) * 100)
            if pct > 100 then pct = 100 end
        end
        cms.loader:value(pct)
        if not cms.loaderAllowClose and (os.clock() - (cms.loaderStart or 0)) >= CMS_LOADER_TIMEOUT then
            cms.loaderAllowClose = true
        end
    end

    if cms.needsRebuild and tasks.msp.mspQueue:isProcessed() then
        if cms.loading and (os.clock() - (cms.lastBuildAt or 0)) < 0.2 then
            return
        end
        cms.needsRebuild = false
        buildForm()
        cms.lastBuildAt = os.clock()
    end

    if cms.wasLoading and not cms.loading then
        -- Re-enable fields after loading completes without forcing a rebuild
        for k, ref in pairs(cms.fieldRefs) do
            if ref and ref.field and ref.field.enable then
                local hasMeta = cms.meta[k] ~= nil or (ref.isBool ~= nil)
                local hasVal = cms.values[k] ~= nil
                if hasMeta and hasVal then
                    ref.field:enable(true)
                end
            end
        end
        updateSaveButton()
    end
    cms.wasLoading = cms.loading

    if not cms.feature.checked and tasks.msp.mspQueue:isProcessed() then
        requestFeatureConfig()
    end

    if cms.feature.cmsEnabled == false then
        if cms.loader then
            cms.loader:close()
            cms.loader = nil
        end
        cms.loading = false
        return
    end

    if not cms.info.requested and tasks.msp.mspQueue:isProcessed() then
        cms.info.requested = true
        requestInfo()
    end

    if #cms.pending > 0 and tasks.msp.mspQueue:isProcessed() then
        local now = os.clock()
        if (now - (cms.lastPendingAt or 0)) >= CMS_PENDING_DELAY then
            cms.lastPendingAt = now
            local nextFn = table.remove(cms.pending, 1)
            if nextFn then nextFn() end
        end
    end

    if cms.info.ready and cms.currentMenuId and tasks.msp.mspQueue:isProcessed() then
        local menu2 = ensureMenu(cms.currentMenuId)
        if not menu2.requested then
            menu2.requested = true
            requestMenuPage(menu2.id, 0, 0x01)
        end
        if menu2.loaded and not menu2.valuesRequested then
            menu2.valuesRequested = true
            for idx = 0, (menu2.total or 0) - 1 do
                local item = menu2.items[idx]
                if item and item.itemType == 2 then
                    local key = menu2.id .. ":" .. tostring(idx)
                    local needMeta = (cms.info.caps & CMS_CAP_VALUE_META) ~= 0 and not (cms.req.meta[key] and cms.req.meta[key].done)
                    local needVal = not (cms.req.value[key] and cms.req.value[key].done)
                    if needMeta or needVal then
                        table.insert(cms.pending, function()
                            if needMeta then requestMeta(menu2.id, idx) end
                            if needVal then requestValue(menu2.id, idx) end
                        end)
                    end
                end
            end
        end
    end
end

local function event(widget, category, value, x, y)

    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openMainMenuSub('tools')
        return true
    end
end

local function onNavMenu()
    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openMainMenuSub('tools')
    return true
end


return {
    openPage = openPage,
    wakeup = wakeup,
    onSaveMenu = function()
        local sentAny = false
        for k, v in pairs(cms.staged) do
            local mid, idx = k:match("^(%d+):(%d+)$")
            if mid and idx then
                table.insert(cms.pending, function()
                    sendValue(tonumber(mid), tonumber(idx), v)
                end)
                sentAny = true
            end
        end
        if sentAny then
            cms.lastStatus = "saving"
            cms.staged = {}
            cms.dirty = false
            updateSaveButton()
        end
        table.insert(cms.pending, function()
            sendSave(cms.currentMenuId)
        end)
    end,
    onReloadMenu = function()
        cms.info.requested = false
        cms.info.ready = false
        cms.info.menuGen = nil
        resetMenuState()
        cms.needsRebuild = true
    end,
    event = event,
    onNavMenu = onNavMenu,
    API = {},
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false}
}
