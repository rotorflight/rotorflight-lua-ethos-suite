local MSP_API = "ESC_PARAMETERS_AM32"
local toolName = "AM32"
moduleName = "am32"


local function getText(buffer, st, en)

    local tt = {}
    for i = st, en do
        local v = buffer[i]
        if v == 0 then break end
        table.insert(tt, string.char(v))
    end
    return table.concat(tt)
end

-- required by framework
local function getEscModel(self)

    local escModelName = ""
    escModelName = getText(self, 8, 19)
    return "AM32 " .. escModelName .. " "

end

-- required by framework
local function getEscVersion(self)
    return " "
end

-- required by framework
local function getEscFirmware(self)

   local version = "SW" .. getPageValue(self, 6) .. "." .. getPageValue(self, 7)
   return version

end

return {
    mspapi="ESC_PARAMETERS_AM32",
    toolName = toolName,
    image = "am32.jpg",
    powerCycle = false,
    getEscModel = getEscModel,
    getEscVersion = getEscVersion,
    getEscFirmware = getEscFirmware,
    mspHeaderBytes = mspHeaderBytes,
    esc4way = true,
}
