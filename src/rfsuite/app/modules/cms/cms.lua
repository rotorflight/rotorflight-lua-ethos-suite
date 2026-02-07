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

local CMS_CAP_READONLY_ARMED = (1 << 0)
local CMS_CAP_ACTION = (1 << 3)
local CMS_CAP_STR_GET = (1 << 4)
local CMS_CAP_VALUE_META = (1 << 5)

local MENU_PAGE_SIZE_DEFAULT = 8

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
    menus = {},
    stack = {},
    currentMenuId = nil,
    strings = {},
    values = {},
    meta = {},
    selected = {menuId = nil, index = nil},
    pending = {},
    lastError = nil,
    lastStatus = nil,
    _uuidSeq = 0
}

local function log(msg)
    if utils and utils.log then utils.log(msg, "debug") end
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

local function buildMenuGetPayload(menuId, startIndex, count)
    local payload = {}
    bufWriteU16(payload, menuId or 0)
    payload[#payload + 1] = startIndex or 0
    payload[#payload + 1] = count or cms.info.maxPageItems or MENU_PAGE_SIZE_DEFAULT
    payload[#payload + 1] = 0 -- options (reserved)
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
    for i = 1, (returned or 0) do
        local itemIndex = mspHelper.readU8(b)
        local itemType = mspHelper.readU8(b)
        local valType = mspHelper.readU8(b)
        local flags = bufReadU16(b)
        local submenuId = bufReadU16(b)
        local label = bufReadStr(b)
        items[#items + 1] = {
            index = itemIndex,
            itemType = itemType,
            valType = valType,
            flags = flags,
            submenuId = submenuId,
            short = label
        }
    end

    return {
        menuGen = menuGen,
        menuId = menuId,
        startIndex = startIndex,
        maxItems = maxItems,
        total = total,
        returned = returned,
        title = title,
        items = items
    }
end

local function requestMenuPage(menuId, startIndex)
    local payload = buildMenuGetPayload(menuId, startIndex, cms.info.maxPageItems or MENU_PAGE_SIZE_DEFAULT)

    enqueue(CMD_MENU_GET, payload, function(self, buf)
        local parsed = parseMenuGet(buf or {})
        if not parsed.menuId then return end
        if not checkMenuGen(parsed.menuGen) then return end

        local menu = ensureMenu(parsed.menuId)
        menu.total = parsed.total
        menu.nextStart = (parsed.startIndex or 0) + (parsed.returned or 0)
        menu.loaded = (menu.nextStart >= (menu.total or 0))
        menu.titleShort = parsed.title

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
                requestMenuPage(menu.id, menu.nextStart)
            end)
        end
    end, {apiname = "CMS:MENU_GET:" .. tostring(menuId) .. ":" .. tostring(startIndex or 0)})
end

local function requestStr(menuId, itemIndex)
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
        cms.needsRebuild = true
    end, {apiname = "CMS:STR_GET:" .. tostring(menuId) .. ":" .. tostring(itemIndex)})
end

local function requestMeta(menuId, itemIndex)
    enqueue(CMD_VALUE_META_GET, buildValueMetaGetPayload(menuId, itemIndex), function(self, buf)
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
        end
        cms.needsRebuild = true
    end, {apiname = "CMS:VALUE_META_GET:" .. tostring(menuId) .. ":" .. tostring(itemIndex)})
end

local function requestValue(menuId, itemIndex)
    enqueue(CMD_VALUE_GET, buildValueGetPayload(menuId, itemIndex), function(self, buf)
        local b = {offset = 1}
        for i = 1, #buf do b[i] = buf[i] end
        local gen = bufReadU16(b)
        local mid = bufReadU16(b)
        local idx = mspHelper.readU8(b)
        local val = bufReadU32(b)
        local flags = bufReadU16(b)
        if checkMenuGen(gen) and mid == menuId then
            cms.values[mid .. ":" .. tostring(idx)] = {value = val, flags = flags}
        end
        cms.needsRebuild = true
    end, {apiname = "CMS:VALUE_GET:" .. tostring(menuId) .. ":" .. tostring(itemIndex)})
end

local function sendValue(menuId, itemIndex, value)
    enqueue(CMD_VALUE_SET, buildValueSetPayload(menuId, itemIndex, value), function(self, buf)
        local b = {offset = 1}
        for i = 1, #buf do b[i] = buf[i] end
        local gen = bufReadU16(b)
        local mid = bufReadU16(b)
        local idx = mspHelper.readU8(b)
        local applied = bufReadU32(b)
        local result = mspHelper.readU8(b)
        local flags = bufReadU16(b)
        if checkMenuGen(gen) and mid == menuId then
            cms.values[mid .. ":" .. tostring(idx)] = {value = applied, flags = flags, result = result}
        end
        cms.lastStatus = "saved"
        cms.needsRebuild = true
    end, {apiname = "CMS:VALUE_SET:" .. tostring(menuId) .. ":" .. tostring(itemIndex)})
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
    ensureMenu(menuId)
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

    local w, _ = lcd.getWindowSize()
    local y = app.radio.linePaddingTop

    local menu = cms.currentMenuId and cms.menus[cms.currentMenuId] or nil
    local title = "CMS Menu"
    if menu then
        title = menu.titleFull or menu.titleShort or ("Menu " .. tostring(menu.id))
    end

    local line = form.addLine(title)

    local buttonW = 100
    local buttonWs = buttonW - (buttonW * 20) / 100
    local x = w - 10

    app.formNavigationFields = app.formNavigationFields or {}

    app.formNavigationFields['menu'] = form.addButton(line, {x = x - 5 - buttonW - buttonWs, y = y, w = buttonW, h = app.radio.navbuttonHeight}, {
        text = "@i18n(app.navigation_menu)@",
        icon = nil,
        options = FONT_S,
        press = function()
            app.ui.openMainMenu()
        end
    })

    app.formNavigationFields['reload'] = form.addButton(line, {x = x - buttonWs, y = y, w = buttonWs, h = app.radio.navbuttonHeight}, {
        text = "@i18n(app.navigation_reload)@",
        icon = nil,
        options = FONT_S,
        press = function()
            cms.info.requested = false
            cms.info.ready = false
            cms.info.menuGen = nil
            resetMenuState()
            cms.needsRebuild = true
        end
    })

    if #cms.stack > 0 then
        local backLine = form.addLine("Back")
        form.addButton(backLine, {x = 0, y = y, w = w, h = app.radio.navbuttonHeight}, {
            text = "Back",
            icon = nil,
            options = FONT_S,
            press = function() goBack() end
        })
    end

    local status = cms.lastStatus or "idle"
    local statusLine = form.addLine("Status")
    form.addStaticText(statusLine, {x = 0, y = y, w = w, h = app.radio.navbuttonHeight}, status)

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

    local count = 0
    for _, _ in pairs(menu.items) do count = count + 1 end
    local infoLine = form.addLine("Items")
    form.addStaticText(infoLine, {x = 0, y = y, w = w, h = app.radio.navbuttonHeight}, tostring(count))

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
                form.addButton(lineItem, {x = 0, y = y, w = w, h = app.radio.navbuttonHeight}, {
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
                form.addButton(lineItem, {x = 0, y = y, w = w, h = app.radio.navbuttonHeight}, {
                    text = label,
                    icon = nil,
                    options = FONT_S,
                    press = function() goBack() end
                })
            elseif item.itemType == 3 then
                local lineItem = form.addLine(label)
                form.addButton(lineItem, {x = 0, y = y, w = w, h = app.radio.navbuttonHeight}, {
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
                local val = valueFor(menu.id, idx)
                local valType = (meta and meta.valType) or item.valType
                if valType == 3 then
                    form.addBooleanField(lineItem, nil,
                        function()
                            if val then return (val.value or 0) ~= 0 end
                            return false
                        end,
                        function(newValue)
                            sendValue(menu.id, idx, newValue and 1 or 0)
                        end
                    )
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
                    form.addNumberField(lineItem, nil, minValue / scale, maxValue / scale,
                        function()
                            if val then return (val.value or 0) / scale end
                            return 0
                        end,
                        function(newValue)
                            local raw = math.floor((newValue or 0) * scale + 0.5)
                            sendValue(menu.id, idx, raw)
                        end,
                        stepValue / scale
                    ):decimals(decimals)
                end

                if not meta or not val then
                    table.insert(cms.pending, function()
                        if not meta and (cms.info.caps & CMS_CAP_VALUE_META) ~= 0 then
                            requestMeta(menu.id, idx)
                        end
                        if not val then
                            requestValue(menu.id, idx)
                        end
                    end)
                end
            end
        end
    end
end

local function openPage(pidx, title, script)
    app.lastIdx = pidx
    app.lastTitle = title
    app.lastScript = script

    cms.needsRebuild = true
    cms.lastStatus = nil
end

local function wakeup()
    if cms.needsRebuild and tasks.msp.mspQueue:isProcessed() then
        cms.needsRebuild = false
        buildForm()
    end

    if not cms.info.requested and tasks.msp.mspQueue:isProcessed() then
        cms.info.requested = true
        requestInfo()
    end

    if #cms.pending > 0 and tasks.msp.mspQueue:isProcessed() then
        local nextFn = table.remove(cms.pending, 1)
        if nextFn then nextFn() end
    end

    if cms.info.ready and cms.currentMenuId and tasks.msp.mspQueue:isProcessed() then
        local menu = ensureMenu(cms.currentMenuId)
        if not menu.requested then
            menu.requested = true
            requestMenuPage(menu.id, 0)
        end
    end
end

return {
    openPage = openPage,
    wakeup = wakeup,
    onNavMenu = function() app.ui.openMainMenu() end,
    API = {},
    navButtons = {menu = true, save = false, reload = true, tool = false, help = false}
}
