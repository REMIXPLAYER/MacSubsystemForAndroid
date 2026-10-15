#!/usr/bin/env python3
"""Draw the Mac Android Subsystem icon (a Mac window holding the Android
robot's head) and write every size the asset catalog, the DMG and the website need.

    python3 apple/icon/make_icons.py

Requires Pillow. Re-run after changing the design; outputs are committed.
"""
import json
import pathlib

from PIL import Image, ImageDraw, ImageFilter

HERE = pathlib.Path(__file__).resolve().parent
APPLE = HERE.parent
ROOT = APPLE.parent
S = 1024

GREEN_DARK = (14, 58, 49)
GREEN = (28, 122, 99)
LIME = (126, 201, 125)
ANDROID_GREEN = (61, 220, 132)  # #3DDC84


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(size, stops):
    """Vertical-diagonal gradient through `stops`."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (0.35 * x + 0.65 * y) / (size - 1)
            seg = min(int(t * (len(stops) - 1)), len(stops) - 2)
            local = t * (len(stops) - 1) - seg
            px[x, y] = lerp(stops[seg], stops[seg + 1], local)
    return img


def master():
    scale = 4
    big = S * scale
    canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))

    # macOS icon grid: 824/1024 rounded square with a soft shadow.
    inset = big * 100 / 1024
    tile = [inset, inset, big - inset, big - inset]
    radius = big * 185 / 1024
    shadow = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([tile[0], tile[1] + big * 0.012, tile[2], tile[3] + big * 0.012],
                                             radius, fill=(0, 0, 0, 90))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(big * 0.018)))

    bg = gradient(S, [GREEN_DARK, GREEN, LIME]).resize((big, big), Image.BICUBIC).convert("RGBA")
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle(tile, radius, fill=255)
    canvas.paste(bg, (0, 0), mask)
    draw = ImageDraw.Draw(canvas, "RGBA")

    # A Mac window.
    wx0, wy0 = big * 0.22, big * 0.25
    wx1, wy1 = big * 0.78, big * 0.77
    wr = big * 0.045
    win_shadow = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    ImageDraw.Draw(win_shadow).rounded_rectangle([wx0, wy0 + big * 0.02, wx1, wy1 + big * 0.02], wr, fill=(5, 30, 25, 120))
    canvas.alpha_composite(win_shadow.filter(ImageFilter.GaussianBlur(big * 0.02)))
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.rounded_rectangle([wx0, wy0, wx1, wy1], wr, fill=(250, 252, 251, 255))
    # Title bar with traffic lights.
    bar = big * 0.075
    draw.rounded_rectangle([wx0, wy0, wx1, wy0 + bar], wr, fill=(232, 238, 236, 255))
    draw.rectangle([wx0, wy0 + bar - wr, wx1, wy0 + bar], fill=(232, 238, 236, 255))
    dot = big * 0.016
    for i, color in enumerate([(255, 95, 87), (254, 188, 46), (40, 200, 64)]):
        cx = wx0 + big * 0.045 + i * big * 0.042
        cy = wy0 + bar / 2
        draw.ellipse([cx - dot, cy - dot, cx + dot, cy + dot], fill=color + (255,))

    # The Android robot's head in the window.
    android_head(draw, cx=(wx0 + wx1) / 2, base=wy1 - big * 0.115, radius=big * 0.175, ink=ANDROID_GREEN,
                 eye=(250, 252, 251, 255))

    return canvas.resize((S, S), Image.LANCZOS)


def android_head(draw, cx, base, radius, ink, eye):
    """The Android robot's head: a half dome, two antennae and two eyes.

    The Android robot is reproduced or modified from work created and shared by
    Google and used according to terms described in the Creative Commons 3.0
    Attribution License.
    """
    import math
    ink = ink + (255,) if len(ink) == 3 else ink
    width = radius * 0.11
    for angle in (122, 58):
        a = math.radians(angle)
        x0, y0 = cx + math.cos(a) * radius * 0.8, base - math.sin(a) * radius * 0.8
        x1, y1 = cx + math.cos(a) * radius * 1.32, base - math.sin(a) * radius * 1.32
        draw.line([(x0, y0), (x1, y1)], fill=ink, width=int(width))
        for x, y in ((x1, y1),):
            draw.ellipse([x - width / 2, y - width / 2, x + width / 2, y + width / 2], fill=ink)
    draw.pieslice([cx - radius, base - radius, cx + radius, base + radius], 180, 360, fill=ink)
    er = radius * 0.11
    for side in (-1, 1):
        ex, ey = cx + side * radius * 0.43, base - radius * 0.42
        draw.ellipse([ex - er, ey - er, ex + er, ey + er], fill=eye)


def write_catalog(path, contents):
    path.mkdir(parents=True, exist_ok=True)
    (path / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def dmg_background():
    for scale, name in [(1, "background.png"), (2, "background@2x.png")]:
        w, h = 600 * scale, 400 * scale
        img = gradient(max(w, h), [(244, 249, 247), (226, 240, 234), (214, 234, 222)]).crop((0, 0, w, h))
        draw = ImageDraw.Draw(img)
        # Arrow from the app to Applications.
        y = 200 * scale
        draw.line([(255 * scale, y), (345 * scale, y)], fill=(28, 122, 99), width=6 * scale)
        draw.polygon([(345 * scale, y - 14 * scale), (370 * scale, y), (345 * scale, y + 14 * scale)], fill=(28, 122, 99))
        out = APPLE / "dmg"
        out.mkdir(parents=True, exist_ok=True)
        img.save(out / name)


def main():
    icon = master()

    assets = APPLE / "Resources/Assets.xcassets"
    write_catalog(assets, {"info": {"author": "xcode", "version": 1}})
    icon_set = assets / "AppIcon.appiconset"
    icon_set.mkdir(parents=True, exist_ok=True)
    images = []
    for pt in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = pt * scale
            name = f"icon-{pt}@{scale}x.png"
            icon.resize((px, px), Image.LANCZOS).save(icon_set / name)
            images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{pt}x{pt}"})
    write_catalog(icon_set, {"images": images, "info": {"author": "xcode", "version": 1}})

    site = ROOT / "site/assets"
    site.mkdir(parents=True, exist_ok=True)
    icon.resize((512, 512), Image.LANCZOS).save(site / "icon-512.png")
    icon.resize((180, 180), Image.LANCZOS).save(site / "apple-touch-icon.png")
    icon.resize((64, 64), Image.LANCZOS).save(site / "favicon.png")
    dmg_background()
    print("Icons written.")


if __name__ == "__main__":
    main()
