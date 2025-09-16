local labels = {}
local fields = {}



fields[#fields + 1] = {t = "@i18n(app.modules.copyprofiles.profile_type)@", value = 0, min = 0, max = 1, table = {[0] = "@i18n(app.modules.copyprofiles.profile_type_pid)@", "@i18n(app.modules.copyprofiles.profile_type_rate)@"}}
fields[#fields + 1] = {t = "@i18n(app.modules.copyprofiles.source_profile)@", value = 0, min = 0, max = 5, tableIdxInc = -1, table = {"1", "2", "3", "4", "5", "6"}}
fields[#fields + 1] = {t = "@i18n(app.modules.copyprofiles.dest_profile)@", value = 0, min = 0, max = 5, tableIdxInc = -1, table = {"1", "2", "3", "4", "5", "6"}}

local doSave = false

local function onSaveMenu()
    local buttons = {{
        label = "@i18n(app.btn_ok)@",
        action = function()

            --- trigger a write here
            doSave = true

            return true
        end
    }, {
        label = "@i18n(app.btn_cancel)@",
        action = function()
            return true
        end
    }}
    local theTitle = "@i18n(app.modules.copyprofiles.msgbox_save)@"
    local theMsg
    if rfsuite.app.Page.extraMsgOnSave then
        theMsg = "@i18n(app.modules.copyprofiles.msgbox_msg)@" .. "\n\n" .. rfsuite.app.Page.extraMsgOnSave
    else    
        theMsg = "@i18n(app.modules.copyprofiles.msgbox_msg)@"
    end


    form.openDialog({
        width = nil,
        title = theTitle,
        message = theMsg,
        buttons = buttons,
        wakeup = function()
        end,
        paint = function()
        end,
        options = TEXT_LEFT
    })
end    


local function getDestinationPidProfile(self)
    local destPidProfile
    if (self.currentPidProfile < self.maxPidProfiles - 1) then
        destPidProfile = self.currentPidProfile + 1
    else
        destPidProfile = self.currentPidProfile - 1
    end
    return destPidProfile
end

local function openPage(idx, title, script, extra1, extra2, extra3, extra5, extra6)
    -- Initialize global UI state and clear form data
    rfsuite.app.uiState = rfsuite.app.uiStatus.pages
    rfsuite.app.triggers.isReady = false
    rfsuite.app.formFields = {}
    rfsuite.app.formLines = {}


    -- Fallback behavior if no custom openPage exists
    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    form.clear()
    rfsuite.session.lastPage = script

    local pageTitle = rfsuite.app.Page.pageTitle or title
    rfsuite.app.ui.fieldHeader(pageTitle)

    if rfsuite.app.Page.headerLine then
        local headerLine = form.addLine("")
        form.addStaticText(headerLine, {
            x = 0,
            y = rfsuite.app.radio.linePaddingTop,
            w = app.lcdWidth,
            h = rfsuite.app.radio.navbuttonHeight
        }, rfsuite.app.Page.headerLine)
    end

    rfsuite.app.formLineCnt = 0

    if fields then
        for i, field in ipairs(fields) do
            local label = labels
            local version = rfsuite.session.apiVersion
            local valid = (field.apiversion    == nil or field.apiversion    <= version) and
                          (field.apiversionlt  == nil or field.apiversionlt  >  version) and
                          (field.apiversiongt  == nil or field.apiversiongt  <  version) and
                          (field.apiversionlte == nil or field.apiversionlte >= version) and
                          (field.apiversiongte == nil or field.apiversiongte <= version) and
                          (field.enablefunction == nil or field.enablefunction())

            if field.hidden ~= true and valid then
                rfsuite.app.ui.fieldLabel(field, i, label)
                if field.type == 0 then
                    rfsuite.app.ui.fieldStaticText(i)
                elseif field.table or field.type == 1 then
                    rfsuite.app.ui.fieldChoice(i)
                elseif field.type == 2 then
                    rfsuite.app.ui.fieldNumber(i)
                elseif field.type == 3 then
                    rfsuite.app.ui.fieldText(i)
                else
                    rfsuite.app.ui.fieldNumber(i)
                end
            else
                rfsuite.app.formFields[i] = {}
            end
        end
    end

    rfsuite.app.triggers.closeProgressLoader = true
end 

local function wakeup()
    if doSave == true then
        rfsuite.app.ui.progressDisplaySave()
        rfsuite.app.triggers.isSavingFake = true

        local payload = {}
        payload[1] = fields[1].value
        payload[2] = fields[3].value
        payload[3] = fields[2].value


        if payload[2] == payload[3] then
            rfsuite.utils.log("Source and destination profiles are the same. No need to copy.","info")
            doSave = false
        end

        local message = {
            command = 183, -- COPY PROFILE
            payload = payload,
            processReply = function(self, buf)
                rfsuite.app.triggers.closeProgressLoader = true
            end,
            simulatorResponse = {}
        }
        rfsuite.tasks.msp.mspQueue:add(message)


        doSave = false
    end     
end    

return {
    -- leaving this api as legacy for now due to unsual read/write scenario.
    -- to change it will mean a bit of a rewrite so leaving it for now.
    --write = 183, -- MSP_COPY_PROFILE
    reboot = false,
    eepromWrite = true,
    title = "Copy",
    openPage = openPage,
    wakeup = wakeup,
    onSaveMenu = onSaveMenu,
    labels = labels,
    fields = fields,
    getDestinationPidProfile = getDestinationPidProfile,
    API = {},
    navButtons = {
        menu = true,
        save = true,
        reload = false,
        tool = false,
        help = true
    },
}
