
return {
    layout = {
        cols =3,
        rows = 4,
        padding = 4
    },
    boxes = {
        --[[
        {col=1, row=1, type="telemetry", source="governor", title="GOVERNOR", unit="", color=nil, titlealign="left", titlecolor = "red", valuealign="right", titlepaddingleft = 10, transform=function(v) return rfsuite.utils.getGovernorState(v) end},
        {col=2, row=1, type="telemetry", source="current", title="CURRENT", unit="A", color="orange", transform = function(v) return v and math.floor(v / 100) * 100 end, titlealign="center", valuealign="center"},
        {col=3, row=1, type="telemetry", source="rpm", title="RPM", unit="RPM", color="red", transform="floor", titlealign="right", valuealign="left"},
        {col=1, row=2, colspan=2, type="text", value="PRE-FLIGHT", title="", unit="", color={0, 188, 4}, bgcolor="blue", titlealign="center", valuealign="center"},
        {col=3, row=2, type="image", value="widgets/dashboard/default_image.png", title="My Craft", titlecolor="black", bgcolor="white", imagepadding = 10, imagewidth=60, imageheight=60, imagealign="left", titlepos="bottom"}
        ]]--
        {col = 1, row = 1, rowspan=2,       type="modelimage"},
        {col = 1, row = 3,                  type = "telemetry", source = "rssi", title = "LQ", unit = "dB", titlepos = "bottom", transform="floor"},
        {col = 1, row = 4,                  type = "text", value = "00:00:00", title = "TIMER", titlepos = "bottom"},
        {col = 2, row = 1, rowspan = 2,     type = "telemetry", source = "voltage", title = "VOLTAGE", unit = "v", titlepos = "bottom"},
        {col = 2, row = 3, rowspan = 2,     type = "telemetry", source = "current", title = "CURRENT", unit = "A", titlepos = "bottom"},
        {col = 3, row = 1, rowspan = 2,     type = "telemetry", source = "fuel", title = "FUEL", unit = "%", titlepos = "bottom"},
        {col = 3, row = 3, rowspan = 2,     type = "telemetry", source = "fuel", title = "RPM", unit = "rpm", titlepos = "bottom"},
    }
}
