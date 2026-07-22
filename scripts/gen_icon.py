from PIL import Image, ImageDraw, ImageFilter
import json
import os

MASTER = 1024
OUT_DIR = "/Users/alex/Documents/reveille/MacAlert/Assets.xcassets/AppIcon.appiconset"
S = MASTER


def make_background():
    img = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    grad = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(grad)
    top_color = (74, 92, 235)      # indigo/blue
    bottom_color = (150, 60, 220)  # purple
    for y in range(MASTER):
        t = y / MASTER
        r = int(top_color[0] + (bottom_color[0] - top_color[0]) * t)
        g = int(top_color[1] + (bottom_color[1] - top_color[1]) * t)
        b = int(top_color[2] + (bottom_color[2] - top_color[2]) * t)
        gdraw.line([(0, y), (MASTER, y)], fill=(r, g, b, 255))

    mask = Image.new("L", (MASTER, MASTER), 0)
    mdraw = ImageDraw.Draw(mask)
    radius = int(MASTER * 0.225)
    mdraw.rounded_rectangle([0, 0, MASTER - 1, MASTER - 1], radius=radius, fill=255)

    img = Image.composite(grad, img, mask)
    return img


def draw_bell(img):
    cx, cy = S * 0.5, S * 0.47
    white = (255, 255, 255, 255)
    shadow_color = (30, 20, 70, 90)

    # Soft shadow layer beneath the bell for depth
    shadow_layer = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow_layer)
    _bell_shapes(sdraw, cx, cy + S * 0.02, shadow_color)
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(radius=S * 0.02))
    img.alpha_composite(shadow_layer)

    draw = ImageDraw.Draw(img)
    _bell_shapes(draw, cx, cy, white)
    return img


def _bell_shapes(draw, cx, cy, color):
    # Knob on top
    knob_r = S * 0.020
    draw.ellipse([cx - knob_r, cy - S * 0.32 - knob_r, cx + knob_r, cy - S * 0.32 + knob_r], fill=color)

    # Dome (upper, narrow)
    r1 = S * 0.135
    y1 = cy - S * 0.22
    draw.ellipse([cx - r1, y1 - r1, cx + r1, y1 + r1], fill=color)

    # Mid section
    r2 = S * 0.185
    y2 = cy - S * 0.06
    draw.ellipse([cx - r2, y2 - r2, cx + r2, y2 + r2], fill=color)

    # Body (widest, lower)
    rw, rh = S * 0.235, S * 0.195
    y3 = cy + S * 0.10
    draw.ellipse([cx - rw, y3 - rh, cx + rw, y3 + rh], fill=color)

    # Rim (flat wide ellipse at the base of the bell)
    rimw, rimh = S * 0.27, S * 0.042
    y4 = cy + S * 0.27
    draw.ellipse([cx - rimw, y4 - rimh, cx + rimw, y4 + rimh], fill=color)

    # Clapper hanging below the rim
    clap_r = S * 0.042
    y5 = cy + S * 0.355
    draw.ellipse([cx - clap_r, y5 - clap_r, cx + clap_r, y5 + clap_r], fill=color)


ICON_SPECS = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png"),
]

CONTENTS = {
    "images": [
        {"idiom": "mac", "scale": "1x", "size": "16x16", "filename": "icon_16x16.png"},
        {"idiom": "mac", "scale": "2x", "size": "16x16", "filename": "icon_16x16@2x.png"},
        {"idiom": "mac", "scale": "1x", "size": "32x32", "filename": "icon_32x32.png"},
        {"idiom": "mac", "scale": "2x", "size": "32x32", "filename": "icon_32x32@2x.png"},
        {"idiom": "mac", "scale": "1x", "size": "128x128", "filename": "icon_128x128.png"},
        {"idiom": "mac", "scale": "2x", "size": "128x128", "filename": "icon_128x128@2x.png"},
        {"idiom": "mac", "scale": "1x", "size": "256x256", "filename": "icon_256x256.png"},
        {"idiom": "mac", "scale": "2x", "size": "256x256", "filename": "icon_256x256@2x.png"},
        {"idiom": "mac", "scale": "1x", "size": "512x512", "filename": "icon_512x512.png"},
        {"idiom": "mac", "scale": "2x", "size": "512x512", "filename": "icon_512x512@2x.png"},
    ],
    "info": {"author": "xcode", "version": 1},
}


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)

    master = make_background()
    master = draw_bell(master)
    master.save("/tmp/icon_master_1024.png")

    for size, scale, filename in ICON_SPECS:
        px = size * scale
        resized = master.resize((px, px), Image.LANCZOS)
        resized.save(os.path.join(OUT_DIR, filename))
        print(f"wrote {filename} ({px}x{px})")

    with open(os.path.join(OUT_DIR, "Contents.json"), "w") as f:
        json.dump(CONTENTS, f, indent=2)
    print("Contents.json updated")
