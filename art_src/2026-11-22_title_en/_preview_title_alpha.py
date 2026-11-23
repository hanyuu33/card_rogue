# -*- coding: utf-8 -*-
"""透明标题在三类背景上的贴图验收：棋盘、深色、暖色插画底色。"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
D = os.path.join(ROOT, "art_src", "2026-11-22_title_en")
SRC = os.path.join(ROOT, "release", "store", "quackill_title_en_alpha.png")


def main():
    logo = Image.open(SRC).convert("RGBA")
    tw = 1200
    th = int(logo.height * tw / logo.width)
    top = 24
    sheet = Image.new("RGB", (tw, (th + top) * 3), (40, 44, 52))
    draw = ImageDraw.Draw(sheet)
    variants = [(238, 238, 238), (32, 35, 42), (198, 90, 45)]
    for row, color in enumerate(variants):
        y0 = row * (th + top)
        panel = Image.new("RGB", (tw, th), color)
        if row == 0:
            for yy in range(0, th, 24):
                for xx in range(0, tw, 24):
                    if (xx // 24 + yy // 24) % 2:
                        ImageDraw.Draw(panel).rectangle([xx, yy, xx + 23, yy + 23], fill=(205, 205, 205))
        small = logo.resize((tw - 40, th - 40), Image.Resampling.LANCZOS)
        panel.paste(small, (20, 20), small)
        sheet.paste(panel, (0, y0 + top))
        draw.text((10, y0 + 4), ("checker" if row == 0 else "dark" if row == 1 else "warm"), fill=(240, 240, 240))
    out = os.path.join(D, "preview_title_alpha.png")
    sheet.save(out, optimize=True)
    print(out)


if __name__ == "__main__":
    main()
