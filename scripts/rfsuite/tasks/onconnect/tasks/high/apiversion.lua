local rfsuite = require("rfsuite")

local apiversion = {}

local mspCallMade = false

-- local helper: "12.09" >= "12.09" etc.
local function version_ge(a, b)
    local function split(v)
        local t = {}
        for part in tostring(v):gmatch("(%d+)") do t[#t+1] = tonumber(part) end
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
    return true -- equal
end

function apiversion.wakeup()
    if rfsuite.session.apiVersion == nil and mspCallMade == false then
        mspCallMade = true

        -- 1) Force probe over MSPv1 regardless of current setting
        local originalProto = rfsuite.config.mspProtocolVersion
        local probeProto = (rfsuite.config.msp and rfsuite.config.msp.probeProtocol) or 1
        rfsuite.config.mspProtocolVersion = probeProto

        local API = rfsuite.tasks.msp.api.load("API_VERSION")
        API.setCompleteHandler(function(self, buf)
            local version = API.readVersion()

            -- restore whatever we had before deciding
            local restoreProto = originalProto

            if version then
                local apiVersionString = tostring(version)

                -- keep your existing supported-version check
                if not rfsuite.utils.stringInArray(rfsuite.config.supportedMspApiVersion, apiVersionString) then
                    rfsuite.utils.log("Incompatible API version detected: " .. apiVersionString, "info")
                    rfsuite.session.apiVersionInvalid = true
                    rfsuite.session.apiVersion = version
                    -- restore probe protocol to original on failure path
                    rfsuite.config.mspProtocolVersion = restoreProto
                    return
                end

                -- 2) Decide target protocol
                local wantProto = probeProto
                local policy = rfsuite.config.msp or {}
                if policy.allowAutoUpgrade and policy.maxProtocol and policy.maxProtocol >= 2 then
                    if policy.v2MinApiVersion and version_ge(apiVersionString, policy.v2MinApiVersion) then
                        wantProto = 2
                    end
                end

                -- 3) Apply if changed
                if wantProto ~= rfsuite.config.mspProtocolVersion then
                    rfsuite.config.mspProtocolVersion = wantProto
                    rfsuite.session.mspProtocolVersion = wantProto -- session-visible

                    -- If MSP layer exposes helpers, call them opportunistically
                    if rfsuite.tasks.msp.setProtocol then
                        pcall(rfsuite.tasks.msp.setProtocol, wantProto)
                    elseif rfsuite.tasks.msp.reset then
                        -- Some stacks need a reset/reload to pick up protocol
                        pcall(rfsuite.tasks.msp.reset)
                    end

                    rfsuite.utils.log(string.format("MSP protocol upgraded to v%d (api %s)", wantProto, apiVersionString), "info")
                else
                    -- No change: restore original if needed
                    rfsuite.config.mspProtocolVersion = wantProto
                end
            else
                -- Could not read version; restore original
                rfsuite.config.mspProtocolVersion = restoreProto
            end

            -- 4) Store/announce API version
            rfsuite.session.apiVersion = version
            rfsuite.session.apiVersionInvalid = false
            if rfsuite.session.apiVersion then
                rfsuite.utils.log("API version: " .. rfsuite.session.apiVersion, "info")
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

function apiversion.isComplete()
    if rfsuite.session.apiVersion ~= nil then return true end
end

return apiversion
