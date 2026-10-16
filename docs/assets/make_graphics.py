#!/usr/bin/env python3
"""Draw the README's graphics and the website's social preview image.

    python3 docs/assets/make_graphics.py

Writes docs/assets/banner.svg, docs/assets/how-it-works.svg and
site/assets/og-image.png (1200x630, for link previews and search results).
The app icon is rendered from apple/Resources/AppIcon.icon with Icon Composer's
ictool, and the PNG with WebKit (render_svg.swift), so this needs macOS and
Xcode 26 or later. Outputs are committed.
"""
import base64
import html
import pathlib
import subprocess
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
ICON = ROOT / "apple/Resources/AppIcon.icon"
ICTOOL = "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
FONT = "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', 'Helvetica Neue', Arial, sans-serif"

DARK, MID, LIGHT = "#06201A", "#0E3A31", "#1C7A63"
MINT, MINT_DIM, ANDROID = "#B7F5D0", "#CFE8DF", "#3DDC84"


def icon_png(size, work):
    out = pathlib.Path(work) / f"icon-{size}.png"
    subprocess.run([ICTOOL, str(ICON), "--export-image", "--output-file", str(out), "--platform", "macOS",
                    "--rendition", "Default", "--width", str(size), "--height", str(size), "--scale", "1"],
                   check=True, stdout=subprocess.DEVNULL)
    return "data:image/png;base64," + base64.b64encode(out.read_bytes()).decode()


def background(w, h):
    return f'''<defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{DARK}"/><stop offset="0.55" stop-color="{MID}"/><stop offset="1" stop-color="{LIGHT}"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.22" cy="0.45" r="0.5">
      <stop offset="0" stop-color="{ANDROID}" stop-opacity="0.28"/><stop offset="1" stop-color="{ANDROID}" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="{w}" height="{h}" rx="28" fill="url(#bg)"/>
  <rect width="{w}" height="{h}" rx="28" fill="url(#glow)"/>'''


def chips(labels, x, y, size=19, gap=12):
    out, cx = [], x
    for label in labels:
        width = int(len(label) * size * 0.56) + 36
        out.append(f'<rect x="{cx}" y="{y}" width="{width}" height="{size + 22}" rx="{(size + 22) / 2}" '
                   f'fill="#FFFFFF" fill-opacity="0.10" stroke="#FFFFFF" stroke-opacity="0.22"/>'
                   f'<text x="{cx + width / 2}" y="{y + size + 5}" text-anchor="middle" font-size="{size}" '
                   f'font-weight="500" fill="{MINT_DIM}">{html.escape(label)}</text>')
        cx += width + gap
    return "\n  ".join(out)


def hero(w, h, icon, icon_size, title_size, chip_rows):
    ix, iy = 70, (h - icon_size) / 2 - (10 if chip_rows else 0)
    tx = ix + icon_size + 44
    rows = "\n  ".join(chips(row, tx, h / 2 + 62 + i * 54) for i, row in enumerate(chip_rows))
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" font-family="{FONT}">
  <title>Mac Android Subsystem: Android apps, at home on your Mac</title>
  {background(w, h)}
  <image href="{icon}" x="{ix}" y="{iy}" width="{icon_size}" height="{icon_size}"/>
  <text x="{tx}" y="{h / 2 - 52}" font-size="{title_size}" font-weight="700" fill="#FFFFFF" letter-spacing="-1">Mac Android Subsystem</text>
  <text x="{tx}" y="{h / 2 - 6}" font-size="{title_size * 0.5}" font-weight="600" fill="{MINT}">Android apps, at home on your Mac.</text>
  <text x="{tx}" y="{h / 2 + 32}" font-size="{title_size * 0.32}" fill="{MINT_DIM}">Every app in its own window with its own Dock icon. Free and open source.</text>
  {rows}
</svg>
'''


def how_it_works():
    steps = [
        ("Menu bar app", "Starts Android, installs", "apps, applies modes"),
        ("Virtual machine", "QEMU on Apple's Hypervisor,", "near native speed"),
        ("Android", "LineageOS, no Google", "apps, in the background"),
        ("Virtual displays", "One per app, streamed", "with hardware decoding"),
        ("Mac windows", "Dock icon, Launchpad,", "Spotlight, ⌘-Tab"),
    ]
    w, h, box, gap, top = 1280, 300, 212, 50, 70
    x0 = (w - (len(steps) * box + (len(steps) - 1) * gap)) / 2
    parts = []
    for i, (title, a, b) in enumerate(steps):
        x = x0 + i * (box + gap)
        accent = ANDROID if i in (2, 4) else MINT
        parts.append(f'''<rect x="{x}" y="{top}" width="{box}" height="160" rx="22" fill="#FFFFFF" fill-opacity="0.08" stroke="#FFFFFF" stroke-opacity="0.2"/>
  <circle cx="{x + 34}" cy="{top + 36}" r="15" fill="{accent}"/>
  <text x="{x + 34}" y="{top + 42}" text-anchor="middle" font-size="17" font-weight="700" fill="{DARK}">{i + 1}</text>
  <text x="{x + 22}" y="{top + 92}" font-size="21" font-weight="700" fill="#FFFFFF">{title}</text>
  <text x="{x + 22}" y="{top + 120}" font-size="15.5" fill="{MINT_DIM}">{a}</text>
  <text x="{x + 22}" y="{top + 141}" font-size="15.5" fill="{MINT_DIM}">{b}</text>''')
        if i < len(steps) - 1:
            ax = x + box + 8
            parts.append(f'<path d="M{ax} {top + 80} h{gap - 22} m-9 -9 l9 9 l-9 9" fill="none" stroke="{MINT}" '
                         f'stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>')
    body = "\n  ".join(parts)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" font-family="{FONT}">
  <title>How Mac Android Subsystem works</title>
  {background(w, h)}
  <text x="{w / 2}" y="44" text-anchor="middle" font-size="22" font-weight="600" fill="{MINT}">How it works</text>
  {body}
</svg>
'''


def main():
    with tempfile.TemporaryDirectory() as work:
        (HERE / "banner.svg").write_text(hero(1280, 440, icon_png(256, work), 250, 64, [
            ["Own window & Dock icon", "Liquid Glass", "Game controllers"],
            ["Privacy controls", "Apple silicon", "Open source"],
        ]))
        (HERE / "how-it-works.svg").write_text(how_it_works())

        og = pathlib.Path(work) / "og-image.svg"
        og.write_text(hero(1200, 630, icon_png(512, work), 290, 62, [
            ["Own window & Dock icon", "Liquid Glass", "Game controllers"],
            ["Privacy controls", "Apple silicon", "Free & open source"],
        ]))
        subprocess.run(["swift", str(HERE / "render_svg.swift"), str(og), str(ROOT / "site/assets/og-image.png"),
                        "1200", "630"], check=True)
        # WebKit renders at the screen's scale; social previews want exactly 1200x630.
        subprocess.run(["sips", "-z", "630", "1200", str(ROOT / "site/assets/og-image.png")], check=True,
                       stdout=subprocess.DEVNULL)
    print("Graphics written.")


if __name__ == "__main__":
    main()
