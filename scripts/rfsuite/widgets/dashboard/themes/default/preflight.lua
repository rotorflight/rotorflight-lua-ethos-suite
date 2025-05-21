return {
    layout = {
        cols = 3,
        rows = 2,
        padding = 4
    },
    boxes = {
        {col=1, row=1, source="voltage", title="VOLTAGE", unit="V", color=nil},
        {col=2, row=1, source="current", title="CURRENT", unit="A", color="orange", transform = function(v) return v and math.floor(v / 100) * 100 end},
        {col=3, row=1, source="rpm", title="RPM", unit="RPM", color="red", transform="floor"},
        {col=1, row=2, colspan=3, value="PRE-FLIGHT", title="", unit="", color={0, 188, 4}, bgcolor="blue"}
    }
}