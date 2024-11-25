local labels = {}
local fields = {}

local arg = {...}

local idx = arg[1]

local currentProfileChecked = false

local ch = idx 
local ch_str = "CH" .. tostring(ch + 1)
local offset = 6 * ch -- 6 bytes per channel


local minmax = {}
minmax[0] = {min=1000,max=2000}     --Receiver
minmax[1] = {min=-1000,max=1000}    --Mixer
minmax[2] = {min=1000,max=2000}     --Servo
minmax[3] = {min=0,max=1000}        --Motor

local enableWakeup = false

local function wakeup()

    if enableWakeup == true then

        local value = rfsuite.app.Page.fields[1].value
       
            for i,v in ipairs(minmax) do
                    if i == value then      
                        rfsuite.app.formFields[2]:setMinimum(10)
                        rfsuite.app.formFields[3]:setMaximum(20)
                    end
            end
        
    end    
end


local function postLoad(self)
    rfsuite.app.triggers.isReady = true
    enableWakeup = true
end

local function onNavMenu(self)

    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(rfsuite.app.lastIdx, rfsuite.app.lastTitle, "sbusout.lua")

end

fields[#fields + 1] = {t = "Type", min = 0, max = 16, vals = {1 + offset}, table = {[0] = "Receiver", "Mixer", "Servo", "Motor"}}
fields[#fields + 1] = {t = "Source Channel", min = 0, max = 15, offset = 1, vals = { 2 + offset}}
fields[#fields + 1] = {t = "Min", min = -2000, max = 2000, vals = {3 + offset,4 + offset}}
fields[#fields + 1] = {t = "Max",  min = -2000, max = 2000, vals = {5 + offset,6 + offset}}


return {
    read = 152, 
    write = 153, 
    title = "SBUS Output",
    reboot = false,
    eepromWrite = true,
    minBytes = nil,
    labels = labels,
    simulatorResponse = {1, 0, 24, 252, 232, 3, 1, 1, 24, 252, 232, 3, 1, 2, 24, 252, 232, 3, 1, 3, 24, 252, 232, 3, 1, 0, 24, 252, 232, 3, 1, 1, 24, 252, 232, 3, 1, 2, 24, 252, 232, 3, 1, 3, 24, 252, 232, 3, 1, 0, 24, 252, 232, 3, 1, 1, 24, 252, 232, 3, 1, 2, 24, 252, 232, 3, 1, 3, 24, 252, 232, 3, 1, 0, 24, 252, 232, 3, 1, 1, 24, 252, 232, 3, 1, 2, 24, 252, 232, 3, 1, 3, 24, 252, 232, 3, 1, 0, 24, 252, 232, 3, 1, 1, 24, 252, 232, 3, 50},
    fields = fields,
    postLoad = postLoad,
    onNavMenu = onNavMenu, 
    wakeup = wakeup,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = true}    
}
