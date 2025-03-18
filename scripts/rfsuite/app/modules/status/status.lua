local fields = {}
local labels = {}
local fcStatus = {}
local dataflashSummary = {}
local wakeupScheduler = os.clock()
local status = {}
local summary = {}
local triggerEraseDataFlash = false
local enableWakeup = false

local displayType = 0
local disableType = false

local w, h = rfsuite.utils.getWindowSize()
local buttonW = 100
local buttonWs = buttonW - (buttonW * 20) / 100
local x = w - 15

local displayPos = {x = x - buttonW - buttonWs - 5 - buttonWs, y = rfsuite.app.radio.linePaddingTop, w = 200, h = rfsuite.app.radio.navbuttonHeight}


local mspapi = {
    api = {
        [1] = nil,
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = rfsuite.i18n.get("app.modules.status.arming_flags"), value = "-", type = displayType, disable = disableType, position = displayPos},
            {t = rfsuite.i18n.get("app.modules.status.dataflash_free_space"), value = "-", type = displayType, disable = disableType, position = displayPos},
            {t = rfsuite.i18n.get("app.modules.status.real_time_load"), value = "-", type = displayType, disable = disableType, position = displayPos},
            {t = rfsuite.i18n.get("app.modules.status.cpu_load"), value = "-", type = displayType, disable = disableType, position = displayPos}
        }
    }                 
}

local function getStatus()
    local message = {
        command = 101, -- MSP_STATUS
        processReply = function(self, buf)

            buf.offset = 12
            status.realTimeLoad = rfsuite.tasks.msp.mspHelper.readU16(buf)
            status.cpuLoad = rfsuite.tasks.msp.mspHelper.readU16(buf)
            buf.offset = 18
            status.armingDisableFlags = rfsuite.tasks.msp.mspHelper.readU32(buf)
            buf.offset = 24
            status.profile = rfsuite.tasks.msp.mspHelper.readU8(buf)
            buf.offset = 26
            status.rateProfile = rfsuite.tasks.msp.mspHelper.readU8(buf)


        end,
        simulatorResponse = {240, 1, 124, 0, 35, 0, 0, 0, 0, 0, 0, 224, 1, 10, 1, 0, 26, 0, 0, 0, 0, 0, 2, 0, 6, 0, 6, 1, 4, 1}
    }

    rfsuite.tasks.msp.mspQueue:add(message)
end

local function getDataflashSummary()
    local message = {
        command = 70, -- MSP_DATAFLASH_SUMMARY
        processReply = function(self, buf)

            local flags = rfsuite.tasks.msp.mspHelper.readU8(buf)
            summary.ready = (flags & 1) ~= 0
            summary.supported = (flags & 2) ~= 0
            summary.sectors = rfsuite.tasks.msp.mspHelper.readU32(buf)
            summary.totalSize = rfsuite.tasks.msp.mspHelper.readU32(buf)
            summary.usedSize = rfsuite.tasks.msp.mspHelper.readU32(buf)

        end,
        simulatorResponse = {3, 1, 0, 0, 0, 0, 4, 0, 0, 0, 3, 0, 0}
    }
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function eraseDataflash()
    local message = {
        command = 72, -- MSP_DATAFLASH_ERASE
        processReply = function(self, buf)

            summary = {}

            -- blank out vars so that we actually are aware that it updated
            rfsuite.app.formFields[1]:value("")
            rfsuite.app.formFields[2]:value("")
            rfsuite.app.formFields[3]:value("")
            rfsuite.app.formFields[4]:value("")
        end,
        simulatorResponse = {}
    }
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function postLoad(self)

    getStatus()
    getDataflashSummary()
    rfsuite.app.triggers.isReady = true
    enableWakeup = true

    rfsuite.app.triggers.closeProgressLoader = true
end

local function postRead(self)
    rfsuite.utils.log("postRead","debug")
end

