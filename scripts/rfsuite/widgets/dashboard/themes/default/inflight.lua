return {
    layout = {
        cols = 3,
        rows = 2,
        padding = 4
    },
    boxes = {
        {col=1, row=1, source="voltage", title="VOLTAGE", unit="V", color=nil},
        {col=2, row=1, source="current", title="CURRENT", unit="A", color=2},
        {col=3, row=1, source="rpm", title="RPM", unit="RPM", color=3, format="floor"},
        {col=1, row=2, colspan=3, value="INFLIGHT", title="", unit="", color=0}
    }
}