from PIL import Image, ImageDraw
import json
import os

S = 512  # master render size for the template icon (downsized after)
OUT_DIR = "/Users/alex/Documents/reveille/MacAlert/Assets.xcassets/MenuBarIcon.imageset"


def _bell_shapes(draw, cx, cy, color):
    knob_r = S * 0.026
    draw.ellipse([cx - knob_r, cy - S * 0.32 - knob_r, cx + knob_r, cy - S * 0.32 + knob_r], fill=color)

    r1 = S * 0.150
    y1 = cy - S * 0.20
    draw.ellipse([cx - r1, y1 - r1, cx + r1, y1 + r1], fill=color)

    r2 = S * 0.205
    y2 = cy - S * 0.03
    draw.ellipse([cx - r2, y2 - r2, cx + r2, y2 + r2], fill=color)

    rw, rh = S * 0.255, S * 0.205
    y3 = cy + S * 0.13
    draw.ellipse([cx - rw, y3 - rh, cx + rw, y3 + rh], fill=color)

    rimw, rimh = S * 0.29, S * 0.048
    y4 = cy + S * 0.30
    draw.ellipse([cx - rimw, y4 - rimh, cx + rimw, y4 + rimh], fill=color)

    clap_r = S * 0.048
    y5 = cy + S * 0.39
    draw.ellipse([cx - clap_r, y5 - clap_r, cx + clap_r, y5 + clap_r], fill=color)


def make_template():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = S * 0.5, S * 0.44
    _bell_shapes(draw, cx, cy, (0, 0, 0, 255))
    return img


CONTENTS = {
    "images": [
        {"idiom": "universal", "filename": "menubar_18.png", "scale": "1x"},
        {"idiom": "universal", "filename": "menubar_18@2x.png", "scale": "2x"},
        {"idiom": "universal", "filename": "menubar_18@3x.png", "scale": "3x"},
    ],
    "info": {"author": "xcode", "version": 1},
    "properties": {"template-rendering-intent": "template"},
}

if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    master = make_template()

    for scale, filename in [(1, "menubar_18.png"), (2, "menubar_18@2x.png"), (3, "menubar_18@3x.png")]:
        px = 18 * scale
        resized = master.resize((px, px), Image.LANCZOS)
        resized.save(os.path.join(OUT_DIR, filename))
        print(f"wrote {filename} ({px}x{px})")

    with open(os.path.join(OUT_DIR, "Contents.json"), "w") as f:
        json.dump(CONTENTS, f, indent=2)
    print("Contents.json written")
