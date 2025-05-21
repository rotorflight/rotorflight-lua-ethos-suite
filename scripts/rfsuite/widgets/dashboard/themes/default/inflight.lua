
return {
    layout = {
        cols = 3,
        rows = 2,
        padding = 4
    },
    boxes = {
        {col=1, row=1, type="telemetry", source="governor", title="GOVERNOR", unit="", color=nil, titlealign="left", titlecolor = "red", valuealign="right", titlepaddingleft = 10, transform=function(v) return rfsuite.utils.getGovernorState(v) end},
        {col=2, row=1, type="telemetry", source="current", title="CURRENT", unit="A", color="orange", transform = function(v) return v and math.floor(v / 100) * 100 end, titlealign="center", valuealign="center"},
        {col=3, row=1, type="telemetry", source="rpm", title="RPM", unit="RPM", color="red", transform="floor", titlealign="right", valuealign="left"},
        {col=1, row=2, colspan=2, type="text", value="PRE-FLIGHT", title="", unit="", color={0, 188, 4}, bgcolor="blue", titlealign="center", valuealign="center"},
        {col=3, row=2, type="image", value="widgets/dashboard/default_image.png", title="My Craft", titlecolor="black", bgcolor="white", imagepadding = 10, imagewidth=60, imageheight=60, imagealign="left", titlepos="bottom"}
    }
}
