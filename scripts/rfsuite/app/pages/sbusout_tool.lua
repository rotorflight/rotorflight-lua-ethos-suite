local labels = {}
local fields = {}

local arg = {...}

local idx = arg[1]
if idx == nil then
 idx = rfsuite.app.lastIdx
end

local currentProfileChecked = false
local firstLoad = true
local minMaxIndex

local ch = idx 
local ch_str = "CH" .. tostring(ch + 1)
local offset = 6 * ch -- 6 bytes per channel

local servoCount = rfsuite.config.servoCount or 6
local motorCount = 1
if rfsuite.config.tailMode == 0 then
    motorCount = 2
end

local minmax = {}
minmax[1] = {min=1000,max=2000, sourceMax=24}     --Receiver
minmax[2] = {min=-1000,max=1000,sourceMax=24}    --Mixer
minmax[3] = {min=1000,max=2000, sourceMax=servoCount}     --Servo
minmax[4] = {min=0,max=1000, sourceMax=motorCount}        --Motor

local enableWakeup = false



local function wakeup()

    if enableWakeup == true then
    
        -- to avoid a page reload we contrain the field values using a wakeup call.
        -- we could use postEdit on the fields line - but this does not update until 
        -- you exit the field!
       local currentMin = minmax[minMaxIndex].min
       local currentMax = minmax[minMaxIndex].max
       local currentSourceMax = minmax[minMaxIndex].sourceMax
        
        -- set min and max values
       if rfsuite.app.Page.fields[2].value >= currentSourceMax then
       --      rfsuite.app.Page.fields[2].value = currentSourceMax
       end   

       -- handle min value
       if rfsuite.app.Page.fields[3].value <= currentMin then
             rfsuite.app.Page.fields[3].value = currentMin
       end
       if rfsuite.app.Page.fields[3].value >= currentMax then
             rfsuite.app.Page.fields[3].value = currentMax
       end
       
       -- handle max value
       if rfsuite.app.Page.fields[4].value >= currentMax then
             rfsuite.app.Page.fields[4].value = currentMax
       end       
       if rfsuite.app.Page.fields[4].value <= currentMin then
             rfsuite.app.Page.fields[4].value = currentMin
       end
    
    end    
end

-- function to set min and max value based on index.
local function setMinMaxIndex(self)
    minMaxIndex = math.floor(rfsuite.app.Page.fields[1].value)

    if firstLoad == true then
        firstLoad = false
    else
        -- default all values
       local currentMin = minmax[minMaxIndex].min
       local currentMax = minmax[minMaxIndex].max
       local currentSourceMax = minmax[minMaxIndex].sourceMax
         

       rfsuite.app.Page.fields[2].value = 0
       rfsuite.app.Page.fields[3].value = currentMin
       rfsuite.app.Page.fields[4].value = currentMax
    end
end


local function postLoad(self)

    setMinMaxIndex(self)

    rfsuite.app.triggers.isReady = true
    enableWakeup = true
end

local function onNavMenu(self)

    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(rfsuite.app.lastIdx, rfsuite.app.lastTitle, "sbusout.lua")

end

fields[#fields + 1] = {t = "Type", min = 0, max = 16, vals = {1 + offset}, table = {"Receiver", "Mixer", "Servo", "Motor"},  postEdit = function(self) self.setMinMaxIndex(self, true) end}
fields[#fields + 1] = {t = "Source", min = 0, max = 15, offset = 1, vals = { 2 + offset}}
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
    setMinMaxIndex = setMinMaxIndex,
    wakeup = wakeup,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = true}    
}
