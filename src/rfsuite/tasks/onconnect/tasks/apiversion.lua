--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local apiversion = {}

local mspCallMade = false

local function version_ge(a, b)
    local function split(v)
        local t = {}
        for part in tostring(v):gmatch("(%d+)") do t[#t + 1] = tonumber(part) end
        return t
    end
    local A, B = split(a), split(b)
    local len = math.max(#A, #B)
    for i = 1, len do
        local ai = A[i] or 0
        local bi = B[i] or 0
        if ai < bi then return false end
        if ai > bi then return true end
    end
    return true
end

function apiversion.wakeup()
    if rfsuite.session.apiVersion == nil and mspCallMade == false then
        mspCallMade = true

        local originalProto = rfsuite.config.mspProtocolVersion
        local probeProto = (rfsuite.config.msp and rfsuite.config.msp.probeProtocol) or 1
        rfsuite.config.mspProtocolVersion = probeProto

        local API = rfsuite.tasks.msp.api.load("API_VERSION")
        API.setCompleteHandler(function(self, buf)
            local version = API.readVersion()

            local restoreProto = originalProto

            if version then
                local apiVersionString = tostring(version)

                if not rfsuite.utils.stringInArray(rfsuite.config.supportedMspApiVersion, apiVersionString) then
                    rfsuite.utils.log("Incompatible API version detected: " .. apiVersionString, "info")
                    rfsuite.utils.log("Incompatible API version detected: " .. apiVersionString, "connect")
                    rfsuite.session.apiVersionInvalid = true
                    rfsuite.session.apiVersion = version

                    rfsuite.config.mspProtocolVersion = restoreProto
                    return
                end

                local wantProto = probeProto
                local policy = rfsuite.config.msp or {}
                if policy.allowAutoUpgrade and policy.maxProtocol and policy.maxProtocol >= 2 then if policy.v2MinApiVersion and version_ge(apiVersionString, policy.v2MinApiVersion) then wantProto = 2 end end

                if wantProto ~= rfsuite.config.mspProtocolVersion then
                    rfsuite.config.mspProtocolVersion = wantProto
                    rfsuite.session.mspProtocolVersion = wantProto

                    if rfsuite.tasks.msp.common.setProtocolVersion then
                        pcall(rfsuite.tasks.msp.common.setProtocolVersion, wantProto)
                    elseif rfsuite.tasks.msp.reset then

                        pcall(rfsuite.tasks.msp.reset)
                    end

                    rfsuite.utils.log(string.format("MSP protocol upgraded to v%d (api %s)", wantProto, apiVersionString), "info")
                    rfsuite.utils.log(string.format("MSP protocol upgraded to v%d (api %s)", wantProto, apiVersionString), "connect")
                else

                    rfsuite.config.mspProtocolVersion = wantProto
                end
            else

                rfsuite.config.mspProtocolVersion = restoreProto
                rfsuite.utils.log(string.format("MSP protocol restored to v%d", restoreProto), "info")
                rfsuite.utils.log(string.format("MSP protocol restored to v%d", restoreProto), "connect")
            end

            rfsuite.session.apiVersion = version
            rfsuite.session.apiVersionInvalid = false
            if rfsuite.session.apiVersion then 
                rfsuite.utils.playFileCommon("beep.wav")
                rfsuite.utils.log("API version: " .. rfsuite.session.apiVersion, "info") 
                rfsuite.utils.log("API version: " .. rfsuite.session.apiVersion, "connect") 
            end
        end)
        API.setUUID("22a683cb-db0e-439f-8d04-04687c9360f3")
        API.read()
    end
end

function apiversion.reset()
    rfsuite.session.apiVersion = nil
    rfsuite.session.apiVersionInvalid = nil
    mspCallMade = false
end

function apiversion.isComplete() if rfsuite.session.apiVersion ~= nil then return true end end

return apiversion
