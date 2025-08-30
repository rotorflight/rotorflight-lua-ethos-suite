local function openPage(pidx, title, script)

    if rfsuite.utils.apiVersionCompare(">=", "12.09") then
        -- load new menu with 3 pages
        rfsuite.app.ui.openPage(pidx, title, "profile_governor/profile_governor.lua")        
    else
        -- load legacy single page rf2.2
        rfsuite.app.ui.openPage(pidx, title, "profile_governor/profile_governor_legacy.lua")
    end

end

return {
    pages = nil, 
    openPage = openPage,
    event = nil,
    wakeup = nil,  
}