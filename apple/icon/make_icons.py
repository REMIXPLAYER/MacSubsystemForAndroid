#!/usr/bin/env python3
"""Write the website's icons and the DMG background.

The app icon is apple/Resources/AppIcon.icon, an Icon Composer document (Liquid
Glass: a frosted Mac window and the glass head of the Android robot peeking in over its bottom edge); Xcode builds it into the
app, with a flat icon for macOS before 26. Edit it in Icon Composer, then run

    python3 apple/icon/make_icons.py

to render the website's PNGs from it. Requires Pillow and Xcode 26 or later.
Outputs are committed.

The Android robot is reproduced or modified from work created and shared by
Google and used according to terms described in the Creative Commons 3.0
Attribution License.
"""
import pathlib
import subprocess

from PIL import Image, ImageDraw

HERE = pathlib.Path(__file__).resolve().parent
APPLE = HERE.parent
ROOT = APPLE.parent
ICON = APPLE / "Resources/AppIcon.icon"
ICTOOL = "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"


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


def site_icons():
    """Render the Liquid Glass icon with Icon Composer's ictool (Xcode 26 or later)."""
    for px, name in [(512, "icon-512.png"), (180, "apple-touch-icon.png"), (64, "favicon.png")]:
        subprocess.run([ICTOOL, str(ICON), "--export-image", "--output-file", str(ROOT / "site/assets" / name),
                        "--platform", "macOS", "--rendition", "Default",
                        "--width", str(px), "--height", str(px), "--scale", "1"],
                       check=True, stdout=subprocess.DEVNULL)


def main():
    site_icons()
    dmg_background()
    print("Icons written.")


if __name__ == "__main__":
    main()
