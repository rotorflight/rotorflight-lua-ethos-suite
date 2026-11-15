"""Generate static documentation: pip install Pillow; python bin/activelook_preview/export_docs.py.

Uses the existing preview requirements and real suite Lua renderer. No server or
simulator settings are needed or modified. The optical projection is approximate.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

from renderer import WidgetRenderer

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "docs" / "assets" / "activelook-layouts"
LAYOUTS = ("one_centered", "one_top_two_bottom", "stacked_three",
           "two_top_one_bottom", "two_top_two_bottom")
EXAMPLE_SLOTS = ["current", "voltage", "fuel", "timer"]
EXAMPLE_SENSORS = dict(armed=True, governorState=4, voltage=24.8,
                       current=42, fuel=70, timer=154)


def display(frame):
    # Supersample the native display using the same font and sizes as index.html.
    scale = 4
    image = Image.new("RGBA", (304 * scale, 256 * scale))
    draw = ImageDraw.Draw(image)
    def bitmap(value):
        ident = value["id"]
        size = 28 if 2 <= ident <= 6 else 40
        atlas = Image.open(HERE.parents[1] / "docs/reference/activelook-frsky-v8/frsky-21-symbols-original-grayscale.png").convert("L")
        x = (ident - 1) % 4 * 300 + 70 + (160 - size * 4) // 2
        y = (ident - 1) // 4 * 230 + 22
        mask = atlas.crop((x, y, x + size * 4, y + size * 4))
        icon = Image.new("RGBA", mask.size, (242, 227, 0, 255))
        icon.putalpha(mask)
        image.alpha_composite(icon, (value["x"] * scale, value["y"] * scale))

    for command in frame["commands"]:
        if "text" not in command:
            bitmap(command["bitmap"])
            continue
        text = command["text"]
        font = ImageFont.truetype(str(HERE / "SSP-SemiBold-Spacing.otf"),
                                  frame["fonts"][text["font"] - 1] * scale)
        draw.text((text["x"] * scale, text["y"] * scale), text["text"],
                  font=font, fill=(242, 227, 0, 204), anchor="lt")
    if frame.get("bitmap"):
        bitmap(frame["bitmap"])
    return image


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    photo = Image.open(HERE / "Engo-Sports-Eyewear.jpg").convert("RGBA")
    w, h = photo.size
    # Match the browser's lens-cleanup overlay over the original printed values.
    cleanup = Image.new("RGBA", photo.size)
    ImageDraw.Draw(cleanup).rectangle((int(w * .70), int(h * .23), int(w * .87), int(h * .39)),
                                     fill=(12, 13, 15, 255))
    photo = Image.alpha_composite(photo, cleanup.filter(ImageFilter.GaussianBlur(4)))
    def save_frame(frame, filename):
        overlay = display(frame)
        width = round(w * .155)
        overlay = overlay.resize((width, round(width * 256 / 304)), Image.Resampling.LANCZOS)
        # Browser uses a slight skew and rotation; preserve the same location.
        overlay = overlay.transform(overlay.size, Image.Transform.AFFINE,
                                    (1, .0524, -overlay.height * .0262, 0, 1, 0),
                                    Image.Resampling.BICUBIC)
        overlay = overlay.rotate(4, Image.Resampling.BICUBIC, expand=True)
        result = photo.copy()
        result.alpha_composite(overlay, (round(w * .712) - (overlay.width - width) // 2,
                                        round(h * .232)))
        result.convert("RGB").save(OUT / filename, quality=94)

    for layout in LAYOUTS:
        # Use one inflight example per layout; narrow top cells get short values.
        slots = (["fuel", "voltage", "current", "timer"]
                 if layout in ("two_top_one_bottom", "two_top_two_bottom")
                 else EXAMPLE_SLOTS)
        settings = {"enabled": True, "offset_x": 0, "offset_y": 0,
                    "layout_inflight": layout}
        settings.update({f"inflight_{i}": key for i, key in enumerate(slots, 1)})
        frame = WidgetRenderer().render({"preview": "inflight",
            "settings": {"activelook": settings},
            "sensors": {"connected": True, "cellCount": 6, "modelType": 1,
                        **EXAMPLE_SENSORS}}, now=10)
        assert frame["enabled"] and frame["commands"], layout
        save_frame(frame, f"{layout}_inflight.jpg")
    examples = [
        ("battery_empty", "low_fuel", 1, 0),
        ("low_fuel", "low_fuel", 2, 0),
        ("esc_temperature", "esc_temp", 1, 0),
        ("rf_link", "rf_link", 1, 0),
        ("headspeed_lost", "governor_lost", 1, 0),
        ("autorotation", "governor_status", 1, 0),
        ("bailout", "governor_status", 1, 2.1),
    ]
    for name, preview, model, elapsed in examples:
        renderer = WidgetRenderer()
        request = {"preview": preview, "settings": {"activelook": {"enabled": True}},
                   "sensors": {"connected": True, "armed": True, "modelType": model,
                               "cellCount": 6, "fuel": 0, "voltage": 22.6,
                               "consumption": 3250, "tempEsc": 95, "link": 35,
                               "rpm": 1200, "governorState": 4}}
        frame = renderer.render(request, now=10)
        if elapsed:
            frame = renderer.render(request, now=10 + elapsed)
        assert frame["commands"], name
        save_frame(frame, f"alert_{name}.jpg")
    print(f"Exported 5 layouts and 7 alert/status examples to {OUT}")


if __name__ == "__main__":
    main()
