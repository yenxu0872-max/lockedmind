#!/usr/bin/env python3
"""Frames raw app captures as App Store screenshots: 1320 x 2868 (6.9-inch
iPhone), a headline above the phone, on the brand's dark background.

    python3 tools/frame.py RAW_DIR OUT_DIR

RAW_DIR holds raw-1-*.png … raw-5-*.png, each an app screen at the phone's
aspect ratio (the Mac preview at 440 x 956 pt, or Simulator captures).
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1320, 2868
FONT = "/System/Library/Fonts/SFNS.ttf"

HEADLINES = {
    "1": "Private AI that lives\non your iPhone",
    "2": "Plans, explains\nand brainstorms",
    "3": "Writes messages\nfor you",
    "4": "Nothing you write\nleaves your phone",
    "5": "Your chats,\nonly on this iPhone",
}


def font(size, weight="Bold"):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_name(weight)
    return f


def background():
    bg = Image.new("RGB", (W, H), (7, 7, 10))
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    d = ImageDraw.Draw(glow)
    d.ellipse((W * 0.5 - 760, -560, W * 0.5 + 760, 900), fill=(84, 52, 150))
    d.ellipse((W * 0.5 - 520, 1500, W * 0.5 + 900, 3300), fill=(0, 70, 110))
    glow = glow.filter(ImageFilter.GaussianBlur(260))
    return Image.blend(bg, glow, 0.85)


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *img.size), radius, fill=255)
    out = img.copy()
    out.putalpha(mask)
    return out


def frame(raw: Path, key: str) -> Image.Image:
    canvas = background().convert("RGBA")
    d = ImageDraw.Draw(canvas)

    # The headline: two lines, centred.
    title = font(104)
    d.multiline_text((W / 2, 250), HEADLINES[key], font=title, fill=(245, 245, 247),
                     anchor="ma", align="center", spacing=22)

    # The phone: the screen in a thin dark bezel, with a soft shadow.
    screen_w = 930
    shot = Image.open(raw).convert("RGB")
    shot = shot.resize((screen_w, round(shot.height * screen_w / shot.width)), Image.LANCZOS)
    bezel = 22
    body_w, body_h = screen_w + bezel * 2, shot.height + bezel * 2
    x, y = (W - body_w) // 2, 610

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x, y + 30, x + body_w, y + body_h + 30), 150, fill=(0, 0, 0, 170))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(50)))

    body = Image.new("RGBA", (body_w, body_h), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle((0, 0, body_w - 1, body_h - 1), 150, fill=(28, 28, 32, 255),
                                           outline=(70, 70, 78, 255), width=3)
    canvas.alpha_composite(body, (x, y))
    canvas.alpha_composite(rounded(shot, 128), (x + bezel, y + bezel))
    return canvas.convert("RGB")


def main():
    raw_dir, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    for raw in sorted(raw_dir.glob("raw-*.png")):
        key = raw.stem.split("-")[1]
        out = out_dir / f"{raw.stem.replace('raw-', '')}.png"
        frame(raw, key).save(out, optimize=True)
        print(out)


if __name__ == "__main__":
    main()