local function armingDisableFlagsToString(flags)
    local t = ""
    for i = 0, 25 do
        if (flags & (1 << i)) ~= 0 then
            if t ~= "" then t = t .. ", " end
            if i == 0 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_0") end
            if i == 1 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_1") end
            if i == 2 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_2") end
            if i == 3 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_3") end
            if i == 4 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_4") end
            if i == 5 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_5") end
            -- if i == 6 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_6") end
            if i == 7 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_7") end
            if i == 8 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_8") end
            if i == 9 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_9") end
            if i == 10 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_10") end
            if i == 11 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_11") end
            if i == 12 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_12") end
            if i == 13 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_13") end
            if i == 14 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_14") end
            if i == 15 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_15") end
            if i == 16 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_16") end
            if i == 17 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_17") end
            if i == 18 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_18") end
            if i == 19 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_19") end
            if i == 20 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_20") end
            if i == 21 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_21") end
            if i == 22 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_22") end
            if i == 23 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_23") end
            if i == 24 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_24") end
            if i == 25 then t = t .. rfsuite.i18n.get("app.modules.status.arming_disable_flag_25") end
        end
    end

    if t == "" then t = rfsuite.i18n.get("app.modules.status.ok") end
    return t
end

local function getFreeDataflashSpace()
    if not summary.supported then return rfsuite.i18n.get("app.modules.status.unsupported") end
    local freeSpace = summary.totalSize - summary.usedSize
    return string.format("%.1f " .. rfsuite.i18n.get("app.modules.status.megabyte"), freeSpace / (1024 * 1024))
end

local function wakeup()

    -- prevent wakeup running until after initialised
    if enableWakeup == false then return end

    if triggerEraseDataFlash == true then
        rfsuite.app.audio.playEraseFlash = true
        triggerEraseDataFlash = false

        rfsuite.app.ui.progressDisplay(rfsuite.i18n.get("app.modules.status.erasing"), rfsuite.i18n.get("app.modules.status.erasing_dataflash"))
        rfsuite.app.Page.eraseDataflash()
        rfsuite.app.triggers.isReady = true
    end

    if triggerEraseDataFlash == false then
        local now = os.clock()
        if (now - wakeupScheduler) >= 2 then
            wakeupScheduler = now
            firstRun = false
            if rfsuite.tasks.msp.mspQueue:isProcessed() then

                getStatus()
                getDataflashSummary()

                if status.armingDisableFlags ~= nil then
                    local value = armingDisableFlagsToString(status.armingDisableFlags)
                    rfsuite.app.formFields[1]:value(value)
                end

                if summary.supported == true then
                    local value = getFreeDataflashSpace()
                    rfsuite.app.formFields[2]:value(value)
                end

                if status.realTimeLoad ~= nil then
                    local value = math.floor(status.realTimeLoad / 10)
                    rfsuite.app.formFields[3]:value(tostring(value) .. "%")
                    if value >= 60 then rfsuite.app.formFields[4]:color(RED) end
                end
                if status.cpuLoad ~= nil then
                    local value = status.cpuLoad / 10
                    rfsuite.app.formFields[4]:value(tostring(value) .. "%")
                    if value >= 60 then rfsuite.app.formFields[4]:color(RED) end
                end

            end
        end
        if (now - wakeupScheduler) >= 1 then
            rfsuite.app.triggers.closeProgressLoader = true
        end
    end

end

local function onToolMenu(self)

    local buttons = {{
        label = rfsuite.i18n.get("app.btn_ok_long"),
        action = function()

            -- we cant launch the loader here to se rely on the modules
            -- wakup function to do this
            triggerEraseDataFlash = true
            return true
        end
    }, {
        label = rfsuite.i18n.get("app.btn_cancel"),
        action = function()
            return true
        end
    }}
    local message
    local title

    title = rfsuite.i18n.get("app.modules.status.erase")
    message = rfsuite.i18n.get("app.modules.status.erase_prompt")

    form.openDialog({
        width = nil,
        title = title,
        message = message,
        buttons = buttons,
        wakeup = function()
        end,
        paint = function()
        end,
        options = TEXT_LEFT
    })

end

return {
    mspapi = mspapi,
    reboot = false,
    eepromWrite = false,
    minBytes = 0,
    wakeup = wakeup,
    refreshswitch = false,
    simulatorResponse = {},
    postLoad = postLoad,
    postRead = postRead,
    eraseDataflash = eraseDataflash,
    onToolMenu = onToolMenu,
    navButtons = {
        menu = true,
        save = false,
        reload = false,
        tool = true,
        help = true
    },
    API = {},
}
