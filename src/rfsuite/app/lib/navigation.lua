--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local navigation = {}

local function getSections(mainMenu)
    if not mainMenu or type(mainMenu.sections) ~= "table" then return nil end
    return mainMenu.sections
end

function navigation.findSection(mainMenu, sectionId)
    if not sectionId then return nil, nil end
    local sections = getSections(mainMenu)
    if not sections then return nil, nil end

    for idx, section in ipairs(sections) do
        if section.id == sectionId then return section, idx end
    end

    return nil, nil
end

function navigation.sectionExists(mainMenu, sectionId)
    local _, idx = navigation.findSection(mainMenu, sectionId)
    return idx ~= nil
end

function navigation.resolveMenuContext(mainMenu, lastMenuId, defaultSectionId)
    if navigation.sectionExists(mainMenu, lastMenuId) then return lastMenuId end
    if navigation.sectionExists(mainMenu, defaultSectionId) then return defaultSectionId end
    return nil
end

local function cloneStack(stack)
    local out = {}
    if type(stack) ~= "table" then return out end
    for i = 1, #stack do out[i] = stack[i] end
    return out
end

function navigation.getReturnStack(appState)
    if not appState then return {} end
    return cloneStack(appState.menuContextStack)
end

function navigation.setReturnStack(appState, stack)
    if not appState then return {} end
    appState.menuContextStack = cloneStack(stack)
    return appState.menuContextStack
end

function navigation.clearReturnStack(appState)
    if not appState then return {} end
    appState.menuContextStack = {}
    return appState.menuContextStack
end

function navigation.pushReturnContext(appState, ctx)
    local stack = navigation.getReturnStack(appState)
    if type(ctx) ~= "table" or type(ctx.script) ~= "string" then
        return stack
    end
    local top = stack[#stack]
    if not (top and top.idx == ctx.idx and top.title == ctx.title and top.script == ctx.script) then
        local entry = {}
        for k, v in pairs(ctx) do
            entry[k] = v
        end
        stack[#stack + 1] = entry
    end
    return navigation.setReturnStack(appState, stack)
end

function navigation.popReturnContext(appState)
    local stack = navigation.getReturnStack(appState)
    local target = stack[#stack]
    if target then
        stack[#stack] = nil
    end
    navigation.setReturnStack(appState, stack)
    return target, stack
end

return navigation
